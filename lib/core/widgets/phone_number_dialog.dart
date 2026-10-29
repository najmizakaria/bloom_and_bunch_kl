import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class PhoneNumberDialog extends StatefulWidget {
  const PhoneNumberDialog({
    super.key,
    required this.currentPhone,
    required this.onSave,
  });
  final String currentPhone;
  final Future<void> Function(String phone) onSave;

  @override
  State<PhoneNumberDialog> createState() => _PhoneNumberDialogState();
}

class _PhoneNumberDialogState extends State<PhoneNumberDialog> {
  late final _controller = TextEditingController(text: widget.currentPhone);
  bool _saving = false, _closed = false;
  String? _error;

  @override
  void dispose() {
    // The route owns this state until its exit animation has finished.
    _controller.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || _closed) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(_controller.text.trim());
      if (!mounted) return;
      _closed = true;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = 'Could not save your phone number. Please retry.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: AlertDialog(
      title: const Text('Phone Number'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              enabled: !_saving && !_closed,
              keyboardType: TextInputType.phone,
              autofillHints: const [AutofillHints.telephoneNumber],
              maxLength: 30,
              decoration: const InputDecoration(hintText: 'e.g. 012-3456789'),
            ),
            if (_error != null)
              Semantics(
                liveRegion: true,
                child: Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: _saving || _closed
              ? null
              : () => Navigator.of(context).pop(false),
          child: const Text('Cancel'),
        ),
        FilledButton(
          style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
          onPressed: _saving || _closed ? null : _save,
          child: Text(_saving ? 'Saving…' : 'Save'),
        ),
      ],
    ),
  );
}
