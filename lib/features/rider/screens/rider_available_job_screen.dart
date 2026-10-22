import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../../core/services/order_service.dart';
import '../../../core/widgets/action_confirmation.dart';
import '../../../models/delivery_job_model.dart';
import '../widgets/delivery_job_card.dart';
import 'package:cloud_functions/cloud_functions.dart';

class RiderAvailableJobScreen extends StatefulWidget {
  final DeliveryJobModel job;
  final bool hasActiveDelivery;

  const RiderAvailableJobScreen({
    super.key,
    required this.job,
    this.hasActiveDelivery = false,
    this.contactReady = true,
    this.accept,
  });
  final Future<void> Function(String)? accept;
  final bool contactReady;

  @override
  State<RiderAvailableJobScreen> createState() =>
      _RiderAvailableJobScreenState();
}

class _RiderAvailableJobScreenState extends State<RiderAvailableJobScreen> {
  bool _accepting = false;

  Future<void> _accept() async {
    if (_accepting ||
        !widget.contactReady ||
        !widget.job.readyForPickup ||
        widget.hasActiveDelivery) {
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
      await (widget.accept?.call(widget.job.orderId) ??
          OrderService().transition(widget.job.orderId, 'accept'));
      if (!mounted) return;
      // My Delivery confirms acceptance. A snackbar here would follow the
      // closing preview into subsequent routes with an in-flight Hero.
      Navigator.pop(context, widget.job.orderId);
    } catch (error) {
      if (mounted) {
        if (error is FirebaseFunctionsException &&
            (error.code == 'not-found' &&
                    (error.message ?? '').contains('Order no longer exists') ||
                error.code == 'failed-precondition' &&
                    (error.message ?? '').contains(
                      'Another rider has accepted',
                    ))) {
          setState(() => _accepting = false);
          await showDialog<void>(
            context: context,
            builder: (dialog) => AlertDialog(
              title: const Text('Delivery unavailable'),
              content: const Text(
                'This delivery has already been taken or is no longer available. Choose another delivery.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(dialog),
                  child: const Text('Back to deliveries'),
                ),
              ],
            ),
          );
          if (mounted) Navigator.pop(context);
          return;
        }
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
        title: const Text('Delivery details'),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          DeliveryJobCard(job: widget.job, detailed: true),
          if (!widget.contactReady)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Ask the store administrator to approve your delivery name and Malaysian phone number. Refresh available deliveries after the contact is approved.',
              ),
            ),
          if (widget.hasActiveDelivery)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 12),
              child: Text(
                'Complete your current delivery and wait for customer confirmation before accepting another.',
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
                      'Recipient contact, delivery instructions and navigation become available after you accept.',
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
                  !widget.contactReady ||
                  !widget.job.readyForPickup ||
                  widget.hasActiveDelivery
              ? null
              : _accept,
          style: FilledButton.styleFrom(
            backgroundColor: AppColors.primary,
            padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 16),
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
                : !widget.contactReady
                ? 'Delivery contact needs review'
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
