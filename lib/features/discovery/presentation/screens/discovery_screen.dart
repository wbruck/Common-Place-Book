import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/entry_card.dart';
import '../../../../shared/widgets/error_display.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../entries/data/repositories/entry_repository.dart';
import '../../../tags/presentation/bloc/tags_cubit.dart';
import '../bloc/discovery_cubit.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({super.key});

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  late final DiscoveryCubit _discoveryCubit;
  String? _selectedTagId;

  @override
  void initState() {
    super.initState();
    _discoveryCubit = DiscoveryCubit(
      entryRepository: context.read<EntryRepository>(),
    )..loadRandomEntry();
  }

  @override
  void dispose() {
    _discoveryCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {

    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
      ),
      body: Column(
        children: [
          // Tag filter
          _buildTagFilter(context),

          // Main content
          Expanded(
            child: BlocBuilder<DiscoveryCubit, DiscoveryState>(
              bloc: _discoveryCubit,
              builder: (context, state) {
                if (state is DiscoveryLoading) {
                  return const LoadingIndicator(message: 'Finding wisdom...');
                }

                if (state is DiscoveryError) {
                  return ErrorDisplay(
                    message: state.message,
                    onRetry: () => _discoveryCubit.loadRandomEntry(),
                  );
                }

                if (state is DiscoveryEmpty) {
                  return EmptyState(
                    icon: Icons.auto_stories_outlined,
                    title: 'No entries to discover',
                    subtitle: _selectedTagId != null
                        ? 'No entries with this tag'
                        : 'Add some entries first',
                    actionLabel: 'Add entry',
                    onAction: () => context.push('/entry/new'),
                  );
                }

                if (state is DiscoveryLoaded) {
                  return _buildDiscoveryContent(context, state);
                }

                return const SizedBox.shrink();
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTagFilter(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      padding: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: theme.colorScheme.surface,
        border: Border(
          bottom: BorderSide(
            color: theme.colorScheme.outline.withValues(alpha: 0.1),
          ),
        ),
      ),
      child: BlocBuilder<TagsCubit, TagsState>(
        builder: (context, state) {
          if (state is! TagsLoaded) {
            return const SizedBox(height: 40);
          }

          final tags = state.tagsWithCounts
              .where((t) => t.entryCount > 0)
              .map((t) => t.tag)
              .toList();

          if (tags.isEmpty) {
            return const SizedBox(height: 40);
          }

          return SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Row(
              children: [
                FilterChip(
                  label: const Text('All'),
                  selected: _selectedTagId == null,
                  onSelected: (_) {
                    setState(() => _selectedTagId = null);
                    _discoveryCubit.clearFilter();
                  },
                ),
                const SizedBox(width: 8),
                ...tags.map((tag) {
                  final isSelected = _selectedTagId == tag.id;
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TagChip(
                      tag: tag,
                      selected: isSelected,
                      onTap: () {
                        setState(() => _selectedTagId = isSelected ? null : tag.id);
                        if (isSelected) {
                          _discoveryCubit.clearFilter();
                        } else {
                          _discoveryCubit.setTagFilter(tag.id);
                        }
                      },
                    ),
                  );
                }),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildDiscoveryContent(BuildContext context, DiscoveryLoaded state) {
    final theme = Theme.of(context);

    return GestureDetector(
      onHorizontalDragEnd: (details) {
        if (details.primaryVelocity != null && details.primaryVelocity!.abs() > 300) {
          _discoveryCubit.shuffle();
        }
      },
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            // Main entry card
            LargeEntryCard(
              entry: state.entry,
              onTap: () => context.push('/entry/${state.entry.id}'),
              onShuffle: () => _discoveryCubit.shuffle(),
            ),

            // Swipe hint
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.swipe,
                    size: 16,
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Swipe or tap shuffle for more',
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.4),
                    ),
                  ),
                ],
              ),
            ),

            // Related entries
            if (state.relatedEntries.isNotEmpty) ...[
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: Text(
                  'Related',
                  style: theme.textTheme.titleMedium,
                ),
              ),
              const SizedBox(height: 12),
              ...state.relatedEntries.map(
                (entry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EntryCard(
                    entry: entry,
                    compact: true,
                    onTap: () => _discoveryCubit.showEntry(entry),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
