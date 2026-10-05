import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'florist_bouquets_tab.dart';
import 'florist_inventory_screen.dart';

class FloristProductsScreen extends StatefulWidget {
  const FloristProductsScreen({super.key});
  @override
  State<FloristProductsScreen> createState() => FloristProductsScreenState();
}

class FloristProductsScreenState extends State<FloristProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(length: 2, vsync: this)
    ..addListener(_changed);
  final Set<int> _visited = {0};
  void _changed() {
    if (!_visited.contains(_controller.index)) {
      setState(() => _visited.add(_controller.index));
    }
  }

  void selectTab(int index) {
    setState(() => _visited.add(index));
    _controller.animateTo(index);
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PageBackButton(),
      centerTitle: false,
      title: const Text('Products'),
      backgroundColor: AppColors.primary,
      foregroundColor: Colors.white,
      bottom: TabBar(
        controller: _controller,
        labelColor: Colors.white,
        unselectedLabelColor: Colors.white70,
        tabs: const [
          Tab(icon: Icon(Icons.local_florist), text: 'Bouquets'),
          Tab(icon: Icon(Icons.grass), text: 'Flowers'),
        ],
      ),
    ),
    body: TabBarView(
      controller: _controller,
      children: [
        _visited.contains(0)
            ? const FloristBouquetsTab()
            : const SizedBox.shrink(),
        _visited.contains(1)
            ? const FloristInventoryScreen(showAppBar: false)
            : const SizedBox.shrink(),
      ],
    ),
  );
}
