import 'package:geolocator/geolocator.dart';
import 'package:geocoding/geocoding.dart';

class LocationService {
  final Geocoding _geocoding = Geocoding();

  /// Returns a human-readable address string, or throws if permission
  /// denied / location services off.
  Future<String> getCurrentAddress() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) {
      throw Exception('Location services are disabled.');
    }

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
      if (permission == LocationPermission.denied) {
        throw Exception('Location permission denied.');
      }
    }
    if (permission == LocationPermission.deniedForever) {
      throw Exception('Location permission permanently denied. Enable it in app settings.');
    }

    final position = await Geolocator.getCurrentPosition(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high),
    );

    final placemarks = await _geocoding.placemarkFromCoordinates(
      position.latitude,
      position.longitude,
    );

    if (placemarks.isEmpty) return 'Current location';

    final p = placemarks.first;
    final parts = [p.street, p.subLocality, p.locality]
        .where((s) => s != null && s.isNotEmpty)
        .toList();
    return parts.isEmpty ? 'Current location' : parts.join(', ');
  }

  /// Converts a manually typed address into coordinates + a clean label.
  Future<String> geocodeAddress(String query) async {
    final locations = await _geocoding.locationFromAddress(query);
    if (locations.isEmpty) throw Exception('Address not found.');
    return query;
  }
}