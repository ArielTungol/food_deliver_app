import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

class RoutePreviewWidget extends StatefulWidget {
  final LatLng start;
  final LatLng end;
  final List<LatLng> route;
  final bool isLoading;

  const RoutePreviewWidget({
    super.key,
    required this.start,
    required this.end,
    required this.route,
    this.isLoading = false,
  });

  @override
  State<RoutePreviewWidget> createState() => _RoutePreviewWidgetState();
}

class _RoutePreviewWidgetState extends State<RoutePreviewWidget> {
  late final MapController _mapController;

  @override
  void initState() {
    super.initState();
    _mapController = MapController();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _centerMapOnRoute();
    });
  }

  void _centerMapOnRoute() {
    if (widget.route.isNotEmpty) {
      double minLat = widget.route.map((p) => p.latitude).reduce((a, b) => a < b ? a : b);
      double maxLat = widget.route.map((p) => p.latitude).reduce((a, b) => a > b ? a : b);
      double minLng = widget.route.map((p) => p.longitude).reduce((a, b) => a < b ? a : b);
      double maxLng = widget.route.map((p) => p.longitude).reduce((a, b) => a > b ? a : b);

      _mapController.move(
        LatLng((minLat + maxLat) / 2, (minLng + maxLng) / 2),
        12,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.isLoading) {
      return const Center(child: CupertinoActivityIndicator());
    }

    return Stack(
      children: [
        FlutterMap(
          mapController: _mapController,
          options: MapOptions(
            // FIXED: Use new parameter names for FlutterMap v6+
            initialCenter: widget.start,
            initialZoom: 13,
            interactionOptions: const InteractionOptions(
              flags: InteractiveFlag.all,
            ),
          ),
          children: [
            TileLayer(
              urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
              userAgentPackageName: 'com.example.food_delivery',
            ),
            if (widget.route.isNotEmpty)
              PolylineLayer(
                polylines: [
                  Polyline(
                    points: widget.route,
                    color: CupertinoColors.activeOrange,
                    strokeWidth: 4,
                  ),
                ],
              ),
            MarkerLayer(
              markers: [
                Marker(
                  point: widget.start,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.delivery_dining,
                    color: CupertinoColors.activeOrange,
                    size: 30,
                  ),
                ),
                Marker(
                  point: widget.end,
                  width: 40,
                  height: 40,
                  child: const Icon(
                    Icons.location_on,
                    color: CupertinoColors.systemGreen,
                    size: 30,
                  ),
                ),
              ],
            ),
          ],
        ),
        Positioned(
          bottom: 20,
          right: 16,
          child: Column(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  borderRadius: BorderRadius.circular(12),
                  boxShadow: [
                    BoxShadow(
                      color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                      blurRadius: 8,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: Column(
                  children: [
                    CupertinoButton(
                      padding: const EdgeInsets.all(12),
                      onPressed: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom + 1,
                        );
                      },
                      child: const Icon(
                        CupertinoIcons.plus,
                        size: 20,
                        color: CupertinoColors.activeOrange,
                      ),
                    ),
                    Container(
                      height: 1,
                      width: 30,
                      color: CupertinoColors.systemGrey5,
                    ),
                    CupertinoButton(
                      padding: const EdgeInsets.all(12),
                      onPressed: () {
                        _mapController.move(
                          _mapController.camera.center,
                          _mapController.camera.zoom - 1,
                        );
                      },
                      child: const Icon(
                        CupertinoIcons.minus,
                        size: 20,
                        color: CupertinoColors.activeOrange,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}