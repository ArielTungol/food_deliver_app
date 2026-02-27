import 'package:latlong2/latlong.dart';
import 'route_service.dart';
import 'geoapify_service.dart';

class PathfindingService {
  static Future<List<LatLng>> findPath(LatLng start, LatLng end) async {
    // Try OpenRouteService first for better road following
    try {
      final path = await RouteService.getRoute(start, end);
      if (path.length > 2) {
        return path;
      }
    } catch (e) {
      print('OpenRouteService failed, falling back to Geoapify: $e');
    }

    // Fallback to Geoapify
    final result = await GeoapifyService.getRoute(start, end);
    return result['route'];
  }

  static Future<Map<String, dynamic>> findPathWithDetails(LatLng start, LatLng end) async {
    // Try OpenRouteService first
    try {
      final routeData = await RouteService.getRouteWithDetails(start, end);
      if (routeData['route'].length > 2) {
        return routeData;
      }
    } catch (e) {
      print('OpenRouteService details failed, falling back to Geoapify: $e');
    }

    // Fallback to Geoapify
    return await GeoapifyService.getRoute(start, end);
  }

  static List<LatLng> findSimplePath(LatLng start, LatLng end) {
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