import 'dart:async';
import 'package:flutter/material.dart';
import '../services/web_maps_stub.dart'
    if (dart.library.js_interop) '../services/web_maps_web.dart';

/// An unavailable browser Maps API must not break the rest of the application.
class MapAccess extends StatefulWidget {
  const MapAccess({
    super.key,
    required this.child,
    this.load,
    this.failures,
    this.errorBuilder,
  });
  final Widget child;
  final Future<void> Function()? load;
  final Stream<void>? failures;
  final Widget Function(BuildContext, VoidCallback retry)? errorBuilder;
  @override
  State<MapAccess> createState() => _MapAccessState();
}

class _MapAccessState extends State<MapAccess> {
  late Future<void> _ready;
  StreamSubscription<void>? _failures;
  bool _failed = false;
  @override
  void initState() {
    super.initState();
    _failures = (widget.failures ?? mapFailures()).listen((_) {
      if (mounted) setState(() => _failed = true);
    });
    _ready = (widget.load ?? ensureMaps)();
  }

  void _retry() => setState(() {
    _failed = false;
    _ready = (widget.load ?? ensureMaps)();
  });
  @override
  void dispose() {
    _failures?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, s) {
      if (s.hasError || _failed) {
        if (widget.errorBuilder != null) {
          return widget.errorBuilder!(context, _retry);
        }
        return Center(
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text(
                    'The map could not load. Please retry or use the written address.',
                    textAlign: TextAlign.center,
                  ),
                  TextButton(onPressed: _retry, child: const Text('Retry map')),
                ],
              ),
            ),
          ),
        );
      }
      if (s.connectionState != ConnectionState.done) {
        return const Center(child: CircularProgressIndicator());
      }
      return widget.child;
    },
  );
}
