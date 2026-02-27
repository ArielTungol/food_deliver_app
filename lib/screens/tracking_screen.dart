import 'dart:async';
import 'dart:math';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:hive/hive.dart';

import '../models/order.dart';
import '../services/route_service.dart';
import '../services/geoapify_service.dart';
import '../utils/api_keys.dart';
import 'home_screen.dart';

class TrackingScreen extends StatefulWidget {
  final String orderId;

  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> with SingleTickerProviderStateMixin {
  final MapController _mapController = MapController();
  LatLng _riderLocation = const LatLng(14.5895, 120.9742); // Restaurant location
  late LatLng _destination;
  List<LatLng> _path = [];
  int _currentPathIndex = 0;
  Timer? _movementTimer;
  OrderStatus _currentStatus = OrderStatus.confirmed;
  final ordersBox = Hive.box<Order>("orders");

  // Tracking variables
  int _totalDistance = 0;
  int _estimatedDuration = 0;
  int _remainingDistance = 0;
  int _remainingTime = 0;
  bool _isLoading = true;
  String _deliveryAddress = "";
  String _errorMessage = "";
  String _riderName = "John Dela Cruz";
  String _riderPhone = "0917-123-4567";
  double _riderRating = 4.8;
  List<LatLng> _trafficPoints = [];
  bool _isHeavyTraffic = false;
  double _progress = 0.0;

  late AnimationController _bounceController;
  bool _showArrivalPopup = false;

  // Speed multiplier - INCREASE THIS TO MAKE DELIVERY FASTER
  final double _speedMultiplier = 40.0; // 3x faster than original

  @override
  void initState() {
    super.initState();
    _bounceController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    )..repeat(reverse: true);
    _loadOrder();
  }

  Future<void> _loadOrder() async {
    setState(() {
      _isLoading = true;
      _errorMessage = "";
    });

    print("========== TRACKING SCREEN ==========");
    print("Loading order ID: ${widget.orderId}");

    try {
      final order = ordersBox.get(widget.orderId);

      if (order != null) {
        print("✅ ORDER FOUND");
        print("   Location: ${order.deliveryLat}, ${order.deliveryLng}");
        print("   Address: ${order.deliveryAddress}");
        print("   Status: ${order.status}");

        _destination = LatLng(order.deliveryLat, order.deliveryLng);
        _deliveryAddress = order.deliveryAddress;
        _currentStatus = order.status;

        Future.delayed(const Duration(milliseconds: 300), () {
          _mapController.move(
            LatLng(
              (_riderLocation.latitude + _destination.latitude) / 2,
              (_riderLocation.longitude + _destination.longitude) / 2,
            ),
            12,
          );
        });

        await _calculateRealisticRoute();
      } else {
        print("❌ ORDER NOT FOUND");
        setState(() {
          _errorMessage = "Order not found. Please check your orders.";
          _destination = const LatLng(14.5995, 120.9842);
        });
      }
    } catch (e) {
      print("❌ ERROR loading order: $e");
      setState(() {
        _errorMessage = "Error loading order: $e";
        _destination = const LatLng(14.5995, 120.9842);
      });
    }

    setState(() {
      _isLoading = false;
    });

    _startStatusSimulation();
  }

  Future<void> _calculateRealisticRoute() async {
    try {
      final routeData = await RouteService.getRouteWithDetails(_riderLocation, _destination);

      setState(() {
        _path = routeData['route'];
        _totalDistance = routeData['distance'].round();
        _estimatedDuration = routeData['duration'].round();
        _remainingDistance = _totalDistance;
        _remainingTime = _estimatedDuration;
        _generateTrafficPoints();
      });

      print("✅ ROUTE CALCULATED");
      print("   Distance: ${_totalDistance}m");
      print("   Duration: ${_estimatedDuration}s");
      print("   Path points: ${_path.length}");
    } catch (e) {
      print("❌ ERROR calculating route: $e");
      _path = _generateRoadLikePath(_riderLocation, _destination);
      setState(() {
        _totalDistance = 5000;
        _estimatedDuration = 900;
        _remainingDistance = _totalDistance;
        _remainingTime = _estimatedDuration;
        _generateTrafficPoints();
      });
    }
  }

  List<LatLng> _generateRoadLikePath(LatLng start, LatLng end) {
    final path = <LatLng>[start];
    double latDiff = end.latitude - start.latitude;
    double lngDiff = end.longitude - start.longitude;
    int segments = 40;

    for (int i = 1; i <= segments; i++) {
      double fraction = i / segments;
      double lat = start.latitude + (latDiff * fraction);
      double lng = start.longitude + (lngDiff * fraction);

      double curve1 = 0.002 * sin(fraction * 4 * pi);
      double curve2 = 0.0015 * cos(fraction * 3 * pi + 0.5);

      lat += curve1 + curve2;
      lng += curve2;

      path.add(LatLng(lat, lng));
    }
    return path;
  }

  void _generateTrafficPoints() {
    _trafficPoints.clear();
    if (_path.isEmpty) return;

    Random random = Random();
    int trafficCount = random.nextInt(5) + 3;

    for (int i = 0; i < trafficCount; i++) {
      int index = random.nextInt(_path.length - 10) + 5;
      _trafficPoints.add(_path[index]);
    }
  }

  void _startStatusSimulation() {
    // FASTER: Reduced waiting times
    Timer(const Duration(seconds: 2), () async { // Was 5 seconds
      if (_currentStatus == OrderStatus.confirmed) {
        setState(() => _currentStatus = OrderStatus.preparing);

        final order = ordersBox.get(widget.orderId);
        if (order != null) {
          order.status = OrderStatus.preparing;
          await ordersBox.put(order.id, order);
        }
      }
    });

    Timer(const Duration(seconds: 6), () async { // Was 15 seconds
      if (_currentStatus == OrderStatus.preparing) {
        setState(() => _currentStatus = OrderStatus.onTheWay);
        _startRealisticMovement();

        final order = ordersBox.get(widget.orderId);
        if (order != null) {
          order.status = OrderStatus.onTheWay;
          await ordersBox.put(order.id, order);
        }
      }
    });
  }

  void _startRealisticMovement() {
    if (_path.isEmpty) return;

    // FASTER: Reduced interval based on speed multiplier
    const baseInterval = Duration(milliseconds: 600);
    // Calculate faster interval
    int fasterIntervalMs = (600 / _speedMultiplier).round();
    final movementInterval = Duration(milliseconds: fasterIntervalMs);

    int steps = _path.length;
    int currentStep = 0;

    print("🚀 Moving at ${_speedMultiplier}x speed");
    print("   Interval: ${movementInterval.inMilliseconds}ms");

    _movementTimer = Timer.periodic(movementInterval, (timer) {
      if (currentStep < steps - 1) {
        bool nextSegmentHasTraffic = false;
        if (currentStep + 5 < steps) {
          for (var trafficPoint in _trafficPoints) {
            double latDiff = (_path[currentStep + 5].latitude - trafficPoint.latitude).abs();
            double lngDiff = (_path[currentStep + 5].longitude - trafficPoint.longitude).abs();

            if (latDiff < 0.001 && lngDiff < 0.001) {
              nextSegmentHasTraffic = true;
              break;
            }
          }
        }

        // REDUCED traffic probability for faster delivery
        if (nextSegmentHasTraffic && Random().nextDouble() > 0.9) { // Was 0.7
          setState(() {
            _isHeavyTraffic = true;
          });
          return;
        }

        setState(() {
          _isHeavyTraffic = false;
          currentStep++;
          _currentPathIndex = currentStep;
          _riderLocation = _path[currentStep];

          _progress = currentStep / (steps - 1);
          _remainingDistance = _totalDistance - (_totalDistance * _progress).round();

          // FASTER: Calculate remaining time based on speed multiplier
          _remainingTime = ((_estimatedDuration - (_estimatedDuration * _progress)) / _speedMultiplier).round();

          if (currentStep > steps * 0.7 || currentStep % 5 == 0) {
            _mapController.move(_riderLocation, 15);
          }
        });

        // REDUCED traffic notifications
        if (_isHeavyTraffic && currentStep % 5 == 0) { // Was % 3
          _showTrafficNotification();
        }
      } else {
        timer.cancel();
        _handleArrival();
      }
    });
  }

  void _handleArrival() {
    // Show arrival popup
    setState(() {
      _showArrivalPopup = true;
      _remainingDistance = 0;
      _remainingTime = 0;
    });

    // Auto-dismiss popup faster
    Future.delayed(const Duration(seconds: 2), () { // Was 4 seconds
      if (mounted) {
        setState(() {
          _showArrivalPopup = false;
        });
      }
    });

    // Update status to delivered faster
    Future.delayed(const Duration(seconds: 1), () async { // Was 2 seconds
      setState(() => _currentStatus = OrderStatus.delivered);

      final order = ordersBox.get(widget.orderId);
      if (order != null) {
        order.status = OrderStatus.delivered;
        await ordersBox.put(order.id, order);

        // Show delivery complete dialog after a short delay
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) {
            _showDeliveryCompleteDialog();
          }
        });
      }
    });
  }

  void _showTrafficNotification() {
    if (!mounted) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            Icon(Icons.traffic, color: CupertinoColors.white, size: 20),
            const SizedBox(width: 8),
            const Expanded(child: Text('Light traffic ahead, minor delay')),
          ],
        ),
        backgroundColor: CupertinoColors.activeOrange,
        duration: const Duration(seconds: 1), // Was 2 seconds
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
    );
  }

  void _showDeliveryCompleteDialog() {
    showCupertinoDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => CupertinoAlertDialog(
        title: Container(
          padding: const EdgeInsets.all(12),
          child: const Icon(
            Icons.check_circle,
            color: CupertinoColors.activeGreen,
            size: 60,
          ),
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Order Delivered!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
              ),
            ),
            SizedBox(height: 12),
            Text(
              'Your order has arrived. Enjoy your meal!',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 14),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    _bounceController.dispose();
    super.dispose();
  }

  String getStatusText() {
    switch (_currentStatus) {
      case OrderStatus.confirmed:
        return 'Order Confirmed';
      case OrderStatus.preparing:
        return 'Preparing your order';
      case OrderStatus.onTheWay:
        return 'Rider is on the way';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }

  String getStatusDescription() {
    switch (_currentStatus) {
      case OrderStatus.confirmed:
        return 'Restaurant has confirmed your order';
      case OrderStatus.preparing:
        return 'Restaurant is preparing your food';
      case OrderStatus.onTheWay:
        return 'Your rider is heading to your location';
      case OrderStatus.delivered:
        return 'Order has been delivered';
    }
  }

  IconData getStatusIcon() {
    switch (_currentStatus) {
      case OrderStatus.confirmed:
        return CupertinoIcons.check_mark_circled_solid;
      case OrderStatus.preparing:
        return CupertinoIcons.clock_solid;
      case OrderStatus.onTheWay:
        return Icons.delivery_dining;
      case OrderStatus.delivered:
        return Icons.check_circle;
    }
  }

  Color getStatusColor() {
    switch (_currentStatus) {
      case OrderStatus.confirmed:
        return CupertinoColors.activeBlue;
      case OrderStatus.preparing:
        return CupertinoColors.activeOrange;
      case OrderStatus.onTheWay:
        return CupertinoColors.activeOrange;
      case OrderStatus.delivered:
        return CupertinoColors.systemGreen;
    }
  }

  String formatDuration(int seconds) {
    if (seconds < 60) return '${seconds} sec';
    if (seconds < 3600) {
      int minutes = (seconds / 60).round();
      return '$minutes min';
    }
    int hours = (seconds / 3600).round();
    int minutes = ((seconds % 3600) / 60).round();
    return '$hours h $minutes min';
  }

  String formatDistance(int meters) {
    if (meters < 1000) return '${meters}m';
    return '${(meters / 1000).toStringAsFixed(1)} km';
  }

  void _showContactDialog() {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Contact Rider'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: CupertinoColors.systemGrey6,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(CupertinoIcons.phone, size: 16),
                  const SizedBox(width: 8),
                  Text(_riderPhone),
                ],
              ),
            ),
          ],
        ),
        actions: [
          CupertinoDialogAction(
            child: const Text('Call'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Message'),
            onPressed: () {
              Navigator.pop(context);
            },
          ),
          CupertinoDialogAction(
            child: const Text('Cancel'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        middle: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.w600)),
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: Stack(
        children: [
          _isLoading
              ? const Center(child: CupertinoActivityIndicator())
              : Column(
            children: [
              // Status Card
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  border: Border(
                    bottom: BorderSide(
                      color: CupertinoColors.systemGrey5.withValues(alpha: 0.5),
                      width: 1,
                    ),
                  ),
                ),
                child: Column(
                  children: [
                    Row(
                      children: [
                        AnimatedContainer(
                          duration: const Duration(milliseconds: 300),
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: getStatusColor().withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            getStatusIcon(),
                            color: getStatusColor(),
                            size: 24,
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                getStatusText(),
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                getStatusDescription(),
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),

                    if (_currentStatus == OrderStatus.onTheWay) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeOrange.withValues(alpha: 0.2),
                                shape: BoxShape.circle,
                              ),
                              child: Center(
                                child: Text(
                                  _riderName.split(' ').map((e) => e[0]).join(''),
                                  style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold,
                                    color: CupertinoColors.activeOrange,
                                  ),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        _riderName,
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w600,
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      Container(
                                        padding: const EdgeInsets.symmetric(
                                          horizontal: 6,
                                          vertical: 2,
                                        ),
                                        decoration: BoxDecoration(
                                          color: CupertinoColors.systemYellow.withValues(alpha: 0.2),
                                          borderRadius: BorderRadius.circular(12),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              Icons.star,
                                              size: 12,
                                              color: CupertinoColors.systemYellow,
                                            ),
                                            const SizedBox(width: 2),
                                            Text(
                                              _riderRating.toString(),
                                              style: const TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.w600,
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(
                                        CupertinoIcons.phone,
                                        size: 12,
                                        color: CupertinoColors.systemGrey,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        _riderPhone,
                                        style: TextStyle(
                                          fontSize: 12,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeOrange,
                                shape: BoxShape.circle,
                              ),
                              child: CupertinoButton(
                                padding: const EdgeInsets.all(10),
                                onPressed: _showContactDialog,
                                child: const Icon(
                                  CupertinoIcons.chat_bubble_text_fill,
                                  color: CupertinoColors.white,
                                  size: 18,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_currentStatus == OrderStatus.onTheWay && _path.isNotEmpty) ...[
                      const SizedBox(height: 16),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              if (_isHeavyTraffic)
                                Container(
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 6,
                                    vertical: 2,
                                  ),
                                  decoration: BoxDecoration(
                                    color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Row(
                                    children: [
                                      const Icon(
                                        Icons.traffic,
                                        size: 12,
                                        color: CupertinoColors.destructiveRed,
                                      ),
                                      const SizedBox(width: 4),
                                      Text(
                                        'Light Traffic',
                                        style: TextStyle(
                                          fontSize: 10,
                                          color: CupertinoColors.destructiveRed,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Text(
                                '${(_progress * 100).toInt()}%',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.activeOrange,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          ClipRRect(
                            borderRadius: BorderRadius.circular(4),
                            child: LinearProgressIndicator(
                              value: _progress,
                              backgroundColor: CupertinoColors.systemGrey5,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                _isHeavyTraffic
                                    ? CupertinoColors.destructiveRed
                                    : CupertinoColors.activeOrange,
                              ),
                              minHeight: 6,
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_currentStatus == OrderStatus.onTheWay) ...[
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    CupertinoIcons.time,
                                    size: 20,
                                    color: CupertinoColors.activeOrange,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'ETA',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                  Text(
                                    formatDuration(_remainingTime),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Container(
                              padding: const EdgeInsets.all(12),
                              decoration: BoxDecoration(
                                color: CupertinoColors.systemGrey6,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                children: [
                                  const Icon(
                                    CupertinoIcons.map,
                                    size: 20,
                                    color: CupertinoColors.activeOrange,
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Distance',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                  Text(
                                    formatDistance(_remainingDistance),
                                    style: const TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],

                    if (_deliveryAddress.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.systemGrey6,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.location_fill,
                              size: 16,
                              color: CupertinoColors.activeOrange,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _deliveryAddress,
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: CupertinoColors.black,
                                ),
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],

                    if (_errorMessage.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CupertinoColors.destructiveRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.exclamationmark_triangle,
                              size: 14,
                              color: CupertinoColors.destructiveRed,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _errorMessage,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.destructiveRed,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),

              // Map
              Expanded(
                child: Stack(
                  children: [
                    FlutterMap(
                      mapController: _mapController,
                      options: MapOptions(
                        initialCenter: _destination,
                        initialZoom: 14,
                        interactionOptions: const InteractionOptions(
                          flags: InteractiveFlag.all,
                        ),
                      ),
                      children: [
                        TileLayer(
                          urlTemplate: 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${ApiKeys.geoapifyKey}',
                          userAgentPackageName: 'com.example.food_delivery',
                        ),

                        if (_path.isNotEmpty)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _path,
                                color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
                                strokeWidth: 4,
                              ),
                            ],
                          ),

                        if (_path.isNotEmpty && _currentPathIndex > 0)
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: _path.sublist(0, _currentPathIndex + 1),
                                color: _currentStatus == OrderStatus.delivered
                                    ? CupertinoColors.systemGreen
                                    : CupertinoColors.activeOrange,
                                strokeWidth: 6,
                              ),
                            ],
                          ),

                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _riderLocation,
                              width: 60,
                              height: 60,
                              child: AnimatedBuilder(
                                animation: _bounceController,
                                builder: (context, child) {
                                  return Transform.translate(
                                    offset: Offset(0, -5 * _bounceController.value),
                                    child: Container(
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.white,
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: _currentStatus == OrderStatus.delivered
                                              ? CupertinoColors.systemGreen
                                              : CupertinoColors.activeOrange,
                                          width: 3,
                                        ),
                                        boxShadow: [
                                          BoxShadow(
                                            color: (_currentStatus == OrderStatus.delivered
                                                ? CupertinoColors.systemGreen
                                                : CupertinoColors.activeOrange).withValues(alpha: 0.3),
                                            blurRadius: 12,
                                            spreadRadius: 2,
                                          ),
                                        ],
                                      ),
                                      child: Center(
                                        child: Icon(
                                          _currentStatus == OrderStatus.delivered
                                              ? Icons.check_circle
                                              : Icons.delivery_dining,
                                          color: _currentStatus == OrderStatus.delivered
                                              ? CupertinoColors.systemGreen
                                              : CupertinoColors.activeOrange,
                                          size: 30,
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                            ),

                            Marker(
                              point: _destination,
                              width: 70,
                              height: 80,
                              child: Column(
                                children: [
                                  Container(
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 12,
                                      vertical: 6,
                                    ),
                                    decoration: BoxDecoration(
                                      color: CupertinoColors.white,
                                      borderRadius: BorderRadius.circular(20),
                                      boxShadow: [
                                        BoxShadow(
                                          color: CupertinoColors.systemGrey.withValues(alpha: 0.3),
                                          blurRadius: 4,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: const Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Icon(
                                          Icons.location_on,
                                          size: 14,
                                          color: CupertinoColors.systemGreen,
                                        ),
                                        SizedBox(width: 4),
                                        Text(
                                          'You',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: CupertinoColors.systemGreen,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const Icon(
                                    Icons.location_pin,
                                    color: CupertinoColors.systemGreen,
                                    size: 40,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    // Zoom Controls
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
                          const SizedBox(height: 8),
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
                            child: CupertinoButton(
                              padding: const EdgeInsets.all(12),
                              onPressed: () {
                                _mapController.move(
                                  _riderLocation,
                                  16,
                                );
                              },
                              child: const Icon(
                                Icons.my_location,
                                size: 20,
                                color: CupertinoColors.activeOrange,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

              // Back to Menu Button
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  width: double.infinity,
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      colors: [
                        CupertinoColors.activeOrange,
                        Color(0xFFFF9F0A),
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.activeOrange.withValues(alpha: 0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CupertinoButton(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: const Text(
                      'Back to Menu',
                      style: TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: () {
                      Navigator.pushAndRemoveUntil(
                        context,
                        CupertinoPageRoute(builder: (context) => const HomeScreen()),
                            (route) => false,
                      );
                    },
                  ),
                ),
              ),
            ],
          ),

          // Arrival Popup
          if (_showArrivalPopup)
            Positioned(
              top: 100,
              left: 20,
              right: 20,
              child: TweenAnimationBuilder(
                duration: const Duration(milliseconds: 300),
                tween: Tween<double>(begin: 0, end: 1),
                curve: Curves.easeOutBack,
                builder: (context, double value, child) {
                  return Transform.scale(
                    scale: value,
                    child: Material(
                      color: Colors.transparent,
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(20),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemGreen.withValues(alpha: 0.4),
                              blurRadius: 20,
                              spreadRadius: 2,
                            ),
                          ],
                          border: Border.all(
                            color: CupertinoColors.systemGreen,
                            width: 2,
                          ),
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: CupertinoColors.systemGreen,
                              size: 50,
                            ),
                            const SizedBox(height: 12),
                            const Text(
                              'Rider has arrived!',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.systemGreen,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              '$_riderName is at your location',
                              style: const TextStyle(
                                fontSize: 14,
                                color: CupertinoColors.black,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }
}