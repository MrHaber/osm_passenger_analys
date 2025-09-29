import 'dart:convert';
import 'package:http/http.dart' as http;

Future<int> getBuildingCountInRadius(double lat, double lon, int radius) async {
  final String overpassUrl = 'https://overpass-api.de/api/interpreter';
  final String query = '''
    [out:json];
    (
      way["building"](around:$radius,$lat,$lon);
      relation["building"](around:$radius,$lat,$lon);
    );
    out count;
  ''';

  try {
    final response = await http.post(Uri.parse(overpassUrl), body: {'data': query});
    if (response.statusCode == 200) {
      final Map<String, dynamic> data = json.decode(response.body);
      final int wayCount = data['elements']?.where((e) => e['type'] == 'way').length ?? 0;
      final int relationCount = data['elements']?.where((e) => e['type'] == 'relation').length ?? 0;
      return wayCount + relationCount;
    } else {
      throw Exception('Ошибка Overpass API: ${response.statusCode}');
    }
  } catch (e) {
    print('Ошибка при запросе: $e');
    return 0;
  }
}