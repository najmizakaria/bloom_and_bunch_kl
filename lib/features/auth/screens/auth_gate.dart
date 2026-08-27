import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/user_model.dart';
import '../../rider/screens/rider_home_screen.dart';
import 'login_screen.dart';

// Placeholder dashboards (we will replace these with full features in later sprints)
import '../../customer/screens/main_navigation_screen.dart';
import '../../florist/screens/florist_home_screen.dart';
import '../../admin/admin_dashboard_screen.dart';

class AuthGate extends StatelessWidget {
  const AuthGate({super.key});

  @override
  Widget build(BuildContext context) {
    final AuthService authService = AuthService();
    final FirestoreService firestoreService = FirestoreService();

    return StreamBuilder<User?>(
      stream: authService.authStateChanges,
      builder: (context, snapshot) {
        // 1. Loading state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        // 2. User NOT logged in
        if (!snapshot.hasData || snapshot.data == null) {
          return const LoginScreen();
        }

        // 3. User logged in -> Fetch role from Firestore (live stream, so it
        // catches the profile doc the instant it finishes being written).
        return StreamBuilder<UserModel?>(
          stream: firestoreService.streamUserData(snapshot.data!.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || userSnapshot.data == null) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            final UserModel user = userSnapshot.data!;

            // 4. Role-based Navigation
            switch (user.role) {
              case 'florist':
                return const FloristHomeScreen();
              case 'rider':
                return const RiderHomeScreen();
              case 'admin':
                return const AdminDashboardScreen();
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