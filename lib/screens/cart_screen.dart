import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../services/geoapify_service.dart';
import '../utils/api_keys.dart';
import 'payment_screen.dart';

class CartScreen extends StatefulWidget {
  const CartScreen({super.key});

  @override
  State<CartScreen> createState() => _CartScreenState();
}

class _CartScreenState extends State<CartScreen> {
  final box = Hive.box("food_delivery");
  List<dynamic> cart = [];

  // Location picking variables
  LatLng? _pickedLocation;
  bool _locationPicked = false;
  String _addressText = "";

  // Search variables
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _searchResults = [];
  bool _isSearching = false;
  bool _showSearchResults = false;

  // Places
  List<Map<String, dynamic>> _nearbyPlaces = [];
  bool _isLoadingPlaces = false;

  final MapController _mapController = MapController();

  @override
  void initState() {
    super.initState();
    setState(() {
      cart = box.get("cart") ?? [];
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void updateQuantity(int index, int change) {
    setState(() {
      int newQuantity = cart[index]["quantity"] + change;
      if (newQuantity <= 0) {
        cart.removeAt(index);
      } else {
        cart[index]["quantity"] = newQuantity;
      }
      box.put("cart", cart);
    });
  }

  double getTotalPrice() {
    double total = 0;
    for (var item in cart) {
      total += item["price"] * item["quantity"];
    }
    return total;
  }

  void _onMapTap(TapPosition tapPosition, LatLng location) {
    _setPickedLocation(location);
  }

  void _setPickedLocation(LatLng location) {
    setState(() {
      _pickedLocation = location;
      _locationPicked = true;
      _showSearchResults = false;
    });

    _mapController.move(location, 16);
    _getAddressFromCoords(location);
    _findNearbyPlaces(location);
  }

  Future<void> _findNearbyPlaces(LatLng location) async {
    setState(() => _isLoadingPlaces = true);

    final places = await GeoapifyService.findNearbyPlaces(location);

    setState(() {
      _nearbyPlaces = places;
      _isLoadingPlaces = false;
    });
  }

  Future<void> _getAddressFromCoords(LatLng location) async {
    setState(() => _addressText = "Loading address...");

    final address = await GeoapifyService.getAddressFromCoords(location);

    setState(() {
      _addressText = address;
    });
  }

  Future<void> _searchLocation(String query) async {
    if (query.length < 3) {
      setState(() {
        _searchResults = [];
        _showSearchResults = false;
      });
      return;
    }

    setState(() {
      _isSearching = true;
      _showSearchResults = true;
    });

    final results = await GeoapifyService.searchAddresses(query);

    setState(() {
      _searchResults = results;
      _isSearching = false;
    });
  }

  void _selectSearchResult(Map<String, dynamic> result) {
    final location = LatLng(result['lat'], result['lon']);
    _setPickedLocation(location);
    setState(() {
      _searchController.text = result['display_name'];
      _showSearchResults = false;
    });
  }

  void _zoomIn() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom + 1,
    );
  }

  void _zoomOut() {
    _mapController.move(
      _mapController.camera.center,
      _mapController.camera.zoom - 1,
    );
  }

  IconData _getPlaceIcon(String type) {
    if (type.contains('restaurant')) return Icons.restaurant;
    if (type.contains('cafe')) return Icons.local_cafe;
    if (type.contains('supermarket')) return Icons.shopping_cart;
    if (type.contains('hotel')) return Icons.hotel;
    return Icons.place;
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        middle: Text(
          'Your Cart',
          style: TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.activeOrange.withValues(alpha: 0.05),
              const Color(0xFFF2F2F7),
            ],
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              Expanded(
                child: cart.isEmpty
                    ? Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(30),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                              blurRadius: 20,
                              offset: const Offset(0, 10),
                            ),
                          ],
                        ),
                        child: const Icon(
                          CupertinoIcons.cart,
                          size: 50,
                          color: CupertinoColors.activeOrange,
                        ),
                      ),
                      const SizedBox(height: 20),
                      const Text(
                        'Your cart is empty',
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Add items from the menu',
                        style: TextStyle(
                          fontSize: 15,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                )
                    : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: cart.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: CupertinoColors.systemGrey5,
                          width: 1,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Container(
                              width: 50,
                              height: 50,
                              decoration: BoxDecoration(
                                color: CupertinoColors.activeOrange.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Icon(
                                CupertinoIcons.cart,
                                color: CupertinoColors.activeOrange,
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    cart[index]["name"],
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                      color: CupertinoColors.black,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '\$${cart[index]["price"].toStringAsFixed(2)} each',
                                    style: TextStyle(
                                      fontSize: 12,
                                      color: CupertinoColors.systemGrey,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
                              children: [
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Icon(CupertinoIcons.minus_circled, size: 24),
                                  onPressed: () => updateQuantity(index, -1),
                                ),
                                Container(
                                  width: 30,
                                  alignment: Alignment.center,
                                  child: Text(
                                    cart[index]["quantity"].toString(),
                                    style: const TextStyle(
                                      fontSize: 16,
                                      color: CupertinoColors.black,
                                    ),
                                  ),
                                ),
                                CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Icon(CupertinoIcons.plus_circled, size: 24),
                                  onPressed: () => updateQuantity(index, 1),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (cart.isNotEmpty)
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    boxShadow: [
                      BoxShadow(
                        color: CupertinoColors.systemGrey.withValues(alpha: 0.2),
                        blurRadius: 10,
                        offset: const Offset(0, -5),
                      ),
                    ],
                  ),
                  child: Column(
                    children: [
                      // INTERACTIVE MAP SECTION
                      Container(
                        margin: const EdgeInsets.only(bottom: 16),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: _locationPicked ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
                            width: _locationPicked ? 2 : 1,
                          ),
                        ),
                        child: Column(
                          children: [
                            // Search Bar
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: CupertinoTextField(
                                      controller: _searchController,
                                      placeholder: 'Search for places, restaurants, landmarks...',
                                      placeholderStyle: TextStyle(
                                        color: CupertinoColors.systemGrey.withValues(alpha: 0.5),
                                        fontSize: 14,
                                      ),
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemGrey6,
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      onChanged: _searchLocation,
                                      prefix: const Padding(
                                        padding: EdgeInsets.only(left: 8),
                                        child: Icon(
                                          CupertinoIcons.search,
                                          size: 18,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                      ),
                                      suffix: _searchController.text.isNotEmpty
                                          ? CupertinoButton(
                                        padding: EdgeInsets.zero,
                                        child: const Icon(
                                          CupertinoIcons.clear_circled,
                                          size: 18,
                                          color: CupertinoColors.systemGrey,
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _searchController.clear();
                                            _searchResults = [];
                                            _showSearchResults = false;
                                          });
                                        },
                                      )
                                          : null,
                                    ),
                                  ),
                                ],
                              ),
                            ),

                            // Search Results
                            if (_showSearchResults && _searchResults.isNotEmpty)
                              Container(
                                constraints: const BoxConstraints(maxHeight: 200),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.white,
                                  borderRadius: BorderRadius.circular(10),
                                  border: Border.all(
                                    color: CupertinoColors.systemGrey5,
                                  ),
                                ),
                                child: ListView.builder(
                                  shrinkWrap: true,
                                  itemCount: _searchResults.length,
                                  itemBuilder: (context, index) {
                                    final result = _searchResults[index];
                                    return GestureDetector(
                                      onTap: () => _selectSearchResult(result),
                                      child: Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          border: Border(
                                            bottom: BorderSide(
                                              color: CupertinoColors.systemGrey5,
                                              width: index < _searchResults.length - 1 ? 1 : 0,
                                            ),
                                          ),
                                        ),
                                        child: Row(
                                          children: [
                                            const Icon(
                                              CupertinoIcons.location,
                                              size: 16,
                                              color: CupertinoColors.activeOrange,
                                            ),
                                            const SizedBox(width: 8),
                                            Expanded(
                                              child: Column(
                                                crossAxisAlignment: CrossAxisAlignment.start,
                                                children: [
                                                  Text(
                                                    result['display_name'],
                                                    style: const TextStyle(
                                                      fontSize: 13,
                                                      color: CupertinoColors.black,
                                                    ),
                                                    maxLines: 2,
                                                    overflow: TextOverflow.ellipsis,
                                                  ),
                                                ],
                                              ),
                                            ),
                                          ],
                                        ),
                                      ),
                                    );
                                  },
                                ),
                              ),

                            if (_isSearching)
                              const Padding(
                                padding: EdgeInsets.all(12),
                                child: CupertinoActivityIndicator(),
                              ),

                            // Map Controls
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              child: Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  Row(
                                    children: [
                                      CupertinoButton(
                                        padding: const EdgeInsets.all(8),
                                        onPressed: _zoomIn,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemGrey6,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.plus,
                                            size: 16,
                                            color: CupertinoColors.activeOrange,
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                      CupertinoButton(
                                        padding: const EdgeInsets.all(8),
                                        onPressed: _zoomOut,
                                        child: Container(
                                          padding: const EdgeInsets.all(5),
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemGrey6,
                                            borderRadius: BorderRadius.circular(8),
                                          ),
                                          child: const Icon(
                                            CupertinoIcons.minus,
                                            size: 16,
                                            color: CupertinoColors.activeOrange,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // Map - UPDATED with FlutterMap v6+ syntax
                            Container(
                              height: 250,
                              decoration: BoxDecoration(
                                borderRadius: const BorderRadius.vertical(
                                  bottom: Radius.circular(14),
                                ),
                                border: Border(
                                  top: BorderSide(
                                    color: CupertinoColors.systemGrey5,
                                    width: 1,
                                  ),
                                ),
                              ),
                              child: Stack(
                                children: [
                                  FlutterMap(
                                    mapController: _mapController,
                                    options: MapOptions(
                                      initialCenter: _pickedLocation ?? const LatLng(14.5995, 120.9842),
                                      initialZoom: 16,
                                      interactionOptions: const InteractionOptions(
                                        flags: InteractiveFlag.all,
                                      ),
                                      onTap: _onMapTap,
                                    ),
                                    children: [
                                      TileLayer(
                                        urlTemplate: 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${ApiKeys.geoapifyKey}',
                                        userAgentPackageName: 'com.example.food_delivery',
                                      ),
                                      if (_pickedLocation != null)
                                        MarkerLayer(
                                          markers: [
                                            Marker(
                                              point: _pickedLocation!,
                                              width: 40,
                                              height: 40,
                                              child: const Icon(
                                                Icons.location_pin,
                                                color: CupertinoColors.activeOrange,
                                                size: 40,
                                              ),
                                            ),
                                          ],
                                        ),
                                      if (_nearbyPlaces.isNotEmpty)
                                        MarkerLayer(
                                          markers: _nearbyPlaces.map((place) {
                                            return Marker(
                                              point: LatLng(place['lat'], place['lon']),
                                              width: 30,
                                              height: 30,
                                              child: Icon(
                                                _getPlaceIcon(place['type']),
                                                color: CupertinoColors.activeOrange,
                                                size: 24,
                                              ),
                                            );
                                          }).toList(),
                                        ),
                                    ],
                                  ),
                                  if (_isLoadingPlaces)
                                    const Positioned(
                                      top: 10,
                                      right: 10,
                                      child: CupertinoActivityIndicator(),
                                    ),
                                ],
                              ),
                            ),

                            // Location Status
                            Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        _locationPicked ? CupertinoIcons.check_mark_circled_solid : CupertinoIcons.location,
                                        color: _locationPicked ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
                                        size: 20,
                                      ),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Column(
                                          crossAxisAlignment: CrossAxisAlignment.start,
                                          children: [
                                            Text(
                                              _locationPicked ? 'Delivery Location Set' : 'Tap on map to set location',
                                              style: TextStyle(
                                                fontSize: 14,
                                                fontWeight: FontWeight.w600,
                                                color: _locationPicked ? CupertinoColors.activeGreen : CupertinoColors.systemGrey,
                                              ),
                                            ),
                                            if (_locationPicked) ...[
                                              const SizedBox(height: 4),
                                              Text(
                                                _addressText,
                                                style: const TextStyle(
                                                  fontSize: 12,
                                                  color: CupertinoColors.black,
                                                ),
                                                maxLines: 2,
                                                overflow: TextOverflow.ellipsis,
                                              ),
                                            ],
                                          ],
                                        ),
                                      ),
                                      if (!_locationPicked)
                                        Container(
                                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                          decoration: BoxDecoration(
                                            color: CupertinoColors.systemOrange.withValues(alpha: 0.1),
                                            borderRadius: BorderRadius.circular(12),
                                          ),
                                          child: const Text(
                                            'Required',
                                            style: TextStyle(
                                              fontSize: 10,
                                              color: CupertinoColors.systemOrange,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                    ],
                                  ),
                                  if (_locationPicked && _nearbyPlaces.isNotEmpty) ...[
                                    const SizedBox(height: 8),
                                    Container(
                                      padding: const EdgeInsets.all(8),
                                      decoration: BoxDecoration(
                                        color: CupertinoColors.systemGrey6,
                                        borderRadius: BorderRadius.circular(8),
                                      ),
                                      child: Row(
                                        children: [
                                          const Icon(
                                            CupertinoIcons.star_fill,
                                            size: 14,
                                            color: CupertinoColors.activeOrange,
                                          ),
                                          const SizedBox(width: 4),
                                          Expanded(
                                            child: Text(
                                              'Found ${_nearbyPlaces.length} nearby places',
                                              style: const TextStyle(
                                                fontSize: 11,
                                                color: CupertinoColors.black,
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
                          ],
                        ),
                      ),

                      // TOTAL
                      Container(
                        margin: const EdgeInsets.only(bottom: 12),
                        padding: const EdgeInsets.symmetric(vertical: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const Text(
                              'TOTAL:',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.black,
                              ),
                            ),
                            Text(
                              '\$${getTotalPrice().toStringAsFixed(2)}',
                              style: const TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.activeOrange,
                              ),
                            ),
                          ],
                        ),
                      ),

                      // CHECKOUT BUTTON
                      Container(
                        width: double.infinity,
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: _locationPicked
                                ? [CupertinoColors.activeOrange, const Color(0xFFFF9F0A)]
                                : [CupertinoColors.systemGrey, CupertinoColors.systemGrey],
                          ),
                          borderRadius: BorderRadius.circular(14),
                          boxShadow: _locationPicked
                              ? [
                            BoxShadow(
                              color: CupertinoColors.activeOrange.withValues(alpha: 0.3),
                              blurRadius: 8,
                              offset: const Offset(0, 2),
                            ),
                          ]
                              : null,
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 16),
                          child: Text(
                            _locationPicked ? 'PROCEED TO CHECKOUT' : 'SET LOCATION FIRST',
                            style: const TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          onPressed: _locationPicked
                              ? () {
                            print("========== CART SCREEN ==========");
                            print("PICKED LOCATION: ${_pickedLocation!.latitude}, ${_pickedLocation!.longitude}");
                            print("ADDRESS: $_addressText");
                            print("=================================");

                            Navigator.push(
                              context,
                              CupertinoPageRoute(
                                builder: (context) => PaymentScreen(
                                  totalAmount: getTotalPrice(),
                                  address: _addressText,
                                  items: List.from(cart),
                                  deliveryLat: _pickedLocation!.latitude,
                                  deliveryLng: _pickedLocation!.longitude,
                                ),
                              ),
                            );
                          }
                              : null,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}