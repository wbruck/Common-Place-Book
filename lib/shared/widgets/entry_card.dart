import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';

import '../../features/entries/domain/entities/entry_entity.dart';
import 'tag_chip.dart';

class EntryCard extends StatelessWidget {

  const EntryCard({
    required this.entry, super.key,
    this.onTap,
    this.showTags = true,
    this.compact = false,
  });
  final EntryEntity entry;
  final VoidCallback? onTap;
  final bool showTags;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final dateFormat = DateFormat.yMMMd();

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.all(compact ? 12 : 16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // Content
              Text(
                entry.content,
                style: compact
                    ? theme.textTheme.bodyMedium
                    : GoogleFonts.lora(
                        fontSize: 16,
                        height: 1.5,
                        fontStyle: FontStyle.italic,
                        color: theme.colorScheme.onSurface,
                      ),
                maxLines: compact ? 3 : 5,
                overflow: TextOverflow.ellipsis,
              ),

              // Source
              if (entry.source != null && entry.source!.isNotEmpty) ...[
                SizedBox(height: compact ? 8 : 12),
                Text(
                  '— ${entry.source}',
                  style: theme.textTheme.bodySmall?.copyWith(
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],

              // Tags
              if (showTags && entry.tags.isNotEmpty) ...[
                SizedBox(height: compact ? 8 : 12),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: entry.tags
                      .take(3)
                      .map((tag) => TagChip(
                            tag: tag,
                            small: compact,
                          ),)
                      .toList(),
                ),
              ],

              // Metadata footer
              if (!compact) ...[
                const SizedBox(height: 12),
                Row(
                  children: [
                    Icon(
                      Icons.calendar_today_outlined,
                      size: 14,
                      color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                    ),
                    const SizedBox(width: 4),
                    Text(
                      dateFormat.format(entry.createdAt),
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withValues(alpha: 0.5),
                      ),
                    ),
                    if (entry.isFavorite) ...[
                      const Spacer(),
                      Icon(
                        Icons.star,
                        size: 16,
                        color: theme.colorScheme.secondary,
                      ),
                    ],
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

class LargeEntryCard extends StatelessWidget {

  const LargeEntryCard({
    required this.entry, super.key,
    this.onTap,
    this.onShuffle,
  });
  final EntryEntity entry;
  final VoidCallback? onTap;
  final VoidCallback? onShuffle;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Quote icon
              Icon(
                Icons.format_quote,
                size: 32,
                color: theme.colorScheme.secondary.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),

              // Content
              Text(
                entry.content,
                style: GoogleFonts.lora(
                  fontSize: 20,
                  height: 1.6,
                  fontStyle: FontStyle.italic,
                  color: theme.colorScheme.onSurface,
                ),
                textAlign: TextAlign.center,
              ),

              // Source
              if (entry.source != null && entry.source!.isNotEmpty) ...[
                const SizedBox(height: 16),
                Text(
                  '— ${entry.source}',
                  style: theme.textTheme.titleSmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.7),
                  ),
                  textAlign: TextAlign.center,
                ),
              ],

              // Tags
              if (entry.tags.isNotEmpty) ...[
                const SizedBox(height: 20),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  alignment: WrapAlignment.center,
                  children:
                      entry.tags.map((tag) => TagChip(tag: tag)).toList(),
                ),
              ],

              // Shuffle button
              if (onShuffle != null) ...[
                const SizedBox(height: 24),
                TextButton.icon(
                  onPressed: onShuffle,
                  icon: const Icon(Icons.shuffle),
                  label: const Text('Shuffle'),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
