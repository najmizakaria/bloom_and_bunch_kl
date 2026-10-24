import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
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
  final Set<int> _visited = {0};
  final _productsKey = GlobalKey<FloristProductsScreenState>();

  final _ordersKey = GlobalKey<FloristOrdersScreenState>();
  late final List<Widget> _screens;

  @override
  void initState() {
    super.initState();

    _screens = [
      FloristDashboardScreen(
        onOpenOrders: (status) {
          setState(() {
            _selectedIndex = 1;
            _visited.add(1);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _ordersKey.currentState?.selectStatus(status);
          });
        },
        onOpenProducts: (tab) {
          setState(() {
            _selectedIndex = 2;
            _visited.add(2);
          });
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted) _productsKey.currentState?.selectTab(tab);
          });
        },
      ),
      FloristOrdersScreen(key: _ordersKey),
      FloristProductsScreen(key: _productsKey),
      const FloristProfileScreen(),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return PageNavigationScope(
      canGoHome: _selectedIndex != 0,
      onHome: () => setState(() => _selectedIndex = 0),
      child: Scaffold(
        body: IndexedStack(
          index: _selectedIndex,
          children: List.generate(
            _screens.length,
            (i) => _visited.contains(i) ? _screens[i] : const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _selectedIndex,
          onDestinationSelected: (index) {
            setState(() {
              _selectedIndex = index;
              _visited.add(index);
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
              icon: Icon(Icons.more_horiz),
              selectedIcon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
