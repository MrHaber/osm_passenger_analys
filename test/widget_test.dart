// This is a basic Flutter widget test.
//
// To perform an interaction with a widget in your test, use the WidgetTester
// utility in the flutter_test package. For example, you can send tap and scroll
// gestures. You can also use WidgetTester to find child widgets in the widget
// tree, read text, and verify that the values of widget properties are correct.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:flutter_map_location_marker/flutter_map_location_marker.dart';
import 'package:latlong2/latlong.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:http/http.dart' as http;
import 'package:syncfusion_flutter_charts/charts.dart';

import 'package:Analytics/geoJson.dart'; // твой geoJson loader
import 'package:shared_preferences/shared_preferences.dart';

import 'package:Analytics/main.dart';

void _debugListAssets() async {
  try {
    final manifestContent = await rootBundle.loadString('AssetManifest.json');
    final Map<String, dynamic> manifest = json.decode(manifestContent);
    final keys = manifest.keys.where((k) => k.contains('buildings')).toList();
    debugPrint('Assets containing "buildings": ${keys.length}');
    for (final k in keys) debugPrint('  asset: $k');
  } catch (e, st) {
    debugPrint('Error reading AssetManifest: $e\n$st');
  }
}
void main() {
  _debugListAssets();
}
