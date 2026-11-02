import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:geocoding/geocoding.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/constants/store_details.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_typography.dart';
import '../../../core/widgets/map_access.dart';
import '../../../models/delivery_job_model.dart';
import '../../../models/order_model.dart';

class RiderNavigation {
  static Future<void> _open(BuildContext context, Uri uri, String error) async {
    try {
      if (await launchUrl(uri, mode: LaunchMode.externalApplication)) return;
    } catch (_) {}
    if (context.mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(error)));
    }
  }

  static Future<void> call(BuildContext context, OrderModel order) => _open(
    context,
    Uri(scheme: 'tel', path: order.recipientPhone),
    'Could not open the phone dialer.',
  );
  static Future<void> navigate(BuildContext context, OrderModel order) => _open(
    context,
    Uri.https('www.google.com', '/maps/dir/', {
      'api': '1',
      'destination': order.latitude != null && order.longitude != null
          ? '${order.latitude},${order.longitude}'
          : order.deliveryAddress,
    }),
    'Could not open navigation. Use the written delivery address.',
  );
}

class RiderDeliveryDetails extends StatelessWidget {
  const RiderDeliveryDetails({super.key, required this.order});
  final OrderModel order;

  @override
  Widget build(BuildContext context) {
    final timing = DeliveryJobModel(
      orderId: order.orderId,
      deliveryArea: '',
      deliveryTimeSlot: order.deliveryTimeSlot,
      createdAt: order.createdAt,
      requestedDeliveryDate: order.requestedDeliveryDate,
      scheduledDeliveryDate: order.scheduledDeliveryDate,
      estimatedDispatchDate: order.estimatedDispatchDate,
    );
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _RiderDeliveryMap(order: order),
            const SizedBox(height: 16),
            Text(
              'Delivery ${timing.reference}',
              style: const AppTypography.productTitle(),
            ),
            const SizedBox(height: 6),
            Text(
              order.orderStatus,
              style: const AppTypography.label(color: AppColors.primary),
            ),
            const SizedBox(height: 16),
            const Text(
              'Deliver to',
              style: AppTypography.caption(color: AppColors.textMuted),
            ),
            const SizedBox(height: 4),
            SelectableText(
              order.deliveryAddress.isEmpty
                  ? 'Address unavailable. Contact the store.'
                  : order.deliveryAddress,
              style: const AppTypography.sectionTitle(),
            ),
            const SizedBox(height: 12),
            Text(
              order.recipientName,
              style: const AppTypography.productTitle(),
            ),
            if (order.recipientPhone.isNotEmpty)
              SelectableText(order.recipientPhone),
            const SizedBox(height: 12),
            Text(timing.timingLabel(), style: const AppTypography.supporting()),
            if (timing.dateWarning() != null)
              Text(
                timing.dateWarning()!,
                style: const AppTypography.label(color: AppColors.primaryDark),
              ),
            if (order.deliveryNote.trim().isNotEmpty) ...[
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.inputFill,
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Delivery instructions',
                      style: AppTypography.label(),
                    ),
                    const SizedBox(height: 4),
                    Text(order.deliveryNote),
                  ],
                ),
              ),
            ],
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: order.deliveryAddress.isEmpty
                  ? null
                  : () => RiderNavigation.navigate(context, order),
              icon: const Icon(Icons.navigation_outlined),
              label: const Text('Navigate'),
            ),
            const SizedBox(height: 8),
            OutlinedButton.icon(
              onPressed: order.recipientPhone.isEmpty
                  ? null
                  : () => RiderNavigation.call(context, order),
              icon: const Icon(Icons.call_outlined),
              label: const Text('Call recipient'),
            ),
            const SizedBox(height: 16),
            const Divider(),
            const Text('Collect from', style: AppTypography.label()),
            const SizedBox(height: 4),
            const Text('${StoreDetails.name}\n${StoreDetails.pickupAddress}'),
            if (order.items.isNotEmpty) ...[
              const SizedBox(height: 16),
              const Text('Items to collect', style: AppTypography.label()),
              const SizedBox(height: 6),
              for (final item in order.items)
                Padding(
                  padding: const EdgeInsets.only(bottom: 4),
                  child: Text(
                    '${item['quantity'] ?? 1} × ${item['name'] ?? 'Bouquet'}${item['type'] == 'addon' ? ' · Add-on' : ''}',
                  ),
                ),
            ],
            if (order.messageCard != null)
              const Text('Include the selected message card.'),
          ],
        ),
      ),
    );
  }
}

class _RiderDeliveryMap extends StatefulWidget {
  const _RiderDeliveryMap({required this.order});
  final OrderModel order;

  @override
  State<_RiderDeliveryMap> createState() => _RiderDeliveryMapState();
}

class _RiderDeliveryMapState extends State<_RiderDeliveryMap> {
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
  void didUpdateWidget(covariant _RiderDeliveryMap oldWidget) {
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
        // Written address remains available when geocoding is unavailable.
        setState(() {
          _deliveryLocation = null;
          _isLoadingMap = false;
        });
      } else {
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

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: SizedBox(
          height: 220,
          width: double.infinity,
          child: _isLoadingMap
              ? const Center(child: CircularProgressIndicator())
              : _deliveryLocation == null
              ? Container(
                  color: AppColors.secondarySurface,
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
                  errorBuilder: (context, retry) => ColoredBox(
                    color: AppColors.secondarySurface,
                    child: Center(
                      child: SingleChildScrollView(
                        child: Padding(
                          padding: const EdgeInsets.all(16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.map_outlined),
                              const SizedBox(height: 8),
                              const Text(
                                'The map could not load. You can still open navigation to this delivery.',
                                textAlign: TextAlign.center,
                              ),
                              const SizedBox(height: 8),
                              Wrap(
                                alignment: WrapAlignment.center,
                                spacing: 8,
                                children: [
                                  TextButton(
                                    onPressed: retry,
                                    child: const Text('Retry map'),
                                  ),
                                  OutlinedButton.icon(
                                    onPressed: () => RiderNavigation.navigate(
                                      context,
                                      widget.order,
                                    ),
                                    icon: const Icon(Icons.navigation_outlined),
                                    label: const Text('Open Google Maps'),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                  child: GoogleMap(
                    key: ValueKey(
                      '${_deliveryLocation!.latitude},${_deliveryLocation!.longitude}',
                    ),
                    scrollGesturesEnabled: false,
                    zoomGesturesEnabled: false,
                    rotateGesturesEnabled: false,
                    tiltGesturesEnabled: false,
                    zoomControlsEnabled: false,
                    mapToolbarEnabled: false,
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
      ),
      if (_approximate)
        const Padding(
          padding: EdgeInsets.symmetric(vertical: 12),
          child: Text(
            'Approximate address marker. Confirm the exact entrance with the recipient.',
          ),
        ),
    ],
  );
}
