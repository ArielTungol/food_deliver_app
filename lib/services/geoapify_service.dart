import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';
import '../utils/api_keys.dart';

class GeoapifyService {
  static const String apiKey = ApiKeys.geoapifyKey;

  // ============== GEOCODING (Address ↔ Coordinates) ==============

  /// Forward geocoding: Convert address to coordinates
  static Future<LatLng?> searchAddress(String address) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v1/geocode/search?'
                'text=${Uri.encodeComponent(address)}&'
                'apiKey=$apiKey&limit=1'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'].isNotEmpty) {
          final coords = data['features'][0]['geometry']['coordinates'];
          return LatLng(coords[1], coords[0]); // Geoapify returns [lon, lat]
        }
      }
    } catch (e) {
      print('Geocoding error: $e');
    }
    return null;
  }

  /// Search with multiple results (for autocomplete)
  static Future<List<Map<String, dynamic>>> searchAddresses(String query) async {
    if (query.length < 3) return [];

    try {
      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v1/geocode/search?'
                'text=${Uri.encodeComponent(query)}&'
                'apiKey=$apiKey&limit=5'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['features'].map<Map<String, dynamic>>((feature) {
          final props = feature['properties'];
          final coords = feature['geometry']['coordinates'];
          return {
            'display_name': props['formatted'] ?? props['address_line1'],
            'lat': coords[1],
            'lon': coords[0],
            'type': props['result_type'],
            'city': props['city'],
            'street': props['street'],
            'housenumber': props['housenumber'],
          };
        }).toList();
      }
    } catch (e) {
      print('Search error: $e');
    }
    return [];
  }

  /// Reverse geocoding: Convert coordinates to address
  static Future<String> getAddressFromCoords(LatLng location) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v1/geocode/reverse?'
                'lat=${location.latitude}&lon=${location.longitude}&'
                'apiKey=$apiKey&format=json'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['results'].isNotEmpty) {
          return data['results'][0]['formatted'] ??
              '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
        }
      }
    } catch (e) {
      print('Reverse geocoding error: $e');
    }
    return '${location.latitude.toStringAsFixed(4)}, ${location.longitude.toStringAsFixed(4)}';
  }

  // ============== PLACES API (Nearby places) ==============

  /// Find nearby places (restaurants, cafes, etc.)
  static Future<List<Map<String, dynamic>>> findNearbyPlaces(
      LatLng location, {
        String categories = 'catering.restaurant,catering.cafe,commercial.supermarket',
        int radius = 1000,
        int limit = 10,
      }) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v2/places?'
                'filter=circle:${location.longitude},${location.latitude},$radius&'
                'categories=$categories&'
                'limit=$limit&'
                'apiKey=$apiKey'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        return data['features'].map<Map<String, dynamic>>((feature) {
          final props = feature['properties'];
          final coords = feature['geometry']['coordinates'];
          return {
            'name': props['name'] ?? props['address_line1'],
            'lat': coords[1],
            'lon': coords[0],
            'type': props['categories']?[0] ?? 'place',
            'address': props['formatted'],
            'distance': props['distance'], // Distance in meters
          };
        }).toList();
      }
    } catch (e) {
      print('Places API error: $e');
    }
    return [];
  }

  // ============== ROUTING API (Directions) ==============

  /// Get route between two points
  static Future<Map<String, dynamic>> getRoute(
      LatLng start,
      LatLng end, {
        String mode = 'drive', // walk, bicycle, drive, truck
      }) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v1/routing?'
                'waypoints=${start.longitude},${start.latitude}|${end.longitude},${end.latitude}&'
                'mode=$mode&'
                'apiKey=$apiKey&'
                'geometry=true'),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final properties = data['features'][0]['properties'];
        final geometry = data['features'][0]['geometry'];

        // Parse route geometry
        List<LatLng> routePoints = [];
        if (geometry['type'] == 'LineString') {
          final coords = geometry['coordinates'];
          for (var coord in coords) {
            routePoints.add(LatLng(coord[1], coord[0]));
          }
        }

        return {
          'route': routePoints,
          'distance': properties['distance'], // in meters
          'time': properties['time'], // in seconds
          'distance_formatted': _formatDistance(properties['distance']),
          'time_formatted': _formatDuration(properties['time']),
        };
      }
    } catch (e) {
      print('Routing error: $e');
    }

    // Fallback to simple path
    return {
      'route': _getSimplePath(start, end),
      'distance': 0,
      'time': 0,
      'distance_formatted': '0 km',
      'time_formatted': '0 min',
    };
  }

  // ============== HELPER METHODS ==============

  static String _formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)}km';
  }

  static String _formatDuration(int seconds) {
    if (seconds < 60) return '${seconds}sec';
    if (seconds < 3600) return '${(seconds / 60).round()}min';
    return '${(seconds / 3600).round()}h ${((seconds % 3600) / 60).round()}min';
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
}