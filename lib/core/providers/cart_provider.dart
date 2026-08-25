import 'package:flutter/material.dart';
import '../../models/cart_item_model.dart';

class CartProvider extends ChangeNotifier {
  final List<CartItemModel> _items = [];

  List<CartItemModel> get items => List.unmodifiable(_items);

  bool get isEmpty => _items.isEmpty;

  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);

  double get totalPrice => _items.fold(0.0, (sum, item) => sum + item.lineTotal);

  /// Ready-made bouquets merge by bouquetId — adding the same one again
  /// just increases quantity instead of creating a duplicate line.
  void addReadyMadeItem({
    required String bouquetId,
    required String name,
    required String imageUrl,
    required double price,
  }) {
    final existingIndex = _items.indexWhere(
      (item) => item.type == 'ready' && item.bouquetId == bouquetId,
    );

    if (existingIndex != -1) {
      _items[existingIndex].quantity += 1;
    } else {
      _items.add(CartItemModel(
        id: 'ready_${bouquetId}_${DateTime.now().microsecondsSinceEpoch}',
        type: 'ready',
        name: name,
        imageUrl: imageUrl,
        unitPrice: price,
        bouquetId: bouquetId,
      ));
    }
    notifyListeners();
  }

  /// Custom bouquets are always added as a new line — each build is unique.
  void addCustomItem({
    required double unitPrice,
    required Map<String, int> stems,
    required String wrapper,
    required String ribbon,
    required String cardNote,
  }) {
    _items.add(CartItemModel(
      id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
      type: 'custom',
      name: 'Custom Bouquet',
      imageUrl: '',
      unitPrice: unitPrice,
      customStems: stems,
      wrapper: wrapper,
      ribbon: ribbon,
      cardNote: cardNote,
    ));
    notifyListeners();
  }

  void incrementQuantity(String id) {
    final item = _items.firstWhere((i) => i.id == id);
    item.quantity += 1;
    notifyListeners();
  }

  void decrementQuantity(String id) {
    final item = _items.firstWhere((i) => i.id == id);
    if (item.quantity > 1) {
      item.quantity -= 1;
    } else {
      _items.removeWhere((i) => i.id == id);
    }
    notifyListeners();
  }

  void removeItem(String id) {
    _items.removeWhere((i) => i.id == id);
    notifyListeners();
  }

  void clear() {
    _items.clear();
    notifyListeners();
  }
}