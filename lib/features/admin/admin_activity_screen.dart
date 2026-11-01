import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../../core/utils/malaysia_time.dart';
import '../../core/widgets/firestore_page.dart';
import 'admin_widgets.dart';
import 'admin_order_detail_screen.dart';
import 'admin_layout.dart';
import 'admin_navigation_scope.dart';

class AdminActivityScreen extends StatelessWidget {
  const AdminActivityScreen({super.key, this.audit = false});
  final bool audit;
  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      return const Scaffold(body: Center(child: Text('Please sign in.')));
    }
    Widget records(Map<String, dynamic> prefs) => FirestorePage(
      query: FirebaseFirestore.instance
          .collection(audit ? 'admin_audit' : 'admin_alerts')
          .orderBy('createdAt', descending: true),
      emptyMessage: audit
          ? 'No recorded administrative actions.'
          : 'No admin alerts yet.',
      builder: (context, docs) {
        final visible = docs
            .where((d) => audit || prefs[d.data()['kind']] != false)
            .toList();
        return ListView(
          padding: const EdgeInsets.only(bottom: 88),
          children: [
            if (visible.isEmpty)
              const Padding(
                padding: EdgeInsets.all(24),
                child: Text('No alerts match your saved preferences.'),
              ),
            for (final doc in visible)
              ListTile(
                leading: Icon(
                  audit ? Icons.history : Icons.notifications_outlined,
                ),
                title: Text(
                  '${doc.data()['title'] ?? doc.data()['action'] ?? 'Activity'}',
                ),
                subtitle: Text(
                  '${doc.data()['target'] ?? doc.data()['orderId'] ?? ''}\n${doc.data()['actorId'] ?? 'System'} · ${doc.data()['createdAt'] is Timestamp ? malaysiaTime((doc.data()['createdAt'] as Timestamp).toDate()) : 'Time not recorded'}',
                ),
                isThreeLine: true,
                onTap: doc.data()['orderId'] != null
                    ? () => openAdminPage(
                        context,
                        AdminOrderDetailScreen(orderId: doc.data()['orderId']),
                      )
                    : null,
              ),
          ],
        );
      },
    );
    final embedded = AdminSectionScope.contains(context);
    final content = audit
        ? records({})
        : StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
            stream: FirebaseFirestore.instance
                .doc('admin_preferences/$uid')
                .snapshots(),
            builder: (context, s) {
              if (s.hasError) {
                return const Center(
                  child: Text(
                    'Could not load notification preferences. Reopen to retry.',
                  ),
                );
              }
              if (!s.hasData) {
                return const Center(child: CircularProgressIndicator());
              }
              return records(s.data?.data() ?? {});
            },
          );
    return Scaffold(
      appBar: embedded
          ? null
          : AppBar(
              title: Text(audit ? 'Administrative activity' : 'Admin alerts'),
            ),
      body: embedded
          ? AdminPage(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  AdminHeading(
                    title: audit ? 'Activity history' : 'Admin alerts',
                    subtitle: audit
                        ? 'Recorded staff, order, payment and store changes.'
                        : 'Order, stock, support and rider notifications.',
                  ),
                  const SizedBox(height: 24),
                  Expanded(
                    child: Card(clipBehavior: Clip.antiAlias, child: content),
                  ),
                ],
              ),
            )
          : content,
    );
  }
}
