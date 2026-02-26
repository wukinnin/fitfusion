# FitFusion — Project Context Document

> **This file is the single source of truth for this project.**
> Read this file at the start of every Windsurf session before writing any code.
> Every architectural decision, design rule, and constraint defined here is final unless
> explicitly updated by the project author.

---

## 1. What This Project Is

**FitFusion** is an Android mobile application that is simultaneously a fitness tool and a 2D augmented reality game. The core concept is simple: the player's physical body is the game controller. To play the game, you must exercise. To exercise effectively, the game must reward you. These two things are inseparable — the exercise IS the gameplay.

The app uses the phone's front-facing camera to detect the player's body movements in real time via Google ML Kit Pose Detection. The game renders as a 2D overlay drawn directly on top of the live camera feed, creating an augmented reality effect. The player sees themselves on screen with game elements — monsters, health bars, HUD — composited as a layer over the camera image. The body is tracked, reps are counted, and those reps drive every game mechanic.

This is an academic Capstone Project. The target study population is students of the University of Cebu Lapu-Lapu and Mandaue (UCLM). The product must be a functioning, demonstrable MVP delivered within one month. **Every decision in this codebase prioritizes a working, shippable product over architectural perfection.**

---

## 2. Formal Academic Objectives (Verbatim — Do Not Paraphrase)

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

## 3. Scope and Limitations (Final — Do Not Add Features Outside This)

### What Is In Scope
- Android mobile application only
- Camera-based motion detection via Google ML Kit Pose Detection
- 2D AR overlay game rendered by Flame on top of live camera preview
- Three selectable workout types: **Squats**, **Jumping Jacks**, **Side Oblique Crunches**
- One workout type selected per session — it cannot change mid-session
- 10-round progressive survival game mode
- Guest mode — play without an account, no data saved
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
- Settings screens beyond the minimum needed for auth

---

## 4. Game Design — Complete and Authoritative Specification

### 4.1 Workout Selection Screen
Before any game session, the player is shown a screen with three options:
- **Squats**
- **Jumping Jacks**
- **Side Oblique Crunches**

The player taps one to select it. This selection persists for the entire session. The game is built around whichever type the player picks. The workout type is passed into the game session and into the rep detector — only that exercise type is detected during play.

### 4.2 The 10-Round Progression Loop

The game is a linear sequence of 10 rounds. Each round presents one monster. The player must defeat all 10 to win.

**Within a round:**
1. A monster appears with a health pool equal to `round + 1` hit points
2. The player performs reps of their chosen exercise
3. Each completed rep deals 1 damage to the monster (reduces its health by 1)
4. When the monster's health reaches 0, the round is won
5. A cooldown period of 10–15 seconds begins (rep detection paused, pace timer paused)
6. After cooldown, the next round starts automatically

**Rep requirements table:**

| Round | Reps to Win |
|-------|-------------|
| 1     | 2           |
| 2     | 3           |
| 3     | 4           |
| 4     | 5           |
| 5     | 6           |
| 6     | 7           |
| 7     | 8           |
| 8     | 9           |
| 9     | 10          |
| 10    | 11          |

Formula: `repsRequired(round) = round + 1`

**Total reps to complete a full game session:** 2+3+4+5+6+7+8+9+10+11 = **65 reps**

### 4.3 The Pace Mechanic (Core Tension)

The pace mechanic is what makes FitFusion a game rather than a rep counter. It enforces continuous movement.

**Rule:** After the first rep of a round, the player must perform each subsequent rep within **3 seconds** of the previous rep.

**Implementation logic:**
- A pace timer starts after each rep is registered
- If the next rep is detected within 3 seconds → timer resets, no penalty
- If 3 seconds elapse with no rep detected → monster attacks → player loses 1 life → timer resets and the player must continue (round does not restart, progress is not lost — only a life is)
- The pace timer is paused during cooldown periods
- The pace timer does not start at the beginning of a round — it starts after the first rep of that round is detected. This gives the player time to get into position.

**Pace threshold constant:** `kPaceThresholdSeconds = 3`

### 4.4 Lives System

- Player starts each game with **3 lives** — displayed as 3 heart icons in the HUD
- Each monster attack (pace failure) costs 1 life → one heart goes dark/empty
- **Lives carry across all rounds for the entire session** — they do not reset between rounds
- Lives cannot be recovered or gained during a session
- At 0 lives: game over, player loses, must retry from Round 1

**Lives constant:** `kStartingLives = 3`

### 4.5 Win and Lose Conditions

| Condition | Event |
|-----------|-------|
| Defeat monster in Round 10 | Player wins — show victory screen |
| Lose all 3 lives at any point | Player loses — show defeat screen |

Neither condition is reversible mid-session. On win or lose, the session ends and results are displayed.

### 4.6 Cooldown Period

- Duration: 10–15 seconds (use 12 seconds as the default — `kCooldownSeconds = 12`)
- Triggered immediately after each monster is defeated
- A countdown is shown visually on screen
- Rep detection is suspended during cooldown
- Pace timer is suspended during cooldown
- Player can use this time to rest and prepare
- Cooldown ends automatically — no player input required

---

## 5. Gamification Systems

### 5.1 Leaderboard

Three separate leaderboards — one per workout type. Each leaderboard shows the top 10 users.

**Leaderboard entries track:**
- **Fastest Session Time** — the shortest time in seconds to complete a full 10-round session (win condition required)
- **Fastest Rep Pace** — the shortest single rep interval (in seconds) recorded across all sessions

Only signed-in users appear. Guest sessions do not post to any leaderboard. A user's entry is updated only if the new session beats their current personal best.

**Firestore path:** `/leaderboard/{workoutType}/fastest_session/{uid}` and `/leaderboard/{workoutType}/fastest_pace/{uid}`

### 5.2 Player Statistics

Displayed on a profile/stats screen. Split per workout type, with totals shown alongside.

**Metrics tracked per workout type:**
- Personal best session time (seconds)
- Personal best rep pace (seconds per rep)
- Average session time (seconds)
- Average rep pace (seconds per rep)
- Total rounds played
- Total minutes played in-game

**Firestore path:** `/users/{uid}/stats/{workoutType}`

### 5.3 Achievements

Unlockable milestones stored per user. Checked and written to Firestore at session end.

Suggested initial achievement set (finalize before Milestone 3):
- **"First Blood"** — Complete your first game session (win or lose)
- **"Dragonslayer"** — Win a full 10-round session for the first time
- **"Untouchable"** — Win a session without losing a single life
- **"Speed Demon"** — Achieve a rep pace under 1.5 seconds
- **"Iron Will"** — Play 10 total sessions
- **"The Long Road"** — Accumulate 30 total minutes of in-game time

**Firestore path:** `/users/{uid}/achievements/{achievementId}`

---

## 6. Authentication and User State

### Two States

**Guest (Unauthenticated)**
- All game mechanics work fully
- Leaderboard is visible (read) but the user cannot post to it
- Stats screen shows a sign-in prompt
- Achievements are visible but locked
- No data is written to Firestore

**Signed-In (Google Account via Firebase Auth)**
- All guest capabilities
- Session data written to Firestore after each session
- Leaderboard updated if session sets a new personal best
- Stats updated after each session
- Achievements checked and unlocked after each session

### Rules for Auth
- Sign-in is never forced — the game is fully playable as a guest
- Sign-in is presented as a value-add: "Sign in to save your progress and compete"
- Google Sign-In is the **only** authentication provider
- On sign-in, create the `/users/{uid}` document if it does not exist
- Handle sign-out gracefully — no crash, return to guest state

---

## 7. Visual Design Direction

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

### Monster Sprite Progression (10 rounds)
Use free sprite packs from itch.io or OpenGameArt.org. All sprites: PNG, transparent background, minimum idle + hit frames.

| Rounds | Monster Type |
|--------|-------------|
| 1–2    | Slime / Goblin |
| 3–4    | Orc / Skeleton |
| 5–6    | Dark Knight |
| 7–8    | Mage / Necromancer |
| 9      | Giant / Titan |
| 10     | Dragon (boss) |

---

## 8. Technical Constraints (Mandatory Rules)

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

### Architecture Rules
1. **No business logic in widget files.** Widgets render state. They do not compute it.
2. **The Flame game does not import Firebase.** Game logic and backend are fully decoupled. A `GameController` sits between them.
3. **The rep detector does not import Flame.** It emits events via a stream. The game listens.
4. **All inter-layer communication uses `Stream<T>`.** Each layer is independent and communicates only through typed event streams.
5. **All Firebase calls are wrapped in `try/catch`.** Firebase failures must never crash the game. Firebase is supplementary — the core gameplay loop has zero Firebase dependency.
6. **All magic numbers are constants in `constants.dart`.** Never hardcode `3`, `10`, `12`, `3.0`, or any game parameter inline.

### Code Style Rules
- Dart file names: `snake_case.dart`
- Class names: `PascalCase`
- Constants: prefix `k`, camelCase — e.g., `kPaceThresholdSeconds`, `kTotalRounds`, `kStartingLives`
- Enum types and values: `PascalCase` — e.g., `WorkoutType.squats`, `GamePhase.cooldown`
- Private members: prefix `_`
- No `print()` in production code — use Flutter's `debugPrint()` wrapped in `assert`
- Prefer `const` constructors wherever possible

---

## 9. Complete File and Directory Structure

This is the target structure. Build to this layout. Do not deviate without reason.

```
fitfusion/
├── lib/
│   ├── main.dart                          # App entry point. Initializes Firebase, wraps app in providers.
│   ├── firebase_options.dart              # Auto-generated by FlutterFire. Do not edit.
│   ├── app.dart                           # MaterialApp root, theme, routing.
│   │
│   ├── core/
│   │   ├── constants.dart                 # ALL game constants. The only place numbers live.
│   │   ├── enums.dart                     # WorkoutType, GamePhase, AchievementId, etc.
│   │   ├── extensions.dart                # Dart extension methods (e.g., WorkoutType.displayName)
│   │   └── theme.dart                     # AppTheme — colors, fonts, text styles, button styles.
│   │
│   ├── features/
│   │   │
│   │   ├── auth/
│   │   │   ├── auth_service.dart          # Firebase Auth + Google Sign-In logic.
│   │   │   └── auth_provider.dart         # ChangeNotifier/Riverpod provider exposing auth state.
│   │   │
│   │   ├── motion/
│   │   │   ├── camera_service.dart        # CameraController init, frame streaming, resolution config.
│   │   │   ├── pose_detector_service.dart # ML Kit PoseDetector wrapper. Emits Stream<Pose?>.
│   │   │   ├── rep_detector.dart          # State machines for each exercise. Emits Stream<RepEvent>.
│   │   │   └── pace_monitor.dart          # Watches rep timestamps. Emits Stream<PaceEvent>.
│   │   │
│   │   ├── game/
│   │   │   ├── fitfusion_game.dart        # FlameGame subclass. The entire Flame game lives here.
│   │   │   ├── game_controller.dart       # Bridge: receives RepEvent/PaceEvent, drives the Flame game.
│   │   │   ├── game_session.dart          # Immutable data class: captures session result for Firebase.
│   │   │   │
│   │   │   └── components/
│   │   │       ├── monster_component.dart       # Monster sprite, health, hit animation.
│   │   │       ├── monster_health_bar.dart      # Decorative health bar component.
│   │   │       ├── player_lives_display.dart    # Row of heart icons, updates on life lost.
│   │   │       ├── round_banner.dart            # "ROUND X / 10" display.
│   │   │       ├── rep_progress_bar.dart        # Rep counter progress (e.g., 2/5 reps this round).
│   │   │       ├── damage_number.dart           # Floating "+1" damage popup, fades out.
│   │   │       ├── cooldown_overlay.dart        # Full-screen cooldown countdown between rounds.
│   │   │       └── pace_timer_indicator.dart    # Visual indicator of pace timer urgency.
│   │   │
│   │   ├── firebase/
│   │   │   ├── firestore_service.dart     # All Firestore reads and writes in one place.
│   │   │   ├── leaderboard_service.dart   # Leaderboard-specific queries and writes.
│   │   │   └── stats_service.dart         # Player stats calculations and writes.
│   │   │
│   │   └── screens/
│   │       ├── splash_screen.dart         # App startup — auth check, route to home or onboarding.
│   │       ├── home_screen.dart           # Main menu: Play, Leaderboard, Stats, Sign In/Out.
│   │       ├── workout_select_screen.dart # Choose Squats / Jumping Jacks / Crunches.
│   │       ├── game_screen.dart           # The game screen: camera preview + Flame GameWidget overlay.
│   │       ├── results_screen.dart        # Post-session: win/lose, stats summary, Firebase write trigger.
│   │       ├── leaderboard_screen.dart    # Top 10 display, tab per workout type.
│   │       └── stats_screen.dart          # Personal stats per workout type.
│   │
│   └── widgets/
│       ├── camera_preview_widget.dart     # Sized camera preview that fills the screen.
│       ├── pose_overlay_painter.dart      # CustomPainter — draws landmark skeleton for debug.
│       └── fantasy_button.dart            # Reusable styled button matching the fantasy theme.
│
├── assets/
│   ├── sprites/                           # Monster sprites, UI decoration sprites (PNG)
│   ├── audio/                             # Sound effects (mp3/ogg): rep hit, monster death, etc.
│   └── fonts/                             # Cinzel and CinzelDecorative font files
│
├── android/
│   └── app/
│       ├── google-services.json           # Firebase Android config. Auto-generated. Do not edit.
│       └── src/main/AndroidManifest.xml   # Camera permission, internet permission declared here.
│
├── CONTEXT.md                             # This file.
├── ARCHITECTURE.md                        # Data flow and system design detail.
├── WINDSURF_HANDOFF.md                    # Windsurf AI session start prompt.
├── pubspec.yaml
└── .gitignore
```

---

## 10. Firebase Data Model (Complete)

### `/users/{uid}`
Document created on first sign-in.
```
{
  uid: string,
  displayName: string,
  email: string,
  photoUrl: string | null,
  createdAt: Timestamp
}
```

### `/users/{uid}/sessions/{auto-id}`
Written once at end of each completed session (win or lose) for signed-in users.
```
{
  workoutType: "squats" | "jumping_jacks" | "oblique_crunches",
  completedAt: Timestamp,
  won: boolean,
  totalReps: number,
  totalTimeSeconds: number,
  roundsCompleted: number,          // 0–10
  bestRepPaceSeconds: number,       // fastest single rep interval this session
  avgRepPaceSeconds: number,
  livesLost: number                 // 0–3
}
```

### `/users/{uid}/stats/{workoutType}`
Upserted (merged) at end of each session. One document per workout type.
```
{
  workoutType: string,
  sessionsPlayed: number,
  totalRoundsPlayed: number,
  totalMinutesPlayed: number,
  bestSessionTimeSeconds: number,   // only set if won == true
  bestRepPaceSeconds: number,
  avgSessionTimeSeconds: number,
  avgRepPaceSeconds: number
}
```

### `/users/{uid}/achievements/{achievementId}`
Written once when achievement is first unlocked. Never overwritten.
```
{
  achievementId: string,
  unlockedAt: Timestamp,
  workoutType: string | null
}
```

### `/leaderboard/{workoutType}/fastest_session/{uid}`
Set (overwrite) only when new session time beats the existing entry for this user.
```
{
  uid: string,
  displayName: string,
  photoUrl: string | null,
  timeSeconds: number,
  achievedAt: Timestamp
}
```

### `/leaderboard/{workoutType}/fastest_pace/{uid}`
Set (overwrite) only when new pace beats the existing entry for this user.
```
{
  uid: string,
  displayName: string,
  photoUrl: string | null,
  paceSeconds: number,
  achievedAt: Timestamp
}
```

---

## 11. Key Constants Reference

These are defined in `lib/core/constants.dart`. Do not use raw numbers anywhere else.

```dart
// Game rules
const int kTotalRounds = 10;
const int kStartingLives = 3;
const double kPaceThresholdSeconds = 3.0;
const int kCooldownSeconds = 12;

// Rep formula
// repsRequired(round) = round + 1  →  implemented as a function, not a constant

// Camera / ML Kit
const int kFrameSkipCount = 2;           // process every Nth frame
const double kLandmarkLikelihoodThreshold = 0.5;

// Rep detection (per exercise — tuned via testing)
const double kSquatHipDropThreshold = 0.15;       // normalized y delta
const double kJumpingJackWristRaiseThreshold = 0.1; // wrist above shoulder threshold
const double kCrunchWristHipProximityThreshold = 0.12; // wrist-to-hip distance threshold

// Firebase
const String kFirebaseRegion = 'asia-southeast1';
```

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
- 

 AI: installed with Flutter/Dart extensions, project indexed
- Sanity check: default Flutter counter app deployed to device successfully

**Status: Ready to write application code. The toolchain is end-to-end verified.**
