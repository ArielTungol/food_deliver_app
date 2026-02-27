import 'package:hive/hive.dart';

part 'order.g.dart';  // This links to the generated file

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