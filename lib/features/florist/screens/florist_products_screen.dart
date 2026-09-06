import 'package:flutter/material.dart';

import 'florist_bouquets_tab.dart';
import 'florist_inventory_screen.dart';

class FloristProductsScreen extends StatelessWidget {
  const FloristProductsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: const Color(0xFFF7F7F7),
        appBar: AppBar(
          title: const Text('Products'),
          backgroundColor: Colors.teal,
          foregroundColor: Colors.white,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(
                icon: Icon(Icons.local_florist),
                text: 'Bouquets',
              ),
              Tab(
                icon: Icon(Icons.grass),
                text: 'Flowers',
              ),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            FloristBouquetsTab(),
            FloristInventoryScreen(showAppBar: false),
          ],
        ),
      ),
    );
  }
}