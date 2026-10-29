import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/user_model.dart';
import '../../rider/screens/rider_home_screen.dart';
import 'auth_welcome_screen.dart';

// Placeholder dashboards (we will replace these with full features in later sprints)
import '../../customer/screens/main_navigation_screen.dart';
import '../../florist/screens/florist_main_navigation_screen.dart';
import '../../admin/admin_main_screen.dart';
import '../../../core/widgets/logout_tile.dart';

class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  final AuthService authService = AuthService();
  final FirestoreService firestoreService = FirestoreService();
  late final Stream<User?> _authStream = authService.authStateChanges;
  Stream<UserModel?>? _profileStream;
  String? _profileUid;

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        // 1. Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. User NOT logged in
        if (!snapshot.hasData || snapshot.data == null) {
          _profileUid = null;
          _profileStream = null;
          return const AuthWelcomeScreen();
        }

        // 3. User logged in -> Fetch role from Firestore (live stream, so it
        // catches the profile doc the instant it finishes being written).
        if (_profileUid != snapshot.data!.uid) {
          _profileUid = snapshot.data!.uid;
          _profileStream = firestoreService.streamUserData(_profileUid!);
        }
        return StreamBuilder<UserModel?>(
          key: ValueKey(_profileUid),
          stream: _profileStream,
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (userSnapshot.hasError || !userSnapshot.hasData) {
              return Scaffold(
                body: Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('Your profile is not available yet.'),
                      TextButton(
                        onPressed: () => setState(() {
                          _profileStream = firestoreService.streamUserData(
                            _profileUid!,
                          );
                        }),
                        child: const Text('Retry'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute<void>(
                            builder: (_) => const AccountMoreScreen(),
                          ),
                        ),
                        child: const Text('More'),
                      ),
                    ],
                  ),
                ),
              );
            }

            final UserModel user = userSnapshot.data!;
            if (user.accountSuspended) {
              return const Scaffold(
                body: Center(
                  child: Padding(
                    padding: EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          'Your account is suspended. Contact the store for help.',
                        ),
                        LogoutTile(),
                      ],
                    ),
                  ),
                ),
              );
            }

            // 4. Role-based Navigation
            switch (user.activeRole) {
              case 'florist':
                return const FloristMainNavigationScreen();
              case 'rider':
                return const RiderHomeScreen();
              case 'admin':
                return const AdminMainScreen();
              case 'customer':
              default:
                return const MainNavigationScreen();
            }
          },
        );
      },
    );
  }
}
