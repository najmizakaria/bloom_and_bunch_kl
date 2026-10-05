import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
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
  final Set<int> _visited = {0};

  final _browseKey = GlobalKey<BouquetCatalogueScreenState>();
  late final List<Widget> _tabs = [
    CustomerHomeScreen(
      onBrowse: (category, mode) {
        setState(() {
          _currentIndex = 1;
          _visited.add(1);
        });
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) {
            _browseKey.currentState?.selectFilters(category, mode);
          }
        });
      },
    ),
    BouquetCatalogueScreen(key: _browseKey),
    const BouquetBuilderScreen(),
    const OrderHistoryScreen(),
    const ProfileScreen(),
  ];

  @override
  Widget build(BuildContext context) {
    return PageNavigationScope(
      canGoHome: _currentIndex != 0,
      onHome: () => setState(() => _currentIndex = 0),
      child: Scaffold(
        body: IndexedStack(
          index: _currentIndex,
          children: List.generate(
            _tabs.length,
            (i) => _visited.contains(i) ? _tabs[i] : const SizedBox.shrink(),
          ),
        ),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _currentIndex,
          onDestinationSelected: (index) => setState(() {
            _currentIndex = index;
            _visited.add(index);
          }),
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
              selectedIcon: Icon(Icons.more_horiz),
              icon: Icon(Icons.more_horiz),
              label: 'More',
            ),
          ],
        ),
      ),
    );
  }
}
