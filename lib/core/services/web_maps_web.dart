import 'dart:js_interop';
import '../config/web_configuration.dart';

@JS('bloomLoadMaps')
external JSPromise<JSAny?> _loadMaps(JSString key);
Future<void> ensureMaps() async {
  final key = WebConfiguration.mapsApiKey;
  await _loadMaps(key.toJS).toDart;
}
