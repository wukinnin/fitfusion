import 'dart:async';
import 'package:flutter/foundation.dart';
import '../../core/constants.dart';
import '../../core/events.dart';
import '../../core/enums.dart';

class PaceMonitor {
  Timer? _paceTimer;
  DateTime? _lastRepTime;
  bool _isActive = false;

  final StreamController<PaceEvent> _paceController =
      StreamController<PaceEvent>.broadcast();

  Stream<PaceEvent> get paceStream => _paceController.stream;

  /// Call this when the FIRST REP of a round is detected.
  /// This starts the pace timer. Do not call this before the first rep
  /// of a round — the player needs time to get into position.
  void startMonitoring() {
    if (_isActive) return; // already monitoring
    _isActive = true;
    _lastRepTime = DateTime.now();
    _resetTimer();
    debugPrint('[PaceMonitor] Started monitoring');
  }

  /// Call this when a round ends (won or lost), during cooldown,
  /// or when the game ends. Stops the timer cleanly without emitting.
  void stopMonitoring() {
    _isActive = false;
    _paceTimer?.cancel();
    _paceTimer = null;
    debugPrint('[PaceMonitor] Stopped monitoring');
  }

  /// Call this each time a rep is detected (after startMonitoring has been called).
  /// Resets the 3-second window and emits a repOnTime event.
  void onRepReceived() {
    if (!_isActive) return;

    final now = DateTime.now();
    final intervalSeconds = _lastRepTime != null
        ? now.difference(_lastRepTime!).inMilliseconds / 1000.0
        : 0.0;

    _lastRepTime = now;
    _resetTimer();

    _paceController.add(PaceEvent(
      type: PaceEventType.repOnTime,
      intervalSeconds: intervalSeconds,
      timestamp: now,
    ));
  }

  void _resetTimer() {
    _paceTimer?.cancel();
    _paceTimer = Timer(
      Duration(milliseconds: (kPaceThresholdSeconds * 1000).round()),
      _onPaceViolation,
    );
  }

  void _onPaceViolation() {
    if (!_isActive) return;

    debugPrint('[PaceMonitor] PACE VIOLATION — no rep in ${kPaceThresholdSeconds}s');

    _paceController.add(PaceEvent(
      type: PaceEventType.paceFailed,
      intervalSeconds: kPaceThresholdSeconds,
      timestamp: DateTime.now(),
    ));

    // Restart the timer — the player must keep moving.
    // The pace monitor keeps firing every 3 seconds until they do a rep
    // or until stopMonitoring() is called.
    _resetTimer();
  }

  Future<void> dispose() async {
    stopMonitoring();
    await _paceController.close();
  }
}
