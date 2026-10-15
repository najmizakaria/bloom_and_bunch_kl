import 'package:cloud_firestore/cloud_firestore.dart';

import '../core/constants/fulfillment_constants.dart';

class OrderModel {
  static String _normalizedStatus(String? s) =>
      s == 'Pending' || s == null ? 'Awaiting Preparation' : s;
  final String orderId;
  final String customerId;
  final String? floristId;
  final String? riderId;
  final double totalAmount;
  final String orderStatus;
  final String fulfillmentType;
  final String recipientName;
  final String recipientPhone;
  final String deliveryAddress;
  final String deliveryNote;
  final String? addressId;
  final double? latitude, longitude;
  final String deliveryTimeSlot;
  final DateTime? requestedDeliveryDate;
  final int leadTimeBusinessDays;
  final bool requiresPrepTime;
  final List<Map<String, dynamic>> items;
  final DateTime createdAt;
  final int deliveryWorkflowVersion;
  final DateTime? customerAcceptedAt;
  final bool hasOpenIssue;
  final String orderMode, paymentStatus;
  bool get paymentOnHold =>
      orderMode == 'toyyibpay_sandbox' && paymentStatus != 'paid';
  bool get receiptConfirmed => customerAcceptedAt != null;

  const OrderModel({
    required this.orderId,
    required this.customerId,
    this.floristId,
    this.riderId,
    required this.totalAmount,
    required this.orderStatus,
    required this.fulfillmentType,
    required this.recipientName,
    required this.recipientPhone,
    required this.deliveryAddress,
    required this.deliveryNote,
    this.addressId,
    this.latitude,
    this.longitude,
    required this.deliveryTimeSlot,
    this.requestedDeliveryDate,
    required this.leadTimeBusinessDays,
    required this.requiresPrepTime,
    required this.items,
    required this.createdAt,
    this.deliveryWorkflowVersion = 1,
    this.customerAcceptedAt,
    this.hasOpenIssue = false,
    this.orderMode = '',
    this.paymentStatus = '',
  });

  factory OrderModel.fromMap(Map<String, dynamic> map, String documentId) {
    final requiresPreparation = map['requiresPrepTime'] as bool? ?? false;

    final explicitFulfillmentType = map['fulfillmentType']?.toString();

    final inferredFulfillmentType = requiresPreparation
        ? FulfillmentTypes.custom
        : FulfillmentTypes.readyNow;

    return OrderModel(
      orderId: documentId,
      orderMode: (map['orderMode'] ?? '').toString(),
      paymentStatus: (map['paymentStatus'] ?? '').toString(),
      hasOpenIssue: map['support'] is Map && map['support']['status'] == 'open',
      deliveryWorkflowVersion:
          (map['deliveryWorkflowVersion'] as num?)?.toInt() ?? 1,
      customerAcceptedAt: (map['customerAcceptedAt'] as Timestamp?)?.toDate(),
      customerId: (map['customerId'] ?? '').toString(),
      floristId: map['floristId']?.toString(),
      riderId: map['riderId']?.toString(),
      totalAmount: (map['totalAmount'] as num?)?.toDouble() ?? 0,
      orderStatus: _normalizedStatus(map['orderStatus']?.toString()),
      fulfillmentType: FulfillmentTypes.values.contains(explicitFulfillmentType)
          ? explicitFulfillmentType!
          : inferredFulfillmentType,
      recipientName: (map['recipientName'] ?? '').toString(),
      recipientPhone: (map['recipientPhone'] ?? '').toString(),
      deliveryAddress: (map['deliveryAddress'] ?? '').toString(),
      deliveryNote: (map['deliveryNote'] ?? '').toString(),
      addressId: map['addressId']?.toString(),
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      deliveryTimeSlot: (map['deliveryTimeSlot'] ?? '').toString(),
      requestedDeliveryDate: (map['requestedDeliveryDate'] as Timestamp?)
          ?.toDate(),
      leadTimeBusinessDays: (map['leadTimeBusinessDays'] as num?)?.toInt() ?? 0,
      requiresPrepTime: requiresPreparation,
      items: (map['items'] as List<dynamic>? ?? const [])
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList(),
      createdAt:
          (map['createdAt'] as Timestamp?)?.toDate() ??
          DateTime.fromMillisecondsSinceEpoch(0),
    );
  }
}
