import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/cart_item_model.dart';
import '../constants/fulfillment_constants.dart';
import '../utils/money.dart';

class CartProvider extends ChangeNotifier {
  static const maximumLines = 20, maximumQuantity = 20;
  final List<CartItemModel> _items = [];
  String _checkoutId = _newId();
  String? _uid;
  int _userGeneration = 0;
  bool _loading = false;
  bool get loading => _loading;
  String? errorMessage;
  Map<String, dynamic>? _pendingRequest;
  Map<String, dynamic>? get pendingRequest => _pendingRequest == null
      ? null
      : jsonDecode(jsonEncode(_pendingRequest!)) as Map<String, dynamic>;
  bool get hasPendingCheckout => _pendingRequest != null;
  Future<void> _writes = Future.value();
  Object? _saveError;
  final Set<String> _forgottenUsers = {};
  static String _newId() =>
      '${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(0x7fffffff)}';
  String get checkoutId => _checkoutId;
  List<CartItemModel> get items => List.unmodifiable(_items);
  bool get isEmpty => _items.isEmpty;
  int get itemCount => _items.fold(0, (sum, item) => sum + item.quantity);
  double get totalPrice =>
      _items.fold<int>(
        0,
        (sum, item) => sum + Money.toSen(item.unitPrice) * item.quantity,
      ) /
      100;

  void _persist() {
    final uid = _uid;
    if (uid == null || _forgottenUsers.contains(uid)) return;
    final value = jsonEncode({
      'checkoutId': _checkoutId,
      'items': _items.map((item) => item.toMap()).toList(),
      'pendingRequest': _pendingRequest,
    });
    _writes = _writes
        .then((_) async {
          if (_forgottenUsers.contains(uid)) return;
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString('cart_$uid', value)) {
            throw StateError('Could not save cart.');
          }
          _saveError = null;
        })
        .catchError((Object error) {
          _saveError = error;
          errorMessage = 'Could not save your cart on this device.';
        });
  }

  Future<void> flush() async {
    await _writes;
    if (_saveError != null) {
      throw StateError(
        'Could not save your checkout. Please free device storage and retry.',
      );
    }
  }

  Future<void> switchUser(String? uid) async {
    if (_uid == uid && !_loading) return;
    _persist();
    _uid = uid;
    final generation = ++_userGeneration;
    _items.clear();
    _pendingRequest = null;
    errorMessage = null;
    _checkoutId = _newId();
    _loading = uid != null;
    super.notifyListeners();
    if (uid == null) return;
    try {
      await _writes;
      final prefs = await SharedPreferences.getInstance();
      final saved = prefs.getString('cart_$uid');
      if (generation != _userGeneration) return;
      if (saved != null) {
        final data = jsonDecode(saved) as Map<String, dynamic>;
        final restored = (data['items'] as List)
            .map(
              (raw) =>
                  CartItemModel.fromMap(Map<String, dynamic>.from(raw as Map)),
            )
            .toList();
        if (restored.length > maximumLines ||
            restored.any(
              (item) => item.quantity < 1 || item.quantity > maximumQuantity,
            )) {
          throw const FormatException('Invalid saved cart.');
        }
        _items.addAll(restored);
        _checkoutId = data['checkoutId'] as String;
        _pendingRequest = data['pendingRequest'] == null
            ? null
            : Map<String, dynamic>.from(data['pendingRequest'] as Map);
      }
    } catch (_) {
      if (generation == _userGeneration) {
        errorMessage =
            'Could not restore your saved cart. Please review it before ordering.';
      }
    } finally {
      if (generation == _userGeneration) {
        _loading = false;
        super.notifyListeners();
      }
    }
  }

  void resetCheckout() {
    if (hasPendingCheckout) return;
    _checkoutId = _newId();
    _persist();
  }

  void _changed() {
    errorMessage = null;
    resetCheckout();
    super.notifyListeners();
  }

  bool _reject(String message) {
    errorMessage = message;
    super.notifyListeners();
    return false;
  }

  bool _editable() => _loading
      ? _reject('Your cart is still loading.')
      : hasPendingCheckout
      ? _reject(
          'Retry checkout to confirm your previous order before changing your cart.',
        )
      : true;

  bool addReadyMadeItem({
    required String bouquetId,
    required String name,
    required String imageUrl,
    required double price,
    String fulfillmentType = FulfillmentTypes.readyNow,
    int leadTimeBusinessDays = 0,
    int quantity = 1,
  }) {
    if (!_editable()) return false;
    if (quantity < 1 || quantity > maximumQuantity) {
      return _reject('Maximum 20 bouquets per cart line.');
    }
    final index = _items.indexWhere(
      (item) =>
          item.type == 'ready' &&
          item.bouquetId == bouquetId &&
          item.fulfillmentType == fulfillmentType,
    );
    if (index >= 0) {
      final count = _items[index].quantity + quantity;
      if (count > maximumQuantity) {
        return _reject('Maximum 20 bouquets per cart line.');
      }
      // Refresh the snapshot and price when the customer adds a current product.
      _items[index] = CartItemModel(
        id: _items[index].id,
        type: 'ready',
        name: name,
        imageUrl: imageUrl,
        unitPrice: Money.round(price),
        quantity: count,
        bouquetId: bouquetId,
        fulfillmentType: fulfillmentType,
        leadTimeBusinessDays: leadTimeBusinessDays,
      );
    } else {
      if (_items.length >= maximumLines) {
        return _reject('Maximum 20 different items per checkout.');
      }
      _items.add(
        CartItemModel(
          id: '${fulfillmentType}_${bouquetId}_${DateTime.now().microsecondsSinceEpoch}',
          type: 'ready',
          name: name,
          imageUrl: imageUrl,
          unitPrice: Money.round(price),
          quantity: quantity,
          bouquetId: bouquetId,
          fulfillmentType: fulfillmentType,
          leadTimeBusinessDays: leadTimeBusinessDays,
        ),
      );
    }
    _changed();
    return true;
  }

  bool addCustomItem({
    required double unitPrice,
    required Map<String, int> stems,
    Map<String, String> stemNames = const {},
    required String wrapper,
    required String ribbon,
    required String cardNote,
    int leadTimeBusinessDays = 2,
    int quantity = 1,
  }) {
    if (!_editable()) return false;
    if (_items.length >= maximumLines) {
      return _reject('Maximum 20 different items per checkout.');
    }
    if (quantity < 1 || quantity > maximumQuantity) {
      return _reject('Maximum 20 bouquets per cart line.');
    }
    if (stems.isEmpty ||
        stems.length > 30 ||
        stems.values.any((count) => count < 1 || count > 100) ||
        stems.values.fold(0, (a, b) => a + b) > 150) {
      return _reject(
        'Choose 1–30 flower types, up to 100 stems each and 150 stems total.',
      );
    }
    _items.add(
      CartItemModel(
        id: 'custom_${DateTime.now().microsecondsSinceEpoch}',
        type: 'custom',
        name: 'Custom Bouquet',
        imageUrl: '',
        unitPrice: Money.round(unitPrice),
        quantity: quantity,
        fulfillmentType: FulfillmentTypes.custom,
        leadTimeBusinessDays: leadTimeBusinessDays.clamp(1, 3),
        customStems: Map.unmodifiable(stems),
        customStemNames: Map.unmodifiable(stemNames),
        wrapper: wrapper,
        ribbon: ribbon,
        cardNote: cardNote,
      ),
    );
    _changed();
    return true;
  }

  void incrementQuantity(String id) {
    if (!_editable()) return;
    final item = _items.firstWhere((item) => item.id == id);
    if (item.quantity >= maximumQuantity) {
      _reject('Maximum 20 bouquets per cart line.');
      return;
    }
    item.quantity++;
    _changed();
  }

  void decrementQuantity(String id) {
    if (!_editable()) return;
    final item = _items.firstWhere((item) => item.id == id);
    if (item.quantity > 1) {
      item.quantity--;
    } else {
      _items.remove(item);
    }
    _changed();
  }

  void removeItem(String id) {
    if (!_editable()) return;
    _items.removeWhere((item) => item.id == id);
    _changed();
  }

  void clear() {
    if (!_editable()) return;
    _items.clear();
    _changed();
  }

  Future<Map<String, dynamic>> prepareCheckout(
    Map<String, dynamic> request,
  ) async {
    final generation = _userGeneration;
    _pendingRequest ??= jsonDecode(jsonEncode(request)) as Map<String, dynamic>;
    _persist();
    await flush();
    if (generation != _userGeneration) {
      throw StateError('Your sign-in changed. Please retry.');
    }
    return pendingRequest!;
  }

  Future<void> forgetDeletedUser(String uid) async {
    _forgottenUsers.add(uid);
    if (_uid == uid) {
      _uid = null;
      _userGeneration++;
      _loading = false;
      _items.clear();
      _pendingRequest = null;
    }
    await _writes;
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('cart_$uid');
    super.notifyListeners();
  }

  void checkoutRejected() {
    _pendingRequest = null;
    _persist();
    super.notifyListeners();
  }

  void checkoutSucceeded() {
    _pendingRequest = null;
    _items.clear();
    _changed();
  }
}
