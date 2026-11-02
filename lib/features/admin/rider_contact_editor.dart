import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import '../../core/utils/rider_phone.dart';

class RiderContactEditor extends StatefulWidget {
  const RiderContactEditor({
    super.key,
    required this.rider,
    required this.save,
  });
  final Map<String, dynamic> rider;
  final Future<void> Function(Map<String, dynamic>) save;
  @override
  State<RiderContactEditor> createState() => _RiderContactEditorState();
}

class _RiderContactEditorState extends State<RiderContactEditor> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(
    text: '${widget.rider['contactName'] ?? widget.rider['name'] ?? ''}',
  );
  late final _phone = TextEditingController(
    text: '${widget.rider['contactPhone'] ?? ''}',
  );
  bool _busy = false;
  String? _error;
  @override
  void dispose() {
    _name.dispose();
    _phone.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.save({
        'uid': widget.rider['uid'],
        'name': _name.text.trim(),
        'phone': RiderPhone.normalize(_phone.text.trim()),
        'contactVersion': widget.rider['contactVersion'],
      });
      if (mounted) Navigator.pop(context, true);
    } catch (error) {
      if (mounted) setState(() => _error = AdminService.message(error));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_busy,
    child: AlertDialog(
      scrollable: true,
      title: const Text('Rider delivery contact'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Customers can call this number during an assigned active delivery.',
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: _name,
              enabled: !_busy,
              maxLength: 160,
              decoration: const InputDecoration(labelText: 'Rider name'),
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter the rider name' : null,
            ),
            TextFormField(
              controller: _phone,
              enabled: !_busy,
              maxLength: 30,
              keyboardType: TextInputType.phone,
              decoration: const InputDecoration(
                labelText: 'Delivery phone number',
                hintText: 'e.g. 676766767',
              ),
              validator: (v) {
                try {
                  RiderPhone.normalize(v?.trim() ?? '');
                  return null;
                } on FormatException catch (e) {
                  return e.message;
                }
              },
            ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _busy ? null : () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _busy ? null : _save,
          child: Text(_busy ? 'Saving…' : 'Save contact'),
        ),
      ],
    ),
  );
}
