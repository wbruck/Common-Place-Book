import 'package:flutter/material.dart';

class EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? subtitle;
  final String? actionLabel;
  final VoidCallback? onAction;

  const EmptyState({
    super.key,
    required this.icon,
    required this.title,
    this.subtitle,
    this.actionLabel,
    this.onAction,
  });

  factory EmptyState.noEntries({VoidCallback? onAddEntry}) {
    return EmptyState(
      icon: Icons.auto_stories_outlined,
      title: 'No entries yet',
      subtitle: 'Start capturing your golden nuggets of wisdom',
      actionLabel: 'Add your first entry',
      onAction: onAddEntry,
    );
  }

  factory EmptyState.noResults({String? query}) {
    return EmptyState(
      icon: Icons.search_off_outlined,
      title: 'No results found',
      subtitle: query != null ? 'No entries match "$query"' : null,
    );
  }

  factory EmptyState.noTaggedEntries({required String tagName}) {
    return EmptyState(
      icon: Icons.label_off_outlined,
      title: 'No entries with this tag',
      subtitle: 'No entries are tagged with "$tagName"',
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 64,
              color: theme.colorScheme.onSurface.withOpacity(0.3),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: theme.textTheme.titleLarge?.copyWith(
                color: theme.colorScheme.onSurface.withOpacity(0.7),
              ),
              textAlign: TextAlign.center,
            ),
            if (subtitle != null) ...[
              const SizedBox(height: 8),
              Text(
                subtitle!,
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: theme.colorScheme.onSurface.withOpacity(0.5),
                ),
                textAlign: TextAlign.center,
              ),
            ],
            if (actionLabel != null && onAction != null) ...[
              const SizedBox(height: 24),
              FilledButton.icon(
                onPressed: onAction,
                icon: const Icon(Icons.add),
                label: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
