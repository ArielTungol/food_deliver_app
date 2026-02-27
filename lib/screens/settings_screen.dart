import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import '../models/order.dart';
import 'login_screen.dart';

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
        border: Border.all(
          color: CupertinoColors.systemGrey5,
          width: 1,
        ),
      ),
      child: CupertinoListTile(
        trailing: trailing,
        leading: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(10),
            color: color.withValues(alpha: 0.1),
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
            colors: [
              CupertinoColors.activeOrange.withValues(alpha: 0.05),
              const Color(0xFFF2F2F7),
            ],
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
                        Text(
                          'Settings',
                          style: TextStyle(
                            fontSize: 14,
                            color: CupertinoColors.systemGrey,
                            fontWeight: FontWeight.w400,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Preferences',
                          style: TextStyle(
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                            color: CupertinoColors.black,
                          ),
                        ),
                      ],
                    ),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: CupertinoColors.white,
                        borderRadius: BorderRadius.circular(14),
                        boxShadow: [
                          BoxShadow(
                            color: CupertinoColors.activeOrange.withValues(alpha: 0.08),
                            blurRadius: 10,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.settings,
                        size: 20,
                        color: CupertinoColors.activeOrange,
                      ),
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
                          Text(
                            'SECURITY',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemGrey,
                              letterSpacing: 0.5,
                            ),
                          ),
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
                      Icons.fingerprint,
                    ),
                    const SizedBox(height: 24),
                    const Padding(
                      padding: EdgeInsets.only(left: 8, bottom: 8),
                      child: Row(
                        children: [
                          Text(
                            'ACCOUNT',
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: CupertinoColors.systemGrey,
                              letterSpacing: 0.5,
                            ),
                          ),
                        ],
                      ),
                    ),
                    GestureDetector(
                      onTap: () {
                        showCupertinoDialog(
                          context: context,
                          builder: (context) => CupertinoAlertDialog(
                            title: const Text(
                              "Sign Out?",
                              style: TextStyle(fontWeight: FontWeight.w600),
                            ),
                            content: const Padding(
                              padding: EdgeInsets.only(top: 8),
                              child: Text('Are you sure you want to sign out?'),
                            ),
                            actions: [
                              CupertinoDialogAction(
                                child: const Text('Cancel'),
                                onPressed: () => Navigator.pop(context),
                              ),
                              CupertinoDialogAction(
                                isDestructiveAction: true,
                                child: const Text('Sign Out'),
                                onPressed: () {
                                  Navigator.pop(context);
                                  Navigator.pushReplacement(
                                    context,
                                    CupertinoPageRoute(
                                      builder: (context) => const LoginScreen(),
                                    ),
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
                          child: const Icon(
                            CupertinoIcons.chevron_forward,
                            size: 14,
                            color: CupertinoColors.systemGrey,
                          ),
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