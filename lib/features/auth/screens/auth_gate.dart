import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../../../core/services/auth_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../models/user_model.dart';
import 'login_screen.dart';

// Placeholder dashboards (we will replace these with full features in later sprints)
import '../../customer/customer_home_screen.dart';
import '../../florist/florist_dashboard_screen.dart';
import '../../rider/rider_dashboard_screen.dart';
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

        // 3. User logged in -> Fetch role from Firestore
        return FutureBuilder<UserModel?>(
          future: firestoreService.getUserData(snapshot.data!.uid),
          builder: (context, userSnapshot) {
            if (userSnapshot.connectionState == ConnectionState.waiting) {
              return const Scaffold(
                body: Center(child: CircularProgressIndicator()),
              );
            }

            if (!userSnapshot.hasData || userSnapshot.data == null) {
              return const LoginScreen();
            }

            final UserModel user = userSnapshot.data!;

            // 4. Role-based Navigation
            switch (user.role) {
              case 'florist':
                return const FloristDashboardScreen();
              case 'rider':
                return const RiderDashboardScreen();
              case 'admin':
                return const AdminDashboardScreen();
              case 'customer':
              default:
                return const CustomerHomeScreen();
            }
          },
        );
      },
    );
  }
}