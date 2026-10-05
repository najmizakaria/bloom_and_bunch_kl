import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import 'action_confirmation.dart';

class LogoutTile extends StatefulWidget {
  const LogoutTile({super.key});
  @override
  State<LogoutTile> createState() => _LogoutTileState();
}

class _LogoutTileState extends State<LogoutTile> {
  bool _busy = false;
  Future<void> _logout() async {
    if (!await confirmAction(
          context,
          title: 'Log out?',
          message: 'You will need to sign in again to use your account.',
          action: 'Log out',
        ) ||
        !mounted) {
      return;
    }
    setState(() => _busy = true);
    try {
      await AuthService().signOut();
      if (mounted) Navigator.of(context).popUntil((route) => route.isFirst);
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not log out. Please try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => ListTile(
    leading: const Icon(Icons.logout),
    title: const Text('Log out'),
    onTap: _busy ? null : _logout,
    trailing: _busy
        ? const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(strokeWidth: 2),
          )
        : null,
  );
}

class AccountMoreScreen extends StatelessWidget {
  const AccountMoreScreen({super.key});
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      leading: const PageBackButton(),
      centerTitle: false,
      title: const Text('More'),
    ),
    body: const SafeArea(child: LogoutTile()),
  );
}
