import 'package:flutter/material.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
      ),
      body: ListView(
        children: [
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
          const ListTile(
            leading: Icon(Icons.cloud_outlined),
            title: Text('Cloud sync'),
            subtitle: Text('Coming in a future update'),
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
