import 'dart:math';
import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import 'admin_widgets.dart';
import 'admin_layout.dart';
import '../../core/theme/app_colors.dart';

class AdminStaffScreen extends StatefulWidget {
  const AdminStaffScreen({super.key, this.peopleLoader});
  final Future<Map<String, dynamic>> Function(String? after)? peopleLoader;
  @override
  State<AdminStaffScreen> createState() => _AdminStaffScreenState();
}

class _AdminStaffScreenState extends State<AdminStaffScreen> {
  final List<String?> _pages = [null];
  int _revision = 0;
  bool _busy = false;
  Future<void> _edit(Map<String, dynamic> person, VoidCallback refresh) async {
    String selected = (person['roles'] as List).contains('florist')
        ? 'florist'
        : 'rider';
    bool suspended = person['suspended'] == true;
    final result = await showDialog<bool>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, setDialog) => AlertDialog(
          scrollable: true,
          title: Text('Manage ${person['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (person['managed'] == true)
                DropdownButtonFormField<String>(
                  initialValue: selected,
                  decoration: const InputDecoration(labelText: 'Staff role'),
                  items: const [
                    DropdownMenuItem(value: 'florist', child: Text('Florist')),
                    DropdownMenuItem(value: 'rider', child: Text('Rider')),
                  ],
                  onChanged: (v) => setDialog(() => selected = v!),
                ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Suspend account access'),
                value: suspended,
                onChanged: (v) => setDialog(() => suspended = v),
              ),
              const Text(
                'Role changes and suspensions are checked against active assignments. Administrator accounts are read-only here.',
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(c, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(c, true),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
    if (result != true || !mounted) return;
    setState(() => _busy = true);
    await adminAction(context, () async {
      await AdminService().call('adminUpdateStaff', {
        'uid': person['uid'],
        'suspended': suspended,
        if (person['managed'] == true &&
            !(person['roles'] as List).contains(selected))
          'role': selected,
      });
    });
    if (mounted) {
      setState(() => _busy = false);
      refresh();
    }
  }

  Widget _roles(Map<String, dynamic> person) => Wrap(
    spacing: 6,
    runSpacing: 6,
    children: [for (final role in person['roles'] as List) AdminBadge('$role')],
  );
  Widget _status(Map<String, dynamic> person) => AdminBadge(
    person['suspended'] == true ? 'Suspended' : 'Active',
    color: person['suspended'] == true
        ? AppColors.statusLowStock
        : AppColors.statusReady,
  );
  Widget _access(Map<String, dynamic> person, VoidCallback refresh) =>
      (person['roles'] as List).contains('admin')
      ? const Tooltip(
          message: 'Administrator access is protected',
          child: Padding(
            padding: EdgeInsets.all(12),
            child: Icon(Icons.shield_outlined),
          ),
        )
      : IconButton(
          tooltip: 'Manage staff access',
          onPressed: _busy ? null : () => _edit(person, refresh),
          icon: const Icon(Icons.manage_accounts_outlined),
        );
  String _phone(Map<String, dynamic> person) =>
      '${person['phone'] ?? ''}'.trim().isEmpty ? '—' : '${person['phone']}';
  Future<void> _create() async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(builder: (_) => const _CreateStaff()),
    );
    if (mounted) setState(() => _revision++);
  }

  @override
  Widget build(BuildContext context) => AdminLoad(
    key: ValueKey(_revision),
    load: () =>
        widget.peopleLoader?.call(_pages.last) ??
        AdminService().call('adminPeople', {
          if (_pages.last != null) 'after': _pages.last,
        }),
    builder: (data, refresh) {
      final people = (data['people'] as List? ?? [])
          .map((p) => Map<String, dynamic>.from(p as Map))
          .toList();
      return AdminPage(
        child: LayoutBuilder(
          builder: (context, box) => ListView(
            padding: const EdgeInsets.only(bottom: 24),
            children: [
              AdminHeading(
                title: 'Staff directory',
                subtitle: 'Manage staff roles and account access.',
                actions: [
                  TextButton.icon(
                    onPressed: refresh,
                    icon: const Icon(Icons.refresh),
                    label: const Text('Refresh'),
                  ),
                  FilledButton.icon(
                    onPressed: _busy ? null : _create,
                    icon: const Icon(Icons.person_add_alt),
                    label: const Text('Create staff'),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              if (people.isEmpty)
                const AdminEmpty(
                  'No staff accounts found.',
                  icon: Icons.people_outline,
                )
              else if (adminUsesTable(context, box.maxWidth))
                AdminTable(
                  columns: const [
                    DataColumn(label: Text('Name')),
                    DataColumn(label: Text('Email')),
                    DataColumn(label: Text('Phone')),
                    DataColumn(label: Text('Roles')),
                    DataColumn(label: Text('Access')),
                    DataColumn(label: Text('Actions')),
                  ],
                  rows: [
                    for (final p in people)
                      DataRow(
                        cells: [
                          DataCell(
                            SizedBox(
                              width: 150,
                              child: Text(
                                '${p['name']}',
                                maxLines: 3,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ),
                          DataCell(
                            SizedBox(
                              width: 220,
                              child: SelectableText(
                                '${p['email']}',
                                maxLines: 3,
                              ),
                            ),
                          ),
                          DataCell(Text(_phone(p))),
                          DataCell(SizedBox(width: 180, child: _roles(p))),
                          DataCell(_status(p)),
                          DataCell(_access(p, refresh)),
                        ],
                      ),
                  ],
                )
              else ...[
                for (final p in people)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      margin: EdgeInsets.zero,
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '${p['name']}',
                                    style: Theme.of(context)
                                        .textTheme
                                        .titleMedium
                                        ?.copyWith(fontWeight: FontWeight.w700),
                                  ),
                                ),
                                _access(p, refresh),
                              ],
                            ),
                            const SizedBox(height: 8),
                            SelectableText(
                              '${p['email']}',
                              style: const TextStyle(
                                color: AppColors.textMuted,
                              ),
                            ),
                            if (_phone(p) != '—') ...[
                              const SizedBox(height: 4),
                              Text(
                                _phone(p),
                                style: const TextStyle(
                                  color: AppColors.textMuted,
                                ),
                              ),
                            ],
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: [_status(p), _roles(p)],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
              AdminPagination(
                page: _pages.length,
                count: people.length,
                onPrevious: _pages.length > 1
                    ? () => setState(() {
                        _pages.removeLast();
                        _revision++;
                      })
                    : null,
                onNext: data['next'] != null
                    ? () => setState(() {
                        _pages.add(data['next'] as String);
                        _revision++;
                      })
                    : null,
              ),
            ],
          ),
        ),
      );
    },
  );
}

class _CreateStaff extends StatefulWidget {
  const _CreateStaff();
  @override
  State<_CreateStaff> createState() => _CreateStaffState();
}

class _CreateStaffState extends State<_CreateStaff> {
  final _form = GlobalKey<FormState>();
  final _name = TextEditingController(),
      _email = TextEditingController(),
      _phone = TextEditingController(),
      _password = TextEditingController();
  String _role = 'florist';
  bool _busy = false, _hide = true;
  final String _request =
      'staff_${DateTime.now().microsecondsSinceEpoch}_${Random.secure().nextInt(1 << 30)}';
  @override
  void dispose() {
    for (final c in [_name, _email, _phone, _password]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _busy) return;
    setState(() => _busy = true);
    try {
      await AdminService().call('adminCreateStaff', {
        'name': _name.text.trim(),
        'email': _email.text.trim(),
        'phone': _phone.text.trim(),
        'password': _password.text,
        'role': _role,
        'requestId': _request,
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
              'Staff account created. Ask the staff member to change their temporary password.',
            ),
          ),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(AdminService.message(e))));
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Create staff account')),
    body: SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 650),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Staff accounts are created securely by the server. Your admin session stays signed in. Share temporary credentials privately and ask the member to change their password.',
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _name,
                  enabled: !_busy,
                  maxLength: 120,
                  decoration: const InputDecoration(labelText: 'Full name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter a name' : null,
                ),
                TextFormField(
                  controller: _email,
                  enabled: !_busy,
                  maxLength: 254,
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                  validator: (v) =>
                      RegExp(r'^\S+@\S+\.\S+$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter a valid email',
                ),
                TextFormField(
                  controller: _phone,
                  enabled: !_busy,
                  maxLength: 30,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone number',
                    hintText: '+60123456789',
                  ),
                  validator: (v) =>
                      RegExp(r'^\+?\d{9,15}$').hasMatch(v?.trim() ?? '')
                      ? null
                      : 'Enter 9–15 digits, optionally starting with +',
                ),
                DropdownButtonFormField<String>(
                  initialValue: _role,
                  decoration: const InputDecoration(labelText: 'Role'),
                  items: const [
                    DropdownMenuItem(value: 'florist', child: Text('Florist')),
                    DropdownMenuItem(value: 'rider', child: Text('Rider')),
                  ],
                  onChanged: _busy ? null : (v) => setState(() => _role = v!),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  controller: _password,
                  enabled: !_busy,
                  obscureText: _hide,
                  maxLength: 128,
                  decoration: InputDecoration(
                    labelText: 'Temporary password',
                    suffixIcon: IconButton(
                      tooltip: 'Show or hide password',
                      onPressed: () => setState(() => _hide = !_hide),
                      icon: Icon(
                        _hide ? Icons.visibility : Icons.visibility_off,
                      ),
                    ),
                  ),
                  validator: (v) => (v?.length ?? 0) < 10
                      ? 'Use at least 10 characters'
                      : null,
                ),
                FilledButton(
                  onPressed: _busy ? null : _save,
                  child: Text(_busy ? 'Creating…' : 'Create staff account'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
