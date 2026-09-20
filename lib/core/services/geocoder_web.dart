import 'dart:js_interop';
import 'address_geocoder.dart';

@JS('google.maps.Geocoder')
extension type _Geocoder._(JSObject _) implements JSObject {
  external factory _Geocoder();
  external JSPromise<_Response> geocode(JSObject request);
}
extension type _Response._(JSObject _) implements JSObject {
  external JSArray<_Result> get results;
}
extension type _Result._(JSObject _) implements JSObject {
  @JS('formatted_address')
  external String get formattedAddress;
  external _Geometry get geometry;
}
extension type _Geometry._(JSObject _) implements JSObject {
  external _LatLng get location;
}
extension type _LatLng._(JSObject _) implements JSObject {
  external double lat();
  external double lng();
}
Future<ResolvedLocation> _resolve(Map<String, Object> request) async {
  final response = await _Geocoder()
      .geocode(request.jsify() as JSObject)
      .toDart;
  final matches = response.results.toDart;
  if (matches.isEmpty) throw StateError('Address not found.');
  final first = matches.first;
  return ResolvedLocation(
    first.geometry.location.lat(),
    first.geometry.location.lng(),
    first.formattedAddress,
  );
}

Future<ResolvedLocation> fromAddress(String address) =>
    _resolve({'address': address, 'region': 'MY'});
Future<ResolvedLocation> fromCoordinates(double latitude, double longitude) =>
    _resolve({
      'location': {'lat': latitude, 'lng': longitude},
    });
