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
  static const _kAccumulatedMs = 'timer_accumulated_ms';

  TimerState _state = TimerState.idle;
  int? _bookId;
  int _accumulatedMs = 0;
  int? _startEpochMs;
  Timer? _ticker;

  TimerState get state => _state;
  int? get bookId => _bookId;
  bool get isActive => _state != TimerState.idle;

  Duration get elapsed {
    if (_state == TimerState.running && _startEpochMs != null) {
      final delta = DateTime.now().millisecondsSinceEpoch - _startEpochMs!;
      return Duration(milliseconds: _accumulatedMs + delta.clamp(0, 604800000));
    }
    return Duration(milliseconds: _accumulatedMs);
  }

  Future<void> restore() async {
    final prefs = await SharedPreferences.getInstance();
    final stateStr = prefs.getString(_kState) ?? 'idle';
    _bookId = prefs.getInt(_kBookId);
    _accumulatedMs = prefs.getInt(_kAccumulatedMs) ?? 0;
    _startEpochMs = prefs.getInt(_kStartEpochMs);

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
    _startEpochMs = DateTime.now().millisecondsSinceEpoch;
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
  }

  @override
  void dispose() {
    _ticker?.cancel();
    super.dispose();
  }
}
