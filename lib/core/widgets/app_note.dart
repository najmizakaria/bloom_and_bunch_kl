import 'package:flutter/material.dart';
import '../theme/app_colors.dart';

/// Quiet supporting information, with a hanging asterisk for wrapped lines.
class AppNote extends StatelessWidget {
  const AppNote(this.message, {super.key, this.liveRegion = false});

  final String message;
  final bool liveRegion;

  @override
  Widget build(BuildContext context) {
    final style = Theme.of(context).textTheme.bodySmall?.copyWith(
      fontSize: 12,
      height: 1.5,
      fontWeight: FontWeight.w400,
      color: AppColors.textMuted,
    );
    return Semantics(
      label: message,
      liveRegion: liveRegion,
      child: ExcludeSemantics(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('*', style: style),
              const SizedBox(width: 6),
              Expanded(child: Text(message, style: style)),
            ],
          ),
        ),
      ),
    );
  }
}
