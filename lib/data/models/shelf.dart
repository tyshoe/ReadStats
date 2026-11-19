/// The system shelf IDs. Stable because shelves are seeded in a fixed order
/// and only exist from v2 onwards (v1 had no shelves). Custom shelves take
/// any other ID.
abstract final class Shelf {
  static const int currentlyReading = 1;
  static const int wantToRead = 2;
  static const int finished = 3;
  static const int unfinished = 4;

  /// Whether a book on [shelfId] can take new reading sessions.
  ///
  /// The shelf is the only thing that decides this — deliberately not
  /// `date_finished`, which stays a plain timestamp for stats and goals. A
  /// book moved off the Finished shelf is readable again immediately, even
  /// though it keeps the date of the read it already completed. Unfinished
  /// (DNF) still accepts sessions: picking one back up is normal.
  static bool acceptsSessions(int? shelfId) => shelfId != finished;
}
