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

  bool get _canAccept =>
      !_accepting &&
      widget.contactReady &&
      widget.job.readyForPickup &&
      !widget.hasActiveDelivery;

  Future<void> _confirmAcceptance() async {
    if (await confirmAction(
          context,
          title: 'Accept delivery?',
          message:
              'You will be responsible for delivering this order. Recipient details unlock after acceptance.',
          action: 'Accept delivery',
        ) &&
        mounted) {
      await _accept();
    }
  }

  Future<void> _accept() async {
    if (!_canAccept) return;
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
                'Ask the store administrator to add your delivery name and phone number, then refresh available deliveries.',
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
                      'Recipient contact, delivery instructions and exact navigation become available after you accept.',
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
        child: _canAccept
            ? Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _SwipeToAccept(onAccept: _accept),
                  TextButton(
                    onPressed: _confirmAcceptance,
                    child: const Text('Accept with confirmation'),
                  ),
                ],
              )
            : FilledButton.icon(
                onPressed: null,
                style: FilledButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(
                    vertical: 16,
                    horizontal: 16,
                  ),
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
                      ? 'Delivery contact missing'
                      : widget.hasActiveDelivery
                      ? 'Complete current delivery first'
                      : 'Waiting for preparation',
                ),
              ),
      ),
    );
  }
}

class _SwipeToAccept extends StatefulWidget {
  const _SwipeToAccept({required this.onAccept});

  final VoidCallback onAccept;

  @override
  State<_SwipeToAccept> createState() => _SwipeToAcceptState();
}

class _SwipeToAcceptState extends State<_SwipeToAccept> {
  double _progress = 0;

  @override
  Widget build(BuildContext context) {
    const thumbSize = 48.0;
    const inset = 4.0;
    final direction = Directionality.of(context);
    return LayoutBuilder(
      builder: (context, constraints) {
        final travel = constraints.maxWidth - thumbSize - inset * 2;
        return DecoratedBox(
          decoration: BoxDecoration(
            color: AppColors.softBlushEnd,
            borderRadius: BorderRadius.circular(28),
          ),
          child: Stack(
            alignment: Alignment.center,
            children: [
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: thumbSize + inset,
                ),
                child: ConstrainedBox(
                  constraints: const BoxConstraints(
                    minHeight: thumbSize + inset * 2,
                  ),
                  child: const Center(
                    child: Text('Swipe to accept', textAlign: TextAlign.center),
                  ),
                ),
              ),
              if (travel > 0)
                PositionedDirectional(
                  start: inset + travel * _progress,
                  child: GestureDetector(
                    excludeFromSemantics: true,
                    onHorizontalDragUpdate: (details) {
                      final delta = direction == TextDirection.ltr
                          ? details.delta.dx
                          : -details.delta.dx;
                      setState(
                        () => _progress = (_progress + delta / travel).clamp(
                          0.0,
                          1.0,
                        ),
                      );
                    },
                    onHorizontalDragCancel: () => setState(() => _progress = 0),
                    onHorizontalDragEnd: (_) {
                      final completed = _progress >= 0.9;
                      setState(() => _progress = 0);
                      if (completed) widget.onAccept();
                    },
                    child: SizedBox.square(
                      dimension: thumbSize,
                      child: DecoratedBox(
                        decoration: const BoxDecoration(
                          color: AppColors.primary,
                          shape: BoxShape.circle,
                        ),
                        child: Icon(
                          direction == TextDirection.ltr
                              ? Icons.chevron_right
                              : Icons.chevron_left,
                          color: AppColors.onPrimary,
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
