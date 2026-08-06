import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class RiderDashboardScreen extends StatelessWidget {
  const RiderDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Rider Delivery Hub'),
        backgroundColor: Colors.green[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text('🛵 Rider Delivery System (Sprint 6)', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}