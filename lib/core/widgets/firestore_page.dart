import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'load_more_on_scroll.dart';

/// Live records that expand as the user scrolls. Filters belong to the query.
class FirestorePage extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final Widget Function(
    BuildContext,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>,
  )?
  builder;
  final Widget Function(
    BuildContext,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>,
    Widget,
  )?
  pageBuilder;
  final String emptyMessage;
  const FirestorePage({
    super.key,
    required this.query,
    this.builder,
    this.pageBuilder,
    this.emptyMessage = 'No records found.',
  }) : assert(builder != null || pageBuilder != null);
  @override
  State<FirestorePage> createState() => _FirestorePageState();
}

class _FirestorePageState extends State<FirestorePage> {
  static const _batch = 20;
  int _limit = _batch;
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _watch();
  Stream<QuerySnapshot<Map<String, dynamic>>> _watch() =>
      widget.query.limit(_limit + 1).snapshots();
  void _refresh() => setState(() {
    _limit = _batch;
    _stream = _watch();
  });
  void _loadMore() => setState(() {
    _limit += _batch;
    _stream = _watch();
  });
  @override
  void didUpdateWidget(covariant FirestorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _limit = _batch;
      _stream = _watch();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    key: ValueKey(widget.query),
    stream: _stream,
    builder: (context, snapshot) {
      final docs =
          snapshot.data?.docs.take(_limit).toList() ??
          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final loading = snapshot.connectionState == ConnectionState.waiting;
      final hasAddButton =
          Scaffold.maybeOf(context)?.widget.floatingActionButton != null;
      Widget content;
      if (snapshot.hasError) {
        content = Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load records. Please try again.'),
                OutlinedButton(onPressed: _refresh, child: const Text('Retry')),
              ],
            ),
          ),
        );
      } else if (!snapshot.hasData) {
        content = const Center(child: CircularProgressIndicator());
      } else if (widget.pageBuilder != null) {
        content = widget.pageBuilder!(
          context,
          docs,
          SizedBox(height: hasAddButton ? 160 : 88),
        );
      } else if (docs.isEmpty) {
        content = Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Text(widget.emptyMessage, textAlign: TextAlign.center),
          ),
        );
      } else {
        content = widget.builder!(context, docs);
      }
      return LoadMoreOnScroll(
        hasMore:
            (snapshot.data?.docs.length ?? 0) > _limit && !snapshot.hasError,
        busy: loading,
        onLoad: _loadMore,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Column(
              children: [
                if (loading && snapshot.hasData)
                  const LinearProgressIndicator(),
                Expanded(child: content),
              ],
            ),
            Positioned(
              left: 16,
              bottom: hasAddButton ? 88 : 16,
              child: SafeArea(
                top: false,
                child: FloatingActionButton.small(
                  heroTag: null,
                  tooltip: 'Reload',
                  onPressed: loading ? null : _refresh,
                  child: const Icon(Icons.refresh),
                ),
              ),
            ),
          ],
        ),
      );
    },
  );
}
