import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import '../florist/screens/florist_inventory_screen.dart';
import 'admin_widgets.dart';
import 'admin_layout.dart';
import 'admin_navigation_scope.dart';

class AdminInventoryAlerts extends StatefulWidget {
  const AdminInventoryAlerts({super.key});
  @override
  State<AdminInventoryAlerts> createState() => _AdminInventoryAlertsState();
}

class _AdminInventoryAlertsState extends State<AdminInventoryAlerts> {
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AdminSectionScope.contains(context)
        ? null
        : AppBar(title: const Text('Flower stock alerts')),
    body: AdminLoad(
      recordsKey: 'flowers',
      loadPage: (cursor) =>
          AdminService().call('adminInventoryAlerts', {'after': ?cursor}),
      builder: (data, refresh) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (AdminSectionScope.contains(context)) ...[
            const AdminHeading(
              title: 'Stock alerts',
              subtitle: 'Review flower availability and replenishment needs.',
            ),
            const SizedBox(height: 24),
          ],
          Text(
            'Alerts use physical stock minus reserved stems. Negative balances require restocking; custom-order sourceability remains separate.',
          ),

          if ((data['flowers'] as List).isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text('No stock alerts.'),
            ),
          for (final f in data['flowers'] as List)
            Card(
              child: ListTile(
                leading: const Icon(Icons.warning_amber_outlined),
                title: Text('${f['name']}'),
                subtitle: Text(
                  'On hand: ${f['stock']} · Reserved: ${f['reserved']}\nAvailable balance: ${(f['stock'] as num) - (f['reserved'] as num)}',
                ),
              ),
            ),
          FilledButton(
            onPressed: () =>
                openAdminPage(context, const FloristInventoryScreen()),
            child: const Text('Manage shared flower inventory'),
          ),
          const SizedBox(height: 12),
        ],
      ),
    ),
  );
}
