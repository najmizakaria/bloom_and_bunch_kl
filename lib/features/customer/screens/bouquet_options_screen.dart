import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../core/providers/cart_provider.dart';
import '../../../core/services/commerce_service.dart';
import '../../../models/cart_item_model.dart';
import '../widgets/delivery_date_picker.dart';

class BouquetOptionsScreen extends StatefulWidget {
  const BouquetOptionsScreen({
    super.key,
    required this.bouquet,
    this.extraBouquets = const [],
    this.initialAddons = const [],
    this.catalogueStream,
    this.datePicker,
  });
  final CartItemModel bouquet;
  final List<CartItemModel> extraBouquets, initialAddons;
  final Stream<QuerySnapshot<Map<String, dynamic>>>? catalogueStream;
  final Future<String?> Function(BuildContext, List<CartItemModel>)? datePicker;
  @override
  State<BouquetOptionsScreen> createState() => _BouquetOptionsScreenState();
}

class _BouquetOptionsScreenState extends State<BouquetOptionsScreen> {
  late final _catalogue =
      widget.catalogueStream ?? CommerceService.catalogue('addons');
  final Map<String, Map<String, dynamic>> _products = {};
  final Map<String, int> _quantities = {};
  String _category = 'All';
  String? _date;
  bool _choosing = false;
  List<CartItemModel> get _bouquets => [
    widget.bouquet,
    ...widget.extraBouquets,
  ];
  bool get _planned => _bouquets.any((b) => b.fulfillmentType != 'ready_now');
  @override
  void initState() {
    super.initState();
    for (final addon in widget.initialAddons) {
      _quantities[addon.addonId!] = addon.quantity;
      _products[addon.addonId!] = addon.toMap()..['price'] = addon.unitPrice;
    }
  }

  Future<void> _choose() async {
    setState(() => _choosing = true);
    final date = await (widget.datePicker ?? chooseDeliveryDate)(
      context,
      _bouquets,
    );
    if (mounted) {
      setState(() {
        _choosing = false;
        if (date != null) _date = date;
      });
    }
  }

  void _add() {
    if (_planned && _date == null) return;
    final stamp = DateTime.now().microsecondsSinceEpoch;
    final selection = [
      ..._bouquets.map((b) => b.withDate(_date)),
      for (final entry in _quantities.entries.where((e) => e.value > 0))
        CartItemModel(
          id: 'addon_${entry.key}_$stamp',
          type: 'addon',
          addonId: entry.key,
          name: _products[entry.key]!['name'] as String,
          imageUrl: _products[entry.key]!['imageUrl'] as String? ?? '',
          unitPrice: (_products[entry.key]!['price'] as num).toDouble(),
          quantity: entry.value,
          requestedDeliveryDate: _date,
        ),
    ];
    final cart = context.read<CartProvider>();
    if (!cart.addSelection(selection)) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(cart.errorMessage ?? 'Could not add these items.'),
        ),
      );
      return;
    }
    Navigator.pop(context, true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Bouquet and selected add-ons added to cart.'),
      ),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Make it extra special')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          widget.bouquet.name,
          style: Theme.of(context).textTheme.headlineSmall,
        ),
        if (widget.extraBouquets.isNotEmpty)
          Text(
            'Also includes ${widget.extraBouquets.map((b) => b.name).join(', ')}',
          ),
        const SizedBox(height: 8),
        const Text(
          '1. Optional add-ons',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
        const Text(
          'Each add-on appears separately in your cart. Message cards are added in the cart.',
        ),
        const SizedBox(height: 16),
        StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
          stream: _catalogue,
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return const Text(
                'Add-ons could not be loaded. You can continue without them.',
              );
            }
            if (!snapshot.hasData) return const LinearProgressIndicator();
            final products = snapshot.data!.docs;
            final categories = {
              'All',
              ...products.map(
                (p) => (p.data()['category'] ?? 'Other').toString(),
              ),
            };
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Wrap(
                  spacing: 8,
                  children: categories
                      .map(
                        (category) => ChoiceChip(
                          label: Text(category),
                          selected: _category == category,
                          onSelected: (_) =>
                              setState(() => _category = category),
                        ),
                      )
                      .toList(),
                ),
                if (products.isEmpty)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No add-ons are currently available.'),
                  ),
                for (final product in products.where(
                  (p) =>
                      _category == 'All' || p.data()['category'] == _category,
                ))
                  Builder(
                    builder: (context) {
                      final data = product.data(),
                          count = _quantities[product.id] ?? 0,
                          stock = (data['stockQuantity'] as num?)?.toInt() ?? 0;
                      return Card(
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if ((data['imageUrl'] ?? '')
                                      .toString()
                                      .isNotEmpty)
                                    Padding(
                                      padding: const EdgeInsets.only(right: 12),
                                      child: Image.network(
                                        data['imageUrl'] as String,
                                        width: 76,
                                        height: 76,
                                        fit: BoxFit.cover,
                                        errorBuilder: (_, error, stack) =>
                                            const Icon(Icons.redeem, size: 48),
                                      ),
                                    ),
                                  Expanded(
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          data['name'] as String,
                                          style: const TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        Text(
                                          'RM ${(data['price'] as num).toStringAsFixed(2)}',
                                        ),
                                        if (stock == 0) const Text('Sold out'),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                              Row(
                                mainAxisAlignment: MainAxisAlignment.end,
                                children: [
                                  IconButton(
                                    tooltip: 'Remove one',
                                    onPressed: count == 0
                                        ? null
                                        : () => setState(
                                            () => _quantities[product.id] =
                                                count - 1,
                                          ),
                                    icon: const Icon(
                                      Icons.remove_circle_outline,
                                    ),
                                  ),
                                  Text('$count'),
                                  IconButton(
                                    tooltip: 'Add one',
                                    onPressed: count >= stock || count >= 20
                                        ? null
                                        : () => setState(() {
                                            _products[product.id] = data;
                                            _quantities[product.id] = count + 1;
                                          }),
                                    icon: const Icon(Icons.add_circle_outline),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
              ],
            );
          },
        ),
        const SizedBox(height: 24),
        Text(
          _planned ? '2. Choose your delivery date' : '2. Delivery',
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        OutlinedButton.icon(
          onPressed: _choosing ? null : _choose,
          icon: const Icon(Icons.calendar_month),
          label: Text(
            _choosing
                ? 'Loading available dates…'
                : _date ??
                      (_planned
                          ? 'Choose delivery date'
                          : 'Deliver later (optional)'),
          ),
        ),
        if (!_planned && _date != null)
          TextButton(
            onPressed: () => setState(() => _date = null),
            child: const Text('Use earliest delivery instead'),
          ),
        const SizedBox(height: 24),
        FilledButton(
          onPressed: _choosing || (_planned && _date == null) ? null : _add,
          child: const Text('Add bouquet and extras to cart'),
        ),
      ],
    ),
  );
}
