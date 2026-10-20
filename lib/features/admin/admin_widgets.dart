import 'dart:async';
import 'package:flutter/material.dart';
import '../../core/services/admin_service.dart';

void openAdminPage(BuildContext context, Widget page) =>
    Navigator.of(context).push(MaterialPageRoute<void>(builder: (_) => page));
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
    required this.load,
    required this.builder,
    this.poll = false,
  });
  final Future<Map<String, dynamic>> Function() load;
  final Widget Function(Map<String, dynamic> data, VoidCallback refresh)
  builder;
  final bool poll;
  @override
  State<AdminLoad> createState() => _AdminLoadState();
}

class _AdminLoadState extends State<AdminLoad> {
  Map<String, dynamic>? _data;
  Object? _error;
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
    });
    try {
      final value = await widget.load();
      if (mounted) setState(() => _data = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
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
    return Column(
      children: [
        if (_busy) const LinearProgressIndicator(),
        Expanded(child: widget.builder(_data ?? {}, _refresh)),
      ],
    );
  }
}
