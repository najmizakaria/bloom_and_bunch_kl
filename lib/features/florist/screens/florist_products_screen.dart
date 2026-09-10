import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
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
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Products'),
          backgroundColor: AppColors.primary,
          foregroundColor: AppColors.onPrimary,
          bottom: const TabBar(
            indicatorColor: Colors.white,
            indicatorWeight: 3,
            labelColor: Colors.white,
            unselectedLabelColor: Colors.white70,
            tabs: [
              Tab(icon: Icon(Icons.local_florist), text: 'Bouquets'),
              Tab(icon: Icon(Icons.grass), text: 'Flowers'),
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
