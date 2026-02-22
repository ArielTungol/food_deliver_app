import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/adapters.dart';
import 'package:local_auth/local_auth.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'package:http/http.dart' as http;
import 'dart:async';
import 'dart:math';
import 'dart:convert';
import 'dart:io' show Platform;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

// ============== API KEYS ==============
class ApiKeys {
  static const String geoapifyKey = '49f1d6111973465f99d26c27dc84cebb';
  static const String orsApiKey = 'eyJvcmciOiI1YjNjZTM1OTc4NTExMTAwMDFjZjYyNDgiLCJpZCI6IjBhMmZlNzZhMjMzMDQyY2JhZmI3ZDBhMjRjMTUyMWM0IiwiaCI6Im11cm11cjY0In0=';
}

// ============== GEOAPIFY SERVICE ==============
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
                'apiKey=$apiKey&limit=1'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        if (data['features'].isNotEmpty) {
          final coords = data['features'][0]['geometry']['coordinates'];
          return LatLng(coords[1], coords[0]);
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
                'apiKey=$apiKey&limit=5'
        ),
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
                'apiKey=$apiKey&format=json'
        ),
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
                'apiKey=$apiKey'
        ),
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
            'distance': props['distance'],
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
        String mode = 'drive',
      }) async {
    try {
      final response = await http.get(
        Uri.parse(
            'https://api.geoapify.com/v1/routing?'
                'waypoints=${start.longitude},${start.latitude}|${end.longitude},${end.latitude}&'
                'mode=$mode&'
                'apiKey=$apiKey&'
                'geometry=true'
        ),
      );

      if (response.statusCode == 200) {
        final data = json.decode(response.body);
        final properties = data['features'][0]['properties'];
        final geometry = data['features'][0]['geometry'];

        List<LatLng> routePoints = [];
        if (geometry['type'] == 'LineString') {
          final coords = geometry['coordinates'];
          for (var coord in coords) {
            routePoints.add(LatLng(coord[1], coord[0]));
          }
        }

        return {
          'route': routePoints,
          'distance': properties['distance'],
          'time': properties['time'],
          'distance_formatted': _formatDistance(properties['distance']),
          'time_formatted': _formatDuration(properties['time']),
        };
      }
    } catch (e) {
      print('Routing error: $e');
    }

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

// ============== ROUTE SERVICE (OpenRouteService Backup) ==============
class RouteService {
  static Future<List<LatLng>> getRoute(LatLng start, LatLng end) async {
    final result = await GeoapifyService.getRoute(start, end);
    return result['route'];
  }

  static Future<Map<String, dynamic>> getRouteWithDetails(LatLng start, LatLng end) async {
    return await GeoapifyService.getRoute(start, end);
  }

  static String formatDuration(int seconds) {
    return GeoapifyService._formatDuration(seconds);
  }

  static String formatDistance(int meters) {
    return GeoapifyService._formatDistance(meters);
  }
}

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize webview platform
  if (!kIsWeb) {
    if (Platform.isAndroid) {
      // Android WebView initialization
      AndroidWebViewController.enableDebugging(true);
      // Register the Android platform implementation
      WebViewPlatform.instance = AndroidWebViewPlatform();
    } else if (Platform.isIOS) {
      // iOS WebView initialization
      WebViewPlatform.instance = WebKitWebViewPlatform();
    }
  }

  await Hive.initFlutter();

  Hive.registerAdapter(OrderStatusAdapter());
  Hive.registerAdapter(OrderItemAdapter());
  Hive.registerAdapter(OrderAdapter());

  await Hive.openBox('food_delivery');
  await Hive.openBox<Order>("orders");

  runApp(const MyApp());
}

// ============== MODELS ==============

@HiveType(typeId: 0)
enum OrderStatus {
  @HiveField(0)
  confirmed,
  @HiveField(1)
  preparing,
  @HiveField(2)
  onTheWay,
  @HiveField(3)
  delivered,
}

@HiveType(typeId: 1)
class OrderItem {
  @HiveField(0)
  final String name;
  @HiveField(1)
  final double price;
  @HiveField(2)
  final int quantity;

  OrderItem({
    required this.name,
    required this.price,
    required this.quantity,
  });
}

@HiveType(typeId: 2)
class Order {
  @HiveField(0)
  final String id;
  @HiveField(1)
  final DateTime orderDate;
  @HiveField(2)
  final List<OrderItem> items;
  @HiveField(3)
  final double totalAmount;
  @HiveField(4)
  OrderStatus status;
  @HiveField(5)
  final String deliveryAddress;
  @HiveField(6)
  final double deliveryLat;
  @HiveField(7)
  final double deliveryLng;

  Order({
    required this.id,
    required this.orderDate,
    required this.items,
    required this.totalAmount,
    required this.status,
    required this.deliveryAddress,
    required this.deliveryLat,
    required this.deliveryLng,
  });
}

class FoodItem {
  final String id;
  final String name;
  final String description;
  final double price;
  final String imageUrl;
  final String category;
  final double rating;
  final int preparationTime;

  FoodItem({
    required this.id,
    required this.name,
    required this.description,
    required this.price,
    required this.imageUrl,
    required this.category,
    required this.rating,
    required this.preparationTime,
  });

  static List<FoodItem> mockItems() {
    return [
      FoodItem(
        id: '1',
        name: 'Margherita Pizza',
        description: 'Fresh tomatoes, mozzarella, basil',
        price: 12.99,
        imageUrl: 'assets/images/pizza.jpg',
        category: 'Italian',
        rating: 4.5,
        preparationTime: 20,
      ),
      FoodItem(
        id: '2',
        name: 'Classic Burger',
        description: 'Beef patty, lettuce, tomato, special sauce',
        price: 8.99,
        imageUrl: 'assets/images/burger.jpg',
        category: 'American',
        rating: 4.3,
        preparationTime: 15,
      ),
      FoodItem(
        id: '3',
        name: 'California Roll',
        description: 'Crab, avocado, cucumber',
        price: 10.99,
        imageUrl: 'assets/images/sushi.jpg',
        category: 'Japanese',
        rating: 4.7,
        preparationTime: 25,
      ),
      FoodItem(
        id: '4',
        name: 'Pasta Carbonara',
        description: 'Creamy pasta with bacon and cheese',
        price: 11.99,
        imageUrl: 'assets/images/pasta.jpg',
        category: 'Italian',
        rating: 4.6,
        preparationTime: 18,
      ),
      FoodItem(
        id: '5',
        name: 'Caesar Salad',
        description: 'Fresh romaine lettuce with caesar dressing',
        price: 7.99,
        imageUrl: 'assets/images/salad.jpg',
        category: 'Healthy',
        rating: 4.2,
        preparationTime: 10,
      ),
      FoodItem(
        id: '6',
        name: 'Chicken Wings',
        description: 'Spicy buffalo wings with dip',
        price: 9.99,
        imageUrl: 'assets/images/wings.jpg',
        category: 'American',
        rating: 4.4,
        preparationTime: 15,
      ),
    ];
  }
}

// ============== ADAPTERS ==============

class OrderStatusAdapter extends TypeAdapter<OrderStatus> {
  @override
  final int typeId = 0;

  @override
  OrderStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0: return OrderStatus.confirmed;
      case 1: return OrderStatus.preparing;
      case 2: return OrderStatus.onTheWay;
      case 3: return OrderStatus.delivered;
      default: return OrderStatus.confirmed;
    }
  }

  @override
  void write(BinaryWriter writer, OrderStatus obj) {
    switch (obj) {
      case OrderStatus.confirmed: writer.writeByte(0); break;
      case OrderStatus.preparing: writer.writeByte(1); break;
      case OrderStatus.onTheWay: writer.writeByte(2); break;
      case OrderStatus.delivered: writer.writeByte(3); break;
    }
  }
}

class OrderItemAdapter extends TypeAdapter<OrderItem> {
  @override
  final int typeId = 1;

  @override
  OrderItem read(BinaryReader reader) {
    return OrderItem(
      name: reader.readString(),
      price: reader.readDouble(),
      quantity: reader.readInt(),
    );
  }

  @override
  void write(BinaryWriter writer, OrderItem obj) {
    writer.writeString(obj.name);
    writer.writeDouble(obj.price);
    writer.writeInt(obj.quantity);
  }
}

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 2;

  @override
  Order read(BinaryReader reader) {
    return Order(
      id: reader.readString(),
      orderDate: DateTime.fromMillisecondsSinceEpoch(reader.readInt()),
      items: reader.readList().cast<OrderItem>(),
      totalAmount: reader.readDouble(),
      status: reader.read(),
      deliveryAddress: reader.readString(),
      deliveryLat: reader.readDouble(),
      deliveryLng: reader.readDouble(),
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer.writeString(obj.id);
    writer.writeInt(obj.orderDate.millisecondsSinceEpoch);
    writer.writeList(obj.items);
    writer.writeDouble(obj.totalAmount);
    writer.write(obj.status);
    writer.writeString(obj.deliveryAddress);
    writer.writeDouble(obj.deliveryLat);
    writer.writeDouble(obj.deliveryLng);
  }
}

// ============== PATHFINDING SERVICE ==============

class PathfindingService {
  static Future<List<LatLng>> findPath(LatLng start, LatLng end) async {
    return await RouteService.getRoute(start, end);
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

// ============== MAIN APP ==============

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final box = Hive.box("food_delivery");

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.activeOrange,
      ),
      debugShowCheckedModeBanner: false,
      home: (box.get("username") != null) ? const HomeScreen() : const LoginScreen(),
    );
  }
}

// ============== LOGIN SCREEN ==============

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final box = Hive.box("food_delivery");
  final ordersBox = Hive.box<Order>("orders");

  TextEditingController _username = TextEditingController();
  TextEditingController _password = TextEditingController();
  bool hidePassword = true;

  Future<void> authenticate() async {
    try {
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: 'Please authenticate to login',
        options: const AuthenticationOptions(biometricOnly: true),
      );
      if (didAuthenticate) {
        setState(() {
          _username.text = box.get("username") ?? '';
          _password.text = box.get("password") ?? '';
        });
      }
    } catch (e) {
      debugPrint('Error: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.activeOrange.withOpacity(0.05),
              const Color(0xFFF2F2F7),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  'Welcome Back',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                    fontWeight: FontWeight.w400,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Login',
                  style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 32,
                    color: CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 32),

                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: CupertinoColors.systemGrey5,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          'Username',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.black,
                          ),
                        ),
                      ),
                      CupertinoTextField(
                        controller: _username,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(
                            CupertinoIcons.person,
                            color: CupertinoColors.systemGrey,
                            size: 20,
                          ),
                        ),
                        placeholder: "Enter your username",
                        placeholderStyle: TextStyle(
                          color: CupertinoColors.systemGrey.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        style: TextStyle(
                          color: CupertinoColors.black,
                          fontSize: 16,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                Container(
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: CupertinoColors.systemGrey5,
                      width: 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(left: 12, top: 8),
                        child: Text(
                          'Password',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w500,
                            color: CupertinoColors.black,
                          ),
                        ),
                      ),
                      CupertinoTextField(
                        controller: _password,
                        prefix: Padding(
                          padding: const EdgeInsets.only(left: 12),
                          child: Icon(
                            CupertinoIcons.padlock,
                            color: CupertinoColors.systemGrey,
                            size: 20,
                          ),
                        ),
                        placeholder: "Enter your password",
                        placeholderStyle: TextStyle(
                          color: CupertinoColors.systemGrey.withOpacity(0.5),
                          fontSize: 16,
                        ),
                        obscureText: hidePassword,
                        padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(14),
                        ),
                        style: TextStyle(
                          color: CupertinoColors.black,
                          fontSize: 16,
                        ),
                        suffix: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: Container(
                            margin: const EdgeInsets.only(right: 12),
                            child: Icon(
                              hidePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                              color: CupertinoColors.systemGrey,
                              size: 20,
                            ),
                          ),
                          onPressed: () {
                            setState(() {
                              hidePassword = !hidePassword;
                            });
                          },
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),
                Center(
                  child: Column(
                    children: [
                      Container(
                        width: double.infinity,
                        height: 50,
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
                              color: CupertinoColors.activeOrange.withOpacity(0.3),
                              blurRadius: 12,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: CupertinoButton(
                          padding: EdgeInsets.zero,
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: CupertinoColors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          onPressed: () {
                            if (_username.text.trim() == box.get("username") &&
                                _password.text.trim() == box.get("password")) {
                              Navigator.pushReplacement(
                                  context,
                                  CupertinoPageRoute(builder: (context) => const HomeScreen())
                              );
                            } else {
                              _showAlert(context, 'Invalid Credentials',
                                  'Please check your username and password.');
                            }
                          },
                        ),
                      ),
                      const SizedBox(height: 16),
                      (box.get("Biometrics", defaultValue: false) == true)
                          ? Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(
                            color: CupertinoColors.systemGrey5,
                            width: 1,
                          ),
                        ),
                        child: CupertinoButton(
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.fingerprint_rounded,
                                color: CupertinoColors.activeOrange,
                                size: 24,
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'Use Biometrics',
                                style: TextStyle(
                                  color: CupertinoColors.activeOrange,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          onPressed: authenticate,
                        ),
                      )
                          : const SizedBox.shrink(),
                      const SizedBox(height: 8),

                      // Clear All Data Button
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Clear All Data',
                          style: TextStyle(
                            color: CupertinoColors.destructiveRed,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          showCupertinoDialog(
                            context: context,
                            builder: (context) => CupertinoAlertDialog(
                              title: const Text(
                                "Clear All Data?",
                                style: TextStyle(fontWeight: FontWeight.w600),
                              ),
                              content: const Padding(
                                padding: EdgeInsets.only(top: 8),
                                child: Text(
                                  'This will clear all orders, cart items, and account data. This action cannot be undone.',
                                ),
                              ),
                              actions: [
                                CupertinoDialogAction(
                                  child: const Text('Cancel'),
                                  onPressed: () => Navigator.pop(context),
                                ),
                                CupertinoDialogAction(
                                  isDestructiveAction: true,
                                  child: const Text('Clear'),
                                  onPressed: () {
                                    box.delete("cart");
                                    box.delete("username");
                                    box.delete("password");
                                    box.put("Biometrics", false);
                                    ordersBox.clear();

                                    _username.clear();
                                    _password.clear();

                                    Navigator.pop(context);
                                    setState(() {});

                                    _showAlert(context, 'Data Cleared', 'All data has been successfully cleared.');
                                  },
                                ),
                              ],
                            ),
                          );
                        },
                      ),

                      const SizedBox(height: 8),
                      CupertinoButton(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Text(
                          'Create Account',
                          style: TextStyle(
                            color: CupertinoColors.activeOrange,
                            fontSize: 15,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                        onPressed: () {
                          Navigator.push(
                            context,
                            CupertinoPageRoute(builder: (context) => const SignUpScreen()),
                          );
                        },
                      ),
                    ],
                  ),
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  void _showAlert(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ============== SIGN UP SCREEN ==============

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final box = Hive.box("food_delivery");
  TextEditingController _username = TextEditingController();
  TextEditingController _password = TextEditingController();
  TextEditingController _confirmPassword = TextEditingController();
  bool hidePassword = true;
  bool hideConfirmPassword = true;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.activeOrange.withOpacity(0.05),
              const Color(0xFFF2F2F7),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Create Account',
                    style: TextStyle(
                      fontSize: 14,
                      color: CupertinoColors.systemGrey,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Sign Up',
                    style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 32,
                      color: CupertinoColors.black,
                    ),
                  ),
                  const SizedBox(height: 32),

                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: CupertinoColors.systemGrey5,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: Text(
                            'Username',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.black,
                            ),
                          ),
                        ),
                        CupertinoTextField(
                          controller: _username,
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              CupertinoIcons.person,
                              color: CupertinoColors.systemGrey,
                              size: 20,
                            ),
                          ),
                          placeholder: "Choose a username",
                          placeholderStyle: TextStyle(
                            color: CupertinoColors.systemGrey.withOpacity(0.5),
                            fontSize: 16,
                          ),
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          style: TextStyle(
                            color: CupertinoColors.black,
                            fontSize: 16,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: CupertinoColors.systemGrey5,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: Text(
                            'Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.black,
                            ),
                          ),
                        ),
                        CupertinoTextField(
                          controller: _password,
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              CupertinoIcons.padlock,
                              color: CupertinoColors.systemGrey,
                              size: 20,
                            ),
                          ),
                          placeholder: "Create a password",
                          placeholderStyle: TextStyle(
                            color: CupertinoColors.systemGrey.withOpacity(0.5),
                            fontSize: 16,
                          ),
                          obscureText: hidePassword,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          style: TextStyle(
                            color: CupertinoColors.black,
                            fontSize: 16,
                          ),
                          suffix: CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Icon(
                                hidePassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                                color: CupertinoColors.systemGrey,
                                size: 20,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                hidePassword = !hidePassword;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),

                  Container(
                    decoration: BoxDecoration(
                      color: CupertinoColors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: CupertinoColors.systemGrey5,
                        width: 1,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Padding(
                          padding: const EdgeInsets.only(left: 12, top: 8),
                          child: Text(
                            'Confirm Password',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                              color: CupertinoColors.black,
                            ),
                          ),
                        ),
                        CupertinoTextField(
                          controller: _confirmPassword,
                          prefix: Padding(
                            padding: const EdgeInsets.only(left: 12),
                            child: Icon(
                              CupertinoIcons.padlock,
                              color: CupertinoColors.systemGrey,
                              size: 20,
                            ),
                          ),
                          placeholder: "Confirm your password",
                          placeholderStyle: TextStyle(
                            color: CupertinoColors.systemGrey.withOpacity(0.5),
                            fontSize: 16,
                          ),
                          obscureText: hideConfirmPassword,
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(14),
                          ),
                          style: TextStyle(
                            color: CupertinoColors.black,
                            fontSize: 16,
                          ),
                          suffix: CupertinoButton(
                            padding: EdgeInsets.zero,
                            child: Container(
                              margin: const EdgeInsets.only(right: 12),
                              child: Icon(
                                hideConfirmPassword ? CupertinoIcons.eye : CupertinoIcons.eye_slash,
                                color: CupertinoColors.systemGrey,
                                size: 20,
                              ),
                            ),
                            onPressed: () {
                              setState(() {
                                hideConfirmPassword = !hideConfirmPassword;
                              });
                            },
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),

                  Container(
                    width: double.infinity,
                    height: 50,
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
                          color: CupertinoColors.activeOrange.withOpacity(0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: CupertinoButton(
                      padding: EdgeInsets.zero,
                      child: const Text(
                        'Sign Up',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        if (_password.text.trim() != _confirmPassword.text.trim()) {
                          _showAlert(context, 'Password Mismatch',
                              'Passwords do not match.');
                          return;
                        }

                        if (_username.text.trim().isEmpty || _password.text.trim().isEmpty) {
                          _showAlert(context, 'Invalid Input',
                              'Please fill in all fields.');
                          return;
                        }

                        box.put("username", _username.text.trim());
                        box.put("password", _password.text.trim());

                        Navigator.pushReplacement(
                            context,
                            CupertinoPageRoute(builder: (context) => const LoginScreen())
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 16),
                  Center(
                    child: CupertinoButton(
                      child: const Text(
                        'Already have an account? Login',
                        style: TextStyle(
                          color: CupertinoColors.activeOrange,
                        ),
                      ),
                      onPressed: () {
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  void _showAlert(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ============== HOME SCREEN ==============

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return CupertinoTabScaffold(
      tabBar: CupertinoTabBar(
        backgroundColor: CupertinoColors.white,
        activeColor: CupertinoColors.activeOrange,
        inactiveColor: CupertinoColors.systemGrey,
        border: Border(
          top: BorderSide(
            color: CupertinoColors.systemGrey5.withOpacity(0.5),
            width: 1,
          ),
        ),
        items: const [
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.home),
            label: "Menu",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.clock),
            label: "Orders",
          ),
          BottomNavigationBarItem(
            icon: Icon(CupertinoIcons.settings),
            label: "Settings",
          ),
        ],
      ),
      tabBuilder: (context, index) {
        if (index == 0) {
          return const FoodListScreen();
        } else if (index == 1) {
          return const OrdersScreen();
        } else {
          return const SettingsScreen();
        }
      },
    );
  }
}

// ============== FOOD LIST SCREEN WITH CAROUSEL AND IMAGES ==============

class FoodListScreen extends StatefulWidget {
  const FoodListScreen({super.key});

  @override
  State<FoodListScreen> createState() => _FoodListScreenState();
}

class _FoodListScreenState extends State<FoodListScreen> {
  final box = Hive.box("food_delivery");
  List<dynamic> cart = [];
  List<FoodItem> foodItems = FoodItem.mockItems();

  // Carousel variables
  final PageController _pageController = PageController(viewportFraction: 0.85);
  int _currentPage = 0;
  Timer? _carouselTimer;

  // Featured items (first 3 items for carousel)
  List<FoodItem> get featuredItems => foodItems.take(3).toList();

  @override
  void initState() {
    super.initState();
    if (box.get("cart") != null) {
      setState(() {
        cart = box.get("cart");
      });
    }

    // Start automatic carousel
    _startCarousel();
  }

  @override
  void dispose() {
    _pageController.dispose();
    _carouselTimer?.cancel();
    super.dispose();
  }

  void _startCarousel() {
    _carouselTimer = Timer.periodic(const Duration(seconds: 3), (timer) {
      if (_currentPage < featuredItems.length - 1) {
        _currentPage++;
      } else {
        _currentPage = 0;
      }

      _pageController.animateToPage(
        _currentPage,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    });
  }

  int getCartItemCount() {
    if (cart.isEmpty) return 0;
    return cart.fold(0, (sum, item) => sum + (item["quantity"] as int));
  }

  void _showAddedToCart(BuildContext context, String itemName) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text('Added to Cart'),
        content: Text('$itemName has been added to your cart.'),
        actions: [
          CupertinoDialogAction(
            child: const Text('Continue Shopping'),
            onPressed: () => Navigator.pop(context),
          ),
          CupertinoDialogAction(
            isDefaultAction: true,
            child: const Text('View Cart'),
            onPressed: () {
              Navigator.pop(context);
              Navigator.push(
                context,
                CupertinoPageRoute(builder: (context) => const CartScreen()),
              ).then((_) {
                setState(() {
                  cart = box.get("cart") ?? [];
                });
              });
            },
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
        border: Border(
          bottom: BorderSide(
            color: CupertinoColors.systemGrey5.withOpacity(0.5),
            width: 1,
          ),
        ),
        middle: const Text(
          'Food Menu',
          style: TextStyle(
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: GestureDetector(
          onTap: () {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const CartScreen()),
            ).then((_) {
              setState(() {
                cart = box.get("cart") ?? [];
              });
            });
          },
          child: Stack(
            alignment: Alignment.topRight,
            children: [
              const Icon(CupertinoIcons.cart, size: 24),
              if (getCartItemCount() > 0)
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: CupertinoColors.activeOrange,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    getCartItemCount().toString(),
                    style: const TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.activeOrange.withOpacity(0.05),
              const Color(0xFFF2F2F7),
            ],
          ),
        ),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              // Welcome Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Hungry?',
                        style: TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w700,
                          color: CupertinoColors.black,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Discover delicious food near you',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              // Featured Items Carousel
              SliverToBoxAdapter(
                child: SizedBox(
                  height: 220,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _pageController,
                          onPageChanged: (index) {
                            setState(() {
                              _currentPage = index;
                            });
                          },
                          itemCount: featuredItems.length,
                          itemBuilder: (context, index) {
                            final item = featuredItems[index];
                            return _buildCarouselItem(item);
                          },
                        ),
                      ),
                      const SizedBox(height: 12),
                      // Page Indicators
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: List.generate(
                          featuredItems.length,
                              (index) => Container(
                            width: 8,
                            height: 8,
                            margin: const EdgeInsets.symmetric(horizontal: 4),
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _currentPage == index
                                  ? CupertinoColors.activeOrange
                                  : CupertinoColors.systemGrey.withOpacity(0.3),
                            ),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),




              // Popular Items Header
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Popular Items',
                        style: TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.black,
                        ),
                      ),

                    ],
                  ),
                ),
              ),

              // Food Items Grid
              SliverPadding(
                padding: const EdgeInsets.all(16),
                sliver: SliverGrid(
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 2,
                    childAspectRatio: 0.75,
                    crossAxisSpacing: 12,
                    mainAxisSpacing: 12,
                  ),
                  delegate: SliverChildBuilderDelegate(
                        (context, index) {
                      return _buildFoodGridItem(foodItems[index]);
                    },
                    childCount: foodItems.length,
                  ),
                ),
              ),

              // Bottom padding
              const SliverToBoxAdapter(
                child: SizedBox(height: 20),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCarouselItem(FoodItem item) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 8),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            CupertinoColors.activeOrange,
            const Color(0xFFFF9F0A),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.activeOrange.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Stack(
        children: [
          // Content
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                          'FEATURED',
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                            color: CupertinoColors.white,
                            letterSpacing: 0.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        item.name,
                        style: const TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        item.description,
                        style: TextStyle(
                          fontSize: 12,
                          color: CupertinoColors.white.withOpacity(0.9),
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white,
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  CupertinoIcons.star_fill,
                                  size: 12,
                                  color: CupertinoColors.activeOrange,
                                ),
                                const SizedBox(width: 4),
                                Text(
                                  item.rating.toString(),
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w600,
                                    color: CupertinoColors.activeOrange,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(
                            '${item.preparationTime} min',
                            style: TextStyle(
                              fontSize: 12,
                              color: CupertinoColors.white.withOpacity(0.9),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                // Food image in carousel
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    item.imageUrl,
                    width: 80,
                    height: 80,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) {
                      // Fallback if image fails to load
                      return Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: CupertinoColors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Icon(
                          CupertinoIcons.cart,
                          size: 40,
                          color: CupertinoColors.white,
                        ),
                      );
                    },
                  ),
                ),
              ],
            ),
          ),
          // Add to cart button
          Positioned(
            top: 8,
            right: 8,
            child: CupertinoButton(
              padding: EdgeInsets.zero,
              onPressed: () {
                setState(() {
                  cart.add({
                    "id": item.id,
                    "name": item.name,
                    "price": item.price,
                    "quantity": 1,
                  });
                  box.put("cart", cart);
                });
                _showAddedToCart(context, item.name);
              },
              child: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: CupertinoColors.white,
                  shape: BoxShape.circle,
                ),
                child: Icon(
                  CupertinoIcons.add,
                  size: 16,
                  color: CupertinoColors.activeOrange,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }



  // UPDATED: Image fills the entire grid cell
  Widget _buildFoodGridItem(FoodItem item) {
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: CupertinoColors.systemGrey.withOpacity(0.1),
            blurRadius: 8,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: Stack(
          children: [
            // Background Image - fills entire container
            Positioned.fill(
              child: Image.asset(
                item.imageUrl,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  // Fallback if image fails to load
                  return Container(
                    color: CupertinoColors.activeOrange.withOpacity(0.1),
                    child: Center(
                      child: Icon(
                        CupertinoIcons.cart,
                        size: 40,
                        color: CupertinoColors.activeOrange,
                      ),
                    ),
                  );
                },
              ),
            ),

            // Dark overlay for better text visibility
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      Colors.transparent,
                      Colors.black.withOpacity(0.7),
                    ],
                  ),
                ),
              ),
            ),

            // Content overlay at the bottom
            Positioned(
              left: 12,
              right: 12,
              bottom: 12,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Name
                  Text(
                    item.name,
                    style: const TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.bold,
                      color: CupertinoColors.white,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),

                  // Rating and time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeOrange,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.star_fill,
                              size: 10,
                              color: CupertinoColors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              item.rating.toString(),
                              style: const TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(width: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: CupertinoColors.black.withOpacity(0.5),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              CupertinoIcons.clock,
                              size: 10,
                              color: CupertinoColors.white,
                            ),
                            const SizedBox(width: 2),
                            Text(
                              '${item.preparationTime} min',
                              style: const TextStyle(
                                fontSize: 10,
                                color: CupertinoColors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),

                  // Price and Add button
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        '\$${item.price.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: CupertinoColors.white,
                        ),
                      ),
                      // Add to cart button
                      CupertinoButton(
                        padding: EdgeInsets.zero,
                        onPressed: () {
                          setState(() {
                            cart.add({
                              "id": item.id,
                              "name": item.name,
                              "price": item.price,
                              "quantity": 1,
                            });
                            box.put("cart", cart);
                          });
                          _showAddedToCart(context, item.name);
                        },
                        child: Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeOrange,
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: const Icon(
                            CupertinoIcons.add,
                            size: 16,
                            color: CupertinoColors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


// ============== CART SCREEN ==============

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

  // Zoom level
  double _currentZoom = 14.0;
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

  void _onMapTap(LatLng location) {
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
              CupertinoColors.activeOrange.withOpacity(0.05),
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
                              color: CupertinoColors.systemGrey.withOpacity(0.1),
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
                                color: CupertinoColors.activeOrange.withOpacity(0.1),
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
                        color: CupertinoColors.systemGrey.withOpacity(0.2),
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
                                        color: CupertinoColors.systemGrey.withOpacity(0.5),
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

                            // Map
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
                                      center: _pickedLocation ?? const LatLng(14.5995, 120.9842),
                                      zoom: 16,
                                      onTap: (tapPosition, point) => _onMapTap(point),
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
                                            color: CupertinoColors.systemOrange.withOpacity(0.1),
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
                              color: CupertinoColors.activeOrange.withOpacity(0.3),
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

  IconData _getPlaceIcon(String type) {
    if (type.contains('restaurant')) return Icons.restaurant;
    if (type.contains('cafe')) return Icons.local_cafe;
    if (type.contains('supermarket')) return Icons.shopping_cart;
    if (type.contains('hotel')) return Icons.hotel;
    return Icons.place;
  }
}

// ============== PAYMENT SCREEN WITH CASH ON DELIVERY ==============

class PaymentScreen extends StatefulWidget {
  final double totalAmount;
  final String address;
  final List<dynamic> items;
  final double deliveryLat;
  final double deliveryLng;

  const PaymentScreen({
    super.key,
    required this.totalAmount,
    required this.address,
    required this.items,
    required this.deliveryLat,
    required this.deliveryLng,
  });

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isProcessing = false;
  bool _paymentSuccess = false;
  String _selectedPaymentMethod = 'xendit'; // 'xendit' or 'cod'
  String? _lastOrderId; // Store the last order ID

  final box = Hive.box("food_delivery");
  final ordersBox = Hive.box<Order>("orders");

  // Xendit Integration
  String secretKey = "xnd_development_CXoCfwuVDnt67nMnIDpxiyQ4NaaMUBPdFKxwTH4mAYeJRzvrxY3v2H5Q0k2hl";
  BuildContext? paymentPageContext;
  BuildContext? dialogContext;

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == 'cod') {
      // Process Cash on Delivery - no payment needed
      _saveOrder();
      setState(() {
        _paymentSuccess = true;
      });
      return;
    }

    // Process Xendit payment
    setState(() => _isProcessing = true);

    dialogContext = context;
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: const Text("Waiting for the Payment Page"),
        content: const CupertinoActivityIndicator(),
      ),
    );

    int amountInPesos = (widget.totalAmount * 100).toInt();
    String auth = 'Basic ' + base64Encode(utf8.encode(secretKey));
    final url = "https://api.xendit.co/v2/invoices/";

    try {
      final response = await http.post(
        Uri.parse(url),
        headers: {
          "Authorization": auth,
          "Content-Type": "application/json"
        },
        body: jsonEncode({
          "external_id": "invoice_example",
          "amount": amountInPesos
        }),
      );

      final data = jsonDecode(response.body);
      String id = data['id'];
      String invoice_url = data['invoice_url'];
      print(invoice_url);

      Navigator.push(context, CupertinoPageRoute(builder: (context) {
        paymentPageContext = context;
        return PaymentPage(url: invoice_url);
      }));

      _checkPaymentStatus(auth, url, id);
    } catch (e) {
      print("Error creating invoice: $e");
      if (dialogContext != null) {
        Navigator.pop(dialogContext!);
        dialogContext = null;
      }
      setState(() => _isProcessing = false);
      _showAlert(context, 'Payment Error', 'Failed to create payment. Please try again.');
    }
  }

  Future<void> _checkPaymentStatus(String auth, String baseUrl, String id) async {
    Timer.periodic(const Duration(seconds: 4), (timer) async {
      try {
        final response = await http.get(
          Uri.parse(baseUrl + id),
          headers: {"Authorization": auth},
        );

        final data = jsonDecode(response.body);
        print(data['status']);

        if (data['status'] == "PAID") {
          timer.cancel();

          Future.delayed(const Duration(seconds: 4), () {
            if (paymentPageContext != null) {
              Navigator.pop(paymentPageContext!);
              paymentPageContext = null;
            }
            if (dialogContext != null) {
              Navigator.pop(dialogContext!);
              dialogContext = null;
            }
          });

          _saveOrder();
        }
      } catch (e) {
        print("Error checking payment status: $e");
      }
    });
  }

  void _saveOrder() {
    // Debug print to verify coordinates
    print("========== PAYMENT SCREEN ==========");
    print("SAVING ORDER - Location: ${widget.deliveryLat}, ${widget.deliveryLng}");
    print("SAVING ORDER - Address: ${widget.address}");
    print("====================================");

    // Generate a unique order ID
    String orderId = DateTime.now().millisecondsSinceEpoch.toString();

    final order = Order(
      id: orderId,
      orderDate: DateTime.now(),
      items: widget.items.map((item) => OrderItem(
        name: item["name"],
        price: item["price"],
        quantity: item["quantity"],
      )).toList(),
      totalAmount: widget.totalAmount,
      status: OrderStatus.confirmed,
      deliveryAddress: widget.address,
      deliveryLat: widget.deliveryLat,
      deliveryLng: widget.deliveryLng,
    );

    // Save to Hive
    ordersBox.put(order.id, order);
    _lastOrderId = order.id; // Store the order ID for later use

    // Verify it was saved
    final savedOrder = ordersBox.get(order.id);
    if (savedOrder != null) {
      print("✅ ORDER SAVED SUCCESSFULLY");
      print("   ID: ${savedOrder.id}");
      print("   Location: ${savedOrder.deliveryLat}, ${savedOrder.deliveryLng}");
      print("   Address: ${savedOrder.deliveryAddress}");
    } else {
      print("❌ ERROR: Order not saved properly!");
    }

    box.delete("cart");

    setState(() {
      _isProcessing = false;
      _paymentSuccess = true;
    });
  }

  String _getPaymentMethodName() {
    switch (_selectedPaymentMethod) {
      case 'xendit':
        return 'Xendit';
      case 'cod':
        return 'Cash on Delivery';
      default:
        return '';
    }
  }

  IconData _getPaymentMethodIcon() {
    switch (_selectedPaymentMethod) {
      case 'xendit':
        return CupertinoIcons.creditcard;
      case 'cod':
        return CupertinoIcons.money_dollar;
      default:
        return CupertinoIcons.creditcard;
    }
  }

  Color _getPaymentMethodColor() {
    switch (_selectedPaymentMethod) {
      case 'xendit':
        return CupertinoColors.activeOrange;
      case 'cod':
        return CupertinoColors.systemGreen;
      default:
        return CupertinoColors.activeOrange;
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        middle: Text(
          _paymentSuccess ? 'Order Placed' : 'Payment',
          style: const TextStyle(fontWeight: FontWeight.w600),
        ),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              CupertinoColors.activeOrange.withOpacity(0.05),
              const Color(0xFFF2F2F7),
            ],
          ),
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: _paymentSuccess ? _buildSuccessUI() : _buildPaymentUI(),
          ),
        ),
      ),
    );
  }

  Widget _buildPaymentUI() {
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 14,
              color: CupertinoColors.systemGrey,
              fontWeight: FontWeight.w400,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Checkout',
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 32,
              color: CupertinoColors.black,
            ),
          ),
          const SizedBox(height: 32),

          // Amount Card
          Container(
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CupertinoColors.systemGrey5,
                width: 1,
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Total Amount',
                        style: TextStyle(
                          fontSize: 14,
                          color: CupertinoColors.systemGrey,
                          fontWeight: FontWeight.w400,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'PHP ${widget.totalAmount.toStringAsFixed(2)}',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.activeOrange,
                        ),
                      ),
                    ],
                  ),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.activeOrange.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      CupertinoIcons.money_dollar,
                      color: CupertinoColors.activeOrange,
                      size: 30,
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),

          // Payment Method Selection
          Container(
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: CupertinoColors.systemGrey5,
                width: 1,
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeOrange.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Icon(
                          CupertinoIcons.creditcard,
                          color: CupertinoColors.activeOrange,
                          size: 20,
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Text(
                        'Select Payment Method',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ],
                  ),
                ),

                // Divider
                Container(
                  height: 1,
                  color: CupertinoColors.systemGrey5.withOpacity(0.5),
                ),

                // Xendit Option
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = 'xendit';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'xendit'
                          ? CupertinoColors.activeOrange.withOpacity(0.05)
                          : Colors.transparent,
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedPaymentMethod == 'xendit'
                                  ? CupertinoColors.activeOrange
                                  : CupertinoColors.systemGrey,
                              width: 2,
                            ),
                          ),
                          child: _selectedPaymentMethod == 'xendit'
                              ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: CupertinoColors.activeOrange,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.activeOrange.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 20,
                                height: 20,
                                child: Image.network(
                                  'https://upload.wikimedia.org/wikipedia/commons/thumb/4/40/Xendit_Logo_2019.png/1200px-Xendit_Logo_2019.png',
                                  errorBuilder: (context, error, stackTrace) {
                                    return const Icon(
                                      CupertinoIcons.creditcard,
                                      size: 16,
                                      color: CupertinoColors.activeOrange,
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Xendit',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: CupertinoColors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pay via Credit Card, GCash, GrabPay',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedPaymentMethod == 'xendit')
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: CupertinoColors.systemGreen,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),

                // Cash on Delivery Option
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _selectedPaymentMethod = 'cod';
                    });
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: _selectedPaymentMethod == 'cod'
                          ? CupertinoColors.systemGreen.withOpacity(0.05)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: CupertinoColors.systemGrey5.withOpacity(0.5),
                          width: 1,
                        ),
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 24,
                          height: 24,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: _selectedPaymentMethod == 'cod'
                                  ? CupertinoColors.systemGreen
                                  : CupertinoColors.systemGrey,
                              width: 2,
                            ),
                          ),
                          child: _selectedPaymentMethod == 'cod'
                              ? Center(
                            child: Container(
                              width: 12,
                              height: 12,
                              decoration: const BoxDecoration(
                                color: CupertinoColors.systemGreen,
                                shape: BoxShape.circle,
                              ),
                            ),
                          )
                              : null,
                        ),
                        const SizedBox(width: 12),
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGreen.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.money_dollar,
                            color: CupertinoColors.systemGreen,
                            size: 20,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Cash on Delivery',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: CupertinoColors.black,
                                ),
                              ),
                              SizedBox(height: 4),
                              Text(
                                'Pay with cash when your order arrives',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: CupertinoColors.systemGrey,
                                ),
                              ),
                            ],
                          ),
                        ),
                        if (_selectedPaymentMethod == 'cod')
                          const Icon(
                            CupertinoIcons.check_mark_circled_solid,
                            color: CupertinoColors.systemGreen,
                            size: 24,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Conditional Info Section based on payment method
          if (_selectedPaymentMethod == 'xendit') ...[
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.activeOrange.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: CupertinoColors.activeOrange.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.info,
                      size: 20,
                      color: CupertinoColors.activeOrange,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'You will be redirected to Xendit secure payment page to complete your transaction.',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ] else if (_selectedPaymentMethod == 'cod') ...[
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.systemGreen.withOpacity(0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: CupertinoColors.systemGreen.withOpacity(0.3),
                  width: 1,
                ),
              ),
              child: const Padding(
                padding: EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      CupertinoIcons.money_dollar,
                      size: 20,
                      color: CupertinoColors.systemGreen,
                    ),
                    SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Pay with cash when your order arrives. Please prepare exact amount.',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.black,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],

          const SizedBox(height: 24),

          // Pay Now Button
          Center(
            child: Column(
              children: [
                Container(
                  width: double.infinity,
                  height: 50,
                  decoration: BoxDecoration(
                    gradient: LinearGradient(
                      colors: _selectedPaymentMethod == 'xendit'
                          ? [CupertinoColors.activeOrange, const Color(0xFFFF9F0A)]
                          : [CupertinoColors.systemGreen, const Color(0xFF34C759)],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    ),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: (_selectedPaymentMethod == 'xendit'
                            ? CupertinoColors.activeOrange
                            : CupertinoColors.systemGreen).withOpacity(0.3),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    child: _isProcessing
                        ? const CupertinoActivityIndicator(color: CupertinoColors.white)
                        : Text(
                      _selectedPaymentMethod == 'xendit'
                          ? 'Pay with Xendit'
                          : 'Place Order (Cash on Delivery)',
                      style: const TextStyle(
                        color: CupertinoColors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed: _isProcessing ? null : _processPayment,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSuccessUI() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Text(
          _selectedPaymentMethod == 'cod' ? 'Order Placed' : 'Payment Successful',
          style: TextStyle(
            fontSize: 14,
            color: CupertinoColors.systemGrey,
            fontWeight: FontWeight.w400,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          'Thank You!',
          style: TextStyle(
            fontWeight: FontWeight.w600,
            fontSize: 32,
            color: CupertinoColors.black,
          ),
        ),
        const SizedBox(height: 32),

        // Success Card
        Container(
          decoration: BoxDecoration(
            color: CupertinoColors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(
              color: CupertinoColors.systemGrey5,
              width: 1,
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Success Icon
                Container(
                  padding: const EdgeInsets.all(20),
                  decoration: BoxDecoration(
                    color: _selectedPaymentMethod == 'cod'
                        ? CupertinoColors.systemGreen.withOpacity(0.1)
                        : CupertinoColors.activeOrange.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    _selectedPaymentMethod == 'cod'
                        ? CupertinoIcons.money_dollar
                        : CupertinoIcons.check_mark_circled_solid,
                    size: 50,
                    color: _selectedPaymentMethod == 'cod'
                        ? CupertinoColors.systemGreen
                        : CupertinoColors.activeOrange,
                  ),
                ),
                const SizedBox(height: 16),

                // Success Message
                Text(
                  _selectedPaymentMethod == 'cod'
                      ? 'Order Confirmed!'
                      : 'Payment Successful!',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w600,
                    color: CupertinoColors.black,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  _selectedPaymentMethod == 'cod'
                      ? 'Your order has been placed. Pay when your order arrives.'
                      : 'Your order has been placed successfully',
                  style: TextStyle(
                    fontSize: 14,
                    color: CupertinoColors.systemGrey,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // Payment Method Badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: _getPaymentMethodColor().withOpacity(0.1),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        _getPaymentMethodIcon(),
                        size: 14,
                        color: _getPaymentMethodColor(),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Paid via ${_getPaymentMethodName()}',
                        style: TextStyle(
                          fontSize: 12,
                          color: _getPaymentMethodColor(),
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Address Display
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.systemGrey6,
                    borderRadius: BorderRadius.circular(10),
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
                        child: Text(
                          widget.address,
                          style: const TextStyle(
                            fontSize: 13,
                            color: CupertinoColors.black,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 24),

        // Track Order Button - FIXED to use the actual order ID
        Center(
          child: Column(
            children: [
              Container(
                width: double.infinity,
                height: 50,
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
                      color: CupertinoColors.activeOrange.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: const Text(
                    'Track Order',
                    style: TextStyle(
                      color: CupertinoColors.white,
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  onPressed: () {
                    if (_lastOrderId != null) {
                      print("Navigating to tracking with orderId: $_lastOrderId");
                      Navigator.pushReplacement(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => TrackingScreen(
                            orderId: _lastOrderId!,
                          ),
                        ),
                      );
                    } else {
                      _showAlert(context, 'Error', 'Order ID not found. Please check your orders.');
                    }
                  },
                ),
              ),
              const SizedBox(height: 12),
              CupertinoButton(
                padding: const EdgeInsets.symmetric(vertical: 12),
                child: Text(
                  'Back to Menu',
                  style: TextStyle(
                    color: CupertinoColors.activeOrange,
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                onPressed: () {
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ],
          ),
        ),
      ],
    );
  }

  void _showAlert(BuildContext context, String title, String message) {
    showCupertinoDialog(
      context: context,
      builder: (context) => CupertinoAlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          CupertinoDialogAction(
            child: const Text('OK'),
            onPressed: () => Navigator.pop(context),
          ),
        ],
      ),
    );
  }
}

// ============== PAYMENT PAGE (WEBVIEW) ==============

class PaymentPage extends StatefulWidget {
  final String url;
  const PaymentPage({super.key, required this.url});

  @override
  State<PaymentPage> createState() => _PaymentPageState();
}

class _PaymentPageState extends State<PaymentPage> {
  late WebViewController controller;

  @override
  void initState() {
    super.initState();
    controller = WebViewController();
    controller.setJavaScriptMode(JavaScriptMode.unrestricted);
    controller.loadRequest(Uri.parse(widget.url));
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: CupertinoNavigationBar(
        middle: const Text("Xendit Payment"),
      ),
      child: WebViewWidget(controller: controller),
    );
  }
}

// ============== TRACKING SCREEN ==============

class TrackingScreen extends StatefulWidget {
  final String orderId;

  const TrackingScreen({super.key, required this.orderId});

  @override
  State<TrackingScreen> createState() => _TrackingScreenState();
}

class _TrackingScreenState extends State<TrackingScreen> {
  final MapController _mapController = MapController();
  LatLng _riderLocation = const LatLng(14.5895, 120.9742); // Rider start
  late LatLng _destination;
  List<LatLng> _path = [];
  int _currentPathIndex = 0;
  Timer? _movementTimer;
  OrderStatus _currentStatus = OrderStatus.confirmed;
  final ordersBox = Hive.box<Order>("orders");

  int _totalDistance = 0;
  int _estimatedDuration = 0;
  bool _isLoading = true;
  String _deliveryAddress = "";
  String _errorMessage = "";

  @override
  void initState() {
    super.initState();
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
      await Future.delayed(const Duration(milliseconds: 100));

      final order = ordersBox.get(widget.orderId);

      if (order != null) {
        print("✅ ORDER FOUND IN DATABASE");
        print("   Location: ${order.deliveryLat}, ${order.deliveryLng}");
        print("   Address: ${order.deliveryAddress}");
        print("   Status: ${order.status}");

        _destination = LatLng(order.deliveryLat, order.deliveryLng);
        _deliveryAddress = order.deliveryAddress;
        _currentStatus = order.status;

        Future.delayed(const Duration(milliseconds: 300), () {
          _mapController.move(_destination, 14);
        });

        await _calculatePath();
      } else {
        print("❌ ORDER NOT FOUND IN DATABASE");
        print("   Available orders: ${ordersBox.keys.toList()}");

        final allOrders = ordersBox.values.toList();
        if (allOrders.isNotEmpty) {
          final latestOrder = allOrders.last;
          print("   Using most recent order: ${latestOrder.id}");
          _destination = LatLng(latestOrder.deliveryLat, latestOrder.deliveryLng);
          _deliveryAddress = latestOrder.deliveryAddress;
          _currentStatus = latestOrder.status;

          Future.delayed(const Duration(milliseconds: 300), () {
            _mapController.move(_destination, 14);
          });

          await _calculatePath();
        } else {
          setState(() {
            _errorMessage = "No orders found. Please place an order first.";
            _destination = const LatLng(14.5995, 120.9842);
            _deliveryAddress = "No orders yet";
          });
        }
      }
    } catch (e) {
      print("❌ ERROR loading order: $e");
      setState(() {
        _errorMessage = "Error loading order: $e";
        _destination = const LatLng(14.5995, 120.9842);
        _deliveryAddress = "Error loading location";
      });
    }

    setState(() {
      _isLoading = false;
    });

    _startStatusTimer();
    print("====================================");
  }

  Future<void> _calculatePath() async {
    try {
      final routeData = await GeoapifyService.getRoute(_riderLocation, _destination);

      setState(() {
        _path = routeData['route'];
        _totalDistance = routeData['distance'].round();
        _estimatedDuration = routeData['time'].round();
      });

      print("✅ ROUTE CALCULATED");
      print("   Distance: ${_totalDistance}m");
      print("   Duration: ${_estimatedDuration}s");
    } catch (e) {
      print("❌ ERROR calculating route: $e");
    }
  }

  void _startStatusTimer() {
    Timer(const Duration(minutes: 1), () async {
      if (_currentStatus == OrderStatus.confirmed) {
        setState(() => _currentStatus = OrderStatus.onTheWay);
        _startMovementSimulation();

        final order = ordersBox.get(widget.orderId);
        if (order != null) {
          order.status = OrderStatus.onTheWay;
          await ordersBox.put(order.id, order);
          print("✅ ORDER STATUS UPDATED TO: ON THE WAY");
        }
      }
    });
  }

  void _startMovementSimulation() {
    _movementTimer = Timer.periodic(const Duration(seconds: 2), (timer) async {
      if (_currentPathIndex < _path.length - 1) {
        setState(() {
          _currentPathIndex++;
          _riderLocation = _path[_currentPathIndex];
        });
      } else {
        timer.cancel();
        setState(() => _currentStatus = OrderStatus.delivered);

        final order = ordersBox.get(widget.orderId);
        if (order != null) {
          order.status = OrderStatus.delivered;
          await ordersBox.put(order.id, order);
          print("✅ ORDER STATUS UPDATED TO: DELIVERED");
        }
      }
    });
  }

  @override
  void dispose() {
    _movementTimer?.cancel();
    super.dispose();
  }

  String getStatusText() {
    switch (_currentStatus) {
      case OrderStatus.confirmed: return 'Order Confirmed';
      case OrderStatus.preparing: return 'Preparing your order';
      case OrderStatus.onTheWay: return 'Delivery is on the way';
      case OrderStatus.delivered: return 'Delivered';
      default: return 'Processing';
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        middle: const Text('Track Order', style: TextStyle(fontWeight: FontWeight.w600)),
        // Add back button to navigation bar
        leading: CupertinoNavigationBarBackButton(
          onPressed: () => Navigator.pop(context),
        ),
      ),
      child: _isLoading
          ? const Center(child: CupertinoActivityIndicator())
          : Column(
        children: [
          // Status Card
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: CupertinoColors.white,
              border: Border(bottom: BorderSide(color: CupertinoColors.systemGrey5, width: 1)),
            ),
            child: Column(
              children: [
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeOrange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Icon(
                        _currentStatus == OrderStatus.delivered
                            ? CupertinoIcons.check_mark_circled_solid
                            : _currentStatus == OrderStatus.onTheWay
                            ? CupertinoIcons.car
                            : CupertinoIcons.clock,
                        color: CupertinoColors.activeOrange,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(getStatusText(), style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600)),
                          const SizedBox(height: 4),
                          Text(
                            _currentStatus == OrderStatus.delivered
                                ? 'Your order has been delivered'
                                : _currentStatus == OrderStatus.onTheWay
                                ? 'Your rider is on the way'
                                : 'Restaurant is preparing your order',
                            style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),

                // Delivery Address
                if (_deliveryAddress.isNotEmpty && _deliveryAddress != "No orders yet") ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.location_fill, size: 14, color: CupertinoColors.activeOrange),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _deliveryAddress,
                            style: const TextStyle(fontSize: 12, color: CupertinoColors.black),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Error message
                if (_errorMessage.isNotEmpty) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: CupertinoColors.destructiveRed.withOpacity(0.1),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      children: [
                        const Icon(CupertinoIcons.exclamationmark_triangle, size: 14, color: CupertinoColors.destructiveRed),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _errorMessage,
                            style: const TextStyle(fontSize: 12, color: CupertinoColors.destructiveRed),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],

                // Route Details
                if (!_isLoading && _currentStatus != OrderStatus.delivered && _totalDistance > 0) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: CupertinoColors.systemGrey6,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        Column(
                          children: [
                            const Icon(CupertinoIcons.map, size: 16, color: CupertinoColors.activeOrange),
                            const SizedBox(height: 4),
                            Text('Distance', style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey)),
                            Text(
                              GeoapifyService._formatDistance(_totalDistance),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.black),
                            ),
                          ],
                        ),
                        Container(height: 30, width: 1, color: CupertinoColors.systemGrey5),
                        Column(
                          children: [
                            const Icon(CupertinoIcons.time, size: 16, color: CupertinoColors.activeOrange),
                            const SizedBox(height: 4),
                            Text('Est. Time', style: TextStyle(fontSize: 10, color: CupertinoColors.systemGrey)),
                            Text(
                              GeoapifyService._formatDuration(_estimatedDuration),
                              style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: CupertinoColors.black),
                            ),
                          ],
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
            child: FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                center: _destination,
                zoom: 14,
              ),
              children: [
                TileLayer(
                  urlTemplate: 'https://maps.geoapify.com/v1/tile/osm-bright/{z}/{x}/{y}.png?apiKey=${ApiKeys.geoapifyKey}',
                  userAgentPackageName: 'com.example.food_delivery',
                ),
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points: _path,
                      color: CupertinoColors.activeGreen,
                      strokeWidth: 5,
                    ),
                  ],
                ),
                MarkerLayer(
                  markers: [
                    // Rider Marker
                    Marker(
                      point: _riderLocation,
                      width: 40,
                      height: 40,
                      child: Container(
                        decoration: BoxDecoration(
                          color: CupertinoColors.white,
                          shape: BoxShape.circle,
                          border: Border.all(color: CupertinoColors.activeOrange, width: 2),
                          boxShadow: [
                            BoxShadow(
                              color: CupertinoColors.activeOrange.withOpacity(0.3),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            ),
                          ],
                        ),
                        child: const Icon(
                          Icons.delivery_dining,
                          color: CupertinoColors.activeOrange,
                          size: 24,
                        ),
                      ),
                    ),
                    // Destination Marker (Pinned Location)
                    Marker(
                      point: _destination,
                      width: 50,
                      height: 50,
                      child: Column(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: CupertinoColors.white,
                              borderRadius: BorderRadius.circular(12),
                              boxShadow: [
                                BoxShadow(
                                  color: CupertinoColors.systemGrey.withOpacity(0.2),
                                  blurRadius: 4,
                                  offset: const Offset(0, 2),
                                ),
                              ],
                            ),
                            child: const Text(
                              'You',
                              style: TextStyle(
                                fontSize: 10,
                                fontWeight: FontWeight.bold,
                                color: CupertinoColors.systemGreen,
                              ),
                            ),
                          ),
                          const Icon(
                            Icons.location_pin,
                            color: CupertinoColors.systemGreen,
                            size: 30,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Back to Menu Button - Added at the bottom
          Padding(
            padding: const EdgeInsets.all(16),
            child: Container(
              width: double.infinity,
              decoration: BoxDecoration(
                gradient: const LinearGradient(
                  colors: [
                    CupertinoColors.systemIndigo,
                    Color(0xFF5E5CE6),
                  ],
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                ),
                borderRadius: BorderRadius.circular(14),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.systemIndigo.withOpacity(0.3),
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
                  // Navigate back to the home screen (menu tab)
                  Navigator.popUntil(context, (route) => route.isFirst);
                },
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============== ORDERS SCREEN ==============

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ordersBox = Hive.box<Order>("orders");

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      navigationBar: const CupertinoNavigationBar(
        backgroundColor: CupertinoColors.white,
        middle: Text('My Orders', style: TextStyle(fontWeight: FontWeight.w600)),
      ),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CupertinoColors.activeOrange.withOpacity(0.05), const Color(0xFFF2F2F7)],
          ),
        ),
        child: ValueListenableBuilder(
          valueListenable: ordersBox.listenable(),
          builder: (context, Box<Order> box, _) {
            final orders = box.values.toList();

            if (orders.isEmpty) {
              return Center(
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
                            color: CupertinoColors.systemGrey.withOpacity(0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(CupertinoIcons.clock, size: 50, color: CupertinoColors.activeOrange),
                    ),
                    const SizedBox(height: 20),
                    const Text('No Orders Yet', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 8),
                    Text('Your orders will appear here', style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey)),
                  ],
                ),
              );
            }

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: orders.length,
              itemBuilder: (context, index) {
                final order = orders[index];
                return Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: CupertinoColors.white,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: CupertinoColors.systemGrey5, width: 1),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      print("Navigating to tracking for order: ${order.id}");
                      print("Order details - Lat: ${order.deliveryLat}, Lng: ${order.deliveryLng}");
                      print("Address: ${order.deliveryAddress}");

                      Navigator.push(
                        context,
                        CupertinoPageRoute(
                          builder: (context) => TrackingScreen(orderId: order.id),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text('Order #${order.id.substring(0, 6)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600)),
                              Container(
                                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order.status).withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(order.status),
                                  style: TextStyle(fontSize: 12, color: _getStatusColor(order.status), fontWeight: FontWeight.w500),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            order.items.map((item) => '${item.quantity}x ${item.name}').join(', '),
                            style: TextStyle(fontSize: 13, color: CupertinoColors.systemGrey),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '\$${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: CupertinoColors.activeOrange),
                              ),
                              Text(
                                _formatDate(order.orderDate),
                                style: TextStyle(fontSize: 12, color: CupertinoColors.systemGrey),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed: return 'Confirmed';
      case OrderStatus.preparing: return 'Preparing';
      case OrderStatus.onTheWay: return 'On the way';
      case OrderStatus.delivered: return 'Delivered';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed: return CupertinoColors.activeBlue;
      case OrderStatus.preparing: return CupertinoColors.activeOrange;
      case OrderStatus.onTheWay: return CupertinoColors.systemGreen;
      case OrderStatus.delivered: return CupertinoColors.systemGrey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }
}

// ============== SETTINGS SCREEN ==============

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  final box = Hive.box("food_delivery");
  final ordersBox = Hive.box<Order>("orders");

  Widget tiles(Color color, String title, dynamic trailing, IconData icon) {
    return Container(
      margin: const EdgeInsets.symmetric(vertical: 4),
      decoration: BoxDecoration(
        color: CupertinoColors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: CupertinoColors.systemGrey5, width: 1),
      ),
      child: CupertinoListTile(
        trailing: trailing,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withOpacity(0.1),
          ),
          child: Icon(icon, size: 18, color: color),
        ),
        title: Text(
          title,
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w500,
            color: color == CupertinoColors.destructiveRed ? color : CupertinoColors.black,
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [CupertinoColors.activeOrange.withOpacity(0.05), const Color(0xFFF2F2F7)],
          ),
        ),
        child: SafeArea(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Settings', style: TextStyle(fontSize: 14, color: CupertinoColors.systemGrey, fontWeight: FontWeight.w400)),
                        const SizedBox(height: 4),
                        const Text('Preferences', style: TextStyle(fontSize: 24, fontWeight: FontWeight.w600, color: CupertinoColors.black)),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.activeOrange.withOpacity(0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(CupertinoIcons.settings, size: 20, color: CupertinoColors.activeOrange),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  children: [
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        children: [
                          Text('SECURITY', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    tiles(
                      CupertinoColors.activeOrange,
                      "Biometrics",
                      CupertinoSwitch(
                        value: box.get("Biometrics", defaultValue: false),
                        onChanged: (value) {
                          setState(() {
                            box.put("Biometrics", value);
                            print("Biometrics set to: $value");
                          });
                        },
                        activeColor: CupertinoColors.activeOrange,
                      ),
                      Icons.fingerprint_rounded,
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        children: [
                          Text('ACCOUNT', style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: CupertinoColors.systemGrey, letterSpacing: 0.5)),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text("Sign Out?", style: TextStyle(fontWeight: FontWeight.w600)),
                            content: const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Are you sure you want to sign out?'),
                            ),
                            actions: [
                              CupertinoDialogAction(child: const Text('Cancel'), onPressed: () => Navigator.pop(context)),
                              CupertinoDialogAction(
                                isDestructiveAction: true,
                                child: const Text('Sign Out'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacement(
                                    context,
                                    CupertinoPageRoute(builder: (context) => const LoginScreen()),
                                  );
                                },
                              ),
                            ],
                          ),
                        );
                      },
                      child: tiles(
                        CupertinoColors.destructiveRed,
                        "Sign Out",
                        Container(
                          padding: const EdgeInsets.all(6),
                          decoration: BoxDecoration(
                            color: CupertinoColors.systemGrey6,
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(CupertinoIcons.chevron_forward, size: 14, color: CupertinoColors.systemGrey),
                        ),
                        CupertinoIcons.arrow_right,
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