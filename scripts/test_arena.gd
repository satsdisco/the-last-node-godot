extends Node2D

## Test Arena — builds the scene in code so we don't fight .tscn format.
## Hit F5 and punch some KYC agents.

# Characters walk ONLY on the street — bottom 25% of screen
# This keeps them on the road, not walking into buildings
const FLOOR_TOP = 275
const FLOOR_BOTTOM = 345
const LEVEL_WIDTH = 3200

var player: CharacterBody2D
var camera: Camera2D

func _ready():
	# === BACKGROUNDS — Synth Cities parallax layers ===

	# Layer 1: Far skyline (slowest scroll)
	_add_parallax_layer("res://assets/backgrounds/synth_back.png", -100, 0.15, 0)

	# Layer 2: Mid buildings
	_add_parallax_layer("res://assets/backgrounds/synth_middle.png", -80, 0.35, 0)

	# Layer 3: Foreground buildings — positioned so the street in the art
	# IS the walkable ground. Bottom of image at y=360 (screen bottom),
	# characters walk on the street area within the image.
	_add_parallax_layer("res://assets/backgrounds/synth_foreground_empty.png", -60, 0.6, 360)

	# No separate floor rect — the foreground image IS the ground.
	# Just a subtle darkening strip at the very bottom for depth
	var floor_fade = ColorRect.new()
	floor_fade.color = Color(0, 0, 0, 0.3)
	floor_fade.position = Vector2(0, FLOOR_BOTTOM)
	floor_fade.size = Vector2(LEVEL_WIDTH, 360 - FLOOR_BOTTOM)
	floor_fade.z_index = -45
	add_child(floor_fade)

	# === MUSIC ===
	var music = AudioStreamPlayer.new()
	var music_stream = load("res://assets/audio/music/cyberpunk_street.ogg")
	if music_stream:
		music.stream = music_stream
		music.volume_db = -8
		music.autoplay = true
		add_child(music)
		print("[Level] Music loaded: cyberpunk_street.ogg")

	# Floor grid lines
	for gy in range(FLOOR_TOP, FLOOR_BOTTOM, 20):
		var line = ColorRect.new()
		line.color = Color(0.055, 0.07, 0.09, 0.5)
		line.position = Vector2(0, gy)
		line.size = Vector2(LEVEL_WIDTH, 1)
		add_child(line)

	# Rain
	_spawn_rain()

	# Player
	player = _create_player(Vector2(100, 280))
	add_child(player)

	# Camera follows player
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_top = 0
	camera.limit_right = LEVEL_WIDTH
	camera.limit_bottom = 360
	player.add_child(camera)
	camera.make_current()

	# Destructible props along the level
	Destructible.spawn(self, Vector2(250, 310), Destructible.PropType.VENDING)
	Destructible.spawn(self, Vector2(750, 310), Destructible.PropType.CHECKPOINT)
	Destructible.spawn(self, Vector2(1200, 310), Destructible.PropType.VENDING)
	Destructible.spawn(self, Vector2(1800, 240), Destructible.PropType.BILLBOARD)
	Destructible.spawn(self, Vector2(2050, 310), Destructible.PropType.VENDING)
	Destructible.spawn(self, Vector2(2500, 310), Destructible.PropType.CHECKPOINT)

	# Pre-placed power-ups at key locations
	Pickup.spawn_power_up(self, Vector2(200, 300), Pickup.PickupType.ORANGE_PILL)
	Pickup.spawn_power_up(self, Vector2(1350, 300), Pickup.PickupType.ORANGE_PILL)
	# Boss prep — heal + damage buff + weapon before the captain
	Pickup.spawn_power_up(self, Vector2(2700, 300), Pickup.PickupType.ORANGE_PILL)
	Pickup.spawn_power_up(self, Vector2(2720, 300), Pickup.PickupType.FULL_NODE)
	Pickup.spawn_power_up(self, Vector2(2740, 300), Pickup.PickupType.COLD_STORAGE)

	# Encounters — triggered when player reaches X position
	_setup_encounters()

	# HUD
	_create_hud()

	# Level splash card
	_show_level_splash("LEVEL 1", "THE GRID", "BLOCK 840,003")

	# Connect player death
	player.died.connect(_on_player_died)

	print("[TestArena] Ready — WASD to move, Z to attack!")

func _add_parallax_layer(texture_path: String, z: int, scroll_factor: float, bottom_align_y: int):
	var tex = load(texture_path) as Texture2D
	if not tex:
		print("[Level] WARNING: %s not found!" % texture_path)
		return

	var tex_w = tex.get_width()
	var tex_h = tex.get_height()
	var prefix = texture_path.get_file().get_basename() + "_"

	# Calculate Y position — either top-aligned or bottom-aligned to a Y coordinate
	var y_pos = 0
	if bottom_align_y > 0:
		# Scale to fit screen width, bottom-align to the given Y
		y_pos = bottom_align_y - int(float(tex_h) * (640.0 / float(tex_w)))
	else:
		# Scale to fill screen height
		y_pos = 0

	# Tile across the level width, scaled to fill viewport height
	var scale_factor = 640.0 / float(tex_w)  # Scale to viewport width
	var tiles_needed = ceili(float(LEVEL_WIDTH) / 640.0) + 2

	for i in range(tiles_needed):
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.centered = false
		sprite.position = Vector2(i * 640, y_pos)
		sprite.scale = Vector2(scale_factor, scale_factor)
		sprite.z_index = z
		sprite.name = "%s%d" % [prefix, i]
		add_child(sprite)

	_parallax_layers.append({"prefix": prefix, "factor": scroll_factor})
	print("[Level] Layer loaded: %s (%dx%d, factor %.2f)" % [texture_path.get_file(), tex_w, tex_h, scroll_factor])

func _create_player(pos: Vector2) -> CharacterBody2D:
	var p = CharacterBody2D.new()
	p.position = pos
	p.set_script(load("res://scripts/player.gd"))
	p.add_to_group("players")

	# Collision shape (feet)
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 10)
	col.shape = shape
	p.add_child(col)

	# Visual body (placeholder — colored rect)
	var body = ColorRect.new()
	body.color = Color(1.0, 0.6, 0.0)  # Bitcoin orange
	body.size = Vector2(24, 40)
	body.position = Vector2(-12, -44)
	p.add_child(body)

	# Head
	var head = ColorRect.new()
	head.color = Color(1.0, 0.6, 0.0)
	head.size = Vector2(18, 14)
	head.position = Vector2(-9, -60)
	p.add_child(head)

	# Eyes (green glow)
	var eye_l = ColorRect.new()
	eye_l.color = Color(0.0, 1.0, 0.4)
	eye_l.size = Vector2(4, 4)
	eye_l.position = Vector2(-6, -56)
	p.add_child(eye_l)

	var eye_r = ColorRect.new()
	eye_r.color = Color(0.0, 1.0, 0.4)
	eye_r.size = Vector2(4, 4)
	eye_r.position = Vector2(3, -56)
	p.add_child(eye_r)

	# Shadow
	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(28, 6)
	shadow.position = Vector2(-14, -2)
	shadow.name = "Shadow"
	p.add_child(shadow)

	# Label
	var lbl = Label.new()
	lbl.text = "NODE"
	lbl.position = Vector2(-20, -72)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	lbl.name = "Label"
	p.add_child(lbl)

	return p

func _spawn_enemy(pos: Vector2, type: String):
	# CBDC Enforcer and Boss have their own scripts
	if type == "ENFORCER":
		_spawn_enforcer(pos)
		return
	if type == "BOSS":
		_spawn_boss(pos)
		return

	var e = CharacterBody2D.new()
	e.position = pos
	e.set_script(load("res://scripts/enemy.gd"))
	e.add_to_group("enemies")

	e.set("enemy_name", type)
	if type == "BANKER":
		e.set("speed", 60.0)
		e.set("max_hp", 20)
		e.set("damage", 4)
		e.set("attack_range", 70.0)
		e.set("attack_cooldown", 1.4)
		e.set("drop_sats", 100)

	# Collision shape
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 8)
	col.shape = shape
	e.add_child(col)

	# Visual body (blue for KYC, green for banker)
	var color = Color(0.29, 0.44, 0.65) if type == "KYC" else Color(0.0, 0.67, 0.27)

	var body = ColorRect.new()
	body.color = color
	body.size = Vector2(22, 36)
	body.position = Vector2(-11, -40)
	e.add_child(body)

	var head_rect = ColorRect.new()
	head_rect.color = color
	head_rect.size = Vector2(16, 12)
	head_rect.position = Vector2(-8, -54)
	e.add_child(head_rect)

	# Red eyes
	var eye = ColorRect.new()
	eye.color = Color(1, 0.2, 0.2)
	eye.size = Vector2(4, 3)
	eye.position = Vector2(-4, -50)
	e.add_child(eye)

	var eye2 = ColorRect.new()
	eye2.color = Color(1, 0.2, 0.2)
	eye2.size = Vector2(4, 3)
	eye2.position = Vector2(2, -50)
	e.add_child(eye2)

	# Shadow
	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(24, 5)
	shadow.position = Vector2(-12, -2)
	shadow.name = "Shadow"
	e.add_child(shadow)

	# HP bars
	var hp_bg = ColorRect.new()
	hp_bg.color = Color(0.2, 0, 0)
	hp_bg.size = Vector2(32, 4)
	hp_bg.position = Vector2(-16, -62)
	hp_bg.name = "HPBarBG"
	e.add_child(hp_bg)

	var hp_bar = ColorRect.new()
	hp_bar.color = Color(1, 0.2, 0.2)
	hp_bar.size = Vector2(32, 4)
	hp_bar.position = Vector2(-16, -62)
	hp_bar.name = "HPBar"
	e.add_child(hp_bar)

	# Label
	var lbl = Label.new()
	lbl.text = type
	lbl.position = Vector2(-20, -74)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.53, 0.67, 1.0))
	lbl.name = "Label"
	e.add_child(lbl)

	add_child(e)

func _spawn_rain():
	for i in range(40):
		var drop = ColorRect.new()
		drop.color = Color(0.53, 0.67, 1.0, 0.35)
		drop.size = Vector2(1, 6)
		drop.rotation = deg_to_rad(15)
		drop.position = Vector2(randf() * 640, randf() * 220)
		drop.z_index = 100
		add_child(drop)

		var tween = create_tween().set_loops()
		tween.tween_property(drop, "position:y", 240.0, randf_range(0.4, 0.8))
		tween.tween_callback(func():
			drop.position.y = -10
			drop.position.x = randf() * 640
		)

func _create_hud():
	var hud = CanvasLayer.new()
	hud.name = "HUD"
	add_child(hud)

	var green = Color(0, 1, 0.4)
	var orange = Color(1, 0.8, 0.2)
	var dim_green = Color(0, 0.5, 0.2)

	# === TOP LEFT: Terminal-style player status ===
	var name_lbl = Label.new()
	name_lbl.text = "> P1 NODE_RUNNER"
	name_lbl.position = Vector2(8, 4)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", green)
	hud.add_child(name_lbl)

	# Terminal-style HP bar using block characters
	var hp_lbl = Label.new()
	hp_lbl.name = "HPLabel"
	hp_lbl.text = "HP [██████████] 100/100"
	hp_lbl.position = Vector2(8, 18)
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.add_theme_color_override("font_color", green)
	hud.add_child(hp_lbl)

	# Thin color bar underneath
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0, 0.08, 0)
	bar_bg.position = Vector2(8, 32)
	bar_bg.size = Vector2(180, 4)
	hud.add_child(bar_bg)

	var bar = ColorRect.new()
	bar.name = "HPBar"
	bar.color = green
	bar.position = Vector2(8, 32)
	bar.size = Vector2(180, 4)
	hud.add_child(bar)

	# Weapon display
	var weapon_lbl = Label.new()
	weapon_lbl.name = "WeaponLabel"
	weapon_lbl.text = ""
	weapon_lbl.position = Vector2(8, 40)
	weapon_lbl.add_theme_font_size_override("font_size", 9)
	weapon_lbl.add_theme_color_override("font_color", orange)
	hud.add_child(weapon_lbl)

	# === TOP RIGHT: Sats + Block height ===
	var sats_lbl = Label.new()
	sats_lbl.name = "SatsLabel"
	sats_lbl.text = "SATS: 3,000"
	sats_lbl.position = Vector2(490, 4)
	sats_lbl.add_theme_font_size_override("font_size", 12)
	sats_lbl.add_theme_color_override("font_color", orange)
	sats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sats_lbl.size = Vector2(140, 20)
	hud.add_child(sats_lbl)

	var block_lbl = Label.new()
	block_lbl.name = "BlockLabel"
	block_lbl.text = "BLOCK 840,000"
	block_lbl.position = Vector2(490, 20)
	block_lbl.add_theme_font_size_override("font_size", 10)
	block_lbl.add_theme_color_override("font_color", green)
	block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	block_lbl.size = Vector2(140, 20)
	hud.add_child(block_lbl)

	# === BOTTOM: Status line with blinking cursor ===
	var status = Label.new()
	status.name = "StatusLabel"
	status.text = "> awaiting_input_"
	status.position = Vector2(8, 340)
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", dim_green)
	hud.add_child(status)

	# Controls hint
	var hint = Label.new()
	hint.text = "WASD move  Z attack  X special  C jump  V grab  ESC pause"
	hint.position = Vector2(150, 348)
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", dim_green)
	hud.add_child(hint)

# Parallax layers for manual scrolling
var _parallax_layers: Array = []
var _last_cam_x: float = 0

# Encounter system
var encounters: Array = []
var current_encounter: int = -1
var encounter_active: bool = false
var gate_left: float = 0
var gate_right: float = 0
var gate_visual: ColorRect = null

var _block_tick_timer: float = 0.0
var _block_height: int = 840000
var _blink_timer: float = 0.0

func _process(delta):
	if not player or not is_instance_valid(player):
		return

	# Encounter system
	_check_encounters()

	# Manual parallax scrolling
	if camera:
		var cam_x = camera.get_screen_center_position().x
		var cam_delta = cam_x - _last_cam_x
		_last_cam_x = cam_x
		for layer_info in _parallax_layers:
			var factor = layer_info["factor"]
			var offset = cam_delta * (1.0 - factor)
			for child in get_children():
				if child.name.begins_with(layer_info["prefix"]):
					child.position.x -= offset

	var hud = get_node_or_null("HUD")
	if not hud:
		return

	# Terminal-style HP bar ██████░░░░
	var hp_lbl = hud.get_node_or_null("HPLabel")
	if hp_lbl:
		var pct = float(player.hp) / float(player.max_hp)
		var blocks = int(pct * 10)
		var bar_str = "█".repeat(blocks) + "░".repeat(10 - blocks)
		hp_lbl.text = "HP [%s] %d/%d" % [bar_str, player.hp, player.max_hp]
		# Color changes at low HP
		if pct < 0.3:
			hp_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		elif pct < 0.6:
			hp_lbl.add_theme_color_override("font_color", Color(1, 0.7, 0))
		else:
			hp_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))

	# HP bar color
	var bar = hud.get_node_or_null("HPBar")
	if bar:
		var pct = float(player.hp) / float(player.max_hp)
		bar.size.x = 180.0 * pct
		if pct < 0.3:
			bar.color = Color(1, 0.2, 0.2)
		elif pct < 0.6:
			bar.color = Color(1, 0.7, 0)
		else:
			bar.color = Color(0, 1, 0.4)

	# Sats with comma formatting
	var sats_lbl = hud.get_node_or_null("SatsLabel")
	if sats_lbl:
		sats_lbl.text = "SATS: %s" % _format_sats(GameState.sats)

	# Block height ticks up every 10s
	_block_tick_timer += delta
	if _block_tick_timer > 10.0:
		_block_tick_timer = 0
		_block_height += 1
	var block_lbl = hud.get_node_or_null("BlockLabel")
	if block_lbl:
		block_lbl.text = "BLOCK %s" % _format_number(_block_height)

	# Blinking cursor on status line
	_blink_timer += delta
	var status = hud.get_node_or_null("StatusLabel")
	if status:
		var cursor = "_" if fmod(_blink_timer, 1.0) < 0.5 else " "
		status.text = "> awaiting_input%s" % cursor

func _format_sats(n: int) -> String:
	return _format_number(n)

func _format_number(n: int) -> String:
	var s = str(n)
	var result = ""
	var count = 0
	for i in range(s.length() - 1, -1, -1):
		if count > 0 and count % 3 == 0:
			result = "," + result
		result = s[i] + result
		count += 1
	return result

# ==== ENCOUNTER SYSTEM ====

func _setup_encounters():
	encounters = [
		# Encounter 1: first KYC swarm
		{ "trigger_x": 400, "left": 320, "right": 700,
		  "enemies": [
			{"type": "KYC", "x": 650, "y": 270},
			{"type": "KYC", "x": 650, "y": 310},
			{"type": "KYC", "x": 350, "y": 280},
		  ]},
		# Encounter 2: Bankers + KYC
		{ "trigger_x": 900, "left": 820, "right": 1200,
		  "enemies": [
			{"type": "BANKER", "x": 1150, "y": 280},
			{"type": "KYC", "x": 860, "y": 300},
			{"type": "KYC", "x": 1150, "y": 260},
		  ]},
		# Encounter 3: bigger fight
		{ "trigger_x": 1500, "left": 1420, "right": 1900,
		  "enemies": [
			{"type": "KYC", "x": 1850, "y": 260},
			{"type": "BANKER", "x": 1460, "y": 300},
			{"type": "KYC", "x": 1850, "y": 310},
			{"type": "BANKER", "x": 1460, "y": 270},
		  ]},
		# Encounter 4: enforcer introduction
		{ "trigger_x": 2200, "left": 2100, "right": 2600,
		  "enemies": [
			{"type": "ENFORCER", "x": 2550, "y": 280},
			{"type": "KYC", "x": 2550, "y": 310},
			{"type": "KYC", "x": 2150, "y": 270},
		  ]},
		# BOSS: Precinct Captain
		{ "trigger_x": 2800, "left": 2700, "right": 3100,
		  "enemies": [
			{"type": "BOSS", "x": 3050, "y": 280},
		  ]},
	]

func _check_encounters():
	if encounter_active:
		# Gate the player
		if player.global_position.x > gate_right - 16:
			player.global_position.x = gate_right - 16
		if player.global_position.x < gate_left + 16:
			player.global_position.x = gate_left + 16

		# Check if all enemies are dead
		var alive = get_tree().get_nodes_in_group("enemies")
		if alive.is_empty():
			_end_encounter()
		return

	# Check if player crossed the next trigger
	var next = current_encounter + 1
	if next >= encounters.size():
		return
	if player.global_position.x >= encounters[next]["trigger_x"]:
		current_encounter = next
		_start_encounter(encounters[next])

func _start_encounter(enc: Dictionary):
	encounter_active = true
	gate_left = enc["left"]
	gate_right = enc["right"]

	# Red gate barrier
	gate_visual = ColorRect.new()
	gate_visual.color = Color(1, 0.2, 0.2, 0.3)
	gate_visual.position = Vector2(gate_right - 4, FLOOR_TOP)
	gate_visual.size = Vector2(4, FLOOR_BOTTOM - FLOOR_TOP)
	gate_visual.z_index = 9990
	add_child(gate_visual)

	SFX.gate_lock(get_tree())

	# Spawn enemies
	for e_data in enc["enemies"]:
		_spawn_enemy(Vector2(e_data["x"], e_data["y"]), e_data["type"])

	# Announcement
	_show_announcement("ENEMIES INCOMING")

func _end_encounter():
	encounter_active = false
	if gate_visual:
		gate_visual.queue_free()
		gate_visual = null

	# Check if this was the last encounter (boss)
	if current_encounter >= encounters.size() - 1:
		get_tree().create_timer(1.5).timeout.connect(_on_level_complete)
		_show_announcement("LEVEL CLEAR")
	else:
		_show_announcement("AREA CLEAR")

func _spawn_enforcer(pos: Vector2):
	var e = CharacterBody2D.new()
	e.position = pos
	e.set_script(load("res://scripts/enemies/cbdc_enforcer.gd"))
	e.add_to_group("enemies")

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 8)
	col.shape = shape
	e.add_child(col)

	# Dark tactical armor body
	var body = ColorRect.new()
	body.color = Color(0.13, 0.13, 0.2)
	body.size = Vector2(26, 40)
	body.position = Vector2(-13, -44)
	e.add_child(body)

	var head_rect = ColorRect.new()
	head_rect.color = Color(0.13, 0.13, 0.2)
	head_rect.size = Vector2(20, 14)
	head_rect.position = Vector2(-10, -60)
	e.add_child(head_rect)

	# Visor (reflective)
	var visor = ColorRect.new()
	visor.color = Color(0.4, 0.6, 0.8)
	visor.size = Vector2(16, 6)
	visor.position = Vector2(-8, -54)
	e.add_child(visor)

	# Red CBDC insignia on chest
	var insignia = ColorRect.new()
	insignia.color = Color(1, 0.2, 0.2)
	insignia.size = Vector2(8, 4)
	insignia.position = Vector2(-4, -32)
	e.add_child(insignia)

	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(24, 5)
	shadow.position = Vector2(-12, -2)
	shadow.name = "Shadow"
	e.add_child(shadow)

	var hp_bg = ColorRect.new()
	hp_bg.color = Color(0.2, 0, 0)
	hp_bg.size = Vector2(32, 4)
	hp_bg.position = Vector2(-16, -68)
	hp_bg.name = "HPBarBG"
	e.add_child(hp_bg)

	var hp_bar = ColorRect.new()
	hp_bar.color = Color(1, 0.2, 0.2)
	hp_bar.size = Vector2(32, 4)
	hp_bar.position = Vector2(-16, -68)
	hp_bar.name = "HPBar"
	e.add_child(hp_bar)

	var lbl = Label.new()
	lbl.text = "ENFORCER"
	lbl.position = Vector2(-30, -80)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.53, 0.67, 1.0))
	lbl.name = "Label"
	e.add_child(lbl)

	add_child(e)

func _spawn_boss(pos: Vector2):
	var boss = CharacterBody2D.new()
	boss.position = pos
	boss.set_script(load("res://scripts/enemies/precinct_captain.gd"))
	boss.add_to_group("enemies")

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 10)
	col.shape = shape
	boss.add_child(col)

	# Boss body — dark blue uniform, larger than grunts
	var body = ColorRect.new()
	body.color = Color(0.0, 0.13, 0.4)
	body.size = Vector2(32, 52)
	body.position = Vector2(-16, -56)
	boss.add_child(body)

	var head_rect = ColorRect.new()
	head_rect.color = Color(0.0, 0.13, 0.4)
	head_rect.size = Vector2(24, 16)
	head_rect.position = Vector2(-12, -74)
	boss.add_child(head_rect)

	# Gold cap band
	var cap = ColorRect.new()
	cap.color = Color(1, 0.8, 0.2)
	cap.size = Vector2(28, 4)
	cap.position = Vector2(-14, -78)
	boss.add_child(cap)

	# Red stripe on chest
	var stripe = ColorRect.new()
	stripe.color = Color(1, 0.2, 0.2)
	stripe.size = Vector2(4, 30)
	stripe.position = Vector2(-2, -48)
	boss.add_child(stripe)

	# Gold epaulettes
	var ep_l = ColorRect.new()
	ep_l.color = Color(1, 0.8, 0.2)
	ep_l.size = Vector2(6, 4)
	ep_l.position = Vector2(-18, -54)
	boss.add_child(ep_l)

	var ep_r = ColorRect.new()
	ep_r.color = Color(1, 0.8, 0.2)
	ep_r.size = Vector2(6, 4)
	ep_r.position = Vector2(12, -54)
	boss.add_child(ep_r)

	# Eyes
	var eye_l = ColorRect.new()
	eye_l.color = Color.WHITE
	eye_l.size = Vector2(4, 4)
	eye_l.position = Vector2(-8, -70)
	boss.add_child(eye_l)

	var eye_r = ColorRect.new()
	eye_r.color = Color.WHITE
	eye_r.size = Vector2(4, 4)
	eye_r.position = Vector2(4, -70)
	boss.add_child(eye_r)

	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(30, 6)
	shadow.position = Vector2(-15, -2)
	shadow.name = "Shadow"
	boss.add_child(shadow)

	# HP bars hidden — boss uses screen-fixed boss bar
	var hp_bg = ColorRect.new()
	hp_bg.color = Color(0, 0, 0, 0)
	hp_bg.size = Vector2(1, 1)
	hp_bg.name = "HPBarBG"
	boss.add_child(hp_bg)

	var hp_bar = ColorRect.new()
	hp_bar.color = Color(0, 0, 0, 0)
	hp_bar.size = Vector2(1, 1)
	hp_bar.name = "HPBar"
	boss.add_child(hp_bar)

	add_child(boss)

	# Register surveillance cameras around the boss arena
	boss.register_cameras([
		Vector2(2720, 228),
		Vector2(2900, 228),
		Vector2(3080, 228),
	])

	# Boss announcement
	_show_announcement("BOSS: THE PRECINCT CAPTAIN")

func _show_announcement(text: String):
	var hud = get_node_or_null("HUD")
	if not hud:
		return
	var lbl = Label.new()
	lbl.text = text
	lbl.position = Vector2(160, 100)
	lbl.add_theme_font_size_override("font_size", 18)
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(320, 40)
	lbl.z_index = 9999
	hud.add_child(lbl)

	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)

func _show_level_splash(level_num: String, level_name: String, block_text: String):
	var hud = get_node_or_null("HUD")
	if not hud:
		return

	# Dark overlay
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.position = Vector2(0, 0)
	overlay.size = Vector2(640, 360)
	overlay.z_index = 99999
	hud.add_child(overlay)

	# Level number
	var num_lbl = Label.new()
	num_lbl.text = level_num
	num_lbl.position = Vector2(120, 100)
	num_lbl.add_theme_font_size_override("font_size", 28)
	num_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.size = Vector2(400, 40)
	num_lbl.z_index = 99999
	hud.add_child(num_lbl)

	# Level name
	var name_lbl = Label.new()
	name_lbl.text = level_name
	name_lbl.position = Vector2(120, 140)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size = Vector2(400, 40)
	name_lbl.z_index = 99999
	hud.add_child(name_lbl)

	# Block height
	var block_lbl = Label.new()
	block_lbl.text = block_text
	block_lbl.position = Vector2(120, 175)
	block_lbl.add_theme_font_size_override("font_size", 12)
	block_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_lbl.size = Vector2(400, 20)
	block_lbl.z_index = 99999
	hud.add_child(block_lbl)

	# Hint
	var hint = Label.new()
	hint.text = "ESC / P  PAUSE + HELP"
	hint.position = Vector2(120, 200)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0.4, 0.8, 1))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hint.size = Vector2(400, 20)
	hint.z_index = 99999
	hud.add_child(hint)

	# Fade out after 2 seconds
	var tween = overlay.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(num_lbl, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(name_lbl, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(block_lbl, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(hint, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func():
		overlay.queue_free()
		num_lbl.queue_free()
		name_lbl.queue_free()
		block_lbl.queue_free()
		hint.queue_free()
	)

func _on_player_died():
	# Death screen
	var hud = get_node_or_null("HUD")
	if not hud:
		return

	get_tree().paused = true

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = Vector2(640, 360)
	overlay.z_index = 99999
	hud.add_child(overlay)

	var title = Label.new()
	title.text = "NODE OFFLINE"
	title.position = Vector2(120, 120)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(400, 40)
	title.z_index = 99999
	hud.add_child(title)

	var prompt = Label.new()
	prompt.text = "[ENTER] RETRY    [ESC] QUIT"
	prompt.position = Vector2(120, 170)
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(0, 1, 0.4))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(400, 30)
	prompt.z_index = 99999
	hud.add_child(prompt)

	# Sats lost
	var sats_lbl = Label.new()
	sats_lbl.text = "SATS COLLECTED: %s" % _format_sats(GameState.sats)
	sats_lbl.position = Vector2(120, 200)
	sats_lbl.add_theme_font_size_override("font_size", 11)
	sats_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	sats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sats_lbl.size = Vector2(400, 20)
	sats_lbl.z_index = 99999
	hud.add_child(sats_lbl)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if get_tree().paused:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				get_tree().paused = false
				GameState.reset()
				get_tree().reload_current_scene()
			elif event.keycode == KEY_ESCAPE:
				get_tree().paused = false
				get_tree().quit()

func _on_level_complete():
	var hud = get_node_or_null("HUD")
	if not hud:
		return

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = Vector2(640, 360)
	overlay.z_index = 99999
	hud.add_child(overlay)

	var title = Label.new()
	title.text = "LEVEL COMPLETE"
	title.position = Vector2(120, 80)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0, 1, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(400, 40)
	title.z_index = 99999
	hud.add_child(title)

	var name_lbl = Label.new()
	name_lbl.text = "THE GRID"
	name_lbl.position = Vector2(120, 110)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size = Vector2(400, 30)
	name_lbl.z_index = 99999
	hud.add_child(name_lbl)

	# Stats
	var stats = [
		"SATS COLLECTED: %s" % _format_sats(GameState.sats),
		"ENEMIES VALIDATED: %d" % (current_encounter + 1),
	]
	for s_idx in range(stats.size()):
		var s_lbl = Label.new()
		s_lbl.text = stats[s_idx]
		s_lbl.position = Vector2(120, 160 + s_idx * 20)
		s_lbl.add_theme_font_size_override("font_size", 12)
		s_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
		s_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		s_lbl.size = Vector2(400, 20)
		s_lbl.z_index = 99999
		hud.add_child(s_lbl)

	var prompt = Label.new()
	prompt.text = "[ENTER] CONTINUE"
	prompt.position = Vector2(120, 260)
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(0, 1, 0.4))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(400, 30)
	prompt.z_index = 99999
	hud.add_child(prompt)
