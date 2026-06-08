import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';

import '../../../../shared/widgets/loading_indicator.dart';
import '../../../../shared/widgets/tag_chip.dart';
import '../../../tags/presentation/bloc/tags_cubit.dart';
import '../../data/repositories/entry_repository.dart';
import '../../domain/entities/entry_entity.dart';
import '../bloc/entries_list_cubit.dart';
import '../bloc/entry_form_cubit.dart';

class EntryFormScreen extends StatefulWidget {
  const EntryFormScreen({
    super.key,
    this.entryId,
    this.initialContent,
    this.initialSource,
  });
  final String? entryId;
  final String? initialContent;
  final String? initialSource;

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
      entryRepository: context.read<EntryRepository>(),
    );

    // Seed the controllers directly from the widget params (e.g. text shared
    // into the app via the Android PWA share target). The BlocConsumer
    // listener can't do this for a new entry: initNewEntry emits its state
    // synchronously in initState, before the listener subscribes, so it never
    // fires for that initial state. (Editing still relies on the listener
    // because that load is async and arrives after subscription.)
    _contentController =
        TextEditingController(text: widget.initialContent ?? '');
    _sourceController = TextEditingController(text: widget.initialSource ?? '');

    if (isEditing) {
      _formCubit.initEditEntry(widget.entryId!);
    } else {
      _formCubit.initNewEntry(
        initialContent: widget.initialContent ?? '',
        initialSource: widget.initialSource ?? '',
      );
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

          _close(context);
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

        return PopScope(
          // We always handle leaving ourselves (discard prompt + pop-or-home
          // fallback) so the hardware back button behaves the same as the
          // close button, including when the form is the root route.
          canPop: false,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            _handleClose(context, formState);
          },
          child: Scaffold(
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
          ),
        );
      },
    );
  }

  Widget _buildTagSelector(BuildContext context, EntryFormReady? formState) {
    return BlocBuilder<TagsCubit, TagsState>(
      builder: (context, tagsState) {
        final tags = tagsState is TagsLoaded ? tagsState.tags : <TagEntity>[];
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
      if (!context.mounted) return;
      final tagsCubit = context.read<TagsCubit>();
      final tag = await tagsCubit.createTag(name: result.trim());
      if (tag != null) {
        _formCubit.addTag(tag.id);
      }
    }
  }

  void _handleClose(BuildContext context, EntryFormReady? formState) {
    if (formState?.hasChanges ?? false) {
      showDialog<void>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Discard changes?'),
          content: const Text(
            'You have unsaved changes. Are you sure you want to discard them?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Keep editing'),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
                _close(context);
              },
              child: const Text('Discard'),
            ),
          ],
        ),
      );
    } else {
      _close(context);
    }
  }

  /// Leaves the form. When the form is the only route on the stack — e.g. it
  /// was launched directly via the Android PWA share target — there is nothing
  /// to pop back to, so fall back to the home route instead of a no-op pop.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}
