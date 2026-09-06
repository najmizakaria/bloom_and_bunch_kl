import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String orderId;
  final String customerId;
  final String? floristId;
  final String? riderId;
  final double totalAmount;
  final String orderStatus; // Pending, Processing, Ready for Delivery, Completed
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddress;
  final String deliveryTimeSlot;
  final bool requiresPrepTime;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;

  OrderModel({
    required this.orderId,
    required this.customerId,
    this.floristId,
    this.riderId,
    required this.totalAmount,
    required this.orderStatus,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryAddress,
    required this.deliveryTimeSlot,
    required this.requiresPrepTime,
    required this.items,
    required this.createdAt,
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String docId) {
    return OrderModel(
      orderId: docId,
      customerId: map['customerId'] ?? '',
      floristId: map['floristId'],
      riderId: map['riderId'],
      totalAmount: (map['totalAmount'] ?? 0.0).toDouble(),
      orderStatus: map['orderStatus'] ?? 'Pending',
      recipientName: map['recipientName'] ?? '',
      recipientPhone: map['recipientPhone'] ?? '',
      deliveryAddress: map['deliveryAddress'] ?? '',
      deliveryTimeSlot: map['deliveryTimeSlot'] ?? '10:00 AM - 2:00 PM',
      requiresPrepTime: map['requiresPrepTime'] ?? false,
      items: (map['items'] as List<dynamic>? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}