/// The three selectable workout types.
/// These map directly to the three exercise state machines in RepDetector
/// and to the three Firestore leaderboard/stats subcollections.
enum WorkoutType {
  squats,
  jumpingJacks,
  obliqueCrunches,
}

/// The phases of a game session.
/// FitFusionGame transitions between these during a session.
/// See ARCHITECTURE.md state machine diagram for valid transitions.
enum GamePhase {
  /// Round has started but the first rep has not yet been detected.
  /// The pace timer has NOT started. Player is getting into position.
  waitingForFirstRep,

  /// Active round. First rep has been detected. Pace timer is running.
  /// Reps deal damage. Pace failures cost lives.
  playing,

  /// Round was won. Rep detection is paused. Pace timer is paused.
  /// Countdown is running. Next round will begin after kCooldownSeconds.
  cooldown,

  /// Terminal state: all 10 rounds completed with at least 1 life remaining.
  victory,

  /// Terminal state: all 3 lives lost at any point during the session.
  defeat,
}

/// Event types emitted by PaceMonitor.
enum PaceEventType {
  /// A rep was detected within the pace threshold window. Timer was reset.
  repOnTime,

  /// No rep was detected within kPaceThresholdSeconds. Player loses a life.
  paceFailed,
}

/// The two leaderboard metrics tracked per workout type.
enum LeaderboardType {
  /// Fastest time to complete a full 10-round winning session (seconds).
  fastestSession,

  /// Fastest single rep interval recorded across all sessions (seconds).
  fastestPace,
}

/// IDs for all achievements. Values must match kAchievement* constants in constants.dart.
enum AchievementId {
  firstBlood,
  dragonslayer,
  untouchable,
  speedDemon,
  ironWill,
  theLongRoad,
}
