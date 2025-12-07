import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../shared/widgets/entry_card.dart';
import '../../../../shared/widgets/error_display.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../data/repositories/local_entry_repository.dart';
import '../bloc/entries_list_cubit.dart';
import '../bloc/entry_detail_cubit.dart';

class EntryDetailScreen extends StatefulWidget {
  final String entryId;

  const EntryDetailScreen({
    super.key,
    required this.entryId,
  });

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late final EntryDetailCubit _detailCubit;

  @override
  void initState() {
    super.initState();
    _detailCubit = EntryDetailCubit(
      entryRepository: context.read<LocalEntryRepository>(),
      entryId: widget.entryId,
    )..loadEntry();
  }

  @override
  void dispose() {
    _detailCubit.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMMd();

    return BlocConsumer<EntryDetailCubit, EntryDetailState>(
      bloc: _detailCubit,
      listener: (context, state) {
        if (state is EntryDetailNotFound) {
          // Entry was deleted, go back
          context.read<EntriesListCubit>().refresh();
          context.pop();
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            actions: [
              if (state is EntryDetailLoaded) ...[
                IconButton(
                  icon: Icon(
                    state.entry.isFavorite ? Icons.star : Icons.star_border,
                    color: state.entry.isFavorite
                        ? theme.colorScheme.secondary
                        : null,
                  ),
                  onPressed: () => _detailCubit.toggleFavorite(),
                ),
                PopupMenuButton<String>(
                  onSelected: (value) => _handleMenuAction(context, value),
                  itemBuilder: (context) => [
                    const PopupMenuItem(
                      value: 'edit',
                      child: ListTile(
                        leading: Icon(Icons.edit_outlined),
                        title: Text('Edit'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'copy',
                      child: ListTile(
                        leading: Icon(Icons.copy_outlined),
                        title: Text('Copy'),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                    const PopupMenuItem(
                      value: 'delete',
                      child: ListTile(
                        leading: Icon(Icons.delete_outline, color: Colors.red),
                        title: Text('Delete', style: TextStyle(color: Colors.red)),
                        contentPadding: EdgeInsets.zero,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
          body: _buildBody(context, state, theme, dateFormat),
        );
      },
    );
  }

  Widget _buildBody(
    BuildContext context,
    EntryDetailState state,
    ThemeData theme,
    DateFormat dateFormat,
  ) {
    if (state is EntryDetailLoading) {
      return const LoadingIndicator();
    }

    if (state is EntryDetailError) {
      return ErrorDisplay(
        message: state.message,
        onRetry: () => _detailCubit.loadEntry(),
      );
    }

    if (state is EntryDetailNotFound) {
      return const Center(child: Text('Entry not found'));
    }

    if (state is EntryDetailLoaded) {
      final entry = state.entry;

      return SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Quote icon
            Center(
              child: Icon(
                Icons.format_quote,
                size: 40,
                color: theme.colorScheme.secondary.withOpacity(0.4),
              ),
            ),
            const SizedBox(height: 24),

            // Content
            Text(
              entry.content,
              style: GoogleFonts.lora(
                fontSize: 22,
                height: 1.6,
                fontStyle: FontStyle.italic,
                color: theme.colorScheme.onSurface,
              ),
              textAlign: TextAlign.center,
            ),

            // Source
            if (entry.source != null && entry.source!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '— ${entry.source}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                  ),
                ),
              ),
            ],

            // Tags
            if (entry.tags.isNotEmpty) ...[
              const SizedBox(height: 32),
              Center(
                child: Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children: entry.tags.map((tag) => TagChip(tag: tag)).toList(),
                ),
              ),
            ],

            // Metadata
            const SizedBox(height: 32),
            const Divider(),
            const SizedBox(height: 16),

            _buildMetadataRow(
              context,
              icon: Icons.calendar_today_outlined,
              label: 'Added',
              value: dateFormat.format(entry.createdAt),
            ),
            const SizedBox(height: 8),
            _buildMetadataRow(
              context,
              icon: Icons.visibility_outlined,
              label: 'Viewed',
              value: '${entry.viewCount} ${entry.viewCount == 1 ? 'time' : 'times'}',
            ),
            if (entry.lastViewedAt != null) ...[
              const SizedBox(height: 8),
              _buildMetadataRow(
                context,
                icon: Icons.access_time_outlined,
                label: 'Last viewed',
                value: dateFormat.format(entry.lastViewedAt!),
              ),
            ],

            // Related entries
            if (state.relatedEntries.isNotEmpty) ...[
              const SizedBox(height: 32),
              const Divider(),
              const SizedBox(height: 16),
              Text(
                'Related Entries',
                style: theme.textTheme.titleMedium,
              ),
              const SizedBox(height: 12),
              ...state.relatedEntries.map(
                (relatedEntry) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: EntryCard(
                    entry: relatedEntry,
                    compact: true,
                    onTap: () => context.push('/entry/${relatedEntry.id}'),
                  ),
                ),
              ),
            ],
          ],
        ),
      );
    }

    return const SizedBox.shrink();
  }

  Widget _buildMetadataRow(
    BuildContext context, {
    required IconData icon,
    required String label,
    required String value,
  }) {
    final theme = Theme.of(context);

    return Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withOpacity(0.5),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.5),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  void _handleMenuAction(BuildContext context, String action) {
    switch (action) {
      case 'edit':
        context.push('/entry/${widget.entryId}/edit');
      case 'copy':
        _copyToClipboard(context);
      case 'delete':
        _confirmDelete(context);
    }
  }

  void _copyToClipboard(BuildContext context) {
    final state = _detailCubit.state;
    if (state is! EntryDetailLoaded) return;

    final entry = state.entry;
    var text = entry.content;
    if (entry.source != null && entry.source!.isNotEmpty) {
      text += '\n— ${entry.source}';
    }

    Clipboard.setData(ClipboardData(text: text));

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Copied to clipboard'),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _confirmDelete(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete entry?'),
        content: const Text(
          'This action cannot be undone. Are you sure you want to delete this entry?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Theme.of(context).colorScheme.error,
            ),
            onPressed: () {
              Navigator.of(context).pop();
              _detailCubit.deleteEntry();
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
