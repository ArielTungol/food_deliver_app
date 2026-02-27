import 'dart:async';
import 'dart:convert';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:hive/hive.dart';
import 'package:http/http.dart' as http;

import '../models/order.dart';
import 'payment_page.dart';
import 'tracking_screen.dart';
import 'home_screen.dart'; // Add this import

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
  String? _lastOrderId;

  final box = Hive.box("food_delivery");
  final ordersBox = Hive.box<Order>("orders");

  // Xendit Integration
  final String secretKey = "xnd_development_CXoCfwuVDnt67nMnIDpxiyQ4NaaMUBPdFKxwTH4mAYeJRzvrxY3v2H5Q0k2hl";
  BuildContext? paymentPageContext;
  BuildContext? dialogContext;

  Future<void> _processPayment() async {
    if (_selectedPaymentMethod == 'cod') {
      _saveOrder();
      setState(() {
        _paymentSuccess = true;
      });
      return;
    }

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
          "external_id": "invoice_${DateTime.now().millisecondsSinceEpoch}",
          "amount": amountInPesos
        }),
      );

      final data = jsonDecode(response.body);
      String id = data['id'];
      String invoice_url = data['invoice_url'];
      print(invoice_url);

      if (!mounted) return;

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

          Future.delayed(const Duration(seconds: 2), () {
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
    print("========== PAYMENT SCREEN ==========");
    print("SAVING ORDER - Location: ${widget.deliveryLat}, ${widget.deliveryLng}");
    print("SAVING ORDER - Address: ${widget.address}");
    print("====================================");

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

    ordersBox.put(order.id, order);
    _lastOrderId = order.id;

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
              CupertinoColors.activeOrange.withValues(alpha: 0.05),
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
                      color: CupertinoColors.activeOrange.withValues(alpha: 0.1),
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
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(10),
                        decoration: BoxDecoration(
                          color: CupertinoColors.activeOrange.withValues(alpha: 0.1),
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

                Container(
                  height: 1,
                  color: CupertinoColors.systemGrey5.withValues(alpha: 0.5),
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
                          ? CupertinoColors.activeOrange.withValues(alpha: 0.05)
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
                            color: CupertinoColors.activeOrange.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: const Icon(
                            CupertinoIcons.creditcard,
                            size: 16,
                            color: CupertinoColors.activeOrange,
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
                          ? CupertinoColors.systemGreen.withValues(alpha: 0.05)
                          : Colors.transparent,
                      border: Border(
                        top: BorderSide(
                          color: CupertinoColors.systemGrey5.withValues(alpha: 0.5),
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
                            color: CupertinoColors.systemGreen.withValues(alpha: 0.1),
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

          // Conditional Info Section
          if (_selectedPaymentMethod == 'xendit') ...[
            Container(
              decoration: BoxDecoration(
                color: CupertinoColors.activeOrange.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: CupertinoColors.activeOrange.withValues(alpha: 0.3),
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
                color: CupertinoColors.systemGreen.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: CupertinoColors.systemGreen.withValues(alpha: 0.3),
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
                            : CupertinoColors.systemGreen).withValues(alpha: 0.3),
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
                        ? CupertinoColors.systemGreen.withValues(alpha: 0.1)
                        : CupertinoColors.activeOrange.withValues(alpha: 0.1),
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
                    color: _getPaymentMethodColor().withValues(alpha: 0.1),
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

        // Track Order Button and Back to Menu
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
                      color: CupertinoColors.activeOrange.withValues(alpha: 0.3),
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
                      if (!mounted) return;
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

              // FIXED: Back to Menu button - now goes to HomeScreen
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
                  // Navigate to HomeScreen and remove all previous routes
                  Navigator.pushAndRemoveUntil(
                    context,
                    CupertinoPageRoute(builder: (context) => const HomeScreen()),
                        (route) => false, // This removes all previous routes
                  );
                },
              ),
            ],
          ),
        ),
      ],
    );
  }
}