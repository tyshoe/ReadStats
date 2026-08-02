import 'dart:io';
import 'dart:math';
import 'dart:ui' show lerpDouble;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

/// Case-opening style picker: a horizontal strip of covers scrolls past a fixed
/// center ticker, decelerating onto a random book. Pops the chosen book back to
/// the caller when the user confirms (or null if dismissed — closing or
/// shuffling again is how the user skips a pick).
class RandomBookPicker extends StatefulWidget {
  final List<Map<String, dynamic>> books;

  /// What pool the pick is drawn from, e.g. "Sci-Fi · 42 books". Shown as a
  /// subtitle so it's clear the pick respects the current shelf/filters.
  final String scopeLabel;

  /// Label of the confirm button — what happens to the picked book.
  final String confirmLabel;

  /// Optional hint under the buttons explaining how to change the pool.
  final String? footerNote;

  const RandomBookPicker({
    super.key,
    required this.books,
    required this.scopeLabel,
    this.confirmLabel = 'Open',
    this.footerNote =
        'Change the shelf or filters to change which books are picked from.',
  });

  @override
  State<RandomBookPicker> createState() => _RandomBookPickerState();
}

class _RandomBookPickerState extends State<RandomBookPicker>
    with SingleTickerProviderStateMixin {
  static const double _cardW = 120;
  static const double _cardH = 196;
  static const double _gap = 8;
  static const double _itemExtent = _cardW + _gap;

  final _rng = Random();

  late final AnimationController _spin;
  late final Animation<double> _reel;

  // The strip of covers to scroll through, and the index that lands on center.
  List<Map<String, dynamic>> _sequence = [];
  int _winnerIndex = 0;
  // A small offset (px) so the ticker doesn't land dead-center every time.
  double _jitter = 0;
  bool _settled = false;

  // Total px the strip travels; used to fire a haptic tick per card that
  // crosses the caret. The count naturally slows with the deceleration.
  double _totalDistance = 0;
  int _tickCount = 0;

  Map<String, dynamic> get _finalBook => _sequence[_winnerIndex];

  @override
  void initState() {
    super.initState();
    _spin = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4200),
    )..addStatusListener((status) {
        if (status == AnimationStatus.completed) _settle();
      });
    // Long fast scroll easing to a graceful stop.
    _reel = CurvedAnimation(parent: _spin, curve: Curves.easeOutQuint);
    _spin.addListener(_onReelTick);

    _buildSequence();
    if (widget.books.length == 1) {
      _settled = true;
      WidgetsBinding.instance
          .addPostFrameCallback((_) => HapticFeedback.mediumImpact());
    } else {
      _spin.forward();
    }
  }

  @override
  void dispose() {
    _spin.dispose();
    super.dispose();
  }

  void _startShuffle() {
    setState(() {
      _settled = false;
      _buildSequence();
    });
    if (widget.books.length == 1) {
      _settle();
      return;
    }
    _spin
      ..reset()
      ..forward();
  }

  /// Fills the strip with non-repeating random covers, plants the winner deep
  /// enough that plenty fly past, and leaves a buffer to its right so the
  /// viewport stays full when it rests.
  void _buildSequence() {
    if (widget.books.length == 1) {
      _sequence = [widget.books.first];
      _winnerIndex = 0;
      _jitter = 0;
      return;
    }

    _winnerIndex = 28 + _rng.nextInt(8);
    final total = _winnerIndex + 6;
    final seq = <Map<String, dynamic>>[];
    for (var i = 0; i < total; i++) {
      Map<String, dynamic> pick;
      do {
        pick = widget.books[_rng.nextInt(widget.books.length)];
      } while (seq.isNotEmpty && pick['id'] == seq.last['id']);
      seq.add(pick);
    }
    _sequence = seq;
    _jitter = (_rng.nextDouble() * 2 - 1) * _cardW * 0.18;
    // Distance from the start offset to the resting offset (see _strip); the
    // viewport-center term cancels, so it needs no layout width.
    _totalDistance =
        _itemExtent + _winnerIndex * _itemExtent + _cardW / 2 - _jitter;
    _tickCount = 0;
  }

  /// Fires a light tick each time another card has scrolled past the caret.
  void _onReelTick() {
    if (_settled) return;
    final passed = (_totalDistance * _reel.value / _itemExtent).floor();
    if (passed != _tickCount) {
      _tickCount = passed;
      HapticFeedback.selectionClick();
      SystemSound.play(SystemSoundType.click);
    }
  }

  void _settle() {
    if (_settled) return;
    HapticFeedback.mediumImpact();
    setState(() => _settled = true);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final book = _settled ? _finalBook : null;

    return Dialog(
      backgroundColor: Colors.transparent,
      elevation: 0,
      insetPadding: const EdgeInsets.all(20),
      child: Stack(
        alignment: Alignment.topRight,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
          Text(
            _settled ? 'Your next read' : 'Picking a book…',
            style: theme.textTheme.titleMedium?.copyWith(
              color: Colors.white,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 2),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.shuffle, size: 13, color: Colors.white60),
              const SizedBox(width: 5),
              Flexible(
                child: Text(
                  widget.scopeLabel,
                  textAlign: TextAlign.center,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: theme.textTheme.bodySmall?.copyWith(
                    color: Colors.white60,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          // Small marker pointing down at the card that will land under it.
          Icon(Icons.arrow_drop_down, color: theme.colorScheme.primary, size: 26),
          _buildReel(theme),
          const SizedBox(height: 20),
          // Reserve space so the layout doesn't jump when the title appears.
          AnimatedOpacity(
            opacity: _settled ? 1.0 : 0.0,
            duration: const Duration(milliseconds: 240),
            child: SizedBox(
              height: 52,
              child: book == null
                  ? null
                  : Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          book['title'] ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.titleSmall?.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        Text(
                          book['author'] ?? '',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: Colors.white70,
                          ),
                        ),
                      ],
                    ),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              TextButton(
                onPressed: _settled ? _startShuffle : null,
                style: TextButton.styleFrom(foregroundColor: Colors.white),
                child: const Text('Shuffle again'),
              ),
              const SizedBox(width: 8),
              FilledButton(
                onPressed:
                    _settled ? () => Navigator.of(context).pop(_finalBook) : null,
                child: Text(widget.confirmLabel),
              ),
            ],
          ),
          if (widget.footerNote != null) ...[
            const SizedBox(height: 10),
            Text(
              widget.footerNote!,
              textAlign: TextAlign.center,
              style: theme.textTheme.bodySmall?.copyWith(
                color: Colors.white54,
                fontStyle: FontStyle.italic,
              ),
            ),
          ],
            ],
          ),
          // Explicit dismiss, even though tapping the barrier also closes it.
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: Colors.white70),
            tooltip: 'Close',
          ),
        ],
      ),
    );
  }

  Widget _buildReel(ThemeData theme) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      // Flick the reel leftward to re-roll once it's landed (matches the
      // scroll direction). A rightward flick does nothing.
      onHorizontalDragEnd: (details) {
        final v = details.primaryVelocity ?? 0;
        if (_settled && v < -200) _startShuffle();
      },
      child: SizedBox(
        height: _cardH,
        // The scrolling strip, hard-clipped so covers cut cleanly at the edges.
        child: ClipRect(
          child: LayoutBuilder(
            builder: (context, constraints) {
              final viewportW = constraints.maxWidth;
              return AnimatedBuilder(
                animation: _reel,
                builder: (context, _) => _strip(viewportW),
              );
            },
          ),
        ),
      ),
    );
  }

  /// Lays out only the covers currently within the viewport, translated so the
  /// winner ends up under the center ticker.
  Widget _strip(double viewportW) {
    final center = viewportW / 2;
    // Where the winner's center should rest (dead-center + a little jitter).
    final targetTx = center - (_winnerIndex * _itemExtent + _cardW / 2) + _jitter;
    // Start pushed off to the right so the strip scrolls leftward into place.
    final startTx = center + _itemExtent;
    final tx = lerpDouble(startTx, targetTx, _reel.value)!;

    final first = (((-_cardW) - tx) / _itemExtent).floor().clamp(0, _sequence.length - 1);
    final last = ((viewportW - tx) / _itemExtent).ceil().clamp(0, _sequence.length - 1);

    final cards = <Widget>[];
    for (var i = first; i <= last; i++) {
      final left = i * _itemExtent + tx;
      final isWinner = _settled && i == _winnerIndex;
      cards.add(Positioned(
        left: left,
        top: 0,
        width: _cardW,
        height: _cardH,
        child: AnimatedScale(
          scale: isWinner ? 1.0 : (_settled ? 0.9 : 1.0),
          duration: const Duration(milliseconds: 220),
          child: AnimatedOpacity(
            opacity: _settled && !isWinner ? 0.45 : 1.0,
            duration: const Duration(milliseconds: 220),
            child: _CoverCard(book: _sequence[i]),
          ),
        ),
      ));
    }
    return Stack(clipBehavior: Clip.none, children: cards);
  }
}

/// Book cover matching the library grid look: cover image with a text fallback.
class _CoverCard extends StatelessWidget {
  final Map<String, dynamic> book;

  const _CoverCard({required this.book});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final coverPath = book['cover_path'] as String?;

    return Card(
      // No elevation: the drop shadow smears into grey bands under the reel's
      // edge fade as cards scroll past.
      elevation: 0,
      margin: EdgeInsets.zero,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      child: coverPath != null
          ? Image.file(
              File(coverPath),
              fit: BoxFit.cover,
              width: double.infinity,
              height: double.infinity,
              errorBuilder: (_, _, _) => _placeholder(theme),
            )
          : _placeholder(theme),
    );
  }

  Widget _placeholder(ThemeData theme) {
    return Container(
      // Fill the card so a coverless book is the same size as one with a cover,
      // regardless of how short the title is.
      width: double.infinity,
      height: double.infinity,
      color: theme.cardTheme.color ?? theme.colorScheme.surface,
      padding: const EdgeInsets.all(10),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            book['title'] ?? '',
            style: theme.textTheme.bodySmall,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
          ),
          const Spacer(),
          Text(
            book['author'] ?? '',
            style: theme.textTheme.labelSmall?.copyWith(
              color: theme.textTheme.bodySmall?.color?.withValues(alpha: 0.6),
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
      ),
    );
  }
}
