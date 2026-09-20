import 'package:flutter/material.dart';

class ActionFeedback {
  static Future<void> run(
    BuildContext context,
    Future<void> Function() action,
  ) async {
    try {
      await action();
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not save this change. Please retry.'),
          ),
        );
      }
    }
  }
}
