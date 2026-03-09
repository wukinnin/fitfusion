import 'package:fitfusion/core/enums.dart';

/// Immutable data class capturing the complete result of one game session.
/// Matches the Firebase data model in CONTEXT.md §12 exactly.
class GameSession {
  final WorkoutType workoutType;
  final bool won;
  final int totalReps;
  final double totalTimeSeconds;
  final int roundsCompleted;
  final int lastRound;
  final double bestRepPaceSeconds;
  final double avgRepPaceSeconds;
  final int livesLost;
  final DateTime completedAt;

  const GameSession({
    required this.workoutType,
    required this.won,
    required this.totalReps,
    required this.totalTimeSeconds,
    required this.roundsCompleted,
    required this.lastRound,
    required this.bestRepPaceSeconds,
    required this.avgRepPaceSeconds,
    required this.livesLost,
    required this.completedAt,
  });

  @override
  String toString() {
    return 'GameSession('
        'workoutType: $workoutType, '
        'won: $won, '
        'totalReps: $totalReps, '
        'totalTimeSeconds: ${totalTimeSeconds.toStringAsFixed(1)}, '
        'roundsCompleted: $roundsCompleted, '
        'lastRound: $lastRound, '
        'bestRepPaceSeconds: ${bestRepPaceSeconds.toStringAsFixed(2)}, '
        'avgRepPaceSeconds: ${avgRepPaceSeconds.toStringAsFixed(2)}, '
        'livesLost: $livesLost, '
        'completedAt: $completedAt)';
  }
}
