import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

enum TimerState { idle, running, paused }

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
  Timer? _ticker;

  TimerState get state => _state;
  int? get bookId => _bookId;
  bool get isActive => _state != TimerState.idle;

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

  Duration get elapsed {
    if (_state == TimerState.running && _startEpochMs != null) {
      final delta = DateTime.now().millisecondsSinceEpoch - _startEpochMs!;
      return Duration(milliseconds: _accumulatedMs + delta.clamp(0, 604800000));
    }
    return Duration(milliseconds: _accumulatedMs);
  }

  /// Length of the optional countdown running alongside the session. Purely a
  /// display concern — the session still records the time actually read.
  Duration? get countdown =>
      _countdownMs == null ? null : Duration(milliseconds: _countdownMs!);

  /// Time left on the countdown; negative once it has run over.
  Duration? get remaining => _countdownMs == null
      ? null
      : Duration(
          milliseconds: _countdownFromMs + _countdownMs! - elapsed.inMilliseconds,
        );

  /// Starts (or replaces) the countdown, running from now rather than from the
  /// start of the session — picking 30 min always means 30 minutes from here.
  /// Pass null to clear it.
  void startCountdown(Duration? length) {
    _countdownMs = length?.inMilliseconds;
    _countdownFromMs = length == null ? 0 : elapsed.inMilliseconds;
    _persist();
    notifyListeners();
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

    switch (stateStr) {
      case 'running':
        _state = TimerState.running;
        _startTicker();
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
    _ticker = Timer(Duration(milliseconds: 1000 - msIntoSecond), () {
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
    } else {
      await prefs.remove(_kCountdownMs);
      await prefs.remove(_kCountdownFromMs);
    }
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
