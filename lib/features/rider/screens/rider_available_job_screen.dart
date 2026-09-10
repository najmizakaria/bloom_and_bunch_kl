import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:flutter/material.dart';

import '../../../core/services/order_service.dart';
import '../../../models/delivery_job_model.dart';

class RiderAvailableJobScreen extends StatefulWidget {
  final DeliveryJobModel job;

  const RiderAvailableJobScreen({super.key, required this.job});

  @override
  State<RiderAvailableJobScreen> createState() =>
      _RiderAvailableJobScreenState();
}

class _RiderAvailableJobScreenState extends State<RiderAvailableJobScreen> {
  bool _accepting = false;

  Future<void> _accept() async {
    setState(() => _accepting = true);
    try {
      await OrderService().transition(widget.job.orderId, 'accept');
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Delivery accepted. Full details unlocked.'),
        ),
      );
      Navigator.pop(context);
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
          onPressed: _accepting ? null : _accept,
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
          label: Text(_accepting ? 'Accepting…' : 'Accept Delivery'),
        ),
      ),
    );
  }
}
