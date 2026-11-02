import 'package:cloud_functions/cloud_functions.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../../models/delivery_job_model.dart';
import 'order_service.dart';

class AvailableDeliveryPage {
  const AvailableDeliveryPage({
    required this.deliveries,
    this.nextCursor,
    this.activeDeliveryId,
    this.contactReady = true,
  });
  final List<DeliveryJobModel> deliveries;
  final Map<String, dynamic>? nextCursor;
  final String? activeDeliveryId;
  final bool contactReady;
}

class DeliveryService {
  static Stream<void> queueChanges() => FirebaseFirestore.instance
      .doc('delivery_queue/current')
      .snapshots()
      .map((_) {});

  static String message(Object error) {
    if (error is FirebaseFunctionsException) {
      return switch (error.code) {
        'not-found' =>
          'The delivery list is currently unavailable. Please contact the store.',
        'permission-denied' =>
          'Your account does not have rider access. Please contact the store.',
        'unavailable' || 'deadline-exceeded' =>
          'Cannot connect to the delivery list. Check your connection and retry.',
        'internal' =>
          'Unable to load available deliveries. Please retry or contact the store.',
        _ => OrderService.message(error),
      };
    }
    return OrderService.message(error);
  }

  Future<AvailableDeliveryPage> available(Map<String, dynamic>? cursor) async {
    final response = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('listAvailableDeliveries').call({'cursor': cursor});
    final data = Map<String, dynamic>.from(response.data as Map);
    return AvailableDeliveryPage(
      deliveries: (data['deliveries'] as List).map((item) {
        final value = Map<String, dynamic>.from(item as Map);
        return DeliveryJobModel.fromMap(value, value['orderId'] as String);
      }).toList(),
      nextCursor: data['nextCursor'] == null
          ? null
          : Map<String, dynamic>.from(data['nextCursor'] as Map),
      activeDeliveryId: data['activeDeliveryId'] as String?,
      contactReady: data['contactReady'] != false,
    );
  }
}
