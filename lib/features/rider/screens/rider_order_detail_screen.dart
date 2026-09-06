import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import 'package:geocoding/geocoding.dart'; 
import '../../../models/order_model.dart';

class RiderOrderDetailScreen extends StatefulWidget {
  final OrderModel order;

  const RiderOrderDetailScreen({super.key, required this.order});

  @override
  State<RiderOrderDetailScreen> createState() => _RiderOrderDetailScreenState();
}

class _RiderOrderDetailScreenState extends State<RiderOrderDetailScreen> {
  bool _isLoading = false;
  
  LatLng? _deliveryLocation;
  bool _isLoadingMap = true;
  // Default fallback center (Kuala Lumpur) if address lookup fails on web
  static const LatLng _klFallback = LatLng(3.1390, 101.6869);

  @override
  void initState() {
    super.initState();
    _fetchCoordinates(); 
  }

  Future<void> _fetchCoordinates() async {
    try {
      if (kIsWeb) {
        // 🌐 WEB HANDLING: Avoids CORS network crashes on web browsers
        // Defaults map to KL location if web geocoding is restricted
        setState(() {
          _deliveryLocation = _klFallback;
          _isLoadingMap = false;
        });
      } else {
        // 🤖 MOBILE HANDLING: Uses native Android Geocoding API
        final geocoding = Geocoding();
        List<Location> locations = await geocoding.locationFromAddress(widget.order.deliveryAddress);

        if (locations.isNotEmpty && mounted) {
          setState(() {
            _deliveryLocation = LatLng(locations.first.latitude, locations.first.longitude);
            _isLoadingMap = false;
          });
        } else if (mounted) {
          setState(() {
            _deliveryLocation = _klFallback;
            _isLoadingMap = false;
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _deliveryLocation = _klFallback;
          _isLoadingMap = false;
        });
      }
    }
  }

  Future<void> _acceptDelivery() async {
    setState(() => _isLoading = true);
    try {
      final currentUserId = FirebaseAuth.instance.currentUser!.uid;
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.orderId).update({
        'orderStatus': 'Out for Delivery',
        'riderId': currentUserId,
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _markAsDelivered() async {
    setState(() => _isLoading = true);
    try {
      await FirebaseFirestore.instance.collection('orders').doc(widget.order.orderId).update({
        'orderStatus': 'Delivered',
      });
      if (mounted) Navigator.pop(context);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: $e')));
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final isAvailable = widget.order.orderStatus == 'Ready for Delivery';
    final isOutForDelivery = widget.order.orderStatus == 'Out for Delivery';

    return Scaffold(
      appBar: AppBar(
        title: const Text('Delivery Route'),
        backgroundColor: Colors.deepOrange,
        foregroundColor: Colors.white,
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
                          child: const Center(
                            child: Text('Could not load map.\nPlease check address details.', textAlign: TextAlign.center),
                          ),
                        )
                      : GoogleMap(
                          initialCameraPosition: CameraPosition(
                            target: _deliveryLocation!,
                            zoom: 15.0,
                          ),
                          markers: {
                            Marker(
                              markerId: const MarkerId('delivery_dropoff'),
                              position: _deliveryLocation!,
                              infoWindow: InfoWindow(title: widget.order.recipientName),
                              icon: BitmapDescriptor.defaultMarkerWithHue(BitmapDescriptor.hueOrange),
                            ),
                          },
                        ),
            ),
            
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Card(
                    color: isAvailable ? Colors.orange.shade50 : Colors.blue.shade50,
                    child: ListTile(
                      title: const Text('Current Status', style: TextStyle(fontWeight: FontWeight.bold)),
                      subtitle: Text(widget.order.orderStatus, style: TextStyle(color: isAvailable ? Colors.orange : Colors.blue, fontSize: 18, fontWeight: FontWeight.bold)),
                    ),
                  ),
                  const SizedBox(height: 20),

                  const Text('Drop-off Details', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  const Divider(),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.location_on, color: Colors.deepOrange),
                    title: Text(widget.order.deliveryAddress),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.person, color: Colors.deepOrange),
                    title: Text(widget.order.recipientName),
                  ),
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    leading: const Icon(Icons.phone, color: Colors.deepOrange),
                    title: Text(widget.order.recipientPhone),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: isAvailable || isOutForDelivery
          ? Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 10, offset: const Offset(0, -5))],
              ),
              child: ElevatedButton(
                onPressed: _isLoading
                    ? null
                    : (isAvailable ? _acceptDelivery : _markAsDelivered),
                style: ElevatedButton.styleFrom(
                  backgroundColor: isAvailable ? Colors.deepOrange : Colors.green,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                ),
                child: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : Text(
                        isAvailable ? 'Accept Delivery' : 'Mark as Delivered',
                        style: const TextStyle(fontSize: 18, color: Colors.white),
                      ),
              ),
            )
          : null,
    );
  }
}