import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../tags/presentation/bloc/tags_cubit.dart';
import '../../data/repositories/local_entry_repository.dart';
import '../../domain/entities/entry_entity.dart';
import '../bloc/entries_list_cubit.dart';
import '../bloc/entry_form_cubit.dart';

class EntryFormScreen extends StatefulWidget {
  final String? entryId;

  const EntryFormScreen({
    super.key,
    this.entryId,
  });

  @override
  State<EntryFormScreen> createState() => _EntryFormScreenState();
}

class _EntryFormScreenState extends State<EntryFormScreen> {
  late final EntryFormCubit _formCubit;
  late final TextEditingController _contentController;
  late final TextEditingController _sourceController;

  bool get isEditing => widget.entryId != null;

  @override
  void initState() {
    super.initState();
    _formCubit = EntryFormCubit(
      entryRepository: context.read<LocalEntryRepository>(),
    );

    _contentController = TextEditingController();
    _sourceController = TextEditingController();

    if (isEditing) {
      _formCubit.initEditEntry(widget.entryId!);
    } else {
      _formCubit.initNewEntry();
    }
  }

  @override
  void dispose() {
    _formCubit.close();
    _contentController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return BlocConsumer<EntryFormCubit, EntryFormState>(
      bloc: _formCubit,
      listener: (context, state) {
        if (state is EntryFormReady && _contentController.text.isEmpty) {
          _contentController.text = state.content;
          _sourceController.text = state.source;
        }

        if (state is EntryFormSaved) {
          // Refresh the entries list
          context.read<EntriesListCubit>().refresh();

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isEditing ? 'Entry updated' : 'Entry saved',
              ),
              behavior: SnackBarBehavior.floating,
            ),
          );

          context.pop();
        }

        if (state is EntryFormError) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(state.message),
              backgroundColor: theme.colorScheme.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      },
      builder: (context, state) {
        final isLoading = state is EntryFormLoading || state is EntryFormSaving;
        final formState = state is EntryFormReady ? state : null;

        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _handleClose(context, formState),
            ),
            title: Text(isEditing ? 'Edit Entry' : 'New Entry'),
            actions: [
              TextButton(
                onPressed: isLoading || formState?.isValid != true
                    ? null
                    : () => _formCubit.save(),
                child: isLoading
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Text('Save'),
              ),
            ],
          ),
          body: isLoading && formState == null
              ? const LoadingIndicator(message: 'Loading...')
              : SingleChildScrollView(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Content field
                      TextField(
                        controller: _contentController,
                        onChanged: _formCubit.updateContent,
                        maxLines: null,
                        minLines: 5,
                        autofocus: !isEditing,
                        textCapitalization: TextCapitalization.sentences,
                        decoration: const InputDecoration(
                          hintText: 'What wisdom would you like to capture?',
                          border: OutlineInputBorder(),
                        ),
                        style: theme.textTheme.bodyLarge,
                      ),

                      const SizedBox(height: 24),

                      // Source field
                      Text(
                        'Source (optional)',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: _sourceController,
                        onChanged: _formCubit.updateSource,
                        textCapitalization: TextCapitalization.words,
                        decoration: const InputDecoration(
                          hintText: 'Author or source...',
                          border: OutlineInputBorder(),
                          prefixIcon: Icon(Icons.person_outline),
                        ),
                      ),

                      const SizedBox(height: 24),

                      // Tags section
                      Text(
                        'Tags',
                        style: theme.textTheme.titleSmall,
                      ),
                      const SizedBox(height: 8),
                      _buildTagSelector(context, formState),
                    ],
                  ),
                ),
        );
      },
    );
  }

  Widget _buildTagSelector(BuildContext context, EntryFormReady? formState) {
    return BlocBuilder<TagsCubit, TagsState>(
      builder: (context, tagsState) {
        final tags =
            tagsState is TagsLoaded ? tagsState.tags : <TagEntity>[];
        final selectedTagIds = formState?.tagIds ?? [];

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TagSelector(
              availableTags: tags,
              selectedTagIds: selectedTagIds,
              onTagSelected: _formCubit.addTag,
              onTagDeselected: _formCubit.removeTag,
              onCreateTag: () => _showCreateTagDialog(context),
              loading: tagsState is TagsLoading,
            ),
          ],
        );
      },
    );
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
      final tagsCubit = context.read<TagsCubit>();
      final tag = await tagsCubit.createTag(name: result.trim());
      if (tag != null) {
        _formCubit.addTag(tag.id);
      }
    }
  }

  void _handleClose(BuildContext context, EntryFormReady? formState) {
    if (formState?.hasChanges == true) {
      showDialog(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                context.pop();
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      context.pop();
    }
  }
}
