import 'dart:async';
import 'package:flutter/material.dart';

class PendingIconButton extends StatefulWidget {
  const PendingIconButton({
    super.key,
    required this.onPressed,
    required this.icon,
    this.tooltip,
  });
  final FutureOr<void> Function() onPressed;
  final Widget icon;
  final String? tooltip;
  @override
  State<PendingIconButton> createState() => _PendingIconButtonState();
}

class _PendingIconButtonState extends State<PendingIconButton> {
  bool _busy = false;
  Future<void> _run() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await Future<void>.sync(widget.onPressed);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this change. Please retry.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => IconButton(
    tooltip: widget.tooltip,
    onPressed: _busy ? null : _run,
    icon: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : widget.icon,
  );
}
