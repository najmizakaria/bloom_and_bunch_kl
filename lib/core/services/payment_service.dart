import 'package:cloud_functions/cloud_functions.dart';

class PaymentSession {
  const PaymentSession({
    required this.id,
    required this.status,
    required this.totalSen,
    required this.orderIds,
    this.paymentUrl,
    this.expiresAt,
    this.payerPhoneRequired = false,
  });
  final String id, status;
  final int totalSen;
  final List<String> orderIds;
  final String? paymentUrl;
  final DateTime? expiresAt;
  final bool payerPhoneRequired;

  bool get paid => status == 'paid';
  bool get needsReview =>
      ['creating', 'creation_unknown', 'needs_review'].contains(status);
  bool get canPay =>
      ['awaiting_bill', 'pending'].contains(status) &&
      (expiresAt == null || expiresAt!.isAfter(DateTime.now()));

  Uri? get checkoutUri {
    final uri = Uri.tryParse(paymentUrl ?? '');
    return uri != null &&
            uri.scheme == 'https' &&
            uri.host == 'dev.toyyibpay.com' &&
            uri.userInfo.isEmpty &&
            uri.port == 443 &&
            RegExp(r'^/[a-zA-Z0-9_-]+$').hasMatch(uri.path) &&
            !uri.hasQuery &&
            !uri.hasFragment
        ? uri
        : null;
  }

  factory PaymentSession.fromMap(Map<String, dynamic> data) => PaymentSession(
    id: data['paymentId'] as String,
    status: data['status'] as String,
    totalSen: (data['totalSen'] as num).toInt(),
    orderIds: List<String>.from(data['orderIds'] as List),
    paymentUrl: data['paymentUrl'] as String?,
    payerPhoneRequired: data['payerPhoneRequired'] == true,
    expiresAt: data['expiresAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (data['expiresAt'] as num).toInt(),
          ),
  );
}

class PaymentService {
  Future<PaymentSession> _call(
    String name,
    String? orderId, [
    Map<String, dynamic> fields = const {},
  ]) async {
    final result =
        await FirebaseFunctions.instanceFor(region: 'asia-southeast1')
            .httpsCallable(name)
            .call({'orderId': ?orderId, ...fields});
    return PaymentSession.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<PaymentSession> check(String orderId) =>
      _call('checkToyyibpayPayment', orderId);
  Future<PaymentSession> checkPayment(String paymentId) =>
      _call('checkToyyibpayPayment', null, {'paymentId': paymentId});
  Future<PaymentSession> start(String orderId, {String? payerPhone}) => _call(
    'createToyyibpayPayment',
    orderId,
    payerPhone == null || payerPhone.trim().isEmpty
        ? const {}
        : {'payerPhone': payerPhone.trim()},
  );
}
