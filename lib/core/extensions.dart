import 'enums.dart';

extension WorkoutTypeExtension on WorkoutType {
  /// Human-readable display name for UI labels.
  String get displayName {
    switch (this) {
      case WorkoutType.squats:
        return 'Squats';
      case WorkoutType.jumpingJacks:
        return 'Jumping Jacks';
      case WorkoutType.obliqueCrunches:
        return 'Side Oblique Crunches';
    }
  }

  /// Firestore-safe key for use as collection/document IDs.
  /// Must be stable — changing these will break existing Firestore data.
  String get firestoreKey {
    switch (this) {
      case WorkoutType.squats:
        return 'squats';
      case WorkoutType.jumpingJacks:
        return 'jumping_jacks';
      case WorkoutType.obliqueCrunches:
        return 'oblique_crunches';
    }
  }

  /// Short label for compact UI (e.g., tab headers).
  String get shortName {
    switch (this) {
      case WorkoutType.squats:
        return 'Squats';
      case WorkoutType.jumpingJacks:
        return 'Jacks';
      case WorkoutType.obliqueCrunches:
        return 'Crunches';
    }
  }
}

extension AchievementIdExtension on AchievementId {
  String get firestoreKey {
    switch (this) {
      case AchievementId.firstBlood:
        return 'first_blood';
      case AchievementId.dragonslayer:
        return 'dragonslayer';
      case AchievementId.untouchable:
        return 'untouchable';
      case AchievementId.speedDemon:
        return 'speed_demon';
      case AchievementId.ironWill:
        return 'iron_will';
      case AchievementId.theLongRoad:
        return 'the_long_road';
    }
  }

  String get displayName {
    switch (this) {
      case AchievementId.firstBlood:
        return 'First Blood';
      case AchievementId.dragonslayer:
        return 'Dragonslayer';
      case AchievementId.untouchable:
        return 'Untouchable';
      case AchievementId.speedDemon:
        return 'Speed Demon';
      case AchievementId.ironWill:
        return 'Iron Will';
      case AchievementId.theLongRoad:
        return 'The Long Road';
    }
  }

  String get description {
    switch (this) {
      case AchievementId.firstBlood:
        return 'Complete your first game session.';
      case AchievementId.dragonslayer:
        return 'Win a full 10-round session.';
      case AchievementId.untouchable:
        return 'Win a session without losing a single life.';
      case AchievementId.speedDemon:
        return 'Achieve a rep pace under 1.5 seconds.';
      case AchievementId.ironWill:
        return 'Play 10 total sessions.';
      case AchievementId.theLongRoad:
        return 'Accumulate 30 minutes of in-game time.';
    }
  }
}
