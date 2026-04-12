# THE LAST NODE — Development Guide

A satirical side-scrolling beat-em-up set in a dystopian CBDC future. Fight your way through the surveillance state to protect the last running Bitcoin node.

**Genre:** Side-scrolling beat-em-up (Streets of Rage / Final Fight lineage)
**Platform:** Web browser (HTML5 Canvas)
**Players:** 1-2 (local co-op)
**Framework:** Phaser.js 3
**Tone:** Meme-infused satire with real teeth

## Tech Stack

- **Engine:** Phaser.js 3 (Canvas/WebGL)
- **Language:** JavaScript or TypeScript (prefer TypeScript for type safety)
- **Build:** Vite for dev server and bundling
- **Assets:** Pixel art sprites (32-48px character height), tilemaps for levels
- **Audio:** Web Audio API via Phaser's sound manager
- **Input:** Keyboard + Gamepad API
- **Hosting:** Static files — deployable anywhere (GitHub Pages, VPS, IPFS)

## Project Structure

```
the-last-node/
├── CLAUDE.md              # This file
├── package.json
├── tsconfig.json
├── vite.config.ts
├── index.html
├── src/
│   ├── main.ts            # Phaser game config and entry point
│   ├── scenes/
│   │   ├── BootScene.ts       # Asset preloading
│   │   ├── TitleScene.ts      # Title screen
│   │   ├── HUDScene.ts        # Terminal-style HUD overlay
│   │   ├── CitadelScene.ts    # Between-level hub (shop, story)
│   │   ├── LevelScene.ts      # Base class for all levels
│   │   ├── Level1Scene.ts     # THE GRID
│   │   ├── Level2Scene.ts     # THE VAULT
│   │   ├── Level3Scene.ts     # THE FEED
│   │   ├── Level4Scene.ts     # THE BENCH
│   │   ├── Level5Scene.ts     # THE PRINTER
│   │   └── Level6Scene.ts     # THE BASEMENT
│   ├── entities/
│   │   ├── Player.ts          # Base player class
│   │   ├── Miner.ts           # The Miner character
│   │   ├── NodeRunner.ts      # The Node Runner character
│   │   ├── Cypherpunk.ts      # The Cypherpunk character
│   │   ├── P2PTrader.ts       # The P2P Trader character
│   │   ├── Enemy.ts           # Base enemy class
│   │   ├── KYCAgent.ts
│   │   ├── ComplianceDrone.ts
│   │   ├── Banker.ts
│   │   ├── CBDCEnforcer.ts
│   │   ├── VerificationBot.ts
│   │   └── bosses/
│   │       ├── Boss.ts            # Base boss class
│   │       ├── PrecinctCaptain.ts
│   │       ├── CentralBanker.ts
│   │       ├── TheAlgorithm.ts
│   │       ├── TheCommissioner.ts
│   │       ├── TheChairman.ts
│   │       ├── TheArchitect.ts
│   │       └── TheNetwork.ts
│   ├── systems/
│   │   ├── CombatSystem.ts    # Hit detection, combos, damage
│   │   ├── InputManager.ts    # Keyboard + gamepad abstraction
│   │   ├── SatEconomy.ts      # Sat collection, spending, halving
│   │   ├── WaveSpawner.ts     # Enemy wave management
│   │   └── CoopManager.ts     # 2-player co-op logic
│   ├── ui/
│   │   ├── TerminalHUD.ts     # Health bar, sat counter, block height
│   │   ├── BossHealthBar.ts   # PID-style boss health display
│   │   ├── DialogueBox.ts     # Terminal-style story text
│   │   └── PauseMenu.ts       # Terminal pause interface
│   ├── items/
│   │   ├── PowerUp.ts         # Base power-up class
│   │   ├── OrangePill.ts      # Health restore
│   │   ├── FullNode.ts        # Damage buff power-up
│   │   ├── LightningBoost.ts  # Speed buff
│   │   ├── ColdStorage.ts     # Invincibility
│   │   ├── FullNode.ts        # Attack buff
│   │   ├── Whitepaper.ts      # Screen clear
│   │   ├── SeedPhrase.ts      # Extra life
│   │   └── Weapon.ts          # Pickup weapons (wrench, keyboard, gavel, etc.)
│   └── utils/
│       ├── constants.ts       # Game constants, balance numbers
│       └── animations.ts      # Sprite animation definitions
├── public/
│   ├── assets/
│   │   ├── sprites/           # Character and enemy sprite sheets
│   │   ├── tilesets/          # Level tilemap assets
│   │   ├── ui/                # HUD elements, fonts
│   │   ├── audio/
│   │   │   ├── music/         # Per-level synthwave tracks
│   │   │   └── sfx/           # Sat pickup, hits, power-ups, etc.
│   │   └── backgrounds/       # Parallax background layers
│   └── favicon.ico
└── docs/
    └── design.md              # Reference: paste or link design doc here
```

## Development Approach

### Phase 1 — Playable Core
Get one character (The Node Runner) fighting basic enemies (KYC Agents) in one level (THE GRID) with placeholder art. This proves the combat feels good.

1. Scaffold the project (Vite + Phaser + TypeScript)
2. Implement Player base class with movement and 4-button input
3. Implement basic combo system (Attack chains)
4. Implement Enemy base class with AI, health, and knockback
5. Build a test arena scene with spawning enemies
6. Add the sat collection system
7. Add the terminal HUD

**Exit criteria:** You can walk around, punch KYC Agents, chain combos, collect sats, and see it all on the HUD. Placeholder rectangles are fine for art.

### Phase 2 — Combat Depth
Add the full combat system with all 4 characters.

1. Implement specials and supers (sat cost system)
2. Implement grabs and throws
3. Implement directional combos
4. Build out all 4 player characters with unique movesets
5. Add finishing moves with taunt text
6. Add basic enemy variety (all 5 common enemy types)
7. Add pickup weapons

**Exit criteria:** All 4 characters are playable with distinct movesets. Combat feels varied and satisfying.

### Phase 3 — Level 1 Complete
Build the first full level as the template for all others.

1. Implement side-scrolling camera and level boundaries
2. Build Level 1 tilemap and parallax backgrounds
3. Implement WaveSpawner for scripted enemy encounters
4. Build the Precinct Captain boss fight with mechanics
5. Add environmental destructibles (vending machines, checkpoints)
6. Add power-up drops
7. Add pleb NPCs to rescue
8. Implement level scoring

**Exit criteria:** Level 1 is playable start to finish with a boss fight, scoring, and transition to the citadel.

### Phase 4 — Remaining Levels
Build levels 2-6, the citadel, and all boss fights.

### Phase 5 — Co-Op
Add 2-player local co-op, shared economy, co-op moves, revive system.

### Phase 6 — Polish
Art, music, sound effects, meme details, easter eggs, title screen, score screen, hard mode.

## Art Direction

### Style: Pixel Meme Noir
- Native resolution: 320x180 scaled up
- Characters: 32-48px tall
- Dark blue-gray world, Bitcoin orange for resistance elements
- Glitch/scanline effects on surveillance tech
- 3-4 layer parallax scrolling backgrounds

### Color Rules
- Fiat/surveillance: steel blue, clinical white, concrete gray, money green
- Bitcoin/resistance: orange, warm amber, terminal green
- Underground: deep black, amber emergency light, node green glow

### UI: Terminal Aesthetic
- HUD styled as command-line output (monospace font, block characters for bars)
- Pause menu is a terminal interface with blinking cursor
- Boss health bars display as system processes with PID numbers
- Dialogue appears as encrypted Nostr messages, typing effect

## Controls

### Keyboard (default)
| Action  | Primary | Alt     |
|---------|---------|---------|
| Move    | Arrows  | WASD    |
| Attack  | Z       | J       |
| Special | X       | K       |
| Jump    | C       | L       |
| Grab    | V       | ;       |
| Pause   | Escape  | P       |

### Gamepad
Standard mapping. Face buttons for Attack/Special/Jump/Grab. D-pad or left stick for movement.

## Game Balance Constants

Keep these in `src/utils/constants.ts` so they're easy to tune:

```typescript
// Economy
const SAT_DROP_SMALL = 100;      // KYC Agent, Banker
const SAT_DROP_MEDIUM = 250;     // CBDC Enforcer, Verification Bot
const SAT_DROP_LARGE = 500;      // Mid-bosses
const SAT_DROP_BOSS = 2000;      // Level bosses

const SPECIAL_COST_1 = 500;
const SPECIAL_COST_2 = 1000;
const SUPER_COST = 5000;

const HALVING_AFTER_LEVEL = 3;   // Sat drops halve after level 3
const REVIVE_COST = 2000;        // Co-op revive cost

// Combat
const COMBO_WINDOW_MS = 400;     // Time to chain next hit
const FINISHING_MOVE_THRESHOLD = 0.1; // 10% health triggers finisher

// Performance
const TARGET_FPS = 60;
const NATIVE_WIDTH = 320;
const NATIVE_HEIGHT = 180;
```

## Conventions

- **One class per file.** Named after the class.
- **Scenes manage flow. Entities manage behavior.** Scenes spawn and coordinate entities. Entities own their own update loops, animations, and state.
- **Use Phaser's built-in physics** (Arcade Physics) for collisions and movement. Don't roll custom physics.
- **Sprite sheets over individual frames.** Pack animations into sheets. Define frames in `animations.ts`.
- **Placeholder art is fine.** Use colored rectangles with labels during development. Swap in real sprites later. Never block gameplay progress on art.
- **Keep balance numbers in constants.ts.** Never hardcode damage values, speeds, or costs in entity files.
- **Test combat feel early and often.** If punching doesn't feel good, nothing else matters.

## Design Reference

The full game design document lives in the LLM Wiki at:
```
~/Documents/Claude/Satsdisco's worksplace/wiki/
```

Key files:
- `the-last-node.md` — Master design doc, premise, narrative arc, design pillars
- `bbeu-characters.md` — All 4 playable characters with full movesets, NPCs, progression
- `bbeu-villains.md` — All enemies, mid-bosses, level bosses, final boss (The Architect → THE NETWORK)
- `bbeu-levels.md` — All 6 levels with environments, enemies, bosses, story beats, Bitcoin culture details
- `bbeu-mechanics.md` — Combat system, sat economy, power-ups, items, co-op, scoring
- `bbeu-art-direction.md` — Visual style, color rules, meme integration, UI/HUD design, music direction

When implementing a feature, read the relevant design doc page first.
