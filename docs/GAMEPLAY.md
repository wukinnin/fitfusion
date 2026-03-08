# PRIORITY FILE; Gameplay Manual

## /assets contents directory layout

**"Asset Integration" section is referring to files in `/assets`"**

```
Sprites

PNGs under `/sprites` are either sprite sheets or otherwise individual frames/layouts

        - Monsters-64x96px
        - Sword-64x64px
    
    HUD
        - PixelHealthBar-128x16px
        - `Heart-sprite-sheet-48x24px.png`

    Audio
        - ST (Soundtrack)
        - SFX (Sound Effects)
        - VO (Voice-Over)
```

---

# Gameplay Loop

## Workout Selection Screen 
Before any game session, the player is shown a screen with three options:
- **Squats**
- **Jumping Jacks**
- **Side Crunches**

The player taps one to select it. This selection persists for the entire session. The game is built around whichever type the player picks. The workout type is passed into the game session and into the rep detector — only that exercise type is detected during play.

## The 10-Round Progression Loop [GAMEPLAY PROPER SCREEN]

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

### Asset Integration

#### HUD
##### PixelHealthBar-128x16px
- Display on Top Center, with space to the left to accommodate for monster sprite
- Shrinks relevant to Monster/Rep count HP. 
- Child of Rep Counter

#### Sprites
##### Monsters-64x96px
- Displayed on the upper left corner.
- Monster PNG is randomly selected from 20 available options from `SPR_monster_*.png`
- Non-repeating sprite for any given session.
- Child of Pace Detection + Rep Counter
##### Sword-64x64px 
- Upon each successful rep, is an "attack" on the monster.
- A random and repeatable Sword Slash animation is played to visualize a successful rep or "hit"
- Animation is played accompanied by random from `SPR_sword_sprite_sheet_*.png`
- Random repeating sword animation sprite sheets 01-03.
- Child of Pace Detection + Rep Counter

#### Audio
##### SFX
- Round begins immediately playing ST: `ST_BATTLE*.mp3`; on loop.
##### VO
- Sword damaging a monster plays a random repeating SFX: `SFX_sword_*.mp3`
- Monsters that are slain plays a random non-repeating VO: `VO_monsterRoar_*.mp3`

---

### The Pace Mechanic [GAMEPLAY PROPER SCREEN]

The pace mechanic is what makes FitFusion a game rather than a rep counter. It enforces continuous movement.

**Rule:** After the first rep of a round, the player must perform each subsequent rep within **5 seconds** of the previous rep.

**Implementation logic:**
- The pace timer starts after each rep is registered
- If the next rep is detected within 5 seconds → timer resets, no penalty
- If 5 seconds elapse with no rep detected → monster attacks → player loses 1 life → timer resets and the player must continue (round does not restart, progress is not lost — only a life is)
- The pace timer is paused during cooldown periods
- The pace timer does not start at the beginning of a round — it starts after the first rep of that round is detected. This gives the player time to get into position.

#### Timer (coded in)
- A visualized countdown stop watch timer is displayed on the top right corner
- It counts down from 5 sec to 1 sec, relative to the pace mechanic logic
- It is green when in pace, then gradually fades to and flashes solid red when falling behind
- Child of Pace Counter Logic

**Pace threshold constant:** `kPaceThresholdSeconds = 5`

---

### Lives System [GAMEPLAY PROPER SCREEN]

- Player starts each game with **3 lives** — displayed as 3 cyan heart icons in the HUD
- Each monster attack (pace failure) costs 1 life → one heart goes dark/empty
- **Lives carry across all rounds for the entire session** — they do not reset between rounds
- Similar to Doom (1993), when the player takes damage, the screen goes to a brief red filter. 
- Lives cannot be recovered or gained during a session
- At 0 lives: game over, player loses, must retry from Round 1
- Child of Pace Counter Logic

**Lives constant:** `kStartingLives = 3`

### Asset Integration
#### HUD
##### Heart-sprite-sheet-48x24px.png
- Cyan and full when life is available
- Dark and empty when life is lost

#### Audio
##### VO
- Plays a random and repeating `VO_playerGrunts_*.mp3` whenever a player loses life

---

### 15 Second Cooldown Period [COOLDOWN SCREEN]

- Duration: 15 seconds (`kCooldownSeconds = 15`)
- Rep detection, and pace timer is paused throughout the duration
- Triggered before each round begins, and after a successful round (Rounds 1-9)
- Rounds 1-10 have a cooldown period before a round, and after a round.
- Round 10 does not have an ending cooldown period
- Player can use this time to rest and prepare
- Cooldown sequence initiates automatically — no player input required.
- Child of Round Loop Logic

### Asset Integration
#### Audio
##### ST
- Plays a very faint background music `ST_COOLDOWN_*.mp3`; Fades in and out of the cooldown duration in time.

---

### Win and Lose Conditions [INTEGRATED WITH COOLDOWN SCREEN]

| Condition | Event |
|-----------|-------|
| Defeat monster after any round | Player continue — proceed to cooldown period, game continue |
| Defeat monster in Round 10 | Player victory — show victory screen, game over |
| Lose all 3 lives at any point | Player defeated — show defeat screen , game over |

Neither condition is reversible mid-session.

### Asset Integration

**Player Continue**
#### Audio Sequence [sequence in order]
1. Play `SFX_win_*.mp3`
2. Play any random and repeating `VO_announcerWin_*.mp3` file 
3. Play `ST_COOLDOWN_*.mp3` for duration of Cooldown Period sequence

**Player Victory**
#### Audio Sequence [sequence in order]
1. Play `SFX_victory_*.mp3`
2. Play any random and repeating `VO_announcerVictory_victory.mp3` file 
3. Play `ST_COOLDOWN_*.mp3` until screen is exited; on loop.

**Player Defeated**
#### Audio [sequence in order]
1. Play `SFX_lose_*.mp3`
2. Play any random `VO_announcerLose_*.mp3` 
3. Play `ST_COOLDOWN_*.mp3` until screen is exited; on loop.

---

### MISC

- Pressing back button, home button, or recent apps/overview button immediately ends the session, and all player lives are lost (There is no such pause or exit function, you cannot cheat!)

---

# General Menu UI Design (Outside gameplay proper)

- Main menu music is `Audio/ST_MAIN_*.mp3`
- UI interaction is accompanied by `Audio/SFX/SFX_click.mp3`
- `logo.png` - Not used during gameplay proper; UI only.
- Primary colors are red and black, akin to the logo.


