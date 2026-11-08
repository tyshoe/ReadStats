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

  /// "2", or "1.5" for an in-between novella.
  static String formatPosition(double position) =>
      position == position.roundToDouble()
          ? position.toInt().toString()
          : position.toString();
}
