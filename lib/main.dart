import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:hive_flutter/hive_flutter.dart';
import 'package:webview_flutter/webview_flutter.dart';
import 'package:webview_flutter_android/webview_flutter_android.dart';
import 'package:webview_flutter_wkwebview/webview_flutter_wkwebview.dart';
import 'dart:io' show Platform;

import 'models/order.dart';  // For Order class only
import 'screens/login_screen.dart';
import 'screens/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize webview platform
  if (!kIsWeb) {
    if (Platform.isAndroid) {
      AndroidWebViewController.enableDebugging(true);
      WebViewPlatform.instance = AndroidWebViewPlatform();
    } else if (Platform.isIOS) {
      WebViewPlatform.instance = WebKitWebViewPlatform();
    }
  }

  await Hive.initFlutter();

  // Register adapters - ONLY from adapters.dart
  Hive.registerAdapter(OrderStatusAdapter());
  Hive.registerAdapter(OrderItemAdapter());
  Hive.registerAdapter(OrderAdapter());

  // Open boxes
  await Hive.openBox('food_delivery');
  await Hive.openBox<Order>('orders');

  runApp(const MyApp());
}

class MyApp extends StatefulWidget {
  const MyApp({super.key});

  @override
  State<MyApp> createState() => _MyAppState();
}

class _MyAppState extends State<MyApp> {
  final box = Hive.box('food_delivery');

  @override
  Widget build(BuildContext context) {
    return CupertinoApp(
      theme: const CupertinoThemeData(
        primaryColor: CupertinoColors.activeOrange,
      ),
      debugShowCheckedModeBanner: false,
      home: (box.get('username') != null) ? const HomeScreen() : const LoginScreen(),
    );
  }
}