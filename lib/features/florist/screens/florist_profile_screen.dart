import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import '../../support/store_operations_screen.dart';

class FloristProfileScreen extends StatefulWidget {
  const FloristProfileScreen({super.key});

  @override
  State<FloristProfileScreen> createState() => _FloristProfileScreenState();
}

class _FloristProfileScreenState extends State<FloristProfileScreen> {
  bool _signingOut = false;

  Future<void> _editProfile(String uid, Map<String, dynamic> profile) async {
    final saved = await showDialog<bool>(
      context: context,
      builder: (_) => _EditFloristProfileDialog(
        uid: uid,
        name: profile['name']?.toString() ?? '',
        phone: profile['phone']?.toString() ?? '',
      ),
    );
    if (saved == true && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Profile updated.')));
    }
  }

  Future<void> _signOut() async {
    if (_signingOut) return;
    setState(() => _signingOut = true);
    try {
      await AuthService().signOut();
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _signingOut = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Profile'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: uid == null
          ? const Center(child: Text('Please sign in to view your profile.'))
          : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
              stream: FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
              builder: (context, snapshot) {
                if (snapshot.hasError) {
                  return const Center(
                    child: Text(
                      'Could not load your profile. Please try again.',
                    ),
                  );
                }
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final profile = snapshot.data!.data();
                if (profile == null) {
                  return const Center(child: Text('Profile unavailable.'));
                }

                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(20),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              profile['name']?.toString() ?? 'Florist',
                              style: Theme.of(context).textTheme.headlineSmall,
                            ),
                            const SizedBox(height: 16),
                            _detail(
                              'Email',
                              profile['email']?.toString() ?? '',
                            ),
                            const SizedBox(height: 12),
                            _detail(
                              'Phone',
                              profile['phone']?.toString() ?? '',
                            ),
                            const SizedBox(height: 16),
                            OutlinedButton.icon(
                              onPressed: () => _editProfile(uid, profile),
                              icon: const Icon(Icons.edit_outlined),
                              label: const Text('Edit name and phone'),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Card(
                      child: ListTile(
                        leading: const Icon(Icons.support_agent_outlined),
                        title: const Text('Store support'),
                        subtitle: const Text(
                          'Review issues, riders, payments and feedback',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const StoreOperationsScreen(),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    OutlinedButton.icon(
                      onPressed: _signingOut ? null : _signOut,
                      icon: const Icon(Icons.logout),
                      label: Text(_signingOut ? 'Logging out…' : 'Log out'),
                    ),
                  ],
                );
              },
            ),
    );
  }

  Widget _detail(String label, String value) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(label, style: const TextStyle(color: AppColors.textMuted)),
      const SizedBox(height: 4),
      Text(value.isEmpty ? 'Not provided' : value),
    ],
  );
}

class _EditFloristProfileDialog extends StatefulWidget {
  const _EditFloristProfileDialog({
    required this.uid,
    required this.name,
    required this.phone,
  });

  final String uid;
  final String name;
  final String phone;

  @override
  State<_EditFloristProfileDialog> createState() =>
      _EditFloristProfileDialogState();
}

class _EditFloristProfileDialogState extends State<_EditFloristProfileDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _phone;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.name);
    _phone = TextEditingController(text: widget.phone);
  }

  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() => _saving = true);
    try {
      if (FirebaseAuth.instance.currentUser?.uid != widget.uid) {
        throw StateError('Your session changed. Please sign in again.');
      }
      await FirestoreService().updateUserFields(widget.uid, {
        'name': _name.text.trim(),
        'phone': _phone.text.trim(),
      });
      if (mounted) Navigator.pop(context, true);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save your profile. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: const Text('Edit profile'),
    content: Form(
      key: _form,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _name,
            maxLength: 120,
            textCapitalization: TextCapitalization.words,
            decoration: const InputDecoration(labelText: 'Name'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your name.'
                : null,
          ),
          TextFormField(
            controller: _phone,
            maxLength: 30,
            keyboardType: TextInputType.phone,
            decoration: const InputDecoration(labelText: 'Phone'),
            validator: (value) => value == null || value.trim().isEmpty
                ? 'Enter your phone number.'
                : null,
          ),
        ],
      ),
    ),
    actions: [
      TextButton(
        onPressed: _saving ? null : () => Navigator.pop(context),
        child: const Text('Cancel'),
      ),
      FilledButton(
        onPressed: _saving ? null : _save,
        child: Text(_saving ? 'Saving…' : 'Save'),
      ),
    ],
  );
}
