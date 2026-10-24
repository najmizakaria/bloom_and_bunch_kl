import 'package:bloom_and_bunch_kl/core/widgets/page_navigation.dart';
import 'package:flutter/material.dart';
import '../services/auth_service.dart';
import '../theme/app_colors.dart';
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
  Widget build(BuildContext context) => Card(
    margin: const EdgeInsets.only(bottom: 8),
    elevation: 2,
    shadowColor: Colors.black.withValues(alpha: 0.10),
    shape: RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(16),
      side: const BorderSide(color: AppColors.inputBorder),
    ),
    child: ListTile(
      leading: const Icon(Icons.logout, color: AppColors.primary),
      title: const Text('Log out'),
      onTap: _busy ? null : _logout,
      trailing: _busy
          ? const SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(strokeWidth: 2),
            )
          : const Icon(Icons.chevron_right),
    ),
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
