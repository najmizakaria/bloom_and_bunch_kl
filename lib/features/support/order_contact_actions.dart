import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../core/constants/fulfillment_constants.dart';
import '../../core/services/rider_contact_service.dart';
import '../../core/widgets/app_note.dart';

class OrderContactActions extends StatefulWidget {
  const OrderContactActions({
    super.key,
    required this.orderId,
    required this.order,
    this.trailing,
    this.service,
    this.open,
  });
  final String orderId;
  final Map<String, dynamic> order;
  final Widget? trailing;
  final RiderContactService? service;
  final Future<bool> Function(Uri)? open;

  @override
  State<OrderContactActions> createState() => _OrderContactActionsState();
}

class _OrderContactActionsState extends State<OrderContactActions> {
  bool _busy = false;
  bool get _assigned =>
      (widget.order['riderId'] as String?)?.isNotEmpty == true;
  bool get _active =>
      _assigned &&
      const [
        OrderStatuses.outForDelivery,
        OrderStatuses.awaitingConfirmation,
      ].contains(widget.order['orderStatus']);

  Future<void> _showContact(String role, RiderContact contact) =>
      showDialog<void>(
        context: context,
        builder: (_) =>
            _ContactDialog(role: role, contact: contact, open: widget.open),
      );

  Future<void> _callRider() async {
    if (_busy || !_active) return;
    final orderId = widget.orderId;
    final riderId = widget.order['riderId'];
    setState(() => _busy = true);
    try {
      final contact = await (widget.service ?? RiderContactService())
          .getForOrder(orderId);
      if (!mounted) return;
      if (!_active ||
          widget.orderId != orderId ||
          widget.order['riderId'] != riderId) {
        throw StateError(
          'The rider assignment changed. Please reopen this order.',
        );
      }
      await _showContact('Rider', contact);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(RiderContactService.message(error))),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final past = OrderStatuses.isPast(
      widget.order['orderStatus']?.toString() ?? '',
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              onPressed: () => _showContact(
                'Florist',
                const RiderContact(
                  name: 'Bloom & Bunch KL',
                  phone: '+60148376919',
                ),
              ),
              icon: const Icon(Icons.storefront_outlined),
              label: const Text('Call Florist'),
            ),
            if (!past)
              OutlinedButton.icon(
                onPressed: _active && !_busy ? _callRider : null,
                icon: const Icon(Icons.delivery_dining_outlined),
                label: Text(_busy ? 'Loading rider…' : 'Call Rider'),
              ),
            if (widget.trailing != null) widget.trailing!,
          ],
        ),
        if (!past && !_assigned) const AppNote('Rider not assigned yet'),
      ],
    );
  }
}

class _ContactDialog extends StatefulWidget {
  const _ContactDialog({required this.role, required this.contact, this.open});
  final String role;
  final RiderContact contact;
  final Future<bool> Function(Uri)? open;
  @override
  State<_ContactDialog> createState() => _ContactDialogState();
}

class _ContactDialogState extends State<_ContactDialog> {
  bool _opening = false;
  String? _error;
  Future<void> _dial() async {
    if (_opening) return;
    setState(() {
      _opening = true;
      _error = null;
    });
    try {
      final uri = Uri(scheme: 'tel', path: widget.contact.phone);
      final opened = await (widget.open?.call(uri) ?? launchUrl(uri));
      if (!mounted) return;
      if (opened) {
        Navigator.pop(context);
      } else {
        setState(
          () => _error =
              'No phone dialer is available. Copy the number above to call.',
        );
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'Could not open the phone dialer. Copy the number above to call.',
        );
      }
    } finally {
      if (mounted) setState(() => _opening = false);
    }
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    title: Text('Call ${widget.role}'),
    content: Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.contact.name),
        const SizedBox(height: 8),
        SelectableText(widget.contact.phone),
        if (_error != null)
          Padding(
            padding: const EdgeInsets.only(top: 12),
            child: Text(_error!),
          ),
      ],
    ),
    actions: [
      TextButton.icon(
        onPressed: () async {
          await Clipboard.setData(ClipboardData(text: widget.contact.phone));
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Phone number copied.')),
            );
          }
        },
        icon: const Icon(Icons.copy_outlined),
        label: const Text('Copy number'),
      ),
      TextButton(
        onPressed: () => Navigator.pop(context),
        child: const Text('Close'),
      ),
      FilledButton(
        onPressed: _opening ? null : _dial,
        child: Text('Call ${widget.role}'),
      ),
    ],
  );
}
