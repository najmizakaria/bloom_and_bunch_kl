import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'app_note.dart';

/// Live, bounded cursor pages. Filters belong to the supplied query.
class FirestorePage extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final Widget Function(
    BuildContext,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>,
  )?
  builder;

  /// Allows a page to scroll its pagination directly after its records.
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
  static const _size = 20;
  final List<DocumentSnapshot<Map<String, dynamic>>?> _starts = [null];
  late Stream<QuerySnapshot<Map<String, dynamic>>> _stream = _watch();
  Stream<QuerySnapshot<Map<String, dynamic>>> _watch() {
    var query = widget.query;
    if (_starts.last != null) query = query.startAfterDocument(_starts.last!);
    return query.limit(_size + 1).snapshots();
  }

  void _refresh() => setState(() {
    _starts.clear();
    _starts.add(null);
    _stream = _watch();
  });
  @override
  void didUpdateWidget(covariant FirestorePage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.query != widget.query) {
      _starts.clear();
      _starts.add(null);
      _stream = _watch();
    }
  }

  @override
  Widget build(
    BuildContext context,
  ) => StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
    stream: _stream,
    builder: (context, snapshot) {
      final docs =
          snapshot.data?.docs.take(_size).toList() ??
          <QueryDocumentSnapshot<Map<String, dynamic>>>[];
      final hasNext = (snapshot.data?.docs.length ?? 0) > _size;
      final loading = snapshot.connectionState == ConnectionState.waiting;
      Widget pageButton({
        required VoidCallback? onPressed,
        required Widget child,
      }) => widget.pageBuilder == null
          ? TextButton(onPressed: onPressed, child: child)
          : OutlinedButton(onPressed: onPressed, child: child);
      final pagination = Padding(
        padding: const EdgeInsets.symmetric(vertical: 16),
        child: Wrap(
          spacing: 12,
          runSpacing: 8,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            Text(
              '${docs.length} ${docs.length == 1 ? 'record' : 'records'} on this page',
            ),
            pageButton(
              onPressed: loading || _starts.length == 1
                  ? null
                  : () => setState(() {
                      _starts.removeLast();
                      _stream = _watch();
                    }),
              child: const Text('Previous'),
            ),
            Text('Page ${_starts.length}'),
            pageButton(
              onPressed: loading || !hasNext || snapshot.hasError
                  ? null
                  : () => setState(() {
                      _starts.add(docs.last);
                      _stream = _watch();
                    }),
              child: const Text('Next'),
            ),
            IconButton(
              tooltip: 'Refresh from first page',
              onPressed: _refresh,
              icon: const Icon(Icons.refresh),
            ),
          ],
        ),
      );
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
      } else if (loading || !snapshot.hasData) {
        content = const Center(child: CircularProgressIndicator());
      } else if (widget.pageBuilder != null) {
        content = widget.pageBuilder!(context, docs, pagination);
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
      return LayoutBuilder(
        builder: (context, constraints) => Column(
          children: [
            if (snapshot.data?.metadata.isFromCache == true)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surfaceContainerLow,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const AppNote(
                    'Showing saved information. Reconnecting…',
                    liveRegion: true,
                  ),
                ),
              ),
            Expanded(child: content),
            if (widget.pageBuilder == null ||
                snapshot.hasError ||
                loading ||
                !snapshot.hasData)
              ConstrainedBox(
                constraints: BoxConstraints(
                  maxHeight: constraints.maxHeight * 0.4,
                ),
                child: SingleChildScrollView(
                  child: SafeArea(top: false, child: pagination),
                ),
              ),
          ],
        ),
      );
    },
  );
}
