import 'year_wrapped.dart';

/// The reader types Wrapped can name. Each one is a measurable claim with a
/// threshold and a minimum amount of evidence — never a label handed out to
/// fill the slide.
enum PersonalityTrait {
  nightOwl,
  earlyBird,
  weekendReader,
  marathonReader,
  speedReader,
  audiobookDevotee,
  consistentReader,
  bookworm,
}

/// A year's reader personality: which trait won, and the figure that earned it.
class ReaderPersonality {
  final PersonalityTrait trait;

  /// How far past its threshold the trait landed — 1.0 is exactly on it. Used
  /// to pick between traits; not shown.
  final double score;

  /// The line that proves it, e.g. "62% of your reading started after 10pm".
  final String evidence;

  const ReaderPersonality({
    required this.trait,
    required this.score,
    required this.evidence,
  });

  String get title => switch (trait) {
        PersonalityTrait.nightOwl => 'The Night Owl',
        PersonalityTrait.earlyBird => 'The Early Bird',
        PersonalityTrait.weekendReader => 'The Weekend Reader',
        PersonalityTrait.marathonReader => 'The Marathon Reader',
        PersonalityTrait.speedReader => 'The Speed Reader',
        PersonalityTrait.audiobookDevotee => 'The Audiobook Devotee',
        PersonalityTrait.consistentReader => 'The Consistent Reader',
        PersonalityTrait.bookworm => 'The Bookworm',
      };

  String get tagline => switch (trait) {
        PersonalityTrait.nightOwl => 'Your best chapters happen after dark.',
        PersonalityTrait.earlyBird =>
          'You read before the rest of the world wakes up.',
        PersonalityTrait.weekendReader =>
          'Saturdays and Sundays belong to your books.',
        PersonalityTrait.marathonReader =>
          'When you sit down with a book, you stay.',
        PersonalityTrait.speedReader => 'The pages fly when you read.',
        PersonalityTrait.audiobookDevotee =>
          'Your stories come with a voice.',
        PersonalityTrait.consistentReader =>
          'Week after week, you showed up.',
        PersonalityTrait.bookworm => 'One finished, another one opened.',
      };

  /// The strongest trait the year qualifies for, or null when none does — in
  /// which case there is no personality slide rather than an invented one.
  static ReaderPersonality? of(YearWrapped w) {
    final candidates = <ReaderPersonality>[];

    void consider(
      PersonalityTrait trait,
      double value,
      double threshold,
      String evidence,
    ) {
      if (threshold <= 0 || value < threshold) return;
      candidates.add(ReaderPersonality(
        trait: trait,
        score: value / threshold,
        evidence: evidence,
      ));
    }

    String pct(double share) => '${(share * 100).round()}%';

    // Time of day — weighted by minutes where there are any, by session count
    // for a reader who doesn't time sessions. Midnight-stamped imports carry
    // no clock and are already left out of these maps.
    if (w.clockedSessions >= 10) {
      final byMinutes = w.daypartMinutes.values.any((v) => v > 0);
      final source = byMinutes ? w.daypartMinutes : w.daypartSessions;
      final total = source.values.fold(0, (a, b) => a + b);
      if (total > 0) {
        // Daypart 3 is Night (10pm–5am) and 0 is Morning (5am–noon) — see
        // daypartOf in reading_clock.dart.
        final night = (source[3] ?? 0) / total;
        final morning = (source[0] ?? 0) / total;
        consider(PersonalityTrait.nightOwl, night, 0.4,
            '${pct(night)} of your reading started after 10pm.');
        consider(PersonalityTrait.earlyBird, morning, 0.4,
            '${pct(morning)} of your reading started before noon.');
      }
    }

    // Weekends — two days of seven is 29%, so 60% is a real lean.
    if (w.sessions >= 10) {
      final byMinutes = w.minutes > 0;
      final source = byMinutes ? w.weekdayMinutes : w.weekdaySessions;
      final total = source.values.fold(0, (a, b) => a + b);
      if (total > 0) {
        final weekend = ((source[DateTime.saturday] ?? 0) +
                (source[DateTime.sunday] ?? 0)) /
            total;
        consider(PersonalityTrait.weekendReader, weekend, 0.6,
            '${pct(weekend)} of your reading happened on weekends.');
      }
    }

    if (w.timedSessions >= 10) {
      final avg = w.avgSessionMinutes;
      consider(PersonalityTrait.marathonReader, avg.toDouble(), 60,
          'Your average session ran ${YearWrapped.formatMinutes(avg)}.');
    }

    // Five hours of paged, timed print reading before a speed means anything.
    if (w.speedMinutes >= 300) {
      final pph = w.pagesPerHour;
      consider(PersonalityTrait.speedReader, pph.toDouble(), 60,
          'You averaged $pph pages an hour.');
    }

    if (w.booksFinished >= 3) {
      final audio = w.formatCounts[WrappedFormat.audio] ?? 0;
      consider(PersonalityTrait.audiobookDevotee, audio / w.booksFinished, 0.5,
          '$audio of your ${w.booksFinished} books were audiobooks.');
    }

    if (w.weeksSpanned >= 8) {
      final share = w.activeWeeks / w.weeksSpanned;
      consider(PersonalityTrait.consistentReader, share, 0.75,
          'You read in ${w.activeWeeks} of ${w.weeksSpanned} weeks.');
    }

    if (w.booksFinished >= 24) {
      final every = (w.daysElapsed / w.booksFinished).round();
      consider(PersonalityTrait.bookworm, w.booksFinished.toDouble(), 24,
          '${w.booksFinished} books — one every $every days.');
    }

    if (candidates.isEmpty) return null;
    candidates.sort((a, b) => b.score.compareTo(a.score));
    return candidates.first;
  }
}
