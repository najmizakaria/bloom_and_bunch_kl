import 'package:flutter/material.dart';

class RetryStreamBuilder<T> extends StatefulWidget {
  const RetryStreamBuilder({
    super.key,
    required this.watch,
    required this.builder,
  });
  final Stream<T> Function() watch;
  final Widget Function(BuildContext, AsyncSnapshot<T>) builder;
  @override
  State<RetryStreamBuilder<T>> createState() => _RetryStreamBuilderState<T>();
}

class _RetryStreamBuilderState<T> extends State<RetryStreamBuilder<T>> {
  late Stream<T> _stream = widget.watch();
  @override
  Widget build(BuildContext context) => StreamBuilder<T>(
    stream: _stream,
    builder: (context, snapshot) {
      if (snapshot.hasError) {
        return Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Could not load this information. Check your connection and access.',
              ),
              TextButton(
                onPressed: () => setState(() => _stream = widget.watch()),
                child: const Text('Retry'),
              ),
            ],
          ),
        );
      }
      return widget.builder(context, snapshot);
    },
  );
}
