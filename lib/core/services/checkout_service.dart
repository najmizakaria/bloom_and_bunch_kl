import 'package:cloud_functions/cloud_functions.dart';
import '../../models/saved_address_model.dart';
import '../../models/cart_item_model.dart';
import '../constants/payment_modes.dart';

class CheckoutQuote {
  final Map<String, dynamic> data;
  CheckoutQuote(Map<String, dynamic> value)
    : data = Map<String, dynamic>.from(value);
  String get id => data['quoteId'] as String;
  bool get usesToyyibpay => data['mode'] == 'toyyibpay_sandbox';
  bool get usesStripe => isStripePaymentMode(data['mode']);
  bool get usesOnlinePayment => isOnlinePaymentMode(data['mode']);
  bool get supportsCardPayment => data['paymentMethod'] == 'card';
  int get totalSen => (data['totalSen'] as num).toInt();
  List<Map<String, dynamic>> get groups => (data['groups'] as List)
      .map((g) => Map<String, dynamic>.from(g as Map))
      .toList();
  static String money(num sen) => 'RM ${(sen / 100).toStringAsFixed(2)}';
}

class CheckoutService {
  CheckoutService({Map<String, Map<String, dynamic>> messageCards = const {}})
    : _messageCards = Map.unmodifiable(messageCards);
  final Map<String, Map<String, dynamic>> _messageCards;
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
          'messageCards': _messageCards,
        });
    return CheckoutQuote(Map<String, dynamic>.from(result.data as Map));
  }
}
