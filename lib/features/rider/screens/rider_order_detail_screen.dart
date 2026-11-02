import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/widgets/live_order_detail.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/material.dart';
import '../../../core/services/order_service.dart';
import '../../support/order_support.dart';
import '../widgets/rider_delivery_details.dart';
import '../../../models/order_model.dart';

class RiderOrderDetailScreen extends StatelessWidget {
  const RiderOrderDetailScreen({super.key, required this.order, this.watch});
  final OrderModel order;
  final OrderWatch? watch;
  @override
  Widget build(BuildContext context) => LiveOrderDetail(
    orderId: order.orderId,
    watch: watch,
    builder: (latest) => _RiderOrderDetailContent(order: latest),
  );
}

class _RiderOrderDetailContent extends StatefulWidget {
  final OrderModel order;

  const _RiderOrderDetailContent({required this.order});

  @override
  State<_RiderOrderDetailContent> createState() =>
      _RiderOrderDetailContentState();
}

class _RiderOrderDetailContentState extends State<_RiderOrderDetailContent> {
  bool _isLoading = false;

  Future<void> _markAsDelivered() async {
    if (_isLoading) return;
    final collecting = widget.order.orderStatus == 'Rider assigned';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(collecting ? 'Confirm collection?' : 'Confirm delivered?'),
        content: Text(
          collecting
              ? 'Confirm that you have collected the packed order from the florist. The customer will see that delivery has started.'
              : 'Confirm the bouquet has been handed to the recipient or left according to their instructions. The order will wait for customer receipt confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: Text(
              collecting ? 'Confirm collection' : 'Confirm delivered',
            ),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await OrderService().transition(
        widget.order.orderId,
        collecting ? 'collect' : 'deliver',
      );
      if (mounted && !collecting) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(OrderService.message(e))));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final collecting = widget.order.orderStatus == 'Rider assigned';
    final active = collecting || widget.order.orderStatus == 'Out for Delivery';
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('My delivery'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        actions: [
          IconButton(
            tooltip: 'Report delivery problem',
            onPressed: () => reportIssue(context, widget.order.orderId),
            icon: const Icon(Icons.report_problem_outlined),
          ),
        ],
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (collecting)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Rider assigned — collect the packed order from the florist, then confirm collection. Delivery has not started yet.',
                ),
              ),
            if (widget.order.hasOpenIssue)
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'An open delivery issue pauses completion. Contact the store.',
                ),
              ),
            if (widget.order.orderStatus == 'Awaiting Customer Confirmation')
              const Padding(
                padding: EdgeInsets.only(bottom: 16),
                child: Text(
                  'Delivery recorded. Waiting for customer receipt confirmation.',
                ),
              ),
            RiderDeliveryDetails(order: widget.order),
            const SizedBox(height: 12),
            OutlinedButton.icon(
              onPressed: () => reportIssue(context, widget.order.orderId),
              icon: const Icon(Icons.report_problem_outlined),
              label: const Text('Report a delivery problem'),
            ),
          ],
        ),
      ),
      bottomNavigationBar: active
          ? SafeArea(
              minimum: const EdgeInsets.all(16),
              child: FilledButton(
                onPressed: _isLoading || widget.order.hasOpenIssue
                    ? null
                    : _markAsDelivered,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
                ),
                child: _isLoading
                    ? const SizedBox.square(
                        dimension: 22,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : Text(
                        collecting ? 'Confirm collection' : 'Mark as Delivered',
                        style: const AppTypography.button(color: Colors.white),
                      ),
              ),
            )
          : null,
    );
  }
}
