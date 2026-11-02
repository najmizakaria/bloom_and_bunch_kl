import 'package:cloud_functions/cloud_functions.dart';
import '../utils/rider_phone.dart';

class RiderContact {
  const RiderContact({required this.name, required this.phone});
  final String name, phone;
}

class RiderContactService {
  static String message(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'failed-precondition') {
        return 'Rider contact is unavailable. Please call the florist.';
      }
      if (error.code == 'permission-denied' ||
          error.code == 'unauthenticated') {
        return 'Please sign in to the account that placed this order.';
      }
      return 'Could not load the rider contact. Please try again or call the florist.';
    }
    if (error is StateError) {
      return error.message.toString().replaceFirst(
        RegExp(r'\s*\[\d{3}\]\s*$'),
        '',
      );
    }
    return 'Rider contact is unavailable. Please call the florist.';
  }

  Future<RiderContact> getForOrder(String orderId) async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable('getAssignedRiderContact').call({'orderId': orderId});
    final data = Map<String, dynamic>.from(result.data as Map);
    return RiderContact(
      name: data['name'] as String,
      phone: RiderPhone.normalize(data['phone'] as String),
    );
  }
}
