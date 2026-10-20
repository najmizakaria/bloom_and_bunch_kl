import '../../../core/widgets/map_access.dart';
import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import '../../../core/widgets/live_order_detail.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_colors.dart';
import 'package:bloom_and_bunch_kl/core/theme/app_typography.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../../../core/services/order_service.dart';
import '../../support/order_support.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart';
import 'package:url_launcher/url_launcher.dart';
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

  LatLng? _deliveryLocation;
  bool _isLoadingMap = true;
  bool _approximate = false;
  int _mapRequest = 0;

  @override
  void initState() {
    super.initState();
    _fetchCoordinates();
  }

  @override
  void didUpdateWidget(covariant _RiderOrderDetailContent oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.order.deliveryAddress != widget.order.deliveryAddress ||
        oldWidget.order.latitude != widget.order.latitude ||
        oldWidget.order.longitude != widget.order.longitude) {
      _fetchCoordinates();
    }
  }

  Future<void> _fetchCoordinates() async {
    final request = ++_mapRequest;
    setState(() {
      _isLoadingMap = true;
      _approximate = false;
    });
    try {
      if (widget.order.latitude != null && widget.order.longitude != null) {
        setState(() {
          _deliveryLocation = LatLng(
            widget.order.latitude!,
            widget.order.longitude!,
          );
          _isLoadingMap = false;
        });
        return;
      }
      if (kIsWeb) {
        // 🌐 WEB HANDLING: Avoids CORS network crashes on web browsers
        // Written address remains available when geocoding is unavailable.
        setState(() {
          _deliveryLocation = null;
          _isLoadingMap = false;
        });
      } else {
        // 🤖 MOBILE HANDLING: Uses native Android Geocoding API
        final geocoding = Geocoding();
        List<Location> locations = await geocoding.locationFromAddress(
          widget.order.deliveryAddress,
        );

        if (!mounted || request != _mapRequest) return;
        if (locations.isNotEmpty && mounted) {
          setState(() {
            _approximate = true;
            _deliveryLocation = LatLng(
              locations.first.latitude,
              locations.first.longitude,
            );
            _isLoadingMap = false;
          });
        } else if (mounted) {
          setState(() {
            _deliveryLocation = null;
            _isLoadingMap = false;
          });
        }
      }
    } catch (e) {
      if (mounted && request == _mapRequest) {
        setState(() {
          _deliveryLocation = null;
          _isLoadingMap = false;
        });
      }
    }
  }

  Future<void> _callRecipient() async {
    final uri = Uri(scheme: 'tel', path: widget.order.recipientPhone);
    if (!await launchUrl(uri) && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open the phone dialer.')),
      );
    }
  }

  Future<void> _openNavigation() async {
    final destination =
        widget.order.latitude != null && widget.order.longitude != null
        ? '${widget.order.latitude},${widget.order.longitude}'
        : widget.order.deliveryAddress;
    final uri = Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': destination,
    });
    if (!await launchUrl(uri, mode: LaunchMode.externalApplication) &&
        mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not open navigation.')),
      );
    }
  }

  Future<void> _markAsDelivered() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Confirm delivered?'),
        content: const Text(
          'Confirm the bouquet has been handed to the recipient or left according to their instructions. The order will wait for customer receipt confirmation.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Not yet'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Confirm delivered'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    setState(() => _isLoading = true);
    try {
      await OrderService().transition(widget.order.orderId, 'deliver');
      if (mounted) Navigator.pop(context);
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
    final isOutForDelivery = widget.order.orderStatus == 'Out for Delivery';

    return Scaffold(
      appBar: AppBar(
        leading: const PageBackButton(),
        centerTitle: false,
        title: const Text('Delivery Route'),
        actions: [
          IconButton(
            tooltip: 'Report delivery problem',
            onPressed: () => reportIssue(context, widget.order.orderId),
            icon: const Icon(Icons.report_problem_outlined),
          ),
        ],
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              height: 250,
              width: double.infinity,
              child: _isLoadingMap
                  ? const Center(child: CircularProgressIndicator())
                  : _deliveryLocation == null
                  ? Container(
                      color: Colors.grey.shade200,
                      child: Center(
                        child: SingleChildScrollView(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text(
                                'Map unavailable. Use the written delivery address.',
                                textAlign: TextAlign.center,
                              ),
                              if (!kIsWeb)
                                TextButton(
                                  onPressed: _fetchCoordinates,
                                  child: const Text('Retry map'),
                                ),
                            ],
                          ),
                        ),
                      ),
                    )
                  : MapAccess(
                      child: GoogleMap(
                        key: ValueKey(
                          '${_deliveryLocation!.latitude},${_deliveryLocation!.longitude}',
                        ),
                        initialCameraPosition: CameraPosition(
                          target: _deliveryLocation!,
                          zoom: 15.0,
                        ),
                        markers: {
                          Marker(
                            markerId: const MarkerId('delivery_dropoff'),
                            position: _deliveryLocation!,
                            infoWindow: InfoWindow(
                              title: widget.order.recipientName,
                            ),
                            icon: BitmapDescriptor.defaultMarkerWithHue(
                              BitmapDescriptor.hueOrange,
                            ),
                          ),
                        },
                      ),
                    ),
            ),

            if (_approximate)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Approximate address marker. Confirm the exact entrance with the recipient.',
                ),
              ),
            if (widget.order.hasOpenIssue)
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'An open delivery issue pauses completion. Contact the store.',
                ),
              ),
            if (widget.order.orderStatus == 'Awaiting Customer Confirmation')
              const Padding(
                padding: EdgeInsets.all(12),
                child: Text(
                  'Delivery recorded. Waiting for customer receipt confirmation.',
                ),
              ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: AppColors.inputFill,
                    child: ListTile(
                      title: const Text(
                        'Current Status',
                        style: AppTypography.label(),
                      ),
                      subtitle: Text(
                        widget.order.orderStatus,
                        style: AppTypography.sectionTitle(
                          color: AppColors.primaryDark,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text(
                    'Drop-off Details',
                    style: AppTypography.sectionTitle(),
                  ),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(
                      Icons.location_on,
                      color: AppColors.primary,
                    ),
                    title: Text(widget.order.deliveryAddress),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person, color: AppColors.primary),
                    title: Text(widget.order.recipientName),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone, color: AppColors.primary),
                    title: Text(widget.order.recipientPhone),
                  ),
                  if (widget.order.deliveryNote.trim().isNotEmpty)
                    Card(
                      color: AppColors.inputFill,
                      child: ListTile(
                        leading: const Icon(
                          Icons.sticky_note_2_outlined,
                          color: AppColors.primary,
                        ),
                        title: const Text(
                          'Delivery instructions',
                          style: AppTypography.label(),
                        ),
                        subtitle: Text(widget.order.deliveryNote),
                      ),
                    ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton.icon(
                          onPressed: _callRecipient,
                          icon: const Icon(Icons.call_outlined),
                          label: const Text('Call'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: _openNavigation,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppColors.primary,
                          ),
                          icon: const Icon(Icons.navigation_outlined),
                          label: const Text('Navigate'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isOutForDelivery
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(color: Colors.white),
              child: ElevatedButton(
                onPressed: _isLoading || widget.order.hasOpenIssue
                    ? null
                    : _markAsDelivered,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primaryDark,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        'Mark as Delivered',
                        style: const AppTypography.sectionTitle(
                          color: Colors.white,
                        ),
                      ),
              ),
            )
          : null,
    );
  }
}
