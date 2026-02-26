# FitFusion — Complete Windsurf AI Prompt Playbook

This document contains every prompt you will give to Windsurf AI,
across all five milestones, from first line of code to release APK.

Each prompt is a discrete, self-contained task. Complete and verify each one
on the physical device before moving to the next. Do not batch prompts together.
Do not skip verification steps.

---

## The Session Start Ritual — Run This Every Single Time

Every time you open Windsurf and start a new session, paste this first.
No exceptions. This is non-negotiable.

```
Read the following three files in their entirety before you do anything else:
1. CONTEXT.md
2. ARCHITECTURE.md
3. WINDSURF_HANDOFF.md

After reading all three, confirm your understanding by answering these exactly:
1. What is FitFusion in one sentence?
2. What is the bundle ID?
3. What is the target device?
4. What milestone are we currently on, and what is its deliverable?
5. What files exist right now under lib/?

Do not write any code until you have answered all five questions and I have
confirmed your answers are correct. If you are unsure about the current state
of any file, ask me — do not assume.
```

Read Windsurf's response. If any answer is wrong or vague, correct it and make
Windsurf re-confirm before proceeding. This 60-second ritual prevents hours of
debugging Windsurf's wrong assumptions.

---

---

# MILESTONE 1 — Camera Feed + Pose Detection + Rep Counting

**Goal:** The app sees the player's body, tracks it in real time, and correctly
counts reps for all three exercises. Nothing about the actual game yet.

**Done when:** You can do squats, jumping jacks, and side oblique crunches in
front of the phone and see correct rep counts printing in the debug console.
All three exercises must work. No false positives. No missed reps.

---

## M1 — Prompt 1: Core Scaffolding and App Skeleton

```
We are beginning Milestone 1 of FitFusion. The project currently has only:
- lib/main.dart (default Flutter counter app — replace this entirely)
- lib/firebase_options.dart (DO NOT TOUCH THIS FILE UNDER ANY CIRCUMSTANCES)

Your task is to build the application skeleton. No game logic, no camera, no
ML Kit yet. Just the structural foundation every other file will build on.

Create the following files. Follow the specifications exactly.

---

FILE 1: lib/core/constants.dart

Define every game constant and parameter in this file. No magic numbers are
permitted anywhere else in the codebase. If a value is used more than once,
or if it controls game behavior, it belongs here.

```dart
// Game Rules
const int kTotalRounds = 10;
const int kStartingLives = 3;
const double kPaceThresholdSeconds = 3.0;
const int kCooldownSeconds = 12;

// Rep formula — repsRequired(round) = round + 1
// round is 1-indexed (1 through 10)
int repsRequiredForRound(int round) => round + 1;

// Camera / ML Kit Performance
const int kFrameSkipCount = 2;  // process every Nth frame from the camera
const double kLandmarkLikelihoodThreshold = 0.5;

// Rep Detection Thresholds
// These are normalized coordinate values (0.0 to 1.0 relative to image size)
// They will require tuning via physical device testing
const double kSquatHipDropThreshold = 0.15;
const double kJumpingJackWristRaiseThreshold = 0.08;
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
```

---

FILE 2: lib/core/enums.dart

All enums for the project in one file.

```dart
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
```

---

FILE 3: lib/core/extensions.dart

Utility extensions used throughout the app.

```dart
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
```

---

FILE 4: lib/core/theme.dart

The visual identity of the app. High Fantasy aesthetic.
Use the google_fonts package for Cinzel. Import it.

Define an AppTheme class with a static ThemeData getter.
The theme must use:
- Primary color: Color(0xFF1A237E) — deep royal blue
- Accent/secondary: Color(0xFFFFD700) — gold
- Background: Color(0xFF0D1B3E) — midnight navy
- Surface: Color(0xFF1A2D5A) — slightly lighter navy for cards/panels
- Error: Color(0xFFB71C1C) — crimson
- On-primary text: Color(0xFFFFFDE7) — cream white
- All body text: GoogleFonts.cinzel
- All display text: GoogleFonts.cinzelDecorative (use cinzel as fallback if unavailable)

Also define these static color constants directly on AppTheme for use
in Flame components (which cannot use ThemeData):
- static const Color gold = Color(0xFFFFD700)
- static const Color royalBlue = Color(0xFF1A237E)
- static const Color midnightNavy = Color(0xFF0D1B3E)
- static const Color crimson = Color(0xFFB71C1C)
- static const Color emerald = Color(0xFF2E7D32)
- static const Color parchment = Color(0xFFFFF8E1)
- static const Color brightGold = Color(0xFFFFEE58)
- static const Color creamWhite = Color(0xFFFFFDE7)

---

FILE 5: lib/core/events.dart

Event data classes used in streams between layers.

```dart
import 'enums.dart';

/// Emitted by RepDetector each time a complete rep is detected.
class RepEvent {
  final WorkoutType workoutType;
  final DateTime timestamp;
  const RepEvent({required this.workoutType, required this.timestamp});
}

/// Emitted by PaceMonitor when a rep arrives on time, or when the pace fails.
class PaceEvent {
  final PaceEventType type;

  /// Seconds elapsed between the last rep and this event.
  /// For repOnTime: the actual interval (will be < kPaceThresholdSeconds).
  /// For paceFailed: equals kPaceThresholdSeconds exactly.
  final double intervalSeconds;

  final DateTime timestamp;

  const PaceEvent({
    required this.type,
    required this.intervalSeconds,
    required this.timestamp,
  });
}
```

---

FILE 6: lib/app.dart

The MaterialApp root. All screen stubs registered as named routes.

```dart
import 'package:flutter/material.dart';
import 'core/theme.dart';
// Import all screen files once they exist. For now, create inline stubs.

class FitFusionApp extends StatelessWidget {
  const FitFusionApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'FitFusion',
      theme: AppTheme.theme,
      debugShowCheckedModeBanner: false,
      initialRoute: '/',
      routes: {
        '/': (context) => const _StubScreen(name: 'Splash'),
        '/home': (context) => const _StubScreen(name: 'Home'),
        '/select': (context) => const _StubScreen(name: 'Workout Select'),
        '/game': (context) => const _StubScreen(name: 'Game'),
        '/results': (context) => const _StubScreen(name: 'Results'),
        '/leaderboard': (context) => const _StubScreen(name: 'Leaderboard'),
        '/stats': (context) => const _StubScreen(name: 'Stats'),
      },
    );
  }
}

/// Temporary stub screen. Will be replaced screen by screen in later tasks.
class _StubScreen extends StatelessWidget {
  final String name;
  const _StubScreen({required this.name});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnightNavy,
      body: Center(
        child: Text(
          name,
          style: const TextStyle(color: AppTheme.gold, fontSize: 24),
        ),
      ),
    );
  }
}
```

---

FILE 7: lib/main.dart

Replace the entire default counter app content.

```dart
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'app.dart';
import 'firebase_options.dart'; // DO NOT MODIFY THIS FILE

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  runApp(const FitFusionApp());
}
```

---

After creating all seven files, do the following:
1. Run: flutter pub get
2. Run: flutter analyze
3. Fix every analysis error before reporting back to me.
4. Run: flutter run
5. Confirm the app launches on the Tecno and shows the Splash stub screen
   (dark navy background, gold text saying "Splash").

Report back with:
- Whether flutter analyze passed clean
- Whether the app launched on the device successfully
- Any errors encountered and how you resolved them
```

**Verify before continuing:** App launches on device. Shows navy background with gold "Splash" text. Zero analyzer errors. If there are errors, fix them before Prompt 2.

---

## M1 — Prompt 2: Camera Service and Camera Preview Widget

```
Milestone 1, Prompt 2: Camera Service.

The scaffolding from Prompt 1 is complete and verified working on the device.
Now we build the camera layer.

---

FILE: lib/features/motion/camera_service.dart

Create a CameraService class that manages the phone's front camera.

Requirements:

1. INITIALIZATION
   - The class has an async initialize() method
   - It must call WidgetsFlutterBinding.ensureInitialized() if not already done
     (safe to call multiple times)
   - Query available cameras using the cameras() function from the camera package
   - Select the front-facing camera: iterate the list and find the first camera
     where lensDirection == CameraLensDirection.front
   - If no front camera is found, fall back to cameras().first
   - Initialize a CameraController with:
       - The selected camera description
       - ResolutionPreset.low (critical for ML Kit performance on budget hardware)
       - imageFormatGroup: ImageFormatGroup.yuv420
       - enableAudio: false (we do not need audio)
   - Call await controller.initialize()
   - After initialization, call controller.startImageStream(_onFrame)

2. FRAME STREAMING WITH SKIP
   - Maintain a private int _frameCount = 0
   - In _onFrame(CameraImage image):
       _frameCount++;
       if (_frameCount % kFrameSkipCount != 0) return;
       _frameController.add(image);
   - _frameController is a StreamController<CameraImage> that is NOT broadcast
     (single subscriber — PoseDetectorService will be the only listener)
   - Expose: Stream<CameraImage> get frameStream => _frameController.stream;

3. CONTROLLER EXPOSURE
   - Expose: CameraController? get controller => _controller;
   - This allows the widget layer to build a CameraPreview

4. CAMERA DESCRIPTION EXPOSURE
   - Expose: CameraDescription? get cameraDescription => _selectedCamera;
   - PoseDetectorService needs the sensor orientation from this

5. STATE TRACKING
   - Expose: bool get isInitialized => _controller?.value.isInitialized ?? false;

6. DISPOSAL
   - dispose() must:
       - Stop the image stream: await _controller?.stopImageStream()
       - Dispose the controller: await _controller?.dispose()
       - Close the stream controller: await _frameController.close()
       - Set _controller to null

7. ERROR HANDLING
   - Wrap initialize() in try/catch
   - On error, debugPrint the error and rethrow so the caller knows it failed
   - Never silently swallow initialization errors

---

FILE: lib/widgets/camera_preview_widget.dart

A widget that displays the live camera feed fullscreen.

Requirements:
- StatefulWidget that takes a required CameraController? controller parameter
- If controller is null or not initialized, show a Container with
  color: Colors.black filling the available space
- If controller is initialized, use SizedBox.expand wrapping a CameraPreview(controller)
- The CameraPreview should be wrapped in a RotatedBox if needed to fix orientation
  (test on the Tecno first — if the camera feed appears sideways, add
  RotatedBox(quarterTurns: 1, child: CameraPreview(controller)))
- Wrap everything in a FittedBox or AspectRatio to handle the camera's
  aspect ratio correctly. The simplest working approach:
    SizedBox.expand(
      child: FittedBox(
        fit: BoxFit.cover,
        child: SizedBox(
          width: controller.value.previewSize!.height,
          height: controller.value.previewSize!.width,
          child: CameraPreview(controller),
        ),
      ),
    )
  This fills the screen without distortion regardless of camera aspect ratio.

---

TEMPORARY TEST: Update the '/game' stub route in app.dart to a temporary
CameraTestScreen so we can verify the camera works in isolation:

Create a StatefulWidget called CameraTestScreen that:
1. Creates a CameraService instance
2. Calls cameraService.initialize() in initState()
3. Calls cameraService.dispose() in dispose()
4. Rebuilds the widget when initialization completes
5. Shows CameraPreviewWidget(controller: cameraService.controller)
6. Shows a CircularProgressIndicator in gold color while initializing

Register it temporarily at the '/game' route in app.dart.

Also update the '/home' stub to add a temporary "Test Camera" button
that navigates to '/game', so you can test it from the running app.

After creating these files:
1. Run flutter analyze — fix all errors
2. Run flutter run
3. Navigate to the Camera Test screen on the device
4. Confirm you can see a live camera feed of the room/yourself on screen
5. Report whether the image is correctly oriented (not sideways, not upside down)
   If it is sideways, tell me and we will add the RotatedBox fix.

Do not proceed until the live camera feed is confirmed working on the physical device.
```

**Verify:** You see yourself in the camera on the Tecno. Image is not sideways or mirrored in a disorienting way. No crash.

---

## M1 — Prompt 3: Pose Detector Service

```
Milestone 1, Prompt 3: Pose Detector Service.

Camera feed is confirmed working. Now we add ML Kit pose detection.

---

FILE: lib/features/motion/pose_detector_service.dart

Create a PoseDetectorService class.

This is the most technically delicate file in Milestone 1. Read every
instruction carefully.

CONSTRUCTOR AND INITIALIZATION:
- Constructor takes no parameters
- Create the PoseDetector in the constructor (not in an async method):
    _detector = PoseDetector(
      options: PoseDetectorOptions(
        mode: PoseDetectionMode.stream,
        model: PoseDetectionModel.base,
      ),
    );
  IMPORTANT: Use PoseDetectionModel.base — NOT PoseDetectionModel.accurate.
  The accurate model is too slow for the Tecno Spark Go 30c.

SUBSCRIBING TO FRAMES:
- Expose: void startProcessing(Stream<CameraImage> frameStream, CameraDescription camera)
- Inside startProcessing, listen to frameStream:
    _subscription = frameStream.listen((image) => _processFrame(image, camera));

FRAME PROCESSING — _processFrame:
This is the core conversion function. It converts a CameraImage (Flutter format)
into an InputImage (ML Kit format).

```dart
Future<void> _processFrame(CameraImage image, CameraDescription camera) async {
  // Prevent concurrent processing — if we're already processing a frame, skip this one
  if (_isProcessing) return;
  _isProcessing = true;

  try {
    final inputImage = _buildInputImage(image, camera);
    if (inputImage == null) {
      _poseController.add(null);
      return;
    }

    final poses = await _detector.processImage(inputImage);

    if (poses.isEmpty) {
      _poseController.add(null);
      return;
    }

    final pose = poses.first;

    // Filter: check that critical landmarks are reliable
    if (!_areCriticalLandmarksReliable(pose)) {
      _poseController.add(null);
      return;
    }

    _poseController.add(pose);
  } catch (e) {
    debugPrint('[PoseDetectorService] Error processing frame: $e');
    _poseController.add(null);
  } finally {
    _isProcessing = false;
  }
}
```

INPUT IMAGE CONVERSION — _buildInputImage:
This is the most common failure point. Implement it exactly as follows:

```dart
InputImage? _buildInputImage(CameraImage image, CameraDescription camera) {
  // Determine rotation from camera sensor orientation
  // Front camera on Android is typically 270 degrees
  final sensorOrientation = camera.sensorOrientation;
  InputImageRotation? rotation;

  // Map sensor orientation degrees to InputImageRotation enum
  switch (sensorOrientation) {
    case 0:
      rotation = InputImageRotation.rotation0deg;
      break;
    case 90:
      rotation = InputImageRotation.rotation90deg;
      break;
    case 180:
      rotation = InputImageRotation.rotation180deg;
      break;
    case 270:
      rotation = InputImageRotation.rotation270deg;
      break;
    default:
      rotation = InputImageRotation.rotation270deg; // front camera default
  }

  // Verify format is YUV420 — this is what we requested in CameraService
  final format = InputImageFormatValue.fromRawValue(image.format.raw);
  if (format == null || format != InputImageFormat.yuv_420_888) {
    // On some Android devices the format raw value may differ
    // Log it so we can debug if this causes issues
    debugPrint('[PoseDetectorService] Unexpected image format: ${image.format.raw}');
    // Do not return null here — try to proceed with yuv_420_888 anyway
  }

  // Concatenate all plane bytes
  final WriteBuffer allBytes = WriteBuffer();
  for (final Plane plane in image.planes) {
    allBytes.putUint8List(plane.bytes);
  }
  final bytes = allBytes.done().buffer.asUint8List();

  return InputImage.fromBytes(
    bytes: bytes,
    metadata: InputImageMetadata(
      size: Size(image.width.toDouble(), image.height.toDouble()),
      rotation: rotation,
      format: InputImageFormat.yuv_420_888,
      bytesPerRow: image.planes[0].bytesPerRow,
    ),
  );
}
```

CRITICAL LANDMARK RELIABILITY CHECK:
```dart
bool _areCriticalLandmarksReliable(Pose pose) {
  const criticalLandmarks = [
    PoseLandmarkType.leftShoulder,
    PoseLandmarkType.rightShoulder,
    PoseLandmarkType.leftHip,
    PoseLandmarkType.rightHip,
  ];

  for (final type in criticalLandmarks) {
    final landmark = pose.landmarks[type];
    if (landmark == null) return false;
    if (landmark.likelihood < kLandmarkLikelihoodThreshold) return false;
  }
  return true;
}
```

STREAM OUTPUT:
- _poseController is a StreamController<Pose?> (broadcast: false)
- Expose: Stream<Pose?> get poseStream => _poseController.stream;

DISPOSAL:
```dart
Future<void> dispose() async {
  await _subscription?.cancel();
  await _detector.close();
  await _poseController.close();
}
```

---

FILE: lib/widgets/pose_overlay_painter.dart

A debug-only widget that draws the 33 pose landmarks as dots on screen.
This is only used during Milestone 1 development to verify that pose
detection is working. It will be hidden behind kDebugMode in later milestones.

Create a StatelessWidget called PoseOverlayWidget that:
- Takes: Pose? pose, Size imageSize
- If pose is null, returns SizedBox.shrink()
- Otherwise, wraps a CustomPainter in SizedBox.expand()

Create the CustomPainter called PoseOverlayPainter:
- Takes: Pose pose, Size imageSize
- In paint(Canvas canvas, Size size):
  - For each landmark in pose.landmarks.values:
    - Skip if landmark.likelihood < kLandmarkLikelihoodThreshold
    - Convert normalized coordinates to screen coordinates:
        // Front camera is mirrored — flip x
        final screenX = size.width - (landmark.x * size.width);
        final screenY = landmark.y * size.height;
    - Draw a filled circle of radius 4 at (screenX, screenY)
    - Use Paint()..color = Colors.greenAccent..style = PaintingStyle.fill
  - Also draw connecting lines between major joints for clarity:
    - Shoulders to hips (torso box)
    - Shoulders to elbows, elbows to wrists (arms)
    - Hips to knees, knees to ankles (legs)
    - Use a thinner stroke (strokeWidth: 2) in Colors.greenAccent.withOpacity(0.5)
    - Only draw a line if BOTH endpoints have likelihood >= threshold
- shouldRepaint: return true always (pose data changes every frame)

---

UPDATE: CameraTestScreen in app.dart (temporary, for Milestone 1 verification only)

Update the CameraTestScreen to:
1. Also create a PoseDetectorService instance
2. In initState, after CameraService initializes:
   poseDetectorService.startProcessing(
     cameraService.frameStream,
     cameraService.cameraDescription!,
   );
3. Listen to poseDetectorService.poseStream:
   - Update a _currentPose state variable on each event
   - Trigger setState to rebuild
4. Update the Stack to include:
   - Layer 1: CameraPreviewWidget
   - Layer 2 (debug only): PoseOverlayWidget(pose: _currentPose, imageSize: ...)
     For imageSize, use Size(640, 480) as a reasonable default —
     the actual image size at ResolutionPreset.low
5. Dispose poseDetectorService in dispose()

Also add a debug counter overlay: a Text widget in the top-right corner
showing "Pose: ACTIVE" in green or "Pose: NULL" in red, updating on each
pose stream event. This confirms at a glance whether ML Kit is detecting.

Run flutter run, navigate to the camera test screen.
Stand in front of the phone.

Report:
1. Do green dots appear on your body? (yes/no)
2. Do the dots roughly track your joints as you move? (yes/no)
3. What FPS are you observing (estimate from how smoothly the dots follow movement)?
4. Any errors in the debug console?

DO NOT proceed to Prompt 4 until the dots are confirmed tracking the body.
If they do not appear, we must debug this before moving on — everything
else depends on ML Kit working.
```

**Verify:** Green dots visible on body on the Tecno. Dots roughly track joints. No crash. If no dots appear, stop here and debug — post the error output verbatim.

---

## M1 — Prompt 4: Rep Detector

```
Milestone 1, Prompt 4: Rep Detector — State Machines for All Three Exercises.

Pose detection is confirmed working on the physical device.
Now we build the logic that turns pose data into rep counts.

---

FILE: lib/features/motion/rep_detector.dart

This is the most algorithmically complex file in the entire project.
Read every specification carefully. Implement exactly as described.

---

SECTION A: The LandmarkBuffer Helper Class

First, define this private helper class inside rep_detector.dart:

```dart
import 'dart:collection';

class _LandmarkBuffer {
  final int windowSize;
  final Queue<double> _values = Queue<double>();

  _LandmarkBuffer(this.windowSize);

  void add(double value) {
    _values.addLast(value);
    if (_values.length > windowSize) {
      _values.removeFirst();
    }
  }

  double get average {
    if (_values.isEmpty) return 0.0;
    return _values.reduce((a, b) => a + b) / _values.length;
  }

  bool get isFull => _values.length >= windowSize;

  void clear() => _values.clear();
}
```

---

SECTION B: The RepDetector Class

```dart
class RepDetector {
  final WorkoutType workoutType;
  
  late final StreamSubscription<Pose?> _poseSubscription;
  final StreamController<RepEvent> _repController = StreamController<RepEvent>();
  
  Stream<RepEvent> get repStream => _repController.stream;
```

CONSTRUCTOR:
```dart
RepDetector({
  required this.workoutType,
  required Stream<Pose?> poseStream,
}) {
  _initializeStateForWorkout();
  _poseSubscription = poseStream.listen(_onPose);
}
```

ROUTING METHOD — _onPose:
```dart
void _onPose(Pose? pose) {
  if (pose == null) return;
  
  switch (workoutType) {
    case WorkoutType.squats:
      _processSquat(pose);
      break;
    case WorkoutType.jumpingJacks:
      _processJumpingJack(pose);
      break;
    case WorkoutType.obliqueCrunches:
      _processObliqueCrunch(pose);
      break;
  }
}
```

STATE MACHINE INITIALIZATION — _initializeStateForWorkout:
Initialize all state variables and buffers for the selected workout.
See state machine implementations below for which variables each needs.

DISPOSAL:
```dart
Future<void> dispose() async {
  await _poseSubscription.cancel();
  await _repController.close();
}
```

EMIT HELPER:
```dart
void _emitRep() {
  debugPrint('[RepDetector] REP DETECTED — $workoutType');
  _repController.add(RepEvent(
    workoutType: workoutType,
    timestamp: DateTime.now(),
  ));
}
```

---

SECTION C: State Machine 1 — Squats

State variables:
```dart
enum _SquatState { standing, squatDown }
_SquatState _squatState = _SquatState.standing;
final _LandmarkBuffer _squatBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
```

Implementation:
```dart
void _processSquat(Pose pose) {
  // Use average of left and right sides for robustness
  // If one side is not visible, the other side still works
  double? metric = _computeSquatMetric(pose);
  if (metric == null) return;

  _squatBuffer.add(metric);
  if (!_squatBuffer.isFull) return; // wait for buffer to fill before deciding

  final smoothed = _squatBuffer.average;

  switch (_squatState) {
    case _SquatState.standing:
      // Hip drops toward knee — delta decreases
      if (smoothed < kSquatHipDropThreshold) {
        _squatState = _SquatState.squatDown;
        debugPrint('[RepDetector] Squat DOWN detected (metric: ${smoothed.toStringAsFixed(3)})');
      }
      break;

    case _SquatState.squatDown:
      // Hip rises back above knee — delta increases again
      if (smoothed >= kSquatHipDropThreshold) {
        _squatState = _SquatState.standing;
        _emitRep();
      }
      break;
  }
}

double? _computeSquatMetric(Pose pose) {
  // hipKneeDelta = knee.y - hip.y
  // In image space, y increases downward.
  // Standing: hip is well above knee, so knee.y > hip.y, delta is POSITIVE and large.
  // Squatting: hip descends toward knee level, delta gets SMALLER.
  
  final leftHip = pose.landmarks[PoseLandmarkType.leftHip];
  final leftKnee = pose.landmarks[PoseLandmarkType.leftKnee];
  final rightHip = pose.landmarks[PoseLandmarkType.rightHip];
  final rightKnee = pose.landmarks[PoseLandmarkType.rightKnee];

  // Try to get at least one valid side
  double? leftDelta;
  double? rightDelta;

  if (leftHip != null && leftKnee != null &&
      leftHip.likelihood >= kLandmarkLikelihoodThreshold &&
      leftKnee.likelihood >= kLandmarkLikelihoodThreshold) {
    leftDelta = leftKnee.y - leftHip.y;
  }

  if (rightHip != null && rightKnee != null &&
      rightHip.likelihood >= kLandmarkLikelihoodThreshold &&
      rightKnee.likelihood >= kLandmarkLikelihoodThreshold) {
    rightDelta = rightKnee.y - rightHip.y;
  }

  if (leftDelta == null && rightDelta == null) return null;
  if (leftDelta == null) return rightDelta;
  if (rightDelta == null) return leftDelta;
  return (leftDelta + rightDelta) / 2.0; // average of both sides
}
```

---

SECTION D: State Machine 2 — Jumping Jacks

State variables:
```dart
enum _JumpingJackState { armsDown, armsUp }
_JumpingJackState _jackState = _JumpingJackState.armsDown;
final _LandmarkBuffer _jackLeftBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
final _LandmarkBuffer _jackRightBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
```

Implementation:
```dart
void _processJumpingJack(Pose pose) {
  final leftMetric = _computeJackMetric(
    pose, PoseLandmarkType.leftWrist, PoseLandmarkType.leftShoulder);
  final rightMetric = _computeJackMetric(
    pose, PoseLandmarkType.rightWrist, PoseLandmarkType.rightShoulder);

  if (leftMetric == null || rightMetric == null) return;

  _jackLeftBuffer.add(leftMetric);
  _jackRightBuffer.add(rightMetric);

  if (!_jackLeftBuffer.isFull || !_jackRightBuffer.isFull) return;

  final leftSmoothed = _jackLeftBuffer.average;
  final rightSmoothed = _jackRightBuffer.average;

  switch (_jackState) {
    case _JumpingJackState.armsDown:
      // Arms raise: wrist goes ABOVE shoulder
      // In image space, y decreases upward, so raised wrist has smaller y than shoulder
      // leftMetric = shoulder.y - wrist.y — positive means wrist is above shoulder
      if (leftSmoothed > kJumpingJackWristRaiseThreshold &&
          rightSmoothed > kJumpingJackWristRaiseThreshold) {
        _jackState = _JumpingJackState.armsUp;
        debugPrint('[RepDetector] Jumping Jack UP detected');
      }
      break;

    case _JumpingJackState.armsUp:
      // Arms return down: wrist drops back below shoulder
      if (leftSmoothed <= 0 && rightSmoothed <= 0) {
        _jackState = _JumpingJackState.armsDown;
        _emitRep();
      }
      break;
  }
}

double? _computeJackMetric(Pose pose, PoseLandmarkType wristType, PoseLandmarkType shoulderType) {
  final wrist = pose.landmarks[wristType];
  final shoulder = pose.landmarks[shoulderType];

  if (wrist == null || shoulder == null) return null;
  if (wrist.likelihood < kLandmarkLikelihoodThreshold) return null;
  if (shoulder.likelihood < kLandmarkLikelihoodThreshold) return null;

  // shoulder.y - wrist.y:
  // Positive = wrist is higher than shoulder (arms raised)
  // Zero or negative = wrist at or below shoulder (arms down)
  return shoulder.y - wrist.y;
}
```

---

SECTION E: State Machine 3 — Side Oblique Crunches

State variables:
```dart
enum _CrunchState { extended, leftCrunchDown, rightCrunchDown }
_CrunchState _crunchState = _CrunchState.extended;
final _LandmarkBuffer _crunchLeftBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
final _LandmarkBuffer _crunchRightBuffer = _LandmarkBuffer(kLandmarkBufferWindowSize);
```

Implementation:
```dart
void _processObliqueCrunch(Pose pose) {
  final leftDist = _computeCrunchDistance(
    pose, PoseLandmarkType.leftWrist, PoseLandmarkType.leftHip);
  final rightDist = _computeCrunchDistance(
    pose, PoseLandmarkType.rightWrist, PoseLandmarkType.rightHip);

  if (leftDist != null) _crunchLeftBuffer.add(leftDist);
  if (rightDist != null) _crunchRightBuffer.add(rightDist);

  if (!_crunchLeftBuffer.isFull || !_crunchRightBuffer.isFull) return;

  final leftSmoothed = _crunchLeftBuffer.average;
  final rightSmoothed = _crunchRightBuffer.average;

  switch (_crunchState) {
    case _CrunchState.extended:
      // Detect crunch: wrist gets close to same-side hip
      if (leftSmoothed < kCrunchWristHipProximityThreshold) {
        _crunchState = _CrunchState.leftCrunchDown;
        debugPrint('[RepDetector] Left crunch DOWN');
      } else if (rightSmoothed < kCrunchWristHipProximityThreshold) {
        _crunchState = _CrunchState.rightCrunchDown;
        debugPrint('[RepDetector] Right crunch DOWN');
      }
      break;

    case _CrunchState.leftCrunchDown:
      // The 1.5x multiplier creates hysteresis — prevents oscillation
      // at the threshold boundary from causing rapid false reps
      if (leftSmoothed > kCrunchWristHipProximityThreshold * 1.5) {
        _crunchState = _CrunchState.extended;
        _emitRep();
      }
      break;

    case _CrunchState.rightCrunchDown:
      if (rightSmoothed > kCrunchWristHipProximityThreshold * 1.5) {
        _crunchState = _CrunchState.extended;
        _emitRep();
      }
      break;
  }
}

double? _computeCrunchDistance(Pose pose, PoseLandmarkType wristType, PoseLandmarkType hipType) {
  final wrist = pose.landmarks[wristType];
  final hip = pose.landmarks[hipType];

  if (wrist == null || hip == null) return null;
  if (wrist.likelihood < kLandmarkLikelihoodThreshold) return null;
  if (hip.likelihood < kLandmarkLikelihoodThreshold) return null;

  // Euclidean distance in normalized coordinate space
  final dx = wrist.x - hip.x;
  final dy = wrist.y - hip.y;
  return math.sqrt(dx * dx + dy * dy);
}
```
Add: import 'dart:math' as math; at the top of the file.

---

Also expose a reset() method on RepDetector:
```dart
void reset() {
  _squatState = _SquatState.standing;
  _jackState = _JumpingJackState.armsDown;
  _crunchState = _CrunchState.extended;
  _squatBuffer.clear();
  _jackLeftBuffer.clear();
  _jackRightBuffer.clear();
  _crunchLeftBuffer.clear();
  _crunchRightBuffer.clear();
  debugPrint('[RepDetector] State reset');
}
```
GameController will call this at the start of each round.

---

UPDATE CameraTestScreen to wire up rep detection:
1. Create a RepDetector(workoutType: WorkoutType.squats, poseStream: poseDetectorService.poseStream)
   (hardcode squats for now, we will make it configurable in Milestone 2)
2. Listen to repDetector.repStream and increment a _repCount state variable
3. Show a large Text overlay on screen: "REPS: $_repCount"
   Style it in gold color, large font, positioned at the bottom center
4. Dispose repDetector in dispose()

After deploying, perform 5 deliberate squats in front of the phone.
You should see the REPS counter increment exactly 5 times.
The debugPrint logs should show:
  [RepDetector] Squat DOWN detected ...
  [RepDetector] REP DETECTED — WorkoutType.squats
  ... (5 times)

Then change the workoutType to WorkoutType.jumpingJacks, hot restart,
and test 5 jumping jacks. Verify 5 reps counted.
Then test WorkoutType.obliqueCrunches.

Report:
1. Squats: correct rep count? Y/N. Any false positives?
2. Jumping Jacks: correct rep count? Y/N. Any false positives?
3. Crunches: correct rep count? Y/N. Any false positives?
4. If counts are wrong, report what you observe (e.g., "fires twice per squat",
   "doesn't fire at all", "fires randomly without movement")

DO NOT proceed to Prompt 5 until all three exercises count correctly.
If thresholds need tuning, tell me what you observe and I will adjust the
threshold constants accordingly.
```

**Verify:** All three exercises count reps correctly. No ghost reps. No missed reps. Test each exercise at least 10 reps. If thresholds need tuning, adjust `constants.dart` and re-test.

---

## M1 — Prompt 5: Pace Monitor

```
Milestone 1, Prompt 5: Pace Monitor.

All three rep detectors work correctly on the device.

---

FILE: lib/features/motion/pace_monitor.dart

Create a PaceMonitor class that enforces the 3-second pace rule.

This class watches for pace violations: if the player goes more than
kPaceThresholdSeconds without completing a rep during an active round,
it emits a paceFailed event.

CRITICAL DESIGN RULE: PaceMonitor is passive. It does not know about
rounds, game state, or lives. It simply runs a timer and reacts to two
inputs: start/stop commands from GameController, and rep notifications
from RepDetector (via GameController). It emits events. It is not
responsible for what happens when those events are received.

```dart
import 'dart:async';
import 'package:flutter/foundation.dart';
import '../core/constants.dart';
import '../core/events.dart';
import '../core/enums.dart';

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
```

---

UPDATE CameraTestScreen for pace testing:
Add a PaceMonitor to the test screen.

Wire it up as follows:
1. Create PaceMonitor instance
2. When a RepEvent is received:
   - If it's the first rep (repCount was 0 before this), call paceMonitor.startMonitoring()
   - Then call paceMonitor.onRepReceived()
3. Listen to paceMonitor.paceStream:
   - On PaceEventType.repOnTime: show "PACE: OK" in green
   - On PaceEventType.paceFailed: show "PACE: FAIL ⚠" in red, increment a _paceFailCount
4. Add a reset button (floating action button) that:
   - Resets _repCount to 0
   - Calls paceMonitor.stopMonitoring()
   - Calls repDetector.reset()
5. Dispose paceMonitor in dispose()

After deploying:
Test 1 — Normal pace: Do 5 squats with < 3 seconds between each.
Expected: PACE: OK shown after each rep. No FAIL events.

Test 2 — Pace violation: Do 1 squat, then wait 4+ seconds without moving.
Expected: After ~3 seconds, PACE: FAIL appears.

Test 3 — Recovery: Do 1 squat, wait 4 seconds (fail), then do another squat.
Expected: FAIL fires at 3s, then PACE: OK fires when the squat is detected.
The monitor should keep running after a failure, not stop.

Report the results of all three tests.
```

**Verify:** All three pace tests pass. Monitor fires correctly. Recovers after a failure. Stops cleanly when stop is called.

---

## M1 — Prompt 6: Milestone 1 Wrap-Up and Camera Permission

```
Milestone 1, Prompt 6: Camera Runtime Permission and Milestone Cleanup.

All motion pipeline components are built and tested. Before closing Milestone 1,
we need two things: runtime camera permission handling, and cleanup.

---

TASK 1: Runtime Camera Permission

On Android 14, declaring permissions in AndroidManifest.xml is not enough.
The app must request the CAMERA permission at runtime before calling
CameraService.initialize().

Update CameraTestScreen (and later GameScreen) to request the permission
on first launch:

```dart
import 'package:permission_handler/permission_handler.dart';

Future<bool> _requestCameraPermission() async {
  final status = await Permission.camera.request();
  if (status.isGranted) return true;
  if (status.isPermanentlyDenied) {
    // User has permanently denied — direct them to settings
    await openAppSettings();
    return false;
  }
  return false;
}
```

In CameraTestScreen's initState, call _requestCameraPermission() BEFORE
calling cameraService.initialize(). If permission is denied, show a
Scaffold with a message explaining that camera access is required.

---

TASK 2: Milestone 1 Final Cleanup

Now that we have confirmed all three exercises work on the physical device:

1. Move the CameraTestScreen into a proper file:
   lib/features/screens/game_screen.dart
   (We will replace its contents entirely in Milestone 2, but the
   camera + pose + rep + pace wiring can live here as a starting point)

2. Remove the inline _StubScreen and _CameraTestScreen from app.dart.
   Replace with proper imports pointing to their real files.
   Any screen that does not have a real file yet should use a simple
   stub Scaffold in its own file under lib/features/screens/.

3. Create stub files for all screens that don't exist yet:
   - lib/features/screens/splash_screen.dart
   - lib/features/screens/home_screen.dart
   - lib/features/screens/workout_select_screen.dart
   - lib/features/screens/results_screen.dart
   - lib/features/screens/leaderboard_screen.dart
   - lib/features/screens/stats_screen.dart
   Each stub: a Scaffold with AppTheme.midnightNavy background and a
   centered Text with the screen name in AppTheme.gold.

4. Run flutter analyze — zero errors required before closing Milestone 1.

5. Do a final end-to-end test on the Tecno:
   - App launches
   - Camera permission requested and granted
   - Camera feed visible
   - Stand in front of phone — green dots appear on body
   - Do 10 squats — rep counter reaches 10
   - Stop for 3+ seconds — PACE FAIL fires
   - All working: commit everything

6. Git commit:
   git add .
   git commit -m "feat: Milestone 1 complete — camera, pose detection, rep detection, pace monitor"
   git push

Update WINDSURF_HANDOFF.md Current Status section to reflect:
- Milestone 1 is COMPLETE
- All motion pipeline files exist and are tested
- List the exact files created
- Note any threshold values that were adjusted during testing
```

**Verify:** `flutter analyze` is clean. All three exercises count correctly. Pace monitor fires at 3 seconds. Camera permission is requested properly. Everything committed and pushed. **Milestone 1 is done.**

---
---

# MILESTONE 2 — Core Game Loop

**Goal:** A fully playable 10-round game session. Reps hit the monster. Pace failures cost lives. Win and lose conditions trigger. Cooldown between rounds works. The whole thing runs on top of the camera feed.

**Done when:** You can select a workout, play all 10 rounds to victory on the Tecno, or intentionally lose all 3 lives, and the correct screen appears afterward. Every mechanic from CONTEXT.md section 4 must work.

---

## M2 — Prompt 1: GameSession Data Class and Game Screen Shell

```
Milestone 2, Prompt 1: GameSession and GameScreen Shell.

Before building the Flame game, we need the data structures and the screen
that will host it.

---

FILE: lib/features/game/game_session.dart

An immutable data class that holds the result of a completed game session.
This is created at session end and passed to ResultsScreen and then to
Firebase (if signed in).

```dart
import '../../core/enums.dart';

class GameSession {
  final WorkoutType workoutType;
  final DateTime completedAt;
  final bool won;
  final int totalReps;
  final int totalTimeSeconds;     // wall-clock seconds from session start to end
  final int roundsCompleted;      // 0–10
  final double bestRepPaceSeconds;  // fastest single rep interval this session
  final double avgRepPaceSeconds;   // average of all rep intervals
  final int livesLost;            // 0–3

  const GameSession({
    required this.workoutType,
    required this.completedAt,
    required this.won,
    required this.totalReps,
    required this.totalTimeSeconds,
    required this.roundsCompleted,
    required this.bestRepPaceSeconds,
    required this.avgRepPaceSeconds,
    required this.livesLost,
  });

  Map<String, dynamic> toFirestore() => {
    'workoutType': workoutType.firestoreKey,
    'completedAt': completedAt.toIso8601String(),
    'won': won,
    'totalReps': totalReps,
    'totalTimeSeconds': totalTimeSeconds,
    'roundsCompleted': roundsCompleted,
    'bestRepPaceSeconds': bestRepPaceSeconds,
    'avgRepPaceSeconds': avgRepPaceSeconds,
    'livesLost': livesLost,
  };
}
```

---

FILE: lib/features/screens/workout_select_screen.dart

The screen where the player selects which exercise to do this session.

Replace the stub with:
- Scaffold with AppTheme.midnightNavy background
- Title: "Choose Your Battle" in AppTheme.gold, Cinzel font, large
- Three large tappable cards, one per workout type
  - Each card shows: the workout name (displayName), a simple icon
    (use Flutter's built-in Icons: fitness_center for squats,
    directions_run for jumping jacks, accessibility for crunches),
    and a brief description of what to do
  - Card style: rounded corners, AppTheme.royalBlue background,
    AppTheme.gold border
  - On tap: navigate to '/game' passing the WorkoutType as a route argument:
    Navigator.pushNamed(context, '/game', arguments: workoutType)

---

UPDATE: lib/features/screens/game_screen.dart

Replace the current CameraTestScreen content with a proper GameScreen shell.

GameScreen receives a WorkoutType from route arguments:
```dart
final workoutType = ModalRoute.of(context)!.settings.arguments as WorkoutType;
```

For now (before Flame is added), GameScreen should:
1. Show the camera feed + pose overlay (reuse from Milestone 1 work)
2. Display a "LOADING GAME..." text overlay while the camera initializes
3. Request camera permission in initState before initializing CameraService
4. Wire up CameraService → PoseDetectorService → RepDetector → PaceMonitor
   (same wiring as the test screen, but now using the passed workoutType)
5. Show a temporary HUD overlay: just Text showing the current rep count,
   lives remaining (hardcoded to 3 for now), and current round (hardcoded to 1)
6. This screen is a placeholder that Prompt 2 will flesh out with Flame

After creating these files, run flutter analyze and fix all errors.
Then update app.dart routes and home screen to navigate to workout select.

The flow to test: Home → tap Play → WorkoutSelectScreen → tap Squats →
GameScreen shows camera feed with rep counter.
```

---

## M2 — Prompt 2: FitFusionGame — The Flame Game

```
Milestone 2, Prompt 2: FitFusionGame — FlameGame core.

This is the largest single file in the project. Read every section before
writing. The entire game state machine lives here.

---

FILE: lib/features/game/fitfusion_game.dart

FitFusionGame extends FlameGame.

CRITICAL: The game background must be transparent so the camera feed
shows through. Set:
```dart
@override
Color backgroundColor() => const Color(0x00000000); // fully transparent
```

---

STATE VARIABLES:
```dart
// Configuration (set before game starts)
WorkoutType _workoutType = WorkoutType.squats;

// Game state machine
GamePhase _phase = GamePhase.waitingForFirstRep;

// Round tracking
int _currentRound = 0;          // 0-indexed internally, displayed as 1-indexed
int _monsterMaxHealth = 0;
int _monsterCurrentHealth = 0;

// Lives
int _livesRemaining = kStartingLives;

// Session statistics (accumulated throughout the session)
DateTime? _sessionStartTime;
int _totalReps = 0;
int _livesLost = 0;
final List<double> _repIntervals = [];  // seconds between consecutive reps
DateTime? _lastRepTime;

// Cooldown
Timer? _cooldownTimer;
```

---

PUBLIC API (called by GameController):
```dart
/// Called before the game starts. Must be called before the FlameGame is mounted.
void configure({required WorkoutType workoutType}) {
  _workoutType = workoutType;
}

/// Called when a rep is detected by RepDetector (via GameController).
void onRepDetected() {
  if (_phase != GamePhase.waitingForFirstRep && _phase != GamePhase.playing) return;

  // Record timing
  final now = DateTime.now();
  if (_lastRepTime != null) {
    final interval = now.difference(_lastRepTime!).inMilliseconds / 1000.0;
    _repIntervals.add(interval);
  }
  _lastRepTime = now;

  // Transition from waiting to playing on first rep
  if (_phase == GamePhase.waitingForFirstRep) {
    _phase = GamePhase.playing;
    _onFirstRepOfRound();
  }

  _totalReps++;
  _monsterCurrentHealth--;
  _onRepHitRegistered();

  if (_monsterCurrentHealth <= 0) {
    _onRoundWon();
  }
}

/// Called when the pace monitor emits a paceFailed event (via GameController).
void onPaceFailed() {
  if (_phase != GamePhase.playing) return;
  _livesLost++;
  _livesRemaining--;
  _onLifeLost();

  if (_livesRemaining <= 0) {
    _onDefeat();
  }
}
```

---

GAME FLOW METHODS:

```dart
@override
Future<void> onLoad() async {
  await super.onLoad();
  _startSession();
}

void _startSession() {
  _sessionStartTime = DateTime.now();
  _currentRound = 0;
  _livesRemaining = kStartingLives;
  _livesLost = 0;
  _totalReps = 0;
  _repIntervals.clear();
  _loadRound(_currentRound);
}

void _loadRound(int roundIndex) {
  // roundIndex is 0-based. Round 1 = index 0.
  _currentRound = roundIndex;
  _monsterMaxHealth = repsRequiredForRound(roundIndex + 1); // +1 for 1-indexed formula
  _monsterCurrentHealth = _monsterMaxHealth;
  _phase = GamePhase.waitingForFirstRep;
  _lastRepTime = null;
  debugPrint('[Game] Round ${roundIndex + 1} loaded. Need $_monsterMaxHealth reps.');
  _onRoundLoaded();
}

void _onFirstRepOfRound() {
  // Notify GameController to start the pace monitor
  onFirstRepCallback?.call();
}

void _onRepHitRegistered() {
  // Update visual components
  _healthBarComponent?.updateHealth(_monsterCurrentHealth, _monsterMaxHealth);
  _repProgressComponent?.updateReps(_totalRepsThisRound, _monsterMaxHealth);
  // Spawn damage number
  _spawnDamageNumber();
  debugPrint('[Game] Rep hit. Monster HP: $_monsterCurrentHealth/$_monsterMaxHealth');
}

void _onRoundWon() {
  _phase = GamePhase.cooldown;
  debugPrint('[Game] Round ${_currentRound + 1} WON');
  // Notify GameController to stop pace monitor
  onRoundWonCallback?.call();
  // Start cooldown
  _startCooldown();
}

void _startCooldown() {
  _cooldownOverlayComponent?.show(kCooldownSeconds);
  _cooldownTimer = Timer(Duration(seconds: kCooldownSeconds), _onCooldownComplete);
}

void _onCooldownComplete() {
  _cooldownTimer = null;
  final nextRoundIndex = _currentRound + 1;
  if (nextRoundIndex >= kTotalRounds) {
    _onVictory();
  } else {
    _loadRound(nextRoundIndex);
    onCooldownCompleteCallback?.call(); // tell GameController to reset repDetector
  }
}

void _onLifeLost() {
  debugPrint('[Game] Life lost. Lives remaining: $_livesRemaining');
  _livesDisplayComponent?.updateLives(_livesRemaining);
  // Visual feedback — flash screen red briefly
  _flashDamage();
}

void _onVictory() {
  _phase = GamePhase.victory;
  debugPrint('[Game] VICTORY');
  _cooldownTimer?.cancel();
  onSessionEndCallback?.call(_buildSession(won: true));
}

void _onDefeat() {
  _phase = GamePhase.defeat;
  debugPrint('[Game] DEFEAT');
  _cooldownTimer?.cancel();
  onSessionEndCallback?.call(_buildSession(won: false));
}
```

---

CALLBACKS (used by GameController to hook into game events):
```dart
VoidCallback? onFirstRepCallback;      // game wants pace monitor started
VoidCallback? onRoundWonCallback;      // game wants pace monitor stopped
VoidCallback? onCooldownCompleteCallback; // game wants rep detector reset
void Function(GameSession)? onSessionEndCallback; // game ended, here's the result
```

---

SESSION RESULT BUILDER:
```dart
GameSession _buildSession({required bool won}) {
  final now = DateTime.now();
  final totalSeconds = _sessionStartTime != null
      ? now.difference(_sessionStartTime!).inSeconds : 0;

  final avgPace = _repIntervals.isEmpty
      ? 0.0
      : _repIntervals.reduce((a, b) => a + b) / _repIntervals.length;

  final bestPace = _repIntervals.isEmpty
      ? 0.0
      : _repIntervals.reduce((a, b) => a < b ? a : b);

  return GameSession(
    workoutType: _workoutType,
    completedAt: now,
    won: won,
    totalReps: _totalReps,
    totalTimeSeconds: totalSeconds,
    roundsCompleted: won ? kTotalRounds : _currentRound,
    bestRepPaceSeconds: bestPace,
    avgRepPaceSeconds: avgPace,
    livesLost: _livesLost,
  );
}
```

---

COMPONENT REFERENCES (will be populated in Prompt 3 when components are created):
```dart
// These will be non-null once onLoad adds the components
MonsterHealthBarComponent? _healthBarComponent;
PlayerLivesDisplayComponent? _livesDisplayComponent;
RepProgressBarComponent? _repProgressComponent;
CooldownOverlayComponent? _cooldownOverlayComponent;
int get _totalRepsThisRound => _monsterMaxHealth - _monsterCurrentHealth;

void _spawnDamageNumber() {
  // Placeholder — will add DamageNumberComponent in Prompt 3
  debugPrint('[Game] +1 damage');
}

void _flashDamage() {
  // Placeholder — will add screen flash in Prompt 3
  debugPrint('[Game] Flash damage');
}

void _onRoundLoaded() {
  // Placeholder — will update MonsterComponent in Prompt 3
}
```

After creating this file, run flutter analyze. There will be errors
for missing component types — that is expected. We will fix those in Prompt 3.
For now, comment out the component reference lines so it compiles cleanly.
```

---

## M2 — Prompt 3: Flame Components

```
Milestone 2, Prompt 3: All Flame Game Components.

FitFusionGame exists but its visual components are commented out.
Now we build them all.

Create each component as its own file under lib/features/game/components/.

---

FILE: components/monster_health_bar_component.dart

A PositionComponent that renders a styled health bar.

Properties:
- int currentHealth, int maxHealth
- Size of the bar: width = 250, height = 20
- Positioned at: center-top of game canvas, below the monster sprite area

Visual:
- Background: dark red rectangle (Color(0xFF4A0000))
- Fill: bright red rectangle, width proportional to currentHealth/maxHealth
- Gold border: draw a rectangle stroke over the whole bar
- Small "HP" text label to the left

void updateHealth(int current, int max):
  - Updates currentHealth and maxHealth
  - Triggers visual refresh

---

FILE: components/player_lives_display_component.dart

A PositionComponent showing 3 heart icons.

Properties: int lives (starts at kStartingLives)

Visual:
- Render 3 heart shapes in a row
- Filled heart (gold, Color(0xFFFFD700)) for each remaining life
- Empty heart outline (grey, Color(0xFF555555)) for each lost life
- Size: 24x24 per heart, 8px gap between
- Positioned: top-right of canvas

void updateLives(int remaining):
  - Updates lives count and redraws

Draw hearts using the Path API or using a ♥ character TextComponent —
TextComponent is simpler for MVP: use three TextComponents with "♥" character,
color them gold (alive) or grey (lost).

---

FILE: components/round_banner_component.dart

A TextComponent subclass showing "ROUND X / 10".

Properties: int currentRound (1-indexed)
- Positioned: top-left of canvas
- Font: large, gold color
- Update via updateRound(int round)

---

FILE: components/rep_progress_bar_component.dart

Shows rep progress this round: "REPS: X / Y" plus a visual progress bar.

Properties: int currentReps, int requiredReps
- Positioned: bottom center of canvas
- Text: "WORKOUT_NAME — REP currentReps / requiredReps"
- Progress bar: same style as health bar but green fill
- void updateReps(int current, int required)

---

FILE: components/damage_number_component.dart

A short-lived floating text component that shows "+1" when a rep lands.

Behavior:
- Spawns at the monster's position (center of canvas, slightly above center)
- Moves upward at constant velocity over 1 second
- Fades out (opacity decreases from 1.0 to 0.0) over 1 second
- Removes itself from the game after 1 second
- Text: "+1" in bright gold, large font (28pt)

Implementation:
- Extends TextComponent
- Override update(double dt):
    position.y -= 80 * dt; // move up 80 pixels per second
    // fade: decrease alpha over 1 second
    _elapsed += dt;
    final opacity = (1.0 - _elapsed).clamp(0.0, 1.0);
    textRenderer = TextPaint(style: TextStyle(
      color: AppTheme.brightGold.withOpacity(opacity),
      fontSize: 28,
      fontWeight: FontWeight.bold,
    ));
    if (_elapsed >= 1.0) removeFromParent();

---

FILE: components/cooldown_overlay_component.dart

A full-canvas overlay shown during the cooldown period between rounds.

Properties: int secondsRemaining

Visual:
- Semi-transparent dark overlay: Color(0x99000000) covering full canvas
- Large centered text: "REST" or "PREPARE" 
- Countdown: "Next round in: X" updating each second
- When called with show(int seconds), start a 1-second repeating timer
  that decrements the display count. Hide (removeFromParent or set opacity 0)
  when count reaches 0.
- The actual cooldown timing is controlled by FitFusionGame's _cooldownTimer —
  this component just displays the countdown visually.

void show(int seconds): makes the overlay visible, starts display countdown
void hide(): hides the overlay

---

FILE: components/pace_timer_indicator_component.dart

A small urgency indicator that shows the player how much of the 3-second
pace window remains.

Visual:
- A thin horizontal bar at the very bottom edge of the screen
- Starts full width (gold) after each rep
- Drains to zero width over kPaceThresholdSeconds seconds
- When empty: turns red briefly before resetting on next rep or pace failure
- Width = canvasSize.x * (timeRemaining / kPaceThresholdSeconds)

void onRepDetected(): resets the timer to full
void onPaceFailed(): briefly flash red
In update(double dt): decrements the internal timer

---

FILE: components/monster_component.dart

A SpriteComponent that represents the current round's monster.

For MVP (before real sprites are sourced), use a colored rectangle with
the monster's name as a text label. This placeholder will be replaced with
real sprites in Milestone 4.

Properties: int roundIndex (0–9)
- Color: get progressively darker red as round increases
- Text label: a sequence of placeholder names:
  ["Slime", "Goblin", "Orc", "Skeleton", "Dark Knight",
   "Mage", "Necromancer", "Giant", "Titan", "Dragon"]
- Size: 120x120 pixels
- Positioned: upper center of canvas (approximately 30% down from top)

void playHitAnimation():
  - Flash the component white briefly (tint to white, then back)
  - Duration: 0.15 seconds
  - Simple implementation: override update, track _hitTimer, if active
    set paint.colorFilter = white, else remove filter

void loadForRound(int roundIndex): updates to the correct monster for the round

---

After creating all component files, update fitfusion_game.dart:
- Uncomment the component reference lines
- In onLoad(), add all components to the game:
    _monsterComponent = MonsterComponent();
    add(_monsterComponent!);
    _healthBarComponent = MonsterHealthBarComponent();
    add(_healthBarComponent!);
    ... (all components)
- Wire the callbacks from onRepDetected to call monsterComponent.playHitAnimation()
- Wire onRoundLoaded to call monsterComponent.loadForRound(_currentRound)
- Wire _spawnDamageNumber to add(DamageNumberComponent(position: ...))

Run flutter analyze. Fix all errors. Deploy to device and run.
Navigate through WorkoutSelect → GameScreen.
You should see: camera feed visible, placeholder monster rectangle in center,
health bar, round indicator, rep counter. Do reps — health bar should decrease.
```

---

## M2 — Prompt 4: GameController and Full Wiring

```
Milestone 2, Prompt 4: GameController — Wiring the Motion Pipeline to the Game.

All components exist. Now we wire everything together through GameController.

---

FILE: lib/features/game/game_controller.dart

GameController is the bridge between the motion pipeline and FitFusionGame.
It knows about both sides. It translates events from one into commands on the other.

```dart
class GameController {
  final FitFusionGame game;
  final RepDetector repDetector;
  final PaceMonitor paceMonitor;

  StreamSubscription<RepEvent>? _repSubscription;
  StreamSubscription<PaceEvent>? _paceSubscription;

  GameController({
    required this.game,
    required this.repDetector,
    required this.paceMonitor,
  }) {
    _wireCallbacks();
    _wireStreams();
  }

  void _wireCallbacks() {
    // FitFusionGame tells GameController when to start/stop the pace monitor
    game.onFirstRepCallback = () {
      paceMonitor.startMonitoring();
    };

    game.onRoundWonCallback = () {
      paceMonitor.stopMonitoring();
    };

    game.onCooldownCompleteCallback = () {
      repDetector.reset();
      // Note: do NOT call paceMonitor.startMonitoring() here —
      // the pace monitor only starts after the first rep of the new round
    };
  }

  void _wireStreams() {
    _repSubscription = repDetector.repStream.listen(_onRepEvent);
    _paceSubscription = paceMonitor.paceStream.listen(_onPaceEvent);
  }

  void _onRepEvent(RepEvent event) {
    paceMonitor.onRepReceived(); // always notify pace monitor first
    game.onRepDetected();         // then notify the game
  }

  void _onPaceEvent(PaceEvent event) {
    if (event.type == PaceEventType.paceFailed) {
      game.onPaceFailed();
    }
    // repOnTime events are handled by pace indicator component directly
    // via a separate stream listener in GameScreen
  }

  Future<void> dispose() async {
    await _repSubscription?.cancel();
    await _paceSubscription?.cancel();
  }
}
```

---

UPDATE: lib/features/screens/game_screen.dart

Rebuild GameScreen to use GameController and FitFusionGame properly.

GameScreen is a StatefulWidget that:
1. Receives WorkoutType from route arguments
2. In initState:
   a. Requests camera permission
   b. Creates and initializes CameraService
   c. Creates PoseDetectorService
   d. Starts pose processing: poseDetectorService.startProcessing(...)
   e. Creates RepDetector(workoutType: workoutType, poseStream: ...)
   f. Creates PaceMonitor
   g. Creates FitFusionGame()
   h. Calls game.configure(workoutType: workoutType)
   i. Creates GameController(game: game, repDetector: ..., paceMonitor: ...)
   j. Sets game.onSessionEndCallback = _onSessionEnd

3. build() returns:
   ```dart
   Scaffold(
     body: Stack(
       children: [
         // Layer 1: Camera feed (fills screen)
         CameraPreviewWidget(controller: cameraService.controller),

         // Layer 2: Pose skeleton (debug mode only)
         if (kDebugMode)
           StreamBuilder<Pose?>(
             stream: poseDetectorService.poseStream,
             builder: (context, snapshot) => PoseOverlayWidget(
               pose: snapshot.data,
               imageSize: const Size(640, 480),
             ),
           ),

         // Layer 3: Flame game (transparent background)
         GameWidget(game: fitFusionGame),
       ],
     ),
   );
   ```

4. _onSessionEnd(GameSession session):
   ```dart
   void _onSessionEnd(GameSession session) {
     Navigator.pushReplacementNamed(
       context,
       '/results',
       arguments: session,
     );
   }
   ```

5. dispose() must dispose in reverse order:
   gameController.dispose();
   paceMonitor.dispose();
   repDetector.dispose();
   poseDetectorService.dispose();
   cameraService.dispose();
   fitFusionGame.detach(); // Flame cleanup

---

UPDATE: lib/features/screens/results_screen.dart

Replace the stub with a real ResultsScreen:
- Receives GameSession from route arguments
- Shows: won/lost banner, total reps, time taken, rounds completed, lives lost
- Two buttons: "Play Again" (→ '/select') and "Home" (→ '/home')
- Style with AppTheme colors and Cinzel font
- No Firebase calls yet — just display the data

---

UPDATE: lib/features/screens/home_screen.dart

Replace the stub with a basic HomeScreen:
- "FitFusion" title in large gold Cinzel font
- "PLAY" button that navigates to '/select'
- Placeholder "LEADERBOARD" and "STATS" buttons (navigate to their stub screens)
- Style with midnight navy background, gold accents

After all updates, run flutter analyze, deploy to device, and test the
complete game loop end-to-end:

TEST 1 — Full victory:
Select Squats → complete all 10 rounds (65 reps total) → Victory screen appears.

TEST 2 — Defeat by pace:
Select Jumping Jacks → start round → stop moving → lose all 3 lives → Defeat screen.

TEST 3 — Results:
After any session, results screen shows correct numbers. "Play Again" returns
to workout select. "Home" returns to home screen.

All three tests must pass before closing Milestone 2.
Commit: "feat: Milestone 2 complete — core game loop, all mechanics working"
Update WINDSURF_HANDOFF.md current status.
```

---
---

# MILESTONE 3 — Firebase Integration

**Goal:** Sign-in works. Session data saved to Firestore. Leaderboard shows real data. Stats show real data.

**Done when:** You can sign in with a real Google account, play a session, open the Firestore console, and see the written data. Leaderboard and stats display actual results.

---

## M3 — Prompt 1: Auth Service and Provider

```
Milestone 3, Prompt 1: AuthService and AuthProvider.

---

FILE: lib/features/auth/auth_service.dart

```dart
class AuthService {
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

  User? get currentUser => _auth.currentUser;
  bool get isSignedIn => currentUser != null;
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  Future<UserCredential?> signInWithGoogle() async {
    try {
      final googleUser = await _googleSignIn.signIn();
      if (googleUser == null) return null; // user cancelled

      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      final userCredential = await _auth.signInWithCredential(credential);

      // Create Firestore user document if first sign-in
      if (userCredential.additionalUserInfo?.isNewUser == true) {
        await FirestoreService().createUserDocument(userCredential.user!);
      }

      return userCredential;
    } catch (e) {
      debugPrint('[AuthService] Sign-in error: $e');
      return null;
    }
  }

  Future<void> signOut() async {
    try {
      await _googleSignIn.signOut();
      await _auth.signOut();
    } catch (e) {
      debugPrint('[AuthService] Sign-out error: $e');
    }
  }
}
```

---

FILE: lib/features/auth/auth_provider.dart

```dart
class AuthProvider extends ChangeNotifier {
  final AuthService _authService = AuthService();
  User? _user;
  bool _isLoading = false;

  User? get user => _user;
  bool get isSignedIn => _user != null;
  bool get isLoading => _isLoading;

  AuthProvider() {
    _authService.authStateChanges.listen((user) {
      _user = user;
      notifyListeners();
    });
  }

  Future<void> signIn() async {
    _isLoading = true;
    notifyListeners();
    await _authService.signInWithGoogle();
    _isLoading = false;
    notifyListeners();
  }

  Future<void> signOut() async {
    await _authService.signOut();
  }
}
```

Update main.dart to add AuthProvider to the MultiProvider:
```dart
MultiProvider(
  providers: [
    ChangeNotifierProvider(create: (_) => AuthProvider()),
  ],
  child: const FitFusionApp(),
)
```
```

---

## M3 — Prompt 2: Firestore Service

```
Milestone 3, Prompt 2: FirestoreService — all database operations.

---

FILE: lib/features/firebase/firestore_service.dart

All Firestore reads and writes in one class.
Every method is wrapped in try/catch.
Firebase failures must never crash the app.

Implement these methods exactly:

createUserDocument(User user) — writes to /users/{uid}
writeSession(String uid, GameSession session) — writes to /users/{uid}/sessions/{auto-id}
updateStats(String uid, GameSession session) — upserts /users/{uid}/stats/{workoutType}
  For stats update, read the existing document first, then calculate new averages:
  newAvgSessionTime = (oldAvg * oldCount + newValue) / (oldCount + 1)
  Only update bestSessionTimeSeconds if session.won == true and new time is faster.
updateLeaderboard(String uid, String displayName, String? photoUrl, GameSession session)
  - Only call this if session.won == true
  - Update fastest_session only if session.totalTimeSeconds < existing entry
  - Update fastest_pace only if session.bestRepPaceSeconds < existing entry
  - Use Firestore set() with merge: false (overwrite the whole entry)
checkAndUnlockAchievements(String uid, GameSession session) — returns List<AchievementId>
  - Read which achievements the user already has
  - Check each possible achievement against the session data and accumulated stats
  - Return only newly unlocked achievements (not already-owned ones)
  - Write each new achievement to /users/{uid}/achievements/{id}
getLeaderboard(WorkoutType workoutType, LeaderboardType type) — returns List<LeaderboardEntry>
  - Query the appropriate subcollection, order by the metric, limit to kLeaderboardSize
  - Returns an empty list on error (never throws)
getPlayerStats(String uid) — returns Map<WorkoutType, PlayerStats>
  - Reads all three stat documents for the user
  - Returns empty map if none exist

Define LeaderboardEntry and PlayerStats as simple data classes in this file.
```

---

## M3 — Prompt 3: Results Screen Firebase Integration and Leaderboard / Stats Screens

```
Milestone 3, Prompt 3: Wire Firebase to ResultsScreen and build data screens.

UPDATE ResultsScreen:
- In initState, if AuthProvider.isSignedIn:
    1. Call FirestoreService().writeSession(uid, session)
    2. Call FirestoreService().updateStats(uid, session)
    3. If session.won: call FirestoreService().updateLeaderboard(...)
    4. Call FirestoreService().checkAndUnlockAchievements(uid, session)
    5. If new achievements were unlocked, show a brief achievement popup
- Show a loading indicator while Firebase writes are in progress
- Show the results regardless of whether Firebase succeeds or fails

UPDATE HomeScreen:
- Use Consumer<AuthProvider> to show:
    - If signed in: user's displayName and photoUrl, "SIGN OUT" button
    - If not signed in: "SIGN IN WITH GOOGLE" button
- On sign in button tap: call authProvider.signIn()
- On sign out button tap: call authProvider.signOut()

BUILD LeaderboardScreen:
- TabBar with 3 tabs: Squats, Jumping Jacks, Side Oblique Crunches
- Each tab has 2 sub-views: Fastest Session, Fastest Pace
- Use FutureBuilder to load leaderboard data from FirestoreService
- Show a numbered list of top 10 entries with: rank, display name, value
- Highlight the current user's entry if they appear

BUILD StatsScreen:
- If not signed in: prompt to sign in
- If signed in: use FutureBuilder to load stats from FirestoreService
- Show stats in three sections (one per workout type), plus totals
- Display: personal best time, best pace, average time, average pace,
  total rounds, total minutes
- Use AppTheme styling throughout

After building all screens, do end-to-end Firebase test:
1. Sign in with a real Google account on the Tecno
2. Play and win a session
3. Open Firestore console — verify the session document was written correctly
4. Open leaderboard screen — verify your entry appears
5. Open stats screen — verify stats are shown
6. Play another session — verify stats update correctly

Commit: "feat: Milestone 3 complete — Firebase auth, leaderboard, stats all working"
```

---
---

# MILESTONE 4 — Visual Polish

**Goal:** The app looks and feels like a real high-fantasy game.

---

## M4 — Prompt 1: Sprites and Monster Component

```
Milestone 4, Prompt 1: Real monster sprites and visual polish on game components.

Before this prompt, source the following free assets:
- Monster sprites: search itch.io for "free fantasy RPG sprites pixel art"
  Recommended pack: "Monsters Creatures Fantasy" by Luiz Melo (free on itch.io)
  Download PNG sprites for at least 5 distinct monster types.
  Place them in assets/sprites/monsters/

- UI assets: search for "fantasy RPG UI free" or "medieval UI elements"
  You need: health bar frame, heart icon (filled and empty)
  Place in assets/sprites/ui/

- Register all new asset paths in pubspec.yaml under flutter: assets:

---

After downloading assets:

UPDATE MonsterComponent:
- Replace the colored rectangle placeholder with a real Sprite
- Load sprites using await Sprite.load('monsters/goblin_idle.png') etc.
- Map round indices to sprite filenames:
    round 0–1: goblin/slime sprite
    round 2–3: orc/skeleton sprite
    round 4–5: dark knight sprite
    round 6–7: mage sprite
    round 8: giant/titan sprite
    round 9: dragon sprite
- Add a simple idle animation: use SpriteAnimationComponent if the sprite
  sheet has multiple frames, or a gentle scale oscillation if it's a single frame
- playHitAnimation(): flash white tint for 0.15 seconds then restore

UPDATE MonsterHealthBarComponent:
- If you have a health bar frame sprite, render it as decoration around the bar
- If not: style the bar with rounded corners, gold border, dark red background,
  bright red fill using Canvas drawRRect

UPDATE PlayerLivesDisplayComponent:
- If you have heart sprites, use them
- If not: draw hearts using Path API for a clean vector heart shape
  Filled gold heart = alive, hollow grey heart = lost

UPDATE CooldownOverlayComponent:
- Add a brief "ROUND COMPLETE!" text that fades in/out
- Animate the countdown number with a scale pulse each second

After all updates, deploy to device and visually verify the game looks
significantly better than the placeholder version.
```

---

## M4 — Prompt 2: Fantasy UI Theme, Fonts, and Screen Polish

```
Milestone 4, Prompt 2: Apply the full High Fantasy theme to all screens.

---

TASK 1: Google Fonts Integration
Verify google_fonts package is in pubspec.yaml.
In AppTheme.theme, ensure all TextTheme styles use GoogleFonts.cinzel.
For display text (titles), use GoogleFonts.cinzelDecorative.

TASK 2: FantasyButton Widget
Create lib/widgets/fantasy_button.dart
A reusable button styled as a stone/wood plank with gold text:
- Background: a Container with BoxDecoration:
    color: AppTheme.royalBlue
    borderRadius: BorderRadius.circular(4)
    border: Border.all(color: AppTheme.gold, width: 2)
    boxShadow: [glow effect in gold, blurRadius: 8, color: AppTheme.gold.withOpacity(0.3)]
- Text: label in AppTheme.gold, GoogleFonts.cinzel, bold
- On tap: slight scale-down animation (0.95) using AnimatedScale or GestureDetector
- Constructor: FantasyButton({required String label, required VoidCallback onTap, double? width})

Replace all ElevatedButtons and TextButtons throughout the app with FantasyButton.

TASK 3: Screen Backgrounds
All screens should have a dark navy-to-blue gradient background:
BoxDecoration(
  gradient: LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFF0D1B3E), Color(0xFF1A2D5A)],
  ),
)
Wrap each Scaffold body in a Container with this decoration.

TASK 4: Sound Effects
Add flame_audio to pubspec.yaml: flame_audio: ^2.10.0
Source free fantasy sound effects from freesound.org or mixkit.co:
- rep_hit.mp3: a short sword strike or magic hit sound
- round_win.mp3: a short victory fanfare
- life_lost.mp3: a thud or impact sound
- game_win.mp3: a longer victory theme
- game_over.mp3: a defeat sting
Place in assets/audio/

In FitFusionGame, add sound calls:
- onRepDetected: FlameAudio.play('rep_hit.mp3')
- onRoundWon: FlameAudio.play('round_win.mp3')
- onLifeLost: FlameAudio.play('life_lost.mp3')
- onVictory: FlameAudio.play('game_win.mp3')
- onDefeat: FlameAudio.play('game_over.mp3')

Wrap all FlameAudio calls in try/catch — never crash on audio failure.

TASK 5: Polish WorkoutSelectScreen
Replace the plain cards with proper styled panels using the fantasy theme.
Each workout card should have a decorative border and feel like a fantasy menu option.

TASK 6: Remove Debug Overlays
The pose skeleton painter (PoseOverlayWidget) should ONLY render when kDebugMode is true.
Verify this is the case in GameScreen's Stack.
In release builds, the skeleton will not render.

After all polish tasks, do a full visual walkthrough on the device:
Home → WorkoutSelect → Game (play 3 rounds) → Results → Leaderboard → Stats
Every screen should look cohesive and on-theme.
```

---
---

# MILESTONE 5 — Testing and Submission

---

## M5 — Prompt 1: Firestore Security Rules and Final QA

```
Milestone 5, Prompt 1: Firestore security rules and final testing.

TASK 1: Firestore Security Rules
The database is currently in test mode (open access). Before submission,
set proper rules.

Open the Firestore console → Rules tab. Replace the existing rules with:

rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {

    // Users can only read/write their own user document
    match /users/{uid} {
      allow read, write: if request.auth != null && request.auth.uid == uid;

      // Sessions and stats: same — only the owner
      match /sessions/{sessionId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
      match /stats/{workoutType} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
      match /achievements/{achievementId} {
        allow read, write: if request.auth != null && request.auth.uid == uid;
      }
    }

    // Leaderboard: anyone can read, only authenticated users can write their own entry
    match /leaderboard/{workoutType}/fastest_session/{uid} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == uid;
    }
    match /leaderboard/{workoutType}/fastest_pace/{uid} {
      allow read: if true;
      allow write: if request.auth != null && request.auth.uid == uid;
    }
  }
}

Click Publish. Verify the app still works after the rule change.

TASK 2: Final QA Checklist — test every item on the physical device:

EXERCISE DETECTION:
[ ] Squats: 10 reps counted correctly, no phantom reps
[ ] Jumping Jacks: 10 reps counted correctly
[ ] Side Oblique Crunches: 10 reps counted correctly (5 left, 5 right)
[ ] All three exercises tested in realistic lighting conditions

GAME MECHANICS:
[ ] Round 1 requires exactly 2 reps to win
[ ] Round 10 requires exactly 11 reps to win
[ ] Stopping for 3+ seconds causes a life to be lost
[ ] After pace fail, game continues (does not end) if lives remain
[ ] Losing all 3 lives ends the session with defeat screen
[ ] Completing round 10 ends the session with victory screen
[ ] Cooldown (12 seconds) appears between rounds
[ ] Lives do not reset between rounds
[ ] First rep of each round starts the pace timer (not before)

FIREBASE:
[ ] Google Sign-In works on the device
[ ] After win: session document appears in Firestore console
[ ] After win: leaderboard entry appears
[ ] After multiple sessions: stats update correctly
[ ] Leaderboard screen shows top 10 data
[ ] Stats screen shows personal stats
[ ] Guest mode: Firebase writes do NOT happen (verify Firestore console stays empty)
[ ] Sign-out works, returns to guest state

NAVIGATION:
[ ] All navigation paths work without crashes
[ ] Back button behavior is sensible on all screens
[ ] Results screen "Play Again" and "Home" both work

STABILITY:
[ ] App does not crash after 3 full sessions in a row
[ ] App does not crash when phone is rotated (lock to portrait: add to AndroidManifest)
[ ] Camera releases properly when navigating away from game screen

Note any failures. Fix them before proceeding to Prompt 2.
```

---

## M5 — Prompt 2: Lock Orientation and Build Release APK

```
Milestone 5, Prompt 2: Lock to portrait orientation and build the release APK.

TASK 1: Lock Portrait Orientation

In android/app/src/main/AndroidManifest.xml, on the <activity> tag, add:
android:screenOrientation="portrait"

This prevents the camera from going sideways if the user tilts the phone
during a workout, which would break the pose detection coordinate system.

Also add this to main.dart before runApp():
SystemChrome.setPreferredOrientations([DeviceOrientation.portraitUp]);
Import: import 'package:flutter/services.dart';

TASK 2: Release Keystore

Generate a release signing key (required for a properly signed APK):

cd android
keytool -genkey -v -keystore release-key.jks -alias fitfusion -keyalg RSA -keysize 2048 -validity 10000

Answer the prompts. Remember the keystore password and key alias password.

IMPORTANT: Add release-key.jks to .gitignore — never commit a signing key.
echo "android/release-key.jks" >> .gitignore

Create android/key.properties with your signing config:
storePassword=YOUR_STORE_PASSWORD
keyPassword=YOUR_KEY_PASSWORD
keyAlias=fitfusion
storeFile=release-key.jks

Add key.properties to .gitignore too:
echo "android/key.properties" >> .gitignore

Update android/app/build.gradle to use the signing config.
(Follow Flutter's official signing docs exactly for the build.gradle changes)

TASK 3: Register Release SHA-1 in Firebase

After generating the release key, get its SHA-1:
keytool -list -v -keystore android/release-key.jks -alias fitfusion

Copy the SHA1 value. Add it to Firebase Console:
Project Settings → Your Apps → Android App → Add Fingerprint

TASK 4: Build Release APK

flutter build apk --release

The APK will be at:
build/app/outputs/flutter-apk/app-release.apk

TASK 5: Install Release APK on Tecno and Final Smoke Test

adb install build/app/outputs/flutter-apk/app-release.apk

Do a complete demo run-through on the release build:
- Launch app
- Sign in with Google
- Play a full session (any workout, win or lose)
- Check leaderboard and stats
- Sign out
- Play as guest

If all passes, this is your submission build.

TASK 6: Final Commit and Tag

git add .
git commit -m "feat: Milestone 5 complete — release APK, signed, QA passed"
git tag v1.0.0-mvp
git push
git push --tags

Update WINDSURF_HANDOFF.md:
- All milestones marked COMPLETE
- Note the release APK path
- Note the keystore location (local only, not in repo)

FITFUSION MVP IS COMPLETE.
```

---

## Final Note

Every prompt in this document is designed to be pasted verbatim into Windsurf after running the session start ritual. Each prompt is one discrete, testable deliverable. The verification step at the end of each prompt is not optional — it is the gate that lets you proceed. A prompt that deploys but has not been physically tested on the Tecno has not been completed.

When Windsurf produces code that contradicts CONTEXT.md or ARCHITECTURE.md, correct it immediately and explicitly. Say: "This contradicts ARCHITECTURE.md which states [X]. Revise to comply." Windsurf will comply. The documents are your authority. Use them.

Good luck.
