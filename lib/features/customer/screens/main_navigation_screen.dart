import 'package:flutter/material.dart';
import 'customer_home_screen.dart';
import 'bouquet_builder_screen.dart';
import 'bouquet_catalogue_screen.dart';
import 'order_history_screen.dart';
import 'profile_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  final List<Widget> _tabs = const [
    CustomerHomeScreen(),
    BouquetCatalogueScreen(),
    BouquetBuilderScreen(),
    OrderHistoryScreen(),
    ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: _currentIndex, children: _tabs),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _currentIndex,
        onDestinationSelected: (index) => setState(() => _currentIndex = index),
        destinations: const [
          NavigationDestination(
            selectedIcon: Icon(Icons.home_rounded),
            icon: Icon(Icons.home_outlined),
            label: 'Home',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.grid_view_rounded),
            icon: Icon(Icons.grid_view_outlined),
            label: 'Browse',
          ),
          NavigationDestination(
            selectedIcon: ImageIcon(
              AssetImage('assets/icons/flower_bouquet.png'),
            ),
            icon: ImageIcon(AssetImage('assets/icons/flower_bouquet.png')),
            label: 'Create',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.receipt_long_rounded),
            icon: Icon(Icons.receipt_long_outlined),
            label: 'Orders',
          ),
          NavigationDestination(
            selectedIcon: Icon(Icons.person_rounded),
            icon: Icon(Icons.person_outline_rounded),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}
