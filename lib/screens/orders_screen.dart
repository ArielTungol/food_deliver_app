import 'package:flutter/cupertino.dart';
import 'package:hive/hive.dart';
import 'package:hive_flutter/hive_flutter.dart';

import '../models/order.dart';
import 'tracking_screen.dart';

class OrdersScreen extends StatefulWidget {
  const OrdersScreen({super.key});

  @override
  State<OrdersScreen> createState() => _OrdersScreenState();
}

class _OrdersScreenState extends State<OrdersScreen> {
  final ordersBox = Hive.box<Order>("orders");

  String _getStatusText(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return 'Confirmed';
      case OrderStatus.preparing:
        return 'Preparing';
      case OrderStatus.onTheWay:
        return 'On the way';
      case OrderStatus.delivered:
        return 'Delivered';
    }
  }

  Color _getStatusColor(OrderStatus status) {
    switch (status) {
      case OrderStatus.confirmed:
        return CupertinoColors.activeBlue;
      case OrderStatus.preparing:
        return CupertinoColors.activeOrange;
      case OrderStatus.onTheWay:
        return CupertinoColors.systemGreen;
      case OrderStatus.delivered:
        return CupertinoColors.systemGrey;
    }
  }

  String _formatDate(DateTime date) {
    return '${date.month}/${date.day}/${date.year}';
  }

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
            colors: [
              CupertinoColors.activeOrange.withValues(alpha: 0.05),
              const Color(0xFFF2F2F7)
            ],
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
                            color: CupertinoColors.systemGrey.withValues(alpha: 0.1),
                            blurRadius: 20,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: const Icon(
                        CupertinoIcons.clock,
                        size: 50,
                        color: CupertinoColors.activeOrange,
                      ),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'No Orders Yet',
                      style: TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Your orders will appear here',
                      style: TextStyle(fontSize: 15, color: CupertinoColors.systemGrey),
                    ),
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
                    border: Border.all(
                      color: CupertinoColors.systemGrey5,
                      width: 1,
                    ),
                  ),
                  child: CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: () {
                      print("Navigating to tracking for order: ${order.id}");
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
                              Text(
                                'Order #${order.id.substring(0, 6)}',
                                style: const TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 8,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: _getStatusColor(order.status).withValues(alpha: 0.1),
                                  borderRadius: BorderRadius.circular(8),
                                ),
                                child: Text(
                                  _getStatusText(order.status),
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: _getStatusColor(order.status),
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            order.items
                                .map((item) => '${item.quantity}x ${item.name}')
                                .join(', '),
                            style: TextStyle(
                              fontSize: 13,
                              color: CupertinoColors.systemGrey,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                          const SizedBox(height: 8),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '\$${order.totalAmount.toStringAsFixed(2)}',
                                style: const TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  color: CupertinoColors.activeOrange,
                                ),
                              ),
                              Text(
                                _formatDate(order.orderDate),
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
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}