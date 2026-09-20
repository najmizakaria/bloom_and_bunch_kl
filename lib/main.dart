import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'firebase_options.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/cart_provider.dart';
import 'core/widgets/auth_cart_sync.dart';
import 'core/widgets/notification_session.dart';
import 'features/auth/screens/auth_gate.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb) {
    await dotenv.load(fileName: ".env");
  }

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
  } on FirebaseException catch (e) {
    if (e.code != 'duplicate-app') {
      rethrow;
    }
  }

  runApp(const BloomAndBunchApp());
}

class BloomAndBunchApp extends StatelessWidget {
  const BloomAndBunchApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => CartProvider(),
      child: AuthCartSync(
        navigatorKey: appNavigatorKey,
        child: MaterialApp(
          navigatorKey: appNavigatorKey,
          scaffoldMessengerKey: appMessengerKey,
          builder: (context, child) => NotificationSession(
            messengerKey: appMessengerKey,
            navigatorKey: appNavigatorKey,
            child: child!,
          ),
          title: 'Bloom & Bunch KL',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.lightTheme,
          home: const AuthGate(),
        ),
      ),
    );
  }
}
