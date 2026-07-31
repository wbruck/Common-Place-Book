// Tests for ShareIntentService: the Dart side of the native Android share
// sheet (ACTION_SEND) channel — fetching the cold-start share and receiving
// warm shares pushed from MainActivity while the app is running.

import 'package:common_place_book/core/share/share_intent_service.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const channel = MethodChannel('com.example.common_place_book/share');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() {
    messenger.setMockMethodCallHandler(channel, null);
  });

  group('ShareIntentService', () {
    test('getInitialShare returns the share that launched the app', () async {
      messenger.setMockMethodCallHandler(channel, (call) async {
        expect(call.method, 'getInitialShare');
        return <String, String>{'text': 'A wise quote.', 'title': 'Wisdom'};
      });

      final share = await ShareIntentService().getInitialShare();

      expect(share, {'text': 'A wise quote.', 'title': 'Wisdom'});
    });

    test('getInitialShare returns null when not launched from a share',
        () async {
      messenger.setMockMethodCallHandler(channel, (call) async => null);

      expect(await ShareIntentService().getInitialShare(), isNull);
    });

    test('setOnShareReceived delivers warm shares to the handler', () async {
      final received = <Map<String, String>>[];
      ShareIntentService().setOnShareReceived(received.add);

      final message = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('shareReceived', <String, String>{'text': 'Hello'}),
      );
      await messenger.handlePlatformMessage(channel.name, message, (_) {});

      expect(received, [
        {'text': 'Hello'},
      ]);
    });

    test('setOnShareReceived ignores unknown methods', () async {
      final received = <Map<String, String>>[];
      ShareIntentService().setOnShareReceived(received.add);

      final message = const StandardMethodCodec().encodeMethodCall(
        const MethodCall('somethingElse', 'payload'),
      );
      await messenger.handlePlatformMessage(channel.name, message, (_) {});

      expect(received, isEmpty);
    });
  });
}
