import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/auth/auth_service.dart';
import '../core/database/database_provider.dart';
import '../features/entries/data/repositories/entry_repository.dart';
import '../features/entries/data/repositories/local_entry_repository.dart';
import '../features/entries/presentation/bloc/entries_list_cubit.dart';
import '../features/tags/data/repositories/local_tag_repository.dart';
import '../features/tags/data/repositories/tag_repository.dart';
import '../features/tags/presentation/bloc/tags_cubit.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CommonPlaceBookApp extends StatelessWidget {
  /// [authService] is injectable so widget tests can supply a fake-backed
  /// service without `Supabase.initialize`. In production it is omitted and
  /// built from the live Supabase client (or a local-only fallback) here, so
  /// the app boots and stays usable logged out even with no auth backend.
  const CommonPlaceBookApp({super.key, AuthService? authService})
      : _injectedAuthService = authService;

  final AuthService? _injectedAuthService;

  @override
  Widget build(BuildContext context) {
    final database = DatabaseProvider.instance;

    // Create concrete implementations
    final entryRepository = LocalEntryRepository(database: database);
    final tagRepository = LocalTagRepository(database: database);
    final authService = _injectedAuthService ?? AuthService.fromSupabase();

    return MultiRepositoryProvider(
      providers: [
        // Provide as abstract types for dependency inversion
        RepositoryProvider<EntryRepository>(
          create: (_) => entryRepository,
        ),
        RepositoryProvider<TagRepository>(
          create: (_) => tagRepository,
        ),
        // App-level so Settings and the login screen read a single instance.
        RepositoryProvider<AuthService>(
          create: (_) => authService,
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
        ],
        child: MaterialApp.router(
          title: 'Common Place Book',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
