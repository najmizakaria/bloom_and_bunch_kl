import 'dart:js_interop';
import '../config/web_configuration.dart';

@JS('bloomLoadMaps')
external JSPromise<JSAny?> _loadMaps(JSString key);
@JS('window.addEventListener')
external void _addListener(JSString event, JSFunction listener);
@JS('window.removeEventListener')
external void _removeListener(JSString event, JSFunction listener);

Stream<void> mapFailures() => Stream<void>.multi((controller) {
  final listener = ((JSAny? event) => controller.add(null)).toJS;
  _addListener('bloom-maps-error'.toJS, listener);
  controller.onCancel = () =>
      _removeListener('bloom-maps-error'.toJS, listener);
});
Future<void> ensureMaps() async {
  final key = WebConfiguration.mapsApiKey;
  await _loadMaps(key.toJS).toDart;
}
