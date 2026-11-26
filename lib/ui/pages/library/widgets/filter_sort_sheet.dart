import 'package:flutter/material.dart';
import 'package:read_stats/data/models/book_type.dart';
import 'package:read_stats/data/models/shelf.dart';
import 'package:read_stats/domain/library_filter.dart';
import 'package:read_stats/ui/settings_view_model.dart';

class SortFilterOptions {
  final String sortOption;
  final bool isAscending;
  final List<String> bookTypes;
  final bool isFavorite;
  final List<String> finishedYears;
  final List<String> tags;
  final String tagFilterMode;
  final bool isReviewed;

  /// Books in a series shown as one series row. A view choice, set under the
  /// sort rather than among the filters, so Clear all leaves it.
  final bool groupSeries;

  /// Only books that belong to a series.
  final bool seriesOnly;

  /// 'all', 'with' (has a cover) or 'without'.
  final String coverFilter;

  /// See [LibraryFilter.rating], [LibraryFilter.pages] and
  /// [LibraryFilter.listening].
  final MeasureRange rating;
  final MeasureRange pages;
  final MeasureRange listening;

  const SortFilterOptions({
    required this.sortOption,
    required this.isAscending,
    required this.bookTypes,
    required this.isFavorite,
    this.finishedYears = const [],
    this.tags = const [],
    this.tagFilterMode = 'any',
    this.isReviewed = false,
    this.groupSeries = true,
    this.seriesOnly = false,
    this.coverFilter = 'all',
    this.rating = MeasureRange.any,
    this.pages = MeasureRange.any,
    this.listening = MeasureRange.any,
  });

  /// How many separate filters are narrowing the list.
  int get activeFilterCount => [
    bookTypes.isNotEmpty,
    isFavorite,
    isReviewed,
    seriesOnly,
    coverFilter != 'all',
    finishedYears.isNotEmpty,
    tags.isNotEmpty,
    rating.isActive,
    pages.isActive,
    listening.isActive,
  ].where((on) => on).length;

  /// Every filter off; the sort and the series grouping kept.
  SortFilterOptions cleared() => SortFilterOptions(
    sortOption: sortOption,
    isAscending: isAscending,
    bookTypes: const [],
    isFavorite: false,
    groupSeries: groupSeries,
  );

  SortFilterOptions copyWith({
    String? sortOption,
    bool? isAscending,
    List<String>? bookTypes,
    bool? isFavorite,
    List<String>? finishedYears,
    List<String>? tags,
    String? tagFilterMode,
    bool? isReviewed,
    bool? groupSeries,
    bool? seriesOnly,
    String? coverFilter,
    MeasureRange? rating,
    MeasureRange? pages,
    MeasureRange? listening,
  }) {
    return SortFilterOptions(
      sortOption: sortOption ?? this.sortOption,
      isAscending: isAscending ?? this.isAscending,
      bookTypes: bookTypes ?? this.bookTypes,
      isFavorite: isFavorite ?? this.isFavorite,
      finishedYears: finishedYears ?? this.finishedYears,
      tags: tags ?? this.tags,
      tagFilterMode: tagFilterMode ?? this.tagFilterMode,
      isReviewed: isReviewed ?? this.isReviewed,
      groupSeries: groupSeries ?? this.groupSeries,
      seriesOnly: seriesOnly ?? this.seriesOnly,
      coverFilter: coverFilter ?? this.coverFilter,
      rating: rating ?? this.rating,
      pages: pages ?? this.pages,
      listening: listening ?? this.listening,
    );
  }
}

/// How the sheet shows one measure filter — rating, pages or listening time.
/// All three are the same control, so they read and behave alike: bars of
/// how the books spread across the measure, a range slider under them over
/// evenly spaced [stops], the range read out in the section heading, and a
/// chip for the books with no value at all.
class FilterMeasure {
  final String title;

  /// The slider's stops, lowest first and evenly spaced, so the middle of
  /// the slider is the middle of the scale. Its ends are open: a thumb
  /// dragged all the way out drops that limit.
  final List<num> stops;

  /// A book's value on this measure, or null when it doesn't have one — or
  /// isn't measured this way at all (an audiobook has no pages).
  final num? Function(Map<String, dynamic> book) valueOf;

  /// Whether each bar stands on a stop (ratings, which only ever sit on
  /// one) rather than between two (page counts and listening times, which
  /// fall anywhere in between).
  final bool barsOnStops;

  /// A value as it reads: '4★', '300', '8' (hours, from minutes).
  final String Function(num value) number;

  /// After a number in the heading: ' pages', ' hours' — nothing for stars,
  /// which [number] already marks.
  final String unit;

  /// After a number on the slider's scale: ' h', or nothing.
  final String scaleUnit;

  /// Whether the top stop stands for "and over" (1000+ pages) rather than a
  /// true ceiling (5 stars).
  final bool openTop;

  /// The chip for books with no value: "No rating", "No page count"…
  final String missingLabel;

  const FilterMeasure({
    required this.title,
    required this.stops,
    required this.valueOf,
    required this.barsOnStops,
    required this.number,
    required this.unit,
    required this.scaleUnit,
    required this.openTop,
    required this.missingLabel,
  });

  int get _last => stops.length - 1;

  /// The scale's label for stop [i]: "½★", "1000+", "30+ h".
  String stopLabel(int i) =>
      '${number(stops[i])}${openTop && i == _last ? '+' : ''}$scaleUnit';

  /// The heading's reading of [r] — "200–400 pages", "8+ hours", "4★+",
  /// "No rating" — or null when it isn't narrowing anything. The Library's
  /// filter chips use the same words.
  String? readout(MeasureRange r) {
    if (r.missing) return missingLabel;
    final lo = r.min, hi = r.max;
    if (lo == null && hi == null) return null;
    if (lo == null) return 'Up to ${number(hi!)}$unit';
    if (hi == null) return '${number(lo)}+$unit';
    if (lo == hi) return '${number(lo)}$unit';
    return '${number(lo)}–${number(hi)}$unit';
  }

  /// The stop nearest [value], or [open] for an open end.
  int _indexOf(num? value, int open) {
    if (value == null) return open;
    var best = 0;
    for (var i = 1; i < stops.length; i++) {
      if ((stops[i] - value).abs() < (stops[best] - value).abs()) best = i;
    }
    return best;
  }

  /// How many of [books] fall at each bar: one bar per stop when
  /// [barsOnStops], else one per gap between stops, the last gap taking
  /// everything above it (the "1000+" end). Books without a value aren't
  /// counted — they're what the "No …" chip is for — but a rating of 0
  /// stars is a value, and stands on the first bar.
  List<int> distribution(Iterable<Map<String, dynamic>> books) {
    final counts = List.filled(barsOnStops ? stops.length : _last, 0);
    for (final book in books) {
      final value = valueOf(book);
      if (value == null) continue;
      counts[barsOnStops ? _indexOf(value, 0) : _gapOf(value)]++;
    }
    return counts;
  }

  int _gapOf(num value) {
    for (var i = 0; i < _last - 1; i++) {
      if (value < stops[i + 1]) return i;
    }
    return _last - 1;
  }

  /// Whether bar [i] lies inside the slider's [low]–[high] stops.
  bool barInRange(int i, int low, int high) =>
      barsOnStops ? i >= low && i <= high : i >= low && i + 1 <= high;
}

String _trimmed(num v) =>
    v == v.roundToDouble() ? v.toInt().toString() : v.toStringAsFixed(1);

bool _isAudio(Map<String, dynamic> book) =>
    book['book_type_id'] == BookType.audiobook;

final ratingMeasure = FilterMeasure(
  title: 'Rating',
  // From no stars — a rating, unlike none at all — to five.
  stops: const [0, 0.5, 1, 1.5, 2, 2.5, 3, 3.5, 4, 4.5, 5],
  valueOf: (book) => book['rating'] as num?,
  barsOnStops: true,
  number: (v) => v == 0.5 ? '½★' : '${_trimmed(v)}★',
  unit: '',
  scaleUnit: '',
  openTop: false,
  missingLabel: 'No rating',
);

/// 50-page steps to 1000 and over.
final pagesMeasure = FilterMeasure(
  title: 'Pages',
  stops: [for (var i = 0; i <= 20; i++) i * 50],
  valueOf: (book) =>
      _isAudio(book) ? null : MeasureRange.known(book['page_count']),
  barsOnStops: false,
  number: (v) => '${v.toInt()}',
  unit: ' pages',
  scaleUnit: '',
  openTop: true,
  missingLabel: 'No page count',
);

/// Hour steps to 30 and over — in minutes, as listening time is kept, and
/// read out in hours.
final listeningMeasure = FilterMeasure(
  title: 'Listening time',
  stops: [for (var i = 0; i <= 30; i++) i * 60],
  valueOf: (book) =>
      _isAudio(book) ? MeasureRange.known(book['duration_minutes']) : null,
  barsOnStops: false,
  number: (v) => '${(v / 60).round()}',
  unit: ' hours',
  scaleUnit: ' h',
  openTop: true,
  missingLabel: 'No listening time',
);

/// The bars over a measure's slider: how the books in view spread across
/// it, those inside the chosen range in the accent colour, the rest grey.
class _DistributionPainter extends CustomPainter {
  final FilterMeasure measure;
  final List<int> counts;
  final int low;
  final int high;
  final Color inRange;
  final Color outOfRange;

  _DistributionPainter({
    required this.measure,
    required this.counts,
    required this.low,
    required this.high,
    required this.inRange,
    required this.outOfRange,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final peak = counts.fold(0, (a, b) => a > b ? a : b);
    if (peak == 0) return;
    // The stops sit evenly across the width — exactly the slider's track.
    final step = size.width / (measure.stops.length - 1);
    // Rating's eleven bars have room to be broad; the page and hour bars
    // split the same width twenty and thirty ways, so stay slim.
    final barWidth = measure.barsOnStops
        ? (step * 0.6).clamp(2.0, 18.0)
        : (step * 0.7).clamp(2.0, 10.0);
    for (var i = 0; i < counts.length; i++) {
      if (counts[i] == 0) continue;
      final centre = measure.barsOnStops ? i * step : (i + 0.5) * step;
      final height = (counts[i] / peak * size.height).clamp(2.0, size.height);
      final paint = Paint()
        ..color = measure.barInRange(i, low, high) ? inRange : outOfRange;
      canvas.drawRRect(
        RRect.fromRectAndCorners(
          Rect.fromLTWH(
            centre - barWidth / 2,
            size.height - height,
            barWidth,
            height,
          ),
          topLeft: const Radius.circular(2),
          topRight: const Radius.circular(2),
        ),
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_DistributionPainter old) =>
      old.low != low ||
      old.high != high ||
      old.inRange != inRange ||
      old.outOfRange != outOfRange ||
      !_sameCounts(old.counts, counts);

  static bool _sameCounts(List<int> a, List<int> b) {
    if (a.length != b.length) return false;
    for (var i = 0; i < a.length; i++) {
      if (a[i] != b[i]) return false;
    }
    return true;
  }
}

/// The name a sort goes by on screen. 'Pages' is what's stored, but the sort
/// covers audiobooks too, by listening time — it's about length.
String sortLabel(String option) => option == 'Pages' ? 'Length' : option;

/// The sorts as the menu lists them: by date, by name, by number.
const List<List<String>> _sortGroups = [
  ['Date added', 'Date started', 'Date finished'],
  ['Title', 'Author'],
  ['Rating', 'Pages'],
];

/// The two directions of [option] in words that fit it, ascending first.
(String, String) _directionWords(String option) => switch (option) {
  'Title' || 'Author' => ('A–Z', 'Z–A'),
  'Rating' => ('Lowest first', 'Highest first'),
  'Pages' => ('Shortest first', 'Longest first'),
  _ => ('Oldest first', 'Newest first'),
};

class SortFilterPopup {
  /// [booksFor] gives the books a set of options would show — for the live
  /// count on the sheet's button. [scopeLabel] names what the sheet filters —
  /// the shelf, or all books — and [shelfFormats] the formats on it, which
  /// decide whether pages, listening time or both are offered.
  /// [defaultSortOption] is the shelf's own sort, marked in the sort menu.
  /// [availableTags] come most-used first.
  static Future<void> show({
    required BuildContext context,
    required SortFilterOptions currentOptions,
    required Function(SortFilterOptions) onOptionsChange,
    required List<String> availableYears,
    required List<String> availableTags,
    required SettingsViewModel settingsViewModel,
    required List<Map<String, dynamic>> Function(SortFilterOptions) booksFor,
    required String scopeLabel,
    required Set<String> shelfFormats,
    required String defaultSortOption,
    int? shelfId,
  }) async {
    final result = await showModalBottomSheet<SortFilterOptions>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (context) => _SortFilterView(
        initialOptions: currentOptions,
        availableYears: availableYears,
        availableTags: availableTags,
        settingsViewModel: settingsViewModel,
        booksFor: booksFor,
        scopeLabel: scopeLabel,
        shelfFormats: shelfFormats,
        defaultSortOption: defaultSortOption,
        shelfId: shelfId,
      ),
    );

    if (result != null) {
      onOptionsChange(result);
    }
  }
}

class _SortFilterView extends StatefulWidget {
  final SortFilterOptions initialOptions;
  final List<String> availableYears;
  final List<String> availableTags;
  final SettingsViewModel settingsViewModel;
  final List<Map<String, dynamic>> Function(SortFilterOptions) booksFor;
  final String scopeLabel;
  final Set<String> shelfFormats;
  final String defaultSortOption;
  final int? shelfId;

  const _SortFilterView({
    required this.initialOptions,
    required this.availableYears,
    required this.availableTags,
    required this.settingsViewModel,
    required this.booksFor,
    required this.scopeLabel,
    required this.shelfFormats,
    required this.defaultSortOption,
    required this.shelfId,
  });

  @override
  State<_SortFilterView> createState() => _SortFilterViewState();
}

class _SortFilterViewState extends State<_SortFilterView> {
  late SortFilterOptions _o;

  /// Whether every tag is on show, rather than the most-used few.
  bool _allTags = false;
  String _tagQuery = '';

  static const _bookTypes = ['Paperback', 'Hardback', 'eBook', 'Audiobook'];

  /// Tags shown before "more" — the most-used ones.
  static const _collapsedTags = 8;

  /// Past this many tags, the full list gets a search field.
  static const _tagSearchFrom = 12;

  /// The width of a slider's scale labels, the same in every measure
  /// section so the three sliders line up one above another.
  static const _scaleWidth = 44.0;

  /// The height of the bars over a measure's slider.
  static const _barsHeight = 32.0;

  /// The slider's touch halo — also how far in from its ends the track
  /// starts, which the bars line up with.
  static const _haloRadius = 18.0;

  @override
  void initState() {
    super.initState();
    _o = widget.initialOptions;
  }

  void _set(SortFilterOptions next) => setState(() => _o = next);

  /// Rating and finish year only mean something for books that have been
  /// read, so they're left off the to-read and reading shelves — unless one
  /// is already set, so a filter in force is never out of reach.
  bool get _readShelf =>
      widget.shelfId != Shelf.currentlyReading &&
      widget.shelfId != Shelf.wantToRead;

  List<String> _toggled(List<String> list, String item) =>
      list.contains(item) ? ([...list]..remove(item)) : [...list, item];

  ColorScheme get _colors => Theme.of(context).colorScheme;

  // ── Building blocks ───────────────────────────────────────────────────────
  //
  // The app's own look, so the sheet sits with everything else: filled grey
  // and borderless, as the Library's shelf chips, the Statistics years, the
  // forms and the other sheets' search boxes are, and the accent's container
  // colour for a choice that's on.

  /// A section: a small capitalised heading, as Statistics uses, over its
  /// controls. [value] reads out the setting where the controls don't spell
  /// it out themselves (the sliders).
  ///
  /// No lines between sections — as on Statistics, the headings and the
  /// space above them do the dividing: 36 points between one section's
  /// controls and the next heading, against 8 to 10 inside a section.
  Widget _section(String title, List<Widget> body, {String? value}) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 24, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            height: 20,
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    title.toUpperCase(),
                    style: theme.textTheme.labelSmall?.copyWith(
                      color: _colors.onSurface.withAlpha(120),
                      letterSpacing: 1.2,
                    ),
                  ),
                ),
                if (value != null)
                  Text(
                    value,
                    style: theme.textTheme.labelMedium?.copyWith(
                      color: _colors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 10),
          ...body,
        ],
      ),
    );
  }

  Widget _chips(List<Widget> children) =>
      Wrap(spacing: 8, runSpacing: 8, children: children);

  /// The app's chip, as the Library's shelves and the Statistics years draw
  /// it: filled grey, the accent's container colour when on, no outline, no
  /// tick.
  ///
  /// [icon] is for the few chips that stand for something the app already
  /// marks with one — the favourite heart, the series stack. It shows on and
  /// off alike, so picking one never shifts the chips beside it, and takes
  /// [selectedIconColor] when on (the heart's red).
  Widget _chip(
    String label, {
    required bool selected,
    required VoidCallback onTap,
    IconData? icon,
    Color? selectedIconColor,
  }) {
    final theme = Theme.of(context);
    return FilterChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      avatar: icon == null
          ? null
          : Icon(
              icon,
              size: 18,
              color: selected
                  ? (selectedIconColor ?? _colors.onPrimaryContainer)
                  : _colors.onSurfaceVariant,
            ),
      showCheckmark: false,
      labelStyle: theme.textTheme.bodySmall,
      labelPadding: EdgeInsets.only(left: icon == null ? 8 : 4, right: 8),
      backgroundColor: _colors.surfaceContainerHighest,
      selectedColor: _colors.primaryContainer,
      elevation: 0,
      pressElevation: 0,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// "+23 more" / "Show fewer": an action among the chips rather than a
  /// choice, so accent text without a pill — as the Library's "Clear all".
  Widget _moreChip(String label, VoidCallback onTap) {
    final theme = Theme.of(context);
    return ActionChip(
      label: Text(label),
      onPressed: onTap,
      labelStyle: theme.textTheme.bodySmall?.copyWith(
        color: _colors.primary,
        fontWeight: FontWeight.w600,
      ),
      labelPadding: const EdgeInsets.symmetric(horizontal: 8),
      backgroundColor: Colors.transparent,
      side: BorderSide.none,
      shape: const StadiumBorder(),
      elevation: 0,
      pressElevation: 0,
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }

  /// The app's filled field, as the forms draw it, for the sort controls.
  ShapeBorder get _fieldShape =>
      RoundedRectangleBorder(borderRadius: BorderRadius.circular(12));

  // ── Sections ──────────────────────────────────────────────────────────────

  /// Which sort, from a menu, and which way, in words that fit it.
  Widget _sortRow() {
    final theme = Theme.of(context);
    final (asc, desc) = _directionWords(_o.sortOption);

    final field = Material(
      color: _colors.surfaceContainerHighest,
      shape: _fieldShape,
      clipBehavior: Clip.antiAlias,
      // The menu opens as wide as the field it drops from.
      child: LayoutBuilder(
        builder: (context, box) => PopupMenuButton<String>(
          tooltip: 'Sort by',
          position: PopupMenuPosition.under,
          constraints: BoxConstraints.tightFor(width: box.maxWidth),
          // A new sort starts the way it's usually read — names A–Z,
          // everything else highest, longest or newest first — rather than
          // carrying the last one's direction over ("Rating, lowest first"
          // after "Title, A–Z").
          onSelected: (option) {
            if (option == _o.sortOption) return;
            _set(
              _o.copyWith(
                sortOption: option,
                isAscending: option == 'Title' || option == 'Author',
              ),
            );
          },
          itemBuilder: (context) => [
            for (final (i, group) in _sortGroups.indexed) ...[
              if (i > 0) const PopupMenuDivider(),
              for (final option in group)
                PopupMenuItem(
                  value: option,
                  child: Row(
                    children: [
                      Expanded(child: Text(sortLabel(option))),
                      // The shelf's own order, so the way back to it is
                      // never a guess.
                      if (option == widget.defaultSortOption)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: Text(
                            'Default',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(color: _colors.onSurfaceVariant),
                          ),
                        ),
                      SizedBox(
                        width: 18,
                        child: option == _o.sortOption
                            ? Icon(
                                Icons.check,
                                size: 18,
                                color: _colors.primary,
                              )
                            : null,
                      ),
                    ],
                  ),
                ),
            ],
          ],
          child: SizedBox(
            height: 44,
            child: Padding(
              padding: const EdgeInsets.only(left: 14, right: 8),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      sortLabel(_o.sortOption),
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
                  Icon(Icons.arrow_drop_down, color: _colors.onSurfaceVariant),
                ],
              ),
            ),
          ),
        ),
      ),
    );

    final direction = Material(
      color: _colors.surfaceContainerHighest,
      shape: _fieldShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: () => _set(_o.copyWith(isAscending: !_o.isAscending)),
        child: SizedBox(
          height: 44,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(
                  Icons.swap_vert,
                  size: 18,
                  color: _colors.onSurfaceVariant,
                ),
                const SizedBox(width: 6),
                // Both directions laid out, only the current one shown, so
                // the button is as wide as the longer of the two and keeps
                // its size when flipped — "Newest first" to "Oldest first".
                Stack(
                  alignment: Alignment.centerLeft,
                  children: [
                    for (final (ascending, words) in [
                      (true, asc),
                      (false, desc),
                    ])
                      Visibility(
                        visible: ascending == _o.isAscending,
                        maintainSize: true,
                        maintainAnimation: true,
                        maintainState: true,
                        child: Text(words, style: theme.textTheme.bodyMedium),
                      ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );

    return Row(
      children: [
        Expanded(child: field),
        const SizedBox(width: 8),
        direction,
      ],
    );
  }

  /// A measure section — rating, pages or listening time, all built here so
  /// they look and work the same: the range in the heading, bars of how the
  /// books spread across the measure, a slider whose ends mean "no limit",
  /// and a chip for the books with no value, which sets the slider aside
  /// while it's on.
  ///
  /// [pool] is what the bars count: the books every other filter lets
  /// through, but not this one — dragging a slider lights its bars up
  /// without changing them.
  Widget _measureSection(
    FilterMeasure m,
    MeasureRange r,
    Iterable<Map<String, dynamic>> pool,
    ValueChanged<MeasureRange> onChanged,
  ) {
    final theme = Theme.of(context);
    final last = m.stops.length - 1;
    final low = m._indexOf(r.min, 0);
    final high = m._indexOf(r.max, last);
    final scale = theme.textTheme.labelMedium?.copyWith(
      color: _colors.onSurfaceVariant,
    );

    // The slider's box overlaps the bars' foot, so its track runs just
    // under them — far enough down that a thumb (about 10 points across the
    // middle of the track) clears the bars rather than running into the one
    // above it. The scale labels sit level with the track.
    const sliderTop = _barsHeight - 6;
    const height = sliderTop + 2 * _haloRadius;
    const labelY = (sliderTop + _haloRadius) / height * 2 - 1;

    return _section(m.title, value: m.readout(r), [
      Opacity(
        opacity: r.missing ? 0.4 : 1,
        child: SizedBox(
          height: height,
          child: Row(
            children: [
              SizedBox(
                width: _scaleWidth,
                child: Align(
                  alignment: const Alignment(-1, labelY),
                  child: Text(m.stopLabel(0), style: scale),
                ),
              ),
              Expanded(
                child: Stack(
                  children: [
                    // Inset by the slider's halo, which is how far in its
                    // track starts and ends — so each bar sits over its
                    // stops.
                    Positioned(
                      left: _haloRadius,
                      right: _haloRadius,
                      top: 0,
                      height: _barsHeight,
                      child: CustomPaint(
                        painter: _DistributionPainter(
                          measure: m,
                          counts: m.distribution(pool),
                          low: low,
                          high: high,
                          inRange: _colors.primary,
                          outOfRange: _colors.onSurface.withAlpha(45),
                        ),
                      ),
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      top: sliderTop,
                      height: 2 * _haloRadius,
                      child: _slider(m, r, low, high, onChanged),
                    ),
                  ],
                ),
              ),
              SizedBox(
                width: _scaleWidth,
                child: Align(
                  alignment: const Alignment(1, labelY),
                  child: Text(m.stopLabel(last), style: scale),
                ),
              ),
            ],
          ),
        ),
      ),
      const SizedBox(height: 6),
      _chips([
        _chip(
          m.missingLabel,
          selected: r.missing,
          onTap: () => onChanged(
            r.missing ? MeasureRange.any : const MeasureRange(missing: true),
          ),
        ),
      ]),
    ]);
  }

  Widget _slider(
    FilterMeasure m,
    MeasureRange r,
    int low,
    int high,
    ValueChanged<MeasureRange> onChanged,
  ) {
    final last = m.stops.length - 1;
    return SliderTheme(
      // Stops without a dot for each — the bars mark the scale, and the
      // value shows while dragging and in the heading. A smaller touch halo
      // keeps the slider tight under its bars.
      data: SliderTheme.of(context).copyWith(
        rangeTickMarkShape: const RoundRangeSliderTickMarkShape(
          tickMarkRadius: 0,
        ),
        overlayShape: const RoundSliderOverlayShape(overlayRadius: _haloRadius),
      ),
      child: RangeSlider(
        values: RangeValues(low.toDouble(), high.toDouble()),
        max: last.toDouble(),
        divisions: last,
        labels: RangeLabels(m.stopLabel(low), m.stopLabel(high)),
        onChanged: r.missing
            ? null
            : (v) {
                final lo = v.start.round(), hi = v.end.round();
                onChanged(
                  MeasureRange(
                    min: lo == 0 ? null : m.stops[lo],
                    max: hi == last ? null : m.stops[hi],
                  ),
                );
              },
      ),
    );
  }

  /// Whether a series shows as one row. A view choice rather than a filter:
  /// it sits with the sort, in the same filled box as the sort controls, so
  /// the section reads as two blocks — how the list is ordered, and how it's
  /// grouped — and Clear all leaves it.
  Widget _groupSeriesRow() {
    final theme = Theme.of(context);
    void toggle() => _set(_o.copyWith(groupSeries: !_o.groupSeries));
    return Material(
      color: _colors.surfaceContainerHighest,
      shape: _fieldShape,
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: toggle,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 8, 8, 8),
          child: Row(
            children: [
              // The series stack, as series rows and "In a series" wear it.
              Icon(
                Icons.collections_bookmark,
                size: 20,
                color: _colors.onSurfaceVariant,
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Group series', style: theme.textTheme.bodyMedium),
                    Text(
                      'Show each series as one row',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: _colors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              Switch(
                value: _o.groupSeries,
                onChanged: (_) => toggle(),
                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// The quick yes-or-no picks — favourites, reviewed, series — kept near
  /// the top, where they're reached for most. Each wears the icon the app
  /// already marks it with: the heart, red when on as on a cover; the review
  /// mark; the series stack.
  List<Widget> _showOnlyBody() => [
    _chips([
      _chip(
        'Favorites',
        icon: Icons.favorite,
        selectedIconColor: Colors.red,
        selected: _o.isFavorite,
        onTap: () => _set(_o.copyWith(isFavorite: !_o.isFavorite)),
      ),
      _chip(
        'Reviewed',
        icon: Icons.rate_review_rounded,
        selected: _o.isReviewed,
        onTap: () => _set(_o.copyWith(isReviewed: !_o.isReviewed)),
      ),
      _chip(
        'In a series',
        icon: Icons.collections_bookmark,
        selected: _o.seriesOnly,
        onTap: () => _set(_o.copyWith(seriesOnly: !_o.seriesOnly)),
      ),
    ]),
  ];

  /// With a cover or without — one choice, so picking one lets go of the
  /// other. Mostly for tidying the library, so it comes last.
  List<Widget> _coverBody() {
    void cover(String value) =>
        _set(_o.copyWith(coverFilter: _o.coverFilter == value ? 'all' : value));
    return [
      _chips([
        _chip(
          'Has cover',
          selected: _o.coverFilter == 'with',
          onTap: () => cover('with'),
        ),
        _chip(
          'No cover',
          selected: _o.coverFilter == 'without',
          onTap: () => cover('without'),
        ),
      ]),
    ];
  }

  /// The most-used tags, with the rest a tap away. Chosen tags always show.
  List<Widget> _tagBody() {
    final theme = Theme.of(context);
    final all = widget.availableTags;
    final query = _tagQuery.trim().toLowerCase();

    final List<String> shown = _allTags
        ? [
            for (final t in all)
              if (query.isEmpty ||
                  _o.tags.contains(t) ||
                  t.toLowerCase().contains(query))
                t,
          ]
        : [
            ...all.take(_collapsedTags),
            ...all.skip(_collapsedTags).where(_o.tags.contains),
          ];
    final hidden = all.length - shown.length;

    return [
      if (_allTags && all.length > _tagSearchFrom) ...[
        // The search box the other sheets use — the bulk tag sheet's and
        // the book picker's.
        TextField(
          onChanged: (v) => setState(() => _tagQuery = v),
          style: theme.textTheme.bodyMedium,
          decoration: InputDecoration(
            hintText: 'Search tags…',
            prefixIcon: const Icon(Icons.search, size: 20),
            filled: true,
            fillColor: _colors.surfaceContainerHighest,
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(12),
              borderSide: BorderSide.none,
            ),
            isDense: true,
            contentPadding: const EdgeInsets.symmetric(
              horizontal: 12,
              vertical: 12,
            ),
          ),
        ),
        const SizedBox(height: 12),
      ],
      _chips([
        for (final tag in shown)
          _chip(
            tag,
            selected: _o.tags.contains(tag),
            onTap: () => _set(_o.copyWith(tags: _toggled(_o.tags, tag))),
          ),
        if (!_allTags && hidden > 0)
          _moreChip('+$hidden more', () => setState(() => _allTags = true)),
        if (_allTags && all.length > _collapsedTags)
          _moreChip(
            'Show fewer',
            () => setState(() {
              _allTags = false;
              _tagQuery = '';
            }),
          ),
      ]),
      if (_o.tags.isNotEmpty) ...[const SizedBox(height: 14), _tagMatch()],
    ];
  }

  /// How the chosen tags combine, worded for how many there are: with one
  /// tag it's simply with or without it.
  Widget _tagMatch() {
    final theme = Theme.of(context);
    final single = _o.tags.length == 1;
    final mode = single && _o.tagFilterMode == 'all' ? 'any' : _o.tagFilterMode;
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: single
            ? const [
                ButtonSegment(value: 'any', label: Text('With this tag')),
                ButtonSegment(value: 'exclude', label: Text('Without it')),
              ]
            : const [
                ButtonSegment(value: 'any', label: Text('Any of these')),
                ButtonSegment(value: 'all', label: Text('All of these')),
                ButtonSegment(value: 'exclude', label: Text('None of these')),
              ],
        selected: {mode},
        onSelectionChanged: (s) => _set(_o.copyWith(tagFilterMode: s.first)),
        showSelectedIcon: false,
        // Filled like the chips above it: grey, the accent's container
        // colour for the one that's on, no outline.
        style: SegmentedButton.styleFrom(
          backgroundColor: _colors.surfaceContainerHighest,
          foregroundColor: _colors.onSurfaceVariant,
          selectedBackgroundColor: _colors.primaryContainer,
          selectedForegroundColor: _colors.onPrimaryContainer,
          side: BorderSide.none,
          shape: const StadiumBorder(),
          textStyle: theme.textTheme.bodySmall,
          visualDensity: VisualDensity.compact,
        ),
      ),
    );
  }

  // ── Build ─────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final active = _o.activeFilterCount;
    final count = widget.booksFor(_o).length;

    // What each measure's bars count: the books every other filter lets
    // through. Pages and listening time leave each other out too, since
    // setting one decides which kind of book the other applies to.
    final lengthPool = widget.booksFor(
      _o.copyWith(pages: MeasureRange.any, listening: MeasureRange.any),
    );
    final ratingPool = widget.booksFor(_o.copyWith(rating: MeasureRange.any));

    // Pages for the print books in view, listening time for the
    // audiobooks: the chosen formats, or else what's on the shelf. Either
    // stays while it's set, so a filter in force is never out of reach.
    final formats = _o.bookTypes.isEmpty
        ? widget.shelfFormats
        : _o.bookTypes.toSet();
    final unknown = formats.isEmpty;
    final showPages =
        unknown || formats.any((f) => f != 'Audiobook') || _o.pages.isActive;
    final showListening =
        unknown || formats.contains('Audiobook') || _o.listening.isActive;
    final showRating = _readShelf || _o.rating.isActive;
    final showYears =
        widget.availableYears.isNotEmpty &&
        (_readShelf || _o.finishedYears.isNotEmpty);

    // Most relevant first: how the list runs and groups, the quick special
    // picks and when the book was finished, then what the book is (format,
    // tags), the three measures together (rating, pages, listening time),
    // and covers — tidying more than browsing — last.
    final sections = [
      _section('Sort by', [
        _sortRow(),
        // The same gap as between the sort menu and its direction button.
        const SizedBox(height: 8),
        _groupSeriesRow(),
      ]),
      _section('Show only', _showOnlyBody()),
      if (showYears)
        _section('Finished in', [
          _chips([
            for (final year in widget.availableYears)
              _chip(
                year,
                selected: _o.finishedYears.contains(year),
                onTap: () => _set(
                  _o.copyWith(finishedYears: _toggled(_o.finishedYears, year)),
                ),
              ),
          ]),
        ]),
      _section('Format', [
        _chips([
          for (final type in _bookTypes)
            _chip(
              type,
              selected: _o.bookTypes.contains(type),
              onTap: () =>
                  _set(_o.copyWith(bookTypes: _toggled(_o.bookTypes, type))),
            ),
        ]),
      ]),
      if (widget.availableTags.isNotEmpty) _section('Tags', _tagBody()),
      if (showRating)
        _measureSection(
          ratingMeasure,
          _o.rating,
          ratingPool,
          (r) => _set(_o.copyWith(rating: r)),
        ),
      if (showPages)
        _measureSection(
          pagesMeasure,
          _o.pages,
          lengthPool,
          (r) => _set(_o.copyWith(pages: r)),
        ),
      if (showListening)
        _measureSection(
          listeningMeasure,
          _o.listening,
          lengthPool,
          (r) => _set(_o.copyWith(listening: r)),
        ),
      _section('Cover', _coverBody()),
    ];

    return Padding(
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: MediaQuery.of(context).size.height * 0.85,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ── Handle ──────────────────────────────────────────────────
            const SizedBox(height: 12),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: _colors.onSurfaceVariant.withAlpha(80),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 14),

            // ── Header ──────────────────────────────────────────────────
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 8, 12),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Sort & Filter',
                          style: theme.textTheme.titleLarge,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          active == 0
                              ? widget.scopeLabel
                              : '${widget.scopeLabel} · $active '
                                    '${active == 1 ? 'filter' : 'filters'} on',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: _colors.onSurfaceVariant,
                          ),
                        ),
                      ],
                    ),
                  ),
                  TextButton(
                    onPressed: active == 0 ? null : () => _set(_o.cleared()),
                    child: const Text('Clear all'),
                  ),
                ],
              ),
            ),
            Divider(height: 1, thickness: 1, color: _colors.outlineVariant),

            // ── Sections ────────────────────────────────────────────────
            Flexible(
              // A chip paints the theme's canvas colour under its own
              // background, so the clear "+23 more" chip came out as a dark
              // pill in the sheet. A clear canvas lets it be plain text.
              child: Theme(
                data: theme.copyWith(canvasColor: Colors.transparent),
                child: SingleChildScrollView(
                  // Room under the last section, so it doesn't sit tight
                  // against the line over the button.
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: sections,
                  ),
                ),
              ),
            ),

            // ── Show ────────────────────────────────────────────────────
            Container(
              padding: EdgeInsets.fromLTRB(
                16,
                12,
                16,
                12 + MediaQuery.of(context).padding.bottom,
              ),
              decoration: BoxDecoration(
                border: Border(top: BorderSide(color: _colors.outlineVariant)),
              ),
              child: FilledButton(
                onPressed: () => Navigator.pop(context, _o),
                style: FilledButton.styleFrom(
                  backgroundColor:
                      widget.settingsViewModel.accentColorNotifier.value,
                  minimumSize: const Size.fromHeight(48),
                ),
                child: Text('Show $count ${count == 1 ? 'book' : 'books'}'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
