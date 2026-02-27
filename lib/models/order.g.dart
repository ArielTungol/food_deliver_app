// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'order.dart';

// **************************************************************************
// TypeAdapterGenerator
// **************************************************************************

class OrderItemAdapter extends TypeAdapter<OrderItem> {
  @override
  final int typeId = 1;

  @override
  OrderItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return OrderItem(
      name: fields[0] as String,
      price: fields[1] as double,
      quantity: fields[2] as int,
    );
  }

  @override
  void write(BinaryWriter writer, OrderItem obj) {
    writer
      ..writeByte(3)
      ..writeByte(0)
      ..write(obj.name)
      ..writeByte(1)
      ..write(obj.price)
      ..writeByte(2)
      ..write(obj.quantity);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderAdapter extends TypeAdapter<Order> {
  @override
  final int typeId = 2;

  @override
  Order read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return Order(
      id: fields[0] as String,
      orderDate: fields[1] as DateTime,
      items: (fields[2] as List).cast<OrderItem>(),
      totalAmount: fields[3] as double,
      status: fields[4] as OrderStatus,
      deliveryAddress: fields[5] as String,
      deliveryLat: fields[6] as double,
      deliveryLng: fields[7] as double,
    );
  }

  @override
  void write(BinaryWriter writer, Order obj) {
    writer
      ..writeByte(8)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.orderDate)
      ..writeByte(2)
      ..write(obj.items)
      ..writeByte(3)
      ..write(obj.totalAmount)
      ..writeByte(4)
      ..write(obj.status)
      ..writeByte(5)
      ..write(obj.deliveryAddress)
      ..writeByte(6)
      ..write(obj.deliveryLat)
      ..writeByte(7)
      ..write(obj.deliveryLng);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}

class OrderStatusAdapter extends TypeAdapter<OrderStatus> {
  @override
  final int typeId = 0;

  @override
  OrderStatus read(BinaryReader reader) {
    switch (reader.readByte()) {
      case 0:
        return OrderStatus.confirmed;
      case 1:
        return OrderStatus.preparing;
      case 2:
        return OrderStatus.onTheWay;
      case 3:
        return OrderStatus.delivered;
      default:
        return OrderStatus.confirmed;
    }
  }

  @override
  void write(BinaryWriter writer, OrderStatus obj) {
    switch (obj) {
      case OrderStatus.confirmed:
        writer.writeByte(0);
        break;
      case OrderStatus.preparing:
        writer.writeByte(1);
        break;
      case OrderStatus.onTheWay:
        writer.writeByte(2);
        break;
      case OrderStatus.delivered:
        writer.writeByte(3);
        break;
    }
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is OrderStatusAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
