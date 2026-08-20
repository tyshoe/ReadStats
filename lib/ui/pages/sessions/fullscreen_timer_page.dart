import 'dart:async';
import 'dart:io';
import 'dart:ui' show ImageFilter;
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '/data/services/reading_timer_service.dart';
import '/data/repositories/session_repository.dart';
import '/data/repositories/book_repository.dart';
import '/viewmodels/SettingsViewModel.dart';
import 'post_session_page.dart';
import 'widgets/countdown_sheet.dart';

/// Immersive version of the inline reading timer. Pops with the finished book
/// (or null) once the session has been saved or discarded, so the caller can
/// pick the flow back up.
class FullscreenTimerPage extends StatefulWidget {
  final ReadingTimerService timerService;
  final Map<String, dynamic> book;
  final SessionRepository sessionRepository;
  final BookRepository bookRepository;
  final SettingsViewModel settingsViewModel;
  final VoidCallback onSessionSaved;

  const FullscreenTimerPage({
    super.key,
    required this.timerService,
    required this.book,
    required this.sessionRepository,
    required this.bookRepository,
    required this.settingsViewModel,
    required this.onSessionSaved,
  });

  @override
  State<FullscreenTimerPage> createState() => _FullscreenTimerPageState();
}

class _FullscreenTimerPageState extends State<FullscreenTimerPage>
    with SingleTickerProviderStateMixin {
  /// How long the page stays lit before settling into its dark reading state.
  static const _sleepAfter = Duration(seconds: 30);

  /// Well under the device's media volume — this is a nudge, not an alarm.
  static const _chimeVolume = 0.25;

  late final AnimationController _pulse;
  final AudioPlayer _chime = AudioPlayer();
  Timer? _sleepTimer;
  bool _asleep = false;
  bool? _wasRunning;
  bool _alertedTimeUp = false;

  @override
  void initState() {
    super.initState();
    _pulse = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3200),
    );
    widget.timerService.addListener(_onTimerChanged);
    final isRunning = widget.timerService.state == TimerState.running;
    _syncPulse(isRunning);
    _syncSleep(isRunning);
  }

  @override
  void dispose() {
    widget.timerService.removeListener(_onTimerChanged);
    _sleepTimer?.cancel();
    _chime.dispose();
    _pulse.dispose();
    super.dispose();
  }

  /// Fires once a second while the session runs, plus on every state change.
  /// All the page's side effects hang off it so that [build] stays pure.
  void _onTimerChanged() {
    final isRunning = widget.timerService.state == TimerState.running;
    _syncPulse(isRunning);
    _syncSleep(isRunning);
    if ((_isOvertime || widget.timerService.pausedBySleep) && !_alertedTimeUp) {
      _handleTimeUp();
    }
  }

  // The page opens bright and only sleeps once the user has settled into
  // reading; pausing or touching the screen wakes it straight back up.
  void _syncSleep(bool isRunning) {
    if (_wasRunning == isRunning) return;
    _wasRunning = isRunning;
    if (isRunning) {
      _scheduleSleep();
    } else {
      _sleepTimer?.cancel();
      _sleepTimer = null;
      if (_asleep) setState(() => _asleep = false);
    }
  }

  void _scheduleSleep() {
    _sleepTimer?.cancel();
    _sleepTimer = Timer(_sleepAfter, () {
      if (mounted) setState(() => _asleep = true);
    });
  }

  void _wake() {
    if (_asleep) setState(() => _asleep = false);
    // Only a running session settles back down on its own; a paused one stays
    // lit, since the reader is being asked what to do next.
    if (widget.timerService.state == TimerState.running) _scheduleSleep();
  }

  bool get _isOvertime {
    final remaining = widget.timerService.remaining;
    return remaining != null && remaining.inMilliseconds <= 0;
  }

  // Countdown finished: wake the screen, buzz and chime, and let the countdown
  // chip carry the message. Under `chime` the session keeps running, so nothing
  // is lost if the user is deep in a chapter and ignores it; under `pause` the
  // service has already stopped the clock and this is just the announcement.
  void _handleTimeUp() {
    if (_alertedTimeUp) return;
    _alertedTimeUp = true;
    if (_asleep) setState(() => _asleep = false);
    // Hold the page lit for a minute after the alert, then let it settle back
    // down rather than burning the screen all evening.
    _sleepTimer?.cancel();
    _sleepTimer = Timer(const Duration(minutes: 1), () {
      if (mounted) setState(() => _asleep = true);
    });
    _playAlert();
  }

  // A soft chime over three long buzzes — enough to feel through a pocket or
  // a cushion, unhurried enough not to jolt someone out of a chapter.
  Future<void> _playAlert() async {
    unawaited(_playChime());
    for (var i = 0; i < 4; i++) {
      HapticFeedback.vibrate();
      await Future.delayed(const Duration(milliseconds: 500));
      if (!mounted) return;
    }
  }

  // Audio can fail for reasons that have nothing to do with the session (no
  // audio focus, a stale install missing the plugin) — fall back to the system
  // tone rather than letting the alert throw.
  Future<void> _playChime() async {
    try {
      await _chime.play(
        AssetSource('sounds/timer_chime.wav'),
        volume: _chimeVolume,
      );
    } catch (_) {
      SystemSound.play(SystemSoundType.alert);
    }
  }

  void _stopCountdown() {
    _alertedTimeUp = false;
    _wake();
    // Notifies its listeners, so the chip and clock rebuild on their own.
    widget.timerService.startCountdown(null);
  }

  Future<void> _openCountdownSheet() async {
    _wake();
    final picked = await showCountdownSheet(
      context: context,
      current: widget.timerService.countdown,
      currentEnd: widget.timerService.countdownEnd,
      accent: widget.settingsViewModel.accentColorNotifier.value,
    );
    if (picked == null || !mounted) return;

    _alertedTimeUp = false;
    widget.timerService.startCountdown(
      picked.duration == Duration.zero ? null : picked.duration,
      end: picked.end,
    );
    if (widget.timerService.state == TimerState.running) _scheduleSleep();
  }

  // While reading, the ambient wash breathes between a floor and full
  // strength; pausing eases it away instead of snapping off.
  void _syncPulse(bool isRunning) {
    if (isRunning && !_pulse.isAnimating) {
      _pulse.repeat(min: 0.7, max: 1, reverse: true);
    } else if (!isRunning && (_pulse.isAnimating || _pulse.value > 0)) {
      _pulse.animateTo(
        0,
        duration: const Duration(milliseconds: 700),
        curve: Curves.easeOut,
      );
    }
  }

  Future<void> _handleFinish() async {
    if (widget.timerService.state == TimerState.running) {
      widget.timerService.pause();
    }

    final result = await Navigator.push<Map<String, dynamic>?>(
      context,
      MaterialPageRoute(
        builder: (_) => PostSessionPage(
          book: widget.book,
          timerService: widget.timerService,
          sessionRepository: widget.sessionRepository,
          bookRepository: widget.bookRepository,
          settingsViewModel: widget.settingsViewModel,
          onSaved: widget.onSessionSaved,
        ),
      ),
    );

    if (!mounted) return;
    // Saved or discarded — there is no session left to show full screen.
    // Otherwise the user backed out and the timer is still theirs to run.
    if (widget.timerService.state == TimerState.idle) {
      Navigator.pop(context, result);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final accent = widget.settingsViewModel.accentColorNotifier.value;
    final coverPath = widget.book['cover_path'] as String?;

    // Everything on the page dims with the background once it has gone to
    // sleep; it comes back to full strength on pause or on a tap anywhere.
    // Only the clock and the buttons listen to the timer, so the cover and
    // title are not rebuilt on every tick.
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          _buildBackground(cs, accent, coverPath),
          GestureDetector(
            behavior: HitTestBehavior.translucent,
            onTap: _wake,
            child: AnimatedOpacity(
              opacity: _asleep ? 0.62 : 1,
              duration: const Duration(milliseconds: 700),
              curve: Curves.easeOut,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  // Outside the SafeArea on purpose: the clock is centered on
                  // the screen itself, not on the space between the chrome.
                  RepaintBoundary(
                    child: ListenableBuilder(
                      listenable: widget.timerService,
                      builder: (context, _) =>
                          _buildClock(theme: theme, accent: accent),
                    ),
                  ),
                  SafeArea(
                    child: Column(
                      children: [
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.fromLTRB(8, 4, 8, 0),
                            child: IconButton(
                              tooltip: 'Minimize',
                              icon: const Icon(Icons.close_fullscreen),
                              color: cs.onSurface.withAlpha(180),
                              onPressed: () => Navigator.pop(context),
                            ),
                          ),
                        ),
                        _buildBookHeader(theme, coverPath),
                        const Spacer(),
                        ListenableBuilder(
                          listenable: widget.timerService,
                          builder: (context, _) => _buildControls(
                            theme,
                            accent,
                            widget.timerService.state == TimerState.running,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // Reading is the eyes-off state, so a settled page goes dark and quiet: the
  // cover drains to near-grey behind a heavy veil, lit only by accent light
  // breathing in from the corners. It starts bright, and pausing or a tap
  // brings it back up — those are the moments the user is actually looking.
  Widget _buildBackground(ColorScheme cs, Color accent, String? coverPath) {
    // `begin` only applies on the very first build; afterwards a changed `end`
    // animates from wherever the value currently sits, which is what carries
    // the page between its lit and settled looks.
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: _asleep ? 1 : 0, end: _asleep ? 1 : 0),
      duration: const Duration(milliseconds: 700),
      curve: Curves.easeOut,
      builder: (context, dim, _) {
        return Stack(
          fit: StackFit.expand,
          children: [
            Container(color: cs.surface),
            if (coverPath != null)
              ColorFiltered(
                colorFilter:
                    ColorFilter.matrix(_saturationMatrix(1 - 0.55 * dim)),
                // The blur is by far the most expensive thing on the page —
                // cache its raster so the breathing glow above cannot force it
                // to be recomputed every frame.
                child: RepaintBoundary(
                  child: ImageFiltered(
                    imageFilter: ImageFilter.blur(sigmaX: 48, sigmaY: 48),
                    child: Image.file(
                      File(coverPath),
                      fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
              ),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: coverPath == null
                      ? [cs.surface, cs.surface]
                      : [
                          cs.surface.withAlpha(186),
                          cs.surface.withAlpha(216),
                        ],
                ),
              ),
            ),
            // The dimmer itself.
            DecoratedBox(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.62 * dim),
              ),
            ),
            RepaintBoundary(
              child: AnimatedBuilder(
                animation: _pulse,
                builder: (context, _) {
                  final glow = _pulse.value;
                  return Stack(
                    fit: StackFit.expand,
                    children: [
                      _accentBlob(
                        accent,
                        const Alignment(-0.9, -0.95),
                        1.15,
                        0.42 * glow,
                      ),
                      _accentBlob(
                        accent,
                        const Alignment(0.95, 0.9),
                        1.25,
                        0.34 * glow,
                      ),
                      _accentBlob(
                        accent,
                        const Alignment(0, -0.1),
                        1.3,
                        0.10 * glow,
                      ),
                    ],
                  );
                },
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _accentBlob(Color accent, Alignment center, double radius, double alpha) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: RadialGradient(
          center: center,
          radius: radius,
          colors: [accent.withValues(alpha: alpha), Colors.transparent],
        ),
      ),
    );
  }

  // 1 = the cover's own colors, 0 = fully grey.
  List<double> _saturationMatrix(double s) {
    const lr = 0.2126, lg = 0.7152, lb = 0.0722;
    final ir = (1 - s) * lr, ig = (1 - s) * lg, ib = (1 - s) * lb;
    return [
      ir + s, ig, ib, 0, 0,
      ir, ig + s, ib, 0, 0,
      ir, ig, ib + s, 0, 0,
      0, 0, 0, 1, 0,
    ];
  }

  Widget _buildBookHeader(ThemeData theme, String? coverPath) {
    final cs = theme.colorScheme;
    final title = widget.book['title'] as String? ?? '';
    final author = widget.book['author'] as String?;

    final details = Column(
      crossAxisAlignment:
          coverPath != null ? CrossAxisAlignment.start : CrossAxisAlignment.center,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          title,
          textAlign: coverPath != null ? TextAlign.start : TextAlign.center,
          maxLines: 3,
          overflow: TextOverflow.ellipsis,
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.w600,
          ),
        ),
        if (author?.isNotEmpty == true) ...[
          const SizedBox(height: 6),
          Text(
            author!,
            textAlign: coverPath != null ? TextAlign.start : TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
            style: theme.textTheme.bodyMedium?.copyWith(
              color: cs.onSurface.withAlpha(150),
            ),
          ),
        ],
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(28, 4, 28, 0),
      child: coverPath == null
          ? details
          : Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Flexible(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Image.file(
                      File(coverPath),
                      height: 168,
                      fit: BoxFit.contain,
                      errorBuilder: (_, __, ___) => const SizedBox.shrink(),
                    ),
                  ),
                ),
                const SizedBox(width: 20),
                Expanded(child: details),
              ],
            ),
    );
  }

  Widget _buildClock({required ThemeData theme, required Color accent}) {
    final cs = theme.colorScheme;
    final service = widget.timerService;
    final elapsed = service.elapsed;
    final remaining = service.remaining;
    final timeUp = remaining != null && remaining.inMilliseconds <= 0;
    final isRunning = service.state == TimerState.running;

    // Three full-screen layers, each centred and then offset: the clock stays
    // exactly on the screen's center point, and the chips above and below it
    // stay tappable (a Positioned child hanging outside its Stack would not).
    return Stack(
      fit: StackFit.expand,
      children: [
        Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(
                _formatClock(elapsed),
                style: theme.textTheme.displayLarge?.copyWith(
                  fontSize: 92,
                  height: 1.05,
                  fontWeight: FontWeight.w700,
                  fontFeatures: [const FontFeature.tabularFigures()],
                  letterSpacing: 1,
                  color: cs.onSurface,
                ),
              ),
            ),
          ),
        ),
        // The countdown lives directly above the clock — both as the readout
        // and as the control that starts, changes and stops it.
        Center(
          child: Transform.translate(
            offset: const Offset(0, -90),
            child: _CountdownChip(
              remaining: remaining,
              end: service.countdownEnd,
              timeUp: timeUp,
              accent: accent,
              onTap: _openCountdownSheet,
              onStop: _stopCountdown,
            ),
          ),
        ),
        Center(
          child: Transform.translate(
            offset: const Offset(0, 88),
            child: _StatusPill(
              isRunning: isRunning,
              pausedBySleep: service.pausedBySleep,
              accent: accent,
            ),
          ),
        ),
      ],
    );
  }

  // Same buttons as the inline timer, just taller: Pause on its own while
  // running, Resume + Finish once paused.
  Widget _buildControls(ThemeData theme, Color accent, bool isRunning) {
    final textStyle =
        theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600);

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 12, 20, 64),
      child: isRunning
          ? SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: widget.timerService.pause,
                icon: const Icon(Icons.pause, size: 24),
                label: const Text('Pause'),
                style: FilledButton.styleFrom(
                  backgroundColor: accent,
                  minimumSize: const Size.fromHeight(60),
                  textStyle: textStyle,
                ),
              ),
            )
          : Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: widget.timerService.resume,
                    icon: const Icon(Icons.play_arrow, size: 24),
                    label: const Text('Resume'),
                    style: FilledButton.styleFrom(
                      backgroundColor: accent,
                      minimumSize: const Size.fromHeight(60),
                      textStyle: textStyle,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _handleFinish,
                    icon: const Icon(Icons.flag, size: 24),
                    label: const Text('Finish'),
                    style: OutlinedButton.styleFrom(
                      minimumSize: const Size.fromHeight(60),
                      side: BorderSide(
                        color: theme.colorScheme.outline.withAlpha(80),
                      ),
                      textStyle: textStyle,
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}

String _formatClock(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  if (h > 0) {
    return '$h:${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
  return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
}

/// The optional countdown, sitting directly above the session clock so the two
/// read as separate things: one counts the session up, this one counts down.
/// It doubles as its own control — tap to set or change it, ✕ to stop it.
class _CountdownChip extends StatelessWidget {
  final Duration? remaining;
  final CountdownEnd end;
  final bool timeUp;
  final Color accent;
  final VoidCallback onTap;
  final VoidCallback onStop;

  const _CountdownChip({
    required this.remaining,
    required this.end,
    required this.timeUp,
    required this.accent,
    required this.onTap,
    required this.onStop,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final left = remaining;

    final isSleep = end == CountdownEnd.pause;

    final String label;
    if (left == null) {
      // Named for the mode it now opens on, and the one worth advertising —
      // a chime countdown is one tap further in.
      label = 'Sleep timer';
    } else if (timeUp) {
      label = "Time's up · +${_formatClock(-left)}";
    } else if (isSleep) {
      label = 'Sleeps in ${_formatClock(left)}';
    } else {
      label = '${_formatClock(left)} left';
    }

    final foreground = timeUp
        ? cs.onPrimary
        : cs.onSurface.withAlpha(left == null ? 150 : 210);

    return Material(
      color: timeUp
          ? accent
          : cs.onSurface.withAlpha(left == null ? 12 : 18),
      borderRadius: BorderRadius.circular(999),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: EdgeInsets.fromLTRB(14, 8, left == null ? 16 : 6, 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                left == null || isSleep ? Icons.bedtime : Icons.hourglass_top,
                size: 18,
                color: foreground,
              ),
              const SizedBox(width: 8),
              Text(
                label,
                style: (left == null
                        ? theme.textTheme.labelLarge
                        : theme.textTheme.titleMedium)
                    ?.copyWith(
                  fontWeight: FontWeight.w700,
                  fontFeatures: [const FontFeature.tabularFigures()],
                  color: foreground,
                ),
              ),
              if (left != null)
                IconButton(
                  tooltip: 'Stop countdown',
                  icon: const Icon(Icons.close, size: 18),
                  color: foreground,
                  visualDensity: VisualDensity.compact,
                  constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
                  padding: EdgeInsets.zero,
                  onPressed: onStop,
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Quiet reading/paused indicator: a tinted capsule that cross-fades between
/// the accent color and a neutral surface tone.
class _StatusPill extends StatelessWidget {
  final bool isRunning;
  final bool pausedBySleep;
  final Color accent;

  const _StatusPill({
    required this.isRunning,
    required this.pausedBySleep,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final cs = theme.colorScheme;
    final muted = cs.onSurface.withAlpha(120);

    return AnimatedContainer(
      duration: const Duration(milliseconds: 400),
      curve: Curves.easeOut,
      padding: const EdgeInsets.fromLTRB(12, 6, 14, 6),
      decoration: BoxDecoration(
        color: isRunning ? accent.withAlpha(30) : cs.onSurface.withAlpha(14),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: 8,
            height: 8,
            decoration: BoxDecoration(
              color: isRunning ? accent : muted,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 8),
          AnimatedDefaultTextStyle(
            duration: const Duration(milliseconds: 400),
            style: (theme.textTheme.labelMedium ?? const TextStyle()).copyWith(
              letterSpacing: 0.6,
              fontWeight: FontWeight.w600,
              color: isRunning ? accent : muted,
            ),
            child: Text(
              isRunning
                  ? 'Reading'
                  : pausedBySleep
                      ? 'Sleep timer ended'
                      : 'Paused',
            ),
          ),
        ],
      ),
    );
  }
}
