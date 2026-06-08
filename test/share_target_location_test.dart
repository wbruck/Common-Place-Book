// Tests for shareTargetLocation: how an Android PWA "share target" launch maps
// raw query params (text/title/url) into the new-entry deep-link, including
// lifting a Chrome-appended trailing URL out of the quote into the source.

import 'package:common_place_book/app/router.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('shareTargetLocation', () {
    Uri? locationFor(Map<String, String> params) {
      final result = shareTargetLocation(params);
      return result == null ? null : Uri.parse(result);
    }

    test('lifts a trailing URL out of the quote into the source', () {
      final uri = locationFor({
        'text': 'A wise quote.\n\nhttps://example.com/page',
      })!;

      expect(uri.path, '/entry/new');
      expect(uri.queryParameters['content'], 'A wise quote.');
      expect(uri.queryParameters['source'], 'https://example.com/page');
    });

    test('uses the separate url param as source and strips it from text', () {
      final uri = locationFor({
        'text': 'A wise quote.\n\nhttps://example.com/page',
        'url': 'https://example.com/page',
      })!;

      expect(uri.queryParameters['content'], 'A wise quote.');
      expect(uri.queryParameters['source'], 'https://example.com/page');
    });

    test('keeps a multi-line selection intact, only stripping the URL', () {
      final uri = locationFor({
        'text': 'Line one.\nLine two.\n\nhttps://example.com/a',
      })!;

      expect(uri.queryParameters['content'], 'Line one.\nLine two.');
      expect(uri.queryParameters['source'], 'https://example.com/a');
    });

    test('plain selected text with no URL has no source', () {
      final uri = locationFor({'text': 'Just a thought.'})!;

      expect(uri.queryParameters['content'], 'Just a thought.');
      expect(uri.queryParameters.containsKey('source'), isFalse);
    });

    test('falls back to title when there is no text', () {
      final uri = locationFor({
        'title': 'Page Title',
        'url': 'https://example.com',
      })!;

      expect(uri.queryParameters['content'], 'Page Title');
      expect(uri.queryParameters['source'], 'https://example.com');
    });

    test('a bare shared URL becomes the content with no source', () {
      final uri = locationFor({'text': 'https://example.com/article'})!;

      expect(uri.queryParameters['content'], 'https://example.com/article');
      expect(uri.queryParameters.containsKey('source'), isFalse);
    });

    test('returns null when nothing shareable is provided', () {
      expect(shareTargetLocation({}), isNull);
      expect(shareTargetLocation({'text': '   '}), isNull);
    });
  });
}
