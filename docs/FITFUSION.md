# FITFUSION

**Brief Overview**
- A mobile game for Android.
- A fitness-centered game that gamifies fitness activities.
- Aesthetically High Fantasy-inspired
- Motion Detection using the camera.
- Body is the controller similar to the Xbox Kinect. 
- Game is 2D rendered AR overlays.

---

*---START OF FORMAL PROJECT DETAIL---*

## General Objective:

This study aims to analyze, design, and develop "FitFusion", A platform for immersive fitness realities enhancing engagement through augmented gamification in digital workouts, to promote a meaningful exercise participation. 

### Specific Objectives:

Specifically, the study aims to:

1. Assess the current state of digital workout solutions, particularly:
    1. User engagement
    2. Interaction, and
    3. Retention.
2. Utilize mobile platforms to design interactive and immersive game-centric functionality, including:
    1. Motion-detection as an input data, and
    2. Augmented reality for game rendering.
3. Implement gamification elements to promote platform engagement, such as:
    1. Competitive Leaderboards
    2. Player Statistics
    3. Achievements

## Scope and Limitations

### Scope of the Study

The study focuses on the analysis, design, and development of Fitfusion: A digital platform that incorporates augmented reality (AR) and motion-tracking with interactive gamification elements, to promote meaningful exercise participation.

The scope of the study encompasses the implementation of core functionalities within a mobile-based platform, such as input data from motion detection, immersive game design fronted by AR, tied with gamified elements such as leaderboards, player statistics, and achievements. 

Central to the design of FitFusion is to create a unique solution utilizing smartphones, to primarily use in tandem; performance-sensitive camera-based motion detection as an input source, and visually engaging AR game design feedback to render output.

With all this, the platform will then tie in gamification elements promoting fitness. Competitive elements include ranked leaderboards, game achievements, and player statistics.

### Limitations of the Study

While FitFusion is designed to offer a unique digital platform for exercise enhancing measures in general, the study is limited in a few key areas.

The study is conducted within a specific group of users in mind, primarily the student populace from the University of Cebu Lapu-Lapu and Mandaue. As such, findings may not fully represent the general population in terms of age, physical ability, or access to advanced mobile technology.

The study is limited especially in regards to system design and development. This is largely due to time constraints and technical ability. Compromises and omissions have been made to account for these limitations.

Technical ability and time limits game rendering to 2D AR renders only. 3D rendering is omitted as the current project's limitations.

Complex multiplayer, including both online and local forms are omitted. As such, FitFusion is strictly a single-player game experience. Only a selected amount of workouts are available to perform at a time, so a session of gameplay is limited to only one specific type of exercise at any given moment.

Any sort of complex personalization will be omitted. This would include setting gender, height/weight parameters, BMI, physical build, etc. The system is disregarding such metrics with the platform.

Naturally, performance may vary depending on device compatibility, sensor accuracy, and physical environment, especially for features involving AR interaction and motion tracking. External factors such as lighting, movement, form, precision, and user connectivity are beyond the scope of this study and may affect the overall experience and results.

*---END OF FORMAL PROJECT DETAIL---*

---

# Project Context

**FitFusion** is an Android mobile application that is simultaneously a fitness tool and a 2D augmented reality game. The core concept is simple: the player's physical body is the game controller. To play the game, you must exercise. To exercise effectively, the game must reward you. These two things are inseparable — the exercise IS the gameplay.

The app uses the phone's front-facing camera to detect the player's body movements in real time via Google ML Kit Pose Detection. The game renders as a 2D overlay drawn directly on top of the live camera feed, creating an augmented reality effect. The player sees themselves on screen with game elements — monsters, health bars, HUD — composited as a layer over the camera image. The body is tracked, reps are counted, and those reps drive every game mechanic.

The product must be a functioning, demonstrable MVP delivered within one month. **Every decision in this codebase prioritizes a working, shippable product over architectural perfection.**

## Visual Design Direction

### Theme: High Fantasy
Bright, vibrant, heroic. Think classic JRPG meets Western high fantasy — golden UI frames, glowing spell effects, colorful monster sprites, ornate borders. Reference: Final Fantasy, Might & Magic, early Dragon Quest aesthetic.

NOT: dark/gritty, desaturated, horror, steampunk, sci-fi.

### Color Palette
| Role | Color | Hex |
|------|-------|-----|
| Primary dark | Royal Blue | `#1A237E` |
| Primary accent | Gold | `#FFD700` |
| Secondary | Emerald | `#2E7D32` |
| Danger | Crimson | `#B71C1C` |
| Background | Midnight Navy | `#0D1B3E` |
| UI panel fill | Parchment | `#FFF8E1` |
| Glow / damage | Bright Gold | `#FFEE58` |
| Text on dark | Cream White | `#FFFDE7` |

### Typography
- **Display / headers:** "Cinzel" (Google Fonts) — serif, classical Roman letterform, feels ancient and heroic
- **Body / HUD:** "Cinzel Decorative" or fallback system serif
- Damage numbers: large, bold, gold, floating upward animation

---

# Development

## Technical Constraints

### The Hardware Constraint
**The target device is the Tecno Spark Go 30c (Android 14, budget tier).** Every performance decision is made for this device. If it works on a flagship but lags on the Tecno, the Tecno wins and the code changes.

### Performance Rules
1. ML Kit Pose Detection must not be called on every camera frame. Process **every 2nd frame minimum**; every 3rd frame if the device shows lag.
2. Camera feed input to ML Kit must be **640×480 or lower resolution**. Do not pass full-resolution frames to the detector.
3. Frame processing (ML Kit inference) must run **off the main thread** — use `compute()` or an `Isolate` to prevent UI jank.
4. Flame targets 60 FPS but must degrade gracefully. Never block the game loop with I/O.
5. Dispose of `CameraController` and `PoseDetector` properly on widget disposal to prevent memory leaks.
6. Firebase writes happen **after session end only** — never during active gameplay.

### ML Kit Pose Detection Rules
- Use the `PoseDetectionMode.stream` mode for live detection
- Use the **base model** (`PoseDetectorOptions` default), not the accurate model — the accurate model is too slow for budget hardware
- 33 landmarks are returned per frame, each with normalized `x`, `y`, `z`, and `likelihood`
- **Always check `likelihood >= 0.5` before using any landmark.** Below this threshold, the data is unreliable — skip that frame's contribution to rep detection
- Landmark coordinates are normalized (0.0–1.0) relative to image dimensions. Multiply by image width/height to get pixel positions for overlay drawing.
- The front camera feed is horizontally mirrored on Android. Compensate for this in the `CustomPainter` overlay and in landmark-based calculations (left/right may be inverted in raw data)

### Code Style Rules
- Dart file names: `snake_case.dart`
- Class names: `PascalCase`
- Constants: prefix `k`, camelCase — e.g., `kPaceThresholdSeconds`, `kTotalRounds`, `kStartingLives`
- Enum types and values: `PascalCase` — e.g., `WorkoutType.squats`, `GamePhase.cooldown`
- Private members: prefix `_`
- No `print()` in production code — use Flutter's `debugPrint()` wrapped in `assert`
- Prefer `const` constructors wherever possible

## Current Project State (At Time of Writing)

**Platform & Language**
- **Flutter** (Dart) — the app framework. Builds and deploys to Android to Linux machine.

**Game Layer**
- **Flame** — 2D game engine that runs inside Flutter. Handles the game loop, sprites, health bars, boss components, and all game logic.

**Motion Input**
- **Google ML Kit Pose Detection** — runs on-device. Reads the camera feed and returns 33 body landmark positions per frame.
- **camera** (Flutter package) — gives access to the phone's camera and streams frames into ML Kit.

**Backend & Auth**
- **Firebase** — the entire backend.
- **Firebase Auth** — handles identity. Google Sign-In is the only provider.
- **Google Sign-In** — the actual OAuth flow users interact with.
- **Cloud Firestore** — Stores leaderboard entries, achievements, and user session statistics.
- **FlutterFire** — the bridge layer that connects your Flutter app to Firebase.

**Dev Environment**
- **Windsurf** — primary code editor for vibe-coding.
- **Git + GitHub** — version control. Repo at https://www.github.com/wukinnin/fitfusion
- **Fedora Linux 43** — host OS on Thinkpad T470.
- **Android SDK (cmd-line tools)** (command-line tools, API 35 / Android 14) — compiles and deploys APKs.
- **OpenJDK 21**
- **Gradle 8**
- **ADB** (Android Debug Bridge) — physical and wireless connection to the Tecno Spark Go 30c.

---

**NOTE: Please read to ARCHITECTURE.md and GAMEPLAY.md for further information about the system.**