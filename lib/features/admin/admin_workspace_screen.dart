import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

import '../../core/services/admin_service.dart';
import '../support/store_operations_screen.dart';
import '../../core/widgets/firestore_page.dart';
import '../../core/theme/app_colors.dart';
import 'admin_layout.dart';

class AdminWorkspaceScreen extends StatefulWidget {
  const AdminWorkspaceScreen({super.key, this.embedded = false});
  final bool embedded;

  @override
  State<AdminWorkspaceScreen> createState() => _AdminWorkspaceScreenState();
}

class _AdminWorkspaceScreenState extends State<AdminWorkspaceScreen> {
  final Set<String> _reviewing = {};
  bool _syncingJobs = false;

  Future<void> _syncDeliveryJobs() async {
    setState(() => _syncingJobs = true);
    try {
      final result = await AdminService().syncDeliveryJobs();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            '${result['eligible']} delivery jobs available; ${result['excluded']} excluded because their location is incomplete.',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AdminService.message(error))));
      }
    } finally {
      if (mounted) setState(() => _syncingJobs = false);
    }
  }

  Future<void> _review(String applicantId, bool approve) async {
    setState(() => _reviewing.add(applicantId));
    try {
      await AdminService().reviewRiderApplication(
        applicantId: applicantId,
        approve: approve,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            approve ? 'Rider application approved.' : 'Application rejected.',
          ),
          backgroundColor: approve
              ? AppColors.primaryDark
              : AppColors.primaryDark,
        ),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(AdminService.message(error)),
          backgroundColor: AppColors.primaryDark,
        ),
      );
    } finally {
      if (mounted) setState(() => _reviewing.remove(applicantId));
    }
  }

  Future<void> _confirmReview(
    String applicantId,
    String applicantName,
    bool approve,
  ) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(approve ? 'Approve rider?' : 'Reject application?'),
        content: Text(
          approve
              ? '$applicantName will receive rider access immediately.'
              : '$applicantName will remain a customer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: approve
                  ? AppColors.primaryDark
                  : AppColors.primaryDark,
            ),
            onPressed: () => Navigator.pop(dialogContext, true),
            child: Text(approve ? 'Approve' : 'Reject'),
          ),
        ],
      ),
    );
    if (confirmed == true) await _review(applicantId, approve);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.softBlushStart,
      appBar: widget.embedded
          ? null
          : AppBar(
              leading: const PageBackButton(),
              centerTitle: false,
              title: const Text('Admin workspace'),
              actions: [
                IconButton(
                  tooltip: 'Store support',
                  icon: const Icon(Icons.support_agent),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const StoreOperationsScreen(),
                    ),
                  ),
                ),

                IconButton(
                  tooltip: 'Sync available delivery jobs',
                  icon: _syncingJobs
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.primary,
                          ),
                        )
                      : const Icon(Icons.sync),
                  onPressed: _syncingJobs ? null : _syncDeliveryJobs,
                ),
              ],
            ),
      body: AdminPage(
        child: FirestorePage(
          query: FirebaseFirestore.instance
              .collection('rider_applications')
              .where('status', isEqualTo: 'pending')
              .orderBy('submittedAt'),
          emptyMessage: 'No pending rider applications.',
          pageBuilder: (context, applications, pagination) {
            return ListView.builder(
              padding: const EdgeInsets.only(bottom: 24),
              itemCount: (applications.isEmpty ? 1 : applications.length) + 2,
              itemBuilder: (context, index) {
                if (index == 0) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 24),
                    child: AdminHeading(
                      title: 'Rider applications',
                      subtitle:
                          'Review pending applications and manage available delivery jobs.',
                      actions: [
                        OutlinedButton.icon(
                          onPressed: _syncingJobs ? null : _syncDeliveryJobs,
                          icon: const Icon(Icons.sync),
                          label: Text(
                            _syncingJobs ? 'Syncing…' : 'Sync delivery jobs',
                          ),
                        ),
                      ],
                    ),
                  );
                }
                if (index ==
                    (applications.isEmpty ? 1 : applications.length) + 1) {
                  return pagination;
                }
                if (applications.isEmpty) {
                  return const AdminEmpty(
                    'No pending rider applications.',
                    icon: Icons.person_add_alt,
                  );
                }
                final document = applications[index - 1];
                final data = document.data();
                final name = (data['name'] ?? 'Applicant').toString();
                final busy = _reviewing.contains(document.id);

                return Card(
                  margin: const EdgeInsets.only(bottom: 12),
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(name, style: const AppTypography.sectionTitle()),
                        const SizedBox(height: 8),
                        _Detail(
                          icon: Icons.phone_outlined,
                          text: data['phone'],
                        ),
                        _Detail(
                          icon: Icons.two_wheeler_outlined,
                          text: data['vehicleType'],
                        ),
                        if ((data['reason'] ?? '').toString().trim().isNotEmpty)
                          _Detail(
                            icon: Icons.notes_outlined,
                            text: data['reason'],
                          ),
                        const SizedBox(height: 12),
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton(
                                onPressed: busy
                                    ? null
                                    : () => _confirmReview(
                                        document.id,
                                        name,
                                        false,
                                      ),
                                child: const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                style: FilledButton.styleFrom(
                                  backgroundColor: AppColors.primaryDark,
                                ),
                                onPressed: busy
                                    ? null
                                    : () => _confirmReview(
                                        document.id,
                                        name,
                                        true,
                                      ),
                                child: busy
                                    ? const SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                    : const Text('Approve'),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        ),
      ),
    );
  }
}

class _Detail extends StatelessWidget {
  const _Detail({required this.icon, required this.text});

  final IconData icon;
  final Object? text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: AppColors.textMuted),
          const SizedBox(width: 8),
          Expanded(child: Text((text ?? 'Not provided').toString())),
        ],
      ),
    );
  }
}
