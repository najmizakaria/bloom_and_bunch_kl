import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../core/providers/cart_provider.dart';
import '../../../core/theme/app_colors.dart';

class CheckoutScreen extends StatefulWidget {
  const CheckoutScreen({super.key});

  @override
  State<CheckoutScreen> createState() =>
      _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  final TextEditingController _nameController =
      TextEditingController();
  final TextEditingController _addressController =
      TextEditingController();
  final TextEditingController _phoneController =
      TextEditingController();

  bool _isProcessing = false;

  final Map<String, double> _wrapperPrices = const {
    'Kraft Paper (Classic)': 5.00,
    'Pastel Pink Waterproof': 8.00,
    'Minimalist Matte Black': 8.00,
    'Satin White Luxury': 10.00,
  };

  final Map<String, double> _ribbonPrices = const {
    'Red Satin': 2.00,
    'Gold Silk': 3.50,
    'Rose Gold Organza': 3.50,
    'Minimalist Twine': 1.50,
  };

  @override
  void dispose() {
    _nameController.dispose();
    _addressController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _placeOrder(CartProvider cart) async {
    if (_isProcessing) return;

    final recipientName = _nameController.text.trim();
    final recipientPhone = _phoneController.text.trim();
    final deliveryAddress =
        _addressController.text.trim();

    if (recipientName.isEmpty ||
        recipientPhone.isEmpty ||
        deliveryAddress.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please fill in all delivery details.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    if (cart.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Your cart is empty.'),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    final user = FirebaseAuth.instance.currentUser;

    if (user == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Please sign in before placing an order.',
          ),
          backgroundColor: Colors.orange,
        ),
      );
      return;
    }

    setState(() {
      _isProcessing = true;
    });

    try {
      final bouquetRequirements = <String, int>{};
      final flowerRequirements = <String, int>{};

      for (final item in cart.items) {
        if (item.type == 'ready') {
          final bouquetId = item.bouquetId;

          if (bouquetId == null || bouquetId.isEmpty) {
            throw const _CheckoutException(
              'A bouquet in your cart is invalid. Remove it and add it again.',
            );
          }

          bouquetRequirements.update(
            bouquetId,
            (quantity) => quantity + item.quantity,
            ifAbsent: () => item.quantity,
          );
        } else if (item.type == 'custom') {
          final stems = item.customStems;

          if (stems == null || stems.isEmpty) {
            throw const _CheckoutException(
              'A custom bouquet has no flower stems.',
            );
          }

          for (final stem in stems.entries) {
            if (stem.value <= 0) continue;

            final requiredQuantity =
                stem.value * item.quantity;

            flowerRequirements.update(
              stem.key,
              (quantity) =>
                  quantity + requiredQuantity,
              ifAbsent: () => requiredQuantity,
            );
          }
        } else {
          throw const _CheckoutException(
            'An unsupported product was found in the cart.',
          );
        }
      }

      final firestore = FirebaseFirestore.instance;
      final orderReference =
          firestore.collection('orders').doc();

      final bouquetCollection =
          firestore.collection('bouquets');
      final flowerCollection =
          firestore.collection('flowers');

      await firestore.runTransaction(
        (transaction) async {
          final bouquetSnapshots = <String,
              DocumentSnapshot<Map<String, dynamic>>>{};

          final flowerSnapshots = <String,
              DocumentSnapshot<Map<String, dynamic>>>{};

          // Firestore transactions must perform all reads
          // before performing any writes.
          for (final bouquetId
              in bouquetRequirements.keys) {
            final reference =
                bouquetCollection.doc(bouquetId);

            bouquetSnapshots[bouquetId] =
                await transaction.get(reference);
          }

          for (final flowerId
              in flowerRequirements.keys) {
            final reference =
                flowerCollection.doc(flowerId);

            flowerSnapshots[flowerId] =
                await transaction.get(reference);
          }

          // Validate every ready-made bouquet.
          for (final requirement
              in bouquetRequirements.entries) {
            final snapshot =
                bouquetSnapshots[requirement.key];

            if (snapshot == null || !snapshot.exists) {
              throw const _CheckoutException(
                'A bouquet in your cart no longer exists.',
              );
            }

            final data = snapshot.data() ?? {};
            final name =
                (data['name'] ?? 'A bouquet').toString();

            final stock =
                (data['stockCount'] as num?)?.toInt() ??
                    0;

            final available =
                data['readyToSend'] == true;

            final archived = data['archived'] == true;

            if (!available || archived) {
              throw _CheckoutException(
                '$name is no longer available.',
              );
            }

            if (stock < requirement.value) {
              throw _CheckoutException(
                'Only $stock $name bouquet(s) remain. '
                'Your cart requests ${requirement.value}.',
              );
            }
          }

          // Validate every flower used by custom bouquets.
          for (final requirement
              in flowerRequirements.entries) {
            final snapshot =
                flowerSnapshots[requirement.key];

            if (snapshot == null || !snapshot.exists) {
              throw const _CheckoutException(
                'A selected flower no longer exists.',
              );
            }

            final data = snapshot.data() ?? {};
            final name =
                (data['name'] ?? 'A flower').toString();

            final stock =
                (data['stockQuantity'] as num?)
                        ?.toInt() ??
                    0;

            final available =
                data['isAvailable'] == true;

            if (!available) {
              throw _CheckoutException(
                '$name is no longer available.',
              );
            }

            if (stock < requirement.value) {
              throw _CheckoutException(
                'Only $stock $name stem(s) remain. '
                'Your cart requests ${requirement.value}.',
              );
            }
          }

          // Confirm that prices have not changed.
          for (final item in cart.items) {
            if (item.type == 'ready') {
              final snapshot =
                  bouquetSnapshots[item.bouquetId];

              final data = snapshot?.data() ?? {};

              final currentPrice =
                  (data['price'] as num?)?.toDouble() ??
                      0;

              if ((currentPrice - item.unitPrice).abs() >
                  0.01) {
                throw _CheckoutException(
                  '${item.name} has a new price. '
                  'Remove it from the cart and add it again.',
                );
              }
            }

            if (item.type == 'custom') {
              double currentPrice = 0;

              for (final stem
                  in item.customStems!.entries) {
                final flowerData =
                    flowerSnapshots[stem.key]?.data() ??
                        {};

                final pricePerStem =
                    (flowerData['pricePerStem'] as num?)
                            ?.toDouble() ??
                        0;

                currentPrice +=
                    pricePerStem * stem.value;
              }

              currentPrice +=
                  _wrapperPrices[item.wrapper] ?? 0;

              currentPrice +=
                  _ribbonPrices[item.ribbon] ?? 0;

              if ((currentPrice - item.unitPrice).abs() >
                  0.01) {
                throw const _CheckoutException(
                  'A custom bouquet price has changed. '
                  'Please rebuild the custom bouquet.',
                );
              }
            }
          }

          // Deduct ready-made bouquet stock.
          for (final requirement
              in bouquetRequirements.entries) {
            final reference =
                bouquetCollection.doc(requirement.key);

            final data =
                bouquetSnapshots[requirement.key]!
                        .data() ??
                    {};

            final currentStock =
                (data['stockCount'] as num?)?.toInt() ??
                    0;

            final newStock =
                currentStock - requirement.value;

            final Map<String, dynamic> updates = {
              'stockCount': newStock,
              'updatedAt': FieldValue.serverTimestamp(),
            };

            if (newStock == 0) {
              updates['readyToSend'] = false;
            }

            transaction.update(reference, updates);
          }

          // Deduct flower-stem stock.
          for (final requirement
              in flowerRequirements.entries) {
            final reference =
                flowerCollection.doc(requirement.key);

            final data =
                flowerSnapshots[requirement.key]!
                        .data() ??
                    {};

            final currentStock =
                (data['stockQuantity'] as num?)
                        ?.toInt() ??
                    0;

            final newStock =
                currentStock - requirement.value;

            final Map<String, dynamic> updates = {
              'stockQuantity': newStock,
              'updatedAt': FieldValue.serverTimestamp(),
            };

            if (newStock == 0) {
              updates['isAvailable'] = false;
            }

            transaction.update(reference, updates);
          }

          final hasCustomItems = cart.items.any(
            (item) => item.type == 'custom',
          );

          transaction.set(orderReference, {
            'customerId': user.uid,
            'recipientName': recipientName,
            'recipientPhone': recipientPhone,
            'deliveryAddress': deliveryAddress,
            'totalAmount': cart.totalPrice,
            'orderStatus': 'Pending',
            'requiresPrepTime': hasCustomItems,
            'deliveryTimeSlot': hasCustomItems
                ? 'Scheduled (1-2 hrs prep)'
                : '10:00 AM - 2:00 PM',
            'items': cart.items
                .map((item) => item.toMap())
                .toList(),
            'createdAt': FieldValue.serverTimestamp(),
            'updatedAt': FieldValue.serverTimestamp(),
          });
        },
      );

      if (!mounted) return;

      cart.clear();

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Order placed successfully! 🎉',
          ),
          backgroundColor: Colors.green,
        ),
      );

      Navigator.of(context).popUntil(
        (route) => route.isFirst,
      );
    } on _CheckoutException catch (error) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(error.message),
          backgroundColor: Colors.orange,
          duration: const Duration(seconds: 4),
        ),
      );
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _isProcessing = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to place order: $error',
          ),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = context.watch<CartProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Checkout'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Card(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Order Summary',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Divider(),
                    ...cart.items.map(
                      (item) => Padding(
                        padding:
                            const EdgeInsets.symmetric(
                          vertical: 5,
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(
                                '${item.name} × ${item.quantity}',
                              ),
                            ),
                            Text(
                              'RM ${item.lineTotal.toStringAsFixed(2)}',
                            ),
                          ],
                        ),
                      ),
                    ),
                    const Divider(),
                    Row(
                      children: [
                        const Text(
                          'Total',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        const Spacer(),
                        Text(
                          'RM ${cart.totalPrice.toStringAsFixed(2)}',
                          style: const TextStyle(
                            color:
                                AppColors.primaryRosewood,
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.teal.shade50,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(
                    Icons.verified_outlined,
                    color: Colors.teal,
                  ),
                  SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Stock and prices will be checked again before the order is confirmed.',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Delivery Details',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _nameController,
              enabled: !_isProcessing,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(
                labelText: 'Recipient Name',
                prefixIcon: Icon(Icons.person_outline),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _phoneController,
              enabled: !_isProcessing,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Recipient Phone',
                prefixIcon: Icon(Icons.phone_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              controller: _addressController,
              enabled: !_isProcessing,
              maxLines: 3,
              textCapitalization:
                  TextCapitalization.sentences,
              decoration: const InputDecoration(
                labelText: 'Full Delivery Address',
                prefixIcon:
                    Icon(Icons.location_on_outlined),
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 30),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor:
                      AppColors.primaryRosewood,
                  foregroundColor: Colors.white,
                ),
                onPressed: _isProcessing
                    ? null
                    : () => _placeOrder(cart),
                child: _isProcessing
                    ? const SizedBox(
                        width: 23,
                        height: 23,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text(
                        'Place Order',
                        style: TextStyle(fontSize: 17),
                      ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CheckoutException implements Exception {
  const _CheckoutException(this.message);

  final String message;

  @override
  String toString() => message;
}