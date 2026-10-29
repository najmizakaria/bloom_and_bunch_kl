import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/address_service.dart';
import '../../../core/services/checkout_service.dart';
import '../../../core/services/order_service.dart';
import '../../../core/services/app_monitoring.dart';
import '../../../core/widgets/action_confirmation.dart';
import '../../../core/widgets/app_note.dart';
import '../../../models/saved_address_model.dart';
import 'address_book_screen.dart';
import 'order_tracking_screen.dart';
import 'payment_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({
    super.key,
    this.addressService,
    this.checkoutService,
    this.orderService,
    this.currentUserId,
  });
  final AddressService? addressService;
  final CheckoutService? checkoutService;
  final OrderService? orderService;
  final String? Function()? currentUserId;
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  SavedAddressModel? _address;
  CheckoutQuote? _quote;
  String? _quotedCartId, _error;
  bool _loading = true, _busy = false;
  int _generation = 0;
  String? get _uid => widget.currentUserId != null
      ? widget.currentUserId!()
      : FirebaseAuth.instance.currentUser?.uid;
  @override
  void initState() {
    super.initState();
    AppMonitoring.event('checkout_started');
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final uid = _uid;
    try {
      final pending = context.read<CartProvider>().pendingRequest;
      var address = pending == null
          ? await (widget.addressService ?? AddressService()).defaultAddress()
          : SavedAddressModel.fromMap(
              Map<String, dynamic>.from(pending['address'] as Map),
              pending['addressId'] as String,
            );
      if (!mounted || uid != _uid) return;
      address ??= await AddressBookScreen.create(context);
      if (!mounted || uid != _uid) return;
      _address = address;
      if (pending != null) {
        _quote = pending['quote'] is Map
            ? CheckoutQuote(Map<String, dynamic>.from(pending['quote'] as Map))
            : null;
      } else if (address != null) {
        await _refreshQuote();
      }
    } catch (e) {
      if (mounted && uid == _uid) {
        setState(() => _error = OrderService.message(e));
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _refreshQuote() async {
    final cart = context.read<CartProvider>();
    if (cart.hasPendingCheckout || _address == null || cart.isEmpty) return;
    final generation = ++_generation, cartId = cart.checkoutId, uid = _uid;
    setState(() {
      _loading = true;
      _quote = null;
      _error = null;
    });
    try {
      await cart.flush();
      final quote =
          await (widget.checkoutService ??
                  CheckoutService(messageCards: cart.messageCards))
              .quote(cart.items, _address!);
      if (mounted &&
          generation == _generation &&
          uid == _uid &&
          cartId == cart.checkoutId) {
        setState(() {
          _quote = quote;
          _quotedCartId = cartId;
        });
      }
    } catch (e) {
      if (mounted && generation == _generation && uid == _uid) {
        setState(() => _error = OrderService.message(e));
      }
    } finally {
      if (mounted && generation == _generation) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _change() async {
    final uid = _uid;
    final a = await Navigator.push<SavedAddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressBookScreen(selectionMode: true),
      ),
    );
    if (!mounted || a == null || uid != _uid) return;
    context.read<CartProvider>().resetCheckout();
    setState(() {
      _address = a;
      _error = null;
    });
    await _refreshQuote();
  }

  Future<void> _place(CartProvider cart) async {
    if (_busy ||
        _loading ||
        _address == null ||
        cart.isEmpty ||
        (!cart.hasPendingCheckout &&
            (_quote == null || _quotedCartId != cart.checkoutId))) {
      return;
    }
    setState(() {
      _busy = true;
      _error = null;
    });
    final uid = _uid;
    try {
      if (!cart.hasPendingCheckout) {
        final confirmed = await confirmAction(
          context,
          title: 'Place Order',
          message:
              'Confirm the delivery address and total RM ${((_quote?.totalSen ?? 0) / 100).toStringAsFixed(2)}. ${_quote?.usesToyyibpay == true ? 'Next, continue to payment. Preparation starts only after payment is verified.' : 'Submitting an order does not confirm payment.'}',
          action: 'Confirm order',
        );
        if (!confirmed || !mounted || uid != _uid) return;
        if (_quotedCartId != cart.checkoutId) {
          throw StateError(
            'Your cart changed. Refresh the order summary before confirming.',
          );
        }
      }
      final request = await cart.prepareCheckout({
        'checkoutId': cart.checkoutId,
        'items': cart.items.map((i) => i.toMap()).toList(),
        'messageCards': cart.messageCards,
        'cartSync': cart.cloudSyncEnabled,
        'expectedTotal': (_quote?.totalSen ?? 0) / 100,
        'quoteId': _quote?.id,
        'quote': _quote?.data,
        'addressId': _address!.id,
        'address': _address!.toMap(),
      });
      if (uid == null || _uid != uid) return;
      final ids = await (widget.orderService ?? OrderService()).placeOrder(
        request,
      );
      if (_uid != uid) return;
      final onlinePayment =
          _quote?.usesToyyibpay == true ||
          (request['quote'] is Map &&
              request['quote']['mode'] == 'toyyibpay_sandbox');
      cart.checkoutSucceeded();
      AppMonitoring.event('checkout_confirmed');
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => onlinePayment
              ? PaymentScreen(orderId: ids.first)
              : OrderTrackingScreen(orderId: ids.first, relatedOrderIds: ids),
        ),
      );
    } catch (e) {
      if (_uid != uid) return;
      AppMonitoring.event('checkout_failed');
      if (e is FirebaseFunctionsException &&
          [
            'invalid-argument',
            'failed-precondition',
            'permission-denied',
            'not-found',
          ].contains(e.code)) {
        cart.checkoutRejected();
        _quote = null;
      }
      if (mounted) setState(() => _error = OrderService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    final stale = !cart.hasPendingCheckout && _quotedCartId != cart.checkoutId;
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Review your order'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const SizedBox(height: 16),
          Text(
            'Recipient and delivery address',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: 8),
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _address == null
                        ? 'Choose or add an address to check delivery.'
                        : '${_address!.recipientName} · ${_address!.recipientPhone}\n${_address!.address}',
                  ),
                  TextButton(
                    onPressed: _busy || _loading || cart.hasPendingCheckout
                        ? null
                        : _change,
                    child: const Text('Change address'),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Your deliveries',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          for (final ready in [true, false])
            if (_quote == null &&
                cart.items.any(
                  (i) => (i.fulfillmentType == 'ready_now') == ready,
                ))
              Card(
                margin: const EdgeInsets.only(top: 12),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        ready ? 'Ready bouquets' : 'Made-to-order bouquets',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      for (final i in cart.items.where(
                        (i) => (i.fulfillmentType == 'ready_now') == ready,
                      ))
                        Padding(
                          padding: const EdgeInsets.only(top: 8),
                          child: Text(
                            '${i.name} × ${i.quantity} · RM ${i.lineTotal.toStringAsFixed(2)}',
                          ),
                        ),
                    ],
                  ),
                ),
              ),
          if (_loading)
            const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()),
            ),
          if (_quote != null && (!stale || cart.hasPendingCheckout))
            CheckoutSummary(quote: _quote!),
          if (cart.hasPendingCheckout)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                'Your previous submission needs confirmation. Check it below before making changes. This checks the same order; it does not create a second one.',
              ),
            ),
          if (_error != null)
            Semantics(
              liveRegion: true,
              child: Padding(
                padding: const EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            ),
          if (!_loading &&
              !cart.hasPendingCheckout &&
              (_quote == null || stale))
            OutlinedButton(
              onPressed: _busy ? null : _load,
              child: const Text('Refresh address and order summary'),
            ),
          const SizedBox(height: 16),
          FilledButton(
            key: const Key('confirm-order'),
            onPressed:
                _busy ||
                    _loading ||
                    _address == null ||
                    cart.isEmpty ||
                    (!cart.hasPendingCheckout && (_quote == null || stale))
                ? null
                : () => _place(cart),
            child: Text(
              _busy
                  ? 'Checking your order…'
                  : cart.hasPendingCheckout
                  ? 'Check existing order'
                  : _loading
                  ? 'Loading order summary…'
                  : _quote == null || stale
                  ? 'Order summary unavailable'
                  : _quote?.usesToyyibpay == true
                  ? 'Continue to payment'
                  : 'Place Order',
            ),
          ),
          const SizedBox(height: 12),
          const AppNote(
            'Submitting an order is not confirmation of payment. Keep your order reference for any questions.',
          ),
        ],
      ),
    );
  }
}

class CheckoutSummary extends StatelessWidget {
  const CheckoutSummary({super.key, required this.quote});
  final CheckoutQuote quote;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      const SizedBox(height: 16),
      for (final g in quote.groups) ...[
        for (final item in (g['items'] as List? ?? []))
          Text(
            '${item['name']} × ${item['quantity']} · RM ${((item['unitPrice'] as num) * (item['quantity'] as num)).toStringAsFixed(2)}',
          ),
        Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: Text(
            '${g['scheduled'] == true ? 'Requested delivery' : 'Estimated dispatch'}: ${g['date']}',
          ),
        ),
      ],
      AppNote(quote.timingNotice),
      if (quote.groups.length > 1)
        const AppNote(
          'These items travel separately. The total below includes all bouquets.',
        ),
      const SizedBox(height: 20),
      Text('Payment', style: Theme.of(context).textTheme.titleLarge),
      AppNote(quote.paymentInstructions),
      const SizedBox(height: 16),
      Text('Items: ${CheckoutQuote.money(quote.data['subtotalSen'] as num)}'),
      if ((quote.data['cardFeeSen'] as num? ?? 0) > 0)
        Text(
          'Message cards: ${CheckoutQuote.money(quote.data['cardFeeSen'] as num)}',
        ),
      Text(
        'Total: ${CheckoutQuote.money(quote.totalSen)}',
        style: Theme.of(context).textTheme.titleLarge,
      ),
    ],
  );
}
