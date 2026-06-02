import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../core/app_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../data_transfer/data/data_transfer_service.dart';
import '../../../data_transfer/data/file_save/file_save.dart';
import '../../../data_transfer/data/json_file_picker.dart';
import '../../../entries/presentation/bloc/entries_list_cubit.dart';
import '../../../tags/presentation/bloc/tags_cubit.dart';

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
          ListTile(
            leading: const Icon(Icons.info_outline),
            title: const Text('Version'),
            subtitle: Text(context.read<AppInfo>().version),
          ),
          ListTile(
            leading: const Icon(Icons.book_outlined),
            title: const Text('About Common Place Book'),
            onTap: () => _showAboutDialog(context),
          ),

          const Divider(),

          // Data section
          _buildSectionHeader(context, 'Data'),
          ListTile(
            leading: const Icon(Icons.upload_outlined),
            title: const Text('Export entries'),
            subtitle: const Text('Save a backup file'),
            onTap: () => _handleExport(context),
          ),
          ListTile(
            leading: const Icon(Icons.download_outlined),
            title: const Text('Import entries'),
            subtitle: const Text('Merge a backup into your library'),
            onTap: () => _handleImport(context),
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

  Future<void> _handleExport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<DataTransferService>();
    try {
      // Anchor the iPad share popover so share_plus does not crash on iPad (it
      // requires a sharePositionOrigin there). Computed before the first await
      // so it is safe to use the context, and inside the try so a render-object
      // failure surfaces as 'Export failed' rather than escaping unhandled.
      final origin = _shareOrigin(context);
      final result = await service.exportToJson();
      final json = result.valueOrNull;
      if (json == null) {
        messenger.showSnackBar(
          const SnackBar(content: Text('Export failed')),
        );
        return;
      }
      final outcome = await saveTextFile(
        fileName: 'commonplace-backup.json',
        contents: json,
        sharePositionOrigin: origin,
      );
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            outcome == FileSaveOutcome.dismissed
                ? 'Export cancelled'
                : 'Export ready',
          ),
        ),
      );
    } on Object catch (e) {
      AppLogger.error('Export failed', tag: 'SettingsScreen', error: e);
      messenger.showSnackBar(
        const SnackBar(content: Text('Export failed')),
      );
    }
  }

  /// Computes the global rect of this screen to anchor the iPad share popover.
  Rect? _shareOrigin(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) {
      return null;
    }
    return box.localToGlobal(Offset.zero) & box.size;
  }

  Future<void> _handleImport(BuildContext context) async {
    final messenger = ScaffoldMessenger.of(context);
    final service = context.read<DataTransferService>();
    final entriesCubit = context.read<EntriesListCubit>();
    final tagsCubit = context.read<TagsCubit>();

    try {
      final contents = await pickJsonFileContents();
      if (contents == null) return; // User cancelled.

      if (!context.mounted) return;
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Import backup'),
          content: const Text(
            'This merges the backup into your library: existing items are '
            'updated and new ones are added. Nothing currently in the app is '
            'deleted.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Import'),
            ),
          ],
        ),
      );
      if (confirmed != true) return;

      final result = await service.importFromJson(contents);
      final summary = result.valueOrNull;
      if (summary == null) {
        // Surface the specific reason (e.g. wrong/old/corrupt file).
        messenger.showSnackBar(
          SnackBar(
            content: Text(result.errorOrNull?.message ?? 'Import failed'),
          ),
        );
        return;
      }
      await entriesCubit.loadEntries();
      await tagsCubit.loadTags();
      // Imported categories are written to the DB but there is no category
      // cubit/UI to go stale yet. When a category list or picker is added,
      // refresh it here so imported categories appear without an app restart.
      messenger.showSnackBar(
        SnackBar(content: Text('Imported ${summary.entries} entries')),
      );
    } on Object catch (e) {
      AppLogger.error('Import failed', tag: 'SettingsScreen', error: e);
      messenger.showSnackBar(
        const SnackBar(content: Text('Import failed')),
      );
    }
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
