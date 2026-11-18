import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

class ProfileFieldDialog extends StatefulWidget {
  const ProfileFieldDialog.phone({
    super.key,
    required String currentPhone,
    required this.onSave,
  }) : _initialValue = currentPhone,
       _isName = false;

  const ProfileFieldDialog.name({
    super.key,
    required String currentName,
    required this.onSave,
  }) : _initialValue = currentName,
       _isName = true;

  final String _initialValue;
  final bool _isName;
  final Future<void> Function(String value) onSave;

  @override
  State<ProfileFieldDialog> createState() => _ProfileFieldDialogState();
}

class _ProfileFieldDialogState extends State<ProfileFieldDialog> {
  late final _controller = TextEditingController(text: widget._initialValue);
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
    final value = _controller.text.trim();
    if (widget._isName && value.isEmpty) {
      setState(() => _error = 'Enter your name.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await widget.onSave(value);
      if (!mounted) return;
      _closed = true;
      Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(
          () => _error = widget._isName
              ? 'Could not save your name. Please retry.'
              : 'Could not save your phone number. Please retry.',
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
      title: Text(widget._isName ? 'Edit name' : 'Phone Number'),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _controller,
              enabled: !_saving && !_closed,
              keyboardType: widget._isName
                  ? TextInputType.name
                  : TextInputType.phone,
              textCapitalization: widget._isName
                  ? TextCapitalization.words
                  : TextCapitalization.none,
              autofillHints: widget._isName
                  ? const [AutofillHints.name]
                  : const [AutofillHints.telephoneNumber],
              maxLength: widget._isName ? 120 : 30,
              decoration: widget._isName
                  ? const InputDecoration(labelText: 'Name')
                  : const InputDecoration(hintText: 'e.g. 012-3456789'),
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
