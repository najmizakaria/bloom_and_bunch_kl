import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../../core/services/order_service.dart';
import '../../../core/widgets/action_confirmation.dart';
import '../../../models/delivery_job_model.dart';

class RiderAvailableJobScreen extends StatefulWidget {
  final DeliveryJobModel job;
  final bool hasActiveDelivery;

  const RiderAvailableJobScreen({
    super.key,
    required this.job,
    this.hasActiveDelivery = false,
  });

  @override
  State<RiderAvailableJobScreen> createState() =>
      _RiderAvailableJobScreenState();
}

class _RiderAvailableJobScreenState extends State<RiderAvailableJobScreen> {
  bool _accepting = false;

  Future<void> _accept() async {
    if (_accepting || !widget.job.readyForPickup || widget.hasActiveDelivery) {
      return;
    }
    if (!await confirmAction(
          context,
          title: 'Accept delivery?',
          message:
              'You will be responsible for delivering this order. Recipient details unlock after acceptance.',
          action: 'Accept delivery',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _accepting = true);
    try {
      await OrderService().transition(widget.job.orderId, 'accept');
      if (!mounted) return;
      // My Delivery confirms acceptance. A snackbar here would follow the
      // closing preview into subsequent routes with an in-flight Hero.
      Navigator.pop(context, widget.job.orderId);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(OrderService.message(error))));
      }
    } finally {
      if (mounted) setState(() => _accepting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Available Delivery'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(
            Icons.local_shipping_outlined,
            size: 72,
            color: AppColors.primary,
          ),
          const SizedBox(height: 20),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.info_outline),
                  title: Text(
                    widget.job.readyForPickup
                        ? 'Ready for pickup'
                        : 'Waiting for preparation',
                  ),
                  subtitle: widget.hasActiveDelivery
                      ? const Text(
                          'Complete your current delivery and wait for customer confirmation before accepting another.',
                        )
                      : null,
                ),
                ListTile(
                  leading: const Icon(Icons.location_city_outlined),
                  title: const Text('Delivery area'),
                  subtitle: Text(widget.job.deliveryArea),
                ),
                ListTile(
                  leading: const Icon(Icons.schedule_outlined),
                  title: const Text('Delivery timing'),
                  subtitle: Text(
                    widget.job.deliveryTimeSlot.isEmpty
                        ? 'As soon as possible'
                        : widget.job.deliveryTimeSlot,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          const Card(
            color: AppColors.secondarySurface,
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                  SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'The exact address, recipient contact, delivery note and navigation become available after you accept.',
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed:
              _accepting ||
                  !widget.job.readyForPickup ||
                  widget.hasActiveDelivery
              ? null
              : _accept,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          icon: _accepting
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                )
              : const Icon(Icons.check_circle_outline),
          label: Text(
            _accepting
                ? 'Accepting…'
                : widget.hasActiveDelivery
                ? 'Complete current delivery first'
                : !widget.job.readyForPickup
                ? 'Waiting for preparation'
                : 'Accept Delivery',
          ),
        ),
      ),
    );
  }
}
