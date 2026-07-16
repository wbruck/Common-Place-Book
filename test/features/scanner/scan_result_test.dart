import 'package:common_place_book/features/scanner/domain/scan_result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const result = ScanTextResult(content: 'scanned words', source: 'An Author');

  group('mergeIntoContent', () {
    test('replaces an empty draft', () {
      expect(result.mergeIntoContent(''), 'scanned words');
    });

    test('replaces a whitespace-only draft', () {
      expect(result.mergeIntoContent('  \n  '), 'scanned words');
    });

    test('appends after a blank line and never clobbers typed text', () {
      expect(
        result.mergeIntoContent('my own draft'),
        'my own draft\n\nscanned words',
      );
    });
  });

  group('shouldFillSource', () {
    test('fills an empty source field', () {
      expect(result.shouldFillSource(''), isTrue);
    });

    test('fills a whitespace-only source field', () {
      expect(result.shouldFillSource('   '), isTrue);
    });

    test('never overwrites a typed source', () {
      expect(result.shouldFillSource('My Notes'), isFalse);
    });

    test('does nothing when the scan found no source', () {
      const sourceless = ScanTextResult(content: 'scanned words');
      expect(sourceless.shouldFillSource(''), isFalse);
    });
  });
}
