extends Node2D

## Level 2 — THE VAULT
## Financial district. Marble and gold. The Central Banker prints money.
## Destroy the money printer. Break the system.

const FLOOR_TOP = 275
const FLOOR_BOTTOM = 345
const LEVEL_WIDTH = 3200

var player: CharacterBody2D
var camera: Camera2D

func _ready():
	# === BACKGROUNDS ===
	# Reuse Synth Cities layers with a warmer gold tint for the financial district
	_add_parallax_layer("res://assets/backgrounds/synth_back.png", -100, 0.15, 0)
	_add_parallax_layer("res://assets/backgrounds/synth_middle.png", -80, 0.35, 0)
	_add_parallax_layer("res://assets/backgrounds/synth_foreground_themed.png", -60, 0.6, 360)

	# Gold-tinted overlay for financial district feel
	var gold_overlay = ColorRect.new()
	gold_overlay.color = Color(0.4, 0.3, 0.1, 0.08)
	gold_overlay.size = Vector2(LEVEL_WIDTH, 360)
	gold_overlay.z_index = -40
	add_child(gold_overlay)

	# Floor darkening
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

	# Floor grid lines (marble-style)
	for gy in range(FLOOR_TOP, FLOOR_BOTTOM, 20):
		var line = ColorRect.new()
		line.color = Color(0.5, 0.4, 0.3, 0.08)
		line.position = Vector2(0, gy)
		line.size = Vector2(LEVEL_WIDTH, 1)
		line.z_index = -44
		add_child(line)

	# === PLAYER ===
	player = _create_player(Vector2(100, 300))
	add_child(player)
	player.died.connect(_on_player_died)

	# Camera
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 8.0
	camera.limit_left = 0
	camera.limit_right = LEVEL_WIDTH
	camera.limit_top = 0
	camera.limit_bottom = 360
	player.add_child(camera)
	camera.make_current()

	# === DESTRUCTIBLE PROPS ===
	Destructible.spawn(self, Vector2(300, FLOOR_TOP + 2), Destructible.PropType.ATM)
	Destructible.spawn(self, Vector2(700, FLOOR_TOP + 5), Destructible.PropType.CRATE)
	Destructible.spawn(self, Vector2(1100, FLOOR_TOP + 2), Destructible.PropType.VENDING)
	Destructible.spawn(self, Vector2(1500, FLOOR_TOP + 5), Destructible.PropType.CRATE)
	Destructible.spawn(self, Vector2(1900, FLOOR_TOP - 10), Destructible.PropType.BILLBOARD)
	Destructible.spawn(self, Vector2(2300, FLOOR_TOP + 2), Destructible.PropType.ATM)
	Destructible.spawn(self, Vector2(2700, FLOOR_TOP + 5), Destructible.PropType.CRATE)

	# Pre-placed power-ups
	Pickup.spawn_power_up(self, Vector2(200, 300), Pickup.PickupType.ORANGE_PILL)
	Pickup.spawn_power_up(self, Vector2(1400, 300), Pickup.PickupType.FULL_NODE)
	Pickup.spawn_power_up(self, Vector2(2400, 300), Pickup.PickupType.ORANGE_PILL)

	# === ENCOUNTERS ===
	_setup_encounters()

	# === RAIN (lighter for indoors feel) ===
	_spawn_rain()

	# === HUD ===
	_create_hud()

	# === PAUSE MENU ===
	var pause_menu = CanvasLayer.new()
	pause_menu.set_script(load("res://scripts/pause_menu.gd"))
	add_child(pause_menu)

	# === INVISIBLE WALLS ===
	_create_bounds()

	# Level splash
	_show_level_splash("LEVEL 2", "THE VAULT", "BLOCK 840,010")

	print("[Level 2] Ready — THE VAULT")

func _create_bounds():
	# Top wall
	var top_wall = StaticBody2D.new()
	top_wall.position = Vector2(LEVEL_WIDTH / 2.0, FLOOR_TOP - 4)
	var top_col = CollisionShape2D.new()
	var top_shape = RectangleShape2D.new()
	top_shape.size = Vector2(LEVEL_WIDTH, 8)
	top_col.shape = top_shape
	top_wall.add_child(top_col)
	add_child(top_wall)

	# Bottom wall
	var bot_wall = StaticBody2D.new()
	bot_wall.position = Vector2(LEVEL_WIDTH / 2.0, FLOOR_BOTTOM + 4)
	var bot_col = CollisionShape2D.new()
	var bot_shape = RectangleShape2D.new()
	bot_shape.size = Vector2(LEVEL_WIDTH, 8)
	bot_col.shape = bot_shape
	bot_wall.add_child(bot_col)
	add_child(bot_wall)

func _add_parallax_layer(path: String, z: int, scroll_factor: float, bottom_align_y: int):
	var tex = load(path)
	if not tex:
		return
	var img_w = tex.get_width()
	var img_h = tex.get_height()
	var tiles_needed = int(LEVEL_WIDTH / img_w) + 3
	var prefix = "parallax_%d_" % z

	for i in range(tiles_needed):
		var sprite = Sprite2D.new()
		sprite.texture = tex
		sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		sprite.centered = false

		if bottom_align_y > 0:
			sprite.position = Vector2(i * img_w, bottom_align_y - img_h)
		else:
			sprite.position = Vector2(i * img_w, 0)

		sprite.z_index = z
		sprite.name = prefix + str(i)
		add_child(sprite)

	_parallax_layers.append({"prefix": prefix, "factor": scroll_factor})

func _create_player(pos: Vector2) -> CharacterBody2D:
	var p = CharacterBody2D.new()
	p.position = pos
	p.set_script(load("res://scripts/player.gd"))
	p.add_to_group("players")

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 10)
	col.shape = shape
	p.add_child(col)

	var body = ColorRect.new()
	body.color = Color(1.0, 0.6, 0.0)
	body.size = Vector2(24, 40)
	body.position = Vector2(-12, -44)
	p.add_child(body)

	var head = ColorRect.new()
	head.color = Color(1.0, 0.6, 0.0)
	head.size = Vector2(18, 14)
	head.position = Vector2(-9, -60)
	p.add_child(head)

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

	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(28, 6)
	shadow.position = Vector2(-14, -2)
	shadow.name = "Shadow"
	p.add_child(shadow)

	var lbl = Label.new()
	lbl.text = "NODE"
	lbl.position = Vector2(-20, -72)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	lbl.name = "Label"
	p.add_child(lbl)

	return p

func _spawn_enemy(pos: Vector2, type: String):
	if type == "ENFORCER":
		_spawn_enforcer(pos)
		return
	if type == "DRONE":
		_spawn_drone(pos)
		return
	if type == "VERIBOT":
		_spawn_veribot(pos)
		return
	if type == "BOSS":
		_spawn_boss(pos)
		return

	var e = CharacterBody2D.new()
	e.position = pos

	if type == "BANKER":
		e.set_script(load("res://scripts/enemies/banker.gd"))
	else:
		e.set_script(load("res://scripts/enemy.gd"))
		e.set("enemy_name", type)
		if type == "TELLER":
			e.set("max_hp", 15)
			e.set("speed", 70.0)
			e.set("drop_sats", 50)

	e.add_to_group("enemies")

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 8)
	col.shape = shape
	e.add_child(col)

	var color: Color
	match type:
		"KYC": color = Color(0.29, 0.44, 0.65)
		"BANKER": color = Color(0.0, 0.67, 0.27)
		"TELLER": color = Color(0.2, 0.4, 0.2)
		_: color = Color(0.4, 0.4, 0.5)

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

	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(24, 5)
	shadow.position = Vector2(-12, -2)
	shadow.name = "Shadow"
	e.add_child(shadow)

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

	var lbl = Label.new()
	lbl.text = type
	lbl.position = Vector2(-20, -74)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.53, 0.67, 1.0))
	lbl.name = "Label"
	e.add_child(lbl)

	add_child(e)

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

	var visor = ColorRect.new()
	visor.color = Color(0.4, 0.6, 0.8)
	visor.size = Vector2(16, 6)
	visor.position = Vector2(-8, -54)
	e.add_child(visor)

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

func _spawn_drone(pos: Vector2):
	var e = CharacterBody2D.new()
	e.position = pos
	e.set_script(load("res://scripts/enemies/compliance_drone.gd"))
	e.add_to_group("enemies")

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(16, 8)
	col.shape = shape
	e.add_child(col)

	# Small angular drone body
	var body = ColorRect.new()
	body.color = Color(0.25, 0.25, 0.3)
	body.size = Vector2(20, 14)
	body.position = Vector2(-10, -18)
	e.add_child(body)

	# Red eye/lens
	var eye = ColorRect.new()
	eye.color = Color(1, 0.1, 0.1)
	eye.size = Vector2(6, 4)
	eye.position = Vector2(-3, -14)
	e.add_child(eye)

	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.3)
	shadow.size = Vector2(16, 4)
	shadow.position = Vector2(-8, -2)
	shadow.name = "Shadow"
	e.add_child(shadow)

	var hp_bg = ColorRect.new()
	hp_bg.color = Color(0.2, 0, 0)
	hp_bg.size = Vector2(24, 3)
	hp_bg.position = Vector2(-12, -24)
	hp_bg.name = "HPBarBG"
	e.add_child(hp_bg)

	var hp_bar = ColorRect.new()
	hp_bar.color = Color(1, 0.2, 0.2)
	hp_bar.size = Vector2(24, 3)
	hp_bar.position = Vector2(-12, -24)
	hp_bar.name = "HPBar"
	e.add_child(hp_bar)

	var lbl = Label.new()
	lbl.text = "DRONE"
	lbl.position = Vector2(-18, -32)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0.53, 0.67, 1.0))
	lbl.name = "Label"
	e.add_child(lbl)

	add_child(e)

func _spawn_veribot(pos: Vector2):
	var e = CharacterBody2D.new()
	e.position = pos
	e.set_script(load("res://scripts/enemies/verification_bot.gd"))
	e.add_to_group("enemies")

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(24, 10)
	col.shape = shape
	e.add_child(col)

	# Boxy kiosk body
	var body = ColorRect.new()
	body.color = Color(0.35, 0.4, 0.45)
	body.size = Vector2(28, 44)
	body.position = Vector2(-14, -48)
	e.add_child(body)

	var head = ColorRect.new()
	head.color = Color(0.3, 0.35, 0.4)
	head.size = Vector2(22, 10)
	head.position = Vector2(-11, -60)
	e.add_child(head)

	# Screen on chest
	var screen = ColorRect.new()
	screen.color = Color(0, 0.6, 0.8)
	screen.size = Vector2(20, 14)
	screen.position = Vector2(-10, -42)
	e.add_child(screen)

	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(28, 6)
	shadow.position = Vector2(-14, -2)
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
	lbl.text = "VERIBOT"
	lbl.position = Vector2(-24, -78)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0.53, 0.67, 1.0))
	lbl.name = "Label"
	e.add_child(lbl)

	add_child(e)

func _spawn_boss(pos: Vector2):
	var boss = CharacterBody2D.new()
	boss.position = pos
	boss.set_script(load("res://scripts/enemies/central_banker.gd"))
	boss.add_to_group("enemies")

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(28, 10)
	col.shape = shape
	boss.add_child(col)

	# Distinguished suit — dark grey with gold accents
	var body = ColorRect.new()
	body.color = Color(0.25, 0.25, 0.3)
	body.size = Vector2(30, 50)
	body.position = Vector2(-15, -54)
	boss.add_child(body)

	var head = ColorRect.new()
	head.color = Color(0.6, 0.55, 0.5)  # Skin tone
	head.size = Vector2(22, 16)
	head.position = Vector2(-11, -72)
	boss.add_child(head)

	# Monocle
	var monocle = ColorRect.new()
	monocle.color = Color(0.8, 0.9, 1)
	monocle.size = Vector2(6, 6)
	monocle.position = Vector2(2, -68)
	boss.add_child(monocle)

	# Gold pocket watch chain
	var chain = ColorRect.new()
	chain.color = Color(1, 0.8, 0.2)
	chain.size = Vector2(12, 2)
	chain.position = Vector2(-6, -38)
	boss.add_child(chain)

	# Vest/waistcoat
	var vest = ColorRect.new()
	vest.color = Color(0.35, 0.2, 0.15)
	vest.size = Vector2(22, 24)
	vest.position = Vector2(-11, -48)
	boss.add_child(vest)

	var shadow = ColorRect.new()
	shadow.color = Color(0, 0, 0, 0.4)
	shadow.size = Vector2(30, 6)
	shadow.position = Vector2(-15, -2)
	shadow.name = "Shadow"
	boss.add_child(shadow)

	# Boss uses screen-fixed bar, hide entity bar
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
	_show_announcement("BOSS: THE CENTRAL BANKER")

func _spawn_rain():
	for i in range(20):  # Lighter rain for indoor feel
		var drop = ColorRect.new()
		drop.color = Color(0.53, 0.67, 1.0, 0.2)
		drop.size = Vector2(1, 4)
		drop.rotation = deg_to_rad(15)
		drop.position = Vector2(randf() * 640, randf() * 220)
		drop.z_index = 100
		add_child(drop)

		var tween = create_tween().set_loops()
		tween.tween_property(drop, "position:y", 240.0, randf_range(0.5, 1.0))
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

	var name_lbl = Label.new()
	name_lbl.text = "> P1 NODE_RUNNER"
	name_lbl.position = Vector2(8, 4)
	name_lbl.add_theme_font_size_override("font_size", 11)
	name_lbl.add_theme_color_override("font_color", green)
	hud.add_child(name_lbl)

	var hp_lbl = Label.new()
	hp_lbl.name = "HPLabel"
	hp_lbl.text = "HP [██████████] 100/100"
	hp_lbl.position = Vector2(8, 18)
	hp_lbl.add_theme_font_size_override("font_size", 10)
	hp_lbl.add_theme_color_override("font_color", green)
	hud.add_child(hp_lbl)

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

	var sats_lbl = Label.new()
	sats_lbl.name = "SatsLabel"
	sats_lbl.text = "SATS: %s" % _format_sats(GameState.sats)
	sats_lbl.position = Vector2(490, 4)
	sats_lbl.add_theme_font_size_override("font_size", 12)
	sats_lbl.add_theme_color_override("font_color", orange)
	sats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	sats_lbl.size = Vector2(140, 20)
	hud.add_child(sats_lbl)

	var block_lbl = Label.new()
	block_lbl.name = "BlockLabel"
	block_lbl.text = "BLOCK 840,010"
	block_lbl.position = Vector2(490, 20)
	block_lbl.add_theme_font_size_override("font_size", 10)
	block_lbl.add_theme_color_override("font_color", green)
	block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	block_lbl.size = Vector2(140, 20)
	hud.add_child(block_lbl)

	var status = Label.new()
	status.name = "StatusLabel"
	status.text = "> awaiting_input_"
	status.position = Vector2(8, 340)
	status.add_theme_font_size_override("font_size", 9)
	status.add_theme_color_override("font_color", dim_green)
	hud.add_child(status)

	var hint = Label.new()
	hint.text = "WASD move  Z attack  X special  C jump  V grab  ESC pause"
	hint.position = Vector2(150, 348)
	hint.add_theme_font_size_override("font_size", 9)
	hint.add_theme_color_override("font_color", dim_green)
	hud.add_child(hint)

# ==== PARALLAX + HUD UPDATE ====

var _parallax_layers: Array = []
var _last_cam_x: float = 0

var encounters: Array = []
var current_encounter: int = -1
var encounter_active: bool = false
var gate_left: float = 0
var gate_right: float = 0
var gate_visual: ColorRect = null

var _block_tick_timer: float = 0.0
var _block_height: int = 840010
var _blink_timer: float = 0.0

func _process(delta):
	if not player or not is_instance_valid(player):
		return

	_check_encounters()

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

	var hp_lbl = hud.get_node_or_null("HPLabel")
	if hp_lbl:
		var pct = float(player.hp) / float(player.max_hp)
		var blocks = int(pct * 10)
		var bar_str = "█".repeat(blocks) + "░".repeat(10 - blocks)
		hp_lbl.text = "HP [%s] %d/%d" % [bar_str, player.hp, player.max_hp]
		if pct < 0.3:
			hp_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		elif pct < 0.6:
			hp_lbl.add_theme_color_override("font_color", Color(1, 0.7, 0))
		else:
			hp_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))

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

	var sats_lbl = hud.get_node_or_null("SatsLabel")
	if sats_lbl:
		sats_lbl.text = "SATS: %s" % _format_sats(GameState.sats)

	_block_tick_timer += delta
	if _block_tick_timer > 10.0:
		_block_tick_timer = 0
		_block_height += 1
	var block_lbl = hud.get_node_or_null("BlockLabel")
	if block_lbl:
		block_lbl.text = "BLOCK %s" % _format_number(_block_height)

	_blink_timer += delta
	var status_lbl = hud.get_node_or_null("StatusLabel")
	if status_lbl:
		var cursor = "_" if fmod(_blink_timer, 1.0) < 0.5 else " "
		status_lbl.text = "> awaiting_input%s" % cursor

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

# ==== ENCOUNTERS ====

func _setup_encounters():
	encounters = [
		# Encounter 1: Bank tellers (easy intro)
		{ "trigger_x": 400, "left": 320, "right": 700,
		  "enemies": [
			{"type": "TELLER", "x": 650, "y": 280},
			{"type": "TELLER", "x": 660, "y": 310},
			{"type": "KYC", "x": 360, "y": 290},
		  ]},
		# Encounter 2: Verification bot + KYC (area denial intro)
		{ "trigger_x": 900, "left": 820, "right": 1250,
		  "enemies": [
			{"type": "VERIBOT", "x": 1100, "y": 290},
			{"type": "KYC", "x": 870, "y": 280},
			{"type": "BANKER", "x": 1200, "y": 300},
		  ]},
		# Encounter 3: Drone + Enforcers (reinforcement pressure)
		{ "trigger_x": 1500, "left": 1420, "right": 1900,
		  "enemies": [
			{"type": "DRONE", "x": 1800, "y": 290},
			{"type": "ENFORCER", "x": 1460, "y": 300},
			{"type": "KYC", "x": 1850, "y": 270},
			{"type": "BANKER", "x": 1460, "y": 270},
		  ]},
		# Encounter 4: Full mix (all enemy types)
		{ "trigger_x": 2200, "left": 2100, "right": 2600,
		  "enemies": [
			{"type": "VERIBOT", "x": 2500, "y": 290},
			{"type": "DRONE", "x": 2400, "y": 280},
			{"type": "ENFORCER", "x": 2150, "y": 300},
			{"type": "KYC", "x": 2550, "y": 270},
		  ]},
		# BOSS: The Central Banker
		{ "trigger_x": 2800, "left": 2700, "right": 3100,
		  "enemies": [
			{"type": "BOSS", "x": 3000, "y": 290},
		  ]},
	]

func _check_encounters():
	if encounter_active:
		if player.global_position.x > gate_right - 16:
			player.global_position.x = gate_right - 16
		if player.global_position.x < gate_left + 16:
			player.global_position.x = gate_left + 16

		var alive = get_tree().get_nodes_in_group("enemies")
		if alive.is_empty():
			_end_encounter()
		return

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

	gate_visual = ColorRect.new()
	gate_visual.color = Color(1, 0.2, 0.2, 0.3)
	gate_visual.position = Vector2(gate_right - 4, FLOOR_TOP)
	gate_visual.size = Vector2(4, FLOOR_BOTTOM - FLOOR_TOP)
	gate_visual.z_index = 3000
	add_child(gate_visual)

	SFX.gate_lock(get_tree())

	for e_data in enc["enemies"]:
		_spawn_enemy(Vector2(e_data["x"], e_data["y"]), e_data["type"])

	_show_announcement("ENEMIES INCOMING")

func _end_encounter():
	encounter_active = false
	if gate_visual:
		gate_visual.queue_free()
		gate_visual = null

	if current_encounter >= encounters.size() - 1:
		get_tree().create_timer(1.5).timeout.connect(_on_level_complete)
		_show_announcement("LEVEL CLEAR")
	else:
		_show_announcement("AREA CLEAR")

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
	lbl.z_index = 3500
	hud.add_child(lbl)

	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)

func _show_level_splash(level_num: String, level_name: String, block_text: String):
	var hud = get_node_or_null("HUD")
	if not hud:
		return

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = Vector2(640, 360)
	overlay.z_index = 4000
	hud.add_child(overlay)

	var num_lbl = Label.new()
	num_lbl.text = level_num
	num_lbl.position = Vector2(120, 100)
	num_lbl.add_theme_font_size_override("font_size", 28)
	num_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	num_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	num_lbl.size = Vector2(400, 40)
	num_lbl.z_index = 4000
	hud.add_child(num_lbl)

	var name_lbl = Label.new()
	name_lbl.text = level_name
	name_lbl.position = Vector2(120, 140)
	name_lbl.add_theme_font_size_override("font_size", 22)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size = Vector2(400, 40)
	name_lbl.z_index = 4000
	hud.add_child(name_lbl)

	var block_lbl = Label.new()
	block_lbl.text = block_text
	block_lbl.position = Vector2(120, 175)
	block_lbl.add_theme_font_size_override("font_size", 12)
	block_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	block_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	block_lbl.size = Vector2(400, 20)
	block_lbl.z_index = 4000
	hud.add_child(block_lbl)

	var tween = overlay.create_tween()
	tween.tween_interval(1.5)
	tween.tween_property(overlay, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(num_lbl, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(name_lbl, "modulate:a", 0.0, 0.7)
	tween.parallel().tween_property(block_lbl, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func():
		overlay.queue_free()
		num_lbl.queue_free()
		name_lbl.queue_free()
		block_lbl.queue_free()
	)

func _on_player_died():
	var hud = get_node_or_null("HUD")
	if not hud:
		return
	get_tree().paused = true

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.8)
	overlay.size = Vector2(640, 360)
	overlay.z_index = 4000
	hud.add_child(overlay)

	var title = Label.new()
	title.text = "NODE OFFLINE"
	title.position = Vector2(120, 120)
	title.add_theme_font_size_override("font_size", 24)
	title.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(400, 40)
	title.z_index = 4000
	hud.add_child(title)

	var prompt = Label.new()
	prompt.text = "[ENTER] RETRY    [ESC] QUIT"
	prompt.position = Vector2(120, 170)
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(0, 1, 0.4))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(400, 30)
	prompt.z_index = 4000
	hud.add_child(prompt)

func _on_level_complete():
	var hud = get_node_or_null("HUD")
	if not hud:
		return

	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = Vector2(640, 360)
	overlay.z_index = 4000
	hud.add_child(overlay)

	var title = Label.new()
	title.text = "LEVEL COMPLETE"
	title.position = Vector2(120, 80)
	title.add_theme_font_size_override("font_size", 22)
	title.add_theme_color_override("font_color", Color(0, 1, 0.4))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(400, 40)
	title.z_index = 4000
	hud.add_child(title)

	var name_lbl = Label.new()
	name_lbl.text = "THE VAULT"
	name_lbl.position = Vector2(120, 110)
	name_lbl.add_theme_font_size_override("font_size", 18)
	name_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	name_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	name_lbl.size = Vector2(400, 30)
	name_lbl.z_index = 4000
	hud.add_child(name_lbl)

	var stats_lbl = Label.new()
	stats_lbl.text = "SATS COLLECTED: %s" % _format_sats(GameState.sats)
	stats_lbl.position = Vector2(120, 160)
	stats_lbl.add_theme_font_size_override("font_size", 12)
	stats_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	stats_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats_lbl.size = Vector2(400, 20)
	stats_lbl.z_index = 4000
	hud.add_child(stats_lbl)

	var prompt = Label.new()
	prompt.text = "[ENTER] CONTINUE"
	prompt.position = Vector2(120, 260)
	prompt.add_theme_font_size_override("font_size", 12)
	prompt.add_theme_color_override("font_color", Color(0, 1, 0.4))
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.size = Vector2(400, 30)
	prompt.z_index = 4000
	hud.add_child(prompt)

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if get_tree().paused:
			if event.keycode == KEY_ENTER or event.keycode == KEY_KP_ENTER:
				get_tree().paused = false
				get_tree().change_scene_to_file("res://scenes/ui/title_screen.tscn")
			elif event.keycode == KEY_ESCAPE:
				get_tree().paused = false
				get_tree().quit()
