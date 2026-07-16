import 'package:flutter/foundation.dart';

/// Result of running [cleanScannedText] over raw OCR output.
@immutable
class CleanedScanText {
  const CleanedScanText({required this.text, this.suggestedSource});

  /// The reflowed quote text.
  final String text;

  /// Attribution pulled from a trailing dash line (e.g. `— Marcus Aurelius`),
  /// or null when no attribution line was detected.
  final String? suggestedSource;
}

/// Ligatures that OCR engines commonly emit for book typography.
const Map<String, String> _ligatures = <String, String>{
  'ﬁ': 'fi',
  'ﬂ': 'fl',
  'ﬀ': 'ff',
  'ﬃ': 'ffi',
  'ﬄ': 'ffl',
};

/// Matches an attribution line: an em dash, an en dash, or a hyphen followed
/// by whitespace, then the attribution itself. A hyphen glued straight onto a
/// letter ("-five") is the OCR'd continuation of a hyphen-split word, never
/// an attribution, so it deliberately does not match.
final RegExp _attributionPattern = RegExp(r'^(?:[—–]|-(?=\s))\s*(.+)$');

/// Matches a line ending in sentence punctuation, optionally followed by a
/// closing quote or bracket. Attributions name an author or a work; a dash
/// line that ends like prose ("— Bonjour, dit-il.") is dash-typeset dialogue
/// or an interrupted sentence, i.e. quote body that must stay in the text.
final RegExp _sentencePunctEnd = RegExp(r'''[.,!?;:…]["'”’)\]]*$''');

/// Matches a line whose last characters are a letter and a hyphen, i.e. a
/// word split across a printed line break ("wis-").
final RegExp _hyphenSplitEnd = RegExp(r'\p{L}-$', unicode: true);

/// Matches a line starting with a lowercase letter (the continuation of a
/// hyphen-split word).
final RegExp _lowercaseStart = RegExp(r'^\p{Ll}', unicode: true);

/// Longest line (in characters) still considered an attribution.
const int _maxAttributionLength = 80;

/// Cleans raw OCR text from a book page into natural paragraphs.
///
/// ML Kit emits a hard newline after every visual line, so quotes arrive
/// artificially wrapped. The heuristics, applied in order:
///
/// a. Normalize line endings and ligatures; collapse intra-line whitespace.
/// b. Extract a trailing attribution line ("— Author") as [CleanedScanText.suggestedSource].
/// c. Rejoin words hyphen-split across line breaks ("wis-\ndom" -> "wisdom").
/// d. Reflow paragraphs: blank lines separate paragraphs, single newlines
///    within a paragraph become spaces.
/// e. Trim the final result.
CleanedScanText cleanScannedText(String raw) {
  final lines = _normalizedLines(raw);
  final suggestedSource = _extractAttribution(lines);
  final text = _reflowParagraphs(lines);
  return CleanedScanText(text: text, suggestedSource: suggestedSource);
}

/// Heuristic (a): normalizes `\r\n`/`\r` to `\n`, replaces common ligatures,
/// collapses runs of spaces/tabs to a single space, and trims each line.
List<String> _normalizedLines(String raw) {
  var text = raw.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
  for (final entry in _ligatures.entries) {
    text = text.replaceAll(entry.key, entry.value);
  }
  return text
      .split('\n')
      .map((line) => line.replaceAll(RegExp(r'[ \t]+'), ' ').trim())
      .toList();
}

/// Heuristic (b): if the last non-empty line is a short (<= 80 chars) dash
/// attribution, removes it from [lines] and returns the attribution with the
/// dash and surrounding whitespace stripped. Returns null otherwise.
///
/// Removing a line silently truncates the quote, so a dash line is only
/// treated as an attribution when it doesn't itself read like prose: lines
/// ending in sentence punctuation (dash-opening dialogue, an interrupted
/// sentence) stay in the text. Better to miss an odd attribution — the user
/// can move it by hand — than to cut quote body into the source field.
String? _extractAttribution(List<String> lines) {
  for (var i = lines.length - 1; i >= 0; i--) {
    final line = lines[i];
    if (line.isEmpty) {
      continue;
    }
    if (line.length > _maxAttributionLength) {
      return null;
    }
    final match = _attributionPattern.firstMatch(line);
    if (match == null || _sentencePunctEnd.hasMatch(line)) {
      return null;
    }
    lines.removeAt(i);
    return match.group(1)!.trim();
  }
  return null;
}

/// Heuristics (c)+(d): joins consecutive non-empty lines into paragraphs.
/// A line ending in `<letter>-` followed by a line starting with a lowercase
/// letter joins without the hyphen; other line breaks become single spaces.
/// Paragraphs (separated by one or more blank lines) are joined with exactly
/// one blank line, and the result is trimmed (heuristic e).
String _reflowParagraphs(List<String> lines) {
  final paragraphs = <String>[];
  final current = StringBuffer();

  void flush() {
    if (current.isNotEmpty) {
      paragraphs.add(current.toString());
      current.clear();
    }
  }

  for (final line in lines) {
    if (line.isEmpty) {
      flush();
      continue;
    }
    if (current.isEmpty) {
      current.write(line);
    } else if (_hyphenSplitEnd.hasMatch(current.toString()) &&
        _lowercaseStart.hasMatch(line)) {
      final joined = current.toString();
      current
        ..clear()
        ..write(joined.substring(0, joined.length - 1))
        ..write(line);
    } else {
      current
        ..write(' ')
        ..write(line);
    }
  }
  flush();

  return paragraphs.join('\n\n');
}
