import 'package:geocoding/geocoding.dart';
import 'address_geocoder.dart';

Future<ResolvedLocation> fromAddress(String address) async {
  final matches = await Geocoding().locationFromAddress(address);
  if (matches.isEmpty) throw StateError('Address not found.');
  return ResolvedLocation(
    matches.first.latitude,
    matches.first.longitude,
    address,
  );
}

Future<ResolvedLocation> fromCoordinates(
  double latitude,
  double longitude,
) async {
  final places = await Geocoding().placemarkFromCoordinates(
    latitude,
    longitude,
  );
  if (places.isEmpty) throw StateError('Address not found.');
  final p = places.first;
  final label = [
    p.street,
    p.subLocality,
    p.locality,
    p.postalCode,
    p.administrativeArea,
    p.country,
  ].whereType<String>().where((s) => s.isNotEmpty).toSet().join(', ');
  return ResolvedLocation(latitude, longitude, label);
}
