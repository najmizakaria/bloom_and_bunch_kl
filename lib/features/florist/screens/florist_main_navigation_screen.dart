import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'florist_dashboard_screen.dart';
import 'florist_orders_screen.dart';
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
      const _FloristPlaceholderScreen(
        title: 'More',
        icon: Icons.more_horiz,
        message: 'Store options',
        description: 'Additional florist options will appear here.',
      ),
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
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _FloristPlaceholderScreen extends StatelessWidget {
  const _FloristPlaceholderScreen({
    required this.title,
    required this.icon,
    required this.message,
    required this.description,
  });

  final String title;
  final IconData icon;
  final String message;
  final String description;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(title)),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: AppColors.primary),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(description, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}
