import 'package:flutter/material.dart';
import '../../../core/services/auth_service.dart';

class FloristDashboardScreen extends StatelessWidget {
  const FloristDashboardScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Florist Dashboard'),
        backgroundColor: Colors.pink[100],
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () => AuthService().signOut(),
          ),
        ],
      ),
      body: const Center(
        child: Text('💐 Florist Order Management (Sprint 5)', style: TextStyle(fontSize: 18)),
      ),
    );
  }
}