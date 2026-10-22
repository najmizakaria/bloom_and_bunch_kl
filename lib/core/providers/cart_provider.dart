import 'dart:convert';
import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/cart_item_model.dart';
import '../constants/fulfillment_constants.dart';
import '../utils/money.dart';
import '../services/cart_sync_service.dart';
import 'package:cloud_functions/cloud_functions.dart';

class CartProvider extends ChangeNotifier {
  CartProvider({this.syncService});
  final CartSyncService? syncService;
  bool get cloudSyncEnabled => syncService != null;
  bool get accountCartReady => !cloudSyncEnabled || _syncReady;
  StreamSubscription<Map<String, dynamic>?>? _cloudSubscription;
  int _revision = 0, _queuedCloudWrites = 0;
  bool _syncReady = false, _disposed = false;
  Map<String, dynamic>? _latestRemote;
  final Map<String, Map<String, dynamic>> _messageCards = {};
  Map<String, Map<String, dynamic>> get messageCards => jsonDecode(
    jsonEncode(_messageCards),
  ).cast<String, Map<String, dynamic>>();
  List<String> get deliveryGroups =>
      _items.map((i) => i.deliveryGroupKey).toSet().toList();
  bool get needsDeliveryDates => _items.any(
    (i) =>
        i.type != 'addon' &&
        i.fulfillmentType != FulfillmentTypes.readyNow &&
        i.requestedDeliveryDate == null,
  );
  bool get hasOrphanAddons => _items.any(
    (item) =>
        item.type == 'addon' &&
        !_items.any(
          (bouquet) =>
              bouquet.type != 'addon' &&
              bouquet.deliveryGroupKey == item.deliveryGroupKey,
        ),
  );
  bool get cardsComplete => _messageCards.values.every(
    (c) =>
        (c['message'] as String? ?? '').trim().isNotEmpty &&
        (c['senderName'] as String? ?? '').trim().isNotEmpty,
  );
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
          100 +
      _messageCards.values.fold<double>(
        0,
        (sum, card) => sum + (card['price'] as num? ?? 0).toDouble(),
      );

  void _persist({bool cloud = true}) {
    final uid = _uid;
    if (uid == null || _forgottenUsers.contains(uid)) return;
    final value = jsonEncode({
      'checkoutId': _checkoutId,
      'items': _items.map((item) => item.toMap()).toList(),
      'pendingRequest': _pendingRequest,
      'messageCards': _messageCards,
    });
    final cloudWrite = cloud && syncService != null && _syncReady;
    final generation = _userGeneration;
    final mutationId = _newId();
    if (cloudWrite) _queuedCloudWrites++;
    _writes = _writes
        .then((_) async {
          if (_forgottenUsers.contains(uid)) return;
          final prefs = await SharedPreferences.getInstance();
          if (!await prefs.setString('cart_$uid', value)) {
            throw StateError('Could not save cart.');
          }
          if (cloudWrite && generation == _userGeneration) {
            if (!_syncReady) {
              throw StateError('Reload your account cart before syncing.');
            }
            final nextRevision = await syncService!.save(
              Map<String, dynamic>.from(jsonDecode(value) as Map),
              _revision,
              mutationId,
            );
            if (generation == _userGeneration) _revision = nextRevision;
          }
          _saveError = null;
        })
        .catchError((Object error) {
          _saveError = error;
          if (generation != _userGeneration) return;
          if (error is FirebaseFunctionsException && error.code == 'aborted') {
            _syncReady = false;
            errorMessage =
                'Your cart changed on another device. Reload the latest cart before editing.';
          } else {
            errorMessage = cloudWrite
                ? 'Cart changes are saved on this device. Reconnect and retry syncing before checkout.'
                : 'Could not save your cart on this device.';
          }
          if (!_disposed) super.notifyListeners();
        })
        .whenComplete(() {
          if (cloudWrite) _queuedCloudWrites--;
          if (generation == _userGeneration &&
              _queuedCloudWrites == 0 &&
              _latestRemote != null &&
              _syncReady) {
            _receiveCloud(_latestRemote!);
          }
        });
  }

  Future<void> flush() async {
    await _writes;
    if (_saveError != null) {
      throw StateError(
        cloudSyncEnabled
            ? (errorMessage ?? 'Could not sync your cart. Reconnect and retry.')
            : 'Could not save your checkout. Please free device storage and retry.',
      );
    }
  }

  Future<void> switchUser(String? uid) async {
    if (_uid == uid && !_loading) return;
    _persist(cloud: false);
    final previousSubscription = _cloudSubscription;
    _cloudSubscription = null;
    _syncReady = false;
    _revision = 0;
    _latestRemote = null;
    _uid = uid;
    final generation = ++_userGeneration;
    _items.clear();
    _messageCards.clear();
    _pendingRequest = null;
    errorMessage = null;
    _checkoutId = _newId();
    _loading = uid != null;
    super.notifyListeners();
    await previousSubscription?.cancel();
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
        _restoreCards(data['messageCards']);
      }
      if (syncService != null) {
        _watchCloud(uid, generation, migrate: true);
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
      : cloudSyncEnabled && !_syncReady
      ? _reject('Reconnect and reload your account cart before editing.')
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
    String? requestedDeliveryDate,
  }) {
    if (!_editable()) return false;
    if (quantity < 1 || quantity > maximumQuantity) {
      return _reject('Maximum 20 bouquets per cart line.');
    }
    final index = _items.indexWhere(
      (item) =>
          item.type == 'ready' &&
          item.bouquetId == bouquetId &&
          item.requestedDeliveryDate == requestedDeliveryDate &&
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
        requestedDeliveryDate: requestedDeliveryDate,
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
          requestedDeliveryDate: requestedDeliveryDate,
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
    String cardNote = '',
    int leadTimeBusinessDays = 2,
    int quantity = 1,
    String? requestedDeliveryDate,
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
        requestedDeliveryDate: requestedDeliveryDate,
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
    _cleanGroups();
    _changed();
  }

  void removeItem(String id) {
    if (!_editable()) return;
    _items.removeWhere((item) => item.id == id);
    _cleanGroups();
    _changed();
  }

  void clear() {
    if (!_editable()) return;
    _items.clear();
    _messageCards.clear();
    _changed();
  }

  Future<Map<String, dynamic>> prepareCheckout(
    Map<String, dynamic> request,
  ) async {
    final generation = _userGeneration;
    await flush();
    if (generation != _userGeneration) {
      throw StateError('Your sign-in changed. Please retry.');
    }
    if (_pendingRequest == null && request['checkoutId'] != _checkoutId) {
      throw StateError(
        'Your cart changed. Review the latest summary before checkout.',
      );
    }
    if (cloudSyncEnabled && !_syncReady) {
      throw StateError('Reload your account cart before checkout.');
    }
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
    final subscription = _uid == uid ? _cloudSubscription : null;
    if (_uid == uid) {
      _cloudSubscription = null;
      _syncReady = false;
      _uid = null;
      _userGeneration++;
      _loading = false;
      _items.clear();
      _messageCards.clear();
      _pendingRequest = null;
    }
    await subscription?.cancel();
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
    _messageCards.clear();
    // placeOrder has already cleared the shared cart transactionally. Never
    // race that write with a second client-side clear.
    if (cloudSyncEnabled) _syncReady = false;
    _changed();
    if (cloudSyncEnabled) {
      unawaited(
        reloadCloud().catchError((Object _) {
          errorMessage =
              'Order confirmed. Reconnect to refresh your account cart.';
          if (!_disposed) super.notifyListeners();
        }),
      );
    }
  }

  void _restoreCards(dynamic value) {
    _messageCards.clear();
    if (value is Map) {
      for (final entry in value.entries) {
        _messageCards[entry.key.toString()] = Map<String, dynamic>.from(
          entry.value as Map,
        );
      }
    }
  }

  void _receiveCloud(Map<String, dynamic> data, {bool force = false}) {
    final revision = (data['revision'] as num?)?.toInt() ?? 0;
    if (!force && revision <= _revision) return;
    try {
      final restored = (data['items'] as List)
          .map(
            (i) => CartItemModel.fromMap(Map<String, dynamic>.from(i as Map)),
          )
          .toList();
      if (restored.length > maximumLines) {
        throw const FormatException('Invalid cart');
      }
      _items
        ..clear()
        ..addAll(restored);
      _restoreCards(data['messageCards']);
      _pendingRequest = data['pendingRequest'] is Map
          ? Map<String, dynamic>.from(data['pendingRequest'] as Map)
          : null;
      _checkoutId = data['checkoutId'] as String;
      _revision = revision;
      _saveError = null;
      _persist(cloud: false);
      if (!_disposed) super.notifyListeners();
    } catch (_) {
      errorMessage = 'Could not restore your account cart.';
    }
  }

  void _watchCloud(String uid, int generation, {bool migrate = false}) {
    var first = migrate;
    _cloudSubscription = syncService!
        .watch(uid)
        .listen(
          (remote) {
            if (generation != _userGeneration || _disposed) return;
            if (first) {
              first = false;
              _syncReady = true;
              if (remote == null) {
                _revision = 0;
                _persist();
              } else {
                _receiveCloud(remote, force: true);
              }
            } else if (remote != null) {
              _latestRemote = remote;
              if (_queuedCloudWrites == 0) _receiveCloud(remote);
            }
            if (!_disposed) super.notifyListeners();
          },
          onError: (Object error) {
            if (generation == _userGeneration && !_disposed) {
              _syncReady = false;
              errorMessage =
                  'Could not sync your account cart. Check your connection and retry.';
              super.notifyListeners();
            }
          },
        );
  }

  Future<void> reloadCloud() async {
    if (_uid == null || syncService == null) return;
    await _writes;
    final uid = _uid, generation = _userGeneration;
    final data = await syncService!.load(uid!);
    if (_disposed || generation != _userGeneration) return;
    await _cloudSubscription?.cancel();
    if (_disposed || generation != _userGeneration) return;
    _latestRemote = null;
    if (data != null) _receiveCloud(data, force: true);
    _syncReady = true;
    _saveError = null;
    errorMessage = null;
    _watchCloud(uid, generation, migrate: data == null);
    super.notifyListeners();
  }

  Future<void> retrySync() async {
    if (_latestRemote != null &&
        (_latestRemote!['revision'] as num? ?? 0) > _revision) {
      await reloadCloud();
      return;
    }
    _syncReady = true;
    _persist();
    await flush();
    if (!_disposed) super.notifyListeners();
  }

  bool addSelection(List<CartItemModel> selection) {
    if (!_editable()) return false;
    if (selection.any((i) => i.quantity < 1 || i.quantity > maximumQuantity)) {
      return _reject('Maximum 20 cart lines and 20 of each item.');
    }
    if (selection.any(
      (i) =>
          i.type != 'addon' &&
          i.fulfillmentType != FulfillmentTypes.readyNow &&
          i.requestedDeliveryDate == null,
    )) {
      return _reject('Choose a delivery date first.');
    }
    final next = _items.map((i) => CartItemModel.fromMap(i.toMap())).toList();
    for (final item in selection) {
      final index = next.indexWhere(
        (existing) =>
            existing.type == item.type &&
            item.type != 'custom' &&
            existing.fulfillmentType == item.fulfillmentType &&
            existing.requestedDeliveryDate == item.requestedDeliveryDate &&
            (item.type == 'addon'
                ? existing.addonId == item.addonId
                : existing.bouquetId == item.bouquetId),
      );
      if (index < 0) {
        next.add(item);
      } else {
        final count = next[index].quantity + item.quantity;
        if (count > maximumQuantity) {
          return _reject(
            item.type == 'addon'
                ? 'Maximum 20 add-ons per cart line.'
                : 'Maximum 20 bouquets per cart line.',
          );
        }
        next[index] = CartItemModel.fromMap({
          ...item.toMap(),
          'id': next[index].id,
          'quantity': count,
        });
      }
    }
    if (next.length > maximumLines) {
      return _reject('Maximum 20 different items per checkout.');
    }
    _items
      ..clear()
      ..addAll(next);
    _changed();
    return true;
  }

  void setMessageCard(String group, Map<String, dynamic>? card) {
    if (!_editable()) return;
    if (card == null) {
      _messageCards.remove(group);
    } else {
      _messageCards[group] = Map.from(card);
    }
    _changed();
  }

  void changeGroupDate(String group, String date) {
    if (!_editable()) return;
    if (_messageCards.containsKey(group) &&
        _messageCards.containsKey(date) &&
        group != date) {
      _reject(
        'Both deliveries have a message card. Remove one card before combining their dates.',
      );
      return;
    }
    for (var i = 0; i < _items.length; i++) {
      if (_items[i].deliveryGroupKey == group) {
        _items[i] = _items[i].withDate(date);
      }
    }
    final card = _messageCards.remove(group);
    if (card != null) _messageCards[date] = card;
    _changed();
  }

  void moveAddon(String id, String group) {
    if (!_editable()) return;
    final index = _items.indexWhere((i) => i.id == id && i.type == 'addon');
    if (index < 0) return;
    _items[index] = _items[index].withDate(group == 'ready_now' ? null : group);
    _cleanGroups();
    _changed();
  }

  void _cleanGroups() {
    final valid = _items
        .where((i) => i.type != 'addon')
        .map((i) => i.deliveryGroupKey)
        .toSet();
    _messageCards.removeWhere((key, _) => !valid.contains(key));
  }

  @override
  void dispose() {
    _disposed = true;
    _cloudSubscription?.cancel();
    super.dispose();
  }
}
