import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';

import '../../../../app/theme/colors.dart';
import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/error_display.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../bloc/tags_cubit.dart';

class TagsScreen extends StatelessWidget {
  const TagsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tags'),
      ),
      body: BlocBuilder<TagsCubit, TagsState>(
        builder: (context, state) {
          if (state is TagsLoading) {
            return const LoadingIndicator();
          }

          if (state is TagsError) {
            return ErrorDisplay(
              message: state.message,
              onRetry: () => context.read<TagsCubit>().loadTags(),
            );
          }

          if (state is TagsEmpty) {
            return const EmptyState(
              icon: Icons.label_outline,
              title: 'No tags yet',
              subtitle: 'Tags will appear here when you add them to entries',
            );
          }

          if (state is TagsLoaded) {
            return ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.tagsWithCounts.length,
              itemBuilder: (context, index) {
                final tagWithCount = state.tagsWithCounts[index];
                final tag = tagWithCount.tag;

                final tagColor = _getTagColor(tag.color, tag.name);

                return ListTile(
                  leading: Container(
                    width: 40,
                    height: 40,
                    decoration: BoxDecoration(
                      color: tagColor.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Icon(
                      Icons.label,
                      color: tagColor,
                    ),
                  ),
                  title: Text(tag.name),
                  subtitle: Text(
                    '${tagWithCount.entryCount} ${tagWithCount.entryCount == 1 ? 'entry' : 'entries'}',
                  ),
                  trailing: PopupMenuButton<String>(
                    onSelected: (value) => _handleMenuAction(
                      context,
                      value,
                      tag.id,
                      tag.name,
                    ),
                    itemBuilder: (context) => [
                      const PopupMenuItem(
                        value: 'rename',
                        child: ListTile(
                          leading: Icon(Icons.edit_outlined),
                          title: Text('Rename'),
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
                );
              },
            );
          }

          return const SizedBox.shrink();
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => _showCreateTagDialog(context),
        child: const Icon(Icons.add),
      ),
    );
  }

  Color _getTagColor(String? colorString, String tagName) {
    if (colorString != null) {
      try {
        return Color(int.parse(colorString.replaceFirst('#', '0xFF')));
      } catch (_) {
        // Fall through to default
      }
    }
    final index = tagName.hashCode.abs() % AppColors.tagColors.length;
    return AppColors.tagColors[index];
  }

  void _handleMenuAction(
    BuildContext context,
    String action,
    String tagId,
    String currentName,
  ) {
    switch (action) {
      case 'rename':
        _showRenameDialog(context, tagId, currentName);
      case 'delete':
        _showDeleteConfirmation(context, tagId, currentName);
    }
  }

  Future<void> _showCreateTagDialog(BuildContext context) async {
    final controller = TextEditingController();

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Create Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Tag name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Create'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty) {
      context.read<TagsCubit>().createTag(name: result.trim());
    }
  }

  Future<void> _showRenameDialog(
    BuildContext context,
    String tagId,
    String currentName,
  ) async {
    final controller = TextEditingController(text: currentName);

    final result = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Rename Tag'),
        content: TextField(
          controller: controller,
          autofocus: true,
          textCapitalization: TextCapitalization.words,
          decoration: const InputDecoration(
            hintText: 'Tag name',
            border: OutlineInputBorder(),
          ),
          onSubmitted: (value) => Navigator.of(context).pop(value),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('Rename'),
          ),
        ],
      ),
    );

    if (result != null && result.trim().isNotEmpty && result != currentName) {
      context.read<TagsCubit>().updateTag(id: tagId, name: result.trim());
    }
  }

  void _showDeleteConfirmation(
    BuildContext context,
    String tagId,
    String tagName,
  ) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete tag?'),
        content: Text(
          'Are you sure you want to delete "$tagName"? This tag will be removed from all entries.',
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
              context.read<TagsCubit>().deleteTag(tagId);
            },
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }
}
