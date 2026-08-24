import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/theme/app_colors.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final user = AuthService().currentUser;

    return Scaffold(
      appBar: AppBar(title: const Text('Profile'), centerTitle: true),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          CircleAvatar(
            radius: 36,
            backgroundColor: AppColors.secondarySurface,
            child: const Icon(Icons.person, size: 40, color: AppColors.primaryRosewood),
          ),
          const SizedBox(height: 12),
          Center(
            child: Text(
              user?.email ?? 'Guest',
              style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600, color: AppColors.textDark),
            ),
          ),
          const SizedBox(height: 24),
          ListTile(
            leading: const Icon(Icons.receipt_long_outlined, color: AppColors.primaryRosewood),
            title: const Text('Order History'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO: build order history screen
          ),
          ListTile(
            leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primaryRosewood),
            title: const Text('Track Live Delivery'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO: build live tracking screen
          ),
          ListTile(
            leading: const Icon(Icons.pedal_bike_outlined, color: AppColors.primaryRosewood),
            title: const Text('Become a Rider'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () {}, // TODO: build rider application screen
          ),
          const Divider(height: 32),
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.redAccent),
            title: const Text('Log Out', style: TextStyle(color: Colors.redAccent)),
            onTap: () => AuthService().signOut(),
          ),
        ],
      ),
    );
  }
}