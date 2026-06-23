import 'package:flutter/material.dart';

/// "Your data & privacy" page reached from Settings.
///
/// States the project's data promise plainly: you own your data, you can
/// export it anytime, and we will never read or use it — then notes that
/// cross-device sync is on the way and will keep the same promise.
class PrivacyScreen extends StatelessWidget {
  const PrivacyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text('Your data & privacy'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 32),
        children: [
          // Hero: the promise in one line.
          Center(
            child: Column(
              children: [
                Icon(
                  Icons.shield_outlined,
                  size: 56,
                  color: colors.secondary,
                ),
                const SizedBox(height: 12),
                Text(
                  'Your data stays yours',
                  style: theme.textTheme.headlineSmall,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 6),
                Text(
                  'How Common Place Book handles what you save.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: colors.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
          const SizedBox(height: 32),

          const _InfoCard(
            icon: Icons.verified_user_outlined,
            title: 'You own your data',
            body: 'Everything you save lives on your device. Your entries are '
                'yours — to keep, edit, and delete on your terms.',
          ),
          const _InfoCard(
            icon: Icons.file_download_outlined,
            title: 'Export anytime',
            body: 'Back up your entire library to a file whenever you like and '
                'take it with you. Open Settings → Export entries to save a '
                'copy you fully control.',
          ),
          const _InfoCard(
            icon: Icons.visibility_off_outlined,
            title: 'We never look at your data',
            body: 'We will never read, analyse, sell, or share what you write. '
                'Your commonplace book is for your eyes only — there is no '
                'tracking and no profiling of your entries.',
          ),
          const _InfoCard(
            icon: Icons.devices_outlined,
            title: 'Sync is coming',
            body: 'Cross-device sync between web and mobile is on the way, so '
                'your library can travel with you. When it arrives it will keep '
                'the same promise: your data stays yours and private to you.',
          ),
        ],
      ),
    );
  }
}

/// A single data-promise card: leading icon, bold title, supporting body.
class _InfoCard extends StatelessWidget {
  const _InfoCard({
    required this.icon,
    required this.title,
    required this.body,
  });

  final IconData icon;
  final String title;
  final String body;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: colors.secondary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: theme.textTheme.titleMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    body,
                    style: theme.textTheme.bodyMedium?.copyWith(
                      color: colors.onSurface.withValues(alpha: 0.75),
                      height: 1.4,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
