extends Node

## Global game state — persists across scenes.
## Autoloaded as "GameState".

# Economy
var sats: int = 3000

# Player state
var character: String = "node_runner"
var character_2: String = "miner"
var hp_pct: float = 1.0
var hp_pct_2: float = 1.0
var coop_mode: bool = false
var hard_mode: bool = false

# Progression
var completed_levels: int = 0
var halving_active: bool = false

# Session peak stats
var combo_peak: int = 0

# Level order
const LEVEL_ORDER = [
	"res://scenes/levels/level_1.tscn",
	"res://scenes/levels/level_2.tscn",
	"res://scenes/levels/level_3.tscn",
	"res://scenes/levels/level_4.tscn",
	"res://scenes/levels/level_5.tscn",
	"res://scenes/levels/level_6.tscn",
]

func reset():
	sats = 3000
	hp_pct = 1.0
	hp_pct_2 = 1.0
	character = "node_runner"
	character_2 = "miner"
	coop_mode = false
	hard_mode = false
	completed_levels = 0
	halving_active = false
	combo_peak = 0

func next_level_path() -> String:
	var idx = mini(completed_levels, LEVEL_ORDER.size() - 1)
	return LEVEL_ORDER[idx]

func enemy_hp_mult() -> float:
	return 1.5 if hard_mode else 1.0

func enemy_dmg_mult() -> float:
	return 1.4 if hard_mode else 1.0

func sat_drop_mult() -> float:
	var m = 1.0
	if halving_active:
		m *= 0.5
	if hard_mode:
		m *= 0.75
	return m
