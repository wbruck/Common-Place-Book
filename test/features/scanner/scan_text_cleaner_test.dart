import 'package:common_place_book/features/scanner/domain/scan_text_cleaner.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('ligature and whitespace normalization', () {
    test('replaces common ligatures', () {
      final cleaned = cleanScannedText('aﬀection ﬁnds ﬂow eﬃcient baﬄe');
      expect(cleaned.text, 'affection finds flow efficient baffle');
    });

    test('collapses runs of spaces and tabs and trims each line', () {
      final cleaned = cleanScannedText('  the   quiet\t\tmind  \n  endures  ');
      expect(cleaned.text, 'the quiet mind endures');
    });

    test('normalizes CRLF and CR line endings', () {
      final cleaned = cleanScannedText('first line\r\nsecond line\rthird');
      expect(cleaned.text, 'first line second line third');
    });
  });

  group('hyphen rejoin', () {
    test('joins a hyphen-split word across a line break', () {
      final cleaned = cleanScannedText('the pursuit of wis-\ndom endures');
      expect(cleaned.text, 'the pursuit of wisdom endures');
    });

    test('keeps the hyphen when the next line starts uppercase', () {
      final cleaned = cleanScannedText('the well-\nRead scholar');
      expect(cleaned.text, 'the well- Read scholar');
    });

    test('does not join when the hyphen does not follow a letter', () {
      final cleaned = cleanScannedText('pages 12-\nfourteen');
      expect(cleaned.text, 'pages 12- fourteen');
    });

    test('keeps a trailing hyphen on the final line of input', () {
      final cleaned = cleanScannedText('the pursuit of wis-');
      expect(cleaned.text, 'the pursuit of wis-');
      expect(cleaned.suggestedSource, isNull);
    });
  });

  group('paragraph reflow', () {
    test('turns single newlines within a paragraph into spaces', () {
      final cleaned = cleanScannedText('one line\nanother line\na third');
      expect(cleaned.text, 'one line another line a third');
    });

    test('preserves paragraph breaks as exactly one blank line', () {
      final cleaned = cleanScannedText(
        'first paragraph\ncontinues here\n\n\n\nsecond paragraph\nends here',
      );
      expect(
        cleaned.text,
        'first paragraph continues here\n\nsecond paragraph ends here',
      );
    });
  });

  group('attribution extraction', () {
    test('extracts an em dash attribution', () {
      final cleaned = cleanScannedText(
        'Guard your thoughts.\n— Marcus Aurelius, Meditations',
      );
      expect(cleaned.text, 'Guard your thoughts.');
      expect(cleaned.suggestedSource, 'Marcus Aurelius, Meditations');
    });

    test('extracts an en dash attribution', () {
      final cleaned = cleanScannedText('Know thyself.\n– Socrates');
      expect(cleaned.text, 'Know thyself.');
      expect(cleaned.suggestedSource, 'Socrates');
    });

    test('extracts a plain hyphen attribution', () {
      final cleaned = cleanScannedText('Less is more.\n- Mies van der Rohe');
      expect(cleaned.text, 'Less is more.');
      expect(cleaned.suggestedSource, 'Mies van der Rohe');
    });

    test('ignores blank lines after the attribution', () {
      final cleaned = cleanScannedText('Stay curious.\n— Anonymous\n\n  \n');
      expect(cleaned.text, 'Stay curious.');
      expect(cleaned.suggestedSource, 'Anonymous');
    });

    test('extracts an attribution line of exactly 80 characters', () {
      final author = 'a' * 78; // '— ' + 78 chars = the 80-char boundary.
      final cleaned = cleanScannedText('Guard your thoughts.\n— $author');
      expect(cleaned.text, 'Guard your thoughts.');
      expect(cleaned.suggestedSource, author);
    });
  });

  group('no attribution extracted', () {
    test('when the last line has no leading dash', () {
      final cleaned = cleanScannedText('Guard your thoughts.\nMarcus Aurelius');
      expect(cleaned.text, 'Guard your thoughts. Marcus Aurelius');
      expect(cleaned.suggestedSource, isNull);
    });

    test('when the dash line exceeds 80 characters', () {
      final longLine = '— ${'a' * 85}';
      final cleaned = cleanScannedText('Guard your thoughts.\n\n$longLine');
      expect(cleaned.text, 'Guard your thoughts.\n\n$longLine');
      expect(cleaned.suggestedSource, isNull);
    });

    test('when the dash line is 81 characters', () {
      final longLine = '— ${'a' * 79}'; // One past the 80-char boundary.
      final cleaned = cleanScannedText('Guard your thoughts.\n$longLine');
      expect(cleaned.text, 'Guard your thoughts. $longLine');
      expect(cleaned.suggestedSource, isNull);
    });
  });

  group('dash-initial quote body stays in the text', () {
    test('keeps dash-opening dialogue', () {
      final cleaned = cleanScannedText('He greeted us.\n— Bonjour, dit-il.');
      expect(cleaned.text, 'He greeted us. — Bonjour, dit-il.');
      expect(cleaned.suggestedSource, isNull);
    });

    test('keeps an interrupted sentence continuation', () {
      final cleaned = cleanScannedText('It was over\n— or so it seemed.');
      expect(cleaned.text, 'It was over — or so it seemed.');
      expect(cleaned.suggestedSource, isNull);
    });

    test('keeps a hyphen-split continuation line ("twenty / -five")', () {
      final cleaned = cleanScannedText('He was twenty\n-five that spring');
      expect(cleaned.text, 'He was twenty -five that spring');
      expect(cleaned.suggestedSource, isNull);
    });

    test('keeps a lone dash as text', () {
      final cleaned = cleanScannedText('Guard your thoughts.\n—');
      expect(cleaned.text, 'Guard your thoughts. —');
      expect(cleaned.suggestedSource, isNull);
    });
  });

  group('realistic book page', () {
    test('combines reflow, hyphen rejoin, ligatures, and attribution', () {
      const raw = 'The happiness of your life depends upon the quality\r\n'
          'of your thoughts: therefore, guard accordingly, and\r\n'
          'take care that you entertain no notions unsuitable\r\n'
          'to virtue and reasonable nature.\r\n'
          '\r\n'
          'Very little is needed to make a happy life; it is all\r\n'
          'within yourself, in your way of thinking. Such diﬃ-\r\n'
          'culties are the ﬁnest teachers.\r\n'
          '\r\n'
          '— Marcus Aurelius, Meditations\r\n';
      final cleaned = cleanScannedText(raw);
      expect(
        cleaned.text,
        'The happiness of your life depends upon the quality of your '
        'thoughts: therefore, guard accordingly, and take care that you '
        'entertain no notions unsuitable to virtue and reasonable nature.'
        '\n\n'
        'Very little is needed to make a happy life; it is all within '
        'yourself, in your way of thinking. Such difficulties are the '
        'finest teachers.',
      );
      expect(cleaned.suggestedSource, 'Marcus Aurelius, Meditations');
    });
  });

  group('empty input', () {
    test('empty string returns empty text and null source', () {
      final cleaned = cleanScannedText('');
      expect(cleaned.text, isEmpty);
      expect(cleaned.suggestedSource, isNull);
    });

    test('whitespace-only input returns empty text and null source', () {
      final cleaned = cleanScannedText('  \n\t\n  \r\n ');
      expect(cleaned.text, isEmpty);
      expect(cleaned.suggestedSource, isNull);
    });
  });
}
