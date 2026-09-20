import 'package:flutter/material.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';

class DeliveryPinScreen extends StatefulWidget {
  final LatLng initialPosition;
  const DeliveryPinScreen({super.key, required this.initialPosition});
  @override
  State<DeliveryPinScreen> createState() => _DeliveryPinScreenState();
}

class _DeliveryPinScreenState extends State<DeliveryPinScreen> {
  late LatLng _pin = widget.initialPosition;
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Confirm delivery pin')),
    body: Column(
      children: [
        const Padding(
          padding: EdgeInsets.all(16),
          child: Text('Tap the map to place the pin at the delivery entrance.'),
        ),
        Expanded(
          child: GoogleMap(
            initialCameraPosition: CameraPosition(target: _pin, zoom: 16),
            onTap: (pin) => setState(() => _pin = pin),
            markers: {
              Marker(
                markerId: const MarkerId('delivery'),
                position: _pin,
                draggable: true,
                onDragEnd: (pin) => setState(() => _pin = pin),
              ),
            },
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(16),
          child: FilledButton(
            onPressed: () => Navigator.pop(context, _pin),
            child: const Text('Use this delivery pin'),
          ),
        ),
      ],
    ),
  );
}
