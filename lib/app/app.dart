import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../core/database/database_provider.dart';
import '../features/entries/data/repositories/local_entry_repository.dart';
import '../features/entries/presentation/bloc/entries_list_cubit.dart';
import '../features/tags/data/repositories/local_tag_repository.dart';
import '../features/tags/presentation/bloc/tags_cubit.dart';
import 'router.dart';
import 'theme/app_theme.dart';

class CommonPlaceBookApp extends StatelessWidget {
  const CommonPlaceBookApp({super.key});

  @override
  Widget build(BuildContext context) {
    final database = DatabaseProvider.instance;

    return MultiRepositoryProvider(
      providers: [
        RepositoryProvider(
          create: (_) => LocalEntryRepository(database: database),
        ),
        RepositoryProvider(
          create: (_) => LocalTagRepository(database: database),
        ),
      ],
      child: MultiBlocProvider(
        providers: [
          BlocProvider(
            create: (context) => EntriesListCubit(
              entryRepository: context.read<LocalEntryRepository>(),
            )..loadEntries(),
          ),
          BlocProvider(
            create: (context) => TagsCubit(
              tagRepository: context.read<LocalTagRepository>(),
            )..loadTags(),
          ),
        ],
        child: MaterialApp.router(
          title: 'Common Place Book',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light,
          darkTheme: AppTheme.dark,
          themeMode: ThemeMode.system,
          routerConfig: appRouter,
        ),
      ),
    );
  }
}
