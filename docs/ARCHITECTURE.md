# FitFusion — System Architecture

> This document describes how FitFusion's systems are structured, how data flows between them,
> and the reasoning behind every major technical decision.
> Read this alongside CONTEXT.md before writing any code.
> CONTEXT.md is the master document — when in conflict, CONTEXT.md wins.

---

## 1. The Big Picture

FitFusion is composed of four independent layers that communicate through clean, typed interfaces. Each layer has a single responsibility. No layer imports another layer's internals — only its public interface.

```
┌──────────────────────────────────────────────────────────────────────┐
│                          MOTION PIPELINE                             │
│   Phone Camera → CameraService → PoseDetectorService → RepDetector  │
│                                                ↓                    │
│                                          PaceMonitor                │
└──────────────────────────────────────────────────────────────────────┘
                                    │ Stream<RepEvent>
                                    │ Stream<PaceEvent>
                                    ↓
┌──────────────────────────────────────────────────────────────────────┐
│                          GAME CONTROLLER                             │
│              (bridge layer — decouples motion from game)            │
└──────────────────────────────────────────────────────────────────────┘
                                    │ method calls
                                    ↓
┌──────────────────────────────────────────────────────────────────────┐
│                           FLAME GAME                                 │
│              FitFusionGame (FlameGame subclass)                      │
│   Components: Monster, HealthBar, SwordSlash, HUD, Cooldown, etc.   │
└──────────────────────────────────────────────────────────────────────┘
                                    │ GameSession (on end)
                                    ↓
┌──────────────────────────────────────────────────────────────────────┐
│                         FIREBASE BACKEND                             │
│          Firestore: sessions, stats, leaderboard, achievements       │
│          Firebase Auth: Google Sign-In identity                      │
└──────────────────────────────────────────────────────────────────────┘
```

**The Iron Rule of Layering:**
- The Flame game does NOT import Firebase
- The rep detector does NOT import Flame
- Each arrow above is a clean interface — stream or method call, nothing else
- This separation is what makes the system debuggable under time pressure

---

## 2. Layer 1 — The Motion Pipeline

The motion pipeline transforms raw camera pixels into discrete, meaningful game events. It is composed of four sequential services.

---

### 2.1 CameraService

**File:** `lib/features/motion/camera_service.dart`

**Responsibility:** Own and manage the `CameraController`. Initialize it at a specified resolution, start the image stream, and emit raw camera frames.

**Key decisions:**
- Resolution preset: `ResolutionPreset.low` (typically 352×288 or 640×480) — intentional for ML Kit performance on budget hardware
- Front camera is selected — player faces the phone
- `CameraController` must be disposed when the game screen is disposed — memory leak here will crash the app

**Frame skipping:**
- Not every frame is forwarded to ML Kit — only every `kFrameSkipCount`-th frame is emitted
- A frame counter increments on every incoming camera frame; frames that don't satisfy `frameCount % kFrameSkipCount == 0` are dropped
- This is the single most important performance optimization in the codebase

**Output:** `Stream<CameraImage>` — throttled raw frames

---

### 2.2 PoseDetectorService

**File:** `lib/features/motion/pose_detector_service.dart`

**Responsibility:** Wrap ML Kit's `PoseDetector`. Accept `CameraImage` frames, convert them to `InputImage` format, run inference, and emit `Pose?` results.

**Key decisions:**
- Uses `PoseDetectionMode.stream` — optimized for consecutive frames, reuses internal state between calls
- Uses the base model, NOT the accurate model — accurate model is too slow for the Tecno Spark Go 30c
- `CameraImage` from Flutter's camera package uses YUV420 byte format on Android — this must be converted properly with correct rotation metadata for ML Kit to accept it

**CameraImage → InputImage conversion (conceptual):**
- Concatenate all plane bytes from the `CameraImage`
- Build an `InputImage` with the correct size, rotation (from sensor orientation), format (YUV420), and bytes-per-row metadata
- This conversion is the most common failure point in the entire pipeline — verify byte format on the physical device early

**Landmark reliability filter:**
- Before emitting a `Pose`, check critical landmarks (the ones needed for the selected workout) for `likelihood >= kLandmarkLikelihoodThreshold (0.5)`
- If critical landmarks are unreliable, emit `null` instead of the pose
- A null emission means "no reliable pose this frame" — the rep detector handles this gracefully

**Output:** `Stream<Pose?>` — null means no reliable pose detected

---

### 2.3 RepDetector

**File:** `lib/features/motion/rep_detector.dart`

**Responsibility:** Consume `Stream<Pose?>` from PoseDetectorService and count completed reps using a state machine appropriate for the selected workout type. Emit a `RepEvent` each time a rep is completed.

**This is the most algorithmically complex piece of the codebase.**

**Pattern: Two-state finite state machine per exercise**

Each exercise uses a "down" and "up" (or equivalent) state. A rep is counted when the machine transitions from the "engaged" position back to "neutral" — the return to neutral signals completion, not the initial movement into the exercise.

**Rolling Average Filter (noise suppression):**
- Each measured landmark value is fed through a rolling average buffer of `kLandmarkBufferWindowSize = 5` frames before being compared to a threshold
- This prevents single-frame jitter from causing phantom reps or missed reps
- At ~15–20 FPS processing speed, a 5-frame window = ~0.25–0.33 seconds of smoothing
- Rep state machine decisions are only made when the buffer is full (5 frames recorded)

---

#### Exercise 1: Squats

**Landmarks used:** `leftHip`, `leftKnee`, `leftAnkle` (mirrored with right side for robustness)

**Detection logic:**
- Measure the vertical distance between hip and knee: `hipKneeDelta = knee.y - hip.y`
- Standing: hip is well above knee, `hipKneeDelta` is large
- Squat (down): hip drops toward knee, `hipKneeDelta` decreases
- Feed `hipKneeDelta` through rolling average buffer before threshold comparison
- Threshold: when averaged `hipKneeDelta` drops below `kSquatHipDropThreshold` → enter `squatDown` state
- When averaged `hipKneeDelta` rises back above threshold → return to `standing` state → **emit RepEvent**

```
State: standing
  averaged hipKneeDelta < kSquatHipDropThreshold → transition to squatDown

State: squatDown
  averaged hipKneeDelta > kSquatHipDropThreshold → transition to standing → EMIT REP
```

---

#### Exercise 2: Jumping Jacks

**Landmarks used:** `leftWrist`, `rightWrist`, `leftShoulder`, `rightShoulder`

**Detection logic:**
- Jumping jacks have two phases: arms down (rest) and arms raised (extended)
- In normalized image space: y=0 is top of image, y=1 is bottom — "above" = smaller y value
- Measure: `wristAboveShoulder = shoulder.y - wrist.y` (positive = wrist higher than shoulder)
- When BOTH wrists simultaneously satisfy `wristAboveShoulder > kJumpingJackWristRaiseThreshold (0.08)` → enter `armsUp` state
- When both wrists drop back below threshold → return to `armsDown` state → **emit RepEvent**

```
State: armsDown
  leftWrist.y < leftShoulder.y AND rightWrist.y < rightShoulder.y → transition to armsUp

State: armsUp
  wrists drop below shoulder level → transition to armsDown → EMIT REP
```

---

#### Exercise 3: Side Oblique Crunches

**Landmarks used:** `leftWrist` + `leftHip` (left side), `rightWrist` + `rightHip` (right side)

**Detection logic:**
- A side oblique crunch involves bending sideways, bringing one hand toward the same-side hip
- Measure: Euclidean distance between wrist and hip on the same side: `d = sqrt((wrist.x - hip.x)² + (wrist.y - hip.y)²)`
- When `d < kCrunchWristHipProximityThreshold` → wrist is near hip → crunch "down" position
- When `d` rises back above threshold → player returned to neutral → **emit RepEvent** (one rep per side)
- Both left and right sides are counted independently — each side crunch = one rep
- Require player to return to a fully extended state (large `d`) between reps to prevent double-counting rapid oscillations
- `kCrunchWristHipProximityThreshold` value to be tuned via physical device testing

```
State: extended
  leftWrist near leftHip (d < threshold) → transition to leftCrunchDown

State: leftCrunchDown
  leftWrist returns to extended → transition to extended → EMIT REP

State: extended
  rightWrist near rightHip → transition to rightCrunchDown

State: rightCrunchDown
  rightWrist returns to extended → transition to extended → EMIT REP
```

---

**RepEvent data class (conceptual):**
```
RepEvent {
  workoutType: WorkoutType
  timestamp: DateTime
}
```

**Output:** `Stream<RepEvent>` — one event per completed rep

---

### 2.4 PaceMonitor

**File:** `lib/features/motion/pace_monitor.dart`

**Responsibility:** Watch `Stream<RepEvent>` and enforce the pace rule. Emit a `PaceEvent` when a pace violation occurs (`kPaceThresholdSeconds = 5.0` elapsed without a rep during an active round).

**PaceMonitor does NOT know about rounds or game state.** It is a pure timer watcher. The GameController tells it when to start and stop monitoring.

**Behavior:**
- Maintains an internal timer that resets on each received `RepEvent`
- If the timer fires (5 seconds elapsed with no rep) → emit `PaceFailureEvent`
- Has `start()`, `stop()`, and `reset()` methods called by GameController
- `start()` — begin watching (called after the first rep of a round is detected)
- `stop()` — cancel monitoring (called on round win, cooldown start, game over)
- `reset()` — restart the 5-second window (called after each rep)
- Timer is always paused during cooldown periods (GameController calls `stop()` then `start()` appropriately)

**PaceEvent data class (conceptual):**
```
PaceEvent {
  type: PaceEventType (repOnTime | paceFailed)
  intervalSeconds: double
  timestamp: DateTime
}
```

**Output:** `Stream<PaceEvent>`

---

## 3. Layer 2 — The Game Controller

**File:** `lib/features/game/game_controller.dart`

**Responsibility:** The bridge between the motion pipeline and the Flame game. Subscribes to `RepEvent` and `PaceEvent` streams, translates them into game actions, and calls methods on `FitFusionGame`.

**This is intentionally a thin orchestration layer.** It contains no game logic itself — that belongs in `FitFusionGame`. It contains no motion detection logic — that belongs in the motion pipeline. It wires them together.

**What GameController does:**
- Subscribes to `RepDetector.repStream` → calls `game.onRepDetected()`
- Subscribes to `PaceMonitor.paceStream` → calls `game.onPaceFailed()` on `paceFailed` events
- Tells `PaceMonitor` to `start()` after the first rep of each round is detected
- Tells `PaceMonitor` to `stop()` when a round ends or the game ends
- Receives `GamePhase` changes from `FitFusionGame` and reacts (pauses pace monitoring during cooldown)

**Lifecycle:**
- Created when `GameScreen` mounts
- Disposed when `GameScreen` unmounts
- Holds `StreamSubscription` references and cancels them all in `dispose()`

---

## 4. Layer 3 — The Flame Game

**File:** `lib/features/game/fitfusion_game.dart`

**Responsibility:** Own and run the entire game session. Manage game state, round progression, monster health, player lives, cooldown timers, win/lose conditions, and all visual components.

---

### 4.1 Game State Machine

The game exists in exactly one phase at all times:

```
GamePhase {
  waitingForFirstRep  // round started, pace timer NOT yet running, player getting into position
  playing             // active round, first rep detected, pace timer running
  cooldown            // between rounds, rep detection paused, countdown running
  victory             // terminal — all 10 rounds completed
  defeat              // terminal — all 3 lives lost
}
```

**State transitions:**
```
waitingForFirstRep
  → first rep detected → playing (pace timer starts)

playing
  → rep detected, monster HP > 0 → playing (update health bar, sword slash, damage number)
  → rep detected, monster HP == 0 → cooldown (round won, start cooldown)
  → pace failed → playing (lose life; if lives == 0 → defeat)

cooldown
  → timer expires, round < 10 → waitingForFirstRep (next round loaded)
  → timer expires, round == 10 → victory

victory / defeat
  → terminal states — no further transitions
```

---

### 4.2 FitFusionGame Public API

These are the methods `GameController` calls on the game:

```
onRepDetected()           // Called when rep detector fires a RepEvent
onPaceFailed()            // Called when pace monitor fires a paceFailed PaceEvent
configure(workoutType)    // Called by GameScreen to pass workout type before game starts
```

---

### 4.3 Component Hierarchy

All game visuals are `FlameComponent` subclasses added to `FitFusionGame`:

```
FitFusionGame
├── MonsterHealthBar              ← Full-width red bar, top of screen, shrinks with HP
├── MonsterComponent              ← Sprite upper-left, randomly selected per round
├── RepProgressBar                ← "X / Y REPS" center pill, updates on each rep
├── PaceTimerIndicator            ← Circular pie countdown upper-right, green → red
├── RoundBanner                   ← "ROUND X" gold pill, lower-center
├── PlayerLivesDisplay            ← 3 cyan pixel hearts, below round banner
├── ExerciseLabel                 ← Exercise name pill, bottom of screen
├── SwordSlashComponent (spawned) ← Slash animation on each rep, auto-removed on complete
├── DamageNumber (spawned)        ← Floating damage number on each rep, fades upward, auto-removed
└── CooldownOverlay (conditional) ← Full-screen dim + round announcement + large countdown timer
```

---

### 4.4 Component Behavioral Specifications

**MonsterHealthBar:**
- Spans full screen width, pinned to top edge
- Red fill on dark background with decorative border
- Width proportional to `currentHP / maxHP` of current monster
- Resets to full on each new round

**MonsterComponent:**
- Positioned in upper-left corner
- On each new round: select a new monster sprite from the pre-drawn session pool of 10
- Pool of 10 is drawn randomly from 20 available sprites at session start, non-repeating within pool
- Monster sprite changes every round (all 10 are unique per session)
- Plays idle animation when alive; hit reaction on each rep; death animation when HP reaches 0

**SwordSlashComponent:**
- Spawned on every successful rep
- Randomly selects one of 3 sword slash sprite sheets per spawn (repeatable)
- Plays the full animation once, then removes itself from the game tree
- Positioned relative to the monster

**PaceTimerIndicator:**
- Circular pie chart in upper-right corner
- Counts down from `kPaceThresholdSeconds = 5.0` to 0
- Fill color: lime green when above ~50% time remaining, transitions toward red as time decreases, solid red + flashes at 0
- Resets and restarts on each rep
- Hidden during `waitingForFirstRep` state (timer hasn't started)
- Hidden during cooldown state

**CooldownOverlay:**
- Shown during `cooldown` GamePhase
- Semi-transparent dark overlay over the full screen (camera still visible beneath)
- Shows "ROUND X" text prominently
- Shows the large circular countdown timer centered on screen (counts from `kCooldownSeconds = 15` to 0)
- Dismisses automatically when timer reaches 0

**PlayerLivesDisplay:**
- 3 pixel heart sprites arranged horizontally
- Cyan / full = life available
- Dark / empty = life lost
- Hearts go dark from right to left as lives are lost

**DamageNumber:**
- Spawned at monster position on each rep hit
- Floats upward with fade-out animation
- Removed from game tree on animation complete

---

### 4.5 Session Tracking

`FitFusionGame` accumulates session data throughout the run:
- `totalReps` — incremented on each rep
- `livesLost` — incremented on each pace failure
- `roundsCompleted` — incremented on each round win
- `lastRound` — the round number when the session ended
- `sessionStartTime` — recorded when first round begins
- `repTimestamps` — list of DateTime for each rep, used to compute avg and fastest pace intervals

On session end (victory or defeat), a `GameSession` object is built from this data and passed to `ResultsScreen` via the navigator.

---

### 4.6 Damage Flash (Life Lost)

On every pace failure (life lost):
- A full-screen red color filter/overlay is applied briefly over everything — camera feed, all HUD, all sprites
- This is a Doom-style visual hit indicator
- Brief duration, then clears automatically
- Implemented as a top-level overlay widget or a full-screen Flame component with a red tinted color

---

### 4.7 The AR Overlay Architecture

The "AR" effect is achieved by compositing the Flame `GameWidget` over a live camera preview widget inside `GameScreen`.

**Stack structure (bottom to top):**
1. **Layer 1 (bottom):** `CameraPreviewWidget` — fills the entire screen with the live camera feed
2. **Layer 2 (debug only):** `PoseOverlayPainter` — `CustomPainter` drawing cyan dots and green lines for the 33 ML Kit landmarks (only rendered in debug builds, hidden in release)
3. **Layer 3 (top):** `GameWidget` — Flame game with transparent background

**Critical:** `FitFusionGame` must have a transparent background. Without explicit transparency, the Flame game renders over a solid color and hides the camera feed entirely.

---

### 4.8 GameSession Data Class

Immutable. Built at session end. Passed to ResultsScreen and then to Firebase.

```
GameSession {
  workoutType: WorkoutType
  won: boolean
  totalReps: int
  totalTimeSeconds: double
  roundsCompleted: int            // 0–10
  lastRound: int                  // round number at session end
  bestRepPaceSeconds: double      // fastest single rep interval this session
  avgRepPaceSeconds: double
  livesLost: int                  // 0–3
  completedAt: DateTime
}
```

---

## 5. Layer 4 — The Firebase Backend

### 5.1 FirestoreService

**File:** `lib/features/firebase/firestore_service.dart`

All Firestore operations live in this single file. No other file touches Firestore directly.

**Public methods (conceptual):**
```
createUserDocument(user)
writeSession(uid, gameSession)
updateStats(uid, gameSession)
updateLeaderboard(uid, displayName, photoUrl, gameSession)
unlockAchievements(uid, List<AchievementId>)
getLeaderboard(workoutType, leaderboardType) → List<LeaderboardEntry>
getPlayerStats(uid) → Map<WorkoutType, PlayerStats>
```

All methods wrapped in `try/catch`. Failures are logged but never re-thrown — the app continues regardless.

---

### 5.2 Session Write Flow

Triggered from `ResultsScreen` after the game session ends:

```
ResultsScreen receives GameSession
  → if user is signed in:
      1. FirestoreService.writeSession(uid, session)
      2. FirestoreService.updateStats(uid, session)
      3. FirestoreService.updateLeaderboard(uid, ...) — only if session.won == true
      4. Evaluate achievement conditions → FirestoreService.unlockAchievements(uid, newAchievements)
  → if guest:
      → skip all Firebase calls, show results locally only
```

**Firebase never blocks the game.** All writes happen after session end. The game has zero Firebase dependency during active play.

---

### 5.3 AuthService

**File:** `lib/features/auth/auth_service.dart`

```
signInWithGoogle() → UserCredential?
signOut()
authStateChanges → Stream<User?>
currentUser → User?
isSignedIn → bool
```

On successful sign-in:
1. Check if `/users/{uid}` document exists
2. If not, call `FirestoreService.createUserDocument(user)`

---

### 5.4 Achievement Evaluation Logic

Achievements are checked at session end, after `GameSession` is built. Each achievement checks a specific condition:

| Achievement | Condition Check |
|-------------|-----------------|
| `first_blood` | Any session completed (always true at session end) — check if not already unlocked |
| `dragonslayer` | `session.won == true` |
| `untouchable` | `session.won == true AND session.livesLost == 0` |
| `speed_demon` | `session.bestRepPaceSeconds < kSpeedDemonPaceThreshold (1.5)` |
| `iron_will` | `userStats.sessionsPlayed >= kIronWillSessionsThreshold (10)` after this session |
| `the_long_road` | `userStats.totalMinutesPlayed >= kLongRoadMinutesThreshold (30)` after this session |

Only achievements not yet unlocked are written. Existing unlocked achievements are never overwritten.

---

## 6. Screen Navigation and Routing

```
App Launch
  └─→ SplashScreen
        └─→ HomeScreen

HomeScreen
  ├─→ [Play] → WorkoutSelectScreen
  │     └─→ [Select Workout] → GameScreen (workout type passed as argument)
  │           └─→ (session ends, victory or defeat) → ResultsScreen
  │                 ├─→ [RETRY] → GameScreen (same workout type — bypasses WorkoutSelectScreen)
  │                 └─→ [QUIT] → HomeScreen
  ├─→ [Leaderboard] → LeaderboardScreen
  ├─→ [Stats] → StatsScreen (or sign-in prompt overlay if guest)
  └─→ [Sign In / Sign Out] → Auth flow (modal/bottom sheet, no dedicated screen)
```

All navigation uses Flutter's `Navigator`. Named routes defined in `app.dart`. No deep linking required.

---

## 7. State Management Strategy

FitFusion uses a minimal, pragmatic approach. No Redux, no BLoC, no complex reactive graph.

**At the widget layer:** `Provider` (pulled in transitively by Firebase packages).
- `AuthProvider` — exposes auth state (current user, isSignedIn) to all screens

**Inside the game screen:** State is managed directly by `GameController` and `FitFusionGame`. These are not exposed as providers — they live within `GameScreen`'s `State` object and are created/disposed with the screen.

**Rule:** State needed by multiple screens → `Provider`. State only needed by the game screen → local to `GameScreen`.

---

## 8. Data Flow — A Single Rep, End to End

```
Phone camera captures frame
  ↓
CameraService: receives CameraImage
  ↓ (skip if frame % kFrameSkipCount != 0)
PoseDetectorService: convert to InputImage, run ML Kit inference
  ↓ (returns Pose with 33 PoseLandmarks)
PoseDetectorService: filter — check likelihood >= 0.5 for critical landmarks
  ↓ (emit Pose, or emit null if unreliable)
RepDetector: extract relevant landmark pair, feed to rolling average buffer
  ↓ (compare buffered average to threshold)
  ↓ (state machine: if transitioning from "engaged" → "neutral" position)
Stream<RepEvent> emits RepEvent
  ↓
GameController: receives RepEvent
  ↓ calls PaceMonitor.reset() or start()
  ↓ calls fitFusionGame.onRepDetected()
FitFusionGame.onRepDetected()
  ↓ monsterHP -= 1
  ↓ spawn SwordSlashComponent
  ↓ spawn DamageNumber component
  ↓ update RepProgressBar
  ↓ update MonsterHealthBar
  ↓ if monsterHP == 0 → transition to cooldown GamePhase
Player sees monster take damage on screen
```

---

## 9. Performance Architecture

### Frame Budget on the Tecno Spark Go 30c

- Camera delivers ~30 FPS at 640×480
- With `kFrameSkipCount = 2`, ML Kit receives ~15 FPS
- ML Kit pose detection on budget device: ~50–80ms per frame inference time
- At 15 FPS input, inference must complete before next frame arrives (~66ms window)
- This is tight but workable with the base model at low resolution

**If processing backs up:** prefer dropping frames over processing late. Stale pose data is worse than no data — it causes the state machine to receive stale inputs and potentially misfire.

### Thread Responsibilities

| Work | Thread |
|------|--------|
| Camera frame capture | Camera background thread |
| ML Kit inference | `compute()` isolate or background thread |
| Rep state machine | Main thread (lightweight) |
| Flame game loop | Main thread (Flutter's raster thread) |
| Firestore writes | Firebase SDK background thread |

ML Kit inference is the only heavyweight operation and must never run on the main thread.

### Memory Management (Dispose Checklist)

Every one of these must be called on their respective screen/widget dispose:
- `CameraController.dispose()` — in `GameScreen.dispose()`
- `PoseDetector.close()` — in `PoseDetectorService.dispose()`
- All `StreamController.close()` — in each service's `dispose()`
- All `StreamSubscription.cancel()` — in `GameController.dispose()`
- `FitFusionGame` detach/removal — on game screen exit

---

## 10. Key Technical Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|------------|------------|
| CameraImage → InputImage conversion fails silently | High | Log byte format, assert format matches. Test on device first. |
| Rep detection threshold wrong for real movement | High | Tune via live testing on physical device. All thresholds are named constants. |
| ML Kit too slow on Tecno — game unplayable | Medium | Frame skipping + base model + low resolution. Test in Milestone 1. |
| Front camera mirroring causes left/right inversion | Medium | Horizontal flip compensation in overlay painter and rep detector landmarks. |
| Flame transparent background not working | Low | Explicitly set `backgroundColor: Colors.transparent` in FlameGame constructor. |
| Firebase write fails mid-session | Low | Wrapped in try/catch. Session data in memory. Never block game on Firebase. |
| Google Sign-In SHA-1 mismatch in release build | Medium | Release build uses different keystore. Regenerate SHA-1 before submission. |

---

## 11. Dependency List

Versions below reflect the resolved `flutter analyze` output at time of writing. Use these as the baseline — do not downgrade without reason.

```yaml
# Game engine
flame: 1.35.1

# Motion detection
google_mlkit_pose_detection: ^0.11.0

# Camera access
camera: 0.11.4

# Firebase
firebase_core: 4.4.0
firebase_auth: 6.1.4
cloud_firestore: 6.1.2

# Auth
google_sign_in: ^6.2.1

# State management
provider: ^6.1.2

# Runtime permissions
permission_handler: 11.4.0

# Typography
google_fonts: 6.3.3
```

---

## 12. Android Manifest Requirements

Required in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Permissions (outside <application> tag) -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>

<!-- On the <application> tag -->
<application
    android:hardwareAccelerated="true"
    ... >
```

- `hardwareAccelerated="true"` is mandatory — without it, camera preview is sluggish or black
- `android:required="false"` on camera feature prevents unnecessary Play Store filtering

---

## 13. Asset Directory Structure

Exact file tree as verified in the repository (72 files, 9 directories):

```
assets/
├── Audio/
│   ├── SFX/
│   │   ├── SFX_Click.mp3
│   │   ├── SFX_lose_violin_lose_4.mp3
│   │   ├── SFX_sword_01.mp3
│   │   ├── SFX_sword_02.mp3
│   │   ├── SFX_sword_03.mp3
│   │   ├── SFX_sword_04.mp3
│   │   ├── SFX_sword_05.mp3
│   │   ├── SFX_victory_winning.mp3
│   │   └── SFX_win_violin_win_5.mp3
│   ├── ST/
│   │   ├── ST_BATTLE_ob-lix-beats_dark_pagan_norse.mp3
│   │   ├── ST_COOLDOWN_medieval_horizons_squire.mp3
│   │   └── ST_MAIN_medieval_horizons_quiet_repose.mp3
│   └── VO/
│       ├── VO_announcerLose_DISAPPOINTING.mp3
│       ├── VO_announcerLose_GAME OVER.mp3
│       ├── VO_announcerLose_PATHETIC.mp3
│       ├── VO_announcerLose_YOU DIED.mp3
│       ├── VO_announcerVictory_VICTOR.mp3
│       ├── VO_announcerWin_BERSERK.mp3
│       ├── VO_announcerWin_DECIMATION.mp3
│       ├── VO_announcerWin_FEROCITY.mp3
│       ├── VO_announcerWin_SAVAGERY.mp3
│       ├── VO_announcerWin_VICIOUS.mp3
│       ├── VO_monsterRoar_01.mp3
│       ├── VO_monsterRoar_02.mp3
│       ├── VO_monsterRoar_03.mp3
│       ├── VO_monsterRoar_04.mp3
│       ├── VO_monsterRoar_05.mp3
│       ├── VO_monsterRoar_06.mp3
│       ├── VO_monsterRoar_07.mp3
│       ├── VO_monsterRoar_08.mp3
│       ├── VO_monsterRoar_09.mp3
│       ├── VO_monsterRoar_10.mp3
│       ├── VO_playerGrunts_01.mp3
│       ├── VO_playerGrunts_02.mp3
│       ├── VO_playerGrunts_03.mp3
│       ├── VO_playerGrunts_04.mp3
│       ├── VO_playerGrunts_05.mp3
│       ├── VO_playerGrunts_06.mp3
│       ├── VO_playerGrunts_07.mp3
│       ├── VO_playerGrunts_08.mp3
│       ├── VO_playerGrunts_09.mp3
│       └── VO_playerGrunts_10.mp3
└── Sprites/
    ├── Monsters-64x96px/
    │   ├── SPR_monster_01.png
    │   ├── SPR_monster_02.png
    │   ├── SPR_monster_03.png
    │   ├── SPR_monster_04.png
    │   ├── SPR_monster_05.png
    │   ├── SPR_monster_06.png
    │   ├── SPR_monster_07.png
    │   ├── SPR_monster_08.png
    │   ├── SPR_monster_09.png
    │   ├── SPR_monster_10.png
    │   ├── SPR_monster_11.png
    │   ├── SPR_monster_12.png
    │   ├── SPR_monster_13.png
    │   ├── SPR_monster_14.png
    │   ├── SPR_monster_15.png
    │   ├── SPR_monster_16.png
    │   ├── SPR_monster_17.png
    │   ├── SPR_monster_18.png
    │   ├── SPR_monster_19.png
    │   └── SPR_monster_20.png
    ├── PixelHealthBar-128x16px/
    │   ├── SPR_bar_emptyHealthBar.png
    │   ├── SPR_bar_healthBar.png
    │   ├── SPR_bar_health.png
    │   ├── SPR_bar_noHealthBar.png
    │   └── SPR_bar_noHealth.png
    ├── Sword-64x64px/
    │   ├── SPR_sword_sprite_sheet_01.png
    │   ├── SPR_sword_sprite_sheet_02.png
    │   └── SPR_sword_sprite_sheet_03.png
    ├── SPR_heart-sprite-sheet-48x24px.png
    └── SPR_logo_fitfusion-752x752px.png
```

**Asset loading notes for Windsurf:**
- Flame's asset loading uses paths relative to the `assets/` root declared in `pubspec.yaml`
- All subdirectories under `assets/` must be individually declared in `pubspec.yaml` — a single `assets/` declaration does not recursively include subdirectories in Flutter
- VO files with spaces in names (e.g., `VO_announcerLose_GAME OVER.mp3`) must be referenced with the exact filename including the space — consider URL-encoding or wrapping in quotes if asset loading fails
