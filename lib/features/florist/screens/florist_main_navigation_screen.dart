import 'package:flutter/material.dart';
import 'florist_dashboard_screen.dart';
import 'florist_orders_screen.dart';
import 'florist_profile_screen.dart';
import 'florist_products_screen.dart';

class FloristMainNavigationScreen extends StatefulWidget {
  const FloristMainNavigationScreen({super.key});

  @override
  State<FloristMainNavigationScreen> createState() =>
      _FloristMainNavigationScreenState();
}

class _FloristMainNavigationScreenState
    extends State<FloristMainNavigationScreen> {
  int _selectedIndex = 0;

  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      FloristDashboardScreen(
        onOpenOrders: () {
          setState(() {
            _selectedIndex = 1;
          });
        },
        onOpenProducts: () {
          setState(() {
            _selectedIndex = 2;
          });
        },
      ),
      const FloristOrdersScreen(),
      const FloristProductsScreen(),
      const FloristProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _selectedIndex, children: _screens),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _selectedIndex,
        onDestinationSelected: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Catalogue',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
