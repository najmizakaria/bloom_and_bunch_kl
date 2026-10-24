// Platform geocoding uses the native plugin on mobile and Maps JS on web.
import 'geocoder_native.dart'
    if (dart.library.js_interop) 'geocoder_web.dart'
    as platform;

class ResolvedLocation {
  final double latitude, longitude;
  final String address;
  final String locality, postcode, state;
  const ResolvedLocation(
    this.latitude,
    this.longitude,
    this.address, {
    this.locality = '',
    this.postcode = '',
    this.state = '',
  });
}

class AddressGeocoder {
  Future<ResolvedLocation> fromAddress(String address) =>
      platform.fromAddress(address);
  Future<ResolvedLocation> fromCoordinates(double latitude, double longitude) =>
      platform.fromCoordinates(latitude, longitude);
}
