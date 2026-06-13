import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/app_info.dart';
import '../../../../core/utils/app_logger.dart';
import '../../../data_transfer/data/data_transfer_service.dart';
import '../../../data_transfer/data/file_save/file_save.dart';
import '../../../data_transfer/data/json_file_picker.dart';
import '../../../entries/presentation/bloc/entries_list_cubit.dart';
import '../../../tags/presentation/bloc/tags_cubit.dart';
import '../bloc/theme_cubit.dart';
import '../widgets/about_dialog.dart';

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
          BlocBuilder<ThemeCubit, ThemeMode>(
            builder: (context, themeMode) => ListTile(
              leading: const Icon(Icons.brightness_6_outlined),
              title: const Text('Theme'),
              subtitle: Text(_themeModeLabel(themeMode)),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _showThemeSelector(context),
            ),
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
            title: const Text('What is a Common Place Book'),
            onTap: () => showAboutCommonPlaceBookDialog(context),
          ),
          ListTile(
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Your data & privacy'),
            subtitle: const Text('You own it, export it, we never see it'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => context.pushNamed('privacy'),
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

  /// Human-readable label for a [ThemeMode], shown both as the Theme tile
  /// subtitle and as the selector option titles.
  static String _themeModeLabel(ThemeMode mode) {
    switch (mode) {
      case ThemeMode.system:
        return 'System default';
      case ThemeMode.light:
        return 'Light';
      case ThemeMode.dark:
        return 'Dark';
    }
  }

  void _showThemeSelector(BuildContext context) {
    final themeCubit = context.read<ThemeCubit>();
    final current = themeCubit.state;

    Widget option(IconData icon, ThemeMode mode) => ListTile(
          leading: Icon(icon),
          title: Text(_themeModeLabel(mode)),
          trailing: mode == current ? const Icon(Icons.check) : null,
          onTap: () {
            themeCubit.setThemeMode(mode);
            Navigator.pop(context);
          },
        );

    showModalBottomSheet<void>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            option(Icons.brightness_auto, ThemeMode.system),
            option(Icons.light_mode, ThemeMode.light),
            option(Icons.dark_mode, ThemeMode.dark),
          ],
        ),
      ),
    );
  }
}
