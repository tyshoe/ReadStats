import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:read_stats/data/services/analytics_service.dart';
import 'package:read_stats/data/services/recap_store.dart';
import 'package:read_stats/domain/wrapped_story.dart';
import 'package:read_stats/domain/year_wrapped.dart';
import 'package:read_stats/ui/pages/wrapped/slides/wrapped_slide_view.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_share.dart';
import 'package:read_stats/ui/pages/wrapped/wrapped_style.dart';
import 'package:read_stats/ui/widgets/book_picker_sheet.dart';

/// ReadStats Wrapped: a year of reading told one full-screen slide at a time.
///
/// Tap the right of the screen (or swipe) to go on, the left to go back. The
/// story never moves on by itself — these are slides people read, and some of
/// them take a moment to take in.
///
/// Works from the app-level book and session lists, like the monthly recap:
/// cover paths are already resolved and the year is a single pass over rows
/// the app is already holding.
class WrappedPage extends StatefulWidget {
  final List<Map<String, dynamic>> books;
  final List<Map<String, dynamic>> sessions;
  final int year;

  const WrappedPage({
    super.key,
    required this.books,
    required this.sessions,
    required this.year,
  });

  /// Fades up from the screen it was opened on, rather than sliding in like an
  /// ordinary page — it is an event, not a step deeper into Statistics.
  static Route<void> route({
    required List<Map<String, dynamic>> books,
    required List<Map<String, dynamic>> sessions,
    required int year,
  }) {
    return PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 420),
      reverseTransitionDuration: const Duration(milliseconds: 260),
      pageBuilder: (_, _, _) =>
          WrappedPage(books: books, sessions: sessions, year: year),
      transitionsBuilder: (_, animation, _, child) {
        final curved =
            CurvedAnimation(parent: animation, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: curved,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.94, end: 1).animate(curved),
            child: child,
          ),
        );
      },
    );
  }

  @override
  State<WrappedPage> createState() => _WrappedPageState();
}

class _WrappedPageState extends State<WrappedPage>
    with TickerProviderStateMixin {
  static const _entranceDuration = Duration(milliseconds: 1600);

  /// Rebuilt when the reader names a different book of the year. The slides
  /// stay the same either way, so the page around them doesn't change.
  late WrappedStory _story;
  late final YearWrapped _previous;
  late final List<int> _otherYears;
  late final PageController _pager;
  late final AnimationController _ambient;
  late final List<AnimationController> _entrances;

  /// Fills the current slide's progress bar. Unlike the entrances it plays
  /// on every visit, so a revisited slide's bar still fills.
  late final AnimationController _fill;

  /// [_fill] after a short hold, eased in, so a new bar starts slowly
  /// instead of leaping off.
  late final CurvedAnimation _fillCurve;

  /// Slides whose entrance has played. Coming back to one shows it settled
  /// rather than making the reader sit through it twice.
  final Set<int> _played = {};

  int _index = 0;

  /// The slide a tap is animating toward, until it arrives.
  int? _heading;

  /// The slide whose bar is filling. Runs ahead of [_index] on a tap, which
  /// only changes once the page is halfway across.
  int _barIndex = 0;
  bool _reduceMotion = false;

  List<WrappedSlide> get _slides => _story.slides;
  WrappedSlide get _slide => _slides[_index];

  @override
  void initState() {
    super.initState();
    AnalyticsService.instance.screen('wrapped');
    AnalyticsService.instance.wrappedOpened();
    _previous = YearWrapped.forYear(
      books: widget.books,
      sessions: widget.sessions,
      year: widget.year - 1,
    );
    _story = _buildStoryData();
    _otherYears = YearWrapped.availableYears(
      books: widget.books,
      sessions: widget.sessions,
    ).where((y) => y != widget.year).toList();

    _pager = PageController();
    _ambient = AnimationController(
      vsync: this,
      duration: const Duration(seconds: 18),
    );
    _entrances = [
      for (final _ in _slides)
        AnimationController(vsync: this, duration: _entranceDuration),
    ];
    // A short hold before the bar starts, then the same fill time as the
    // entrance.
    const fillDelay = Duration(milliseconds: 200);
    final fillTotal = _entranceDuration + fillDelay;
    _fill = AnimationController(vsync: this, duration: fillTotal);
    _fillCurve = CurvedAnimation(
      parent: _fill,
      curve: Interval(
        fillDelay.inMilliseconds / fillTotal.inMilliseconds,
        1,
        curve: Curves.easeIn,
      ),
    );
    RecapStore.instance.markWrappedSeen(widget.year);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Honour the system's reduce-motion switch: slides arrive already in
    // place and the backdrop holds still.
    _reduceMotion = MediaQuery.of(context).disableAnimations;
    if (_reduceMotion) {
      _ambient.stop();
    } else if (!_ambient.isAnimating) {
      _ambient.repeat();
    }
    if (!_played.contains(_index)) {
      _play(_index);
      _startFill(_index);
    }
  }

  @override
  void dispose() {
    _pager.dispose();
    _ambient.dispose();
    _fillCurve.dispose();
    _fill.dispose();
    for (final c in _entrances) {
      c.dispose();
    }
    super.dispose();
  }

  void _play(int index) {
    _played.add(index);
    if (_reduceMotion) {
      _entrances[index].value = 1;
    } else {
      _entrances[index].forward(from: 0);
    }
  }

  void _startFill(int index) {
    _barIndex = index;
    if (_reduceMotion) {
      _fill.value = 1;
    } else {
      _fill.forward(from: 0);
    }
  }

  void _onPageChanged(int index) {
    setState(() {
      _index = index;
      // A tap already moved the bars; slides it passes on the way don't.
      if (_heading == null && index != _barIndex) _startFill(index);
    });
    HapticFeedback.selectionClick();
    if (!_played.contains(index)) _play(index);
  }

  Future<void> _go(int index) async {
    if (index < 0 || index >= _slides.length) return;
    // The bars move on the tap itself, not when the page is halfway over.
    setState(() {
      _heading = index;
      _startFill(index);
    });
    await _pager.animateToPage(
      index,
      duration: Duration(milliseconds: _reduceMotion ? 1 : 380),
      curve: Curves.easeOutCubic,
    );
    if (_heading == index) _heading = null;
  }

  void _onTapUp(TapUpDetails details) {
    // Count from where a slide in progress is heading, so a quick second
    // tap moves on again instead of repeating the first.
    final from = _heading ?? _index;
    final width = MediaQuery.sizeOf(context).width;
    if (details.localPosition.dx < width * 0.28) {
      _go(from - 1);
    } else {
      _go(from + 1);
    }
  }

  void _jump(int index) => _pager.jumpToPage(index);

  void _replay() {
    _played.clear();
    for (final c in _entrances) {
      c.value = 0;
    }
    setState(() => _startFill(0));
    _pager.jumpToPage(0);
    // jumpToPage reports no change when already on the first slide.
    if (_index == 0) _play(0);
  }

  WrappedStory _buildStoryData() => WrappedStory.of(
        YearWrapped.forYear(
          books: widget.books,
          sessions: widget.sessions,
          year: widget.year,
          chosenBookId: RecapStore.instance.bookOfYearPick(widget.year),
        ),
        previous: _previous,
      );

  /// Lets the reader name the book of the year themselves, from the books
  /// they finished that year — best rated first, so the likely picks are at
  /// hand.
  Future<void> _chooseBook() async {
    final w = _story.wrapped;
    final current = w.bookOfTheYear?.$1.id;
    final rows = {for (final b in widget.books) b['id']: b};
    final finished = w.finished.toList()
      ..sort((a, b) {
        final r = b.rating.compareTo(a.rating);
        return r != 0 ? r : b.finishedAt!.compareTo(a.finishedAt!);
      });
    final candidates = [
      for (final b in finished)
        if (b.id != current && rows[b.id] != null) rows[b.id]!,
    ];

    final picked = await showBookPickerSheet(
      context: context,
      books: candidates,
      title: 'Your book of ${widget.year}',
      emptyMessage: 'No other books finished in ${widget.year}',
    );
    if (picked == null || !mounted) return;

    final id = picked['id'] as int;
    await RecapStore.instance.setBookOfYearPick(widget.year, id);
    AnalyticsService.instance.wrappedBookChosen();
    if (!mounted) return;
    setState(() => _story = _buildStoryData());
  }

  void _openYear(int year) {
    Navigator.of(context).pushReplacement(WrappedPage.route(
      books: widget.books,
      sessions: widget.sessions,
      year: year,
    ));
  }

  void _share() =>
      shareWrappedSlide(context: context, story: _story, slide: _slide);

  @override
  Widget build(BuildContext context) {
    final palette = WrappedPalette.of(_slide, _story.wrapped);

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.light.copyWith(
        statusBarColor: Colors.transparent,
        systemNavigationBarColor: palette.deep,
      ),
      child: MediaQuery.withClampedTextScaling(
        maxScaleFactor: 1.15,
        child: Scaffold(
          backgroundColor: palette.deep,
          body: _story.wrapped.isEmpty ? _buildEmpty() : _buildStory(),
        ),
      ),
    );
  }

  Widget _buildStory() {
    final padding = MediaQuery.paddingOf(context);
    final isFinale = _slide == WrappedSlide.finale;

    return Stack(
      fit: StackFit.expand,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapUp: _onTapUp,
          child: PageView.builder(
            controller: _pager,
            onPageChanged: _onPageChanged,
            itemCount: _slides.length,
            itemBuilder: (context, i) {
              final slide = _slides[i];
              return WrappedSlideView(
                key: ValueKey(slide),
                slide: slide,
                env: SlideEnv(
                  story: _story,
                  entrance: _entrances[i],
                  ambient: _ambient,
                  insets: EdgeInsets.only(
                    top: padding.top + 64,
                    bottom: padding.bottom +
                        (slide == WrappedSlide.finale ? 20 : 80),
                  ),
                  onShare: _share,
                  onReplay: _replay,
                  onJump: _jump,
                  otherYears: _otherYears,
                  onOpenYear: _openYear,
                  onChooseBook: _chooseBook,
                ),
              );
            },
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: padding.top + 8,
          child: _buildChrome(),
        ),
        if (_slide.isShareable && !isFinale)
          Positioned(
            right: 20,
            bottom: padding.bottom + 22,
            child: _ShareButton(onTap: _share),
          ),
      ],
    );
  }

  Widget _buildChrome() {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Column(
        children: [
          Row(
            children: [
              for (var i = 0; i < _slides.length; i++)
                Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: _ProgressSegment(
                      fill: i < _barIndex
                          ? const AlwaysStoppedAnimation(1)
                          : i == _barIndex
                              ? _fillCurve
                              : const AlwaysStoppedAnimation(0),
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 4),
          Row(
            children: [
              const SizedBox(width: 6),
              Image.asset('assets/icon/readstats_white.png',
                  width: 16, height: 16),
              const SizedBox(width: 6),
              Text('${widget.year} Wrapped',
                  style: WrappedType.caption(context, alpha: 0.85)
                      .copyWith(fontWeight: FontWeight.w700)),
              if (_story.wrapped.isInProgress) ...[
                const SizedBox(width: 8),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 7, vertical: 2),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.16),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text('So far',
                      style: WrappedType.caption(context, alpha: 0.9)
                          .copyWith(fontSize: 11, fontWeight: FontWeight.w700)),
                ),
              ],
              const Spacer(),
              IconButton(
                icon: const Icon(Icons.close),
                color: Colors.white,
                tooltip: 'Close',
                onPressed: () => Navigator.of(context).maybePop(),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildEmpty() {
    return Stack(
      fit: StackFit.expand,
      children: [
        WrappedBackdrop(palette: WrappedPalette.intro, ambient: _ambient),
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: IconButton(
                    icon: const Icon(Icons.close),
                    color: Colors.white,
                    tooltip: 'Close',
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ),
                const Spacer(),
                Text('${widget.year}',
                    style: WrappedType.hero(context, size: 96)),
                const SizedBox(height: 12),
                Text('Nothing to wrap yet.',
                    style: WrappedType.headline(context)),
                const SizedBox(height: 10),
                Text(
                  'Log a reading session or finish a book, and your year '
                  'starts telling its story.',
                  style: WrappedType.body(context),
                ),
                const Spacer(flex: 2),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// One slide's bar in the progress strip: full once passed, empty ahead, and
/// filling with [fill] while current.
class _ProgressSegment extends StatelessWidget {
  final Animation<double> fill;

  const _ProgressSegment({required this.fill});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(2),
      child: SizedBox(
        height: 3,
        child: ColoredBox(
          color: Colors.white.withValues(alpha: 0.25),
          child: AnimatedBuilder(
            animation: fill,
            builder: (context, _) => FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: fill.value.clamp(0.0, 1.0),
              child: const ColoredBox(color: Colors.white),
            ),
          ),
        ),
      ),
    );
  }
}

class _ShareButton extends StatelessWidget {
  final VoidCallback onTap;

  const _ShareButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.white,
      borderRadius: BorderRadius.circular(24),
      child: InkWell(
        borderRadius: BorderRadius.circular(24),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.ios_share, size: 18, color: Colors.black),
              const SizedBox(width: 6),
              Text('Share',
                  style: WrappedType.caption(context, alpha: 1).copyWith(
                      color: Colors.black,
                      fontSize: 14,
                      fontWeight: FontWeight.w700)),
            ],
          ),
        ),
      ),
    );
  }
}
