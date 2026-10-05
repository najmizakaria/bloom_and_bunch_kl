import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:flutter/material.dart';
import '../../core/widgets/logout_tile.dart';
import 'admin_dashboard_screen.dart';
import 'rider_history_screen.dart';

class AdminMainScreen extends StatefulWidget {
  const AdminMainScreen({super.key});
  @override
  State<AdminMainScreen> createState() => _AdminMainScreenState();
}

class _AdminMainScreenState extends State<AdminMainScreen> {
  int _index = 0;
  final _visited = {0};
  @override
  Widget build(BuildContext context) => PageNavigationScope(
    canGoHome: _index != 0,
    onHome: () => setState(() => _index = 0),
    child: Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          const AdminDashboardScreen(),
          _visited.contains(1)
              ? const RiderHistoryScreen()
              : const SizedBox.shrink(),
          const AccountMoreScreen(),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: (i) => setState(() {
          _index = i;
          _visited.add(i);
        }),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.dashboard_outlined),
            label: 'Dashboard',
          ),
          NavigationDestination(
            icon: Icon(Icons.history),
            label: 'Rider history',
          ),
          NavigationDestination(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    ),
  );
}
