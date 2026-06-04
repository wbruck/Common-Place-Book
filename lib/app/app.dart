import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/app_info.dart';
import '../core/database/database_provider.dart';
import '../core/utils/app_logger.dart';
import '../features/data_transfer/data/data_transfer_service.dart';
import '../features/data_transfer/data/local_backup_repository.dart';
import '../features/data_transfer/domain/backup_repository.dart';
import '../features/entries/data/repositories/entry_repository.dart';
import '../features/entries/data/repositories/local_entry_repository.dart';
import '../features/entries/presentation/bloc/entries_list_cubit.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/settings/presentation/bloc/theme_cubit.dart';
import '../features/settings/presentation/widgets/about_dialog.dart';
import '../features/tags/data/repositories/local_tag_repository.dart';
import '../features/tags/data/repositories/tag_repository.dart';
import '../features/tags/presentation/bloc/tags_cubit.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CommonPlaceBookApp extends StatelessWidget {
  const CommonPlaceBookApp({
    required this.appInfo,
    required this.settingsRepository,
    this.initialThemeMode = ThemeMode.system,
    this.showIntroOnLaunch = false,
    super.key,
  });

  final AppInfo appInfo;
  final SettingsRepository settingsRepository;
  final ThemeMode initialThemeMode;

  /// When true, the one-time welcome dialog is shown after the first frame.
  /// Resolved in `main` from [SettingsRepository.hasSeenIntro] so a returning
  /// user never sees it again.
  final bool showIntroOnLaunch;

  @override
  Widget build(BuildContext context) {
    final database = DatabaseProvider.instance;

    // Create concrete implementations
    final entryRepository = LocalEntryRepository(database: database);
    final tagRepository = LocalTagRepository(database: database);

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider<AppInfo>(
          create: (_) => appInfo,
        ),
        // Provide as abstract types for dependency inversion
        RepositoryProvider<EntryRepository>(
          create: (_) => entryRepository,
        ),
        RepositoryProvider<TagRepository>(
          create: (_) => tagRepository,
        ),
        RepositoryProvider<BackupRepository>(
          create: (_) => LocalBackupRepository(database),
        ),
        RepositoryProvider<DataTransferService>(
          create: (context) => DataTransferService(
            context.read<BackupRepository>(),
            appVersion: appInfo.version,
          ),
        ),
        // Provided as the abstract type for dependency inversion.
        RepositoryProvider<SettingsRepository>(
          create: (_) => settingsRepository,
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => EntriesListCubit(
              entryRepository: context.read<EntryRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => TagsCubit(
              tagRepository: context.read<TagRepository>(),
            ),
          ),
          BlocProvider(
            create: (context) => ThemeCubit(
              settingsRepository: context.read<SettingsRepository>(),
              initialMode: initialThemeMode,
            ),
          ),
        ],
        child: BlocBuilder<ThemeCubit, ThemeMode>(
          builder: (context, themeMode) => MaterialApp.router(
            title: 'Common Place Book',
            debugShowCheckedModeBanner: false,
            theme: AppTheme.light,
            darkTheme: AppTheme.dark,
            themeMode: themeMode,
            routerConfig: appRouter,
            builder: (context, child) => _FirstRunIntroGate(
              enabled: showIntroOnLaunch,
              settingsRepository: settingsRepository,
              child: child ?? const SizedBox.shrink(),
            ),
          ),
        ),
      ),
    );
  }
}

/// Shows the [AboutCommonPlaceBookDialog] once, on a user's first visit.
///
/// Lives in `MaterialApp.router`'s `builder`, whose context sits *above* the
/// GoRouter navigator, so it reaches into the navigator via [rootNavigatorKey]
/// to present the dialog. The "seen" flag is persisted the moment the dialog is
/// presented, so the welcome appears exactly once.
class _FirstRunIntroGate extends StatefulWidget {
  const _FirstRunIntroGate({
    required this.enabled,
    required this.settingsRepository,
    required this.child,
  });

  final bool enabled;
  final SettingsRepository settingsRepository;
  final Widget child;

  @override
  State<_FirstRunIntroGate> createState() => _FirstRunIntroGateState();
}

class _FirstRunIntroGateState extends State<_FirstRunIntroGate> {
  @override
  void initState() {
    super.initState();
    if (widget.enabled) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _showIntro());
    }
  }

  void _showIntro() {
    // The router's navigator is built by the first frame; its context is what
    // `showDialog` needs to find a Navigator + Overlay.
    final navigatorContext = rootNavigatorKey.currentContext;
    if (navigatorContext == null) {
      // Nothing shown, flag not set: retry on the next launch rather than
      // silently consuming the one-time welcome.
      return;
    }
    unawaited(_markIntroSeen());
    unawaited(
      showAboutCommonPlaceBookDialog(
        navigatorContext,
        dismissLabel: 'Get started',
      ),
    );
  }

  Future<void> _markIntroSeen() async {
    try {
      await widget.settingsRepository.markIntroSeen();
    } on Object catch (error, stackTrace) {
      // A persistence failure only means the welcome may reappear next launch;
      // it must not crash startup.
      AppLogger.error(
        'Failed to persist intro-seen flag',
        tag: 'FirstRunIntroGate',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
