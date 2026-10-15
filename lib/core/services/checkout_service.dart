import 'package:cloud_functions/cloud_functions.dart';
import '../../models/saved_address_model.dart';
import '../../models/cart_item_model.dart';

class CheckoutQuote {
  final Map<String, dynamic> data;
  CheckoutQuote(Map<String, dynamic> value)
    : data = Map<String, dynamic>.from(value);
  String get id => data['quoteId'] as String;
  bool get isDemo => data['mode'] == 'demo';
  bool get usesToyyibpay => data['mode'] == 'toyyibpay_sandbox';
  int get totalSen => (data['totalSen'] as num).toInt();
  List<Map<String, dynamic>> get groups => (data['groups'] as List)
      .map((g) => Map<String, dynamic>.from(g as Map))
      .toList();
  String get paymentInstructions => isDemo
      ? 'Submitting an order does not confirm payment. Contact the store for payment arrangements.'
      : data['paymentInstructions'] as String;
  String get timingNotice => isDemo
      ? 'Estimated dispatch dates depend on preparation and rider availability.'
      : data['timingNotice'] as String;
  static String money(num sen) => 'RM ${(sen / 100).toStringAsFixed(2)}';
}

class CheckoutService {
  Future<CheckoutQuote> quote(
    List<CartItemModel> items,
    SavedAddressModel address,
  ) async {
    final result =
        await FirebaseFunctions.instanceFor(
          region: 'asia-southeast1',
        ).httpsCallable('quoteCheckout').call({
          'items': items.map((i) => i.toMap()).toList(),
          'address': address.toMap(),
        });
    return CheckoutQuote(Map<String, dynamic>.from(result.data as Map));
  }
}
