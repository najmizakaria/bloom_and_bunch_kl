import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';

/// Live, bounded cursor pages. Filters belong to the supplied query.
class FirestorePage extends StatefulWidget {
  final Query<Map<String, dynamic>> query;
  final Widget Function(
    BuildContext,
    List<QueryDocumentSnapshot<Map<String, dynamic>>>,
  )
  builder;
  final String emptyMessage;
  const FirestorePage({
    super.key,
    required this.query,
    required this.builder,
    this.emptyMessage = 'No records found.',
  });
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
  Widget build(BuildContext context) =>
      StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: _stream,
        builder: (context, snapshot) {
          final docs =
              snapshot.data?.docs.take(_size).toList() ??
              <QueryDocumentSnapshot<Map<String, dynamic>>>[];
          final hasNext = (snapshot.data?.docs.length ?? 0) > _size;
          final loading = snapshot.connectionState == ConnectionState.waiting;
          return LayoutBuilder(
            builder: (context, constraints) {
              return Column(
                children: [
                  Expanded(
                    child: snapshot.hasError
                        ? Center(
                            child: SingleChildScrollView(
                              padding: const EdgeInsets.all(20),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  const Text(
                                    'Could not load records. Please try again.',
                                  ),
                                  OutlinedButton(
                                    onPressed: _refresh,
                                    child: const Text('Retry'),
                                  ),
                                ],
                              ),
                            ),
                          )
                        : loading || !snapshot.hasData
                        ? const Center(child: CircularProgressIndicator())
                        : docs.isEmpty
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(20),
                              child: Text(
                                widget.emptyMessage,
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : widget.builder(context, docs),
                  ),
                  if (snapshot.data?.metadata.isFromCache == true)
                    const Text('Showing saved information. Reconnecting…'),
                  ConstrainedBox(
                    constraints: BoxConstraints(
                      maxHeight: constraints.maxHeight * 0.4,
                    ),
                    child: SingleChildScrollView(
                      child: SafeArea(
                        top: false,
                        child: Padding(
                          padding: const EdgeInsets.all(8),
                          child: Wrap(
                            alignment: WrapAlignment.center,
                            spacing: 12,
                            crossAxisAlignment: WrapCrossAlignment.center,
                            children: [
                              TextButton(
                                onPressed: loading || _starts.length == 1
                                    ? null
                                    : () => setState(() {
                                        _starts.removeLast();
                                        _stream = _watch();
                                      }),
                                child: const Text('Previous'),
                              ),
                              Text('Page ${_starts.length}'),
                              TextButton(
                                onPressed:
                                    loading || !hasNext || snapshot.hasError
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
                        ),
                      ),
                    ),
                  ),
                ],
              );
            },
          );
        },
      );
}
