import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/entry_card.dart';
import '../../../../shared/widgets/error_display.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../discovery/presentation/bloc/discovery_cubit.dart';
import '../../../scanner/data/scan_image_picker.dart';
import '../../../scanner/data/text_recognition_service_factory.dart';
import '../../../tags/presentation/bloc/tags_cubit.dart';
import '../../data/repositories/entry_repository.dart';
import '../../domain/entities/entry_entity.dart';
import '../bloc/entries_list_cubit.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  late final DiscoveryCubit _discoveryCubit;
  bool _initialized = false;

  /// Scan entry points only exist on platforms where on-device recognition
  /// can actually run; see [isScanSupported].
  final bool _scanSupported = isScanSupported;

  @override
  void initState() {
    super.initState();
    _discoveryCubit = DiscoveryCubit(
      entryRepository: context.read<EntryRepository>(),
    );
    _resumeLostScan();
  }

  /// Resumes a scan whose photo Android recovered after the OS killed the
  /// app while the camera was open (image_picker's lost-data contract): the
  /// app cold-starts here at home, so this is where the captured photo must
  /// be picked back up instead of silently discarded. No-op everywhere else.
  Future<void> _resumeLostScan() async {
    if (!_scanSupported) return;
    final image = await retrieveLostScanImage();
    if (image == null || !mounted) return;
    unawaited(context.push('/scan', extra: image));
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_initialized) {
      _initialized = true;
      final entriesCubit = context.read<EntriesListCubit>();
      final tagsCubit = context.read<TagsCubit>();
      // Load data after the widget tree is built and database is ready
      Future.microtask(() {
        entriesCubit.loadEntries();
        tagsCubit.loadTags();
        _discoveryCubit.loadRandomEntry();
      });
    }
  }

  @override
  void dispose() {
    _discoveryCubit.close();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_getGreeting()),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearch(context),
          ),
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert),
            onSelected: (value) {
              switch (value) {
                case 'timeline':
                  // The Timeline is the Discover feed centered on today.
                  final uri = Uri(
                    path: '/discover',
                    queryParameters: {
                      'date': DateTime.now().millisecondsSinceEpoch.toString(),
                    },
                  );
                  context.push(uri.toString());
                case 'import_photo':
                  context.push('/scan?source=gallery');
                case 'tags':
                  context.push('/tags');
                case 'settings':
                  context.push('/settings');
              }
            },
            itemBuilder: (context) => [
              if (_scanSupported)
                const PopupMenuItem(
                  value: 'import_photo',
                  child: ListTile(
                    leading: Icon(Icons.image_search_outlined),
                    title: Text('Import from Photo'),
                    contentPadding: EdgeInsets.zero,
                  ),
                ),
              const PopupMenuItem(
                value: 'timeline',
                child: ListTile(
                  leading: Icon(Icons.timeline_outlined),
                  title: Text('Timeline'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'tags',
                child: ListTile(
                  leading: Icon(Icons.label_outline),
                  title: Text('Manage Tags'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
              const PopupMenuItem(
                value: 'settings',
                child: ListTile(
                  leading: Icon(Icons.settings_outlined),
                  title: Text('Settings'),
                  contentPadding: EdgeInsets.zero,
                ),
              ),
            ],
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          await Future.wait([
            context.read<EntriesListCubit>().refresh(),
            _discoveryCubit.loadRandomEntry(),
          ]);
        },
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.only(bottom: 100),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Today's Wisdom Section
              _buildTodaysWisdom(context),

              const SizedBox(height: 24),

              // Recent Entries Section
              _buildRecentEntries(context),

              const SizedBox(height: 24),

              // By Topic Section
              _buildByTopic(context),
            ],
          ),
        ),
      ),
      floatingActionButton: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (_scanSupported) ...[
            FloatingActionButton.small(
              heroTag: 'scan-text',
              tooltip: 'Scan text with the camera',
              onPressed: () => context.push('/scan'),
              child: const Icon(Icons.document_scanner_outlined),
            ),
            const SizedBox(height: 12),
          ],
          FloatingActionButton.extended(
            heroTag: 'new-entry',
            onPressed: () => context.push('/entry/new'),
            icon: const Icon(Icons.add),
            label: const Text('New Entry'),
          ),
        ],
      ),
    );
  }

  /// Opens the Timeline (Discover feed) centered on the day the given
  /// [entry] was created, so "Discover more" continues from the card in view.
  void _openTimelineForEntry(BuildContext context, EntryEntity entry) {
    final uri = Uri(
      path: '/discover',
      queryParameters: {
        'date': entry.createdAt.millisecondsSinceEpoch.toString(),
      },
    );
    context.push(uri.toString());
  }

  Widget _buildTodaysWisdom(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 0),
      child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
        bloc: _discoveryCubit,
        builder: (context, state) {
          final loadedEntry = state is DiscoveryLoaded ? state.entry : null;

          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Flexible(
                    child: Text(
                      "Today's Wisdom",
                      style: theme.textTheme.titleMedium,
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton.tonalIcon(
                    onPressed: loadedEntry == null
                        ? null
                        : () => _openTimelineForEntry(context, loadedEntry),
                    icon: const Icon(Icons.explore_outlined, size: 18),
                    label: const Text('Discover more'),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              if (state is DiscoveryLoading)
                const SizedBox(
                  height: 200,
                  child: LoadingIndicator(),
                )
              else if (loadedEntry != null)
                LargeEntryCard(
                  entry: loadedEntry,
                  onTap: () => context.push('/entry/${loadedEntry.id}'),
                  onShuffle: () => _discoveryCubit.shuffle(),
                )
              else if (state is DiscoveryEmpty)
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      children: [
                        Icon(
                          Icons.lightbulb_outline,
                          size: 48,
                          color: theme.colorScheme.secondary.withValues(alpha: 0.5),
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'Add your first entry to see wisdom here',
                          style: theme.textTheme.bodyMedium?.copyWith(
                            color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ),
                )
              else
                const SizedBox.shrink(),
            ],
          );
        },
      ),
    );
  }

  Widget _buildRecentEntries(BuildContext context) {
    final theme = Theme.of(context);

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Text(
            'Recent Entries',
            style: theme.textTheme.titleMedium,
          ),
        ),
        const SizedBox(height: 12),
        BlocBuilder<EntriesListCubit, EntriesListState>(
          builder: (context, state) {
            if (state is EntriesListLoading) {
              return const SizedBox(
                height: 150,
                child: LoadingIndicator(),
              );
            }

            if (state is EntriesListError) {
              return SizedBox(
                height: 150,
                child: ErrorDisplay(
                  message: state.message,
                  onRetry: () => context.read<EntriesListCubit>().loadEntries(),
                ),
              );
            }

            if (state is EntriesListEmpty) {
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: EmptyState.noEntries(
                  onAddEntry: () => context.push('/entry/new'),
                ),
              );
            }

            if (state is EntriesListLoaded) {
              final entries = state.entries.take(5).toList();

              return SizedBox(
                height: 180,
                child: ListView.separated(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  itemCount: entries.length,
                  separatorBuilder: (_, __) => const SizedBox(width: 12),
                  itemBuilder: (context, index) {
                    final entry = entries[index];
                    return SizedBox(
                      width: 280,
                      child: EntryCard(
                        entry: entry,
                        compact: true,
                        onTap: () => context.push('/entry/${entry.id}'),
                      ),
                    );
                  },
                ),
              );
            }

            return const SizedBox.shrink();
          },
        ),
      ],
    );
  }

  Widget _buildByTopic(BuildContext context) {
    final theme = Theme.of(context);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'By Topic',
                style: theme.textTheme.titleMedium,
              ),
              TextButton(
                onPressed: () => context.push('/tags'),
                child: const Text('See all'),
              ),
            ],
          ),
          const SizedBox(height: 12),
          BlocBuilder<TagsCubit, TagsState>(
            builder: (context, state) {
              if (state is TagsLoading) {
                return const SizedBox(
                  height: 100,
                  child: LoadingIndicator(),
                );
              }

              if (state is TagsLoaded) {
                final tagsWithCounts = state.tagsWithCounts
                    .where((t) => t.entryCount > 0)
                    .take(6)
                    .toList();

                if (tagsWithCounts.isEmpty) {
                  return Card(
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Text(
                        'Tags will appear here once you add entries with tags',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                        ),
                      ),
                    ),
                  );
                }

                return Card(
                  child: Column(
                    children: tagsWithCounts.map((tagWithCount) {
                      return ListTile(
                        leading: Icon(
                          Icons.label_outline,
                          color: theme.colorScheme.secondary,
                        ),
                        title: Text(tagWithCount.tag.name),
                        trailing: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${tagWithCount.entryCount}',
                            style: theme.textTheme.labelMedium,
                          ),
                        ),
                        onTap: () {
                          context
                              .read<EntriesListCubit>()
                              .filterByTag(tagWithCount.tag.id);
                          // Could navigate to a filtered view
                        },
                      );
                    }).toList(),
                  ),
                );
              }

              return const SizedBox.shrink();
            },
          ),
        ],
      ),
    );
  }

  void _showSearch(BuildContext context) {
    showSearch(
      context: context,
      delegate: EntrySearchDelegate(
        entryRepository: context.read<EntryRepository>(),
      ),
    );
  }
}

class EntrySearchDelegate extends SearchDelegate<EntryEntity?> {

  EntrySearchDelegate({required this.entryRepository});
  final EntryRepository entryRepository;

  @override
  String get searchFieldLabel => 'Search entries...';

  @override
  List<Widget> buildActions(BuildContext context) {
    return [
      if (query.isNotEmpty)
        IconButton(
          icon: const Icon(Icons.clear),
          onPressed: () => query = '',
        ),
    ];
  }

  @override
  Widget buildLeading(BuildContext context) {
    return IconButton(
      icon: const Icon(Icons.arrow_back),
      onPressed: () => close(context, null),
    );
  }

  @override
  Widget buildResults(BuildContext context) {
    return _buildSearchResults(context);
  }

  @override
  Widget buildSuggestions(BuildContext context) {
    if (query.isEmpty) {
      return Center(
        child: Text(
          'Search your wisdom...',
          style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.5),
              ),
        ),
      );
    }
    return _buildSearchResults(context);
  }

  Widget _buildSearchResults(BuildContext context) {
    return FutureBuilder<List<EntryEntity>>(
      future: entryRepository.searchEntries(query),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const LoadingIndicator();
        }

        if (snapshot.hasError) {
          return ErrorDisplay(message: snapshot.error.toString());
        }

        final entries = snapshot.data ?? [];

        if (entries.isEmpty) {
          return EmptyState.noResults(query: query);
        }

        return ListView.builder(
          padding: const EdgeInsets.all(16),
          itemCount: entries.length,
          itemBuilder: (context, index) {
            final entry = entries[index];
            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: EntryCard(
                entry: entry,
                onTap: () {
                  close(context, entry);
                  context.push('/entry/${entry.id}');
                },
              ),
            );
          },
        );
      },
    );
  }
}
