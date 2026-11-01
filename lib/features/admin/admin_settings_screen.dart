import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import '../../core/services/notification_service.dart';
import '../../core/widgets/logout_tile.dart';
import '../support/store_operations_screen.dart';
import 'admin_widgets.dart';
import 'admin_layout.dart';
import 'admin_activity_screen.dart';

class AdminSettingsScreen extends StatelessWidget {
  const AdminSettingsScreen({super.key});
  @override
  Widget build(BuildContext context) => AdminPage(
    child: ListView(
      padding: const EdgeInsets.only(bottom: 24),
      children: [
        const AdminHeading(
          title: 'Administration',
          subtitle: 'Manage your account, store operations and preferences.',
        ),
        const SizedBox(height: 24),
        Card(
          child: ListTile(
            leading: const Icon(Icons.person_outline),
            title: const Text('Admin profile'),
            subtitle: const Text('Update your name and phone number'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => openAdminPage(context, const AdminProfileScreen()),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.lock_outline),
            title: const Text('Security'),
            subtitle: const Text(
              'Reset your password through your registered email',
            ),
            onTap: () async {
              final u = FirebaseAuth.instance.currentUser;
              if (u?.email == null) return;
              if (!u!.providerData.any((p) => p.providerId == 'password')) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Manage sign-in security through your Google account.',
                    ),
                  ),
                );
                return;
              }
              await adminAction(
                context,
                () => FirebaseAuth.instance.sendPasswordResetEmail(
                  email: u.email!,
                ),
                success: 'Password reset email sent. Check your inbox.',
              );
            },
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.storefront_outlined),
            title: const Text('Store operations'),
            subtitle: const Text(
              'Opening days, delivery area, cutoff and capacity',
            ),
            onTap: () => openAdminPage(context, const AdminStorePolicyScreen()),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.notifications_outlined),
            title: const Text('Notifications'),
            subtitle: const Text(
              'Save admin alert preferences and device push settings',
            ),
            onTap: () => openAdminPage(context, const AdminPreferencesScreen()),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.support_agent),
            title: const Text('Order support and feedback'),
            onTap: () => openAdminPage(context, const StoreOperationsScreen()),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: ListTile(
            leading: const Icon(Icons.history),
            title: const Text('Administrative activity'),
            subtitle: const Text(
              'Staff access, payment checks, store changes and order events',
            ),
            onTap: () =>
                openAdminPage(context, const AdminActivityScreen(audit: true)),
          ),
        ),
        const SizedBox(height: 12),
        const LogoutTile(),
      ],
    ),
  );
}

class AdminProfileScreen extends StatefulWidget {
  const AdminProfileScreen({super.key});
  @override
  State<AdminProfileScreen> createState() => AdminProfileScreenState();
}

class AdminProfileScreenState extends State<AdminProfileScreen> {
  final _name = TextEditingController(), _phone = TextEditingController();
  bool _loaded = false, _busy = false;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Admin profile')),
    body: AdminLoad(
      load: () async {
        final u = FirebaseAuth.instance.currentUser;
        final s = await FirebaseFirestore.instance.doc('users/${u!.uid}').get();
        return s.data() ?? {};
      },
      builder: (data, refresh) {
        if (!_loaded) {
          _name.text = data['name'] ?? '';
          _phone.text = data['phone'] ?? '';
          _loaded = true;
        }
        return ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text('${data['email'] ?? ''}'),
            const SizedBox(height: 16),
            TextField(
              controller: _name,
              maxLength: 120,
              decoration: const InputDecoration(labelText: 'Full name'),
            ),
            TextField(
              controller: _phone,
              maxLength: 30,
              decoration: const InputDecoration(labelText: 'Phone number'),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      if (_name.text.trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Enter your name.')),
                        );
                        return;
                      }
                      setState(() => _busy = true);
                      await adminAction(
                        context,
                        () => FirebaseFirestore.instance
                            .doc(
                              'users/${FirebaseAuth.instance.currentUser!.uid}',
                            )
                            .update({
                              'name': _name.text.trim(),
                              'phone': _phone.text.trim(),
                              'updatedAt': FieldValue.serverTimestamp(),
                            }),
                      );
                      if (mounted) setState(() => _busy = false);
                    },
              child: const Text('Save profile'),
            ),
          ],
        );
      },
    ),
  );
}

class AdminPreferencesScreen extends StatefulWidget {
  const AdminPreferencesScreen({super.key});
  @override
  State<AdminPreferencesScreen> createState() => AdminPreferencesScreenState();
}

class AdminPreferencesScreenState extends State<AdminPreferencesScreen> {
  bool _orders = true,
      _riders = true,
      _push = false,
      _loaded = false,
      _busy = false;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Notification preferences')),
    body: AdminLoad(
      load: () async {
        final uid = FirebaseAuth.instance.currentUser!.uid;
        final prefs = await FirebaseFirestore.instance
            .doc('admin_preferences/$uid')
            .get();
        final profile = await FirebaseFirestore.instance
            .doc('users/$uid')
            .get();
        return {
          ...?prefs.data(),
          'push': profile.data()?['notificationsEnabled'] == true,
        };
      },
      builder: (data, refresh) {
        if (!_loaded) {
          _orders = data['orders'] != false;
          _riders = data['riders'] != false;
          _push = data['push'] == true;
          _loaded = true;
        }
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'These preferences control the admin alert inbox. Push permission is configured separately for this device.',
            ),
            SwitchListTile(
              title: const Text('Order, payment, support and stock alerts'),
              value: _orders,
              onChanged: _busy ? null : (v) => setState(() => _orders = v),
            ),
            SwitchListTile(
              title: const Text('Rider application alerts'),
              value: _riders,
              onChanged: _busy ? null : (v) => setState(() => _riders = v),
            ),
            FilledButton(
              onPressed: _busy
                  ? null
                  : () async {
                      setState(() => _busy = true);
                      await adminAction(context, () async {
                        await AdminService().call('saveAdminPreferences', {
                          'orders': _orders,
                          'riders': _riders,
                        });
                      });
                      if (mounted) setState(() => _busy = false);
                    },
              child: const Text('Save alert preferences'),
            ),
            const Divider(),
            SwitchListTile(
              title: const Text('Push notifications on this device'),
              subtitle: const Text(
                'Uses the shared notification service. Browser/device permission is required.',
              ),
              value: _push,
              onChanged: !NotificationService.supported || _busy
                  ? null
                  : (v) async {
                      setState(() => _busy = true);
                      final saved = await adminAction(
                        context,
                        () => NotificationService.instance.setEnabled(v),
                      );
                      if (mounted) {
                        setState(() {
                          if (saved) _push = v;
                          _busy = false;
                        });
                      }
                    },
            ),
          ],
        );
      },
    ),
  );
}

class AdminStorePolicyScreen extends StatefulWidget {
  const AdminStorePolicyScreen({super.key});
  @override
  State<AdminStorePolicyScreen> createState() => AdminStorePolicyScreenState();
}

class AdminStorePolicyScreenState extends State<AdminStorePolicyScreen> {
  final _open = TextEditingController(),
      _cutoff = TextEditingController(),
      _capacity = TextEditingController(),
      _booking = TextEditingController(),
      _instructions = TextEditingController(),
      _holidays = TextEditingController(),
      _latitude = TextEditingController(),
      _longitude = TextEditingController(),
      _radius = TextEditingController(),
      _area = TextEditingController();
  final Set<int> _days = {};
  bool _loaded = false, _busy = false, _limitArea = false;
  @override
  void dispose() {
    for (final c in [
      _open,
      _cutoff,
      _capacity,
      _booking,
      _instructions,
      _holidays,
      _latitude,
      _longitude,
      _radius,
      _area,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Store operations')),
    body: AdminLoad(
      load: () => AdminService().call('adminStorePolicy'),
      builder: (data, refresh) {
        final p = Map<String, dynamic>.from(data['policy'] as Map? ?? {});
        if (!_loaded) {
          _open.text = '${p['openingHour'] ?? 9}';
          _cutoff.text = '${p['cutoffHour'] ?? 17}';
          _capacity.text = '${p['dailyDeliveryCapacity'] ?? 0}';
          _booking.text = '${p['bookingWindowDays'] ?? 90}';
          _instructions.text = p['paymentInstructions'] ?? '';
          _holidays.text = (p['holidays'] as List? ?? []).join(', ');
          _days.addAll((p['operatingWeekdays'] as List? ?? []).cast<int>());
          final a = p['serviceArea'];
          _limitArea = a is Map;
          if (a is Map) {
            _area.text = a['label'] ?? '';
            _latitude.text = '${a['latitude']}';
            _longitude.text = '${a['longitude']}';
            _radius.text = '${a['radiusKm']}';
          }
          _loaded = true;
        }
        Widget field(
          TextEditingController c,
          String label, {
          bool number = false,
          int lines = 1,
        }) => Padding(
          padding: const EdgeInsets.only(bottom: 16),
          child: TextField(
            controller: c,
            enabled: !_busy,
            keyboardType: number
                ? const TextInputType.numberWithOptions(
                    decimal: true,
                    signed: true,
                  )
                : TextInputType.text,
            maxLines: lines,
            decoration: InputDecoration(labelText: label),
          ),
        );
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 700),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Text(
                    'Current order mode: ${p['mode']}. Payment mode and gateway credentials remain deployment settings.',
                  ),
                  const SizedBox(height: 16),
                  const Text('Operating days · Malaysia time'),
                  Wrap(
                    spacing: 8,
                    children: List.generate(
                      7,
                      (i) => FilterChip(
                        label: Text(
                          const [
                            'Sun',
                            'Mon',
                            'Tue',
                            'Wed',
                            'Thu',
                            'Fri',
                            'Sat',
                          ][i],
                        ),
                        selected: _days.contains(i),
                        onSelected: _busy
                            ? null
                            : (selected) => setState(() {
                                if (selected) {
                                  _days.add(i);
                                } else {
                                  _days.remove(i);
                                }
                              }),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  field(_open, 'Opening hour (0–23)', number: true),
                  field(_cutoff, 'Order cutoff hour (1–24)', number: true),
                  field(
                    _capacity,
                    'Daily delivery capacity (0 = unlimited)',
                    number: true,
                  ),
                  field(
                    _holidays,
                    'Closed dates: YYYY-MM-DD, separated by commas',
                  ),
                  field(
                    _booking,
                    'Booking window in days (7–365)',
                    number: true,
                  ),
                  field(_instructions, 'Manual payment instructions', lines: 3),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Limit delivery to a service area'),
                    value: _limitArea,
                    onChanged: _busy
                        ? null
                        : (v) => setState(() => _limitArea = v),
                  ),
                  if (_limitArea) ...[
                    field(_area, 'Service area name'),
                    field(_latitude, 'Centre latitude', number: true),
                    field(_longitude, 'Centre longitude', number: true),
                    field(_radius, 'Delivery radius in km', number: true),
                  ],
                  const Text(
                    'Changes apply to new checkout quotes. Existing orders retain their recorded totals and dates. Customers with an older quote will be asked to refresh it.',
                  ),
                  const SizedBox(height: 16),
                  FilledButton(
                    onPressed: _busy
                        ? null
                        : () async {
                            setState(() => _busy = true);
                            await adminAction(context, () async {
                              await AdminService().call(
                                'saveAdminStorePolicy',
                                {
                                  'policy': {
                                    'openingHour': int.tryParse(_open.text),
                                    'bookingWindowDays': int.tryParse(
                                      _booking.text,
                                    ),
                                    'cutoffHour': int.tryParse(_cutoff.text),
                                    'dailyDeliveryCapacity': int.tryParse(
                                      _capacity.text,
                                    ),
                                    'operatingWeekdays': _days.toList()..sort(),
                                    'holidays': _holidays.text
                                        .split(',')
                                        .map((s) => s.trim())
                                        .where((s) => s.isNotEmpty)
                                        .toList(),
                                    'paymentInstructions': _instructions.text
                                        .trim(),
                                    'serviceArea': _limitArea
                                        ? {
                                            'label': _area.text.trim(),
                                            'latitude': double.tryParse(
                                              _latitude.text,
                                            ),
                                            'longitude': double.tryParse(
                                              _longitude.text,
                                            ),
                                            'radiusKm': double.tryParse(
                                              _radius.text,
                                            ),
                                          }
                                        : null,
                                  },
                                },
                              );
                            });
                            if (mounted) setState(() => _busy = false);
                          },
                    child: const Text('Save store operations'),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    ),
  );
}
