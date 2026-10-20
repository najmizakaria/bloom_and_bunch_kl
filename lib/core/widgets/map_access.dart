import 'package:flutter/material.dart';
import '../services/web_maps_stub.dart'
    if (dart.library.js_interop) '../services/web_maps_web.dart';

/// An unavailable browser Maps API must not break the rest of the application.
class MapAccess extends StatefulWidget {
  const MapAccess({super.key, required this.child});
  final Widget child;
  @override
  State<MapAccess> createState() => _MapAccessState();
}

class _MapAccessState extends State<MapAccess> {
  late Future<void> _ready = ensureMaps();
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _ready,
    builder: (context, s) {
      if (s.hasError) {
        return Center(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Map unavailable. Check your connection and web Maps configuration.',
                ),
                TextButton(
                  onPressed: () => setState(() => _ready = ensureMaps()),
                  child: const Text('Retry map'),
                ),
              ],
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
