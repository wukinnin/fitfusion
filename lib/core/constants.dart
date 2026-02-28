// Game Rules
const int kTotalRounds = 10;
const int kStartingLives = 3;
const double kPaceThresholdSeconds = 3.0;
const int kCooldownSeconds = 12;

// Rep formula — repsRequired(round) = round + 1
// round is 1-indexed (1 through 10)
int repsRequiredForRound(int round) => round + 1;

// Camera / ML Kit Performance
const int kFrameSkipCount = 2; // process every Nth frame from the camera
const double kLandmarkLikelihoodThreshold = 0.5;

// Rep Detection Thresholds
// These are normalized coordinate values (0.0 to 1.0 relative to image size)
// They will require tuning via physical device testing
const double kSquatDownThreshold = 0.15; // Hip must drop below this delta to count as DOWN
const double kSquatUpThreshold = 0.28;   // Hip must rise above this delta to count as UP (stand fully)
const double kJumpingJackWristRaiseThreshold = 0.08;
const double kJumpingJackPerLegThreshold = 0.55; // Each leg must be > 0.55x shoulder width from center
const double kJumpingJackLegsTogetherRatio = 0.9; // Ankle separation must be < 0.9x shoulder width
const double kCrunchWristHipProximityThreshold = 0.18;

// Rolling Average Buffer
const int kLandmarkBufferWindowSize = 5;

// Firebase
const String kFirebaseRegion = 'asia-southeast1';

// Leaderboard
const int kLeaderboardSize = 10;

// Achievements — IDs must match Firestore document IDs exactly
const String kAchievementFirstBlood = 'first_blood';
const String kAchievementDragonslayer = 'dragonslayer';
const String kAchievementUntouchable = 'untouchable';
const String kAchievementSpeedDemon = 'speed_demon';
const String kAchievementIronWill = 'iron_will';
const String kAchievementTheLongRoad = 'the_long_road';

// Speed Demon threshold: fastest rep pace in seconds to unlock the achievement
const double kSpeedDemonPaceThreshold = 1.5;

// Iron Will threshold: total sessions played to unlock
const int kIronWillSessionsThreshold = 10;

// The Long Road threshold: total minutes played to unlock
const int kLongRoadMinutesThreshold = 30;
