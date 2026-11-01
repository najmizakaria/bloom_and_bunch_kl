import 'package:cloud_functions/cloud_functions.dart';

class OrderService {
  final FirebaseFunctions _functions = FirebaseFunctions.instanceFor(
    region: 'asia-southeast1',
  );

  Future<List<String>> placeOrder(Map<String, dynamic> request) async {
    final result = await _functions.httpsCallable('placeOrder').call(request);
    final ids = List<String>.from(result.data['orderIds'] as List);
    if (ids.isEmpty) throw StateError('Missing order confirmation.');
    return ids;
  }

  Future<void> transition(
    String orderId,
    String action, {
    Map<String, dynamic> details = const {},
  }) async {
    await _functions.httpsCallable('transitionOrder').call({
      'orderId': orderId,
      'action': action,
      ...details,
    });
  }

  static String message(Object error) {
    if (error is StateError) return error.message.toString();
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
