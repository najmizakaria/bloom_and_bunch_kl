import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import '../../core/theme/app_colors.dart';
import '../../core/utils/malaysia_time.dart';
import '../florist/screens/florist_products_screen.dart';
import '../support/store_operations_screen.dart';
import 'admin_widgets.dart';
import 'admin_orders_screen.dart';
import 'admin_riders_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_staff_screen.dart';
import 'admin_activity_screen.dart';
import 'admin_inventory_alerts.dart';
import 'admin_layout.dart';

class AdminDashboardScreen extends StatefulWidget {
  const AdminDashboardScreen({super.key});
  @override
  State<AdminDashboardScreen> createState() => _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends State<AdminDashboardScreen> {
  int _index = 0;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: AppColors.softBlushStart,
    appBar: AppBar(
      title: Text(
        [
          'Admin dashboard',
          'Riders',
          'Staff management',
          'Admin settings',
        ][_index],
      ),
      actions: [
        IconButton(
          tooltip: 'Inventory: bouquets and flowers',
          onPressed: () =>
              openAdminPage(context, const FloristProductsScreen()),
          icon: const Icon(Icons.inventory_2_outlined),
        ),
        IconButton(
          tooltip: 'Admin alerts',
          onPressed: () => openAdminPage(context, const AdminActivityScreen()),
          icon: const Icon(Icons.notifications_outlined),
        ),
      ],
    ),
    body: switch (_index) {
      0 => const AdminOverview(),
      1 => const AdminRidersScreen(),
      2 => const AdminStaffScreen(),
      _ => const AdminSettingsScreen(),
    },
    bottomNavigationBar: NavigationBar(
      selectedIndex: _index,
      onDestinationSelected: (value) => setState(() => _index = value),
      destinations: const [
        NavigationDestination(
          icon: Icon(Icons.dashboard_outlined),
          label: 'Dashboard',
        ),
        NavigationDestination(
          icon: Icon(Icons.delivery_dining),
          label: 'Riders',
        ),
        NavigationDestination(icon: Icon(Icons.people_outline), label: 'Staff'),
        NavigationDestination(
          icon: Icon(Icons.settings_outlined),
          label: 'Settings',
        ),
      ],
    ),
  );
}

class AdminOverview extends StatelessWidget {
  const AdminOverview({super.key, this.summaryLoader});
  final Future<Map<String, dynamic>> Function()? summaryLoader;
  @override
  Widget build(BuildContext context) => AdminLoad(
    poll: true,
    load: summaryLoader ?? () => AdminService().call('adminSummary'),
    builder: (data, refresh) {
      String amount(String key) =>
          'RM ${((data[key] as num? ?? 0) / 100).toStringAsFixed(2)}';
      AdminMetric metric(String title, String value, VoidCallback onTap) =>
          AdminMetric(title, value, onTap);
      final now = DateTime.now().toUtc().add(const Duration(hours: 8));
      final today = DateTime(now.year, now.month, now.day);
      final month = DateTimeRange(
        start: DateTime(now.year, now.month),
        end: today,
      );
      void orders({
        String? status,
        String? payment,
        String? mode,
        DateTimeRange? dates,
        String dateField = 'createdAt',
      }) => openAdminPage(
        context,
        AdminOrdersScreen(
          initialStatus: status,
          initialPayment: payment,
          initialMode: mode,
          initialDates: dates,
          initialDateField: dateField,
        ),
      );
      return AdminPage(
        child: ListView(
          padding: const EdgeInsets.only(bottom: 24),
          children: [
            AdminHeading(
              title: 'Store overview',
              subtitle:
                  'Updated ${malaysiaTime(DateTime.fromMillisecondsSinceEpoch((data['generatedAt'] as num? ?? 0).toInt()))}. Refreshes every 30 seconds.',
              actions: [
                TextButton.icon(
                  onPressed: refresh,
                  icon: const Icon(Icons.refresh),
                  label: const Text('Refresh'),
                ),
              ],
            ),
            const SizedBox(height: 24),
            AdminMetricGrid(
              metrics: [
                metric(
                  'Manual payments received today',
                  amount('todayPaidSen'),
                  () => orders(
                    payment: 'paid',
                    mode: 'manual',
                    dates: DateTimeRange(start: today, end: today),
                    dateField: 'paidAt',
                  ),
                ),
                metric(
                  'Manual payments received this month',
                  amount('monthPaidSen'),
                  () => orders(
                    payment: 'paid',
                    mode: 'manual',
                    dates: month,
                    dateField: 'paidAt',
                  ),
                ),
                metric(
                  'Sandbox paid this month · test only',
                  amount('sandboxPaidSen'),
                  () => orders(
                    payment: 'paid',
                    mode: 'toyyibpay_sandbox',
                    dates: month,
                    dateField: 'paidAt',
                  ),
                ),
                metric(
                  'Orders created this month',
                  '${data['monthOrders'] ?? 0}',
                  () => orders(dates: month),
                ),
                metric(
                  'Awaiting / in preparation',
                  '${data['preparation'] ?? 0}',
                  () => orders(status: 'preparation'),
                ),
                metric(
                  'Ready for rider collection',
                  '${data['ready'] ?? 0}',
                  () => orders(status: 'Ready for Delivery'),
                ),
                metric(
                  'Out for delivery',
                  '${data['delivering'] ?? 0}',
                  () => orders(status: 'Out for Delivery'),
                ),
                metric(
                  'Awaiting customer confirmation',
                  '${data['confirmation'] ?? 0}',
                  () => orders(status: 'Awaiting Customer Confirmation'),
                ),
                metric(
                  'Pending payments',
                  '${data['payments'] ?? 0}',
                  () => orders(payment: 'pending'),
                ),
                metric(
                  'Open support issues',
                  '${data['issues'] ?? 0}',
                  () => openAdminPage(context, const StoreOperationsScreen()),
                ),
                metric(
                  'Pending rider applications',
                  '${data['applications'] ?? 0}',
                  () => openAdminPage(
                    context,
                    const AdminRidersScreen(standalone: true, initialTab: 1),
                  ),
                ),
              ],
            ),
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: Text(
                'Payment totals use recorded payment dates in Malaysia time. Demo orders and payments without a recorded payment date are excluded. Sandbox payments are test transactions.',
              ),
            ),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () => orders(),
                  icon: const Icon(Icons.receipt_long),
                  label: const Text('Manage orders'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      openAdminPage(context, const FloristProductsScreen()),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Shared inventory'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      openAdminPage(context, const AdminInventoryAlerts()),
                  icon: const Icon(Icons.warning_amber_outlined),
                  label: const Text('Review stock alerts'),
                ),
                OutlinedButton.icon(
                  onPressed: () =>
                      openAdminPage(context, const StoreOperationsScreen()),
                  icon: const Icon(Icons.support_agent),
                  label: const Text('Support and feedback'),
                ),
              ],
            ),
            if ((data['legacyProducts'] as num? ?? 0) > 0)
              Padding(
                padding: const EdgeInsets.only(top: 12),
                child: Text(
                  '${data['legacyProducts']} legacy product records exist. They are preserved and excluded from live stock; review them before any migration.',
                ),
              ),
          ],
        ),
      );
    },
  );
}
