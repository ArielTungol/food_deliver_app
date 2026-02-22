import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:food_delivery_app/utils/api_keys.dart';

class RouteService {
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.openrouteservice.org/v2/directions/driving-car?'
                'api_key=${ApiKeys.orsApiKey}&'
                'start=${start.longitude},${start.latitude}&'
                'end=${end.longitude},${end.latitude}'
        ),
      );

      if (response.statusCode == 200) {
        return _parseRouteResponse(response.body);
      } else {
        print('Error: ${response.statusCode} - ${response.body}');
        return _getSimplePath(start, end);
      }
    } catch (e) {
      print('Exception: $e');
      return _getSimplePath(start, end);
    }
  }

  static Future<Map<String, dynamic>> getRouteWithDetails(LatLng start, LatLng end) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.openrouteservice.org/v2/directions/driving-car?'
                'api_key=${ApiKeys.orsApiKey}&'
                'start=${start.longitude},${start.latitude}&'
                'end=${end.longitude},${end.latitude}'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final List<dynamic> coordinates = data['features'][0]['geometry']['coordinates'];
        final summary = data['features'][0]['properties']['summary'];

        List<LatLng> routePoints = [];
        for (var coord in coordinates) {
          routePoints.add(LatLng(coord[1], coord[0]));
        }

        return {
          'route': routePoints,
          'distance': summary['distance'], // in meters
          'duration': summary['duration'], // in seconds
        };
      }
    } catch (e) {
      print('Error getting route details: $e');
    }

    return {
      'route': _getSimplePath(start, end),
      'distance': 0,
      'duration': 0,
    };
  }

  static List<LatLng> _parseRouteResponse(String responseBody) {
    final data = json.decode(responseBody);
    final List<LatLng> routePoints = [];

    try {
      final List<dynamic> coordinates = data['features'][0]['geometry']['coordinates'];

      for (var coord in coordinates) {
        routePoints.add(LatLng(coord[1], coord[0]));
      }
    } catch (e) {
      print('Error parsing route: $e');
    }

    return routePoints;
  }

  static List<LatLng> _getSimplePath(LatLng start, LatLng end) {
    final path = <LatLng>[start];
    double latStep = (end.latitude - start.latitude) / 20;
    double lngStep = (end.longitude - start.longitude) / 20;

    for (int i = 1; i <= 20; i++) {
      path.add(LatLng(
        start.latitude + (latStep * i),
        start.longitude + (lngStep * i),
      ));
    }
    return path;
  }

  static String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds} sec';
    if (seconds < 3600) return '${(seconds / 60).round()} min';
    return '${(seconds / 3600).round()} hr ${((seconds % 3600) / 60).round()} min';
  }

  static String formatDistance(int meters) {
    if (meters < 1000) return '${meters} m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }
}