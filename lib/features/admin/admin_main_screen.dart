import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'admin_shell.dart';

class AdminMainScreen extends StatelessWidget {
  const AdminMainScreen({super.key});

  @override
  Widget build(BuildContext context) => AdminShell(
    accountName:
        FirebaseAuth.instance.currentUser?.displayName ?? 'Administrator',
  );
}
