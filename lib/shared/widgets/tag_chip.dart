import 'package:flutter/material.dart';

import '../../app/theme/colors.dart';
import '../../features/entries/domain/entities/entry_entity.dart';

class TagChip extends StatelessWidget {

  const TagChip({
    required this.tag, super.key,
    this.selected = false,
    this.small = false,
    this.onTap,
    this.onDeleted,
  });
  final TagEntity tag;
  final bool selected;
  final bool small;
  final VoidCallback? onTap;
  final VoidCallback? onDeleted;

  Color _getTagColor() {
    if (tag.color != null) {
      try {
        return Color(int.parse(tag.color!.replaceFirst('#', '0xFF')));
      } on Object catch (_) {
        // Fall through to default color
      }
    }
    // Use hash of tag name to get consistent color
    final index = tag.name.hashCode.abs() % AppColors.tagColors.length;
    return AppColors.tagColors[index];
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final tagColor = _getTagColor();

    if (small) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
        decoration: BoxDecoration(
          color: tagColor.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(4),
        ),
        child: Text(
          tag.name,
          style: theme.textTheme.labelSmall?.copyWith(
            color: tagColor,
            fontWeight: FontWeight.w500,
          ),
        ),
      );
    }

    return FilterChip(
      label: Text(tag.name),
      selected: selected,
      onSelected: onTap != null ? (_) => onTap!() : null,
      onDeleted: onDeleted,
      backgroundColor: tagColor.withValues(alpha: 0.1),
      selectedColor: tagColor.withValues(alpha: 0.25),
      labelStyle: TextStyle(
        color: selected ? tagColor : tagColor.withValues(alpha: 0.9),
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
        fontSize: 13,
      ),
      side: BorderSide.none,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(8),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 4),
      visualDensity: VisualDensity.compact,
    );
  }
}

class TagSelector extends StatelessWidget {

  const TagSelector({
    required this.availableTags, required this.selectedTagIds, required this.onTagSelected, required this.onTagDeselected, super.key,
    this.onCreateTag,
    this.loading = false,
  });
  final List<TagEntity> availableTags;
  final List<String> selectedTagIds;
  final ValueChanged<String> onTagSelected;
  final ValueChanged<String> onTagDeselected;
  final VoidCallback? onCreateTag;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    if (loading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: [
        ...availableTags.map((tag) {
          final isSelected = selectedTagIds.contains(tag.id);
          return TagChip(
            tag: tag,
            selected: isSelected,
            onTap: () {
              if (isSelected) {
                onTagDeselected(tag.id);
              } else {
                onTagSelected(tag.id);
              }
            },
          );
        }),
        if (onCreateTag != null)
          ActionChip(
            avatar: const Icon(Icons.add, size: 18),
            label: const Text('New tag'),
            onPressed: onCreateTag,
            backgroundColor: theme.colorScheme.surface,
            side: BorderSide(
              color: theme.colorScheme.outline.withValues(alpha: 0.3),
            ),
          ),
      ],
    );
  }
}
