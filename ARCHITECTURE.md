# FitFusion — System Architecture

> This document describes how FitFusion's systems are structured, how data flows between them,
> and the reasoning behind every major technical decision.
> Read this alongside CONTEXT.md before writing any code.

---

## 1. The Big Picture

FitFusion is composed of three independent systems that communicate through typed streams:

```
┌─────────────────────────────────────────────────────────────────────┐
│                         MOTION PIPELINE                             │
│  Phone Camera → CameraService → PoseDetectorService → RepDetector  │
│                                               ↓                     │
│                                         PaceMonitor                 │
└─────────────────────────────────────────────────────────────────────┘
                                    │ Stream<RepEvent>
                                    │ Stream<PaceEvent>
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│                          GAME CONTROLLER                            │
│                  (bridge layer — decouples motion from game)        │
└─────────────────────────────────────────────────────────────────────┘
                                    │ method calls
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│                           FLAME GAME                                │
│              FitFusionGame (FlameGame subclass)                     │
│         Components: Monster, HealthBar, HUD, Cooldown, etc.        │
└─────────────────────────────────────────────────────────────────────┘
                                    │ GameSession (on end)
                                    ↓
┌─────────────────────────────────────────────────────────────────────┐
│                         FIREBASE BACKEND                            │
│            Firestore: sessions, stats, leaderboard, achievements    │
│            Firebase Auth: Google Sign-In identity                   │
└─────────────────────────────────────────────────────────────────────┘
```

Each box is independent. Each arrow is a clean interface. The Flame game does not import Firebase. The rep detector does not import Flame. This separation is what makes the system debuggable under time pressure — you can test each layer in isolation.

---

## 2. Layer 1 — The Motion Pipeline

### 2.1 CameraService

**File:** `lib/features/motion/camera_service.dart`

**Responsibility:** Own and manage the `CameraController`. Initialize it at a specified resolution, start the image stream, and emit raw `CameraImage` frames. Also expose a widget-compatible preview stream.

**Key decisions:**
- Resolution is set to `ResolutionPreset.low` (typically 352×288 or 640×480 depending on device). This is intentional — lower resolution means faster ML Kit inference on budget hardware.
- The front camera is selected because the player faces the phone.
- `CameraController` must be disposed when the game screen is disposed. A memory leak here will crash the app.

**Outputs:**
- `Stream<CameraImage>` — raw frames, throttled by `kFrameSkipCount`

**Frame skipping logic:**
```dart
int _frameCount = 0;

void _onFrame(CameraImage image) {
  _frameCount++;
  if (_frameCount % kFrameSkipCount != 0) return; // skip this frame
  _frameController.add(image);
}
```

This ensures ML Kit only receives every Nth frame, which is the single most important performance optimization in the codebase.

---

### 2.2 PoseDetectorService

**File:** `lib/features/motion/pose_detector_service.dart`

**Responsibility:** Wrap ML Kit's `PoseDetector`. Accept `CameraImage` frames, convert them to `InputImage` format, run inference, and emit `Pose?` results.

**Key decisions:**
- Uses `PoseDetector` with `PoseDetectorOptions(mode: PoseDetectionMode.stream)` — stream mode is optimized for consecutive frames and reuses internal state between calls.
- Uses the base model, not the accurate model. The accurate model is too slow for real-time use on the Tecno Spark Go 30c.
- `InputImage` conversion from `CameraImage` is the trickiest part of the entire pipeline. The `CameraImage` from Flutter's camera package uses a YUV420 byte format (on Android). ML Kit requires this to be converted properly with the correct rotation metadata.

**CameraImage → InputImage conversion:**
```dart
InputImage _toInputImage(CameraImage image, int sensorOrientation) {
  final WriteBuffer allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: InputImageRotationValue.fromRawValue(sensorOrientation)
          ?? InputImageRotation.rotation0deg,
      format: InputImageFormat.yuv420,
      bytesPerRow: image.planes[0].bytesPerRow,
    ),
  );
}
```

**Landmark reliability filter:**
Before emitting a `Pose`, filter out any pose where critical landmarks (the ones needed for the selected workout) have `likelihood < kLandmarkLikelihoodThreshold (0.5)`. If critical landmarks are unreliable, emit `null` instead.

**Outputs:**
- `Stream<Pose?>` — null means "no reliable pose detected this frame"

---

### 2.3 RepDetector

**File:** `lib/features/motion/rep_detector.dart`

**Responsibility:** Consume the `Stream<Pose?>` from `PoseDetectorService` and count completed reps by running a state machine appropriate for the selected workout type. Emit a `RepEvent` each time a rep is completed.

**This is the most algorithmically complex piece of the codebase.** Take time to get it right.

**Pattern: State Machine per Exercise**

Each exercise is detected using a two-state finite state machine: `up` and `down` (or equivalent). A rep is completed when the machine transitions from `down` → `up` (i.e., the return to neutral position signals completion, not the initial movement into position).

---

#### Exercise 1: Squats

**Landmarks used:** `leftHip`, `leftKnee`, `leftAnkle` (mirror with right side for robustness)

**Detection logic:**
- Compute the vertical distance between the hip and knee: `hipKneeDelta = knee.y - hip.y`
- In a standing position, the hip is significantly above the knee: `hipKneeDelta` is large
- In a squat (down) position, the hip drops toward the knee: `hipKneeDelta` decreases
- Threshold: when `hipKneeDelta` drops below `kSquatHipDropThreshold` of normalized height, transition to `squatDown` state
- When `hipKneeDelta` rises back above threshold, transition to `squatUp` state → **rep counted**

**Noise filtering:** Apply a rolling average of the last 5 frames' `hipKneeDelta` values before comparing to the threshold. This prevents single-frame jitter from causing false reps.

```
State: standing
  hipKneeDelta < threshold → transition to squatDown

State: squatDown
  hipKneeDelta > threshold → transition to standing → EMIT REP
```

---

#### Exercise 2: Jumping Jacks

**Landmarks used:** `leftWrist`, `rightWrist`, `leftShoulder`, `rightShoulder`

**Detection logic:**
- Jumping jacks have two phases: arms down (rest) and arms raised (extended)
- In arms-raised position: both wrists are above or near shoulder height
- Measure: `wristAboveShoulder = shoulder.y - wrist.y` (positive = wrist higher than shoulder in image space, since y increases downward)
- When both wrists simultaneously satisfy `wristAboveShoulder > kJumpingJackWristRaiseThreshold`, transition to `armsUp` state
- When both wrists drop back below threshold, transition to `armsDown` state → **rep counted**

**Note on coordinate space:** In normalized image space, y=0 is the top of the image and y=1 is the bottom. "Above" means smaller y value. A raised wrist will have a smaller y value than the shoulder.

```
State: armsDown
  leftWrist.y < leftShoulder.y AND rightWrist.y < rightShoulder.y → transition to armsUp

State: armsUp
  wrists drop below shoulder level → transition to armsDown → EMIT REP
```

---

#### Exercise 3: Side Oblique Crunches

**Landmarks used:** `leftWrist`, `leftHip` (for left-side crunch) and `rightWrist`, `rightHip` (for right-side crunch)

**Detection logic:**
- An oblique crunch involves bending sideways, bringing one hand down toward the same-side hip
- Measure: Euclidean distance between `wrist` and `hip` on the same side: `d = sqrt((wrist.x - hip.x)² + (wrist.y - hip.y)²)`
- When `d < kCrunchWristHipProximityThreshold`, the wrist is near the hip → crunch is in the "down" position
- When `d` rises back above threshold, the player has returned to neutral → **rep counted** (one side only per rep)
- Both left and right sides are counted. Each side crunch is one rep.
- To avoid double-counting rapid oscillations, require the player to return to a fully extended state (large `d`) between reps.

```
State: extended (both sides)
  leftWrist near leftHip (d < threshold) → transition to leftCrunchDown

State: leftCrunchDown
  leftWrist returns to extended position → transition to extended → EMIT REP

State: extended
  rightWrist near rightHip → transition to rightCrunchDown

State: rightCrunchDown
  rightWrist returns to extended → transition to extended → EMIT REP
```

---

**RepEvent data class:**
```dart
class RepEvent {
  final WorkoutType workoutType;
  final DateTime timestamp;

  const RepEvent({required this.workoutType, required this.timestamp});
}
```

**Outputs:**
- `Stream<RepEvent>` — one event per completed rep

---

### 2.4 PaceMonitor

**File:** `lib/features/motion/pace_monitor.dart`

**Responsibility:** Watch the `Stream<RepEvent>` and enforce the pace rule. Emit a `PaceEvent` when a pace violation occurs (3 seconds without a rep during an active round).

**PaceMonitor does NOT know about rounds or game state.** It is simply a timer watcher. The `GameController` tells it when to start and stop monitoring (i.e., it is paused during cooldown and before the first rep of a round).

**Implementation:**
- Maintains a `Timer` that resets on each `RepEvent`
- If the timer fires (3 seconds elapsed with no rep), emit a `PaceFailureEvent`
- The monitor has `start()`, `stop()`, and `reset()` methods called by `GameController`
- `start()` begins watching (called after the first rep of a round)
- `stop()` cancels monitoring (called on round win, cooldown start, game over)
- `reset()` is called after each rep to restart the 3-second window

**PaceEvent data class:**
```dart
class PaceEvent {
  final PaceEventType type; // repOnTime, paceFailed
  final double intervalSeconds;  // seconds since last rep
  final DateTime timestamp;
}

enum PaceEventType { repOnTime, paceFailed }
```

**Outputs:**
- `Stream<PaceEvent>`

---

## 3. Layer 2 — The Game Controller

**File:** `lib/features/game/game_controller.dart`

**Responsibility:** The bridge between the motion pipeline and the Flame game. It subscribes to `RepEvent` and `PaceEvent` streams, translates them into game actions, and calls methods on `FitFusionGame`.

**This is intentionally a thin orchestration layer.** It contains no game logic itself — that belongs in `FitFusionGame`. It contains no motion detection logic — that belongs in the motion pipeline. It just wires them together.

**GameController responsibilities:**
- Subscribe to `RepDetector.repStream` → call `game.onRepDetected()`
- Subscribe to `PaceMonitor.paceStream` → call `game.onPaceFailed()` on `paceFailed` events
- Tell `PaceMonitor` to start after the first rep of each round
- Tell `PaceMonitor` to stop when a round ends or the game ends
- Receive `GamePhase` changes from `FitFusionGame` and react accordingly (e.g., pause pace monitoring during cooldown)

**Lifecycle:**
- Created when `GameScreen` mounts
- Disposed when `GameScreen` unmounts
- Holds `StreamSubscription` references and cancels them in `dispose()`

---

## 4. Layer 3 — The Flame Game

**File:** `lib/features/game/fitfusion_game.dart`

**Responsibility:** Own and run the entire game session. Manage game state, round progression, monster health, player lives, cooldown timers, win/lose conditions, and all visual components.

### 4.1 Game State Machine

The game exists in one of these phases at all times:

```dart
enum GamePhase {
  waitingForFirstRep,  // round started, pace timer not yet running
  playing,             // active round, pace timer running
  cooldown,            // between rounds, rep detection paused
  victory,             // player won — all 10 rounds complete
  defeat,              // player lost — 0 lives
}
```

State transitions:

```
waitingForFirstRep
  → first rep detected → playing

playing
  → rep detected, monster health > 0 → playing (update health bar)
  → rep detected, monster health == 0 → cooldown (round won)
  → pace failed → playing (lose life, check if lives == 0)
  → lives == 0 → defeat

cooldown
  → timer expires → waitingForFirstRep (next round loaded)
  → was round 10 → victory

victory / defeat
  → terminal states, no transitions
```

### 4.2 FitFusionGame Public API

These are the methods `GameController` calls:

```dart
// Called by GameController when rep detector fires
void onRepDetected();

// Called by GameController when pace monitor fires a paceFailed event
void onPaceFailed();

// Called by GameScreen to pass configuration in before game starts
void configure({required WorkoutType workoutType});
```

### 4.3 Session Tracking

`FitFusionGame` accumulates session data throughout the run:

```dart
// Accumulated during play
int _totalReps = 0;
int _livesLost = 0;
int _roundsCompleted = 0;
DateTime? _sessionStartTime;
DateTime? _lastRepTime;
List<double> _repIntervals = []; // seconds between consecutive reps
```

On session end (victory or defeat), build a `GameSession` object and pass it to `ResultsScreen` via the navigator.

### 4.4 Component Hierarchy

All game visuals are `FlameComponent` subclasses added to `FitFusionGame`:

```
FitFusionGame
├── MonsterComponent               ← sprite, idle/hit animation, positioned upper-center
│   └── MonsterHealthBar          ← child component, positioned below monster
├── RoundBanner                   ← "ROUND X / 10" text, top-left
├── PlayerLivesDisplay            ← heart icons, top-right
├── RepProgressBar                ← "REPS: X / Y" progress, bottom HUD
├── DamageNumber (spawned)        ← "+1" floating, spawned on each rep hit, auto-removed
├── CooldownOverlay (conditional) ← full-screen overlay during cooldown, shows countdown
└── PaceTimerIndicator            ← urgency meter showing remaining pace time
```

### 4.5 The AR Overlay Architecture

The "AR" effect is achieved by compositing the `GameWidget` over a camera preview widget. This is implemented in `GameScreen`:

```dart
// lib/features/screens/game_screen.dart

Stack(
  children: [
    // Layer 1 (bottom): Camera feed fills the screen
    CameraPreviewWidget(controller: _cameraController),

    // Layer 2 (debug only): Pose landmark skeleton overlay
    if (kDebugMode)
      PoseOverlayPainter(pose: _currentPose, imageSize: _imageSize),

    // Layer 3 (top): Flame game with transparent background
    GameWidget(game: _fitFusionGame),
  ],
)
```

**Critical:** `FitFusionGame` must have a transparent background — set `backgroundColor` in the `FlameGame` constructor to `Colors.transparent`. Without this, the camera feed is hidden behind a solid color.

---

## 5. Layer 4 — The Firebase Backend

### 5.1 FirestoreService

**File:** `lib/features/firebase/firestore_service.dart`

All Firestore operations in one file. No other file touches Firestore directly.

Public methods:
```dart
Future<void> createUserDocument(User user);
Future<void> writeSession(String uid, GameSession session);
Future<void> updateStats(String uid, GameSession session);
Future<void> updateLeaderboard(String uid, String displayName, String? photoUrl, GameSession session);
Future<void> unlockAchievements(String uid, List<AchievementId> achievements);
Future<List<LeaderboardEntry>> getLeaderboard(WorkoutType workoutType, LeaderboardType type);
Future<Map<WorkoutType, PlayerStats>> getPlayerStats(String uid);
```

All methods are wrapped in `try/catch`. Failures are logged but not re-thrown — the app continues.

### 5.2 Session Write Flow

Triggered from `ResultsScreen` after session ends:

```
ResultsScreen receives GameSession
  → if user is signed in:
      1. FirestoreService.writeSession(uid, session)
      2. FirestoreService.updateStats(uid, session)
      3. FirestoreService.updateLeaderboard(uid, ...) — only if session was a win
      4. Check achievements → FirestoreService.unlockAchievements(uid, newAchievements)
  → if guest:
      → skip all Firebase calls, show results locally only
```

### 5.3 AuthService

**File:** `lib/features/auth/auth_service.dart`

```dart
Future<UserCredential?> signInWithGoogle();
Future<void> signOut();
Stream<User?> get authStateChanges; // from FirebaseAuth.instance.authStateChanges()
User? get currentUser;
bool get isSignedIn;
```

On successful `signInWithGoogle()`:
1. Check if `/users/{uid}` document exists
2. If not, call `FirestoreService.createUserDocument(user)`

---

## 6. Screen Navigation Flow

```
App Launch
  └─→ SplashScreen
        ├─→ (auth check) → HomeScreen
        └─→ (first launch) → HomeScreen

HomeScreen
  ├─→ [Play] → WorkoutSelectScreen
  │     └─→ [Select Workout] → GameScreen
  │           └─→ (session ends) → ResultsScreen
  │                 └─→ [Play Again] → WorkoutSelectScreen
  │                 └─→ [Home] → HomeScreen
  ├─→ [Leaderboard] → LeaderboardScreen
  ├─→ [Stats] → StatsScreen (or sign-in prompt if guest)
  └─→ [Sign In / Sign Out] → Auth flow (no dedicated screen — modal/bottom sheet)
```

All navigation uses Flutter's `Navigator`. Named routes defined in `app.dart`.

---

## 7. State Management Strategy

FitFusion uses a **minimal, pragmatic** approach to state management. There is no Redux, no BLoC, no complex reactive graph.

**At the widget layer:** Use `Provider` (already pulled in transitively by Firebase packages). Two providers are needed:

```dart
// In main.dart, wrapping the app:
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
    // Add more as needed
  ],
  child: FitFusionApp(),
)
```

**Inside the game screen:** State is managed directly by `GameController` and `FitFusionGame`. These are not exposed as providers — they live within `GameScreen`'s `State` object and are created/disposed with the screen.

**Rule:** If a piece of state is needed by multiple screens (auth status, user display name), it goes in a `Provider`. If it's only needed by the game screen, it stays local.

---

## 8. The RepDetector in Detail — Rolling Average Filter

Rep detection is susceptible to landmark jitter — single-frame outliers where a landmark briefly misreports its position. Without smoothing, this causes phantom reps or missed reps.

**Solution: Rolling average buffer**

```dart
class _LandmarkBuffer {
  final int windowSize;
  final Queue<double> _values = Queue();

  _LandmarkBuffer(this.windowSize);

  void add(double value) {
    _values.addLast(value);
    if (_values.length > windowSize) _values.removeFirst();
  }

  double get average {
    if (_values.isEmpty) return 0.0;
    return _values.reduce((a, b) => a + b) / _values.length;
  }

  bool get isFull => _values.length == windowSize;
}
```

Each measured value (e.g., `hipKneeDelta` for squats) is fed through a `_LandmarkBuffer(5)` before being compared to a threshold. Only when the buffer is full (5 frames have been recorded) do we start making rep decisions. This 5-frame window at ~15–20 FPS processing speed = ~0.25–0.33 seconds of smoothing, which is enough to eliminate jitter without introducing perceptible latency.

---

## 9. Data Flow Diagram — A Single Rep, End to End

```
Phone camera captures frame
  ↓
CameraService receives CameraImage
  ↓ (skip if frame % kFrameSkipCount != 0)
PoseDetectorService.processFrame(CameraImage)
  ↓ (convert to InputImage, run ML Kit inference)
Pose returned with 33 PoseLandmarks
  ↓ (filter: check likelihood >= 0.5 for critical landmarks)
RepDetector.onPose(Pose)
  ↓ (extract relevant landmark pair, add to rolling buffer)
  ↓ (compare buffered average to threshold)
  ↓ (state machine transition: if returning from "down" → "up" position)
Stream<RepEvent> emits RepEvent
  ↓
GameController receives RepEvent
  ↓ (calls PaceMonitor.onRepReceived())
  ↓ (calls fitFusionGame.onRepDetected())
FitFusionGame.onRepDetected()
  ↓ (monsterHealth -= 1)
  ↓ (if monsterHealth == 0 → roundComplete())
  ↓ (spawn DamageNumber component)
  ↓ (update RepProgressBar)
MonsterHealthBar updates visually
  ↓
User sees monster take damage on screen
```

Total path: Camera frame → visible game feedback. This is the heartbeat of the application.

---

## 10. Performance Architecture

### Frame Budget on the Tecno Spark Go 30c

At 640×480, the camera delivers ~30 FPS. With `kFrameSkipCount = 2`, ML Kit sees ~15 FPS. ML Kit pose detection on a budget device takes ~50–80ms per frame. At 15 FPS input, inference must complete before the next frame arrives (~66ms). This is tight but workable with the base model.

If frame processing backs up (queue grows), prefer **dropping frames** over processing them late. Late pose data is worse than no data — it causes the state machine to receive stale inputs and misfire.

### What Runs Where

| Work | Thread |
|------|--------|
| Camera frame capture | Camera background thread |
| ML Kit inference | `compute()` isolate or background thread |
| Rep state machine | Main thread (lightweight) |
| Flame game loop | Main thread (Flutter's raster thread) |
| Firestore writes | Firebase SDK background thread |

Flame's game loop and Flutter's widget tree share the main thread. ML Kit inference is the only heavyweight operation and must not run on the main thread.

### Memory Management Checklist
- `CameraController.dispose()` — called in `GameScreen.dispose()`
- `PoseDetector.close()` — called in `PoseDetectorService.dispose()`
- `StreamController.close()` — called in each service's `dispose()`
- `StreamSubscription.cancel()` — called in `GameController.dispose()`
- `FitFusionGame.detach()` or `removeFromParent()` — called on game screen exit

---

## 11. Key Technical Risks and Mitigations

| Risk | Likelihood | Mitigation |
|------|-----------|------------|
| CameraImage → InputImage conversion fails silently | High | Log and assert byte format matches. Test on device early. |
| Rep detection threshold is wrong for real user movement | High | Tune thresholds with live testing, not assumptions. Make thresholds configurable via constants. |
| ML Kit too slow on Tecno → game unplayable | Medium | Frame skipping + base model + low resolution. Test in Milestone 1. |
| Front camera mirroring causes left/right landmark inversion | Medium | Add horizontal flip compensation in both overlay painter and rep detector. |
| Flame GameWidget transparent background not working | Low | Explicitly set `backgroundColor: Colors.transparent` in FlameGame constructor. |
| Firebase write fails mid-session | Low | Wrap in try/catch. Session data held in memory. Retry once on failure. Never block game on Firebase. |
| Google Sign-In SHA-1 mismatch in release build | Medium | Release build uses a different key. Regenerate SHA-1 from release keystore before submission. |

---

## 12. Dependency List (pubspec.yaml reference)

```yaml
dependencies:
  flutter:
    sdk: flutter

  # Game engine
  flame: ^1.18.0

  # Motion detection
  google_mlkit_pose_detection: ^0.11.0

  # Camera access
  camera: ^0.11.0

  # Firebase
  firebase_core: ^3.3.0
  firebase_auth: ^5.1.4
  cloud_firestore: ^5.2.1

  # Auth
  google_sign_in: ^6.2.1

  # State management
  provider: ^6.1.2

  # Runtime permissions (camera requires runtime request on Android 14)
  permission_handler: ^11.3.0

  # Google Fonts (Cinzel for fantasy typography)
  google_fonts: ^6.2.1
```

---

## 13. Android Manifest Requirements

The following must be present in `android/app/src/main/AndroidManifest.xml`:

```xml
<!-- Outside <application> tag -->
<uses-permission android:name="android.permission.CAMERA"/>
<uses-permission android:name="android.permission.INTERNET"/>
<uses-feature android:name="android.hardware.camera" android:required="false"/>

<!-- On the <application> tag -->
<application
    android:hardwareAccelerated="true"
    ... >
```

`hardwareAccelerated="true"` is mandatory for acceptable camera preview performance. Without it, the camera feed will be sluggish or black on some devices.

`android:required="false"` on the camera feature allows installation on devices without a front camera (edge case, but prevents unnecessary Play Store filtering in future).
