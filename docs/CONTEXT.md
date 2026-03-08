# FitFusion — Project Context Document

> **MASTER DOCUMENT — SINGLE SOURCE OF TRUTH**
> This file is authoritative over all other documentation.
> Read this file at the start of every Windsurf session before writing any code.
> Every architectural decision, design rule, gameplay rule, and constraint defined here is final
> unless explicitly updated and versioned by the project author.
> When in conflict, this file wins over ARCHITECTURE.md and WINDSURF.md.

---

## 1. Project Identity

| Field | Value |
|-------|-------|
| Project Name | FitFusion |
| Type | Android mobile application — fitness game with 2D AR overlay |
| Bundle ID | `com.wukinnin428.fitfusion` |
| Repository | `https://github.com/wukinnin/fitfusion` |
| Platform | Flutter (Dart), Android only |
| Target Device | Tecno Spark Go 30c (Android 14, budget hardware) |
| Academic Context | Capstone Project — University of Cebu Lapu-Lapu and Mandaue (UCLM) |
| Deadline | One month from project start — MVP delivery is the singular goal |

---

## 2. What FitFusion Is

FitFusion is an Android mobile application that is simultaneously a fitness tool and a 2D augmented reality game. The core concept is indivisible: **the player's physical body is the game controller. To play the game, you must exercise. To exercise effectively, the game rewards you.**

The app uses the phone's front-facing camera to detect the player's body movements in real time via Google ML Kit Pose Detection. The game renders as a 2D overlay drawn directly on top of the live camera feed, creating an augmented reality effect. The player sees themselves on screen with game elements — monsters, health bars, HUD — composited as a layer over the camera image. The body is tracked, reps are counted, and those reps drive every game mechanic.

**"Immersive"** in this project means: to interact with the game, you must physically immerse yourself in exercise. There is no other input method.

**"Augmented Reality"** in this project means: 2D game elements (sprites, health bars, HUD) rendered as an overlay on a live camera feed. NOT ARCore, NOT plane detection, NOT world anchoring, NOT 3D of any kind.

**"Augmented Gamification"** means: the visual game layer that reacts to physical input. Reps happen → the game reacts visually and mechanically.

This is an academic Capstone Project. The product must be a functioning, demonstrable MVP delivered within one month. **Every decision prioritizes a working, shippable product over architectural perfection.**

---

## 3. Formal Academic Objectives

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

---

## 4. Scope and Limitations

### In Scope — Build These
- Android mobile application only
- Camera-based motion detection via Google ML Kit Pose Detection
- 2D AR overlay game rendered by Flame on top of live camera preview
- Three selectable workout types: **Squats**, **Jumping Jacks**, **Side Oblique Crunches**
- One workout type selected per session — cannot change mid-session
- 10-round progressive survival game mode
- Guest mode — fully playable without an account, no data saved
- Google Sign-In via Firebase Auth
- Competitive leaderboard (Top 10, per workout type)
- Player statistics (per user, per workout type)
- Achievements system

### Out of Scope — Do Not Implement These
- 3D rendering of any kind
- Multiplayer of any kind (online or local)
- Narrative campaigns or story modes
- Personalization (gender, height, weight, BMI, body type)
- In-app purchases or monetization
- Push notifications
- Offline data sync or caching
- iOS, web, or desktop builds
- Settings screens beyond minimum needed for auth
- Pause functionality (there is no pause — see Misc section)

---

## 5. Complete Game Design Specification

### 5.1 Workout Selection Screen

Before any game session, the player is presented a screen with three selectable exercise options:
- **Squats**
- **Jumping Jacks**
- **Side Crunches** (Side Oblique Crunches)

The player taps one to select it. This selection is locked for the entire session — it cannot change mid-session. The selected workout type is passed into the game session and into the rep detector. Only that exercise type is detected during play.

---

### 5.2 The 10-Round Progression Loop

The game is a linear sequence of 10 rounds. Each round presents one monster. The player must defeat all 10 monsters to win the session.

#### Within a Round:
1. A cooldown period begins before the round starts (player sees ROUND X announcement + countdown timer)
2. After cooldown expires, the round begins — a monster appears with a health pool equal to `round + 1` hit points
3. The player performs reps of their chosen exercise
4. Each completed rep deals 1 damage to the monster (reduces its HP by 1)
5. Each rep triggers a sword slash animation and sound effect
6. When the monster's HP reaches 0, the round is won
7. A cooldown period begins after the round ends (Rounds 1–9 only)
8. After cooldown, the next round begins automatically

#### Rep Requirements Per Round:

| Round | Monster HP / Reps to Win |
|-------|--------------------------|
| 1     | 2                        |
| 2     | 3                        |
| 3     | 4                        |
| 4     | 5                        |
| 5     | 6                        |
| 6     | 7                        |
| 7     | 8                        |
| 8     | 9                        |
| 9     | 10                       |
| 10    | 11                       |

**Formula:** `repsRequired(round) = round + 1`
**Total reps to complete a full winning session:** 2+3+4+5+6+7+8+9+10+11 = **65 reps**

#### Cooldown Timing Rules:
- Every round (1–10) has a cooldown period **before** it starts
- Rounds 1–9 also have a cooldown period **after** the monster is defeated
- **Round 10 has NO ending cooldown** — on defeating the Round 10 monster, the Victory screen appears immediately
- `kCooldownSeconds = 15` — all cooldowns are exactly 15 seconds
- During cooldown: rep detection is paused, pace timer is paused
- Cooldown ends automatically — no player input required

---

### 5.3 The Pace Mechanic

The pace mechanic is what makes FitFusion a game rather than a simple rep counter. It enforces continuous movement and creates pressure.

**Rule:** After the first rep of a round, the player must perform each subsequent rep within **5 seconds** of the previous rep.

**Detailed Logic:**
- The pace timer does NOT start at the beginning of a round — it starts after the **first rep** of that round is detected. This gives the player time to get into position.
- After each rep is detected, the pace timer resets to 5 seconds
- If the next rep is detected within 5 seconds → timer resets, no penalty
- If 5 seconds elapse with no rep detected → monster attacks → player loses 1 life → timer resets → player must continue (round does not restart, rep progress is not lost — only a life is lost)
- The pace timer is paused during cooldown periods
- `kPaceThresholdSeconds = 5.0`

**Visual Representation (Pace Timer):**
- Displayed as a circular pie-chart countdown in the upper-right corner
- Shows the remaining seconds as a number inside the circle
- **Green** when within pace (time remaining)
- Gradually transitions to and flashes **solid red** when falling behind
- Shows "0" and solid red at the moment of pace failure (life lost)

---

### 5.4 Lives System

- Player starts each game with **3 lives** — displayed as 3 cyan pixel heart icons in the HUD
- Each monster attack (pace failure) costs 1 life → one heart goes dark/empty (rightmost first)
- Lives carry across all rounds for the entire session — they do not reset between rounds
- Lives cannot be recovered or gained during a session
- At 0 lives: game over, player loses, Defeat screen appears
- `kStartingLives = 3`

**Damage Visual Feedback:**
- On life loss: full-screen red tint filter applied over everything (Doom-style damage flash)
- The red tint affects the camera feed, all HUD elements, and all game sprites simultaneously
- The tint is brief and then clears

---

### 5.5 Win and Lose Conditions

| Condition | Outcome |
|-----------|---------|
| Monster defeated in Round 10 | **Victory** — Victory screen shown immediately (no end cooldown) |
| All 3 lives lost at any point | **Defeat** — Defeat screen shown immediately |

Neither condition is reversible mid-session. On win or lose, the session ends and the Results screen is shown.

---

### 5.6 Cooldown Screen

- Duration: 15 seconds (`kCooldownSeconds = 15`)
- Triggered before each round begins AND after each round ends (Rounds 1–9)
- Round 10: cooldown before it begins, but NO cooldown after (Victory screen instead)
- Visual: semi-transparent dark overlay over the camera feed
- Shows the round number announcement prominently (e.g., "ROUND 1")
- Shows the large circular pie countdown timer centered on screen (counts from 15 down to 0)
- Bottom HUD elements (hearts, exercise label) persist visibly during cooldown
- Rep detection paused, pace timer paused for full duration
- Cooldown ends automatically

---

### 5.7 Results Screens

Both Victory and Defeat share the same structural layout. The camera feed remains active and visible in the background during results. The pose skeleton overlay also persists (in debug builds).

**Shared Layout:**
- Semi-transparent dark card overlay in the upper portion of the screen
- Title text (VICTORY or DEFEAT) in large bold serif font
- Stats block — left-aligned labels, right-aligned values
- Two gold pill buttons: **RETRY** and **QUIT**
- Bottom HUD: hearts (in their final state), exercise label pill

**VICTORY Screen:**
- Title: "VICTORY" in bright green
- Background tint: dark green
- Stats displayed:
  - `Session Time` — total elapsed time (MM:SS.mm format)
  - `Total Reps` — shown as `65/65`
  - `Average rep/sec` — average interval between reps (00:SS.mm format)
  - `Fastest rep/sec` — fastest single rep interval this session
- Flavour text below stats: *"You defeated all 10 monsters!"*
- No "Last round" field (irrelevant — all 10 were completed)

**DEFEAT Screen:**
- Title: "DEFEAT" in red
- Background tint: dark red
- Stats displayed:
  - `Session Time` — total elapsed time
  - `Total Reps` — shown as `X/65`
  - `Average rep/sec`
  - `Fastest rep/sec`
  - `Last round` — the round number reached before defeat
- No flavour text

**Button Behavior:**
- RETRY → restarts the game with the **same workout type** (goes directly back to game, not WorkoutSelectScreen)
- QUIT → returns to HomeScreen

---

### 5.8 HUD Layout (Gameplay Proper — Portrait Orientation)

```
┌──────────────────────────────────────────────┐
│  [HEALTH BAR — full width, top of screen]    │  ← Red fill, black border, shrinks left→right
│                                              │
│  [MONSTER]     [X / Y REPS]    [PACE TIMER] │  ← Upper row
│  upper-left    center pill     upper-right   │
│                                              │
│  [LIVE CAMERA FEED — player visible]         │  ← Full screen background
│  [POSE SKELETON OVERLAY — debug only]        │
│                                              │
│                                              │
│              [ROUND X]                       │  ← Lower center pill (gold text)
│           [♥  ♥  ♥]                         │  ← Cyan pixel hearts
│           [EXERCISE NAME]                    │  ← Bottom pill (gold text)
└──────────────────────────────────────────────┘
```

**HUD Element Details:**
- **Health Bar:** Full-width, pinned to very top of screen. Red fill on dark/black background with decorative border. Shrinks proportionally as monster HP is depleted.
- **Monster Sprite:** Upper-left corner. 64×96px. Randomly selected from 10 of the 20 available `SPR_monster_*.png` sprites (non-repeating per session). Changes with each new round.
- **Rep Counter:** Center, pill-shaped dark background. Format: `"X / Y REPS"` in white bold text. X = current reps this round, Y = reps required this round.
- **Pace Timer:** Upper-right corner. Circular pie-chart countdown. Green → red as time decreases. Shows remaining seconds as a number. Solid red + "0" on pace failure.
- **Round Label:** Lower-center pill. Format: `"ROUND X"`. Gold/yellow text on dark pill with rounded border.
- **Lives Display:** Below round label. 3 cyan pixel hearts. Rightmost heart empties first on life loss.
- **Exercise Label:** Bottom pill. Shows selected workout name (e.g., "SIDE CRUNCHES"). Gold text on dark pill.

---

### 5.9 Misc Rules

- Pressing the back button, home button, or recent apps/overview button **during an ongoing gameplay session immediately ends the session** — all player lives are forcibly lost and the Defeat screen is shown. There is no pause. There is no way to resume a session once interrupted. This is intentional by design.
- No pause function exists anywhere in the game. This cannot be added as a feature — it is a deliberate anti-cheat mechanic.

---

## 6. Sprite and Asset Specification

### Monster Sprites
- 20 total monster sprites: `SPR_monster_01.png` through `SPR_monster_20.png`, located in `assets/Sprites/Monsters-64x96px/`
- Per session: 10 are randomly drawn from the 20, non-repeating within that session
- One new monster is shown per round (10 rounds = 10 different monsters per session)
- Sprites are 64×96px, PNG with transparent background
- Displayed in upper-left corner of the game screen

### Sword Slash Animation
- Triggered on every successful rep (each rep = one sword "attack" on the monster)
- Animation played from sprite sheets in `assets/Sprites/Sword-64x64px/`:
  - `SPR_sword_sprite_sheet_01.png`
  - `SPR_sword_sprite_sheet_02.png`
  - `SPR_sword_sprite_sheet_03.png`
- One sheet is selected at random per rep (repeatable — same sheet can play twice in a row)
- Sprite sheet frame dimensions: 64×64px

### HUD Sprites
- **Health Bar** — located in `assets/Sprites/PixelHealthBar-128x16px/`. Five component files:
  - `SPR_bar_emptyHealthBar.png` — empty bar frame
  - `SPR_bar_healthBar.png` — filled bar frame
  - `SPR_bar_health.png` — health fill segment
  - `SPR_bar_noHealthBar.png` — no-health bar frame
  - `SPR_bar_noHealth.png` — depleted fill
- **Hearts** — `SPR_heart-sprite-sheet-48x24px.png` — cyan/full when life available, dark/empty when life lost
- **Logo** — `SPR_logo_fitfusion-752x752px.png` — used in main menu UI only, never during gameplay

### Audio — Exact File Reference

All audio files are located under `assets/Audio/`.

**SFX (`assets/Audio/SFX/`):**
- `SFX_Click.mp3` — UI button interaction sound (note capital C)
- `SFX_sword_01.mp3` through `SFX_sword_05.mp3` — rep hit sounds (5 files, select random)
- `SFX_win_violin_win_5.mp3` — round won
- `SFX_victory_winning.mp3` — session victory
- `SFX_lose_violin_lose_4.mp3` — session defeat

**ST — Soundtrack (`assets/Audio/ST/`):**
- `ST_BATTLE_ob-lix-beats_dark_pagan_norse.mp3` — loops during active round
- `ST_COOLDOWN_medieval_horizons_squire.mp3` — fades in/out during cooldown periods
- `ST_MAIN_medieval_horizons_quiet_repose.mp3` — loops on main menu

**VO — Voice Over (`assets/Audio/VO/`):**
- `VO_announcerWin_BERSERK.mp3` — round win call (random from 5)
- `VO_announcerWin_DECIMATION.mp3`
- `VO_announcerWin_FEROCITY.mp3`
- `VO_announcerWin_SAVAGERY.mp3`
- `VO_announcerWin_VICIOUS.mp3`
- `VO_announcerVictory_VICTOR.mp3` — session victory call (single file)
- `VO_announcerLose_DISAPPOINTING.mp3` — session defeat call (random from 4)
- `VO_announcerLose_GAME OVER.mp3`
- `VO_announcerLose_PATHETIC.mp3`
- `VO_announcerLose_YOU DIED.mp3`
- `VO_monsterRoar_01.mp3` through `VO_monsterRoar_10.mp3` — monster death (10 files, non-repeating per session)
- `VO_playerGrunts_01.mp3` through `VO_playerGrunts_10.mp3` — player life lost (10 files, random repeating)

### Audio Sequences

**Round Won (Player Continue):**
1. `SFX_win_violin_win_5.mp3`
2. Random `VO_announcerWin_*.mp3` (select from the 5 available)
3. `ST_COOLDOWN_medieval_horizons_squire.mp3` for cooldown duration

**Session Victory:**
1. `SFX_victory_winning.mp3`
2. `VO_announcerVictory_VICTOR.mp3`
3. `ST_COOLDOWN_medieval_horizons_squire.mp3` on loop until screen exited

**Session Defeat:**
1. `SFX_lose_violin_lose_4.mp3`
2. Random `VO_announcerLose_*.mp3` (select from the 4 available)
3. `ST_COOLDOWN_medieval_horizons_squire.mp3` on loop until screen exited

**Life Lost:**
- Random `VO_playerGrunts_*.mp3` on each life loss (select from the 10 available, repeatable)

---

## 7. Gamification Systems

### 7.1 Leaderboard

Three separate leaderboards — one per workout type. Each shows the Top 10 entries.

**Two metrics tracked per leaderboard:**
- **Fastest Session Time** — shortest time in seconds to complete a full 10-round winning session (win required)
- **Fastest Rep Pace** — shortest single rep interval (seconds) recorded across all sessions

Only signed-in users appear. Guest sessions never post to any leaderboard. A user's entry is updated only if the new session beats their current personal best.

**Firestore path:**
- `/leaderboard/{workoutType}/fastest_session/{uid}`
- `/leaderboard/{workoutType}/fastest_pace/{uid}`

---

### 7.2 Player Statistics

Displayed on a profile/stats screen. Split per workout type, with totals shown alongside.

**Metrics tracked per workout type:**
- Personal best session time (seconds) — wins only
- Personal best rep pace (seconds per rep)
- Average session time (seconds)
- Average rep pace (seconds per rep)
- Total sessions played
- Total rounds played
- Total minutes played in-game

**Firestore path:** `/users/{uid}/stats/{workoutType}`

---

### 7.3 Achievements

Unlockable milestones stored per user. Checked and written to Firestore at session end.

| Achievement ID | Display Name | Unlock Condition |
|----------------|--------------|-----------------|
| `first_blood` | First Blood | Complete your first game session (win or lose) |
| `dragonslayer` | Dragonslayer | Win a full 10-round session for the first time |
| `untouchable` | Untouchable | Win a session without losing a single life |
| `speed_demon` | Speed Demon | Achieve a rep pace under 1.5 seconds |
| `iron_will` | Iron Will | Play 10 total sessions |
| `the_long_road` | The Long Road | Accumulate 30 total minutes of in-game time |

**Firestore path:** `/users/{uid}/achievements/{achievementId}`

---

## 8. Authentication and User State

### Two User States

**Guest (Unauthenticated):**
- All game mechanics work fully
- Leaderboard visible (read-only) — cannot post to it
- Stats screen shows a sign-in prompt
- Achievements visible but locked
- No data written to Firestore

**Signed-In (Google Account via Firebase Auth):**
- All guest capabilities, plus:
- Session data written to Firestore after each session
- Leaderboard updated if session sets a new personal best
- Stats updated after each session
- Achievements checked and unlocked after each session

### Auth Rules
- Sign-in is never forced — game is fully playable as a guest
- Google Sign-In is the **only** authentication provider
- On sign-in: create `/users/{uid}` document if it does not exist
- Handle sign-out gracefully — no crash, return to guest state
- Sign-in is presented as value-add: "Sign in to save your progress and compete"

---

## 9. Visual Design Specification

### Theme: High Fantasy
Bright, vibrant, heroic. References: classic JRPG meets Western high fantasy — think Final Fantasy, early Dragon Quest, Elder Scrolls aesthetic. Colorful, ornate, golden, heroic.

NOT: dark/gritty, desaturated, horror, steampunk, sci-fi.

### Color Palette

| Role | Color | Hex |
|------|-------|-----|
| Primary Accent | Gold | `#FFD700` |
| Danger / Defeat | Red | `#CC0000` (or similar deep red) |
| Background / Panels | Dark Gray | `#21201E` |
| Text / Clean UI | White | `#FFFFFF` |
| Lives / Accents | Cyan | (pixel heart sprites — use sprite color) |
| Victory | Bright Green | (Victory screen title color) |

Gold is the dominant UI accent. Red communicates damage/defeat. Black frames and panels. White for primary text. These four are the core palette — apply consistently.

### Typography
- **Display / headers / titles:** Cinzel (Google Fonts) — serif, classical Roman letterform, heroic feel
- **HUD / body text:** Cinzel Decorative or fallback system serif
- Damage numbers: large, bold, gold, floating upward animation
- Button text: Cinzel, bold, white on gold pill background

### UI Styling (from mockups)
- Buttons: rounded pill shape, gold fill, white bold text (RETRY, QUIT, exercise options)
- Labels/tags: dark pill with rounded border, gold text (ROUND X, exercise name)
- Rep counter pill: dark background, white bold text, center-screen placement
- Results card: semi-transparent dark rounded card, full stats block inside
- All interactive UI elements use `SFX_Click.mp3` on tap

### Main Menu
- Primary colors: Red and Black (`#21201E`), complemented by Gold and White accents
- Background music: `ST_MAIN_medieval_horizons_quiet_repose.mp3` on loop
- `SPR_logo_fitfusion-752x752px.png` used here — not during gameplay proper
- All button taps use `SFX_Click.mp3`

---

## 10. Technical Constraints (Mandatory Rules)

### The Hardware Constraint
**Target device: Tecno Spark Go 30c (Android 14, budget tier).** Every performance decision is made for this device. If it works on a flagship but lags on the Tecno, the Tecno wins and the code changes.

### Performance Rules
1. ML Kit Pose Detection must not be called on every camera frame — process **every 2nd frame minimum** (`kFrameSkipCount = 2`)
2. Camera feed input to ML Kit must be **640×480 or lower resolution**
3. Frame processing (ML Kit inference) must run **off the main thread** — use `compute()` or an `Isolate`
4. Flame targets 60 FPS but must degrade gracefully — never block the game loop with I/O
5. Dispose of `CameraController` and `PoseDetector` properly on widget disposal to prevent memory leaks
6. Firebase writes happen **after session end only** — never during active gameplay

### ML Kit Rules
- Use `PoseDetectionMode.stream` for live detection
- Use the **base model** (not accurate model — too slow for budget hardware)
- 33 landmarks returned per frame, each with normalized `x`, `y`, `z`, and `likelihood`
- **Always check `likelihood >= 0.5` before using any landmark** — below this is unreliable, skip that frame's contribution
- Landmark coordinates are normalized (0.0–1.0) relative to image dimensions
- Front camera feed is horizontally mirrored on Android — compensate in overlay painter and in landmark calculations (left/right may be inverted in raw data)

### Architecture Rules
1. No business logic in widget files — widgets render state, they do not compute it
2. The Flame game does not import Firebase — game logic and backend are fully decoupled
3. The rep detector does not import Flame — it emits events via stream only
4. All inter-layer communication uses `Stream<T>` — each layer is independent
5. All Firebase calls are wrapped in `try/catch` — Firebase failures must never crash the game
6. All magic numbers are constants in `constants.dart` — never hardcode game parameters inline

### Code Style Rules
- Dart file names: `snake_case.dart`
- Class names: `PascalCase`
- Constants: prefix `k`, camelCase — e.g., `kPaceThresholdSeconds`, `kTotalRounds`
- Enum types and values: `PascalCase` — e.g., `WorkoutType.squats`, `GamePhase.cooldown`
- Private members: prefix `_`
- No `print()` in production — use `debugPrint()` wrapped in `assert`
- Prefer `const` constructors wherever possible

---

## 11. Complete File and Directory Structure

```
fitfusion/
├── lib/
│   ├── main.dart                          # App entry point. Initializes Firebase, wraps app in providers.
│   ├── firebase_options.dart              # Auto-generated by FlutterFire. DO NOT EDIT.
│   ├── app.dart                           # MaterialApp root, theme, routing.
│   │
│   ├── core/
│   │   ├── constants.dart                 # ALL game constants. The only place numbers live.
│   │   ├── enums.dart                     # WorkoutType, GamePhase, AchievementId, PaceEventType, LeaderboardType.
│   │   ├── extensions.dart                # Dart extension methods (e.g., WorkoutType.displayName, .firestoreKey).
│   │   └── theme.dart                     # AppTheme — colors, fonts, text styles, button styles.
│   │
│   ├── features/
│   │   │
│   │   ├── auth/
│   │   │   ├── auth_service.dart          # Firebase Auth + Google Sign-In logic.
│   │   │   └── auth_provider.dart         # ChangeNotifier exposing auth state to widgets.
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
│   │   │   ├── game_session.dart          # Immutable data class capturing session result for Firebase.
│   │   │   │
│   │   │   └── components/
│   │   │       ├── monster_component.dart       # Monster sprite, idle/hit animation.
│   │   │       ├── monster_health_bar.dart      # Red health bar, shrinks with HP.
│   │   │       ├── sword_slash_component.dart   # Sword slash animation on rep, random sprite sheet.
│   │   │       ├── player_lives_display.dart    # Row of 3 cyan pixel hearts, updates on life lost.
│   │   │       ├── round_banner.dart            # "ROUND X" pill label.
│   │   │       ├── rep_progress_bar.dart        # "X / Y REPS" center pill counter.
│   │   │       ├── damage_number.dart           # Floating damage popup, fades/rises and auto-removes.
│   │   │       ├── cooldown_overlay.dart        # Full-screen dim overlay during cooldown with countdown.
│   │   │       └── pace_timer_indicator.dart    # Circular pie countdown, green→red urgency.
│   │   │
│   │   ├── firebase/
│   │   │   ├── firestore_service.dart     # All Firestore reads and writes in one place.
│   │   │   ├── leaderboard_service.dart   # Leaderboard-specific queries and writes.
│   │   │   └── stats_service.dart         # Player stats calculations and writes.
│   │   │
│   │   └── screens/
│   │       ├── splash_screen.dart         # App startup — auth check, route to home.
│   │       ├── home_screen.dart           # Main menu: Play, Leaderboard, Stats, Sign In/Out.
│   │       ├── workout_select_screen.dart # Choose Squats / Jumping Jacks / Side Crunches.
│   │       ├── game_screen.dart           # Game screen: camera preview + Flame GameWidget overlay.
│   │       ├── results_screen.dart        # Post-session: win/lose, stats, Firebase write trigger.
│   │       ├── leaderboard_screen.dart    # Top 10 display, tab per workout type.
│   │       └── stats_screen.dart          # Personal stats per workout type.
│   │
│   └── widgets/
│       ├── camera_preview_widget.dart     # Sized camera preview filling the screen.
│       ├── pose_overlay_painter.dart      # CustomPainter drawing landmark skeleton (debug only).
│       └── fantasy_button.dart            # Reusable styled gold pill button.
│
├── assets/
│   ├── sprites/                           # Monster sprites, sword slash sprites, HUD sprites (PNG)
│   ├── audio/                             # ST (soundtrack), SFX (sound effects), VO (voice-over) (MP3)
│   └── fonts/                             # Cinzel and CinzelDecorative font files
│
├── android/
│   └── app/
│       ├── google-services.json           # Firebase Android config. Auto-generated. Do not edit.
│       └── src/main/AndroidManifest.xml   # Camera permission, internet permission, hardwareAccelerated.
│
├── CONTEXT.md                             # This file — master source of truth.
├── ARCHITECTURE.md                        # Data flow, system design, technical detail.
├── WINDSURF.md                            # Windsurf AI session guide, milestones, prompts.
├── pubspec.yaml
└── .gitignore
```

---

## 12. Firebase Data Model (Complete)

### `/users/{uid}`
Created on first sign-in.
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
  roundsCompleted: number,        // 0–10
  lastRound: number,              // round number at session end (10 if won, 1–9 if defeated)
  bestRepPaceSeconds: number,     // fastest single rep interval this session
  avgRepPaceSeconds: number,
  livesLost: number               // 0–3
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
  bestSessionTimeSeconds: number, // only updated if won == true
  bestRepPaceSeconds: number,
  avgSessionTimeSeconds: number,
  avgRepPaceSeconds: number
}
```

### `/users/{uid}/achievements/{achievementId}`
Written once when first unlocked. Never overwritten.
```
{
  achievementId: string,
  unlockedAt: Timestamp,
  workoutType: string | null
}
```

### `/leaderboard/{workoutType}/fastest_session/{uid}`
Overwritten only when new session time beats the existing entry.
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
Overwritten only when new pace beats the existing entry.
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

## 13. Key Constants Reference

All defined in `lib/core/constants.dart`. Never use raw numbers anywhere else in the codebase.

```
// Game Rules
kTotalRounds = 10
kStartingLives = 3
kPaceThresholdSeconds = 5.0
kCooldownSeconds = 15

// Rep formula — repsRequired(round) = round + 1 (implemented as a function)

// Camera / ML Kit Performance
kFrameSkipCount = 2
kLandmarkLikelihoodThreshold = 0.5

// Rep Detection Thresholds (normalized 0.0–1.0, tuned via physical device testing)
kSquatHipDropThreshold = 0.15
kJumpingJackWristRaiseThreshold = 0.08
kCrunchWristHipProximityThreshold = (to be tuned via device testing)
kLandmarkBufferWindowSize = 5

// Leaderboard
kLeaderboardSize = 10

// Achievement Thresholds
kSpeedDemonPaceThreshold = 1.5      // seconds
kIronWillSessionsThreshold = 10     // total sessions
kLongRoadMinutesThreshold = 30      // total minutes

// Firebase
kFirebaseRegion = 'asia-southeast1'

// Achievement IDs (must match Firestore document IDs exactly)
kAchievementFirstBlood = 'first_blood'
kAchievementDragonslayer = 'dragonslayer'
kAchievementUntouchable = 'untouchable'
kAchievementSpeedDemon = 'speed_demon'
kAchievementIronWill = 'iron_will'
kAchievementTheLongRoad = 'the_long_road'
```

---

## 14. Enums Reference

All defined in `lib/core/enums.dart`.

```
WorkoutType: squats | jumpingJacks | obliqueCrunches
GamePhase: waitingForFirstRep | playing | cooldown | victory | defeat
PaceEventType: repOnTime | paceFailed
LeaderboardType: fastestSession | fastestPace
AchievementId: firstBlood | dragonslayer | untouchable | speedDemon | ironWill | theLongRoad
```

---

## 15. Screen Navigation Flow

```
App Launch
  └─→ SplashScreen (auth check)
        └─→ HomeScreen

HomeScreen
  ├─→ [Play] → WorkoutSelectScreen
  │     └─→ [Select Workout] → GameScreen
  │           └─→ (session ends) → ResultsScreen
  │                 ├─→ [RETRY] → GameScreen (same workout type, no WorkoutSelectScreen)
  │                 └─→ [QUIT] → HomeScreen
  ├─→ [Leaderboard] → LeaderboardScreen
  ├─→ [Stats] → StatsScreen (or sign-in prompt if guest)
  └─→ [Sign In / Sign Out] → Auth flow (modal/bottom sheet, no dedicated screen)
```

All navigation uses Flutter's `Navigator`. Named routes defined in `app.dart`.
