import 'package:cloud_functions/cloud_functions.dart';

class PaymentSession {
  const PaymentSession({
    required this.id,
    required this.status,
    required this.totalSen,
    required this.orderIds,
    this.paymentUrl,
    this.expiresAt,
  });
  final String id, status;
  final int totalSen;
  final List<String> orderIds;
  final String? paymentUrl;
  final DateTime? expiresAt;

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
    expiresAt: data['expiresAt'] == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(
            (data['expiresAt'] as num).toInt(),
          ),
  );
}

class PaymentService {
  Future<PaymentSession> _call(String name, String orderId) async {
    final result = await FirebaseFunctions.instanceFor(
      region: 'asia-southeast1',
    ).httpsCallable(name).call({'orderId': orderId});
    return PaymentSession.fromMap(
      Map<String, dynamic>.from(result.data as Map),
    );
  }

  Future<PaymentSession> check(String orderId) =>
      _call('checkToyyibpayPayment', orderId);
  Future<PaymentSession> start(String orderId) =>
      _call('createToyyibpayPayment', orderId);
}
