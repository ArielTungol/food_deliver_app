import 'package:flutter/cupertino.dart';

import 'food_list_screen.dart';
import 'orders_screen.dart';
import 'settings_screen.dart';

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
            color: CupertinoColors.systemGrey5.withValues(alpha: 0.5),
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