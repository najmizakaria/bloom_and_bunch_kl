import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/theme/app_colors.dart';
import 'address_book_screen.dart';
import 'become_rider_screen.dart';
import 'favourites_screen.dart';
import 'order_history_screen.dart';
import 'order_tracking_screen.dart';

// Store contact information.
const String _storeWhatsAppNumber =
    '60148376919'; // country code, no + or spaces
const String _storePhoneNumber = '+60148376919';
const String _storeAddress =
    'Unit G2, StreetMall Cyberjaya, Cyberjaya, 63000 Cyberjaya, Selangor';
const String _storeHours = 'Daily, 9:00 AM – 7:00 PM';
const String _appVersion = '1.0.0';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  bool _notificationsEnabled = true;

  Future<void> _switchToRider(BuildContext context) async {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;
    try {
      await FirestoreService().switchActiveRole(uid, 'rider');
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Unable to switch dashboards.')),
        );
      }
    }
  }

  Future<void> _editPhoneNumber(
    BuildContext context,
    String currentPhone,
  ) async {
    final controller = TextEditingController(text: currentPhone);
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Phone Number'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.phone,
          decoration: const InputDecoration(hintText: 'e.g. 012-3456789'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
            onPressed: () async {
              await FirestoreService().updateUserFields(uid, {
                'phone': controller.text.trim(),
              });
              if (context.mounted) Navigator.pop(context);
            },
            child: const Text('Save'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteAccount(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete Account'),
        content: const Text(
          'This permanently deletes your account and cannot be undone. Continue?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text(
              'Delete',
              style: TextStyle(color: AppColors.primaryDark),
            ),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid != null) {
        await FirebaseFirestore.instance.collection('users').doc(uid).delete();
      }
      await FirebaseAuth.instance.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      if (e.code == 'requires-recent-login') {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text(
                'Please log out and log back in, then try deleting your account again.',
              ),
            ),
          );
        }
      }
    }
  }

  Future<void> _openWhatsApp(BuildContext context) async {
    final uri = Uri.parse('https://wa.me/$_storeWhatsAppNumber');
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open WhatsApp.')),
        );
      }
    }
  }

  Future<void> _callStore(BuildContext context) async {
    final uri = Uri(scheme: 'tel', path: _storePhoneNumber);
    if (!await launchUrl(uri)) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open phone dialer.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    final uid = user?.uid;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Profile'),
        centerTitle: true,
        automaticallyImplyLeading: false,
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: uid == null
            ? null
            : FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .snapshots(),
        builder: (context, userDocSnapshot) {
          final userData = userDocSnapshot.data?.data();
          final phone = userData?['phone'] ?? '';
          final name = userData?['name'] ?? user?.displayName ?? 'Guest';
          final roles = (userData?['roles'] as List<dynamic>? ?? const [])
              .whereType<String>();
          final hasRiderRole =
              userData?['role'] == 'rider' || roles.contains('rider');

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // ---------- 1. Account Header ----------
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 32,
                        backgroundColor: AppColors.secondarySurface,
                        backgroundImage: (user?.photoURL != null)
                            ? NetworkImage(user!.photoURL!)
                            : null,
                        child: user?.photoURL == null
                            ? const Icon(
                                Icons.person,
                                size: 34,
                                color: AppColors.primary,
                              )
                            : null,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const AppTypography.productTitle(),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              user?.email ?? '',
                              style: const AppTypography.supporting(
                                color: AppColors.textMuted,
                              ),
                            ),
                            const SizedBox(height: 6),
                            GestureDetector(
                              onTap: () => _editPhoneNumber(context, phone),
                              child: Row(
                                children: [
                                  const Icon(
                                    Icons.phone,
                                    size: 14,
                                    color: AppColors.primary,
                                  ),
                                  const SizedBox(width: 4),
                                  Text(
                                    phone.isEmpty ? 'Add phone number' : phone,
                                    style: AppTypography.label(
                                      color: phone.isEmpty
                                          ? AppColors.primaryDark
                                          : AppColors.textDark,
                                    ),
                                  ),
                                  const SizedBox(width: 4),
                                  const Icon(
                                    Icons.edit,
                                    size: 12,
                                    color: AppColors.textMuted,
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // ---------- 2. Active Order (sticky-style card) ----------
              StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                stream: FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerId', isEqualTo: uid)
                    .where(
                      'orderStatus',
                      whereIn: [
                        'Pending',
                        'Awaiting Preparation',
                        'Processing',
                        'Ready for Delivery',
                        'Out for Delivery',
                      ],
                    )
                    .orderBy('createdAt', descending: true)
                    .limit(1)
                    .snapshots(),
                builder: (context, snapshot) {
                  final docs = snapshot.data?.docs ?? [];
                  if (docs.isEmpty) return const SizedBox.shrink();

                  final order = docs.first;
                  final data = order.data();
                  final friendly = _friendlyStatus(
                    data['orderStatus'] ?? 'Pending',
                  );

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Card(
                      color: AppColors.primary,
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(14),
                        leading: const Icon(
                          Icons.local_florist,
                          color: Colors.white,
                        ),
                        title: const Text(
                          'Active Order',
                          style: AppTypography.label(color: Colors.white),
                        ),
                        subtitle: Text(
                          friendly,
                          style: const TextStyle(color: Colors.white70),
                        ),
                        trailing: FilledButton(
                          style: FilledButton.styleFrom(
                            backgroundColor: Colors.white,
                            foregroundColor: AppColors.primary,
                          ),
                          onPressed: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) =>
                                    OrderTrackingScreen(orderId: order.id),
                              ),
                            );
                          },
                          child: const Text('Track'),
                        ),
                      ),
                    ),
                  );
                },
              ),

              _sectionLabel('Your flowers'),
              _menuTile(
                icon: Icons.favorite_border_rounded,
                title: 'Saved bouquets',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const FavouritesScreen()),
                ),
              ),
              _menuTile(
                icon: Icons.receipt_long_outlined,
                title: 'Order History',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const OrderHistoryScreen()),
                ),
              ),

              _sectionLabel('Address Book'),
              _menuTile(
                icon: Icons.location_on_outlined,
                title: 'Saved Addresses & Recipients',
                onTap: () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const AddressBookScreen()),
                ),
              ),

              _sectionLabel('Work With Us'),
              _menuTile(
                icon: Icons.pedal_bike_outlined,
                title: hasRiderRole
                    ? 'Switch to Rider Dashboard'
                    : 'Become a Rider',
                onTap: hasRiderRole
                    ? () => _switchToRider(context)
                    : () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => const BecomeRiderScreen(),
                        ),
                      ),
              ),

              _sectionLabel('Store Support'),
              _menuTile(
                icon: Icons.chat_bubble_outline,
                title: 'Chat with Florist (WhatsApp)',
                onTap: () => _openWhatsApp(context),
              ),
              _menuTile(
                icon: Icons.call_outlined,
                title: 'Call Store',
                onTap: () => _callStore(context),
              ),
              Card(
                child: const Padding(
                  padding: EdgeInsets.all(14),
                  child: Row(
                    children: [
                      Icon(Icons.storefront_outlined, color: AppColors.primary),
                      SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _storeAddress,
                              style: AppTypography.supporting(),
                            ),
                            SizedBox(height: 4),
                            Text(
                              _storeHours,
                              style: AppTypography.caption(
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              _sectionLabel('Settings'),
              Card(
                child: SwitchListTile(
                  activeThumbColor: AppColors.primary,
                  title: const Text('Push Notifications'),
                  subtitle: const Text(
                    'Order status updates',
                    style: AppTypography.caption(),
                  ),
                  value: _notificationsEnabled,
                  onChanged: (val) {
                    setState(() => _notificationsEnabled = val);
                    if (uid != null) {
                      FirestoreService().updateUserFields(uid, {
                        'notificationsEnabled': val,
                      });
                    }
                  },
                ),
              ),

              _sectionLabel('Legal & Account'),
              _menuTile(
                icon: Icons.info_outline,
                title: 'App Version',
                subtitle: _appVersion,
                onTap: null,
              ),
              _menuTile(
                icon: Icons.description_outlined,
                title: 'Terms of Service',
                onTap: () => _showStaticDoc(context, 'Terms of Service'),
              ),
              _menuTile(
                icon: Icons.privacy_tip_outlined,
                title: 'Privacy Policy',
                onTap: () => _showStaticDoc(context, 'Privacy Policy'),
              ),
              const SizedBox(height: 8),
              _menuTile(
                icon: Icons.logout,
                title: 'Log Out',
                titleColor: AppColors.primaryDark,
                onTap: () => AuthService().signOut(),
              ),
              _menuTile(
                icon: Icons.delete_outline,
                title: 'Delete Account',
                titleColor: AppColors.primaryDark,
                onTap: () => _confirmDeleteAccount(context),
              ),
              const SizedBox(height: 20),
            ],
          );
        },
      ),
    );
  }

  Widget _sectionLabel(String text) => Padding(
    padding: const EdgeInsets.only(top: 8, bottom: 8),
    child: Text(
      text,
      style: const AppTypography.label(color: AppColors.textMuted),
    ),
  );

  Widget _menuTile({
    required IconData icon,
    required String title,
    String? subtitle,
    Color? titleColor,
    VoidCallback? onTap,
  }) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        leading: Icon(icon, color: titleColor ?? AppColors.primary),
        title: Text(title, style: TextStyle(color: titleColor)),
        subtitle: subtitle != null ? Text(subtitle) : null,
        trailing: onTap != null ? const Icon(Icons.chevron_right) : null,
        onTap: onTap,
      ),
    );
  }

  void _showStaticDoc(BuildContext context, String title) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(
          child: Text(
            'Add your actual $title content here before publishing the app.',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

String _friendlyStatus(String raw) {
  switch (raw) {
    case 'Awaiting Preparation':
    case 'Pending':
      return 'Received';
    case 'Processing':
      return 'Assembling';
    case 'Ready for Delivery':
      return 'Ready for rider collection';
    case 'Completed':
      return 'Delivered';
    default:
      return raw;
  }
}
