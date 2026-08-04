import 'package:cloud_firestore/cloud_firestore.dart';

class OrderModel {
  final String orderId;
  final String customerId;
  final String? floristId;
  final String? riderId;
  final double totalAmount;
  final String orderStatus; // Pending, Accepted, Preparing, Out for Delivery, Delivered, Cancelled
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddress;
  final DateTime deliveryDate;
  final String deliveryTimeSlot;
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
    required this.deliveryDate,
    required this.deliveryTimeSlot,
    required this.createdAt,
  });

  Map<String, dynamic> toMap() {
    return {
      'orderId': orderId,
      'customerId': customerId,
      'floristId': floristId,
      'riderId': riderId,
      'totalAmount': totalAmount,
      'orderStatus': orderStatus,
      'recipientName': recipientName,
      'recipientPhone': recipientPhone,
      'deliveryAddress': deliveryAddress,
      'deliveryDate': Timestamp.fromDate(deliveryDate),
      'deliveryTimeSlot': deliveryTimeSlot,
      'createdAt': Timestamp.fromDate(createdAt),
    };
  }

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
      deliveryDate: (map['deliveryDate'] as Timestamp?)?.toDate() ?? DateTime.now(),
      deliveryTimeSlot: map['deliveryTimeSlot'] ?? '',
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}