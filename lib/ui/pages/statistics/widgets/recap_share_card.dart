import 'dart:io';
import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/material.dart';

import '/data/database/database_helper.dart';
import '/data/models/monthly_recap.dart';

enum RecapCardStyle {
  /// The month's numbers in full: hero stats, the supporting line, and what was
  /// finished.
  summary,

  /// The covers of everything finished, which is the part most worth showing.
  books,
}

/// A month of reading, drawn as a shareable card.
///
/// Deliberately the same shape as [BookShareCard] — same corner radius, same
/// header-over-body split, same footer — so a recap and a finished book posted
/// side by side read as coming from the same app.
class RecapShareCard extends StatelessWidget {
  final MonthlyRecap recap;

  /// Absolute path to the month's most-read book cover, used as the header
  /// backdrop. Null when there is nothing to draw.
  final String? coverPath;
  final int? coverShape;

  final Color? headerColor;
  final bool useCoverBackground;
  final bool isTransparent;
  final bool isDark;
  final RecapCardStyle style;

  const RecapShareCard({
    super.key,
    required this.recap,
    this.coverPath,
    this.coverShape,
    this.headerColor,
    this.useCoverBackground = true,
    this.isTransparent = false,
    this.isDark = false,
    this.style = RecapCardStyle.summary,
  });

  /// What the summary card needs, and the floor for the books card.
  static const double _baseHeight = 440;

  /// Every card has to fit the share sheet's slot without scrolling, so the
  /// parts that could grow — the header cover, how many finished books are
  /// listed — are capped rather than left to the data.
  static const double _headerCoverHeight = 84;

  static const int _maxFinishedRows = 2;

  /// The bounds the cover grid arranges itself inside — see [_gridLayout] for
  /// how many columns a given month actually gets. Five across is as narrow as
  /// a cover can go and still be recognisable; three below three rows would
  /// make a heavy month's covers pointlessly small.
  static const int _minColumns = 3;
  static const int _maxColumns = 5;
  static const int _maxRows = 3;
  static const int _maxCoverThumbs = _maxColumns * _maxRows;
  static const double _gridSpacing = 8;
  static const double _gridRunSpacing = 10;

  /// The rating line under a cover, and the gap above it. Fixed so an unrated
  /// book still holds the space and the covers in the row below start level.
  static const double _gridRatingHeight = 13;
  static const double _gridRatingGap = 5;

  /// Horizontal padding inside a card body, which is what the cover grid has
  /// to divide up. Named because [slotHeightFor] works from it too.
  static const double _bodyPadding = 20;

  /// Everything on the books card that isn't the grid: the compact header, the
  /// label above the covers, the two rules, the stat line, and the footer.
  /// Only used to size the preview slot — see [slotHeightFor].
  static const double _booksChromeHeight = 232;

  @override
  Widget build(BuildContext context) {
    final palette = _Palette.of(
      headerColor: headerColor,
      isDark: isDark,
      isTransparent: isTransparent,
    );

    switch (style) {
      case RecapCardStyle.summary:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(palette),
            _buildSummaryBody(palette),
          ],
        );
      case RecapCardStyle.books:
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            _buildHeader(palette, compact: true),
            _buildBooksBody(palette),
          ],
        );
    }
  }

  // ── Header ───────────────────────────────────────────────────────────

  /// The month's own title bar. Backed by the most-read book's cover, blurred
  /// the same way the book card blurs its own — a recap of a month spent inside
  /// one book should look like that book.
  Widget _buildHeader(_Palette palette, {bool compact = false}) {
    final hasCover =
        _cover != null && !isTransparent && useCoverBackground;
    final fg = hasCover ? Colors.white : palette.headerFg;

    return ClipRRect(
      borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      child: Stack(
        children: [
          if (hasCover) ...[
            Positioned.fill(
              child: ImageFiltered(
                imageFilter: ui.ImageFilter.blur(sigmaX: 60, sigmaY: 60),
                child: Image.file(_cover!, fit: BoxFit.cover),
              ),
            ),
            Positioned.fill(
              child: Container(color: Colors.black.withValues(alpha: 0.45)),
            ),
          ] else
            Positioned.fill(
              child:
                  Container(decoration: BoxDecoration(gradient: palette.header)),
            ),
          Padding(
            padding: EdgeInsets.fromLTRB(20, compact ? 16 : 18, 20, compact ? 16 : 18),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        _eyebrow,
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.6,
                          color: fg.withValues(alpha: 0.70),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        recap.monthLabel,
                        style: TextStyle(
                          fontSize: compact ? 22 : 26,
                          fontWeight: FontWeight.w800,
                          color: fg,
                          height: 1.1,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                if (_cover != null && useCoverBackground && !compact) ...[
                  const SizedBox(width: 16),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      _cover!,
                      width: coverShape == DatabaseHelper.coverShapeSquare
                          ? _headerCoverHeight
                          : 58,
                      height: _headerCoverHeight,
                      fit: BoxFit.cover,
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── Summary body ─────────────────────────────────────────────────────

  Widget _buildSummaryBody(_Palette palette) {
    final finished = recap.booksFinished;
    return Container(
      decoration: BoxDecoration(
        color: palette.bodyBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildHeroStats(palette),
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: palette.divider),
          const SizedBox(height: 12),
          _buildSecondaryLine(palette),
          if (finished.isNotEmpty) ...[
            const SizedBox(height: 14),
            Divider(height: 1, thickness: 1, color: palette.divider),
            const SizedBox(height: 12),
            _buildFinishedList(palette),
          ],
          const SizedBox(height: 14),
          Divider(height: 1, thickness: 1, color: palette.divider),
          const SizedBox(height: 10),
          _buildFooter(),
        ],
      ),
    );
  }

  Widget _buildHeroStats(_Palette palette) {
    final items = <(String, String)>[];
    if (recap.minutes > 0) {
      items.add((MonthlyRecap.formatMinutes(recap.minutes), 'Read Time'));
    }
    if (recap.sessions > 0) items.add(('${recap.sessions}', 'Sessions'));
    // Pages rather than books finished: the covers below already say how many
    // there were, twice over, and pages is the one figure of the month's
    // reading that isn't anywhere else on the card.
    if (recap.pages > 0) items.add((_formatNumber(recap.pages), 'Pages'));
    if (items.isEmpty) return const SizedBox.shrink();

    final cells = <Widget>[];
    for (var i = 0; i < items.length; i++) {
      if (i > 0) {
        cells.add(Container(
          width: 1,
          height: 42,
          margin: const EdgeInsets.symmetric(horizontal: 4),
          color: palette.bodySecondary.withValues(alpha: 0.25),
        ));
      }
      cells.add(Expanded(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                items[i].$1,
                maxLines: 1,
                softWrap: false,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: palette.bodyPrimary,
                  letterSpacing: -0.5,
                ),
              ),
            ),
            const SizedBox(height: 3),
            Text(
              items[i].$2.toUpperCase(),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: 9,
                fontWeight: FontWeight.w600,
                color: palette.bodySecondary,
                letterSpacing: 0.8,
              ),
            ),
          ],
        ),
      ));
    }
    return Row(children: cells);
  }

  /// The line under the summary's hero numbers. It is there to add what the
  /// three big figures above it left out, so it can afford the smaller facts.
  Widget _buildSecondaryLine(_Palette palette) {
    final parts = <String>[];
    if (recap.activeDays > 0) {
      parts.add('${recap.activeDays} of ${recap.daysInMonth} days');
    }
    if (recap.avgSessionMinutes > 0) {
      parts.add('${MonthlyRecap.formatMinutes(recap.avgSessionMinutes)} avg');
    }
    // A run of one is just a day that was read, which the first part of the
    // line already counted.
    if (recap.longestDayStreak > 1) {
      parts.add('${recap.longestDayStreak} day streak');
    }
    return _buildStatLine(parts, palette);
  }

  /// The line under the covers, which is the only reading figure on that card
  /// and so has to be the headline one: the time it took, the pages it came to,
  /// and what the month's books were worth. Average session length belongs on
  /// the summary, where it is one detail among many rather than the whole of
  /// what a card says about a month.
  Widget _buildBooksLine(_Palette palette) {
    final parts = <String>[];
    if (recap.minutes > 0) {
      parts.add(MonthlyRecap.formatMinutes(recap.minutes));
    }
    if (recap.pages > 0) parts.add('${_formatNumber(recap.pages)} pages');
    if (recap.averageRating > 0) {
      parts.add('${recap.averageRating.toStringAsFixed(1)} avg rating');
    }
    return _buildStatLine(parts, palette);
  }

  /// The dot-separated run of facts both bodies close on, scaled down rather
  /// than wrapped so it stays one line whatever it is given.
  Widget _buildStatLine(List<String> parts, _Palette palette) {
    if (parts.isEmpty) return const SizedBox.shrink();

    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: Alignment.centerLeft,
      child: Text(
        parts.join('  ·  '),
        maxLines: 1,
        softWrap: false,
        style: TextStyle(
          fontSize: 12,
          color: palette.bodySecondary,
          fontWeight: FontWeight.w500,
        ),
      ),
    );
  }

  /// The finished books as a list of covers and titles. Capped so a heavy month
  /// doesn't grow the card past its slot in the share sheet; the rest are
  /// counted on the last line.
  Widget _buildFinishedList(_Palette palette) {
    // Best first, because only two of them fit: a card that names two books out
    // of six should name the two worth recommending, not the two most recent.
    // Unrated books sort to the back. Equal ratings fall back to position,
    // which keeps the recap's newest-first order — `sort` is not stable, so the
    // tiebreak has to be spelled out rather than assumed.
    final ranked = [
      for (var i = 0; i < recap.booksFinished.length; i++)
        (i, recap.booksFinished[i]),
    ]..sort((a, b) {
        final byRating = b.$2.rating.compareTo(a.$2.rating);
        return byRating != 0 ? byRating : a.$1.compareTo(b.$1);
      });
    final shown =
        ranked.take(_maxFinishedRows).map((e) => e.$2).toList();
    final extra = recap.booksFinishedCount - shown.length;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'FINISHED',
          style: TextStyle(
            fontSize: 9,
            fontWeight: FontWeight.w600,
            letterSpacing: 0.8,
            color: palette.bodySecondary,
          ),
        ),
        const SizedBox(height: 8),
        for (var i = 0; i < shown.length; i++) ...[
          if (i > 0) const SizedBox(height: 8),
          Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _coverThumb(shown[i], palette, width: 24),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      shown[i].title,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: palette.bodyPrimary,
                      ),
                    ),
                    if (shown[i].author.isNotEmpty)
                      Text(
                        shown[i].author,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 10,
                          color: palette.bodySecondary,
                        ),
                      ),
                  ],
                ),
              ),
              if (shown[i].rating > 0) ...[
                const SizedBox(width: 8),
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 13, color: Color(0xFFFBCB04)),
                    const SizedBox(width: 2),
                    Text(
                      shown[i].rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: palette.bodyPrimary,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ],
        if (extra > 0) ...[
          const SizedBox(height: 8),
          Text(
            '+ $extra more',
            style: TextStyle(fontSize: 11, color: palette.bodySecondary),
          ),
        ],
      ],
    );
  }

  // ── Books body ───────────────────────────────────────────────────────

  /// A shelf of what the month produced. Only offered when something was
  /// actually finished — see [RecapShareCard.stylesFor].
  Widget _buildBooksBody(_Palette palette) {
    // A month past the cap gives up one cover to the "+N" tile, so the tile
    // count — and with it the grid's shape — stays where [slotHeightFor]
    // worked out the sheet's slot from.
    final cells = _cellCount(recap.booksFinishedCount);
    final overflows = recap.booksFinishedCount > _maxCoverThumbs;
    final shown =
        recap.booksFinished.take(overflows ? cells - 1 : cells).toList();
    final extra = recap.booksFinishedCount - shown.length;

    return Container(
      decoration: BoxDecoration(
        color: palette.bodyBg,
        borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
      ),
      padding: const EdgeInsets.fromLTRB(_bodyPadding, 18, _bodyPadding, 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${recap.booksFinishedCount} '
            '${recap.booksFinishedCount == 1 ? 'BOOK' : 'BOOKS'} FINISHED',
            style: TextStyle(
              fontSize: 9,
              fontWeight: FontWeight.w600,
              letterSpacing: 0.8,
              color: palette.bodySecondary,
            ),
          ),
          const SizedBox(height: 14),
          _buildCoverGrid(palette, shown, extra),
          const SizedBox(height: 16),
          Divider(height: 1, thickness: 1, color: palette.divider),
          const SizedBox(height: 12),
          _buildBooksLine(palette),
          const SizedBox(height: 12),
          Divider(height: 1, thickness: 1, color: palette.divider),
          const SizedBox(height: 10),
          _buildFooter(),
        ],
      ),
    );
  }

  /// The shape the cover grid takes for [cells] covers across [contentWidth].
  ///
  /// A fixed five across would make three books look lost on a card built for
  /// fifteen, so the grid is solved for instead: use as few rows as five across
  /// allows, even those rows out, and only fall back to narrower covers when
  /// the taller ones would push the card past what a full grid already costs.
  /// A light month gets a handful of large covers; a heavy one gets the full
  /// three by five.
  ///
  /// [_CoverGrid.perRow] can be fewer than the columns the covers are sized
  /// for: twelve books are laid out three rows of four rather than 5 · 5 · 2,
  /// which is the same height and reads as a shelf rather than as a remainder.
  static _CoverGrid _gridLayout(int cells, double contentWidth) {
    double widthAt(int columns) =>
        (contentWidth - _gridSpacing * (columns - 1)) / columns;

    double cellHeightAt(int columns) =>
        widthAt(columns) / DatabaseHelper.coverAspectRatio(null) +
        _gridRatingGap +
        _gridRatingHeight;

    double gridHeightAt(int columns, int rows) =>
        rows * cellHeightAt(columns) + (rows - 1) * _gridRunSpacing;

    // What a full grid costs. Nothing is allowed to be taller than that, so
    // the sheet never has to make room for a light month it didn't need to.
    final budget = gridHeightAt(_maxColumns, _maxRows);

    var columns =
        math.max(_minColumns, (cells / (cells / _maxColumns).ceil()).ceil());
    while (columns < _maxColumns &&
        gridHeightAt(columns, (cells / columns).ceil()) > budget) {
      columns++;
    }

    final rows = (cells / columns).ceil();
    return _CoverGrid(
      rows: rows,
      // Spreading the covers evenly over the rows they already occupy costs no
      // height and never needs more than `columns` of them.
      perRow: (cells / rows).ceil(),
      cellWidth: widthAt(columns),
      cellHeight: cellHeightAt(columns),
    );
  }

  /// The covers, each with the rating it was given, in the arrangement
  /// [_gridLayout] settled on.
  ///
  /// Explicit rows rather than a [Wrap]: the cell width is divided out of the
  /// card's own width, and a [Wrap] asked to fit that many of them would drop
  /// one on a rounding error. Rows are centred, so a last row that comes up
  /// short sits under the ones above rather than hugging the left edge.
  Widget _buildCoverGrid(
    _Palette palette,
    List<RecapBook> shown,
    int extra,
  ) {
    final cells = shown.length + (extra > 0 ? 1 : 0);

    return LayoutBuilder(
      builder: (context, constraints) {
        final grid = _gridLayout(cells, constraints.maxWidth);
        final tiles = <Widget>[
          for (final book in shown) _buildBookCell(book, palette, grid.cellWidth),
          if (extra > 0) _buildExtraCell(extra, palette, grid.cellWidth),
        ];

        return Column(
          children: [
            for (var start = 0; start < tiles.length; start += grid.perRow) ...[
              if (start > 0) const SizedBox(height: _gridRunSpacing),
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (var i = start;
                      i < math.min(start + grid.perRow, tiles.length);
                      i++) ...[
                    if (i > start) const SizedBox(width: _gridSpacing),
                    SizedBox(width: grid.cellWidth, child: tiles[i]),
                  ],
                ],
              ),
            ],
          ],
        );
      },
    );
  }

  /// A cover with its rating under it.
  Widget _buildBookCell(
    RecapBook book,
    _Palette palette,
    double width,
  ) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Square covers are shorter than portrait ones, so the cover hangs from
        // the bottom of a box of portrait height — which is what keeps the
        // ratings across a row of mixed shapes on one line.
        SizedBox(
          height: width / DatabaseHelper.coverAspectRatio(null),
          child: Align(
            alignment: Alignment.bottomCenter,
            child: _coverThumb(book, palette, width: width, labelled: true),
          ),
        ),
        const SizedBox(height: _gridRatingGap),
        SizedBox(
          height: _gridRatingHeight,
          child: book.rating > 0
              ? Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.star_rounded,
                        size: 11, color: Color(0xFFFBCB04)),
                    const SizedBox(width: 1),
                    Text(
                      book.rating.toStringAsFixed(1),
                      style: TextStyle(
                        fontSize: 10,
                        fontWeight: FontWeight.w700,
                        color: palette.bodyPrimary,
                        height: 1.1,
                      ),
                    ),
                  ],
                )
              : null,
        ),
      ],
    );
  }

  /// The tile standing in for the covers past the cap, sized like one of them.
  Widget _buildExtraCell(int extra, _Palette palette, double width) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: width,
          height: width / DatabaseHelper.coverAspectRatio(null),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: palette.bodySecondary.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Center(
              child: Text(
                '+$extra',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                  color: palette.bodySecondary,
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: _gridRatingGap),
        const SizedBox(height: _gridRatingHeight),
      ],
    );
  }

  /// A cover, or a stand-in when the book has none — a grid with holes in it
  /// reads as broken rather than as unfinished data.
  ///
  /// [labelled] gives the stand-in the book's title and author rather than its
  /// initial. Worth it wherever the tile is big enough to read, which is the
  /// cover grid; the summary's 24pt thumbnails only have room for a letter.
  Widget _coverThumb(
    RecapBook book,
    _Palette palette, {
    required double width,
    bool labelled = false,
  }) {
    final height = width / DatabaseHelper.coverAspectRatio(book.coverShape);
    final placeholder = labelled
        ? _titledPlaceholder(book, palette, width: width, height: height)
        : _letteredPlaceholder(book, palette, width: width, height: height);

    final path = book.coverPath;
    if (path == null || path.isEmpty) return placeholder;
    return ClipRRect(
      borderRadius: BorderRadius.circular(6),
      child: Image.file(
        File(path),
        width: width,
        height: height,
        fit: BoxFit.cover,
        errorBuilder: (_, _, _) => placeholder,
      ),
    );
  }

  Widget _letteredPlaceholder(
    RecapBook book,
    _Palette palette, {
    required double width,
    required double height,
  }) {
    return Container(
      width: width,
      height: height,
      decoration: BoxDecoration(
        color: palette.bodySecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      alignment: Alignment.center,
      child: Text(
        book.title.isEmpty ? '?' : book.title.substring(0, 1).toUpperCase(),
        style: TextStyle(
          fontSize: width * 0.4,
          fontWeight: FontWeight.w700,
          color: palette.bodySecondary,
        ),
      ),
    );
  }

  /// The stand-in for a cover the reader never added: the book set as type,
  /// which is what a cover would have told them anyway. Sized off the tile so
  /// it holds up whether the grid is three across or five.
  Widget _titledPlaceholder(
    RecapBook book,
    _Palette palette, {
    required double width,
    required double height,
  }) {
    final titleSize = (width * 0.15).clamp(7.0, 12.0);

    return Container(
      width: width,
      height: height,
      padding: EdgeInsets.symmetric(
        horizontal: width * 0.10,
        vertical: width * 0.12,
      ),
      decoration: BoxDecoration(
        color: palette.bodySecondary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Flexible(
            child: Text(
              book.title,
              maxLines: 4,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                fontSize: titleSize,
                fontWeight: FontWeight.w700,
                height: 1.2,
                color: palette.bodyPrimary,
              ),
            ),
          ),
          if (book.author.isNotEmpty) ...[
            SizedBox(height: width * 0.06),
            Flexible(
              child: Text(
                book.author,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: titleSize * 0.85,
                  height: 1.2,
                  color: palette.bodySecondary,
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }

  // ── Shared ───────────────────────────────────────────────────────────

  /// Just the wordmark. The month is the card's title already — repeating it
  /// down here said nothing the top of the card hadn't.
  Widget _buildFooter() {
    final brandColor = isDark || isTransparent
        ? Colors.white.withValues(alpha: 0.85)
        : const Color(0xFF111827);
    return Row(
      mainAxisAlignment: MainAxisAlignment.end,
      children: [
        Image.asset(
          'assets/icon/readstats_white.png',
          width: 26,
          height: 26,
          color: brandColor,
        ),
        const SizedBox(width: 5),
        Text(
          'ReadStats',
          style: TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w700,
            color: brandColor,
          ),
        ),
      ],
    );
  }

  /// The small line above the month. Carries the "so far" that used to sit in
  /// the footer, so a month still being read isn't posted as a closed one.
  String get _eyebrow =>
      recap.isInProgress ? 'READING RECAP · SO FAR' : 'READING RECAP';


  File? get _cover =>
      (coverPath == null || coverPath!.isEmpty) ? null : File(coverPath!);

  static String _formatNumber(int n) => n.toString().replaceAllMapped(
        RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'),
        (m) => '${m[1]},',
      );

  /// How tall the share sheet's slot has to be for [recap] at [cardWidth].
  ///
  /// The summary is built to a fixed shape, so the only card whose height
  /// follows the data is the cover grid — one row for most months,
  /// three for a heavy one. Deriving the slot rather than fixing it keeps the
  /// sheet the size it is today for a reader who finished a few books, and only
  /// grows it for the reader who has fifteen covers to show.
  ///
  /// An estimate, and deliberately a cheap one: the preview is scrollable, so
  /// being a little under only costs a scroll and being a little over only
  /// costs some space under the shorter cards.
  static double slotHeightFor(MonthlyRecap recap, double cardWidth) {
    if (!stylesFor(recap).contains(RecapCardStyle.books)) return _baseHeight;

    final grid = _gridLayout(
      _cellCount(recap.booksFinishedCount),
      cardWidth - _bodyPadding * 2,
    );
    return math.max(_baseHeight, _booksChromeHeight + grid.height);
  }

  /// How many tiles the grid draws for [booksFinished] — the covers, plus the
  /// "+N" tile that replaces the last of them once the month runs past the cap.
  static int _cellCount(int booksFinished) =>
      math.min(booksFinished, _maxCoverThumbs);

  /// The styles worth offering for [recap]. The cover shelf is dropped when
  /// nothing was finished — an empty shelf is not a card anyone wants to post.
  static List<RecapCardStyle> stylesFor(MonthlyRecap recap) => [
        RecapCardStyle.summary,
        if (recap.booksFinishedCount > 0) RecapCardStyle.books,
      ];

  static String labelFor(RecapCardStyle style) => switch (style) {
        RecapCardStyle.summary => 'Summary',
        RecapCardStyle.books => 'Books',
      };
}

/// The arrangement [RecapShareCard._gridLayout] settled on for one month's
/// covers: how many rows, how many go in each, and how big each one is.
class _CoverGrid {
  final int rows;
  final int perRow;
  final double cellWidth;
  final double cellHeight;

  const _CoverGrid({
    required this.rows,
    required this.perRow,
    required this.cellWidth,
    required this.cellHeight,
  });

  /// What the whole grid occupies, which is what the share sheet sizes its
  /// preview slot from.
  double get height =>
      rows * cellHeight + (rows - 1) * RecapShareCard._gridRunSpacing;
}

/// The three colour schemes a card can be drawn in, resolved once per build.
/// Mirrors [BookShareCard]'s palette so the two sets of cards stay in step.
class _Palette {
  final Gradient header;
  final Color headerFg;
  final Color bodyBg;
  final Color bodyPrimary;
  final Color bodySecondary;
  final Color divider;

  const _Palette({
    required this.header,
    required this.headerFg,
    required this.bodyBg,
    required this.bodyPrimary,
    required this.bodySecondary,
    required this.divider,
  });

  factory _Palette.of({
    required Color? headerColor,
    required bool isDark,
    required bool isTransparent,
  }) {
    if (isTransparent) {
      return _Palette(
        header: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Colors.black.withValues(alpha: 0.62),
            Colors.black.withValues(alpha: 0.44),
          ],
        ),
        headerFg: Colors.white,
        bodyBg: Colors.black.withValues(alpha: 0.28),
        bodyPrimary: Colors.white,
        bodySecondary: Colors.white.withValues(alpha: 0.58),
        divider: Colors.white.withValues(alpha: 0.12),
      );
    }
    if (isDark) {
      final base = headerColor ?? const Color(0xFF2C2C2C);
      final start = Color.lerp(base, Colors.black, 0.3)!;
      return _Palette(
        header: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, Color.lerp(base, Colors.black, 0.65)!],
        ),
        headerFg: _fgFor(start),
        bodyBg: const Color(0xFF141414),
        bodyPrimary: Colors.white,
        bodySecondary: Colors.white.withValues(alpha: 0.52),
        divider: Colors.white.withValues(alpha: 0.10),
      );
    }
    final base = headerColor ?? const Color(0xFF484848);
    return _Palette(
      header: LinearGradient(
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
        colors: [base, Color.lerp(base, Colors.black, 0.40)!],
      ),
      headerFg: _fgFor(base),
      bodyBg: Colors.white,
      bodyPrimary: const Color(0xFF111827),
      bodySecondary: const Color(0xFF6B7280),
      divider: const Color(0xFFE9EAEC),
    );
  }

  static Color _fgFor(Color background) =>
      ThemeData.estimateBrightnessForColor(background) == Brightness.light
          ? Colors.black
          : Colors.white;
}
