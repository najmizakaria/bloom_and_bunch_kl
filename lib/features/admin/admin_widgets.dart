import 'dart:async';
import '../../core/widgets/load_more_on_scroll.dart';
import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';
import 'admin_navigation_scope.dart';

void openAdminPage(BuildContext context, Widget page) {
  final workspace = AdminNavigationScope.maybeOf(context);
  if (workspace != null) {
    workspace.open(page);
  } else {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
  }
}

Future<bool> adminAction(
  BuildContext context,
  Future<void> Function() action, {
  String success = 'Saved successfully.',
}) async {
  try {
    await action();
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (error) {
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(AdminService.message(error))));
    }
    return false;
  }
}

class AdminLoad extends StatefulWidget {
  const AdminLoad({
    super.key,
    this.load,
    this.loadPage,
    this.recordsKey,
    required this.builder,
    this.poll = false,
  }) : assert(load != null || (loadPage != null && recordsKey != null));
  final Future<Map<String, dynamic>> Function()? load;
  final Future<Map<String, dynamic>> Function(String? cursor)? loadPage;
  final String? recordsKey;
  final Widget Function(Map<String, dynamic> data, VoidCallback refresh)
  builder;
  final bool poll;
  @override
  State<AdminLoad> createState() => _AdminLoadState();
}

class _AdminLoadState extends State<AdminLoad> {
  Map<String, dynamic>? _data;
  Object? _error;
  Object? _moreError;
  bool _busy = false;
  Timer? _timer;
  @override
  void initState() {
    super.initState();
    _refresh();
    if (widget.poll) {
      _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
    }
  }

  Future<void> _refresh() async {
    if (_busy) return;
    setState(() {
      _busy = true;
      _error = null;
      _moreError = null;
    });
    try {
      var value = widget.loadPage == null
          ? await widget.load!()
          : await _read(null);
      final target = (_data?[widget.recordsKey] as List?)?.length ?? 0;
      while (widget.loadPage != null &&
          (value[widget.recordsKey] as List).length < target &&
          value['next'] != null) {
        final next = await _read(value['next'] as String);
        value = {
          ...next,
          widget.recordsKey!: [
            ...value[widget.recordsKey] as List,
            ...next[widget.recordsKey] as List,
          ],
        };
      }
      if (mounted) setState(() => _data = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<Map<String, dynamic>> _read(String? cursor) async {
    final visited = <String?>{};
    while (true) {
      if (!visited.add(cursor)) {
        throw StateError('The list could not continue. Please reload.');
      }
      final value = await widget.loadPage!(cursor);
      if ((value[widget.recordsKey] as List? ?? []).isNotEmpty ||
          value['next'] == null) {
        return value;
      }
      cursor = value['next'] as String;
    }
  }

  Future<void> _loadMore() async {
    if (_busy || _data?['next'] == null) return;
    setState(() {
      _busy = true;
      _moreError = null;
    });
    try {
      final cursor = _data!['next'] as String;
      final next = await _read(cursor);
      if (next['next'] == cursor) {
        throw StateError('The list could not continue. Please reload.');
      }
      if (mounted) {
        setState(
          () => _data = {
            ...next,
            widget.recordsKey!: [
              ..._data![widget.recordsKey] as List,
              ...next[widget.recordsKey] as List,
            ],
          },
        );
      }
    } catch (error) {
      if (mounted) setState(() => _moreError = error);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_data == null && _busy) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null) {
      return Center(
        child: SingleChildScrollView(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  AdminService.message(_error!),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                FilledButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          ),
        ),
      );
    }
    return LoadMoreOnScroll(
      hasMore:
          widget.loadPage != null &&
          _data?['next'] != null &&
          _moreError == null,
      busy: _busy,
      onLoad: _loadMore,
      child: Column(
        children: [
          if (_busy) const LinearProgressIndicator(),
          Expanded(
            key: const ValueKey('records'),
            child: widget.builder(_data ?? {}, _refresh),
          ),
          if (_moreError != null)
            TextButton(
              onPressed: _loadMore,
              child: const Text('Retry loading more'),
            ),
          if (widget.loadPage != null)
            SafeArea(
              top: false,
              child: Center(
                child: IconButton(
                  tooltip: 'Reload',
                  onPressed: _busy ? null : _refresh,
                  icon: const Icon(Icons.refresh),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
