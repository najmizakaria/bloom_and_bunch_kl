import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/config/app_environment.dart';
import 'core/services/app_monitoring.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/cart_provider.dart';
import 'core/widgets/auth_cart_sync.dart';
import 'core/widgets/notification_session.dart';
import 'features/auth/screens/auth_gate.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const _StartupApp());
}
class _StartupApp extends StatefulWidget {
  const _StartupApp();
  @override
  State<_StartupApp> createState() => _StartupAppState();
}
class _StartupAppState extends State<_StartupApp> {
  late Future<void> _startup = _initialize();
  Future<void> _initialize() async {
    if (!kIsWeb && !AppEnvironment.isDemo) await dotenv.load(fileName: '.env', isOptional: true);
    await AppEnvironment.initialize();
    await AppMonitoring.initialize();
  }
  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done && !snapshot.hasError) return const BloomAndBunchApp();
      return MaterialApp(theme: AppTheme.lightTheme, home: Scaffold(body: Center(child: Padding(
        padding: const EdgeInsets.all(24),
        child: snapshot.hasError ? Column(mainAxisSize: MainAxisSize.min, children: [
          const Icon(Icons.cloud_off_outlined, size: 48), const SizedBox(height: 16),
          const Text('We could not start the app. Check your connection and try again.', textAlign: TextAlign.center),
          const SizedBox(height: 16), FilledButton(onPressed: () => setState(() => _startup = _initialize()), child: const Text('Try again')),
        ]) : const CircularProgressIndicator(),
      ))));
    },
  );
}
class BloomAndBunchApp extends StatelessWidget {
  const BloomAndBunchApp({super.key});
  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => CartProvider(),
    child: AuthCartSync(navigatorKey: appNavigatorKey, child: MaterialApp(
      navigatorKey: appNavigatorKey, scaffoldMessengerKey: appMessengerKey,
      builder: (context, child) => NotificationSession(messengerKey: appMessengerKey, navigatorKey: appNavigatorKey, child: child!),
      title: 'Bloom & Bunch KL', debugShowCheckedModeBanner: false, theme: AppTheme.lightTheme,
      home: const AuthGate(),
    )),
  );
}
