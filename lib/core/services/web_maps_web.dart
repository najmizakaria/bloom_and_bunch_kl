import 'dart:js_interop';

@JS('bloomLoadMaps')
external JSPromise<JSAny?> _loadMaps(JSString key);
Future<void> ensureMaps() async {
  const key = String.fromEnvironment('MAPS_API_KEY_WEB');
  await _loadMaps(key.toJS).toDart;
}
