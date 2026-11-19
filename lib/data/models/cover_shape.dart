import 'package:read_stats/data/models/book_type.dart';

/// How a book's cover is framed — a per-book choice, not tied to book type.
/// Audiobook art is square, but the user can pick either shape for any book.
abstract final class CoverShape {
  static const int portrait = 0;
  static const int square = 1;

  /// The shape a new book of [bookTypeId] starts with: square for an
  /// audiobook, as that is how their art is made, portrait otherwise.
  /// Only a starting point — see above.
  static int defaultFor(int bookTypeId) =>
      bookTypeId == BookType.audiobook ? square : portrait;

  /// Width / height for [shape]. Drives both the crop frame and every place a
  /// cover is drawn, so what the user framed is what the library shows.
  static double aspectRatio(int? shape) => shape == square ? 1 : 2 / 3;
}
