import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';

import 'login_screen.dart';

class SignUpScreen extends StatefulWidget {
  const SignUpScreen({super.key});

  @override
  State<SignUpScreen> createState() => _SignUpScreenState();
}

class _SignUpScreenState extends State<SignUpScreen> {
  final box = Hive.box("food_delivery");
  final TextEditingController _username = TextEditingController();
  final TextEditingController _password = TextEditingController();
  final TextEditingController _confirmPassword = TextEditingController();
  bool hidePassword = true;
  bool hideConfirmPassword = true;

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
                          placeholder: "Choose a username",
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
                          placeholder: "Create a password",
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
                  const SizedBox(height: 12),

                  // Confirm Password field
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
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.5),
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

                  // Sign Up button
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
                        'Sign Up',
                        style: TextStyle(
                          color: CupertinoColors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      onPressed: () {
                        if (_password.text.trim() != _confirmPassword.text.trim()) {
                          _showAlert(context, 'Password Mismatch', 'Passwords do not match.');
                          return;
                        }

                        if (_username.text.trim().isEmpty || _password.text.trim().isEmpty) {
                          _showAlert(context, 'Invalid Input', 'Please fill in all fields.');
                          return;
                        }

                        box.put("username", _username.text.trim());
                        box.put("password", _password.text.trim());

                        Navigator.pushReplacement(
                            context,
                            CupertinoPageRoute(builder: (context) => const LoginScreen()));
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
}