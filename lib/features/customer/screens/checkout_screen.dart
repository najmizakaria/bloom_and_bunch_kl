import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/address_service.dart';
import '../../../core/services/order_service.dart';
import '../../../models/saved_address_model.dart';
import 'address_book_screen.dart';
import 'order_tracking_screen.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});
  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  SavedAddressModel? _address;
  bool _loading = true, _busy = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final pending = context.read<CartProvider>().pendingRequest;
      var a = pending == null
          ? await AddressService().defaultAddress()
          : SavedAddressModel.fromMap(
              Map<String, dynamic>.from(pending['address'] as Map),
              pending['addressId'] as String,
            );
      if (a == null && mounted) {
        a = await AddressBookScreen.create(context);
      }
      if (mounted) setState(() => _address = a);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load your saved address.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _change() async {
    final a = await Navigator.push<SavedAddressModel>(
      context,
      MaterialPageRoute(
        builder: (_) => const AddressBookScreen(selectionMode: true),
      ),
    );
    if (mounted &&
        a != null &&
        (a.id != _address?.id ||
            a.toMap().toString() != _address?.toMap().toString())) {
      context.read<CartProvider>().resetCheckout();
    }
    if (mounted && a != null) {
      setState(() {
        _address = a;
        _error = null;
      });
    }
  }

  Future<void> _place(CartProvider cart) async {
    if (_busy || _address == null || cart.isEmpty) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    final uid = FirebaseAuth.instance.currentUser?.uid;
    try {
      final request = await cart.prepareCheckout({
        'checkoutId': cart.checkoutId,
        'items': cart.items.map((i) => i.toMap()).toList(),
        'expectedTotal': cart.totalPrice,
        'addressId': _address!.id,
        'address': _address!.toMap(),
      });
      if (uid == null || FirebaseAuth.instance.currentUser?.uid != uid) return;
      final ids = await OrderService().placeOrder(request);
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      cart.checkoutSucceeded();
      if (!mounted) return;
      if (ids.length > 1) {
        await showDialog<void>(
          context: context,
          builder: (c) => AlertDialog(
            title: const Text('Two deliveries confirmed'),
            content: const Text(
              'Your ready bouquet will leave first. Your planned bouquet has its own preparation and delivery timeline. Both are in Order History.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(c),
                child: const Text('View urgent order'),
              ),
            ],
          ),
        );
      }
      if (!mounted) return;
      Navigator.pushReplacement(
        context,
        MaterialPageRoute(
          builder: (_) => OrderTrackingScreen(orderId: ids.first),
        ),
      );
    } catch (e) {
      if (FirebaseAuth.instance.currentUser?.uid != uid) return;
      if (e is FirebaseFunctionsException &&
          [
            'invalid-argument',
            'failed-precondition',
            'permission-denied',
            'not-found',
          ].contains(e.code)) {
        cart.checkoutRejected();
      }
      if (mounted) setState(() => _error = OrderService.message(e));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Checkout')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(20),
              children: [
                Text(
                  'Order summary',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                ...cart.items.map(
                  (i) => ListTile(
                    title: Text('${i.name} × ${i.quantity}'),
                    subtitle: Text(
                      i.fulfillmentType == 'ready_now'
                          ? 'Ready to Send'
                          : 'Prepared in ${i.leadTimeBusinessDays} business days',
                    ),
                    trailing: Text('RM ${i.lineTotal.toStringAsFixed(2)}'),
                  ),
                ),
                Text(
                  'Total RM ${cart.totalPrice.toStringAsFixed(2)}',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 20),
                Card(
                  child: ListTile(
                    title: const Text('Deliver to'),
                    subtitle: Text(
                      _address == null
                          ? 'Choose or add your address'
                          : '${_address!.recipientName} · ${_address!.recipientPhone}\n${_address!.address}',
                    ),
                    trailing: TextButton(
                      onPressed: _busy || cart.hasPendingCheckout
                          ? null
                          : _change,
                      child: const Text('Change'),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ready bouquets are dispatched separately from planned bouquets. Planned delivery dates exclude weekends.',
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                FilledButton(
                  onPressed: _busy || _address == null || cart.isEmpty
                      ? null
                      : () => _place(cart),
                  child: Text(
                    _busy
                        ? 'Confirming order…'
                        : cart.hasPendingCheckout
                        ? 'Retry and confirm order'
                        : 'Place order',
                  ),
                ),
              ],
            ),
    );
  }
}
