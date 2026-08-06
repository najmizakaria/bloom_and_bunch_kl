import 'package:flutter/material.dart';
import '../../core/services/auth_service.dart';

class CustomerHomeScreen extends StatelessWidget {
  const CustomerHomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Bloom & Bunch KL'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text('🌸 Customer Portal (Sprint 2 Core)', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}