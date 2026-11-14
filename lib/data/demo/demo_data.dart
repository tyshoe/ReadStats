import 'dart:math';

import '../database/database_helper.dart';
import '../models/book.dart';
import '../models/book_tag.dart';
import '../models/goal.dart';
import '../models/session.dart';
import '../models/tag.dart';
import '../repositories/goal_repository.dart';

/// A sample library for exploring and testing the app without real data:
/// Settings → Data → Load Demo Data, or the demo option during onboarding.
///
/// Generated, not stored, and anchored to [DemoData.generate]'s `now`, so the
/// streak is always alive, last month always has a recap and last year always
/// has a Wrapped. Seeded, so every load produces the same library.
///
/// KEEP THIS IN STEP WITH THE APP. When a feature reads data the demo doesn't
/// produce — a new column, a new shelf or format, a new kind of goal, a stat
/// that needs a pattern (time of day, streaks, rereads...) — extend the
/// generator here so the feature has something to show. What it covers today:
///
/// * Every shelf: finished, currently reading, want to read, unfinished.
/// * Every format: paperback, hardback, ebook, audiobook (with narrator and
///   length, square covers).
/// * ~26 months of sessions on two tracks — print in the evenings and at
///   weekends, audio on weekday mornings — with notes on some, and two breaks
///   so the longest streak isn't simply "all of it".
/// * Ratings (halves included), reviews, favourites, tags with colours.
/// * Series: Sherlock Holmes #1 and #3 (a gap at #2 on purpose), plus #2
///   sitting unlinked with the series in its title, for "Find series in
///   titles"; and The d'Artagnan Romances with #1 in progress and #2 waiting,
///   so finishing #1 shows "Next in series".
/// * Real covers (downloaded from Open Library on load, drawn ones as the
///   offline fallback) and Open Library work keys; a few books left bare for
///   the no-cover paths. A new title needs an entry in `_openLibrary`.
/// * A same-day bulk add (the activity feed's "Added N books").
/// * Goals of each period, with target changes, created in the past — plus a
///   weekly sessions goal one session short this week, so logging any session
///   sets off the goal celebration (and its "Met your weekly goal" entry).
/// * Planner entries.
class DemoData {
  DemoData._();

  static DemoDataset generate(DateTime now) => _Generator(now).build();
}

/// Everything a demo load writes. Goal rows use the backup-row shape so they
/// go in through the same restore path as a backup.
class DemoDataset {
  final List<Tag> tags;

  /// Books with ids. A non-null `coverPath` is the filename the loader should
  /// draw a cover into.
  final List<Book> books;
  final List<Session> sessions;
  final List<BookTag> bookTags;
  final List<Map<String, dynamic>> goals;
  final List<Map<String, dynamic>> goalTargets;

  /// `book_id` and `date_added` for each planner entry, in order.
  final List<Map<String, dynamic>> planner;

  /// Where to download each book's real cover, by book id. Books with a
  /// `coverPath` but no URL here (or whose download fails) get a drawn one.
  final Map<int, String> coverUrls;

  const DemoDataset({
    required this.tags,
    required this.books,
    required this.sessions,
    required this.bookTags,
    required this.goals,
    required this.goalTargets,
    required this.planner,
    required this.coverUrls,
  });
}

// ── Catalogue ───────────────────────────────────────────────────────────────
// Public-domain titles only. Narrators are invented.

const _paperback = 1;
const _hardback = 2;
const _ebook = 3;
const _audiobook = 4;

class _Title {
  final String title;
  final String author;
  final int pages;
  final int format;
  final List<String> tags;
  final int minutes;
  final String? narrator;
  final String? series;
  final double? position;

  const _Title(this.title, this.author, this.pages, this.format, this.tags,
      {this.minutes = 0, this.narrator, this.series, this.position});

  bool get isAudio => format == _audiobook;
}

const _tagColors = {
  'Classic': 0xFF8D6E63,
  'Romance': 0xFFE57373,
  'Adventure': 0xFF4DB6AC,
  'Science Fiction': 0xFF64B5F6,
  'Horror': 0xFF9575CD,
  'Mystery': 0xFFFFB74D,
  'Philosophy': 0xFF90A4AE,
  'Nonfiction': 0xFF81C784,
};

/// Finished on the print track, oldest first.
const _printFinished = [
  _Title('Pride and Prejudice', 'Jane Austen', 432, _paperback, ['Classic', 'Romance']),
  _Title('The Time Machine', 'H. G. Wells', 118, _ebook, ['Science Fiction', 'Classic']),
  _Title('Dracula', 'Bram Stoker', 418, _paperback, ['Horror', 'Classic']),
  _Title('The Hound of the Baskervilles', 'Arthur Conan Doyle', 256, _paperback, ['Mystery'],
      series: 'Sherlock Holmes', position: 3),
  _Title('Frankenstein', 'Mary Shelley', 280, _hardback, ['Horror', 'Science Fiction']),
  _Title('Great Expectations', 'Charles Dickens', 544, _paperback, ['Classic']),
  _Title('Meditations', 'Marcus Aurelius', 254, _ebook, ['Philosophy', 'Nonfiction']),
  _Title('Jane Eyre', 'Charlotte Brontë', 532, _paperback, ['Classic', 'Romance']),
  _Title('Treasure Island', 'Robert Louis Stevenson', 292, _paperback, ['Adventure']),
  _Title('The War of the Worlds', 'H. G. Wells', 192, _ebook, ['Science Fiction']),
  _Title('Middlemarch', 'George Eliot', 880, _hardback, ['Classic']),
  _Title('The Moonstone', 'Wilkie Collins', 528, _paperback, ['Mystery']),
  _Title('The Picture of Dorian Gray', 'Oscar Wilde', 254, _paperback, ['Classic', 'Horror']),
  _Title('Walden', 'Henry David Thoreau', 352, _ebook, ['Nonfiction', 'Philosophy']),
  _Title('Twenty Thousand Leagues Under the Seas', 'Jules Verne', 432, _paperback, ['Adventure', 'Science Fiction']),
  _Title('Crime and Punishment', 'Fyodor Dostoevsky', 671, _hardback, ['Classic']),
  _Title('The Turn of the Screw', 'Henry James', 120, _ebook, ['Horror']),
  _Title('A Study in Scarlet', 'Arthur Conan Doyle', 188, _paperback, ['Mystery'],
      series: 'Sherlock Holmes', position: 1),
  _Title('Little Women', 'Louisa May Alcott', 449, _paperback, ['Classic']),
  _Title('The Great Gatsby', 'F. Scott Fitzgerald', 180, _paperback, ['Classic']),
  _Title('The Woman in White', 'Wilkie Collins', 720, _hardback, ['Mystery']),
  _Title('Persuasion', 'Jane Austen', 249, _ebook, ['Romance', 'Classic']),
];

/// Finished on the audio track, oldest first.
const _audioFinished = [
  _Title('Adventures of Huckleberry Finn', 'Mark Twain', 0, _audiobook, ['Adventure', 'Classic'],
      minutes: 680, narrator: 'Eleanor Hale'),
  _Title('Around the World in Eighty Days', 'Jules Verne', 0, _audiobook, ['Adventure'],
      minutes: 420, narrator: 'Marcus Webb'),
  _Title('Strange Case of Dr Jekyll and Mr Hyde', 'Robert Louis Stevenson', 0, _audiobook, ['Horror'],
      minutes: 170, narrator: 'Eleanor Hale'),
  _Title('The Call of the Wild', 'Jack London', 0, _audiobook, ['Adventure'],
      minutes: 190, narrator: 'Thomas Reyes'),
  _Title('Narrative of the Life of Frederick Douglass', 'Frederick Douglass', 0, _audiobook, ['Nonfiction'],
      minutes: 230, narrator: 'Daniel Okafor'),
];

const _printCurrent = [
  _Title('The Brothers Karamazov', 'Fyodor Dostoevsky', 796, _paperback, ['Classic']),
  _Title('Emma', 'Jane Austen', 474, _ebook, ['Romance', 'Classic']),
];

const _audioCurrent = _Title('The Three Musketeers', 'Alexandre Dumas', 0, _audiobook, ['Adventure'],
    series: "The d'Artagnan Romances", position: 1,
    minutes: 1680, narrator: 'Marcus Webb');

const _setAside = [
  _Title('The Count of Monte Cristo', 'Alexandre Dumas', 1276, _hardback, ['Adventure']),
  _Title('Don Quixote', 'Miguel de Cervantes', 1072, _paperback, ['Classic', 'Adventure']),
];

const _wantToRead = [
  _Title('Anna Karenina', 'Leo Tolstoy', 864, _paperback, ['Classic', 'Romance']),
  _Title('Wuthering Heights', 'Emily Brontë', 416, _paperback, ['Classic', 'Romance']),
  _Title('The Odyssey', 'Homer', 541, _paperback, ['Classic', 'Adventure']),
  _Title('The Souls of Black Folk', 'W. E. B. Du Bois', 288, _ebook, ['Nonfiction']),
  _Title('The Mysterious Affair at Styles', 'Agatha Christie', 296, _paperback, ['Mystery']),
  _Title('The Art of War', 'Sun Tzu', 112, _ebook, ['Philosophy', 'Nonfiction']),
  // Series named in the title and left unlinked, the way Goodreads-era data
  // arrives — "Find series in titles" should link it and fill the #2 gap.
  _Title('The Sign of the Four (Sherlock Holmes #2)', 'Arthur Conan Doyle', 166, _paperback, ['Mystery']),
  // Waiting after the audiobook in progress, so finishing that one has a
  // "Next in series" to offer.
  _Title('Twenty Years After', 'Alexandre Dumas', 880, _paperback, ['Adventure'],
      series: "The d'Artagnan Romances", position: 2),
];

/// Open Library cover id and work key for each title, looked up once so every
/// load shows the same edition. Covers are downloaded when the demo loads —
/// the same source the app's own cover search uses — never bundled.
const _openLibrary = <String, (int, String)>{
  'Twenty Years After': (14634038, '/works/OL36462W'),
  'The Sign of the Four (Sherlock Holmes #2)': (9247987, '/works/OL262438W'),
  'Pride and Prejudice': (14665299, '/works/OL66554W'),
  'The Time Machine': (9008368, '/works/OL52267W'),
  'Dracula': (12216503, '/works/OL85892W'),
  'The Hound of the Baskervilles': (8063264, '/works/OL262454W'),
  'Frankenstein': (12356249, '/works/OL450063W'),
  'Great Expectations': (14972723, '/works/OL8721462W'),
  'Meditations': (211529, '/works/OL1317211W'),
  'Jane Eyre': (8235363, '/works/OL1095427W'),
  'Treasure Island': (13859660, '/works/OL24034W'),
  'The War of the Worlds': (36314, '/works/OL52114W'),
  'Middlemarch': (252882, '/works/OL20867W'),
  'The Moonstone': (8237041, '/works/OL176092W'),
  'The Picture of Dorian Gray': (12244074, '/works/OL8193416W'),
  'Walden': (11248037, '/works/OL55649W'),
  'Twenty Thousand Leagues Under the Seas': (10817535, '/works/OL24304873W'),
  'Crime and Punishment': (15183762, '/works/OL45018229W'),
  'The Turn of the Screw': (181493, '/works/OL276386W'),
  'A Study in Scarlet': (13405534, '/works/OL262496W'),
  'Little Women': (8775559, '/works/OL29983W'),
  'The Great Gatsby': (10590366, '/works/OL468431W'),
  'The Woman in White': (4684227, '/works/OL176045W'),
  'Persuasion': (15259107, '/works/OL66544W'),
  'Adventures of Huckleberry Finn': (8157718, '/works/OL53908W'),
  'Around the World in Eighty Days': (11531296, '/works/OL24776232W'),
  'Strange Case of Dr Jekyll and Mr Hyde': (295773, '/works/OL24156W'),
  'The Call of the Wild': (12393037, '/works/OL14942956W'),
  'Narrative of the Life of Frederick Douglass': (14785220, '/works/OL69178W'),
  'The Brothers Karamazov': (11263774, '/works/OL24600223W'),
  'Emma': (9278312, '/works/OL66513W'),
  'The Three Musketeers': (15079464, '/works/OL38438001W'),
  'The Count of Monte Cristo': (8851690, '/works/OL20201553W'),
  'Don Quixote': (13846974, '/works/OL26799707W'),
  'Wuthering Heights': (12818862, '/works/OL21177W'),
  'The Odyssey': (12474938, '/works/OL26446888W'),
  'The Souls of Black Folk': (6564090, '/works/OL28577W'),
  'The Mysterious Affair at Styles': (13699667, '/works/OL472715W'),
  'The Art of War': (4849549, '/works/OL244537W'),
  'Anna Karenina': (2560652, '/works/OL267096W'),
};

const _reviews = [
  'Slow first half, but the ending made every page worth it.',
  'Characters I\'ll be thinking about for a long time.',
  'Beautifully written. I kept stopping to reread sentences.',
  'Tense, atmospheric, and over far too quickly.',
  'Funnier than I expected, and sharper too.',
  'A comfort read. Exactly what I needed this month.',
  'Dense in places, but rewarding if you give it time.',
];
const _lowReview = 'Not for me — I admired it more than I enjoyed it.';

const _notes = [
  'Couldn\'t put it down tonight.',
  'Slow chapter, but it picked up at the end.',
  'Reread the last few pages twice.',
  'Read on the train.',
  'Finally starting to get into it.',
  'Stayed up later than I meant to.',
];

// ── Generator ───────────────────────────────────────────────────────────────

class _Generator {
  final DateTime now;
  final DateTime today;
  final Random rng = Random(20260101);

  final tags = <Tag>[];
  final tagIds = <String, int>{};
  final books = <Book>[];
  final sessions = <Session>[];
  final bookTags = <BookTag>[];
  final coverUrls = <int, String>{};

  /// Two quiet spells, so the longest weekly streak is a run, not everything.
  late final List<(DateTime, DateTime)> breaks = [
    (today.subtract(const Duration(days: 430)), today.subtract(const Duration(days: 414))),
    (today.subtract(const Duration(days: 205)), today.subtract(const Duration(days: 193))),
  ];

  _Generator(this.now) : today = DateTime(now.year, now.month, now.day);

  DateTime get trackStart => DateTime(today.year - 2, today.month, today.day)
      .add(const Duration(days: 5));

  DemoDataset build() {
    var id = 1;
    for (final MapEntry(key: name, value: color) in _tagColors.entries) {
      tags.add(Tag(id: id, name: name, color: color));
      tagIds[name] = id++;
    }

    _buildPrintTrack();
    _buildAudioTrack();
    _buildCurrent();
    _buildSetAside();
    final planner = _buildWantToRead();

    sessions.sort((a, b) => a.date.compareTo(b.date));
    final (goals, targets) = _buildGoals();

    return DemoDataset(
      tags: tags,
      books: books,
      sessions: sessions,
      bookTags: bookTags,
      goals: goals,
      goalTargets: targets,
      planner: planner,
      coverUrls: coverUrls,
    );
  }

  // ── Tracks ─────────────────────────────────────────────────────────────────

  /// Finished print books, back to back, each given a window of days in
  /// proportion to its length, ending where the current reads begin.
  void _buildPrintTrack() {
    final end = today.subtract(const Duration(days: 27));
    final totalDays = end.difference(trackStart).inDays;
    final totalPages = _printFinished.fold(0, (s, t) => s + t.pages);

    var cursor = trackStart;
    for (var i = 0; i < _printFinished.length; i++) {
      final t = _printFinished[i];
      final days = max(3, (totalDays * t.pages / totalPages).round() - 1);
      final windowEnd = cursor.add(Duration(days: days));
      final readDays = _readDays(cursor, windowEnd, weekday: 0.72, weekend: 0.85);
      final logged = _logPrint(books.length + 1, t.pages, readDays);
      // The first evening's worth of books went in together.
      final added = i < 10
          ? trackStart.subtract(const Duration(days: 2)).add(Duration(hours: 20, minutes: i * 3))
          : _addedBefore(logged.first);
      _addBook(t, DatabaseHelper.shelfFinished,
          added: added, started: logged.first, finished: logged.last, rated: true);
      cursor = windowEnd.add(Duration(days: 1 + rng.nextInt(2)));
    }
  }

  /// Finished audiobooks, spread across the same span on weekday mornings.
  void _buildAudioTrack() {
    final span = today.subtract(const Duration(days: 40)).difference(trackStart).inDays;
    final spacing = span ~/ _audioFinished.length;
    for (var i = 0; i < _audioFinished.length; i++) {
      final t = _audioFinished[i];
      final start = trackStart.add(Duration(days: i * spacing + 12));
      final logged = _logAudio(books.length + 1, t.minutes, start, t.minutes);
      _addBook(t, DatabaseHelper.shelfFinished,
          added: i == 0
              ? trackStart.subtract(const Duration(days: 2)).add(const Duration(hours: 20, minutes: 40))
              : _addedBefore(logged.first),
          started: logged.first,
          finished: logged.last,
          rated: true);
    }
  }

  void _buildCurrent() {
    final starts = [27, 9];
    final shares = [0.55, 0.3];
    for (var i = 0; i < _printCurrent.length; i++) {
      final t = _printCurrent[i];
      final readDays = _readDays(today.subtract(Duration(days: starts[i])), today,
          weekday: 0.55, weekend: 0.6);
      if (i == 0) {
        // Always some reading yesterday and today, so this week's goal and the
        // "today" views have something in them whatever day the demo loads.
        final yesterday = today.subtract(const Duration(days: 1));
        readDays.removeWhere((d) => d == yesterday || d == today);
        readDays.addAll([yesterday, today]);
      }
      final logged = _logPrint(books.length + 1, (t.pages * shares[i]).round(), readDays);
      _addBook(t, DatabaseHelper.shelfCurrentlyReading,
          added: _addedBefore(logged.first), started: logged.first);
    }

    final t = _audioCurrent;
    final logged = _logAudio(books.length + 1, (t.minutes * 0.6).round(),
        today.subtract(const Duration(days: 15)), t.minutes);
    _addBook(t, DatabaseHelper.shelfCurrentlyReading,
        added: _addedBefore(logged.first), started: logged.first);
  }

  void _buildSetAside() {
    const plans = [(300, 12, 210), (520, 9, 140)]; // days ago, window, pages
    for (var i = 0; i < _setAside.length; i++) {
      final t = _setAside[i];
      final (ago, window, pages) = plans[i];
      final start = today.subtract(Duration(days: ago));
      final readDays = _readDays(start, start.add(Duration(days: window)),
          weekday: 0.6, weekend: 0.7);
      final logged = _logPrint(books.length + 1, pages, readDays);
      _addBook(t, DatabaseHelper.shelfUnfinished,
          added: _addedBefore(logged.first), started: logged.first);
    }
  }

  List<Map<String, dynamic>> _buildWantToRead() {
    final planner = <Map<String, dynamic>>[];
    for (var i = 0; i < _wantToRead.length; i++) {
      final added = _at(today.subtract(Duration(days: 8 + rng.nextInt(190))), 21, rng.nextInt(50));
      _addBook(_wantToRead[i], DatabaseHelper.shelfWantToRead, added: added);
      if (i < 3) {
        planner.add({
          'book_id': books.last.id,
          'date_added': added.add(Duration(days: 1 + i)).toIso8601String(),
        });
      }
    }
    return planner;
  }

  // ── Goals ──────────────────────────────────────────────────────────────────

  (List<Map<String, dynamic>>, List<Map<String, dynamic>>) _buildGoals() {
    final goals = <Map<String, dynamic>>[];
    final targets = <Map<String, dynamic>>[];

    void goal(GoalMetric metric, GoalPeriod period, DateTime created,
        List<(DateTime, int)> changes) {
      final id = goals.length + 1;
      goals.add({
        'id': id,
        'metric': metric.dbValue,
        'period': period.dbValue,
        'target': changes.last.$2,
        'created_at': created.toIso8601String(),
      });
      for (final (from, target) in changes) {
        targets.add({
          'goal_id': id,
          'target': target,
          'effective_from': _ymd(GoalRepository.periodStartOf(period, from)),
        });
      }
    }

    final weeklyCreated = _at(today.subtract(const Duration(days: 200)), 9, 15);
    goal(GoalMetric.timeReading, GoalPeriod.weekly, weeklyCreated, [
      (weeklyCreated, 120),
      (today.subtract(const Duration(days: 70)), 180),
    ]);

    final monthlyCreated = _at(today.subtract(const Duration(days: 150)), 20, 5);
    goal(GoalMetric.pagesRead, GoalPeriod.monthly, monthlyCreated, [
      (monthlyCreated, 600),
    ]);

    final yearlyCreated = DateTime(today.year - 1, 1, 3, 10);
    goal(GoalMetric.booksFinished, GoalPeriod.yearly, yearlyCreated, [
      (yearlyCreated, 12),
      (DateTime(today.year, 1, 1), 15),
    ]);

    // One session short of this week's target, whatever day the demo loads:
    // log a session and the goal celebration plays.
    final weekStart = GoalRepository.periodStartOf(GoalPeriod.weekly, today);
    final thisWeek = sessions
        .where((s) => !DateTime.parse(s.date).isBefore(weekStart))
        .length;
    final sessionsCreated = _at(today.subtract(const Duration(days: 45)), 8, 30);
    goal(GoalMetric.sessions, GoalPeriod.weekly, sessionsCreated, [
      (sessionsCreated, thisWeek + 1),
    ]);

    return (goals, targets);
  }

  // ── Sessions ───────────────────────────────────────────────────────────────

  /// Days in [start, end] the reader picks the book up, skipping the breaks.
  List<DateTime> _readDays(DateTime start, DateTime end,
      {required double weekday, required double weekend}) {
    final days = <DateTime>[];
    for (var d = start; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
      final day = DateTime(d.year, d.month, d.day);
      if (_inBreak(day)) continue;
      final isWeekend = day.weekday >= DateTime.saturday;
      if (rng.nextDouble() < (isWeekend ? weekend : weekday)) days.add(day);
    }
    if (days.isEmpty) days.add(DateTime(start.year, start.month, start.day));
    return days;
  }

  /// Spreads [pages] over [days] and logs the sessions; returns their times.
  List<DateTime> _logPrint(int bookId, int pages, List<DateTime> days) {
    final split = _split(pages, days.length);
    final times = <DateTime>[];
    for (var i = 0; i < days.length; i++) {
      final at = _clampToNow(_printTime(days[i]));
      if (at == null || split[i] <= 0) continue;
      // Mostly 25–50 pages an hour, with the odd quick sitting.
      final perPage = rng.nextDouble() < 0.05 ? 0.75 : 1.2 + rng.nextDouble() * 1.2;
      // Capped at three and a half hours — long sittings, not all-nighters.
      _session(bookId, at, split[i], min(210, max(5, (split[i] * perPage).round())));
      times.add(at);
    }
    if (times.isEmpty) {
      // Every planned day fell after now; log it all the evening before.
      final at = _at(today.subtract(const Duration(days: 1)), 20, 0);
      _session(bookId, at, pages, max(5, (pages * 1.6).round()));
      times.add(at);
    }
    return times;
  }

  /// Weekday-morning listening from [start] until [minutes] are logged.
  List<DateTime> _logAudio(int bookId, int minutes, DateTime start, int bookMinutes) {
    final count = max(1, (minutes / 38).ceil());
    final split = _split(minutes, count);
    final times = <DateTime>[];
    var day = DateTime(start.year, start.month, start.day);
    var i = 0;
    while (i < count && !day.isAfter(today)) {
      final weekday = day.weekday < DateTime.saturday;
      if (!_inBreak(day) && weekday && rng.nextDouble() < 0.8) {
        final at = _clampToNow(_at(day, 7, 30 + rng.nextInt(70)));
        if (at != null) {
          _session(bookId, at, 0, split[i]);
          times.add(at);
          i++;
        }
      }
      day = day.add(const Duration(days: 1));
    }
    if (times.isEmpty) {
      final at = _at(DateTime(start.year, start.month, start.day), 8, 0);
      _session(bookId, at, 0, minutes);
      times.add(at);
    }
    return times;
  }

  void _session(int bookId, DateTime at, int pages, int minutes) {
    sessions.add(Session(
      bookId: bookId,
      pagesRead: pages,
      durationMinutes: minutes,
      date: at.toIso8601String(),
      notes: rng.nextDouble() < 0.07 ? _notes[rng.nextInt(_notes.length)] : null,
    ));
  }

  /// Evenings on weekdays, with mornings and lunch breaks mixed in; weekends
  /// spread across the day. Gives the time-of-day charts something to show.
  DateTime _printTime(DateTime day) {
    final r = rng.nextDouble();
    if (day.weekday >= DateTime.saturday) {
      if (r < 0.25) return _at(day, 8 + rng.nextInt(2), rng.nextInt(60));
      if (r < 0.65) return _at(day, 13 + rng.nextInt(4), rng.nextInt(60));
      return _at(day, 20 + rng.nextInt(3), rng.nextInt(60));
    }
    if (r < 0.15) return _at(day, 6, 30 + rng.nextInt(60));
    if (r < 0.3) return _at(day, 12, 10 + rng.nextInt(40));
    return _at(day, 19, 30 + rng.nextInt(250));
  }

  /// Nothing in the future: today's session lands before now or not at all.
  DateTime? _clampToNow(DateTime at) {
    if (at.isBefore(now)) return at;
    final earlier = now.subtract(const Duration(minutes: 30));
    final sameDay = earlier.year == at.year &&
        earlier.month == at.month &&
        earlier.day == at.day;
    return sameDay ? earlier : null;
  }

  /// [total] split into [n] uneven positive parts that sum exactly.
  List<int> _split(int total, int n) {
    if (n <= 0) return const [];
    final weights = List.generate(n, (_) => 0.5 + rng.nextDouble());
    final sum = weights.fold(0.0, (a, b) => a + b);
    final parts = [for (final w in weights) max(1, (total * w / sum).floor())];
    parts[n - 1] += total - parts.fold(0, (a, b) => a + b);
    if (parts[n - 1] < 1) parts[n - 1] = 1;
    return parts;
  }

  bool _inBreak(DateTime day) =>
      breaks.any((b) => !day.isBefore(b.$1) && !day.isAfter(b.$2));

  // ── Books ──────────────────────────────────────────────────────────────────

  void _addBook(
    _Title t,
    int shelf, {
    required DateTime added,
    DateTime? started,
    DateTime? finished,
    bool rated = false,
  }) {
    final id = books.length + 1;
    final finishedIndex = books.where((b) => b.shelfId == DatabaseHelper.shelfFinished).length;

    double? rating;
    String? review;
    if (rated && finishedIndex % 9 != 4) {
      const pool = [4.0, 4.5, 3.5, 5.0, 4.0, 3.0, 4.5, 5.0, 2.5, 4.0];
      rating = pool[rng.nextInt(pool.length)];
      if (finishedIndex % 3 == 0) {
        review = rating <= 3 ? _lowReview : _reviews[finishedIndex ~/ 3 % _reviews.length];
      }
    }

    // A few books stay bare so the no-cover layouts get exercised too.
    final hasCover = id % 12 != 5;
    final openLibrary = _openLibrary[t.title];
    if (hasCover && openLibrary != null) {
      // default=false makes a missing cover a 404 rather than a blank image.
      coverUrls[id] =
          'https://covers.openlibrary.org/b/id/${openLibrary.$1}-L.jpg?default=false';
    }

    books.add(Book(
      id: id,
      title: t.title,
      author: t.author,
      pageCount: t.isAudio ? null : t.pages,
      rating: rating,
      isFavorite: (rating ?? 0) >= 4.5 && finishedIndex % 3 != 1,
      bookTypeId: t.format,
      dateAdded: added.toIso8601String(),
      dateStarted: started?.toIso8601String(),
      dateFinished: finished?.toIso8601String(),
      userReview: review,
      durationMinutes: t.isAudio ? t.minutes : null,
      shelfId: shelf,
      coverPath: hasCover ? '$id.jpg' : null,
      openLibraryKey: openLibrary?.$2,
      coverShape: t.isAudio
          ? DatabaseHelper.coverShapeSquare
          : DatabaseHelper.coverShapePortrait,
      narrator: t.narrator,
      // Resolved to a series id by the loader.
      seriesName: t.series,
      seriesPosition: t.position,
    ));
    for (final tag in t.tags) {
      bookTags.add(BookTag(bookId: id, tagId: tagIds[tag]!));
    }
  }

  /// Added to the library a few days to a few weeks before being started.
  DateTime _addedBefore(DateTime started) {
    final day = started.subtract(Duration(days: 1 + rng.nextInt(40)));
    final floor = trackStart.subtract(const Duration(days: 2));
    final d = day.isBefore(floor) ? floor : day;
    return _at(d, 21, rng.nextInt(55));
  }

  static DateTime _at(DateTime day, int hour, int minute) =>
      DateTime(day.year, day.month, day.day, hour, minute);

  static String _ymd(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
