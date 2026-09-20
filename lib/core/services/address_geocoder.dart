// Platform geocoding uses the native plugin on mobile and Maps JS on web.
import 'geocoder_native.dart'
    if (dart.library.js_interop) 'geocoder_web.dart'
    as platform;

class ResolvedLocation {
  final double latitude, longitude;
  final String address;
  const ResolvedLocation(this.latitude, this.longitude, this.address);
}

class AddressGeocoder {
  Future<ResolvedLocation> fromAddress(String address) =>
      platform.fromAddress(address);
  Future<ResolvedLocation> fromCoordinates(double latitude, double longitude) =>
      platform.fromCoordinates(latitude, longitude);
}
