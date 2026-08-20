import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimerState { idle, running, paused }

/// What the countdown does when it reaches zero.
enum CountdownEnd {
  /// Alerts and keeps counting the session up. The countdown is a nudge.
  chime,

  /// Pauses the session at exactly the countdown's length — a sleep timer, so
  /// a reader who nods off doesn't record the rest of the night.
  pause,
}

// Elapsed time is computed as:
//   accumulatedMs + (now.epochMs - startEpochMs)   [when running]
//   accumulatedMs                                    [when paused/idle]
//
// UTC epoch ms is used so timezone changes and DST have no effect on the count.
// State is persisted to SharedPreferences so the timer survives app kills.
class ReadingTimerService extends ChangeNotifier {
  static const _kState = 'timer_state';
  static const _kBookId = 'timer_book_id';
  static const _kStartEpochMs = 'timer_start_epoch_ms';
  static const _kSessionStartEpochMs = 'timer_session_start_epoch_ms';
  static const _kAccumulatedMs = 'timer_accumulated_ms';
  static const _kCountdownMs = 'timer_countdown_ms';
  static const _kCountdownFromMs = 'timer_countdown_from_ms';
  static const _kCountdownEnd = 'timer_countdown_end';
  static const _kPausedBySleep = 'timer_paused_by_sleep';

  TimerState _state = TimerState.idle;
  int? _bookId;
  int _accumulatedMs = 0;
  int? _startEpochMs;

  /// When the reader hit start, as opposed to [_startEpochMs], which restarts
  /// on every resume and so only marks the current running span. Set once by
  /// [start] and left alone until [stop], because it dates the saved session.
  int? _sessionStartEpochMs;
  int? _countdownMs;
  int _countdownFromMs = 0;
  CountdownEnd _countdownEnd = CountdownEnd.chime;
  bool _pausedBySleep = false;
  Timer? _ticker;

  TimerState get state => _state;
  int? get bookId => _bookId;
  bool get isActive => _state != TimerState.idle;

  /// True while the session sits paused because a sleep countdown ran out,
  /// rather than because the reader tapped Pause. Cleared on resume.
  bool get pausedBySleep => _pausedBySleep;

  /// When the current session began, for dating it once it's saved.
  ///
  /// A session is filed under the day it started, not the day it was saved —
  /// reading from 11:40pm to 12:20am is last night's reading, and dating it to
  /// the finish would drop it into the following week, breaking a streak the
  /// reader had just sat down to protect.
  ///
  /// Falls back to [_startEpochMs] for a session already in progress when this
  /// was added, which is exact unless it had been paused. Null once stopped, so
  /// callers must read this before [stop].
  DateTime? get startedAt {
    final epochMs = _sessionStartEpochMs ?? _startEpochMs;
    return epochMs == null
        ? null
        : DateTime.fromMillisecondsSinceEpoch(epochMs);
  }

  int get _rawElapsedMs {
    if (_state == TimerState.running && _startEpochMs != null) {
      final delta = DateTime.now().millisecondsSinceEpoch - _startEpochMs!;
      return _accumulatedMs + delta.clamp(0, 604800000);
    }
    return _accumulatedMs;
  }

  /// The elapsed value a sleep countdown stops the session at, in the same
  /// space as [elapsed] — so time spent paused never drains the countdown.
  int? get _sleepCapMs =>
      (_countdownMs != null && _countdownEnd == CountdownEnd.pause)
          ? _countdownFromMs + _countdownMs!
          : null;

  /// Time read so far, held at the sleep cap once a sleep countdown is up.
  ///
  /// The cap is applied here rather than left to the ticker because a phone
  /// that is face-down or asleep stops firing timers — which is exactly the
  /// situation a sleep countdown exists for. Clamping on read means a tick
  /// that lands late (or on the next cold start, hours later) still reports
  /// the session as ending precisely when the countdown ran out.
  Duration get elapsed {
    final raw = _rawElapsedMs;
    final cap = _sleepCapMs;
    return Duration(milliseconds: cap != null && raw > cap ? cap : raw);
  }

  /// Length of the optional countdown running alongside the session.
  Duration? get countdown =>
      _countdownMs == null ? null : Duration(milliseconds: _countdownMs!);

  /// What the countdown will do when it reaches zero.
  CountdownEnd get countdownEnd => _countdownEnd;

  /// Time left on the countdown; negative once it has run over, which only
  /// happens under [CountdownEnd.chime] — a sleep countdown clears itself.
  Duration? get remaining => _countdownMs == null
      ? null
      : Duration(
          milliseconds: _countdownFromMs + _countdownMs! - elapsed.inMilliseconds,
        );

  /// Starts (or replaces) the countdown, running from now rather than from the
  /// start of the session — picking 30 min always means 30 minutes from here.
  /// Pass null to clear it.
  void startCountdown(Duration? length, {CountdownEnd end = CountdownEnd.chime}) {
    // Read the mark before touching the fields [elapsed] is derived from —
    // otherwise replacing one sleep countdown with another measures the new
    // one from the old one's cap instead of from now.
    final from = elapsed.inMilliseconds;
    _pausedBySleep = false;
    _countdownMs = length?.inMilliseconds;
    _countdownFromMs = length == null ? 0 : from;
    _countdownEnd = length == null ? CountdownEnd.chime : end;
    // The ticker aims its next tick at the cap, so re-arm it to pick up one
    // that has just been set, moved, or cleared.
    if (_state == TimerState.running) _startTicker();
    _persist();
    notifyListeners();
  }

  /// Pauses the session at the sleep cap if the countdown has run out.
  /// Returns whether it did, leaving persistence to the caller.
  ///
  /// The countdown is cleared as it fires so that [elapsed] is no longer
  /// clamped — otherwise resuming would leave the clock frozen at the cap.
  bool _applySleepCap() {
    final cap = _sleepCapMs;
    if (cap == null || _state != TimerState.running) return false;
    if (_rawElapsedMs < cap) return false;

    _accumulatedMs = cap;
    _startEpochMs = null;
    _state = TimerState.paused;
    _ticker?.cancel();
    _ticker = null;
    _countdownMs = null;
    _countdownFromMs = 0;
    _countdownEnd = CountdownEnd.chime;
    _pausedBySleep = true;
    return true;
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stateStr = prefs.getString(_kState) ?? 'idle';
    _bookId = prefs.getInt(_kBookId);
    _accumulatedMs = prefs.getInt(_kAccumulatedMs) ?? 0;
    _startEpochMs = prefs.getInt(_kStartEpochMs);
    _sessionStartEpochMs = prefs.getInt(_kSessionStartEpochMs);
    _countdownMs = prefs.getInt(_kCountdownMs);
    _countdownFromMs = prefs.getInt(_kCountdownFromMs) ?? 0;
    _countdownEnd = prefs.getString(_kCountdownEnd) == CountdownEnd.pause.name
        ? CountdownEnd.pause
        : CountdownEnd.chime;
    _pausedBySleep = prefs.getBool(_kPausedBySleep) ?? false;

    switch (stateStr) {
      case 'running':
        _state = TimerState.running;
        // The session may have run past its sleep countdown while the app was
        // gone — settle that before ticking, or the first frame shows a clock
        // that has been counting all night.
        if (_applySleepCap()) {
          _persist();
        } else {
          _startTicker();
        }
      case 'paused':
        _state = TimerState.paused;
      default:
        _state = TimerState.idle;
    }
    notifyListeners();
  }

  void start(int bookId) {
    _bookId = bookId;
    _accumulatedMs = 0;
    _countdownMs = null;
    _countdownFromMs = 0;
    _countdownEnd = CountdownEnd.chime;
    _pausedBySleep = false;
    _startEpochMs = DateTime.now().millisecondsSinceEpoch;
    _sessionStartEpochMs = _startEpochMs;
    _state = TimerState.running;
    _startTicker();
    _persist();
    notifyListeners();
  }

  void pause() {
    if (_state != TimerState.running) return;
    _accumulatedMs = elapsed.inMilliseconds;
    _startEpochMs = null;
    _state = TimerState.paused;
    _ticker?.cancel();
    _ticker = null;
    _persist();
    notifyListeners();
  }

  void resume() {
    if (_state != TimerState.paused) return;
    _pausedBySleep = false;
    _startEpochMs = DateTime.now().millisecondsSinceEpoch;
    _state = TimerState.running;
    _startTicker();
    _persist();
    notifyListeners();
  }

  /// Stops the timer and returns the total elapsed duration.
  Duration stop() {
    final total = elapsed;
    _ticker?.cancel();
    _ticker = null;
    _state = TimerState.idle;
    _bookId = null;
    _accumulatedMs = 0;
    _startEpochMs = null;
    _sessionStartEpochMs = null;
    _countdownMs = null;
    _countdownFromMs = 0;
    _countdownEnd = CountdownEnd.chime;
    _pausedBySleep = false;
    _persist();
    notifyListeners();
    return total;
  }

  // Schedules ticks to fire exactly on whole-second boundaries of `elapsed`
  // (rather than a fixed periodic interval) so the displayed value never
  // needs to "catch up" by an extra second when the timer is paused.
  void _startTicker() {
    _ticker?.cancel();
    _scheduleNextTick();
  }

  void _scheduleNextTick() {
    final msIntoSecond = elapsed.inMilliseconds % 1000;
    var delay = 1000 - msIntoSecond;
    // Land exactly on a sleep countdown's last millisecond when that comes
    // first, so the session stops on the second the reader was promised.
    final cap = _sleepCapMs;
    if (cap != null) {
      final toCap = cap - _rawElapsedMs;
      if (toCap > 0 && toCap < delay) delay = toCap;
    }
    _ticker = Timer(Duration(milliseconds: delay), () {
      if (_applySleepCap()) {
        _persist();
        notifyListeners();
        return;
      }
      notifyListeners();
      if (_state == TimerState.running) _scheduleNextTick();
    });
  }

  Future<void> _persist() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kState, _state.name);
    if (_bookId != null) {
      await prefs.setInt(_kBookId, _bookId!);
    } else {
      await prefs.remove(_kBookId);
    }
    await prefs.setInt(_kAccumulatedMs, _accumulatedMs);
    if (_startEpochMs != null) {
      await prefs.setInt(_kStartEpochMs, _startEpochMs!);
    } else {
      await prefs.remove(_kStartEpochMs);
    }
    if (_sessionStartEpochMs != null) {
      await prefs.setInt(_kSessionStartEpochMs, _sessionStartEpochMs!);
    } else {
      await prefs.remove(_kSessionStartEpochMs);
    }
    if (_countdownMs != null) {
      await prefs.setInt(_kCountdownMs, _countdownMs!);
      await prefs.setInt(_kCountdownFromMs, _countdownFromMs);
      await prefs.setString(_kCountdownEnd, _countdownEnd.name);
    } else {
      await prefs.remove(_kCountdownMs);
      await prefs.remove(_kCountdownFromMs);
      await prefs.remove(_kCountdownEnd);
    }
    await prefs.setBool(_kPausedBySleep, _pausedBySleep);
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
