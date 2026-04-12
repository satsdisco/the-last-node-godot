# THE LAST NODE — Godot Migration Roadmap (3 Months)

## The Vision

Take everything we built — the game design, the Bitcoin culture, the 6-level narrative arc, the combat system, the AI art pipeline — and rebuild it in Godot as a **production-quality beat-em-up** worthy of comparison to Simpsons Arcade and Scott Pilgrim vs The World.

**Bitcoin only. Never crypto. Beautiful. Fun to play.**

---

## What We're Bringing Forward

Everything design-related transfers 1:1:

- ✅ Complete game design doc (CLAUDE.md — characters, enemies, bosses, levels, mechanics)
- ✅ Design wiki (8 detailed wiki pages — characters, villains, levels, mechanics, art direction)
- ✅ 2-year roadmap vision
- ✅ AI art pipeline (ChatGPT prompts for backgrounds, characters, props)
- ✅ AI-generated assets (city skyline, mid buildings, concept art)
- ✅ Aseprite workflow doc
- ✅ Character concept art (NodeRunner, Cypherpunk references)
- ✅ Bitcoin-only cultural guidelines
- ✅ Combat system design (combos, specials, supers, grabs, finishers)
- ✅ All boss mechanics (11 bosses with unique phases)
- ✅ Narrative arc (Intro → 6 levels → Citadel → Credits)
- ✅ Music direction (synthwave, per-level mood)
- ✅ README, .gitignore, GitHub repo infrastructure

---

## Month 1 — FOUNDATION (Weeks 1-4)

### Week 1: Godot Setup + Core Movement

**Goal:** Character walks around a test arena and punches.

- [ ] Install Godot 4.3+ on Mac
- [ ] Create new Godot project `the-last-node-godot`
- [ ] Set up project settings:
  - Resolution: 640×360, stretch mode: viewport, aspect: keep
  - Pixel art filter: Nearest Neighbor
  - Default gravity: 0 (2.5D beat-em-up, no platformer gravity)
- [ ] Create the Player scene:
  - CharacterBody2D with small foot collision shape
  - AnimatedSprite2D (placeholder rect for now)
  - Shadow sprite (ellipse)
  - State machine: IDLE, WALK, ATTACK, HIT, JUMP, GRAB, DOWN
- [ ] Implement WASD movement on the ground plane (Y = depth, not gravity)
- [ ] Implement basic 3-hit combo on Z key
  - Combo window timer
  - Hitbox area that activates during attack frames
- [ ] Camera follow player with smooth lerp
- [ ] Add a test arena with floor bounds

**Exit criteria:** You can walk around and punch. Movement feels responsive.

### Week 2: Combat System

**Goal:** Full combat with enemies fighting back.

- [ ] Create Enemy base scene:
  - CharacterBody2D + AnimatedSprite2D + AI script
  - HP, damage, knockback, stun
  - Chase → attack behavior
- [ ] Create KYCAgent enemy (scan beam attack)
- [ ] Create Banker enemy (ranged bill throw)
- [ ] Hit detection via Area2D hitboxes:
  - Player attack hitbox (activates during attack animation)
  - Enemy hurt box (permanent)
  - Visual: show hitboxes in debug mode
- [ ] Knockback physics on hit
- [ ] Hit stun (brief freeze-frame on impact — Godot makes this trivial)
- [ ] Screen shake on heavy hits
- [ ] Combo counter + finisher at low HP
- [ ] Sat drops on enemy death (Area2D pickup)
- [ ] Damage numbers floating up

**Exit criteria:** Combat feels punchy and satisfying. Enemies fight back.

### Week 3: Art Pipeline + First Real Character

**Goal:** AI-generated character art playing in-game with smooth animation.

- [ ] Set up the art workflow:
  - Generate character poses in ChatGPT (9 frames per character)
  - Process via ImageMagick (strip bg, uniform scale)
  - Import into Aseprite, align frames, tag animations
  - Export PNG + JSON
  - Drag into Godot → AnimatedSprite2D → done
- [ ] Create Node Runner with real art:
  - idle (4 frames)
  - walk (8 frames)
  - attack1/2/3 (4 frames each)
  - hit (2 frames)
  - jump (3 frames)
  - grab + throw
- [ ] Create KYC Agent with real art (6-8 frames)
- [ ] Create Banker with real art (6-8 frames)
- [ ] VFX scenes for combat:
  - Slash arc (AnimatedSprite2D or Line2D with shader)
  - Hit sparks (GPUParticles2D — orange burst)
  - Screen flash on finisher

**Exit criteria:** Node Runner looks like the concept art, animated smoothly.

### Week 4: Level 1 — THE GRID (Complete)

**Goal:** Level 1 is a polished, playable vertical slice.

- [ ] Level scene structure:
  - ParallaxBackground with 4 layers:
    - Far skyline (AI art — already have this!)
    - Mid buildings (AI art — already have 3 variants!)
    - Foreground props
    - Rain/atmosphere overlay
  - TileMap for the ground (or simple textured ground)
  - Encounter zones (Area2D triggers that lock camera + spawn enemies)
- [ ] Port all Level 1 encounters:
  - Encounter 1: KYC swarm
  - Encounter 2: Bankers + KYC
  - Encounter 3: Drone + Enforcer
  - Boss: Precinct Captain
- [ ] Destructible props (CBDC vending, KYC checkpoint)
- [ ] Pleb rescue NPCs
- [ ] Power-up drops (OrangePill, FullNode, ColdStorage, etc.)
- [ ] Weapon pickups (wrench, keyboard, gavel)
- [ ] HUD overlay:
  - HP bar (CanvasLayer)
  - Sat counter
  - Block height
  - Boss health bar
- [ ] Nostr DM dialog system (CanvasLayer popup)
- [ ] Level splash card ("LEVEL 1 — THE GRID")
- [ ] Gate system (red barrier during encounters)
- [ ] Boss: Precinct Captain with:
  - Megaphone commands (FREEZE, COMPLY, DISPERSE)
  - Destructible surveillance cameras
  - Phase 2 helicopter spotlight
- [ ] Score screen at level end

**Exit criteria:** Level 1 is playable start to finish and looks beautiful. This is the demo you show people.

---

## Month 2 — CONTENT (Weeks 5-8)

### Week 5: Remaining Characters + Enemies

- [ ] Miner character (all animations)
- [ ] Cypherpunk character (all animations + purple energy VFX)
- [ ] P2P Trader character (all animations + item throw)
- [ ] Character select on Title screen
- [ ] CBDC Enforcer enemy (shield block + bash)
- [ ] Compliance Drone enemy (hover + reinforcement call)
- [ ] Verification Bot enemy (area denial zone)
- [ ] Regulatory Lawyer enemy (subpoena throw)
- [ ] Fed Guard enemy (coordinated pair tactics)

### Week 6: Levels 2-3

- [ ] Level 2 — THE VAULT:
  - Financial district parallax (marble, gold, BTC ticker)
  - Branch Manager mid-boss
  - Central Banker boss (money printer spawns)
  - Gold bar weapon
- [ ] Level 3 — THE FEED:
  - Media campus parallax (glass towers, server rooms)
  - Content Moderator mid-boss (shrinking arena)
  - The Algorithm boss (hologram face, shadowban)

### Week 7: Levels 4-5

- [ ] Level 4 — THE BENCH:
  - Government district parallax (brutalist concrete, red tape)
  - The Auditor mid-boss (sat drain beam)
  - The Commissioner boss (rule changes mid-fight)
  - Halving cutscene between L3 and L4
- [ ] Level 5 — THE PRINTER:
  - Federal Reserve parallax (marble halls, money printers)
  - Gauntlet waves (no mid-boss)
  - The Chairman boss (monetary policy arena effects)

### Week 8: Level 6 + Citadel + Full Loop

- [ ] Level 6 — THE BASEMENT:
  - Underground tunnels parallax (pipes, steam, amber lights)
  - The Architect boss (surveillance weapons, drone strikes)
  - The Network survival phase (propagation bar)
  - "Running Bitcoin" ending
- [ ] Citadel hub:
  - Merchant shop (buy power-ups)
  - Relay Runner NPC (per-level dialog)
  - Visual: Bitcoin node wall, Lightning channels
- [ ] Credits scene ("RUNNING BITCOIN" → "THE NETWORK IS SECURE")
- [ ] Full game loop: Title → Intro → L1 → Citadel → L2 → ... → L6 → Credits

---

## Month 3 — POLISH (Weeks 9-12)

### Week 9: Co-Op + Music

- [ ] 2-player local co-op:
  - Player 2 input (IJKL + 7890 or gamepad)
  - Shared sat pool
  - Revive system (hold grab near downed ally)
  - Multisig finisher (both grab same enemy)
  - Camera follows midpoint
- [ ] Music system:
  - Per-level composed tracks (Godot AudioStreamPlayer)
  - Dynamic music (combat intensity affects layers)
  - Title theme, Citadel ambient, boss themes
  - Victory/death stingers

### Week 10: VFX + Animation Polish

- [ ] Particle effects for every action:
  - Walk dust
  - Hit impact (directional sparks)
  - Death dissolve
  - Special move energy (per-character color)
  - Sat pickup sparkle
  - Power-up activation glow
- [ ] Screen effects via shaders:
  - CRT scanline overlay (subtle)
  - Damage vignette (red pulse on hit)
  - Boss phase transition flash
  - Halving cutscene shader
- [ ] Animation polish:
  - Idle breathing on all characters
  - Hit reactions (different for light/heavy)
  - Walk cycle blending at different speeds
  - Attack anticipation frames

### Week 11: UI + Narrative

- [ ] Title screen redesign (animated background, character showcase)
- [ ] How To Play screen with animated demos
- [ ] Pause menu with settings (music volume, SFX, CRT toggle)
- [ ] Nostr DM dialog system polish (typing sound, message encryption animation)
- [ ] Per-level intro cards (full-screen art + title)
- [ ] Cutscenes between levels (illustrated panels or in-engine)
- [ ] Relay Runner expanded dialog (character arc)
- [ ] Hard Mode toggle + difficulty scaling
- [ ] Score system + letter grades

### Week 12: Release Prep

- [ ] Gamepad support (full controller mapping)
- [ ] Web export (Godot → HTML5, host on GitHub Pages)
- [ ] Mac export (.app bundle for direct sharing)
- [ ] Performance optimization pass
- [ ] Bug fixing sprint
- [ ] Balance tuning (enemy HP, damage, sat economy)
- [ ] README update with new screenshots
- [ ] Trailer capture (90-second gameplay reel)
- [ ] Push to itch.io (free, web-playable)
- [ ] GitHub release tag v1.0

---

## Architecture in Godot

```
the-last-node-godot/
├── project.godot
├── assets/
│   ├── sprites/
│   │   ├── characters/       # Player + enemy sprite sheets
│   │   ├── props/            # Destructibles, pickups, weapons
│   │   └── ui/               # HUD elements, fonts
│   ├── backgrounds/          # AI-generated parallax layers (already have!)
│   ├── audio/
│   │   ├── music/            # Per-level tracks
│   │   └── sfx/              # Hit, pickup, menu, etc.
│   └── shaders/              # CRT, damage flash, transitions
├── scenes/
│   ├── characters/
│   │   ├── player.tscn       # Base player scene (CharacterBody2D)
│   │   ├── node_runner.tscn  # Inherits player, unique stats + anims
│   │   ├── miner.tscn
│   │   ├── cypherpunk.tscn
│   │   └── p2p_trader.tscn
│   ├── enemies/
│   │   ├── enemy.tscn        # Base enemy scene
│   │   ├── kyc_agent.tscn
│   │   ├── banker.tscn
│   │   ├── cbdc_enforcer.tscn
│   │   └── ...
│   ├── bosses/
│   │   ├── precinct_captain.tscn
│   │   └── ...
│   ├── levels/
│   │   ├── level_base.tscn   # Base level (parallax, floor, HUD, encounter system)
│   │   ├── level_1.tscn      # THE GRID
│   │   └── ...
│   ├── ui/
│   │   ├── hud.tscn
│   │   ├── title_screen.tscn
│   │   ├── nostr_dm.tscn
│   │   └── pause_menu.tscn
│   └── vfx/
│       ├── hit_spark.tscn    # GPUParticles2D
│       ├── slash_arc.tscn
│       └── sat_pickup.tscn
├── scripts/
│   ├── player.gd
│   ├── enemy.gd
│   ├── combat_system.gd
│   ├── sat_economy.gd
│   ├── encounter_manager.gd
│   └── game_state.gd        # Global autoload (sats, character, progress)
└── docs/
    ├── CLAUDE.md             # Game design (carried forward)
    ├── ROADMAP.md            # This file
    └── ART_GUIDE.md          # AI art generation prompts
```

## Key Godot Concepts We'll Use

| Concept | What it does for us |
|---|---|
| **CharacterBody2D** | Player + enemy movement with built-in collision |
| **AnimatedSprite2D** | Frame-based animation from sprite sheets — visual timeline editor |
| **AnimationPlayer** | Keyframe anything — position, scale, modulate, call functions |
| **Area2D** | Attack hitboxes, pickup collection, encounter triggers |
| **ParallaxBackground** | Multi-layer scrolling backgrounds — just set the scroll factor |
| **TileMap** | Paint the ground tiles visually |
| **GPUParticles2D** | Hit sparks, dust, energy effects — no code needed |
| **CanvasLayer** | HUD that stays fixed over the game world |
| **AudioStreamPlayer** | Music + SFX with volume bus routing |
| **Shaders** | CRT effect, damage flash, boss transitions |
| **Autoload** | Global game state (sats, character, progress) |
| **Scene inheritance** | Base enemy → KYC Agent → Banker (shared logic, unique behavior) |

## Milestones

| When | What | Deliverable |
|---|---|---|
| **Week 2** | Core combat | Punch enemies in a test arena |
| **Week 4** | Level 1 demo | Show friends a beautiful, polished Level 1 |
| **Week 8** | Full game | All 6 levels playable end to end |
| **Week 10** | VFX + music | Game looks and sounds professional |
| **Week 12** | Release | Web + Mac build on itch.io + GitHub |

## Principles (carried forward)

1. **Bitcoin only.** Never crypto. Never altcoins. The language, culture, memes — all bitcoin-native.
2. **Beautiful over big.** Polish Level 1 before building Level 2.
3. **Co-op first.** Every mechanic tested in 2-player.
4. **Open source, open game.** GitHub repo, static hosting, no server.
5. **Culture is the game.** The mechanic is punching. The game is about why we punch.
6. **Art pipeline:** AI generates → ImageMagick processes → Aseprite refines → Godot imports. Streamlined, repeatable.

---

## Day 1 Action Items

1. ✅ Install Godot 4.3
2. ✅ Create project with correct settings
3. ✅ Copy AI art assets from Phaser project
4. ✅ Set up ParallaxBackground with the skyline + mid buildings
5. ✅ Create Player CharacterBody2D with placeholder rect
6. ✅ WASD movement on the ground plane
7. ✅ First punch on Z key
8. ✅ Push to new GitHub repo

**Let's go.**
