import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:geolocator/geolocator.dart';
import '../../../core/services/address_service.dart';
import '../../../models/saved_address_model.dart';

class AddressBookScreen extends StatelessWidget {
  static Future<SavedAddressModel?> create(BuildContext context) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const _AddressForm()),
    );
    return AddressService().defaultAddress();
  }

  final bool selectionMode;
  const AddressBookScreen({super.key, this.selectionMode = false});
  Future<void> _edit(BuildContext context, [SavedAddressModel? address]) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(builder: (_) => _AddressForm(existing: address)),
    );
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(selectionMode ? 'Select delivery address' : 'Address Book'),
      actions: [
        IconButton(
          onPressed: () => _edit(context),
          icon: const Icon(Icons.add),
        ),
      ],
    ),
    body: StreamBuilder<List<SavedAddressModel>>(
      stream: AddressService().addressesStream(),
      builder: (context, snapshot) {
        if (snapshot.hasError) {
          return const Center(
            child: Text('Unable to load addresses. Please reopen this page.'),
          );
        }
        if (!snapshot.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final addresses = snapshot.data!;
        if (addresses.isEmpty) {
          return Center(
            child: FilledButton.icon(
              onPressed: () => _edit(context),
              icon: const Icon(Icons.add_location_alt),
              label: const Text('Add your first address'),
            ),
          );
        }
        return ListView(
          children: addresses
              .map(
                (a) => Card(
                  child: ListTile(
                    title: Text(a.label),
                    subtitle: Text(
                      '${a.address}\n${a.recipientName} · ${a.recipientPhone}',
                    ),
                    onTap: selectionMode
                        ? () => Navigator.pop(context, a)
                        : () => _edit(context, a),
                    trailing: PopupMenuButton<String>(
                      onSelected: (value) async {
                        try {
                          if (value == 'edit') {
                            await _edit(context, a);
                          }
                          if (value == 'default') {
                            await AddressService().setDefault(a.id);
                          }
                          if (value == 'delete' && context.mounted) {
                            final confirmed = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: const Text('Delete address?'),
                                actions: [
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, false),
                                    child: const Text('Keep'),
                                  ),
                                  TextButton(
                                    onPressed: () => Navigator.pop(c, true),
                                    child: const Text('Delete'),
                                  ),
                                ],
                              ),
                            );
                            if (confirmed == true) {
                              await AddressService().deleteAddress(a.id);
                            }
                          }
                        } catch (e) {
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Unable to save this change. Please retry.',
                                ),
                              ),
                            );
                          }
                        }
                      },
                      itemBuilder: (_) => const [
                        PopupMenuItem(value: 'edit', child: Text('Edit')),
                        PopupMenuItem(
                          value: 'default',
                          child: Text('Use as default'),
                        ),
                        PopupMenuItem(value: 'delete', child: Text('Delete')),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
        );
      },
    ),
  );
}

class _AddressForm extends StatefulWidget {
  final SavedAddressModel? existing;
  const _AddressForm({this.existing});
  @override
  State<_AddressForm> createState() => _AddressFormState();
}

class _AddressFormState extends State<_AddressForm> {
  final _form = GlobalKey<FormState>();
  final _label = TextEditingController(),
      _address = TextEditingController(),
      _name = TextEditingController(),
      _phone = TextEditingController(),
      _note = TextEditingController();
  bool _busy = false, _default = true;
  double? _lat, _lng;
  @override
  void initState() {
    super.initState();
    final a = widget.existing;
    _label.text = a?.label ?? 'Home';
    _address.text = a?.address ?? '';
    _name.text = a?.recipientName ?? '';
    _phone.text = a?.recipientPhone ?? '';
    _note.text = a?.note ?? '';
    _default = a?.isDefault ?? true;
    _lat = a?.latitude;
    _lng = a?.longitude;
    _loadProfile();
    if (a == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _detect();
      });
    }
  }

  Future<void> _loadProfile() async {
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) return;
      final user = await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .get();
      if (!mounted) return;
      if (_name.text.isEmpty) _name.text = user.data()?['name'] ?? '';
      if (_phone.text.isEmpty) _phone.text = user.data()?['phone'] ?? '';
    } catch (_) {}
  }

  Future<void> _detect() async {
    setState(() => _busy = true);
    try {
      var permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.denied ||
          permission == LocationPermission.deniedForever) {
        throw StateError('Location permission denied');
      }
      final p = await Geolocator.getCurrentPosition(
        locationSettings: const LocationSettings(
          timeLimit: Duration(seconds: 20),
        ),
      );
      final places = await Geocoding().placemarkFromCoordinates(
        p.latitude,
        p.longitude,
      );
      if (!mounted) return;
      if (places.isEmpty) throw StateError('Address not found');
      final a = places.first;
      _address.text = [
        a.street,
        a.subLocality,
        a.locality,
        a.postalCode,
        a.administrativeArea,
        a.country,
      ].whereType<String>().where((s) => s.isNotEmpty).toSet().join(', ');
      _lat = p.latitude;
      _lng = p.longitude;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Could not detect a complete address. Please enter it below.',
            ),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate()) return;
    setState(() => _busy = true);
    try {
      await AddressService().saveAddress(
        SavedAddressModel(
          id: widget.existing?.id ?? '',
          label: _label.text.trim(),
          address: _address.text.trim(),
          recipientName: _name.text.trim(),
          recipientPhone: _phone.text.trim(),
          note: _note.text.trim(),
          isDefault: _default,
          latitude: _lat,
          longitude: _lng,
        ),
      );
      if (mounted) Navigator.pop(context);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to save address. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    for (final c in [_label, _address, _name, _phone, _note]) {
      c.dispose();
    }
    super.dispose();
  }

  Widget _field(
    TextEditingController c,
    String label,
    int max, {
    bool optional = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: TextFormField(
      controller: c,
      enabled: !_busy,
      maxLength: max,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      onChanged: c == _address
          ? (_) {
              _lat = null;
              _lng = null;
            }
          : null,
      validator: (s) =>
          !optional && (s == null || s.trim().isEmpty) ? 'Required' : null,
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Delivery address')),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          OutlinedButton.icon(
            onPressed: _busy ? null : _detect,
            icon: const Icon(Icons.my_location),
            label: const Text('Use current location'),
          ),
          const Text('Check your unit, building and street before saving.'),
          const SizedBox(height: 16),
          _field(_label, 'Label', 60),
          _field(_address, 'Full address', 600),
          _field(_name, 'Recipient name', 120),
          _field(_phone, 'Phone', 30),
          _field(_note, 'Delivery note', 300, optional: true),
          SwitchListTile(
            title: const Text('Use as default address'),
            value: _default,
            onChanged: _busy ? null : (v) => setState(() => _default = v),
          ),
          FilledButton(
            onPressed: _busy ? null : _save,
            child: Text(_busy ? 'Please wait…' : 'Save address'),
          ),
        ],
      ),
    ),
  );
}
