import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart' show kIsWeb, kDebugMode;
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:provider/provider.dart';
import 'core/config/app_environment.dart';
import 'core/services/app_monitoring.dart';
import 'core/services/payment_links.dart';
import 'core/widgets/payment_link_session.dart';
import 'core/theme/app_theme.dart';
import 'core/providers/cart_provider.dart';
import 'core/services/cart_sync_service.dart';
import 'core/widgets/auth_cart_sync.dart';
import 'core/widgets/notification_session.dart';
import 'core/widgets/app_router.dart';
import 'features/auth/screens/auth_gate.dart';

final appNavigatorKey = GlobalKey<NavigatorState>();
final appMessengerKey = GlobalKey<ScaffoldMessengerState>();
final paymentLinks = PaymentLinks();
final paymentLinkNavigatorObserver = PaymentLinkNavigatorObserver();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  if (!kIsWeb && !AppEnvironment.isDemo) paymentLinks.start();
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
    try {
      if (!AppEnvironment.isDemo && (!kIsWeb || kDebugMode)) {
        await dotenv.load(fileName: '.env', isOptional: true);
      }
      await AppEnvironment.initialize();
      await AppMonitoring.initialize();
    } catch (error, stack) {
      if (kDebugMode) {
        FlutterError.reportError(
          FlutterErrorDetails(
            exception: error,
            stack: stack,
            library: 'app startup',
          ),
        );
      }
      rethrow;
    }
  }

  @override
  Widget build(BuildContext context) => FutureBuilder<void>(
    future: _startup,
    builder: (context, snapshot) {
      if (snapshot.connectionState == ConnectionState.done &&
          !snapshot.hasError) {
        return const BloomAndBunchApp();
      }
      return MaterialApp(
        theme: AppTheme.lightTheme,
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: snapshot.hasError
                  ? Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.cloud_off_outlined, size: 48),
                        const SizedBox(height: 16),
                        const Text(
                          'We could not start the app. Please try again.',
                          textAlign: TextAlign.center,
                        ),
                        if (kDebugMode) ...[
                          const SizedBox(height: 12),
                          Text(
                            snapshot.error is StateError
                                ? (snapshot.error as StateError).message
                                      .toString()
                                : 'Startup initialization failed. Check the Flutter terminal for the error details.',
                            textAlign: TextAlign.center,
                          ),
                        ],
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: () =>
                              setState(() => _startup = _initialize()),
                          child: const Text('Try again'),
                        ),
                      ],
                    )
                  : const CircularProgressIndicator(),
            ),
          ),
        ),
      );
    },
  );
}

class BloomAndBunchApp extends StatefulWidget {
  const BloomAndBunchApp({super.key});
  @override
  State<BloomAndBunchApp> createState() => _BloomAndBunchAppState();
}

class _BloomAndBunchAppState extends State<BloomAndBunchApp> {
  late final _router = AppRouterDelegate(
    navigatorKey: appNavigatorKey,
    observers: [paymentLinkNavigatorObserver],
    home: const AuthGate(),
  );
  @override
  void dispose() {
    _router.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => ChangeNotifierProvider(
    create: (_) => CartProvider(syncService: CartSyncService()),
    child: AuthCartSync(
      navigatorKey: appNavigatorKey,
      child: MaterialApp.router(
        routerDelegate: _router,
        scaffoldMessengerKey: appMessengerKey,
        builder: (context, child) => NotificationSession(
          messengerKey: appMessengerKey,
          navigatorKey: appNavigatorKey,
          child: kIsWeb || AppEnvironment.isDemo
              ? child!
              : PaymentLinkSession(
                  links: paymentLinks,
                  navigatorKey: appNavigatorKey,
                  routeChanges: paymentLinkNavigatorObserver.changes,
                  child: child!,
                ),
        ),
        title: 'Bloom & Bunch KL',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.lightTheme,
      ),
    ),
  );
}
