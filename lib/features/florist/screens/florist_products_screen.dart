import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import 'florist_bouquets_tab.dart';
import 'florist_inventory_screen.dart';
import 'commerce_catalogue_screen.dart';
import '../../admin/admin_navigation_scope.dart';
import '../../admin/admin_layout.dart';

class FloristProductsScreen extends StatefulWidget {
  const FloristProductsScreen({super.key, this.initialTab = 0});
  final int initialTab;
  @override
  State<FloristProductsScreen> createState() => FloristProductsScreenState();
}

class FloristProductsScreenState extends State<FloristProductsScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _controller = TabController(
    length: 4,
    initialIndex: widget.initialTab,
    vsync: this,
  )..addListener(_changed);
  late final Set<int> _visited = {widget.initialTab};
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
      leading: AdminSectionScope.contains(context)
          ? null
          : const PageBackButton(),
      automaticallyImplyLeading: !AdminSectionScope.contains(context),
      toolbarHeight: AdminSectionScope.contains(context) ? 0 : kToolbarHeight,
      centerTitle: false,
      title: const Text('Products'),
      backgroundColor: AdminSectionScope.contains(context)
          ? Colors.white
          : AppColors.primary,
      foregroundColor: AdminSectionScope.contains(context)
          ? Theme.of(context).colorScheme.onSurface
          : Colors.white,
      bottom: TabBar(
        isScrollable: true,
        controller: _controller,
        labelColor: AdminSectionScope.contains(context)
            ? Theme.of(context).colorScheme.primary
            : Colors.white,
        unselectedLabelColor: AdminSectionScope.contains(context)
            ? Theme.of(context).colorScheme.onSurfaceVariant
            : Colors.white70,
        tabs: const [
          Tab(icon: Icon(Icons.local_florist), text: 'Bouquets'),
          Tab(icon: Icon(Icons.grass), text: 'Flowers'),
          Tab(icon: Icon(Icons.redeem), text: 'Add-ons'),
          Tab(icon: Icon(Icons.mail_outline), text: 'Cards'),
        ],
      ),
    ),
    body: Column(
      children: [
        if (AdminSectionScope.contains(context))
          const Padding(
            padding: EdgeInsets.fromLTRB(24, 20, 24, 8),
            child: AdminHeading(
              title: 'Inventory',
              subtitle: 'Manage bouquets, flowers, add-ons and card designs.',
            ),
          ),
        Expanded(
          child: TabBarView(
            controller: _controller,
            children: [
              _visited.contains(0)
                  ? const FloristBouquetsTab()
                  : const SizedBox.shrink(),
              _visited.contains(1)
                  ? const FloristInventoryScreen(showAppBar: false)
                  : const SizedBox.shrink(),
              _visited.contains(2)
                  ? const CommerceCatalogueScreen(kind: 'addons')
                  : const SizedBox.shrink(),
              _visited.contains(3)
                  ? const CommerceCatalogueScreen(kind: 'card_designs')
                  : const SizedBox.shrink(),
            ],
          ),
        ),
      ],
    ),
  );
}
