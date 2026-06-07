import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/entry_card.dart';
import '../../../../shared/widgets/error_display.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../entries/data/repositories/entry_repository.dart';
import '../../../tags/presentation/bloc/tags_cubit.dart';
import '../bloc/discover_feed_cubit.dart';

class DiscoveryScreen extends StatefulWidget {
  const DiscoveryScreen({
    super.key,
    this.initialTagIds = const {},
    this.centerDate,
  });

  final Set<String> initialTagIds;
  final DateTime? centerDate;

  @override
  State<DiscoveryScreen> createState() => _DiscoveryScreenState();
}

class _DiscoveryScreenState extends State<DiscoveryScreen> {
  late final DiscoverFeedCubit _feedCubit;
  final ScrollController _scrollController = ScrollController();

  /// Per-day divider keys, rebuilt fresh on each list build so that
  /// [Scrollable.ensureVisible] can target the correct day group.
  final Map<DateTime, GlobalKey> _dayKeys = {};

  /// One-shot guard so the center-on-date scroll only fires once.
  bool _centered = false;

  @override
  void initState() {
    super.initState();
    _feedCubit = DiscoverFeedCubit(
      entryRepository: context.read<EntryRepository>(),
      initialTagIds: widget.initialTagIds,
    )..load();

    // Defensive: ensure tags are loaded for the filter chips on cold deep-links.
    if (context.read<TagsCubit>().state is! TagsLoaded) {
      context.read<TagsCubit>().loadTags();
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    _feedCubit.close();
    super.dispose();
  }

  DateTime _dayKeyFor(DateTime date) =>
      DateTime(date.year, date.month, date.day);

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Discover'),
      ),
      body: BlocConsumer<DiscoverFeedCubit, DiscoverFeedState>(
        bloc: _feedCubit,
        listener: (context, state) {
          if (state is DiscoverFeedLoaded &&
              widget.centerDate != null &&
              !_centered) {
            final targetDay = _dayKeyFor(widget.centerDate!);
            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              final key = _dayKeys[targetDay];
              final ctx = key?.currentContext;
              if (ctx != null) {
                Scrollable.ensureVisible(
                  ctx,
                  alignment: 0.5,
                  duration: const Duration(milliseconds: 400),
                  curve: Curves.easeInOut,
                );
                _centered = true;
              }
            });
          }
        },
        builder: (context, state) {
          return Column(
            children: [
              _buildTagFilter(context),
              Expanded(child: _buildBody(context, state)),
            ],
          );
        },
      ),
    );
  }

  Widget _buildTagFilter(BuildContext context) {
    final theme = Theme.of(context);
    final selectedTagIds = _feedCubit.selectedTagIds;

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
                  selected: selectedTagIds.isEmpty,
                  onSelected: (_) => _feedCubit.clearTags(),
                ),
                const SizedBox(width: 8),
                ...tags.map((tag) {
                  final isSelected = selectedTagIds.contains(tag.id);
                  return Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: TagChip(
                      tag: tag,
                      selected: isSelected,
                      onTap: () => _feedCubit.toggleTag(tag.id),
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

  Widget _buildBody(BuildContext context, DiscoverFeedState state) {
    if (state is DiscoverFeedLoading || state is DiscoverFeedInitial) {
      return const LoadingIndicator(message: 'Finding wisdom...');
    }

    if (state is DiscoverFeedError) {
      return ErrorDisplay(
        message: state.message,
        onRetry: () => _feedCubit.load(),
      );
    }

    if (state is DiscoverFeedEmpty) {
      return EmptyState(
        icon: Icons.auto_stories_outlined,
        title: 'No entries to discover',
        subtitle: state.selectedTagIds.isNotEmpty
            ? 'No entries match the selected tags'
            : 'Add some entries first',
        actionLabel: 'Add entry',
        onAction: () => context.push('/entry/new'),
      );
    }

    if (state is DiscoverFeedLoaded) {
      return _buildFeed(context, state);
    }

    return const SizedBox.shrink();
  }

  Widget _buildFeed(BuildContext context, DiscoverFeedLoaded state) {
    // Rebuild the day-key map fresh on each build so that off-screen day
    // headers can be located by GlobalKey for the center-on-date scroll.
    _dayKeys.clear();

    final children = <Widget>[];
    DateTime? currentDay;

    for (final entry in state.entries) {
      final day = _dayKeyFor(entry.createdAt);
      if (currentDay == null || day != currentDay) {
        currentDay = day;
        final key = _dayKeys.putIfAbsent(day, GlobalKey.new);
        children.add(_DateDivider(key: key, day: day));
      }
      children.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: EntryCard(
            entry: entry,
            onTap: () => context.push('/entry/${entry.id}'),
          ),
        ),
      );
    }

    // Use a non-lazy list so every day divider exists in the tree and can be
    // scrolled to via Scrollable.ensureVisible for the center-on-date feature.
    return SingleChildScrollView(
      controller: _scrollController,
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: children,
      ),
    );
  }
}

class _DateDivider extends StatelessWidget {
  const _DateDivider({required this.day, super.key});

  final DateTime day;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final label = DateFormat.yMMMMd().format(day);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          const Expanded(child: Divider()),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            child: Text(
              label,
              style: theme.textTheme.labelMedium?.copyWith(
                color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
              ),
            ),
          ),
          const Expanded(child: Divider()),
        ],
      ),
    );
  }
}
