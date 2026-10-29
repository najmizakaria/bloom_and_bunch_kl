import 'dart:async';
import 'package:app_links/app_links.dart';
import 'package:flutter/foundation.dart';

// Links identify a payment only. Status, amounts and ownership come from the
// authenticated backend, never from the browser's return parameters.
String? paymentIdFromLink(Uri uri) {
  if (uri.scheme != 'bloombunch' ||
      uri.host != 'payment-return' ||
      uri.path.isNotEmpty ||
      uri.userInfo.isNotEmpty ||
      uri.hasPort ||
      uri.hasFragment) {
    return null;
  }
  final ids = uri.queryParametersAll['payment_id'];
  if (ids == null ||
      ids.length != 1 ||
      !RegExp(r'^[a-f0-9]{64}$').hasMatch(ids.single)) {
    return null;
  }
  return ids.single;
}

class PaymentLinks extends ValueNotifier<String?> {
  PaymentLinks() : super(null);
  StreamSubscription<Uri>? _subscription;

  // Start before Firebase initialization so a cold-start link is retained.
  void start() {
    _subscription ??= AppLinks().uriLinkStream.listen((uri) {
      final id = paymentIdFromLink(uri);
      if (id != null) value = id;
    }, onError: (Object _) {});
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
