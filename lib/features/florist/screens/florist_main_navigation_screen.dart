import 'package:flutter/material.dart';
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
      body: IndexedStack(
        index: _selectedIndex,
        children: _screens,
      ),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (index) {
          setState(() {
            _selectedIndex = index;
          });
        },
        type: BottomNavigationBarType.fixed,
        selectedItemColor: Colors.teal,
        unselectedItemColor: Colors.grey,
        items: const [
          BottomNavigationBarItem(
            icon: Icon(Icons.home_outlined),
            activeIcon: Icon(Icons.home),
            label: 'Home',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.receipt_long_outlined),
            activeIcon: Icon(Icons.receipt_long),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.inventory_2_outlined),
            activeIcon: Icon(Icons.inventory_2),
            label: 'Products',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.more_horiz),
            label: 'More',
          ),
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
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.teal,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, size: 64, color: Colors.teal),
              const SizedBox(height: 16),
              Text(
                message,
                textAlign: TextAlign.center,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 8),
              Text(
                description,
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}