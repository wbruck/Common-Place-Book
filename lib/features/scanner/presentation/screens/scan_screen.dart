import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

import '../../../../shared/widgets/empty_state.dart';
import '../../../../shared/widgets/loading_indicator.dart';
import '../../data/text_recognition_service_factory.dart';
import '../../domain/scan_result.dart';
import '../../domain/scan_source.dart';
import '../bloc/scan_cubit.dart';

/// Owns the whole scan flow: launches the camera/gallery picker on open,
/// shows recognition progress, then lets the user review and edit the
/// recognized text before handing it to the new-entry form.
class ScanScreen extends StatefulWidget {
  const ScanScreen({
    super.key,
    this.source = ScanSource.camera,
    this.returnResult = false,
    this.recoveredImage,
    this.createCubit,
  });

  /// Where captures come from: the first attempt and every retake use this
  /// source, so an "Import from Photo" flow retries in the gallery rather
  /// than surprising the user with the camera.
  final ScanSource source;

  /// When true, "Use text" pops this screen with a [ScanTextResult] so the
  /// caller (e.g. an already-open entry form) can consume the text, instead
  /// of pushing a new-entry form.
  final bool returnResult;

  /// A photo recovered via `retrieveLostScanImage` after Android killed the
  /// app while the picker was open; when set, the screen skips the picker
  /// and recognizes this image directly.
  final XFile? recoveredImage;

  /// Test seam: builds this screen's [ScanCubit], letting tests inject fake
  /// picking/recognition. Defaults to a cubit backed by the real platform
  /// services.
  final ScanCubit Function()? createCubit;

  @override
  State<ScanScreen> createState() => _ScanScreenState();
}

class _ScanScreenState extends State<ScanScreen> {
  late final ScanCubit _cubit;
  final TextEditingController _textController = TextEditingController();
  final TextEditingController _sourceController = TextEditingController();

  /// The last [ScanReview] the listener consumed. A retake the user backs
  /// out of re-emits the same review instance; skipping it keeps the user's
  /// in-flight edits in the controllers instead of resetting them.
  ScanReview? _handledReview;

  /// The source value this screen itself auto-filled from a scan suggestion.
  /// Lets a retake distinguish the app's own fill (stale, safe to replace)
  /// from text the user typed (never clobbered).
  String? _autoFilledSource;

  @override
  void initState() {
    super.initState();
    _cubit = widget.createCubit?.call() ??
        ScanCubit(recognitionService: createTextRecognitionService());
    final recovered = widget.recoveredImage;
    if (recovered == null) {
      _cubit.scan(widget.source);
    } else {
      _cubit.recognizeImage(recovered);
    }
  }

  @override
  void dispose() {
    _cubit.close();
    _textController.dispose();
    _sourceController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<ScanCubit, ScanState>(
      bloc: _cubit,
      listener: (context, state) {
        if (state is ScanCancelled) {
          _close(context);
        }
        // A cancelled retake re-emits the review already consumed (identical
        // instance): skip it so the user's edits survive.
        if (state is ScanReview && !identical(state, _handledReview)) {
          _handledReview = state;
          _textController.text = state.text;
          _applySuggestedSource(state.suggestedSource);
        }
      },
      builder: (context, state) {
        return Scaffold(
          appBar: AppBar(
            leading: IconButton(
              icon: const Icon(Icons.close),
              onPressed: () => _close(context),
            ),
            title: const Text('Scan Text'),
          ),
          body: switch (state) {
            ScanInitial() ||
            ScanCapturing() =>
              const LoadingIndicator(message: 'Waiting for a photo...'),
            ScanRecognizing() =>
              const LoadingIndicator(message: 'Reading text...'),
            // Momentary: the listener pops the screen.
            ScanCancelled() => const SizedBox.shrink(),
            ScanFailed(reason: final reason) => _buildFailure(reason),
            final ScanReview review => _buildReview(context, review),
          },
        );
      },
    );
  }

  Widget _buildFailure(ScanFailureReason reason) {
    final fromCamera = widget.source == ScanSource.camera;
    final retryLabel = fromCamera ? 'Retake photo' : 'Choose another photo';
    return switch (reason) {
      ScanFailureReason.noTextFound => EmptyState(
          icon: Icons.manage_search_outlined,
          title: 'No text found',
          subtitle: fromCamera
              ? 'Try again with the page flat, well lit, and in focus.'
              : 'Try a sharper photo where the text fills the frame.',
          actionLabel: retryLabel,
          onAction: _retake,
        ),
      ScanFailureReason.captureFailed => EmptyState(
          icon: Icons.no_photography_outlined,
          title: fromCamera
              ? "Couldn't take a photo"
              : "Couldn't open that photo",
          subtitle: fromCamera
              ? 'Check that the app is allowed to use the camera, '
                  'then try again.'
              : 'Check that the app is allowed to access your photos, '
                  'then try again.',
          actionLabel: 'Try again',
          onAction: _retake,
        ),
      ScanFailureReason.recognitionFailed => EmptyState(
          icon: Icons.error_outline,
          title: "Couldn't read the photo",
          subtitle: 'Something went wrong while reading the text. '
              'Please try again.',
          actionLabel: retryLabel,
          onAction: _retake,
        ),
      ScanFailureReason.unsupportedPlatform => const EmptyState(
          icon: Icons.devices_other_outlined,
          title: 'Scanning is not available here',
          subtitle: 'Scanning text from photos works on the iOS and '
              'Android apps.',
        ),
    };
  }

  Widget _buildReview(BuildContext context, ScanReview review) {
    final theme = Theme.of(context);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (review.imageBytes != null) ...[
                  ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: Image.memory(
                      review.imageBytes!,
                      height: 140,
                      width: double.infinity,
                      fit: BoxFit.cover,
                    ),
                  ),
                  const SizedBox(height: 16),
                ],
                Text(
                  'Scanned text',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _textController,
                  maxLines: null,
                  minLines: 6,
                  textCapitalization: TextCapitalization.sentences,
                  decoration: const InputDecoration(
                    hintText: 'Recognized text will appear here',
                    border: OutlineInputBorder(),
                  ),
                  style: theme.textTheme.bodyLarge,
                ),
                const SizedBox(height: 8),
                Text(
                  'Fix any words the scan got wrong before continuing.',
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: theme.colorScheme.onSurface.withValues(alpha: 0.6),
                  ),
                ),
                const SizedBox(height: 24),
                Text(
                  'Source (optional)',
                  style: theme.textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                TextField(
                  controller: _sourceController,
                  textCapitalization: TextCapitalization.words,
                  decoration: const InputDecoration(
                    hintText: 'Author or source...',
                    border: OutlineInputBorder(),
                    prefixIcon: Icon(Icons.person_outline),
                  ),
                ),
              ],
            ),
          ),
        ),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
            child: Row(
              children: [
                OutlinedButton.icon(
                  onPressed: _retake,
                  icon: Icon(
                    widget.source == ScanSource.camera
                        ? Icons.camera_alt_outlined
                        : Icons.photo_library_outlined,
                    size: 18,
                  ),
                  label: Text(
                    widget.source == ScanSource.camera
                        ? 'Retake'
                        : 'Change photo',
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ValueListenableBuilder<TextEditingValue>(
                    valueListenable: _textController,
                    builder: (context, value, _) => FilledButton(
                      onPressed: value.text.trim().isEmpty
                          ? null
                          : () => _useText(context),
                      child: const Text('Use text'),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }

  /// Offers [suggested] in the source field without clobbering user input:
  /// the field is only written while it is empty or still holds this
  /// screen's own earlier auto-fill (stale once a different page is scanned).
  void _applySuggestedSource(String? suggested) {
    final current = _sourceController.text;
    if (current.isNotEmpty && current != _autoFilledSource) {
      return;
    }
    _sourceController.text = suggested ?? '';
    _autoFilledSource = suggested;
  }

  /// Retries from the flow's original source, so a gallery import lets the
  /// user pick a different photo and a camera scan re-opens the camera.
  void _retake() => _cubit.scan(widget.source);

  /// Hands the reviewed text to the caller. In return mode this pops back to
  /// the launching screen with a [ScanTextResult]; otherwise it deep-links
  /// into the new-entry form (the same link the share target uses), replacing
  /// this screen so back never returns to a consumed scan.
  void _useText(BuildContext context) {
    if (widget.returnResult) {
      context.pop(
        ScanTextResult(
          content: _textController.text.trim(),
          source: _sourceController.text.trim(),
        ),
      );
      return;
    }
    context.pushReplacementNamed(
      'newEntry',
      queryParameters: {
        'content': _textController.text.trim(),
        if (_sourceController.text.trim().isNotEmpty)
          'source': _sourceController.text.trim(),
      },
    );
  }

  /// Leaves the scanner, falling back to home if it is the root route.
  void _close(BuildContext context) {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/');
    }
  }
}
