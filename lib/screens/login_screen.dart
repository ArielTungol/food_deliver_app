import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:hive/hive.dart';
import 'package:local_auth/local_auth.dart';
import 'package:local_auth/error_codes.dart' as auth_error;

import '../models/order.dart';
import 'home_screen.dart';
import 'signup_screen.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final LocalAuthentication auth = LocalAuthentication();
  final box = Hive.box("food_delivery");
  final ordersBox = Hive.box<Order>("orders");

  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  bool hidePassword = true;
  bool _isBiometricAvailable = false;
  List<BiometricType> _availableBiometrics = [];
  bool _hasAccount = false; // New variable to check if account exists

  @override
  void initState() {
    super.initState();
    _checkForExistingAccount();
    _checkBiometrics();
  }

  // New method to check if an account exists
  void _checkForExistingAccount() {
    final username = box.get("username");
    final password = box.get("password");

    setState(() {
      _hasAccount = username != null && password != null;
    });

    print("Account exists: $_hasAccount");
  }

  Future<void> _checkBiometrics() async {
    try {
      // Check if biometrics are available on the device
      _isBiometricAvailable = await auth.canCheckBiometrics;

      if (_isBiometricAvailable) {
        // Get list of available biometrics (FaceID, TouchID, etc.)
        _availableBiometrics = await auth.getAvailableBiometrics();

        // For iOS, this will show "Face ID" or "Touch ID" accordingly
        if (_availableBiometrics.isNotEmpty) {
          print("Available biometrics: $_availableBiometrics");
        }
      }

      setState(() {});
    } on PlatformException catch (e) {
      print("Error checking biometrics: $e");
      setState(() {
        _isBiometricAvailable = false;
      });
    }
  }

  Future<void> _authenticateWithBiometrics() async {
    try {
      // Check if biometrics are available
      final bool canAuthenticate = await auth.canCheckBiometrics &&
          (await auth.getAvailableBiometrics()).isNotEmpty;

      if (!canAuthenticate) {
        _showAlert(context, 'Biometrics Not Available',
            'Face ID / Touch ID is not available on this device.');
        return;
      }

      // Check if user has enabled biometrics in the app
      if (box.get("Biometrics", defaultValue: false) != true) {
        _showAlert(context, 'Biometrics Not Enabled',
            'Please enable Biometrics in Settings first.');
        return;
      }

      // Get the stored credentials
      String? storedUsername = box.get("username");
      String? storedPassword = box.get("password");

      if (storedUsername == null || storedPassword == null) {
        _showAlert(context, 'No Account Found',
            'Please create an account first.');

        // Redirect to signup after a short delay
        Future.delayed(const Duration(seconds: 1), () {
          if (mounted) {
            Navigator.push(
              context,
              CupertinoPageRoute(builder: (context) => const SignUpScreen()),
            );
          }
        });
        return;
      }

      // Authenticate with iOS Face ID / Touch ID
      final bool didAuthenticate = await auth.authenticate(
        localizedReason: _getBiometricPrompt(),
        options: AuthenticationOptions(
          biometricOnly: true,
          stickyAuth: true,
          useErrorDialogs: true,
        ),
      );

      if (didAuthenticate) {
        // Successfully authenticated with Face ID / Touch ID
        print("✅ Biometric authentication successful");

        // Auto login with stored credentials
        _performLogin(storedUsername, storedPassword);
      } else {
        print("❌ Biometric authentication failed or was canceled");
      }
    } on PlatformException catch (e) {
      print("Biometric authentication error: $e");

      // Handle specific error cases
      if (e.code == auth_error.notAvailable) {
        _showAlert(context, 'Biometrics Not Available',
            'Face ID / Touch ID is not available on this device.');
      } else if (e.code == auth_error.notEnrolled) {
        _showAlert(context, 'No Biometrics Enrolled',
            'Please set up Face ID or Touch ID in your device settings first.');
      } else if (e.code == auth_error.lockedOut) {
        _showAlert(context, 'Biometrics Locked Out',
            'Too many failed attempts. Please use your password to login.');
      } else if (e.code == auth_error.permanentlyLockedOut) {
        _showAlert(context, 'Biometrics Permanently Locked',
            'Biometric authentication is locked. Please use your password to login.');
      } else {
        _showAlert(context, 'Authentication Error',
            'Failed to authenticate with Face ID / Touch ID. Please try again.');
      }
    } catch (e) {
      print("Unexpected error: $e");
      _showAlert(context, 'Error', 'An unexpected error occurred.');
    }
  }

  String _getBiometricPrompt() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Use Face ID to login';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Use Touch ID to login';
    } else {
      return 'Use biometrics to login';
    }
  }

  String _getBiometricIconName() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return 'Face ID';
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return 'Touch ID';
    } else {
      return 'Biometrics';
    }
  }

  IconData _getBiometricIcon() {
    if (_availableBiometrics.contains(BiometricType.face)) {
      return Icons.face; // Face ID icon
    } else if (_availableBiometrics.contains(BiometricType.fingerprint)) {
      return Icons.fingerprint; // Touch ID icon
    } else {
      return Icons.fingerprint;
    }
  }

  void _performLogin(String username, String password) {
    if (username == box.get("username") && password == box.get("password")) {
      Navigator.pushReplacement(
        context,
        CupertinoPageRoute(builder: (context) => const HomeScreen()),
      );
    } else {
      _showAlert(context, 'Invalid Credentials',
          'Stored credentials are invalid. Please login manually.');
    }
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

  @override
  Widget build(BuildContext context) {
    bool biometricsEnabled = box.get("Biometrics", defaultValue: false) == true;

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

                // Conditional rendering based on account existence
                if (_hasAccount) ...[
                  // Username field
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
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.5),
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

                  // Password field
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
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.5),
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
                ],

                Center(
                  child: Column(
                    children: [
                      // Show login button only if account exists
                      if (_hasAccount) ...[
                        // Login button
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
                                color: CupertinoColors.activeOrange.withValues(alpha: 0.3),
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
                                    CupertinoPageRoute(builder: (context) => const HomeScreen()));
                              } else {
                                _showAlert(context, 'Invalid Credentials',
                                    'Please check your username and password.');
                              }
                            },
                          ),
                        ),
                        const SizedBox(height: 16),

                        // Biometrics button - UPDATED for iOS Face ID / Touch ID
                        if (biometricsEnabled && _isBiometricAvailable)
                          Container(
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
                                    _getBiometricIcon(),
                                    color: CupertinoColors.activeOrange,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Login with ${_getBiometricIconName()}',
                                    style: TextStyle(
                                      color: CupertinoColors.activeOrange,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: _authenticateWithBiometrics,
                            ),
                          )
                        else if (biometricsEnabled && !_isBiometricAvailable)
                          Container(
                            decoration: BoxDecoration(
                              color: CupertinoColors.systemGrey5,
                              borderRadius: BorderRadius.circular(14),
                            ),
                            child: CupertinoButton(
                              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Icon(
                                    Icons.fingerprint,
                                    color: CupertinoColors.systemGrey,
                                    size: 24,
                                  ),
                                  const SizedBox(width: 8),
                                  Text(
                                    'Biometrics Unavailable',
                                    style: TextStyle(
                                      color: CupertinoColors.systemGrey,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                              onPressed: null,
                            ),
                          ),

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
                                      setState(() {
                                        _hasAccount = false; // Update account status
                                      });

                                      _showAlert(context, 'Data Cleared',
                                          'All data has been successfully cleared.');
                                    },
                                  ),
                                ],
                              ),
                            );
                          },
                        ),

                        const SizedBox(height: 8),
                      ],

                      // Show "No Account" message and Create Account button if no account exists
                      if (!_hasAccount) ...[
                        Container(
                          padding: const EdgeInsets.all(24),
                          decoration: BoxDecoration(
                            color: CupertinoColors.white,
                            borderRadius: BorderRadius.circular(14),
                            border: Border.all(
                              color: CupertinoColors.systemGrey5,
                              width: 1,
                            ),
                          ),
                          child: Column(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(16),
                                decoration: BoxDecoration(
                                  color: CupertinoColors.activeOrange.withValues(alpha: 0.1),
                                  shape: BoxShape.circle,
                                ),
                                child: const Icon(
                                  CupertinoIcons.person_add,
                                  color: CupertinoColors.activeOrange,
                                  size: 40,
                                ),
                              ),
                              const SizedBox(height: 16),
                              const Text(
                                'No Account Found',
                                style: TextStyle(
                                  fontSize: 18,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.black,
                                ),
                              ),
                              const SizedBox(height: 8),
                              Text(
                                'You need to create an account first to start ordering.',
                                style: TextStyle(
                                  fontSize: 14,
                                  color: CupertinoColors.systemGrey,
                                ),
                                textAlign: TextAlign.center,
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
                                      color: CupertinoColors.activeOrange.withValues(alpha: 0.3),
                                      blurRadius: 12,
                                      offset: const Offset(0, 4),
                                    ),
                                  ],
                                ),
                                child: CupertinoButton(
                                  padding: EdgeInsets.zero,
                                  child: const Text(
                                    'Create Account',
                                    style: TextStyle(
                                      color: CupertinoColors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                  ),
                                  onPressed: () {
                                    Navigator.push(
                                      context,
                                      CupertinoPageRoute(builder: (context) => const SignUpScreen()),
                                    );
                                  },
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // Always show Create Account button as an alternative (even when account exists)
                      if (_hasAccount) ...[
                        CupertinoButton(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'Create New Account',
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
}