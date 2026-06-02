import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/app_info.dart';
import '../core/database/database_provider.dart';
import '../features/data_transfer/data/data_transfer_service.dart';
import '../features/data_transfer/data/local_backup_repository.dart';
import '../features/data_transfer/domain/backup_repository.dart';
import '../features/entries/data/repositories/entry_repository.dart';
import '../features/entries/data/repositories/local_entry_repository.dart';
import '../features/entries/presentation/bloc/entries_list_cubit.dart';
import '../features/settings/domain/settings_repository.dart';
import '../features/settings/presentation/bloc/theme_cubit.dart';
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
    super.key,
  });

  final AppInfo appInfo;
  final SettingsRepository settingsRepository;
  final ThemeMode initialThemeMode;

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
          ),
        ),
      ),
    );
  }
}
