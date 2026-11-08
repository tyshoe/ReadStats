import 'dart:math' as math;

import 'package:flutter/material.dart';

import '/data/models/year_wrapped.dart';
import '../wrapped_style.dart';
import 'wrapped_slide_view.dart';

// ── The big ones ─────────────────────────────────────────────────────────────

class BigBooksSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const BigBooksSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;
    final longest = w.longestBook;
    final shortest = w.shortestBook;
    final mostTime = w.mostTimeBook;

    // Lead with the longest book when there are two lengths to compare;
    // otherwise the book that took the most time is the story.
    final leadIsLength = longest != null && shortest != null;
    final hero = leadIsLength ? longest : mostTime!;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('The big ones', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text(
            leadIsLength ? 'Your biggest\nread.' : 'The book that\nhad you hooked.',
            style: WrappedType.headline(context, size: 34),
          ),
        ),
        const Spacer(),
        Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            Reveal(
              animation: a,
              start: 0.12,
              end: 0.55,
              lift: 48,
              child: Transform.rotate(
                angle: -0.05,
                child: WrappedCover(book: hero, width: 132, palette: palette),
              ),
            ),
            const SizedBox(width: 20),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: CountUp(
                      animation: a,
                      value: leadIsLength ? hero.pages : hero.minutes,
                      format: leadIsLength
                          ? YearWrapped.formatNumber
                          : YearWrapped.formatMinutes,
                      start: 0.25,
                      end: 0.8,
                      style: WrappedType.hero(context,
                          size: 60, color: palette.accent),
                    ),
                  ),
                  Reveal(
                    animation: a,
                    start: 0.3,
                    end: 0.7,
                    child: Text(
                      leadIsLength ? 'pages' : 'spent with it this year',
                      style: WrappedType.body(context),
                    ),
                  ),
                  const SizedBox(height: 14),
                  Reveal(
                    animation: a,
                    start: 0.35,
                    end: 0.75,
                    child: _TitleBlock(book: hero),
                  ),
                ],
              ),
            ),
          ],
        ),
        const Spacer(),
        if (leadIsLength)
          Reveal(
            animation: a,
            start: 0.55,
            end: 0.9,
            child: _SideBook(
              book: shortest,
              palette: palette,
              label: 'Your shortest',
              value: YearWrapped.plural(shortest.pages, 'page'),
            ),
          ),
        if (mostTime != null && mostTime.id != hero.id) ...[
          const SizedBox(height: 12),
          Reveal(
            animation: a,
            start: 0.65,
            end: 1,
            child: _SideBook(
              book: mostTime,
              palette: palette,
              label: 'Most time spent',
              value: YearWrapped.formatMinutes(mostTime.minutes),
            ),
          ),
        ] else if (!leadIsLength && longest != null && longest.id != hero.id) ...[
          const SizedBox(height: 12),
          Reveal(
            animation: a,
            start: 0.65,
            end: 1,
            child: _SideBook(
              book: longest,
              palette: palette,
              label: 'Your biggest read',
              value: YearWrapped.plural(longest.pages, 'page'),
            ),
          ),
        ],
      ],
    );
  }
}

class _TitleBlock extends StatelessWidget {
  final WrappedBook book;
  final TextAlign align;

  const _TitleBlock({required this.book, this.align = TextAlign.start});

  @override
  Widget build(BuildContext context) {
    final cross = align == TextAlign.center
        ? CrossAxisAlignment.center
        : CrossAxisAlignment.start;
    return Column(
      crossAxisAlignment: cross,
      children: [
        Text(book.title,
            maxLines: 3,
            overflow: TextOverflow.ellipsis,
            textAlign: align,
            style: WrappedType.title(context)),
        if (book.author.isNotEmpty) ...[
          const SizedBox(height: 4),
          Text(book.author,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              textAlign: align,
              style: WrappedType.caption(context, alpha: 0.75)),
        ],
      ],
    );
  }
}

/// A supporting book on a slide: small cover, what it was, and its figure.
class _SideBook extends StatelessWidget {
  final WrappedBook book;
  final WrappedPalette palette;
  final String label;
  final String value;

  const _SideBook({
    required this.book,
    required this.palette,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.09),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          WrappedCover(book: book, width: 40, palette: palette),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label.toUpperCase(),
                    style: WrappedType.eyebrow(context).copyWith(fontSize: 10)),
                const SizedBox(height: 3),
                Text(book.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: WrappedType.title(context, size: 16)),
              ],
            ),
          ),
          const SizedBox(width: 10),
          Text(value,
              style: WrappedType.title(context, size: 16)
                  .copyWith(color: palette.accent)),
        ],
      ),
    );
  }
}

// ── Book of the year ─────────────────────────────────────────────────────────

class BookOfYearSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const BookOfYearSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final pick = env.w.bookOfTheYear;
    if (pick == null) return _ShelfSlide(env: env, palette: palette);

    final w = env.w;
    final a = env.entrance;
    final (book, reason) = pick;
    final also = w.alsoLoved;
    final highShare = w.highRatedShare;

    final reasonText = switch (reason) {
      BookOfYearReason.favorite => book.isRated
          ? 'A favorite, rated ${book.rating.toStringAsFixed(1)}★'
          : 'Marked as a favorite',
      BookOfYearReason.topRated =>
        'Your highest rated — ${book.rating.toStringAsFixed(1)}★',
      BookOfYearReason.mostTime =>
        'The one you spent the most time with — '
            '${YearWrapped.formatMinutes(book.minutes)}',
      BookOfYearReason.onlyBook => 'The one you finished this year',
    };

    final scale = CurvedAnimation(
      parent: a,
      curve: const Interval(0.05, 0.6, curve: Curves.easeOutBack),
    );

    return Column(
      children: [
        SizedBox(
          width: double.infinity,
          child: SlideEyebrow('Book of the year', entrance: a),
        ),
        const Spacer(),
        Stack(
          alignment: Alignment.center,
          children: [
            // A halo behind the cover, in the slide's accent.
            Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  palette.accent.withValues(alpha: 0.4),
                  palette.accent.withValues(alpha: 0),
                ]),
              ),
            ),
            AnimatedBuilder(
              animation: scale,
              builder: (context, child) => Opacity(
                opacity: scale.value.clamp(0.0, 1.0),
                child: Transform.scale(
                    scale: 0.7 + 0.3 * scale.value, child: child),
              ),
              child: WrappedCover(book: book, width: 150, palette: palette),
            ),
          ],
        ),
        const SizedBox(height: 18),
        Reveal(
          animation: a,
          start: 0.35,
          end: 0.7,
          child: _TitleBlock(book: book, align: TextAlign.center),
        ),
        const SizedBox(height: 10),
        if (book.isRated)
          Reveal(
            animation: a,
            start: 0.42,
            end: 0.75,
            child: WrappedStars(rating: book.rating, size: 22),
          ),
        const SizedBox(height: 10),
        Reveal(
          animation: a,
          start: 0.48,
          end: 0.8,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 7),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(reasonText,
                textAlign: TextAlign.center,
                style: WrappedType.caption(context, alpha: 0.95)
                    .copyWith(fontWeight: FontWeight.w600)),
          ),
        ),
        const Spacer(),
        if (also.isNotEmpty)
          Reveal(
            animation: a,
            start: 0.6,
            end: 1,
            child: Column(
              children: [
                Text('ALSO LOVED',
                    style: WrappedType.eyebrow(context).copyWith(fontSize: 10)),
                const SizedBox(height: 10),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    for (final b in also)
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Column(
                          children: [
                            WrappedCover(book: b, width: 50, palette: palette),
                            const SizedBox(height: 6),
                            Text('${b.rating.toStringAsFixed(1)}★',
                                style: WrappedType.caption(context, alpha: 0.9)
                                    .copyWith(fontWeight: FontWeight.w700)),
                          ],
                        ),
                      ),
                  ],
                ),
              ],
            ),
          )
        else if (highShare != null)
          Reveal(
            animation: a,
            start: 0.6,
            end: 1,
            child: Text(
              '${(highShare * 100).round()}% of the books you rated got '
              'four stars or more.',
              textAlign: TextAlign.center,
              style: WrappedType.body(context),
            ),
          ),
      ],
    );
  }
}

/// The finished books together, when there is no honest way to pick one.
class _ShelfSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const _ShelfSlide({required this.env, required this.palette});

  static const _maxCovers = 12;

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;
    final books = w.finished.reversed.take(_maxCovers).toList();
    final extra = w.booksFinished - books.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('Your ${w.year} shelf', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text('${w.booksFinished} books\nmade the shelf.',
              style: WrappedType.headline(context, size: 34)),
        ),
        const Spacer(),
        LayoutBuilder(builder: (context, constraints) {
          const columns = 4;
          const gap = 10.0;
          final width =
              (constraints.maxWidth - gap * (columns - 1)) / columns;
          return Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [
              for (var i = 0; i < books.length; i++)
                Reveal(
                  animation: a,
                  start: 0.15 + i * 0.04,
                  end: 0.5 + i * 0.04,
                  child: WrappedCover(
                      book: books[i], width: width, palette: palette),
                ),
            ],
          );
        }),
        const Spacer(),
        if (extra > 0)
          Text('and $extra more', style: WrappedType.body(context)),
      ],
    );
  }
}

// ── Your people ──────────────────────────────────────────────────────────────

class PeopleSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const PeopleSlide({super.key, required this.env, required this.palette});

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;
    final author = w.topAuthor;
    final narrator = w.topNarrator;

    final (String name, List<WrappedBook> books) = author ?? narrator!;
    final isAuthor = author != null;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow(isAuthor ? 'Your author' : 'Your narrator', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text(
            isAuthor
                ? '${books.length} books by'
                : '${books.length} audiobooks read by',
            style: WrappedType.headline(context, size: 28),
          ),
        ),
        const SizedBox(height: 4),
        Reveal(
          animation: a,
          start: 0.1,
          end: 0.5,
          child: Text(name,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
              style: WrappedType.hero(context, size: 48, color: palette.accent)
                  .copyWith(height: 1.0)),
        ),
        const Spacer(),
        Center(child: _CoverFan(books: books, env: env, palette: palette)),
        const Spacer(),
        Reveal(
          animation: a,
          start: 0.55,
          end: 0.9,
          child: Text(
            isAuthor
                ? 'Nobody else took up more of your ${w.year}.'
                : 'The voice you spent the most of ${w.year} with.',
            style: WrappedType.body(context),
          ),
        ),
        if (isAuthor && narrator != null) ...[
          const SizedBox(height: 14),
          Reveal(
            animation: a,
            start: 0.65,
            end: 1,
            child: Row(
              children: [
                Icon(Icons.headphones, size: 18, color: palette.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${narrator.$1} narrated ${narrator.$2.length} of your '
                    'audiobooks.',
                    style: WrappedType.caption(context, alpha: 0.85),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }
}

/// Up to four covers fanned like a hand of cards.
class _CoverFan extends StatelessWidget {
  final List<WrappedBook> books;
  final SlideEnv env;
  final WrappedPalette palette;

  const _CoverFan({
    required this.books,
    required this.env,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final shown = books.take(4).toList();
    const coverWidth = 104.0;
    final n = shown.length;
    final spread = n == 1 ? 0.0 : 0.16;

    return SizedBox(
      height: coverWidth * 1.6,
      width: coverWidth + (n - 1) * 52.0 + 30,
      child: Stack(
        alignment: Alignment.center,
        children: [
          for (var i = 0; i < n; i++)
            AnimatedBuilder(
              animation: env.entrance,
              builder: (context, child) {
                final t = Curves.easeOutCubic.transform(
                    ((env.entrance.value - 0.2 - i * 0.06) / 0.4)
                        .clamp(0.0, 1.0));
                final centered = i - (n - 1) / 2;
                return Opacity(
                  opacity: t,
                  child: Transform.translate(
                    offset: Offset(centered * 52 * t, (1 - t) * 30),
                    child: Transform.rotate(
                      angle: centered * spread * t,
                      child: child,
                    ),
                  ),
                );
              },
              child: WrappedCover(
                  book: shown[i], width: coverWidth, palette: palette),
            ),
        ],
      ),
    );
  }
}

// ── How you read ─────────────────────────────────────────────────────────────

class FormatsSlide extends StatelessWidget {
  final SlideEnv env;
  final WrappedPalette palette;

  const FormatsSlide({super.key, required this.env, required this.palette});

  static String _name(WrappedFormat f) => switch (f) {
        WrappedFormat.physical => 'Print',
        WrappedFormat.ebook => 'E-book',
        WrappedFormat.audio => 'Audiobook',
      };

  static IconData _icon(WrappedFormat f) => switch (f) {
        WrappedFormat.physical => Icons.menu_book,
        WrappedFormat.ebook => Icons.tablet_android,
        WrappedFormat.audio => Icons.headphones,
      };

  @override
  Widget build(BuildContext context) {
    final w = env.w;
    final a = env.entrance;
    final counts = w.formatCounts;
    final total = w.booksFinished;
    final ordered = WrappedFormat.values
        .where((f) => (counts[f] ?? 0) > 0)
        .toList()
      ..sort((x, y) => counts[y]!.compareTo(counts[x]!));
    final top = ordered.first;
    final topShare = counts[top]! / total;
    final tied = ordered.length > 1 && counts[ordered[1]] == counts[top];

    final headline = tied
        ? 'A bit of\neverything.'
        : switch (top) {
            WrappedFormat.physical => 'Mostly\non paper.',
            WrappedFormat.ebook => 'Mostly\non screen.',
            WrappedFormat.audio => 'Mostly\nby ear.',
          };

    final colors = [
      palette.accent,
      Colors.white,
      Colors.white.withValues(alpha: 0.4),
    ];

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SlideEyebrow('How you read', entrance: a),
        const SizedBox(height: 14),
        Reveal(
          animation: a,
          start: 0.02,
          end: 0.4,
          child: Text(headline, style: WrappedType.headline(context, size: 36)),
        ),
        const Spacer(),
        if (!tied) ...[
          Reveal(
            animation: a,
            start: 0.1,
            end: 0.5,
            child: CountUp(
              animation: a,
              value: (topShare * 100).round(),
              format: (v) => '$v%',
              start: 0.15,
              end: 0.7,
              style: WrappedType.hero(context, size: 88, color: palette.accent),
            ),
          ),
          Reveal(
            animation: a,
            start: 0.18,
            end: 0.55,
            child: Text(
              'of your books were ${switch (top) {
                WrappedFormat.physical => 'in print',
                WrappedFormat.ebook => 'e-books',
                WrappedFormat.audio => 'audiobooks',
              }}.',
              style: WrappedType.body(context),
            ),
          ),
          const SizedBox(height: 26),
        ],
        // One bar, split by format, growing in from the left.
        AnimatedBuilder(
          animation: a,
          builder: (context, _) {
            final t = Curves.easeOutCubic
                .transform(((a.value - 0.3) / 0.45).clamp(0.0, 1.0));
            return ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: SizedBox(
                height: 44,
                child: Row(
                  children: [
                    for (var i = 0; i < ordered.length; i++)
                      Expanded(
                        flex: math.max(1, (counts[ordered[i]]! * 1000 * t).round()),
                        child: Container(
                          margin: EdgeInsets.only(
                              right: i == ordered.length - 1 ? 0 : 3),
                          color: colors[i],
                        ),
                      ),
                    // The unfilled remainder while the bar grows.
                    if (t < 1)
                      Expanded(
                        flex: math.max(1, (total * 1000 * (1 - t)).round()),
                        child: const SizedBox(),
                      ),
                  ],
                ),
              ),
            );
          },
        ),
        const SizedBox(height: 22),
        for (var i = 0; i < ordered.length; i++)
          Reveal(
            animation: a,
            start: 0.5 + i * 0.1,
            end: 0.85 + i * 0.05,
            child: Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                        color: colors[i],
                        borderRadius: BorderRadius.circular(3)),
                  ),
                  const SizedBox(width: 10),
                  Icon(_icon(ordered[i]),
                      size: 18, color: Colors.white.withValues(alpha: 0.8)),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(_name(ordered[i]),
                        style: WrappedType.title(context, size: 17)),
                  ),
                  Text(YearWrapped.plural(counts[ordered[i]]!, 'book'),
                      style: WrappedType.body(context, alpha: 0.85)),
                ],
              ),
            ),
          ),
        const Spacer(),
      ],
    );
  }
}
