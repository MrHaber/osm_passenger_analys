// lib/geoJson.dart
import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;
import 'package:latlong2/latlong.dart';

class GeoPoint {
  final LatLng point;
  final String name; // номер/ид
  final String displayName; // display_name
  final String timeRange; // e.g. "06:00 - 22:00"

  GeoPoint({
    required this.point,
    required this.name,
    required this.displayName,
    required this.timeRange,
  });
}

class GeoJsonLoader {
  /// Возвращает список путей к .geojson в ассетах (поддерживает 'datas/' и 'assets/datas/')
  static Future<List<String>> listGeoJsonAssets() async {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifestMap = json.decode(manifestContent);

    final files = manifestMap.keys.where((path) {
      final lower = path.toLowerCase();
      return (lower.startsWith('datas/') ||
          lower.startsWith('assets/datas/') ||
          lower.contains('/datas/')) &&
          lower.endsWith('.geojson');
    }).toList();

    files.sort();
    return files;
  }

  /// Пробует извлечь display_name (если есть) из корня файла или первой feature.properties
  static Future<String?> extractDisplayNameFromAsset(String assetPath) async {
    try {
      final content = await rootBundle.loadString(assetPath);
      final parsed = json.decode(content);

      if (parsed is Map<String, dynamic>) {
        if (parsed['display_name'] is String) return parsed['display_name'] as String;
        if (parsed['displayName'] is String) return parsed['displayName'] as String;

        final features = parsed['features'];
        if (features is List && features.isNotEmpty) {
          final first = features[0];
          if (first is Map<String, dynamic>) {
            final props = first['properties'];
            if (props is Map<String, dynamic>) {
              if (props['display_name'] is String) return props['display_name'] as String;
              if (props['displayName'] is String) return props['displayName'] as String;
            }
          }
        }
      }
    } catch (e) {
      // silent
    }
    return null;
  }

  /// Загружает GeoJSON и возвращает список GeoPoint (точки + свойства name/display_name/time).
  /// Если значение отсутствует в feature.properties, используются root-значения файла (если есть).
  static Future<List<GeoPoint>> loadGeoPointsFromAsset(String assetPath) async {
    final content = await rootBundle.loadString(assetPath);
    final parsed = json.decode(content);

    // считываем возможные "корневые" свойства, которые будут дефолтом для каждой feature
    String rootDisplayName = '';
    String rootName = '';
    String rootTime = '';

    if (parsed is Map<String, dynamic>) {
      if (parsed['display_name'] is String) rootDisplayName = parsed['display_name'] as String;
      if (parsed['displayName'] is String) rootDisplayName = parsed['displayName'] as String;
      if (parsed['name'] is String) rootName = parsed['name'] as String;
      if (parsed['time'] is String) rootTime = parsed['time'] as String;

      // также иногда first feature может содержать properties с нужными значениями,
      // но мы всё равно используем корневые как дефолт — конкретные feature.properties имеют приоритет ниже
    }

    final List<GeoPoint> points = [];

    String _propString(Map<String, dynamic> props, String key, String fallback) {
      final v = props[key];
      if (v is String && v.isNotEmpty) return v;
      // try alternative key forms
      final alt = props[key.toLowerCase()];
      if (alt is String && alt.isNotEmpty) return alt;
      return fallback;
    }

    void addPointFromCoords(List<dynamic> coord, Map<String, dynamic> props) {
      if (coord.length >= 2) {
        final lon = coord[0];
        final lat = coord[1];
        if (lon is num && lat is num) {
          // приоритет: feature.properties -> root value -> пустая строка
          final name = _propString(props, 'name', rootName);
          final displayName = _propString(props, 'display_name', rootDisplayName);
          final timeRange = _propString(props, 'time', rootTime);

          points.add(GeoPoint(
            point: LatLng(lat.toDouble(), lon.toDouble()),
            name: name,
            displayName: displayName,
            timeRange: timeRange,
          ));
        }
      }
    }

    void processGeometry(Map<String, dynamic> geometry, Map<String, dynamic> props) {
      final type = geometry['type'];
      final coords = geometry['coordinates'];

      if (type == 'Point' && coords is List) {
        addPointFromCoords(coords, props);
      } else if (type == 'MultiPoint' && coords is List) {
        for (final p in coords) if (p is List) addPointFromCoords(p, props);
      } else if (type == 'LineString' && coords is List) {
        for (final p in coords) if (p is List) addPointFromCoords(p, props);
      } else if (type == 'MultiLineString' && coords is List) {
        for (final line in coords) if (line is List) for (final p in line) if (p is List) addPointFromCoords(p, props);
      } else if (type == 'Polygon' && coords is List) {
        for (final ring in coords) if (ring is List) for (final p in ring) if (p is List) addPointFromCoords(p, props);
      } else if (type == 'MultiPolygon' && coords is List) {
        for (final poly in coords) if (poly is List) for (final ring in poly) if (ring is List) for (final p in ring) if (p is List) addPointFromCoords(p, props);
      }
    }

    if (parsed is Map<String, dynamic>) {
      if (parsed['type'] == 'FeatureCollection' && parsed['features'] is List) {
        for (final f in parsed['features']) {
          if (f is Map<String, dynamic>) {
            final geometry = f['geometry'];
            final props = f['properties'] is Map<String, dynamic> ? f['properties'] as Map<String, dynamic> : <String, dynamic>{};
            if (geometry is Map<String, dynamic>) {
              processGeometry(geometry, props);
            }
          }
        }
      } else if (parsed['type'] == 'Feature' && parsed['geometry'] is Map<String, dynamic>) {
        final props = parsed['properties'] is Map<String, dynamic> ? parsed['properties'] as Map<String, dynamic> : <String, dynamic>{};
        processGeometry(parsed['geometry'] as Map<String, dynamic>, props);
      } else if (parsed['geometry'] is Map<String, dynamic>) {
        final props = parsed['properties'] is Map<String, dynamic> ? parsed['properties'] as Map<String, dynamic> : <String, dynamic>{};
        processGeometry(parsed['geometry'] as Map<String, dynamic>, props);
      } else if (parsed['coordinates'] != null && parsed['type'] != null) {
        processGeometry(parsed as Map<String, dynamic>, <String, dynamic>{});
      } else {
        // fallback: попытка взять первую feature
        final features = parsed['features'];
        if (features is List && features.isNotEmpty) {
          final first = features[0];
          if (first is Map<String, dynamic>) {
            final geometry = first['geometry'];
            final props = first['properties'] is Map<String, dynamic> ? first['properties'] as Map<String, dynamic> : <String, dynamic>{};
            if (geometry is Map<String, dynamic>) processGeometry(geometry, props);
          }
        }
      }
    }

    return points;
  }
  static Future<List<BuildingPoint>> loadBuildingsFromAsset(String assetPath) async {
    final List<BuildingPoint> result = [];
    try {
      final content = await rootBundle.loadString(assetPath);
      final data = json.decode(content);


      final list = (data is Map<String, dynamic>)
          ? (data['railway_district_new_buildings'] ?? data['buildings'] ?? data['items'])
          : null;
      if (list is List) {
        for (final e in list) {
          if (e is Map<String, dynamic>) {
            final coords = e['coordinates'];
            if (coords is List && coords.length >= 2) {
              final lon = (coords[0] as num).toDouble();
              final lat = (coords[1] as num).toDouble();
              final id = (e['id'] is num) ? (e['id'] as num).toInt() : int.tryParse('${e['id'] ?? ''}') ?? 0;
              final name = (e['name'] is String) ? e['name'] as String : '';
              final builder = (e['builder'] is String) ? e['builder'] as String : '';
              final company = (e['company_group'] is String) ? e['company_group'] as String : '';
              final livingArea = (e['living_area'] is num) ? (e['living_area'] as num).toInt() : null;
              final commission = (e['commissioning_date'] is String) ? e['commissioning_date'] as String : '';
              final isAvail = (e['isCurrentAvailable'] is bool) ? (e['isCurrentAvailable'] as bool) : false;

              result.add(BuildingPoint(
                id: id,
                point: LatLng(lat, lon),
                name: name,
                builder: builder,
                companyGroup: company,
                livingArea: livingArea,
                commissioningDate: commission,
                isCurrentAvailable: isAvail,
              ));
            }
          }
        }
      }
    } catch (e, st) {
      // не падаем — вернём пустой список
      print('Ошибка загрузки buildings asset $assetPath: $e\n$st');
    }
    return result;
  }
}

class BuildingPoint {
  final int id;
  final LatLng point;
  final String name;
  final String builder;
  final String companyGroup;
  final int? livingArea;
  final String commissioningDate;
  final bool isCurrentAvailable;

  BuildingPoint({
    required this.id,
    required this.point,
    required this.name,
    required this.builder,
    required this.companyGroup,
    this.livingArea,
    required this.commissioningDate,
    required this.isCurrentAvailable,
  });
}


