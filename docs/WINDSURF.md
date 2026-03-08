# FitFusion — Windsurf AI Guide

> This document is the operational guide for all Windsurf AI development sessions on FitFusion.
> It combines session-start rituals, milestone planning, task descriptions, rules, and troubleshooting.
> Read CONTEXT.md and ARCHITECTURE.md before writing any code in any session.
> This file does NOT override CONTEXT.md — when in conflict, CONTEXT.md wins.

---

## Part 1: Session Start Ritual

> **Run this at the start of EVERY Windsurf session. No exceptions. Do not skip it.**
> This 60-second ritual prevents hours of wrong-direction code generation.

### Paste This Into Windsurf First:

```
Read the following project files in their entirety before you do anything else:
1. CONTEXT.md
2. ARCHITECTURE.md
3. WINDSURF.md — read the "Current Project State" section specifically

After reading all three, confirm your understanding by answering these exactly:
1. What is FitFusion in one sentence?
2. What is the bundle ID and target device?
3. What is the pace threshold in seconds and the cooldown duration in seconds?
4. What milestone are we currently on, and what is its deliverable?
5. What files currently exist under lib/? List them.

Do not write any code until you have answered all five questions and I confirm
your answers are correct. If unsure about the current state of any file, ask —
do not assume.
```

Read Windsurf's response. Correct any wrong answers before proceeding. Then give the specific task.

---

## Part 2: Project Identity (Quick Reference for Windsurf)

| Field | Value |
|-------|-------|
| Project | FitFusion |
| Type | Android mobile app — fitness game with 2D AR overlay |
| Bundle ID | `com.wukinnin428.fitfusion` |
| Repository | `https://github.com/wukinnin/fitfusion` |
| Platform | Flutter (Dart), Android only |
| Target Device | Tecno Spark Go 30c (Android 14, budget hardware) |
| IDE | Windsurf on Fedora Linux 43, ThinkPad T470 |
| Context | Academic Capstone Project — one-month deadline, MVP is the only goal |

### 30-Second Summary for Windsurf:

FitFusion is a game where you exercise to play. The phone's front camera detects your body movements via Google ML Kit Pose Detection. The game renders as a 2D overlay on top of the live camera feed — the "AR" effect. The player chooses one of three exercises (Squats, Jumping Jacks, Side Oblique Crunches) before a session. Completing reps attacks a monster on screen. If more than 5 seconds pass without a rep, the monster attacks back (player loses a life). Survive 10 rounds to win. Google Sign-In via Firebase saves scores to a leaderboard. High Fantasy aesthetic — gold, red, black, white; pixel sprites; Cinzel font. Ship the MVP. That is the only goal.

---

## Part 3: Complete Tech Stack

| Layer | Tool | Version / Notes |
|-------|------|-----------------|
| App framework | Flutter (Dart) | Android only |
| Game engine | Flame | `1.35.1` |
| Motion detection | google_mlkit_pose_detection | `^0.11.0` — base model, on-device |
| Camera | camera | `0.11.4` — frame streaming to ML Kit |
| Auth | Firebase Auth + google_sign_in | Auth `6.1.4` / Sign-In `^6.2.1` — Google only |
| Database | Cloud Firestore | `6.1.2` — Singapore region (`asia-southeast1`) |
| Backend bridge | FlutterFire | Config already done — `firebase_core 4.4.0` |
| State management | provider | `^6.1.2` — minimal usage |
| Permissions | permission_handler | `11.4.0` — camera runtime request |
| Typography | google_fonts | `6.3.3` — Cinzel for fantasy look |
| IDE | Windsurf | Primary code editor |
| Version control | Git + GitHub | `wukinnin/fitfusion` |
| Host OS | Fedora Linux 43 | ThinkPad T470 |
| Java | OpenJDK 21 | Required for Gradle |
| Gradle | 8 | Android build system |
| Android SDK | API 35 / build-tools 35.0.0 | Command-line tools only |
| ADB | Via Android SDK platform-tools | Device: Tecno Spark Go 30c |

---

## Part 4: Development Environment

All of the following are verified working — nothing in the dev environment needs setup:

- Flutter SDK at `~/development/flutter`, on `$PATH`
- Android SDK at `~/development/android-sdk`, `$ANDROID_HOME` set, on `$PATH`
- `flutter doctor` passes on Flutter + Android toolchain
- Device connected via ADB (Tecno Spark Go 30c, Android 14)
- `flutter run` successfully deploys to device
- Firebase project configured, `firebase_options.dart` exists at `lib/firebase_options.dart`
- `google-services.json` exists at `android/app/google-services.json`
- Firebase Auth: Google Sign-In enabled, debug SHA-1 fingerprint registered
- Firestore: database created, test mode, Singapore region (`asia-southeast1`)
- Git initialized, main branch, remote at `github.com/wukinnin/fitfusion`

**Start writing code immediately. The toolchain is end-to-end verified.**

---

## Part 5: Current Project State

> **UPDATE THIS SECTION AFTER EVERY SIGNIFICANT CODING SESSION.**
> An outdated status is worse than no status. Windsurf will make wrong assumptions if this is stale.

### Template for Each Update:
```
### As of: [Date] — [Session Description]

Milestone: [Current milestone name and number]

What was completed this session:
- [file or feature created/changed]
- [file or feature created/changed]

What currently exists under lib/:
- [list every relevant file]

What does NOT exist yet:
- [list files still to be created]

Known issues or blockers:
- [any bugs, failed tests, or open questions]

Next task:
- [the specific next thing to do]
```

---

### As of: Initial Handoff (Day 0)

**What exists:**
- Flutter scaffold created (`flutter create fitfusion --org com.wukinnin428 --platforms android`)
- `pubspec.yaml` with all dependencies added and resolved
- `lib/firebase_options.dart` — generated by FlutterFire, DO NOT TOUCH
- `android/app/google-services.json` — Firebase config, DO NOT TOUCH
- `AndroidManifest.xml` — camera and internet permissions added, `hardwareAccelerated="true"` set
- Git: commits on `main` branch

**What does NOT exist yet:**
- No feature code under `lib/` except `main.dart` (default counter app) and `firebase_options.dart`
- No `lib/core/` directory
- No `lib/features/` directory
- No `lib/widgets/` directory
- No `assets/` content

**The app currently runs the default Flutter counter app on the Tecno Spark Go 30c.**

---

## Part 6: Milestone Map

Work through milestones in strict order. Do not start the next milestone until the current one is working and verified on the physical device.

---

### ✅ Milestone 0 — Environment Setup
**Status: COMPLETE**

Dev environment fully set up. Firebase configured. App deploys to device. Default Flutter counter app runs successfully on the Tecno Spark Go 30c.

---

### 🔲 Milestone 1 — Camera Feed + Pose Detection + Rep Counting
**Target: Days 1–4**

**Deliverable:** Open the app → see yourself in the camera feed → ML Kit detects your pose → skeleton overlay drawn on your body → rep counter for all three exercises correctly counts reps in the debug console.

**Done when:** Squats, jumping jacks, and side crunches are all detected correctly with no false positives and no missed reps when tested on the physical device.

**Tasks (in order):**

1. **App skeleton** — Replace default `main.dart`. Create `app.dart` with `MaterialApp`, theme, routing shell. Initialize Firebase in `main()`. Wrap app in `MultiProvider` with `AuthProvider`.

2. **Core constants** — Create `lib/core/constants.dart` with ALL game constants. Refer to the constants reference in CONTEXT.md §13. No magic numbers anywhere else in the codebase.

3. **Enums** — Create `lib/core/enums.dart` with `WorkoutType`, `GamePhase`, `PaceEventType`, `LeaderboardType`, `AchievementId`.

4. **Extensions** — Create `lib/core/extensions.dart` — extension methods on `WorkoutType` (`displayName`, `firestoreKey`, `shortName`) and `AchievementId` (`firestoreKey`, `displayName`, `description`).

5. **Theme** — Create `lib/core/theme.dart` — `AppTheme` class with `ThemeData`. Apply Gold/Black/Red/White color palette. Cinzel font for display text. Cinzel Decorative for body. Fantasy-styled button theme (gold pill, white bold text). See CONTEXT.md §9 for palette.

6. **CameraService** — Create `lib/features/motion/camera_service.dart`. Manages `CameraController`. Selects front camera. Initializes at `ResolutionPreset.low`. Streams frames. Implements frame skipping using `kFrameSkipCount`. Exposes `Stream<CameraImage>`. Must have a proper `dispose()` method.

7. **PoseDetectorService** — Create `lib/features/motion/pose_detector_service.dart`. Wraps ML Kit `PoseDetector`. Accepts `CameraImage`, converts to `InputImage` (YUV420, correct rotation from sensor orientation), runs inference off main thread. Filters landmarks below `kLandmarkLikelihoodThreshold`. Exposes `Stream<Pose?>`. Must have a proper `dispose()`.

8. **Camera preview widget** — Create `lib/widgets/camera_preview_widget.dart`. A widget that fills its parent with the camera feed using `CameraPreview`. Handles aspect ratio correctly on portrait screens.

9. **Pose overlay painter** — Create `lib/widgets/pose_overlay_painter.dart`. A `CustomPainter` that draws cyan dots at each of the 33 ML Kit landmark positions and green lines connecting them (skeleton). Only rendered in debug builds (`kDebugMode`). Accounts for front camera horizontal mirroring.

10. **Basic GameScreen stub** — Create a minimal `lib/features/screens/game_screen.dart` that shows the camera feed + pose overlay. No Flame yet. Deploy to device and verify pose skeleton renders correctly and tracks the body.

11. **RepDetector** — Create `lib/features/motion/rep_detector.dart`. Implements three independent two-state finite state machines — one per exercise type (`WorkoutType`). Each machine uses a rolling average buffer of `kLandmarkBufferWindowSize = 5` frames before threshold comparison. Rep counted on return to neutral position. See ARCHITECTURE.md §2.3 for full per-exercise logic. Exposes `Stream<RepEvent>`.

12. **PaceMonitor** — Create `lib/features/motion/pace_monitor.dart`. Watches rep events. Maintains an internal countdown timer (`kPaceThresholdSeconds = 5.0`). Emits `PaceFailureEvent` if timer fires. Has `start()`, `stop()`, `reset()` methods. Does not know about game state. Exposes `Stream<PaceEvent>`.

13. **Test all three exercises** — Wire rep detector output to debug console. Test squats, jumping jacks, and side crunches on the physical Tecno device. Confirm correct counts with no phantom reps and no missed reps. Adjust thresholds in `constants.dart` based on real performance.

---

### 🔲 Milestone 2 — Core Game Loop
**Target: Days 5–12**

**Deliverable:** A fully playable 10-round game session on the device. Camera feed visible, game elements overlaid, reps hit the monster, pace mechanic works, lives system works, cooldown works, win/lose screens appear.

**Done when:** A complete 10-round session can be played end-to-end on the Tecno. All mechanics (reps, pace, lives, cooldown, round progression, win/lose) behave exactly as specified in CONTEXT.md §5.

**Tasks (in order):**

1. **FitFusionGame** — Create `lib/features/game/fitfusion_game.dart`. FlameGame subclass. Transparent background (mandatory). Implements the `GamePhase` state machine. Has `onRepDetected()`, `onPaceFailed()`, and `configure(workoutType)` public methods. Manages round counter, monster HP, lives, session timing. Builds and emits `GameSession` on session end. See ARCHITECTURE.md §4 for full spec.

2. **GameSession data class** — Create `lib/features/game/game_session.dart`. Immutable data class. Fields match the Firebase data model in CONTEXT.md §12. Includes `lastRound` field.

3. **Flame components** — Create all components under `lib/features/game/components/`:
   - `monster_health_bar.dart` — full-width red bar, top of screen, shrinks with HP
   - `monster_component.dart` — sprite upper-left, randomly selected from session's 10-sprite pool, changes each round
   - `sword_slash_component.dart` — spawned on each rep, random of 3 sprite sheets, auto-removes on complete
   - `player_lives_display.dart` — 3 cyan pixel hearts, empties rightmost first
   - `round_banner.dart` — "ROUND X" gold pill, lower-center
   - `rep_progress_bar.dart` — "X / Y REPS" center pill
   - `damage_number.dart` — floating number, rises and fades, auto-removes
   - `cooldown_overlay.dart` — full-screen dim overlay, "ROUND X" announcement, large circular countdown timer
   - `pace_timer_indicator.dart` — circular pie countdown, upper-right, green → red → flashing red at 0

4. **GameController** — Create `lib/features/game/game_controller.dart`. Bridge layer. Subscribes to `RepDetector` and `PaceMonitor` streams. Translates events into `game.onRepDetected()` and `game.onPaceFailed()` calls. Manages PaceMonitor start/stop based on GamePhase. Disposes subscriptions in `dispose()`. See ARCHITECTURE.md §3 for full spec.

5. **Damage flash** — Implement the full-screen red filter on life loss. Brief duration. Applied over everything — camera feed and all HUD elements. See CONTEXT.md §5.4 and ARCHITECTURE.md §4.6.

6. **GameScreen** — Build full `lib/features/screens/game_screen.dart`. Stack: camera feed (bottom) → pose overlay (debug only) → GameWidget (top, transparent). Creates and owns `CameraService`, `PoseDetectorService`, `RepDetector`, `PaceMonitor`, `GameController`, `FitFusionGame`. Disposes everything in `dispose()`.

7. **WorkoutSelectScreen** — Create `lib/features/screens/workout_select_screen.dart`. Three styled gold pill buttons (Squats, Jumping Jacks, Side Crunches). Tapping one routes to `GameScreen` with that `WorkoutType` passed as argument.

8. **ResultsScreen** — Create `lib/features/screens/results_screen.dart`. Receives `GameSession`. Renders VICTORY (green title) or DEFEAT (red title) based on `session.won`. Displays all stats. RETRY button → same workout type back to `GameScreen`. QUIT button → `HomeScreen`. Camera feed remains active in background. See CONTEXT.md §5.7 for exact layout and fields.

9. **HomeScreen** — Create `lib/features/screens/home_screen.dart`. Play button → `WorkoutSelectScreen`. Placeholder nav items for Leaderboard and Stats (wired in Milestone 3). Background music `ST_MAIN_*.mp3`.

10. **Wire navigation** — Define all named routes in `app.dart`. Connect all screens in the flow defined in CONTEXT.md §15.

11. **End-to-end test** — Play a complete session on the Tecno. Verify: workout selection → 10 rounds → correct HP per round → pace failures cost lives → damage flash on life loss → cooldown 15s before AND after each round → Round 10 no ending cooldown → victory/defeat screen shows correct stats → RETRY works → QUIT works.

---

### 🔲 Milestone 3 — Firebase Integration
**Target: Days 13–18**

**Deliverable:** Google Sign-In works on the device. After a session, data writes to Firestore. Leaderboard shows real data. Stats screen shows real data. Achievements unlock correctly.

**Done when:** Sign-in works on the Tecno. After a winning session, data appears in the Firestore console. Leaderboard and stats screens display real data from Firestore.

**Tasks (in order):**

1. **AuthService** — Create `lib/features/auth/auth_service.dart`. Wraps Firebase Auth and Google Sign-In. Methods: `signInWithGoogle()`, `signOut()`, `authStateChanges` stream, `currentUser`, `isSignedIn`. On first sign-in: create `/users/{uid}` document via `FirestoreService`.

2. **AuthProvider** — Create `lib/features/auth/auth_provider.dart`. `ChangeNotifier` that wraps `AuthService` and exposes auth state to the widget tree via `Provider`.

3. **FirestoreService** — Create `lib/features/firebase/firestore_service.dart`. All Firestore reads and writes in one file. Methods as listed in ARCHITECTURE.md §5.1. All wrapped in `try/catch`. Failures logged but never rethrown.

4. **LeaderboardService** — Create `lib/features/firebase/leaderboard_service.dart`. Leaderboard-specific queries. Fetches Top 10 per workout type per leaderboard metric. Only updates entry if new value beats current personal best.

5. **StatsService** — Create `lib/features/firebase/stats_service.dart`. Handles player stats upsert logic (merged/incremental update, not overwrite). Calculates running averages.

6. **Wire ResultsScreen to Firebase** — After session ends, if signed in: call session write, stats update, leaderboard update (if won), achievement evaluation. If guest: skip all, show local results only. See ARCHITECTURE.md §5.2 for full flow.

7. **LeaderboardScreen** — Create `lib/features/screens/leaderboard_screen.dart`. Tabbed view — one tab per workout type. Each tab shows Top 10 for Fastest Session and Fastest Pace. Reads from Firestore via `LeaderboardService`.

8. **StatsScreen** — Create `lib/features/screens/stats_screen.dart`. Shows personal stats per workout type. If guest, shows sign-in prompt instead of data.

9. **Auth in HomeScreen** — Add Sign In / Sign Out button to `HomeScreen`. Uses `AuthProvider` to reflect current state. Sign-in triggers Google OAuth flow. Sign-out returns to guest state.

10. **Achievement evaluation** — Implement achievement checking logic in `ResultsScreen` after session. Evaluate all achievement conditions against the completed session and current user stats. Unlock any not yet unlocked. See ARCHITECTURE.md §5.4 for condition table.

11. **End-to-end Firebase test** — Sign in on device → play a session → check Firestore console for written session, stats, achievements → check leaderboard screen shows data.

---

### 🔲 Milestone 4 — Visual Polish
**Target: Days 18–24**

**Deliverable:** The app looks like a real high-fantasy game, not a prototype. All screens are visually styled. Audio plays correctly throughout. Animations are smooth.

**Done when:** The app looks presentable for a demo and academic defense. All screens use consistent Gold/Black/Red/White palette. Cinzel font throughout. Audio plays at all correct moments.

**Tasks (in order):**

1. **Monster sprites** — Ensure all 20 monster sprites are in `assets/Sprites/Monsters-64x96px/`. Verify naming convention (`SPR_monster_01.png` through `SPR_monster_20.png`). Integrate session-pool logic: draw 10 random non-repeating sprites from 20 at session start. Assign one per round.

2. **Monster animations** — Implement idle animation and hit-reaction animation in `MonsterComponent`. Death animation (or visual effect) when monster HP reaches 0.

3. **Sword slash animations** — Verify `SwordSlashComponent` correctly randomly selects from `SPR_sword_sprite_sheet_01.png`, `_02.png`, `_03.png` in `assets/Sprites/Sword-64x64px/`. Confirm animation plays and component removes itself.

4. **Apply AppTheme everywhere** — Audit all screens for consistent Cinzel font, Gold `#FFD700` / Dark Gray `#21201E` / Red / White palette. Replace any placeholder styling. Apply `fantasy_button.dart` to all interactive buttons.

5. **Damage number polish** — Confirm `DamageNumber` floats upward and fades correctly. Style with gold bold Cinzel text.

6. **Health bar visual** — Style `MonsterHealthBar` using the `PixelHealthBar-128x16px/` sprite components (`SPR_bar_healthBar.png`, `SPR_bar_health.png`, etc.). Red fill, dark border, decorative frame. Match mockup.

7. **Heart sprites** — Confirm `PlayerLivesDisplay` uses `SPR_heart-sprite-sheet-48x24px.png` correctly. Cyan full → dark empty on life loss.

8. **Pace timer visual** — Confirm `PaceTimerIndicator` pie-chart renders correctly. Green → red gradient as time depletes. Flashes solid red at 0.

9. **Audio integration** — Implement all audio via Flame's audio system using exact filenames from `assets/Audio/`:
   - `ST_BATTLE_ob-lix-beats_dark_pagan_norse.mp3` — on loop during active round
   - `ST_COOLDOWN_medieval_horizons_squire.mp3` — fades in/out during cooldown
   - `ST_MAIN_medieval_horizons_quiet_repose.mp3` — on loop on HomeScreen
   - `SFX_sword_01.mp3` through `SFX_sword_05.mp3` — random on each rep
   - `SFX_win_violin_win_5.mp3` + random `VO_announcerWin_*.mp3` (5 available) on round win
   - `SFX_victory_winning.mp3` + `VO_announcerVictory_VICTOR.mp3` on session victory
   - `SFX_lose_violin_lose_4.mp3` + random `VO_announcerLose_*.mp3` (4 available) on session defeat
   - Random `VO_monsterRoar_01–10.mp3` (non-repeating per session) on monster death
   - Random `VO_playerGrunts_01–10.mp3` on life loss
   - `SFX_Click.mp3` on all UI button taps (note capital C)
   - See CONTEXT.md §6 for complete audio sequences and full file list
   - **Note:** All `assets/Audio/` subdirectories must be declared in `pubspec.yaml`. Watch for the space in `VO_announcerLose_GAME OVER.mp3` — reference with the exact filename.

10. **Victory / Defeat screen styling** — Apply dark semi-transparent cards, color-correct titles (green VICTORY, red DEFEAT), gold pill buttons, stats block layout matching the mockups.

11. **Cooldown screen styling** — Confirm dim overlay, large ROUND X text, large circular countdown timer all match the mockup.

12. **Remove debug overlays from release** — Pose skeleton overlay must be wrapped in `kDebugMode` guard and never rendered in release/profile builds.

13. **Visual consistency audit** — Walk through every screen on the Tecno. Check fonts, colors, button styles, spacing. Fix inconsistencies.

---

### 🔲 Milestone 5 — Testing and Submission
**Target: Days 25–30**

**Deliverable:** A release APK that works reliably for a demo on the Tecno Spark Go 30c.

**Done when:** Release APK installs, all three exercises work, Firebase flows work, no crashes during a full demo run.

**Tasks (in order):**

1. **Full exercise testing** — Test all three exercise types (Squats, Jumping Jacks, Side Crunches) end-to-end. Verify rep detection is accurate on the physical Tecno. Tune thresholds in `constants.dart` if needed. Document minimum lighting requirement.

2. **Full session testing** — Play multiple complete 10-round sessions. Verify all game mechanics: round progression, cooldown timing, pace failures, lives, victory, defeat.

3. **Firebase flow testing** — Test Google Sign-In → play session → verify Firestore has correct data → check leaderboard and stats screens.

4. **Guest flow testing** — Test full gameplay without signing in. Verify no Firebase calls are made and no crashes occur.

5. **Edge case testing** — Test: back button during game (should trigger defeat), RETRY from results, QUIT from results, sign out and back in.

6. **Firestore security rules** — Replace test-mode rules with proper production rules. Users can only read/write their own documents. Leaderboard is readable by all authenticated users.

7. **Release keystore** — Generate a release signing keystore. Update `android/app/build.gradle` with signing config.

8. **Register release SHA-1** — Get the SHA-1 fingerprint from the release keystore. Register it in Firebase Console → Project Settings → Android App → Add Fingerprint.

9. **Build release APK** — Run `flutter build apk --release`. Verify no build errors.

10. **Install and smoke test** — Install release APK on the Tecno Spark Go 30c via `adb install`. Run a complete demo flow. Verify Google Sign-In works with the release SHA-1.

11. **Tag release commit** — `git tag v1.0.0-mvp && git push origin v1.0.0-mvp`

---

## Part 7: Rules for Windsurf

These apply to every file, every session, without exception.

1. **Read CONTEXT.md and ARCHITECTURE.md first.** Every session. No exceptions. Never write code before confirming understanding.

2. **Target device is a budget Android phone.** Every performance decision favors the Tecno Spark Go 30c. Flagship behavior is irrelevant.

3. **Process ML Kit inference off the main thread.** Use `compute()` or a background isolate. Never block the UI thread with pose detection.

4. **Skip camera frames.** Never send every frame to ML Kit. Always use `kFrameSkipCount`. This is the most important performance rule.

5. **Check landmark likelihood.** Never use a landmark with `likelihood < kLandmarkLikelihoodThreshold`. Discard frames with unreliable critical landmarks.

6. **No magic numbers.** Every game parameter lives in `lib/core/constants.dart`. Use the constant name in code. Never hardcode `5`, `15`, `3`, `10`, `0.08`, or any game value inline.

7. **No logic in widget files.** Widgets display state. State lives in services, controllers, and notifiers.

8. **The Flame game does not import Firebase.** If Firebase appears in `fitfusion_game.dart` or any file under `lib/features/game/components/`, stop and refactor.

9. **The rep detector does not import Flame.** Motion and game layers are independent. They communicate only via streams.

10. **All Firebase calls are wrapped in try/catch.** Firebase must never crash the game or any screen.

11. **Test on the physical Tecno device, not the emulator.** Camera and ML Kit behave differently on real hardware. Always deploy to the Tecno during Milestones 1 and 2.

12. **Commit when something works.** `git add . && git commit -m "..."` after each meaningful working step. Do not let working code exist only locally.

13. **Do not implement out-of-scope features.** If it is not in CONTEXT.md, it does not exist. No multiplayer, no 3D, no personalization, no extra game modes, no pause functionality.

14. **Prefer simple over clever.** This is a one-month deadline project. Readable, working code beats elegant architecture every time.

15. **RETRY routes to GameScreen with the same WorkoutType.** It does not go back to WorkoutSelectScreen.

16. **Cooldown happens BEFORE and AFTER each round (Rounds 1–9).** Round 10 has a pre-round cooldown but NO post-round cooldown — Victory screen appears immediately on Round 10 monster defeat.

17. **`firebase_options.dart` and `google-services.json` are never touched.** These are auto-generated. Any regeneration must be done via FlutterFire CLI, not manual editing.

---

## Part 8: Useful Commands

```bash
# Run on device
flutter run

# Run with verbose output (debugging camera/ML Kit issues)
flutter run -v

# Hot reload (while flutter run is active)
r

# Hot restart (while flutter run is active)
R

# Check connected devices
flutter devices

# Check ADB device connection
adb devices

# Reconnect wireless ADB after phone reboot
adb tcpip 5555
adb connect <phone-ip>:5555

# Clean build (when weird build errors appear — use sparingly, forces full re-sync)
flutter clean && flutter pub get

# View device logs filtered to Flutter
adb logcat | grep flutter

# Build release APK (Milestone 5 only)
flutter build apk --release

# Install APK to device
adb install build/app/outputs/flutter-apk/app-release.apk

# Get signing report (for SHA-1 fingerprint)
cd android && ./gradlew signingReport

# Commit and push
git add .
git commit -m "your message"
git push
```

---

## Part 9: Common Issues and Fixes

**"CameraImage → InputImage conversion fails" or "ML Kit returns no landmarks"**
→ The byte format conversion is the most common failure in the pipeline. Log `image.format.group` and verify it is `ImageFormatGroup.yuv420`. On some Android devices the format group name may differ. Verify rotation metadata from `sensorOrientation` is being applied correctly. Test on the physical Tecno early — this must work before anything else.

**"Rep detection fires too easily / phantom reps"**
→ Rolling average window is too small, or threshold is too permissive. Increase `kLandmarkBufferWindowSize` from 5 to 7. Tighten the threshold constant. Test with deliberate slow movements to find the boundary.

**"Rep detection doesn't fire / misses real reps"**
→ Threshold is too strict, or likelihood filter is too aggressive. Lower `kLandmarkLikelihoodThreshold` from 0.5 to 0.4 as a test. Check that critical landmarks are not consistently below likelihood threshold for the test environment (bad lighting, partial occlusion).

**"Camera preview is black or frozen"**
→ `hardwareAccelerated="true"` missing from AndroidManifest. Or `CameraController` was not initialized before `CameraPreview` widget was built. Use `FutureBuilder` to wait for `_cameraController.initialize()` to complete.

**"Flame game covers the camera feed"**
→ `FitFusionGame` background is not transparent. Set `backgroundColor: Colors.transparent` in the FlameGame constructor or override `backgroundColor()` method.

**"Pose skeleton renders mirrored / left-right inverted"**
→ Front camera feed is horizontally mirrored on Android. Apply a horizontal flip transform in `PoseOverlayPainter`. Apply the same inversion compensation in the landmark-based calculations in `RepDetector`.

**"Gradle sync takes forever or fails on first run"**
→ First sync downloads 200–400MB. Run `flutter run -v` and wait. If it fails with a network error, run again. Do not run `flutter clean` unnecessarily — it forces a full re-sync.

**"adb device not found after phone reboot"**
→ Wireless ADB connection is lost on reboot. Reconnect: `adb tcpip 5555 && adb connect <phone-ip>:5555`

**"Google Sign-In fails with 'developer error' or error code 10"**
→ SHA-1 fingerprint is not registered in Firebase Console, or the wrong fingerprint was added. Run `cd android && ./gradlew signingReport`, copy the debug SHA-1, and register it at Firebase Console → Project Settings → Your Apps → Android App → Add Fingerprint.

**"Firebase writes fail silently"**
→ Firestore is still in test mode with a time-limited rule. Check Firestore Console → Rules. Verify test mode has not expired. For production, implement proper security rules in Milestone 5.

**"Pace timer starts immediately at round start before first rep"**
→ PaceMonitor's `start()` is being called at the wrong time. It must only be called after the **first rep** of a round is detected — not when the round begins. The `waitingForFirstRep` GamePhase exists precisely for this reason. Pace timer must not run during `waitingForFirstRep`.

**"Cooldown happens after Round 10 win instead of Victory screen"**
→ The cooldown/round-end logic is not checking the current round number. After Round 10 monster is defeated, the game must transition directly to `GamePhase.victory` — not `GamePhase.cooldown`. Add a round-number check in the round-complete handler.
