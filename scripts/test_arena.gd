extends Node2D

## Test Arena — builds the scene in code so we don't fight .tscn format.
## Hit F5 and punch some KYC agents.

const FLOOR_TOP = 220
const FLOOR_BOTTOM = 340
const LEVEL_WIDTH = 3200

var player: CharacterBody2D
var camera: Camera2D

func _ready():
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.04, 0.055, 0.08)
	bg.size = Vector2(LEVEL_WIDTH, 360)
	add_child(bg)

	# Far skyline parallax
	var parallax_bg = ParallaxBackground.new()
	add_child(parallax_bg)

	if ResourceLoader.exists("res://assets/backgrounds/bg_skyline_far.png"):
		var sky_layer = ParallaxLayer.new()
		sky_layer.motion_scale = Vector2(0.3, 0)
		sky_layer.motion_mirroring = Vector2(540, 0)
		parallax_bg.add_child(sky_layer)

		var sky_sprite = Sprite2D.new()
		sky_sprite.texture = load("res://assets/backgrounds/bg_skyline_far.png")
		sky_sprite.position = Vector2(270, 180)
		sky_layer.add_child(sky_sprite)

	# Mid buildings parallax
	if ResourceLoader.exists("res://assets/backgrounds/bg_buildings_mid.png"):
		var mid_layer = ParallaxLayer.new()
		mid_layer.motion_scale = Vector2(0.5, 0)
		mid_layer.motion_mirroring = Vector2(1800, 0)
		parallax_bg.add_child(mid_layer)

		var mid_sprite = Sprite2D.new()
		mid_sprite.texture = load("res://assets/backgrounds/bg_buildings_mid.png")
		mid_sprite.position = Vector2(900, FLOOR_TOP - 100)
		mid_layer.add_child(mid_sprite)

	# Floor
	var floor_rect = ColorRect.new()
	floor_rect.color = Color(0.07, 0.086, 0.12)
	floor_rect.position = Vector2(0, FLOOR_TOP)
	floor_rect.size = Vector2(LEVEL_WIDTH, FLOOR_BOTTOM - FLOOR_TOP)
	add_child(floor_rect)

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

	# Enemies
	_spawn_enemy(Vector2(350, 270), "KYC")
	_spawn_enemy(Vector2(450, 300), "KYC")
	_spawn_enemy(Vector2(600, 260), "BANKER")

	# HUD
	_create_hud()

	print("[TestArena] Ready — WASD to move, Z to attack!")

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
	var e = CharacterBody2D.new()
	e.position = pos
	e.set_script(load("res://scripts/enemy.gd"))
	e.add_to_group("enemies")

	# Set enemy properties
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

	# Character name
	var name_lbl = Label.new()
	name_lbl.text = "> P1 NODE RUNNER"
	name_lbl.position = Vector2(10, 6)
	name_lbl.add_theme_font_size_override("font_size", 12)
	name_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	hud.add_child(name_lbl)

	# HP
	var hp_lbl = Label.new()
	hp_lbl.name = "HPLabel"
	hp_lbl.text = "HP 100/100"
	hp_lbl.position = Vector2(10, 24)
	hp_lbl.add_theme_font_size_override("font_size", 11)
	hp_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	hud.add_child(hp_lbl)

	# HP bar
	var bar_bg = ColorRect.new()
	bar_bg.color = Color(0, 0.13, 0)
	bar_bg.position = Vector2(10, 42)
	bar_bg.size = Vector2(200, 6)
	hud.add_child(bar_bg)

	var bar = ColorRect.new()
	bar.name = "HPBar"
	bar.color = Color(0, 1, 0.4)
	bar.position = Vector2(10, 42)
	bar.size = Vector2(200, 6)
	hud.add_child(bar)

	# Sats
	var sats_lbl = Label.new()
	sats_lbl.name = "SatsLabel"
	sats_lbl.text = "SATS 3000"
	sats_lbl.position = Vector2(500, 6)
	sats_lbl.add_theme_font_size_override("font_size", 12)
	sats_lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	hud.add_child(sats_lbl)

	# Block height
	var block_lbl = Label.new()
	block_lbl.text = "BLOCK 840000"
	block_lbl.position = Vector2(500, 24)
	block_lbl.add_theme_font_size_override("font_size", 11)
	block_lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	hud.add_child(block_lbl)

	# Controls hint
	var hint = Label.new()
	hint.text = "MOVE WASD    Z ATTACK    X SPECIAL    C JUMP    V GRAB    ESC PAUSE"
	hint.position = Vector2(80, 340)
	hint.add_theme_font_size_override("font_size", 10)
	hint.add_theme_color_override("font_color", Color(0, 1, 0.4))
	hud.add_child(hint)

func _process(_delta):
	# Update HUD
	if player and is_instance_valid(player):
		var hud = get_node_or_null("HUD")
		if hud:
			var hp_lbl = hud.get_node_or_null("HPLabel")
			if hp_lbl:
				hp_lbl.text = "HP %d/%d" % [player.hp, player.max_hp]
			var bar = hud.get_node_or_null("HPBar")
			if bar:
				bar.size.x = 200.0 * (float(player.hp) / float(player.max_hp))
			var sats_lbl = hud.get_node_or_null("SatsLabel")
			if sats_lbl:
				sats_lbl.text = "SATS %d" % GameState.sats
