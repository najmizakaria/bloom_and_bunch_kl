import 'package:bloom_and_bunch_kl/core/config/web_configuration.dart';
import 'package:bloom_and_bunch_kl/firebase_options.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late DotEnv previous;
  setUp(() {
    previous = dotenv;
    dotenv = DotEnv();
  });
  tearDown(() => dotenv = previous);

  const compiledFirebase = String.fromEnvironment('FIREBASE_API_KEY_WEB');
  const compiledMaps = String.fromEnvironment('MAPS_API_KEY_WEB');
  const compiledVapid = String.fromEnvironment('FCM_VAPID_KEY_WEB');
  const compiledAppCheck = String.fromEnvironment('APP_CHECK_WEB_SITE_KEY');

  test('plain debug runs resolve public web settings from the local env', () {
    dotenv.testLoad(
      fileInput: '''
FIREBASE_API_KEY_WEB=local-firebase
MAPS_API_KEY_WEB=local-maps
FCM_VAPID_KEY_WEB=local-vapid
APP_CHECK_WEB_SITE_KEY=local-app-check
''',
    );
    expect(
      WebConfiguration.firebaseApiKey,
      compiledFirebase.isEmpty ? 'local-firebase' : compiledFirebase,
    );
    expect(
      WebConfiguration.mapsApiKey,
      compiledMaps.isEmpty ? 'local-maps' : compiledMaps,
    );
    expect(
      WebConfiguration.vapidKey,
      compiledVapid.isEmpty ? 'local-vapid' : compiledVapid,
    );
    expect(
      WebConfiguration.appCheckSiteKey,
      compiledAppCheck.isEmpty ? 'local-app-check' : compiledAppCheck,
    );
    expect(
      DefaultFirebaseOptions.web.apiKey,
      compiledFirebase.isEmpty ? 'local-firebase' : compiledFirebase,
    );
    expect(DefaultFirebaseOptions.web.projectId, 'bloom-and-bunch-kl');
  });

  test(
    'missing configuration reports the setting and normal local command',
    () {
      if (compiledFirebase.isEmpty) {
        expect(
          () => DefaultFirebaseOptions.web,
          throwsA(
            isA<StateError>().having(
              (e) => e.message.toString(),
              'message',
              allOf(
                contains('FIREBASE_API_KEY_WEB'),
                contains('flutter run -d edge'),
              ),
            ),
          ),
        );
      } else {
        expect(DefaultFirebaseOptions.web.apiKey, compiledFirebase);
      }
      expect(WebConfiguration.mapsApiKey, compiledMaps);
      expect(WebConfiguration.vapidKey, compiledVapid);
      expect(WebConfiguration.appCheckSiteKey, compiledAppCheck);
    },
  );
}
