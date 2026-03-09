import 'dart:async' hide Timer;
import 'dart:math';

import 'package:fitfusion/core/constants.dart';
import 'package:fitfusion/core/enums.dart';
import 'package:fitfusion/features/game/game_session.dart';
import 'package:flame/game.dart';
import 'package:flame/timer.dart';
import 'package:flutter/material.dart';

/// The core Flame game engine for FitFusion.
/// Manages game state, rounds, lives, and session data.
/// Driven by external GameController calls (onRepDetected, onPaceFailed).
class FitFusionGame extends FlameGame {
  final void Function(GameSession session) onSessionComplete;

  FitFusionGame({required this.onSessionComplete});

  // --- State & Streams ---

  final StreamController<GamePhase> _phaseController = StreamController<GamePhase>.broadcast();
  Stream<GamePhase> get phaseStream => _phaseController.stream;

  GamePhase _phase = GamePhase.waitingForFirstRep;
  GamePhase get phase => _phase;

  // Session Config
  WorkoutType _workoutType = WorkoutType.squats;

  // Game Progress
  int _currentRound = 1;
  int _monsterHP = 2; // Initialized in _resetGame
  int _playerLives = kStartingLives;
  
  // Session Stats
  int _totalReps = 0;
  int _livesLost = 0;
  int _roundsCompleted = 0;
  DateTime? _sessionStartTime;
  final List<DateTime> _repTimestamps = [];

  // Timers
  Timer? _cooldownTimer;

  // --- Lifecycle & Config ---

  @override
  Color backgroundColor() => Colors.transparent;

  @override
  Future<void> onLoad() async {
    await super.onLoad();
    // Initialize components here in later steps
  }

  /// Called by GameScreen/GameController before the game session starts.
  void configure({required WorkoutType workoutType}) {
    _workoutType = workoutType;
    _resetGame();
  }

  void _resetGame() {
    _phase = GamePhase.waitingForFirstRep;
    _phaseController.add(_phase);
    
    _currentRound = 1;
    _monsterHP = repsRequiredForRound(1);
    _playerLives = kStartingLives;
    
    _totalReps = 0;
    _livesLost = 0;
    _roundsCompleted = 0;
    _sessionStartTime = null;
    _repTimestamps.clear();
    
    _cooldownTimer?.stop();
  }

  @override
  void update(double dt) {
    super.update(dt);
    _cooldownTimer?.update(dt);
  }

  @override
  void onRemove() {
    _phaseController.close();
    super.onRemove();
  }

  // --- External API (Called by GameController) ---

  void onRepDetected() {
    if (_phase == GamePhase.waitingForFirstRep) {
      _startPlaying();
    }
    
    if (_phase == GamePhase.playing) {
      _handleRep();
    }
  }

  void onPaceFailed() {
    // Pace failures only matter during active play
    if (_phase == GamePhase.playing) {
      _handlePaceFailure();
    }
  }

  // --- Internal Game Logic ---

  void _startPlaying() {
    _phase = GamePhase.playing;
    _phaseController.add(_phase);
    _sessionStartTime ??= DateTime.now();
  }

  void _handleRep() {
    _monsterHP--;
    _totalReps++;
    _repTimestamps.add(DateTime.now());
    
    // TODO: Trigger visuals (SwordSlash, DamageNumber, HealthBar update)
    
    if (_monsterHP <= 0) {
      _handleRoundWon();
    }
  }

  void _handlePaceFailure() {
    _playerLives--;
    _livesLost++;
    
    // TODO: Trigger damage flash
    
    if (_playerLives <= 0) {
      _handleDefeat();
    }
  }

  void _handleRoundWon() {
    _roundsCompleted++;
    
    if (_currentRound == kTotalRounds) {
      // Victory immediately after Round 10
      _handleVictory();
    } else {
      // Cooldown for Rounds 1-9
      _phase = GamePhase.cooldown;
      _phaseController.add(_phase);
      
      _cooldownTimer = Timer(
        kCooldownSeconds.toDouble(),
        onTick: _advanceToNextRound,
        repeat: false,
      );
      _cooldownTimer!.start();
    }
  }

  void _advanceToNextRound() {
    _currentRound++;
    _monsterHP = repsRequiredForRound(_currentRound);
    _phase = GamePhase.waitingForFirstRep;
    _phaseController.add(_phase);
  }

  void _handleVictory() {
    _phase = GamePhase.victory;
    _phaseController.add(_phase);
    _finishSession(won: true);
  }

  void _handleDefeat() {
    _phase = GamePhase.defeat;
    _phaseController.add(_phase);
    _finishSession(won: false);
  }

  void _finishSession({required bool won}) {
    final endTime = DateTime.now();
    
    // If session never started (e.g. quit immediately), use current time as start
    final startTime = _sessionStartTime ?? endTime;
    final durationSeconds = endTime.difference(startTime).inMilliseconds / 1000.0;
        
    // Calculate pace stats
    double bestPace = 0.0;
    double avgPace = 0.0;
    
    if (_repTimestamps.length >= 2) {
       List<double> intervals = [];
       for (int i = 1; i < _repTimestamps.length; i++) {
         intervals.add(
           _repTimestamps[i].difference(_repTimestamps[i-1]).inMilliseconds / 1000.0
         );
       }
       if (intervals.isNotEmpty) {
         bestPace = intervals.reduce(min);
         avgPace = intervals.reduce((a, b) => a + b) / intervals.length;
       }
    }

    final session = GameSession(
      workoutType: _workoutType,
      won: won,
      totalReps: _totalReps,
      totalTimeSeconds: durationSeconds,
      roundsCompleted: _roundsCompleted,
      lastRound: _currentRound,
      bestRepPaceSeconds: bestPace,
      avgRepPaceSeconds: avgPace,
      livesLost: _livesLost,
      completedAt: endTime,
    );
    
    onSessionComplete(session);
  }
}
