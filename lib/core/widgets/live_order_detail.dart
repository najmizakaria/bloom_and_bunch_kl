import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import '../../models/order_model.dart';

typedef OrderWatch = Stream<OrderModel?> Function(String orderId);

class LiveOrderDetail extends StatefulWidget {
  const LiveOrderDetail({
    super.key,
    required this.orderId,
    required this.builder,
    this.watch,
  });
  final String orderId;
  final Widget Function(OrderModel) builder;
  final OrderWatch? watch;
  @override
  State<LiveOrderDetail> createState() => _LiveOrderDetailState();
}

class _LiveOrderDetailState extends State<LiveOrderDetail> {
  late Stream<OrderModel?> _stream = _watch();
  Stream<OrderModel?> _watch() =>
      widget.watch?.call(widget.orderId) ??
      FirebaseFirestore.instance
          .doc('orders/${widget.orderId}')
          .snapshots()
          .map(
            (doc) =>
                doc.exists ? OrderModel.fromMap(doc.data()!, doc.id) : null,
          );
  @override
  void didUpdateWidget(covariant LiveOrderDetail oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.orderId != widget.orderId ||
        oldWidget.watch != widget.watch) {
      _stream = _watch();
    }
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<OrderModel?>(
    stream: _stream,
    builder: (context, snapshot) {
      if (!snapshot.hasError &&
          snapshot.connectionState != ConnectionState.waiting &&
          snapshot.data != null) {
        return widget.builder(snapshot.data!);
      }
      return Scaffold(
        appBar: AppBar(
          leading: const PageBackButton(),
          centerTitle: false,
          title: const Text('Order details'),
        ),
        body: Center(
          child:
              snapshot.connectionState == ConnectionState.waiting &&
                  !snapshot.hasError
              ? const CircularProgressIndicator()
              : Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        snapshot.hasError
                            ? 'Order could not be loaded. Check your connection and access.'
                            : 'This order is no longer available.',
                        textAlign: TextAlign.center,
                      ),
                      TextButton(
                        onPressed: () => setState(() => _stream = _watch()),
                        child: const Text('Retry'),
                      ),
                    ],
                  ),
                ),
        ),
      );
    },
  );
}
