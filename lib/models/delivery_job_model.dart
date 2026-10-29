import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:intl/intl.dart';
import '../core/constants/store_details.dart';

/// Rider-visible order destination, without recipient contact or map coordinates.
class DeliveryJobModel {
  final String orderId;
  final String deliveryArea;
  final String deliveryAddress;
  final String orderStatus;
  bool get readyForPickup => orderStatus == 'Ready for Delivery';
  final String deliveryTimeSlot;
  final DateTime? requestedDeliveryDate;
  final DateTime createdAt;
  final String locality, postcode, state, pickupName, pickupAddress;
  final String? estimatedDispatchDate, scheduledDeliveryDate;
  final int itemCount;

  const DeliveryJobModel({
    required this.orderId,
    required this.deliveryArea,
    this.deliveryAddress = '',
    this.orderStatus = 'Ready for Delivery',
    required this.deliveryTimeSlot,
    this.requestedDeliveryDate,
    required this.createdAt,
    this.locality = '',
    this.postcode = '',
    this.state = '',
    this.pickupName = StoreDetails.name,
    this.pickupAddress = StoreDetails.pickupAddress,
    this.estimatedDispatchDate,
    this.scheduledDeliveryDate,
    this.itemCount = 0,
  });

  String get reference =>
      '#${orderId.substring(0, orderId.length.clamp(0, 8)).toUpperCase()}';
  bool get hasDeliveryAddress => deliveryAddress.trim().isNotEmpty;
  String get destination => hasDeliveryAddress
      ? deliveryAddress.trim()
      : locality.isNotEmpty
      ? [locality, postcode].where((value) => value.isNotEmpty).join(' · ')
      : deliveryArea.contains('Malaysia') ||
            deliveryArea.toLowerCase().contains('delivery area')
      ? 'Area needs confirmation'
      : deliveryArea;
  bool get areaNeedsConfirmation => destination == 'Area needs confirmation';
  // Legacy orders also stored estimated dates in requestedDeliveryDate.
  bool get hasRequestedDate => scheduledDeliveryDate != null;
  DateTime? get deliveryDate =>
      _date(scheduledDeliveryDate) ??
      _date(estimatedDispatchDate) ??
      requestedDeliveryDate;
  static DateTime _day(DateTime value) {
    final malaysia = value.toUtc().add(const Duration(hours: 8));
    return DateTime.utc(malaysia.year, malaysia.month, malaysia.day);
  }

  String timingLabel({DateTime? now}) {
    final date = deliveryDate;
    if (date == null) {
      return deliveryTimeSlot.isEmpty
          ? 'Timing: confirm with store'
          : deliveryTimeSlot;
    }
    final day = _day(date), today = _day(now ?? DateTime.now());
    final prefix = day == today
        ? 'Today, '
        : day == today.add(const Duration(days: 1))
        ? 'Tomorrow, '
        : '';
    return '${hasRequestedDate ? 'Requested delivery' : 'Estimated dispatch'}: $prefix${DateFormat(day.year == today.year ? 'd MMM' : 'd MMM yyyy').format(day)}';
  }

  String? dateWarning({DateTime? now}) =>
      deliveryDate != null &&
          _day(deliveryDate!).isBefore(_day(now ?? DateTime.now()))
      ? hasRequestedDate
            ? 'Requested date passed'
            : 'Dispatch date passed'
      : null;

  static DateTime? _date(dynamic value) => value is Timestamp
      ? value.toDate()
      : value is num
      ? DateTime.fromMillisecondsSinceEpoch(value.toInt())
      : value is String && RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(value)
      ? DateTime.tryParse('${value}T00:00:00Z')
      : null;

  factory DeliveryJobModel.fromMap(
    Map<String, dynamic> map,
    String documentId,
  ) {
    return DeliveryJobModel(
      orderId: (map['orderId'] ?? documentId).toString(),
      orderStatus: (map['orderStatus'] ?? 'Ready for Delivery').toString(),
      deliveryArea: (map['deliveryArea'] ?? 'Area needs confirmation')
          .toString(),
      deliveryAddress: (map['deliveryAddress'] ?? '').toString(),
      deliveryTimeSlot: (map['deliveryTimeSlot'] ?? '').toString(),
      requestedDeliveryDate: _date(map['requestedDeliveryDate']),
      createdAt: _date(map['createdAt']) ?? DateTime.now(),
      locality: (map['deliveryLocality'] ?? '').toString(),
      postcode: (map['deliveryPostcode'] ?? '').toString(),
      state: (map['deliveryState'] ?? '').toString(),
      pickupName: (map['pickupName'] ?? StoreDetails.name).toString(),
      pickupAddress: (map['pickupAddress'] ?? StoreDetails.pickupAddress)
          .toString(),
      itemCount: (map['itemCount'] as num?)?.toInt() ?? 0,
      estimatedDispatchDate: map['estimatedDispatchDate'] as String?,
      scheduledDeliveryDate: map['scheduledDeliveryDate'] as String?,
    );
  }
}
