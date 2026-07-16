import 'dart:typed_data';

import 'package:common_place_book/core/utils/result.dart';
import 'package:common_place_book/features/scanner/domain/scan_result.dart';
import 'package:common_place_book/features/scanner/domain/scan_source.dart';
import 'package:common_place_book/features/scanner/domain/text_recognition_service.dart';
import 'package:common_place_book/features/scanner/presentation/bloc/scan_cubit.dart';
import 'package:common_place_book/features/scanner/presentation/screens/scan_screen.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:image_picker/image_picker.dart';

/// An [XFile] whose bytes can't be read. Real file I/O never completes in a
/// widget test's fake-async zone, and the preview is optional anyway: the
/// cubit swallows the read failure and reviews without a preview image.
class _UnreadableXFile extends XFile {
  _UnreadableXFile() : super('/scan/photo.jpg');

  @override
  Future<Uint8List> readAsBytes() async =>
      throw Exception('no preview bytes in tests');
}

/// Serves recognition results in order; the last one repeats.
class _QueuedRecognitionService implements TextRecognitionService {
  _QueuedRecognitionService(this.results);
  final List<Result<String, TextRecognitionError>> results;
  int _calls = 0;

  @override
  bool get isSupported => true;

  @override
  Future<Result<String, TextRecognitionError>> recognizeText(
    String imagePath,
  ) async {
    final index = _calls < results.length ? _calls : results.length - 1;
    _calls++;
    return results[index];
  }
}

void main() {
  final image = _UnreadableXFile();

  /// A tiny app with a launcher screen that pushes the scanner and captures
  /// the popped result, mirroring how the entry form consumes a scan.
  GoRouter scanRouter({
    required ScanCubit Function() createCubit,
    ScanSource source = ScanSource.camera,
    bool returnResult = false,
    void Function(ScanTextResult?)? onResult,
  }) {
    late final GoRouter router;
    return router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Center(
              child: ElevatedButton(
                // Note: the push must happen unconditionally — a null-aware
                // `onResult?.call(await ...)` would short-circuit past it.
                onPressed: () async {
                  final result = await router.push<ScanTextResult>('/scan');
                  onResult?.call(result);
                },
                child: const Text('launch scan'),
              ),
            ),
          ),
        ),
        GoRoute(
          path: '/scan',
          builder: (context, state) => ScanScreen(
            source: source,
            returnResult: returnResult,
            createCubit: createCubit,
          ),
        ),
      ],
    );
  }

  Future<void> launchScan(WidgetTester tester, GoRouter router) async {
    await tester.pumpWidget(MaterialApp.router(routerConfig: router));
    await tester.tap(find.text('launch scan'));
    await tester.pumpAndSettle();
  }

  testWidgets('"Use text" in return mode pops a ScanTextResult', (tester) async {
    ScanTextResult? popped;
    var completed = false;
    final router = scanRouter(
      returnResult: true,
      onResult: (result) {
        popped = result;
        completed = true;
      },
      createCubit: () => ScanCubit(
        recognitionService: _QueuedRecognitionService(
          [const Success('scanned words')],
        ),
        pickImage: (_) async => image,
        deleteImage: (_) async {},
      ),
    );
    await launchScan(tester, router);

    expect(find.text('scanned words'), findsOneWidget);
    await tester.enterText(find.byType(TextField).at(1), 'My Author');
    await tester.tap(find.text('Use text'));
    await tester.pumpAndSettle();

    expect(completed, isTrue);
    expect(popped?.content, 'scanned words');
    expect(popped?.source, 'My Author');
  });

  testWidgets('backing out of a retake keeps the review and hand edits',
      (tester) async {
    var picks = 0;
    final router = scanRouter(
      createCubit: () => ScanCubit(
        recognitionService: _QueuedRecognitionService(
          [const Success('original ocr text')],
        ),
        // The retake's picker is dismissed without a photo.
        pickImage: (_) async => ++picks == 1 ? image : null,
        deleteImage: (_) async {},
      ),
    );
    await launchScan(tester, router);

    await tester.enterText(find.byType(TextField).at(0), 'edited by hand');
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();

    // Still on the review with the edits intact — the scanner never closed.
    expect(find.byType(ScanScreen), findsOneWidget);
    expect(find.text('edited by hand'), findsOneWidget);
  });

  testWidgets('a stale auto-filled source is replaced after a retake',
      (tester) async {
    final router = scanRouter(
      createCubit: () => ScanCubit(
        recognitionService: _QueuedRecognitionService(const [
          Success('text from page a\n— Author A'),
          Success('text from page b\n— Author B'),
        ]),
        pickImage: (_) async => image,
        deleteImage: (_) async {},
      ),
    );
    await launchScan(tester, router);
    expect(find.text('Author A'), findsOneWidget);

    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();

    expect(find.text('text from page b'), findsOneWidget);
    expect(find.text('Author B'), findsOneWidget);
    expect(find.text('Author A'), findsNothing);
  });

  testWidgets('a user-typed source survives a retake suggestion',
      (tester) async {
    final router = scanRouter(
      createCubit: () => ScanCubit(
        recognitionService: _QueuedRecognitionService(const [
          Success('text from page a\n— Author A'),
          Success('text from page b\n— Author B'),
        ]),
        pickImage: (_) async => image,
        deleteImage: (_) async {},
      ),
    );
    await launchScan(tester, router);

    await tester.enterText(find.byType(TextField).at(1), 'My Notes');
    await tester.tap(find.text('Retake'));
    await tester.pumpAndSettle();

    expect(find.text('My Notes'), findsOneWidget);
    expect(find.text('Author B'), findsNothing);
  });

  testWidgets('a failed gallery import retries from the gallery',
      (tester) async {
    final sources = <ScanSource>[];
    final router = scanRouter(
      source: ScanSource.gallery,
      createCubit: () => ScanCubit(
        recognitionService: _QueuedRecognitionService(
          [const Failure(TextRecognitionError.noTextFound)],
        ),
        pickImage: (pickSource) async {
          sources.add(pickSource);
          return image;
        },
        deleteImage: (_) async {},
      ),
    );
    await launchScan(tester, router);

    expect(find.text('No text found'), findsOneWidget);
    await tester.tap(find.text('Choose another photo'));
    await tester.pumpAndSettle();

    expect(sources, [ScanSource.gallery, ScanSource.gallery]);
  });
}
