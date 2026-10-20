import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import '../florist/screens/florist_inventory_screen.dart';
import 'admin_widgets.dart';

class AdminInventoryAlerts extends StatefulWidget {
  const AdminInventoryAlerts({super.key});
  @override
  State<AdminInventoryAlerts> createState() => _AdminInventoryAlertsState();
}

class _AdminInventoryAlertsState extends State<AdminInventoryAlerts> {
  final List<String?> _pages = [null];
  int _revision = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Flower stock alerts')),
    body: AdminLoad(
      key: ValueKey(_revision),
      load: () => AdminService().call('adminInventoryAlerts', {
        if (_pages.last != null) 'after': _pages.last,
      }),
      builder: (data, refresh) => ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Reviewed ${data['scanned']} flowers on page ${_pages.length}. Alerts use physical stock minus reserved stems. Negative balances require restocking; custom-order sourceability remains separate.',
          ),
          TextButton.icon(
            onPressed: refresh,
            icon: const Icon(Icons.refresh),
            label: const Text('Refresh this page'),
          ),
          if ((data['flowers'] as List).isEmpty)
            const Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'No stock alerts on this inventory page. Continue to review the next page.',
              ),
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
          Wrap(
            spacing: 12,
            children: [
              OutlinedButton(
                onPressed: _pages.length > 1
                    ? () => setState(() {
                        _pages.removeLast();
                        _revision++;
                      })
                    : null,
                child: const Text('Previous'),
              ),
              FilledButton(
                onPressed: data['next'] != null
                    ? () => setState(() {
                        _pages.add(data['next'] as String);
                        _revision++;
                      })
                    : null,
                child: const Text('Next'),
              ),
            ],
          ),
        ],
      ),
    ),
  );
}
