import 'package:bloom_and_bunch_kl/core/services/auth_service.dart';
import 'package:bloom_and_bunch_kl/features/auth/screens/login_screen.dart';
import 'package:bloom_and_bunch_kl/features/auth/screens/signup_email_screen.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

class TestUser implements User {
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestCredential implements UserCredential {
  @override
  User get user => TestUser();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class TestAuth implements AuthService {
  bool cancelGoogle = false;
  bool failEmail = false;
  @override
  Future<UserCredential?> signIn({
    required String email,
    required String password,
  }) async {
    if (failEmail) throw FirebaseAuthException(code: 'invalid-credential');
    return TestCredential();
  }

  @override
  Future<UserCredential?> signUp({
    required String name,
    required String email,
    required String password,
    required String phone,
    String role = 'customer',
  }) async => TestCredential();
  @override
  Future<UserCredential?> signInWithGoogle() async =>
      cancelGoogle ? null : TestCredential();
  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

Future<void> openAuth(WidgetTester tester, Widget screen) async {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);
  await tester.pumpWidget(
    MaterialApp(
      home: Builder(
        builder: (context) => Scaffold(
          body: TextButton(
            onPressed: () => Navigator.push(
              context,
              MaterialPageRoute<void>(builder: (_) => screen),
            ),
            child: const Text('Home'),
          ),
        ),
      ),
    ),
  );
  await tester.tap(find.text('Home'));
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('email login immediately returns to the root dashboard', (
    tester,
  ) async {
    await openAuth(tester, LoginScreen(authService: TestAuth()));
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'buyer@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
  testWidgets('signup immediately returns to the root dashboard', (
    tester,
  ) async {
    await openAuth(tester, SignupEmailScreen(authService: TestAuth()));
    await tester.enterText(find.byType(TextFormField).at(0), 'Buyer');
    await tester.enterText(
      find.byType(TextFormField).at(1),
      'buyer@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(2), 'password123');
    await tester.tap(find.widgetWithText(FilledButton, 'Create account'));
    await tester.pumpAndSettle();
    expect(find.byType(SignupEmailScreen), findsNothing);
    expect(find.text('Home'), findsOneWidget);
  });
  for (final signup in [false, true]) {
    testWidgets(
      'Google ${signup ? 'signup' : 'login'} returns home only on success',
      (tester) async {
        final auth = TestAuth()..cancelGoogle = true;
        await openAuth(
          tester,
          signup
              ? SignupEmailScreen(authService: auth)
              : LoginScreen(authService: auth),
        );
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(find.text('Continue with Google'), findsOneWidget);
        auth.cancelGoogle = false;
        await tester.tap(find.text('Continue with Google'));
        await tester.pumpAndSettle();
        expect(find.text('Home'), findsOneWidget);
        expect(find.text('Continue with Google'), findsNothing);
      },
    );
  }
  testWidgets('failed login stays on the form with a useful error', (
    tester,
  ) async {
    await openAuth(
      tester,
      LoginScreen(authService: TestAuth()..failEmail = true),
    );
    await tester.enterText(
      find.byType(TextFormField).at(0),
      'buyer@example.com',
    );
    await tester.enterText(find.byType(TextFormField).at(1), 'wrong-password');
    await tester.tap(find.widgetWithText(FilledButton, 'Log in'));
    await tester.pumpAndSettle();
    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.text('The email or password is incorrect.'), findsOneWidget);
  });
}
