import 'package:cloud_functions/cloud_functions.dart';

class OrderService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  Future<List<String>> placeOrder(Map<String, dynamic> request) async {
    final result = await _functions.httpsCallable('placeOrder').call(request);
    return List<String>.from(result.data['orderIds'] as List);
  }

  Future<void> transition(String orderId, String action) async {
    await _functions.httpsCallable('transitionOrder').call({
      'orderId': orderId,
      'action': action,
    });
  }

  static String message(Object error) {
    if (error is FirebaseFunctionsException) {
      if (error.code == 'not-found') {
        return 'The order service is not deployed yet. Please contact the store.';
      }
      if (error.code == 'unavailable' || error.code == 'deadline-exceeded') {
        return 'Connection interrupted. Retry to check your order safely.';
      }
      return error.message ?? 'Unable to finish. Please retry.';
    }
    return 'Unable to finish. Please check your connection and retry.';
  }
}
