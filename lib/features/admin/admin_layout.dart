import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../core/theme/app_colors.dart';

/// Shared bounds and spacing for the admin workspace, including embedded tabs.
class AdminPage extends StatelessWidget {
  const AdminPage({super.key, required this.child});
  final Widget child;
  @override
  Widget build(BuildContext context) => Align(
    alignment: Alignment.topCenter,
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 1488),
      child: Padding(
        padding: EdgeInsets.all(
          MediaQuery.sizeOf(context).width < 600 ? 16 : 24,
        ),
        child: SizedBox(width: double.infinity, child: child),
      ),
    ),
  );
}

class AdminHeading extends StatelessWidget {
  const AdminHeading({
    super.key,
    required this.title,
    this.subtitle,
    this.actions = const [],
  });
  final String title;
  final String? subtitle;
  final List<Widget> actions;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final heading = Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 6),
            Text(subtitle!, style: const TextStyle(color: AppColors.textMuted)),
          ],
        ],
      );
      final buttons = Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: actions,
      );
      if (box.maxWidth < 700 ||
          MediaQuery.textScalerOf(context).scale(1) > 1.4) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            heading,
            if (actions.isNotEmpty) ...[const SizedBox(height: 16), buttons],
          ],
        );
      }
      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: heading),
          if (actions.isNotEmpty) ...[const SizedBox(width: 24), buttons],
        ],
      );
    },
  );
}

class AdminBadge extends StatelessWidget {
  const AdminBadge(this.label, {super.key, this.color = AppColors.primary});
  final String label;
  final Color color;
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.09),
      borderRadius: BorderRadius.circular(8),
    ),
    child: Text(
      label,
      style: Theme.of(context).textTheme.labelMedium?.copyWith(
        color: color,
        fontWeight: FontWeight.w600,
      ),
    ),
  );
}

class AdminTable extends StatelessWidget {
  const AdminTable({super.key, required this.columns, required this.rows});
  final List<DataColumn> columns;
  final List<DataRow> rows;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    clipBehavior: Clip.antiAlias,
    child: LayoutBuilder(
      builder: (context, box) => SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: ConstrainedBox(
          constraints: BoxConstraints(minWidth: box.maxWidth),
          child: DataTable(
            headingRowColor: const WidgetStatePropertyAll(
              AppColors.softBlushStart,
            ),
            headingTextStyle: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontWeight: FontWeight.w700,
              color: AppColors.textMuted,
            ),
            dataRowMinHeight: MediaQuery.textScalerOf(context).scale(1) > 1.1
                ? 112
                : 80,
            dataRowMaxHeight: MediaQuery.textScalerOf(context).scale(1) > 1.1
                ? 112
                : 80,
            horizontalMargin: 16,
            columnSpacing: 24,
            dividerThickness: 1,
            columns: columns,
            rows: rows,
          ),
        ),
      ),
    ),
  );
}

bool adminUsesTable(BuildContext context, double width) =>
    width >= 1000 && MediaQuery.textScalerOf(context).scale(1) <= 1.4;

class AdminPagination extends StatelessWidget {
  const AdminPagination({
    super.key,
    required this.page,
    required this.count,
    required this.onPrevious,
    required this.onNext,
    this.onRefresh,
  });
  final int page, count;
  final VoidCallback? onPrevious, onNext, onRefresh;
  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 16, bottom: 8),
    child: Wrap(
      spacing: 12,
      runSpacing: 8,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(
          '$count ${count == 1 ? 'record' : 'records'} on this page',
          style: const TextStyle(color: AppColors.textMuted),
        ),
        OutlinedButton(onPressed: onPrevious, child: const Text('Previous')),
        Text('Page $page'),
        OutlinedButton(onPressed: onNext, child: const Text('Next')),
        if (onRefresh != null)
          IconButton(
            tooltip: 'Refresh from first page',
            onPressed: onRefresh,
            icon: const Icon(Icons.refresh),
          ),
      ],
    ),
  );
}

class AdminEmpty extends StatelessWidget {
  const AdminEmpty(this.message, {super.key, this.icon = Icons.inbox_outlined});
  final String message;
  final IconData icon;
  @override
  Widget build(BuildContext context) => Card(
    margin: EdgeInsets.zero,
    child: Padding(
      padding: const EdgeInsets.all(32),
      child: Column(
        children: [
          Icon(icon, size: 32, color: AppColors.textMuted),
          const SizedBox(height: 12),
          Text(message, textAlign: TextAlign.center),
        ],
      ),
    ),
  );
}

class AdminIdentifier extends StatelessWidget {
  const AdminIdentifier(this.id, {super.key});
  final String id;
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Flexible(
        child: Tooltip(
          message: id,
          child: Text(
            id.length > 12 ? '#${id.substring(0, 8)}…' : '#$id',
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ),
      IconButton(
        tooltip: 'Copy full order ID',
        icon: const Icon(Icons.copy_outlined, size: 18),
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: id));
          if (context.mounted) {
            ScaffoldMessenger.of(
              context,
            ).showSnackBar(const SnackBar(content: Text('Order ID copied.')));
          }
        },
      ),
    ],
  );
}

class AdminMetric {
  const AdminMetric(this.title, this.value, this.onTap);
  final String title, value;
  final VoidCallback onTap;
}

class AdminMetricGrid extends StatelessWidget {
  const AdminMetricGrid({super.key, required this.metrics});
  final List<AdminMetric> metrics;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final columns = box.maxWidth >= 1200
          ? 5
          : box.maxWidth >= 760
          ? 3
          : box.maxWidth >= 520
          ? 2
          : 1;
      final width = (box.maxWidth - 16 * (columns - 1)) / columns;
      final titleStyle = Theme.of(context).textTheme.bodyLarge!;
      final valueStyle = Theme.of(
        context,
      ).textTheme.headlineSmall!.copyWith(fontWeight: FontWeight.w700);
      double titleHeight = 0, valueHeight = 0;
      for (final metric in metrics) {
        final title = TextPainter(
          text: TextSpan(text: metric.title, style: titleStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, width - 72));
        final value = TextPainter(
          text: TextSpan(text: metric.value, style: valueStyle),
          textDirection: Directionality.of(context),
          textScaler: MediaQuery.textScalerOf(context),
        )..layout(maxWidth: math.max(1, width - 32));
        titleHeight = math.max(titleHeight, title.height);
        valueHeight = math.max(valueHeight, value.height);
        title.dispose();
        value.dispose();
      }
      final height = math.max(144.0, titleHeight + valueHeight + 52);
      return Wrap(
        spacing: 16,
        runSpacing: 16,
        children: [
          for (final metric in metrics)
            SizedBox(
              width: width,
              height: height,
              child: Card(
                key: ValueKey('metric-${metric.title}'),
                margin: EdgeInsets.zero,
                clipBehavior: Clip.antiAlias,
                child: InkWell(
                  onTap: metric.onTap,
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Text(metric.title, style: titleStyle),
                            ),
                            const SizedBox(width: 8),
                            const Icon(Icons.chevron_right, size: 24),
                          ],
                        ),
                        const Spacer(),
                        Text(metric.value, style: valueStyle),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      );
    },
  );
}
