import 'package:cloud_firestore/cloud_firestore.dart';

/// A privacy-safe preview of a delivery that has not been assigned yet.
class DeliveryJobModel {
  final String orderId;
  final String deliveryArea;
  final String deliveryTimeSlot;
  final DateTime? requestedDeliveryDate;
  final DateTime createdAt;

  const DeliveryJobModel({
    required this.orderId,
    required this.deliveryArea,
    required this.deliveryTimeSlot,
    this.requestedDeliveryDate,
    required this.createdAt,
  });

  factory DeliveryJobModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return DeliveryJobModel(
      orderId: (map['orderId'] ?? documentId).toString(),
      deliveryArea: (map['deliveryArea'] ?? 'Kuala Lumpur delivery area')
          .toString(),
      deliveryTimeSlot: (map['deliveryTimeSlot'] ?? '').toString(),
      requestedDeliveryDate: (map['requestedDeliveryDate'] as Timestamp?)
          ?.toDate(),
      createdAt: (map['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
    );
  }
}
