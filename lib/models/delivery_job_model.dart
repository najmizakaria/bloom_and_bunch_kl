import 'package:cloud_firestore/cloud_firestore.dart';

/// A privacy-safe preview of a delivery that has not been assigned yet.
class DeliveryJobModel {
  final String orderId;
  final String deliveryArea;
  final String orderStatus;
  bool get readyForPickup => orderStatus == 'Ready for Delivery';
  final String deliveryTimeSlot;
  final DateTime? requestedDeliveryDate;
  final DateTime createdAt;

  const DeliveryJobModel({
    required this.orderId,
    required this.deliveryArea,
    this.orderStatus = 'Ready for Delivery',
    required this.deliveryTimeSlot,
    this.requestedDeliveryDate,
    required this.createdAt,
  });

  static DateTime? _date(dynamic value) => value is Timestamp
      ? value.toDate()
      : value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : null;

  factory DeliveryJobModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return DeliveryJobModel(
      orderId: (map['orderId'] ?? documentId).toString(),
      orderStatus: (map['orderStatus'] ?? 'Ready for Delivery').toString(),
      deliveryArea: (map['deliveryArea'] ?? 'Kuala Lumpur delivery area')
          .toString(),
      deliveryTimeSlot: (map['deliveryTimeSlot'] ?? '').toString(),
      requestedDeliveryDate: _date(map['requestedDeliveryDate']),
      createdAt: _date(map['createdAt']) ?? DateTime.now(),
    );
  }
}
