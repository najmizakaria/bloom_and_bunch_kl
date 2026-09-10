import 'dart:math';
import 'package:flutter/material.dart';

import '../../models/cart_item_model.dart';
import '../constants/fulfillment_constants.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];
  String _checkoutId = _newId();
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';
  String get checkoutId => _checkoutId;
  void resetCheckout() {
    _checkoutId = _newId();
  }

  @override
  void notifyListeners() {
    resetCheckout();
    super.notifyListeners();
  }

  List<CartItemModel> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.fold(0, (sum, item) => sum + item.lineTotal);

  void addReadyMadeItem({
    required String bouquetId,
    required String name,
    required String imageUrl,
    required double price,
    String fulfillmentType = FulfillmentTypes.readyNow,
    int leadTimeBusinessDays = 0,
  }) {
    final existingIndex = _items.indexWhere(
      (item) =>
          item.type == 'ready' &&
          item.bouquetId == bouquetId &&
          item.fulfillmentType == fulfillmentType,
    );

    if (existingIndex != -1) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(
        CartItemModel(
          id:
              '${fulfillmentType}_${bouquetId}_'
              '${DateTime.now().microsecondsSinceEpoch}',
          type: 'ready',
          name: name,
          imageUrl: imageUrl,
          unitPrice: price,
          bouquetId: bouquetId,
          fulfillmentType: fulfillmentType,
          leadTimeBusinessDays: leadTimeBusinessDays,
        ),
      );
    }

    notifyListeners();
  }

  void addCustomItem({
    required double unitPrice,
    required Map<String, int> stems,
    Map<String, String> stemNames = const {},
    required String wrapper,
    required String ribbon,
    required String cardNote,
    int leadTimeBusinessDays = 2,
  }) {
    _items.add(
      CartItemModel(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        type: 'custom',
        name: 'Custom Bouquet',
        imageUrl: '',
        unitPrice: unitPrice,
        fulfillmentType: FulfillmentTypes.custom,
        leadTimeBusinessDays: leadTimeBusinessDays.clamp(1, 3),
        customStems: Map<String, int>.from(stems),
        customStemNames: Map<String, String>.from(stemNames),
        wrapper: wrapper,
        ribbon: ribbon,
        cardNote: cardNote,
      ),
    );

    notifyListeners();
  }

  void incrementQuantity(String id) {
    final item = _items.firstWhere((item) => item.id == id);
    item.quantity += 1;
    notifyListeners();
  }

  void decrementQuantity(String id) {
    final item = _items.firstWhere((item) => item.id == id);

    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _items.removeWhere((item) => item.id == id);
    }

    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}
