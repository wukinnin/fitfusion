# PRIORITY FILE; Gameplay Manual

## /assets contents directory layout

**"Asset Integration" section is referring to files in `tree assets/`"**

```
assets/
├── audio
│   ├── music
│   │   ├── battle.mp3
│   │   ├── cooldown_period.mp3
│   │   └── main_menu.mp3
│   ├── sfx
│   │   ├── lose_violin.mp3
│   │   ├── sword_01.mp3
│   │   ├── sword_02.mp3
│   │   ├── sword_03.mp3
│   │   ├── sword_04.mp3
│   │   ├── sword_05.mp3
│   │   ├── victory_end.mp3
│   │   └── win_violin.mp3
│   └── vo
│       ├── announcer_lose_disappointing.mp3
│       ├── announcer_lose_game_over.mp3
│       ├── announcer_lose_pathetic.mp3
│       ├── announcer_lose_you_died.mp3
│       ├── announcer_victory_victor.mp3
│       ├── announcer_win_berserk.mp3
│       ├── announcer_win_decimation.mp3
│       ├── announcer_win_ferocity.mp3
│       ├── announcer_win_savagery.mp3
│       ├── announcer_win_vicious.mp3
│       ├── monster_roar_01.mp3
│       ├── monster_roar_02.mp3
│       ├── monster_roar_03.mp3
│       ├── monster_roar_04.mp3
│       ├── monster_roar_05.mp3
│       ├── monster_roar_06.mp3
│       ├── monster_roar_07.mp3
│       ├── monster_roar_08.mp3
│       ├── monster_roar_09.mp3
│       ├── monster_roar_10.mp3
│       ├── player_grunts_01.mp3
│       ├── player_grunts_02.mp3
│       ├── player_grunts_03.mp3
│       ├── player_grunts_04.mp3
│       ├── player_grunts_05.mp3
│       ├── player_grunts_06.mp3
│       ├── player_grunts_07.mp3
│       ├── player_grunts_08.mp3
│       ├── player_grunts_09.mp3
│       └── player_grunts_10.mp3
└── images
    ├── monsters
    │   ├── monster_01.png
    │   ├── monster_02.png
    │   ├── monster_03.png
    │   ├── monster_04.png
    │   ├── monster_05.png
    │   ├── monster_06.png
    │   ├── monster_07.png
    │   ├── monster_08.png
    │   ├── monster_09.png
    │   └── monster_10.png
    ├── sword
    │   ├── sword_sheet_01.png
    │   ├── sword_sheet_02.png
    │   └── sword_sheet_03.png
    └── ui
        ├── bar_empty.png
        ├── bar_health.png
        ├── bar_no_health.png
        └── heart_sheet.png

9 directories, 58 files
```

---

# Gameplay Loop

## Workout Selection Screen 
Before any game session, the player is shown a screen with three options:
- **Squats**
- **Jumping Jacks**
- **Side Crunches**

The player taps one to select it. This selection persists for the entire session. The game is built around whichever type the player picks. The workout type is passed into the game session and into the rep detector — only that exercise type is detected during play.

## The 10-Round Progression Loop

The game is a linear sequence of 10 rounds. Each round presents one monster. The player must defeat all 10 to win.

**Within a round:**
1. A monster appears with a health pool equal to `round + 1` hit points
2. The player must perform the reps of their chosen exercise within at least 5 seconds of each other
3. Each completed rep deals 1 damage to the monster (reduces its health by 1)
4. When the monster's health reaches 0, the round is won
5. A cooldown period of 15 seconds begins.
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

### Asset Integration: assets/images/ui

#### Health Bar (assets/images/ui/bar_*.png)
- Display on Top Center, with space to the left to accommodate for monster sprite
- Shrinks relevant to Monster/Rep count HP. 
- Tied to Rep Counter

#### Monsters (assets/images/monster/monster_*.png)
- Displayed on the upper left corner.
- Monsters are displayed at random with no repetition linearly.
- Tied to Pace Detection

#### Sword (assets/images/ui/sword/sword_sheet_*.png)
- Upon each successful rep, is an "attack" on the monster.
- A sword slash animation is played for each successful "attack".
- Sprites are sequenced linearly for each hit (play sheet_01, sheet02, sheet03; rinse and repeat)
- Tied to Pace Detection

### Asset Integration: assets/audio

- Round begins immediately playing ST: `audio/music/battle.mp3`; on loop.
- Sword damaging a monster plays a random repeating SFX: `audio/sfx/sword_*.mp3`
- Monsters that are "slain" plays a random non-repeating VO: `audio/vo/monster_roar_*.mp3`

---

### Pace Mechanic

The pace mechanic is what makes FitFusion a game rather than a rep counter. It enforces continuous movement.

**Rule:** After the first rep of a round, the player must perform each subsequent rep within **5 seconds** of the previous rep.

### Pace Timer (coded in)

- A visualized countdown timer is displayed on the top right corner
- It counts down from 5 sec to 0 sec, relative to the pace mechanic logic
- It is green when in pace, then gradually fades to and flashes solid red when falling behind

**Implementation logic:**
- The pace timer does not start at the beginning of a round — it starts after the first rep of that round is detected. This gives the player time to get into position.
- If the next rep is detected within 5 seconds after any given rep → timer resets, no penalty
- If 5 seconds elapse with no rep detected → monster attacks → player loses 1 life → timer resets and the player must continue (round does not restart, progress is not lost — only a life is lost)
- The pace timer is paused during cooldown periods

---

### Lives System

- Player starts each game with **3 lives** — displayed as 3 cyan heart icons in the HUD
- Each monster attack (pace failure) costs 1 life → one heart goes dark/empty
- **Lives carry across all rounds for the entire session** — they do not reset between rounds
- Similar to Doom (1993), when the player takes damage, the screen goes to a brief red filter. 
- Lives cannot be recovered or gained during a session
- At 0 lives: game over, player loses, must retry from Round 1

**Lives constant:** `kStartingLives = 3`

### Asset Integration

- `images/ui/heart_sheet.png` — Spritesheet for active and inactive hearts.
- Plays audio of a random and repeating `audio/vo/player_grunts_*.mp3` file whenever a player loses life.

---

### Cooldown Period

Duration: 15 seconds (`kCooldownSeconds = 15`)

- Rep detection, and pace timer is paused throughout the duration
- Triggered before each round begins, and after a successful round (Rounds 1-9)
- Rounds 1-10 have a cooldown period before a round
- Round 10 does not have an ending cooldown period
- Player can use this time to rest and prepare
- Cooldown sequence initiates automatically — no player input required.

#### Cooldown Period Screen
- Screen is overlaid with black opacity at ~25%
- A timer ticks down from 15 secs - 0 secs as is the duration.
- Header that displays the next round number

### Asset Integration
- Plays a very faint background music `audio/music/cooldown_period.mp3`.
- Cued to fade in and fade out in time with the cooldown period duration.

---

### Win and Lose Conditions [CONJUNCTION WITH COOLDOWN SCREEN]

| Condition | Event |
|-----------|-------|
| Defeat monster after any round | Player continue — proceed to cooldown period screen, game continue |
| Defeat monster in Round 10 | Player victory — show victory screen, game over |
| Lose all 3 lives at any point | Player defeated — show defeat screen , game over |

Neither condition is reversible mid-session.

#### Victory Screen
- Screen is tinted green at ~25% opacity
- Header: "VICTORY" in green
- Displays stats:
    - Session Time (minutes:secs.milliseconds)
    - Total Reps (total reps/total reps)
    - Average rep/sec (minutes:secs.milliseconds)
    - Fastest rep/sec (minutes:secs.milliseconds)
- Subtext: "You have defeated all 10 monsters!"
- Shows "Retry" and 'Quit" button, each with "Are you sure you want to [X]?" confirmation screen?

#### Defeat Screen
- Screen is tinted red at ~25% opacity
- Header: "DEFEAT" in red
- Displays stats:
    - Session Time (minutes:secs.milliseconds)
    - Total Reps (last rep number/total reps)
    - Average rep/sec (minutes:secs.milliseconds)
    - Fastest rep/sec (minutes:secs.milliseconds)
    - Last round (last round/total rounds)
- Subtext: "You have failed to keep up!"
- Shows "Retry" and 'Quit" button, each with "Are you sure you want to [X]?" confirmation screen?

### Asset Integration: Audio Sequences [in order]

Executed one after the other.

**Player Continue**
1. Play `audio/sfx/win_*.mp3`
2. Play any random and repeating `audio/vo/announcer_win_*.mp3` file.
3. Execute Cooldown Period screen + music

**Player Victory**
1. Play `audio/sfx/victory_*.mp3`
2. Play the `audio/vo/announcer_victory_*.mp3` file 
3. Execute Victory screen + `audio/music/cooldown_period.mp3` in loop until player quits or retries.


**Player Defeated**
1. Play `audio/sfx/lose_*.mp3`
2. Play any random and repeating `audio/vo/announcer_lose_*.mp3` file 
3. Execute Defeat screen + `audio/music/cooldown_period.mp3` in loop until player quits or retries.

---

### Screens and Gameplay Flow

PSEUDO LOGIC

1. Launch Game
2. Select from (3) Workout Types: Squats, Jumping Jacks, Side Crunches
3. Gameplay Begins (Gameplay Proper screen)

while Round > 9
{
1. Cooldown period Screen (give player time to prepare)
2. Gameplay proper (with all conditions and game mechanics in place)
3. if winRound = true, then Cooldown Period screen +  Audio sequence (Continue)
}

if round = 10
{
1. Cooldown period
2. Gameplay proper
3. if winRound = true, then Victory screen +  Audio sequence (victory)
}

If at any point the player fails to rep, the player takes damage, and loses a life, show damage screen red filter thing.
Take enough damage, and lose all life, then show defeat screen. +  Audio sequence (Lose)

---

### MISC

- In gameplay proper, is a hands-free experience.
- Pressing back button, home button, or recent apps/overview button immediately ends the session to the defeat screen anywhere during gameplay proper, and all player lives are lost (There is no such pause or exit function mid game; this is by design)
- All screens/gameplay mockup screenshots are located in `fitfusion/docs/*.png`, and is the basis for most description. May include visual elements unexpounded upon verbally.
    - `gameplay_proper.png` — Proper game session
    - `gameplay_life_lost.png`— During gameplay proper, when player loses a life.
    - `gameplay_cooldown_period.png` — During a cooldown period
    - `gameplay_defeat.png` — Defeat screen, after gameplay session
    - `gameplay_victory.png` — Victory screen, after gameplay session


