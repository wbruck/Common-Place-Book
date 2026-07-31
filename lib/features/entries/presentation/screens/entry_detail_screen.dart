import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../../../core/notifications/notification_service.dart';
import '../../../../shared/widgets/entry_card.dart';
import '../../../../shared/widgets/error_display.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../reminders/domain/entry_reminder_scheduler.dart';
import '../../data/repositories/entry_repository.dart';
import '../../domain/entities/entry_entity.dart';
import '../bloc/entries_list_cubit.dart';
import '../bloc/entry_detail_cubit.dart';

class EntryDetailScreen extends StatefulWidget {

  const EntryDetailScreen({
    required this.entryId, super.key,
  });
  final String entryId;

  @override
  State<EntryDetailScreen> createState() => _EntryDetailScreenState();
}

class _EntryDetailScreenState extends State<EntryDetailScreen> {
  late final EntryDetailCubit _detailCubit;

  @override
  void initState() {
    super.initState();
    final entryRepository = context.read<EntryRepository>();
    final notificationService = context.read<NotificationService>();
    _detailCubit = EntryDetailCubit(
      entryRepository: entryRepository,
      notificationService: notificationService,
      reminderScheduler: EntryReminderScheduler(
        entryRepository: entryRepository,
        notificationService: notificationService,
      ),
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
                if (_detailCubit.remindersSupported)
                  IconButton(
                    tooltip: state.entry.reminderAt != null
                        ? 'Edit reminder'
                        : 'Set reminder',
                    icon: Icon(
                      state.entry.reminderAt != null
                          ? Icons.notifications_active
                          : Icons.notifications_none,
                      color: state.entry.reminderAt != null
                          ? theme.colorScheme.secondary
                          : null,
                    ),
                    onPressed: () => _handleReminder(context, state.entry),
                  ),
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
                color: theme.colorScheme.secondary.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(height: 24),

            // Content — tap to copy the quote (and its source) to the clipboard.
            GestureDetector(
              onTap: () => _copyToClipboard(context),
              behavior: HitTestBehavior.opaque,
              child: Text(
                entry.content,
                style: GoogleFonts.lora(
                  fontSize: 22,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),
            ),

            // Source
            if (entry.source != null && entry.source!.isNotEmpty) ...[
              const SizedBox(height: 24),
              Center(
                child: Text(
                  '— ${entry.source}',
                  style: theme.textTheme.titleMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
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
              onTap: () => _openDiscoverForEntry(context, entry),
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
            if (entry.reminderAt != null) ...[
              const SizedBox(height: 8),
              _buildMetadataRow(
                context,
                icon: Icons.notifications_active_outlined,
                label: 'Reminder',
                value: DateFormat.yMMMMd().add_jm().format(entry.reminderAt!),
                onTap: () => _handleReminder(context, entry),
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
    VoidCallback? onTap,
  }) {
    final theme = Theme.of(context);

    final row = Row(
      children: [
        Icon(
          icon,
          size: 16,
          color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
        ),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
          ),
        ),
        Text(
          value,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
          ),
        ),
      ],
    );

    if (onTap == null) {
      return row;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(4),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: row,
      ),
    );
  }

  void _openDiscoverForEntry(BuildContext context, EntryEntity entry) {
    final created = entry.createdAt;
    final tagIds = entry.tags.map((t) => t.id).toList();
    final uri = Uri(
      path: '/discover',
      queryParameters: {
        'date': created.millisecondsSinceEpoch.toString(),
        if (tagIds.isNotEmpty) 'tags': tagIds.join(','),
      },
    );
    context.push(uri.toString());
  }

  Future<void> _handleReminder(BuildContext context, EntryEntity entry) async {
    if (entry.reminderAt == null) {
      await _pickAndSetReminder(context, initial: null);
      return;
    }

    final action = await showModalBottomSheet<_ReminderAction>(
      context: context,
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.edit_calendar_outlined),
              title: const Text('Change reminder'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ReminderAction.change),
            ),
            ListTile(
              leading: const Icon(Icons.notifications_off_outlined),
              title: const Text('Remove reminder'),
              onTap: () =>
                  Navigator.of(sheetContext).pop(_ReminderAction.remove),
            ),
          ],
        ),
      ),
    );

    if (!context.mounted || action == null) return;

    switch (action) {
      case _ReminderAction.change:
        await _pickAndSetReminder(context, initial: entry.reminderAt);
      case _ReminderAction.remove:
        await _detailCubit.clearReminder();
        if (!context.mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reminder removed'),
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Runs the date → time picker flow, then persists and schedules the reminder
  /// (or reports why it could not be set).
  Future<void> _pickAndSetReminder(
    BuildContext context, {
    required DateTime? initial,
  }) async {
    final messenger = ScaffoldMessenger.of(context);
    final dateTimeFormat = DateFormat.yMMMMd().add_jm();
    final now = DateTime.now();
    final base = (initial != null && initial.isAfter(now))
        ? initial
        : now.add(const Duration(hours: 1));

    final date = await showDatePicker(
      context: context,
      initialDate: base,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5, now.month, now.day),
      helpText: 'Reminder date',
    );
    if (date == null || !context.mounted) return;

    final time = await showTimePicker(
      context: context,
      initialTime: TimeOfDay.fromDateTime(base),
      helpText: 'Reminder time',
    );
    if (time == null || !mounted) return;

    final scheduledFor = DateTime(
      date.year,
      date.month,
      date.day,
      time.hour,
      time.minute,
    );

    if (!scheduledFor.isAfter(DateTime.now())) {
      messenger.showSnackBar(
        const SnackBar(
          content: Text('Pick a time in the future'),
          behavior: SnackBarBehavior.floating,
        ),
      );
      return;
    }

    final scheduled = await _detailCubit.setReminder(scheduledFor);
    if (!mounted) return;

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          scheduled
              ? 'Reminder set for ${dateTimeFormat.format(scheduledFor)}'
              : 'Enable notifications in system settings to set reminders',
        ),
        behavior: SnackBarBehavior.floating,
      ),
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
    showDialog<void>(
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

/// The choice offered when tapping an entry that already has a reminder.
enum _ReminderAction { change, remove }
