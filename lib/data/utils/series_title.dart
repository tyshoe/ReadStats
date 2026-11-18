/// A series named inside a book title, Goodreads style:
/// "Legendary (Caraval #2)" or "The Final Empire (Mistborn, #1)".
class SeriesTitle {
  /// The title without the series part — "Legendary".
  final String title;
  final String series;
  final double position;

  const SeriesTitle(this.title, this.series, this.position);

  // The last parenthetical, holding a name and a single #number. Omnibus
  // ranges like "#1-3" don't match: they aren't one place in the series.
  static final _pattern = RegExp(
      r'^(.*?\S)\s*\(([^()]*?[^\s,()]),?\s*#\s*(\d+(?:\.\d+)?)\)\s*$');

  /// The series in [raw], or null when the title doesn't name one.
  static SeriesTitle? parse(String raw) {
    final m = _pattern.firstMatch(raw.trim());
    if (m == null) return null;
    return SeriesTitle(m[1]!, m[2]!.trim(), double.parse(m[3]!));
  }

  // A number as catalogues write it: 3, 1.5, IV, Three, Third.
  static const _number = r'(\d+(?:\.\d+)?|[ivxl]+|one|two|three|four|five|six|'
      r'seven|eight|nine|ten|eleven|twelve|first|second|third|fourth|fifth|'
      r'sixth|seventh|eighth|ninth|tenth|eleventh|twelfth)';

  // "Harry Potter, Book 1", "Harry Potter: Book One", "Name (Vol. 2)",
  // "Name ; v. 3". The name has to end on a non-digit so "Warhammer 40,000"
  // isn't read as number 0 of "Warhammer 40".
  static final _keywordListing = RegExp(
    r'^(.*?\D)(?:\s+|\s*[,;:(\-–—]\s*)'
    r'(?:book|bk|volume|vol|v|part|pt|number|no|nr|tome|tomo|t|band|bd|livro|libro)'
    r'\.?\s*#?\s*' '$_number' r'\)?\.?$',
    caseSensitive: false,
  );

  // "The Stormlight Archive #1", "Harry Potter, 1", "Harry Potter, I".
  static final _bareListing = RegExp(
    r'^(.*?\D)\s*(?:#|[,;:(]\s*#?)\s*' '$_number' r'\)?\.?$',
    caseSensitive: false,
  );

  /// A series line as Open Library editions carry it — a name, often with
  /// the book's number in one of many spellings. Null when there's no name.
  static ({String name, double? position})? parseListing(String raw) {
    final text = raw.trim();
    final m = _keywordListing.firstMatch(text) ?? _bareListing.firstMatch(text);
    final position = m == null ? null : parseNumber(m[2]!);
    final name = _cleanName(position == null ? text : m![1]!);
    if (name.isEmpty) return null;
    return (name: name, position: position);
  }

  static String _cleanName(String name) {
    var s = name
        .replaceAll('_', ' ')
        .replaceAll(RegExp(r'[\s,;:.\-–—(]+$'), '')
        .trim();
    // Quotes around the whole name, not one that belongs inside it.
    final quoted = RegExp(r'''^["“'](.*)["”']$''').firstMatch(s);
    if (quoted != null) s = quoted[1]!.trim();
    return s;
  }

  /// [text] as a series number: digits, a Roman numeral or an English word.
  /// Null for anything else.
  static double? parseNumber(String text) {
    final t = text.trim().toLowerCase();
    final n = double.tryParse(t) ?? _words[t]?.toDouble() ?? _roman(t);
    return n != null && n >= 0 && n < 1000 ? n : null;
  }

  static const _words = {
    'one': 1, 'two': 2, 'three': 3, 'four': 4, 'five': 5, 'six': 6,
    'seven': 7, 'eight': 8, 'nine': 9, 'ten': 10, 'eleven': 11, 'twelve': 12,
    'first': 1, 'second': 2, 'third': 3, 'fourth': 4, 'fifth': 5,
    'sixth': 6, 'seventh': 7, 'eighth': 8, 'ninth': 9, 'tenth': 10,
    'eleventh': 11, 'twelfth': 12,
  };

  // I to LXXXIX — well-formed numerals only, so a stray "ill" isn't one.
  static double? _roman(String t) {
    if (!RegExp(r'^(l?x{0,3}|xl|xc)(i{0,3}|iv|vi{0,3}|ix)$').hasMatch(t) ||
        t.isEmpty) {
      return null;
    }
    const values = {'i': 1, 'v': 5, 'x': 10, 'l': 50, 'c': 100};
    var total = 0;
    for (var i = 0; i < t.length; i++) {
      final v = values[t[i]]!;
      final next = i + 1 < t.length ? values[t[i + 1]]! : 0;
      total += v < next ? -v : v;
    }
    return total.toDouble();
  }

  /// What two spellings of one series have in common, so "The Stormlight
  /// Archive", "Stormlight Archive" and "stormlight archive series" are
  /// recognised as the same series rather than saved as three.
  static String matchKey(String name) => name
      .toLowerCase()
      .trim()
      .replaceFirst(RegExp(r'^the\s+'), '')
      .replaceFirst(RegExp(r'\s+(series|saga|trilogy|sequence|cycle)$'), '')
      .replaceAll(RegExp(r'[^\p{L}\p{N}]', unicode: true), '');

  /// "2", or "1.5" for an in-between novella.
  static String formatPosition(double position) =>
      position == position.roundToDouble()
          ? position.toInt().toString()
          : position.toString();
}
