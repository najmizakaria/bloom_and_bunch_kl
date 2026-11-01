import 'package:flutter/material.dart';

class LoadMoreOnScroll extends StatefulWidget {
  const LoadMoreOnScroll({
    super.key,
    required this.hasMore,
    required this.busy,
    required this.onLoad,
    required this.child,
  });
  final bool hasMore, busy;
  final VoidCallback onLoad;
  final Widget child;
  @override
  State<LoadMoreOnScroll> createState() => _LoadMoreOnScrollState();
}

class _LoadMoreOnScrollState extends State<LoadMoreOnScroll> {
  bool _scheduled = false;
  ScrollMetrics? _metrics;
  @override
  void didUpdateWidget(covariant LoadMoreOnScroll oldWidget) {
    super.didUpdateWidget(oldWidget);
    _schedule();
  }

  void _schedule() {
    if (_scheduled ||
        !widget.hasMore ||
        widget.busy ||
        _metrics == null ||
        _metrics!.extentAfter >= 200) {
      return;
    }
    _scheduled = true;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      if (mounted &&
          widget.hasMore &&
          !widget.busy &&
          _metrics != null &&
          _metrics!.extentAfter < 200) {
        widget.onLoad();
      }
    });
  }

  bool _onNotification(Notification notification) {
    final metrics = switch (notification) {
      ScrollNotification n => n.metrics,
      ScrollMetricsNotification n => n.metrics,
      _ => null,
    };
    if (metrics?.axis == Axis.vertical) {
      _metrics = metrics;
      _schedule();
    }
    return false;
  }

  @override
  Widget build(BuildContext context) => NotificationListener<Notification>(
    onNotification: _onNotification,
    child: widget.child,
  );
}
