import 'dart:async';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/admin_service.dart';

/// Foreground, opt-in location sharing. No background permission is requested.
class RiderLocationSharing extends StatefulWidget {
  const RiderLocationSharing({super.key});
  @override
  State<RiderLocationSharing> createState() => _RiderLocationSharingState();
}

class _RiderLocationSharingState extends State<RiderLocationSharing>
    with WidgetsBindingObserver {
  StreamSubscription<Position>? _positions;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _profile;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? _delivery;
  String? _deliveryId;
  bool _enabled = false,
      _busy = false,
      _sending = false,
      _active = false,
      _foreground = true;
  DateTime? _last;
  String _message =
      'Share your location with the store during an active delivery.';
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid != null) {
      _profile = FirebaseFirestore.instance
          .doc('users/$uid')
          .snapshots()
          .listen(
            (s) {
              final id = s.data()?['accountSuspended'] == true
                  ? null
                  : s.data()?['activeDeliveryId'] as String?;
              if (id == _deliveryId) return;
              _deliveryId = id;
              _delivery?.cancel();
              if (id == null) {
                if (_enabled) unawaited(_stop());
                if (mounted) setState(() => _active = false);
                return;
              }
              _delivery = FirebaseFirestore.instance
                  .doc('orders/$id')
                  .snapshots()
                  .listen(
                    (order) {
                      final active =
                          order.data()?['riderId'] == uid &&
                          order.data()?['orderStatus'] == 'Out for Delivery';
                      if (!active && _enabled) unawaited(_stop());
                      if (mounted) setState(() => _active = active);
                    },
                    onError: (_) {
                      unawaited(_stop());
                      if (mounted) setState(() => _active = false);
                    },
                  );
            },
            onError: (_) {
              _stop();
              if (mounted) {
                setState(
                  () => _message =
                      'Could not check delivery access. Reopen your rider dashboard.',
                );
              }
            },
          );
    }
  }

  Future<void> _publish(Position p) async {
    if (_sending ||
        !_enabled ||
        !_active ||
        !_foreground ||
        (_last != null &&
            DateTime.now().difference(_last!) < const Duration(seconds: 15))) {
      return;
    }
    _sending = true;
    try {
      await AdminService().call('publishRiderLocation', {
        'latitude': p.latitude,
        'longitude': p.longitude,
      });
      _last = DateTime.now();
      if (mounted) {
        setState(
          () => _message = 'Sharing your foreground location with the store.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _message =
              'Location update failed. Turn sharing off and on to retry.',
        );
      }
    } finally {
      _sending = false;
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      if (!await Geolocator.isLocationServiceEnabled()) {
        throw StateError('Enable location services on this device.');
      }
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if ([
        LocationPermission.denied,
        LocationPermission.deniedForever,
      ].contains(permission)) {
        throw StateError(
          'Allow location access in your browser or device settings.',
        );
      }
      if (!mounted || !_active || !_foreground) return;
      setState(() => _enabled = true);
      _last = null;
      _positions =
          Geolocator.getPositionStream(
            locationSettings: const LocationSettings(
              accuracy: LocationAccuracy.high,
              distanceFilter: 20,
            ),
          ).listen(
            _publish,
            onError: (_) {
              _stop();
              if (mounted) {
                setState(
                  () => _message =
                      'Location unavailable. Check permissions and try again.',
                );
              }
            },
          );
      await _publish(
        await Geolocator.getCurrentPosition(
          locationSettings: const LocationSettings(
            accuracy: LocationAccuracy.high,
            timeLimit: Duration(seconds: 20),
          ),
        ),
      );
    } catch (e) {
      await _stop();
      if (mounted) {
        setState(
          () => _message = e is StateError
              ? e.message.toString()
              : 'Could not access location. Check permissions and retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _stop() async {
    _enabled = false;
    await _positions?.cancel();
    _positions = null;
    // A request already in flight finishes before the final deletion.
    while (_sending) {
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    try {
      await AdminService().call('publishRiderLocation', {'stop': true});
    } catch (_) {
      /* Old coordinates are never displayed as fresh indefinitely. */
    }
    if (mounted) setState(() => _message = 'Location sharing is off.');
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    _foreground = state == AppLifecycleState.resumed;
    if (!_foreground && _enabled) {
      unawaited(_stop());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _profile?.cancel();
    _delivery?.cancel();
    _positions?.cancel();
    if (_enabled) unawaited(_stop());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => _active
      ? SwitchListTile(
          title: const Text('Share delivery location'),
          subtitle: Text(_message),
          value: _enabled,
          onChanged: _busy ? null : (v) => v ? _start() : _stop(),
        )
      : const SizedBox.shrink();
}
