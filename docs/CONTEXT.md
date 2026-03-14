# CONTEXT.md -- Supplement/Compliment to FITFUSION.md

## What This Project Is

**FitFusion** is an Android mobile application that is simultaneously a fitness tool and a 2D augmented reality game. The core concept is simple: the player's physical body is the game controller. To play the game, you must exercise. To exercise effectively, the game must reward you. These two things are inseparable — the exercise IS the gameplay.

The app uses the phone's front-facing camera to detect the player's body movements in real time via Google ML Kit Pose Detection. The game renders as a 2D overlay drawn directly on top of the live camera feed, creating an augmented reality effect. The player sees themselves on screen with game elements — monsters, health bars, HUD — composited as a layer over the camera image. The body is tracked, reps are counted, and those reps drive every game mechanic.

The product must be a functioning, demonstrable MVP delivered within one month. **Every decision in this codebase prioritizes a working, shippable product over architectural perfection.**

---

## Formal Academic Objectives (Verbatim — Do Not Paraphrase)

### General Objective
To analyze, design, and develop "FitFusion" — a platform for immersive fitness realities enhancing engagement through augmented gamification in digital workouts — to promote meaningful exercise participation.

### Specific Objectives
1. Assess the current state of digital workout solutions, particularly:
   - User engagement
   - Interaction
   - Retention
2. Utilize mobile platforms to design interactive and immersive game-centric functionality, including:
   - Motion detection as input data
   - Augmented reality for game rendering
3. Implement gamification elements to promote platform engagement, such as:
   - Competitive Leaderboards
   - Player Statistics
   - Achievements

### What These Objectives Mean in Code
- "Immersive" = the player must physically exercise to interact with the game. There is no other input method.
- "Augmented Reality" = 2D game elements (sprites, health bars, HUD) rendered as an overlay on a live camera feed. NOT: ARCore, plane detection, world anchoring, or 3D anything.
- "Augmented Gamification" = the visual game layer that reacts to physical input. Reps happen → game reacts visually.

---

## Scope and Limitations (Final — Do Not Add Features Outside This)

### What Is In Scope
- Android mobile application only
- Camera-based motion detection via Google ML Kit Pose Detection
- 2D AR overlay game rendered by Flame on top of live camera preview
- Three selectable workout types: **Squats**, **Jumping Jacks**, **Side Oblique Crunches**
- One workout type selected per session — it cannot change mid-session
- 10-round progressive survival game mode
- Google Sign-In via Firebase Auth
- Competitive leaderboard (Top 10, split per workout type)
- Player statistics (per user, per workout type)
- Achievements system

### What Is Out of Scope — Do Not Implement These
- 3D rendering of any kind
- Multiplayer of any kind (online or local)
- Narrative campaigns or story modes
- Personalization (gender, height, weight, BMI, body type)
- In-app purchases or monetization
- Push notifications
- Offline data sync or caching
- iOS, web, or desktop builds

---

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

### HUD Layout (Portrait Orientation)

```
┌──────────────────────────────────────┐
│  ╔══════════════╗  ╔══════════════╗  │
│  ║ ROUND  3/10  ║  ║  ♥  ♥  ♡   ║  │  ← Top HUD bar
│  ╚══════════════╝  ╚══════════════╝  │
│                                      │
│         [MONSTER SPRITE]             │  ← Monster (upper center)
│      ████████████░░░░  HP: 4/7       │  ← Monster health bar
│                                      │
│  [LIVE CAMERA FEED — PLAYER VISIBLE] │  ← Background
│                                      │
│  ╔══════════════════════════════════╗ │
│  ║  SQUATS   REPS: ██░░░░   2 / 5  ║ │  ← Bottom HUD bar
│  ╚══════════════════════════════════╝ │
└──────────────────────────────────────┘
```

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

---

## 12. Current Project State (At Time of Writing)

**Environment: Fully set up and verified.**

- Flutter SDK: installed, on PATH
- Android SDK: API 35 / build-tools 35.0.0, installed
- Java: OpenJDK 21, active
- Gradle: 8
- Device: Tecno Spark Go 30c, connected via ADB, authorized
- Bundle ID: `com.wukinnin428.fitfusion`
- Firebase: project live, Singapore region, Auth + Firestore active
- FlutterFire: configured, `firebase_options.dart` present
- `google-services.json`: present in `android/app/`
- Git: initialized, commits pushed to `github.com/wukinnin/fitfusion`

