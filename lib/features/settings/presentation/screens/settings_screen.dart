import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/auth/auth_service.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final authService = context.read<AuthService>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
          // Account section: optional sign-in for cross-device sync. The app
          // is fully usable signed out; this never gates any screen (US-007).
          _buildSectionHeader(context, 'Account'),
          _AccountTile(authService: authService),

          const Divider(),

          // Appearance section
          _buildSectionHeader(context, 'Appearance'),
          ListTile(
            leading: const Icon(Icons.brightness_6_outlined),
            title: const Text('Theme'),
            subtitle: const Text('System default'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showThemeSelector(context),
          ),

          const Divider(),

          // About section
          _buildSectionHeader(context, 'About'),
          const ListTile(
            leading: Icon(Icons.info_outline),
            title: Text('Version'),
            subtitle: Text('1.0.0'),
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('About Common Place Book'),
            onTap: () => _showAboutDialog(context),
          ),

          const Divider(),

          // Data section
          _buildSectionHeader(context, 'Data'),
          const ListTile(
            leading: Icon(Icons.upload_outlined),
            title: Text('Export entries'),
            subtitle: Text('Coming soon'),
            enabled: false,
          ),
          const ListTile(
            leading: Icon(Icons.download_outlined),
            title: Text('Import entries'),
            subtitle: Text('Coming soon'),
            enabled: false,
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(BuildContext context, String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleSmall?.copyWith(
              color: Theme.of(context).colorScheme.primary,
            ),
      ),
    );
  }

  void _showThemeSelector(BuildContext context) {
    showModalBottomSheet<void>(
      context: context,
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.brightness_auto),
              title: const Text('System default'),
              trailing: const Icon(Icons.check),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.light_mode),
              title: const Text('Light'),
              onTap: () => Navigator.pop(context),
            ),
            ListTile(
              leading: const Icon(Icons.dark_mode),
              title: const Text('Dark'),
              onTap: () => Navigator.pop(context),
            ),
          ],
        ),
      ),
    );
  }

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (context) => AlertDialog(
        title: Row(
          children: [
            Icon(
              Icons.auto_stories,
              color: Theme.of(context).colorScheme.secondary,
            ),
            const SizedBox(width: 12),
            const Text('Common Place Book'),
          ],
        ),
        content: const Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'A digital commonplace book for storing and rediscovering golden nuggets of wisdom, quotes, and ideas.',
            ),
            SizedBox(height: 16),
            Text(
              'A commonplace book is a traditional method of compiling knowledge - a personal repository where one stores quotes, ideas, and observations organized by themes for later reflection and retrieval.',
              style: TextStyle(fontSize: 13),
            ),
            SizedBox(height: 16),
            Text(
              '"A commonplace book is what a provident poet cannot subsist without, for this proverbial reason, that great wits have short memories."',
              style: TextStyle(
                fontStyle: FontStyle.italic,
                fontSize: 13,
              ),
            ),
            Text(
              '— Jonathan Swift',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}

/// Settings row reflecting the current account state (US-007).
///
/// Signed out: an actionable row that routes to `/login`
/// ("Sign in to sync across devices"). Signed in: the account email plus a
/// "Sign out" action. Rebuilds reactively on [AuthService.authStateChanges]
/// so the row flips immediately when the user signs in or out elsewhere.
///
/// Signing out is non-destructive: it clears the session only and never
/// touches the local Drift database, so every entry stays on the device
/// (FR-11 / US-013).
class _AccountTile extends StatefulWidget {
  const _AccountTile({required this.authService});

  final AuthService authService;

  @override
  State<_AccountTile> createState() => _AccountTileState();
}

class _AccountTileState extends State<_AccountTile> {
  bool _isSigningOut = false;

  Future<void> _signOut() async {
    setState(() => _isSigningOut = true);
    final result = await widget.authService.signOut();

    if (!mounted) {
      return;
    }
    setState(() => _isSigningOut = false);

    result.fold(
      onSuccess: (_) => _showMessage('Signed out. Your entries stay on this '
          'device.'),
      onFailure: (failure) => _showMessage(failure.message, isError: true),
    );
  }

  void _showMessage(String message, {bool isError = false}) {
    final theme = Theme.of(context);
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: isError ? theme.colorScheme.error : null,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<AuthSessionState>(
      stream: widget.authService.authStateChanges,
      builder: (context, snapshot) {
        // The stream only emits on change, so seed the initial render from the
        // current user rather than waiting for the first event.
        final user = widget.authService.currentUser;
        if (user == null) {
          return ListTile(
            leading: const Icon(Icons.cloud_off_outlined),
            title: const Text('Sign in to sync across devices'),
            subtitle: const Text(
              'Optional. Back up your entries and keep every device in sync.',
            ),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.push('/login'),
          );
        }

        final email = user.email ?? 'Signed in';
        return ListTile(
          leading: const Icon(Icons.cloud_done_outlined),
          title: Text(email),
          subtitle: const Text('Synced across your devices'),
          trailing: _isSigningOut
              ? const SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : TextButton(
                  onPressed: _signOut,
                  child: const Text('Sign out'),
                ),
        );
      },
    );
  }
}
