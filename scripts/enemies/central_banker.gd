extends Enemy
class_name CentralBanker

## THE CENTRAL BANKER — Level 2 boss.
## Distinguished older man with cane. Prints endless waves of enemies from money printer.
## Players must balance attacking the boss vs destroying the printer.
## Phase 2: printer malfunctions, spawns enforcers instead.

var printer_hp: int = 80
var printer_max_hp: int = 80
var printer_active: bool = true
var printer_visual: Node2D = null
var printer_spawn_timer: float = 0.0
var printer_spawn_interval: float = 6.0
var gold_throw_timer: float = 0.0
var gold_throw_interval: float = 3.5
var phase: int = 1
var boss_bar: ColorRect = null
var boss_bar_bg: ColorRect = null
var boss_label: Label = null
var printer_bar: ColorRect = null
var printer_label: Label = null

func _ready():
	super._ready()
	speed = 55
	max_hp = int(280 * GameState.enemy_hp_mult())
	hp = max_hp
	damage = 12
	attack_range = 44
	attack_cooldown = 1.2
	drop_sats = 2000
	enemy_name = "CENTRAL BANKER"

	# Recolor to suit grey
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			child.color = Color(0.3, 0.3, 0.35)

	# Build boss HP bar on HUD
	_create_boss_bar()

	# Build money printer in the arena
	get_tree().create_timer(0.1).timeout.connect(_create_printer)

func _create_boss_bar():
	var hud = get_tree().root.get_node_or_null("Level2/HUD")
	if not hud:
		# Try after a frame
		get_tree().create_timer(0.2).timeout.connect(_create_boss_bar)
		return

	boss_bar_bg = ColorRect.new()
	boss_bar_bg.color = Color(0.15, 0, 0)
	boss_bar_bg.position = Vector2(140, 50)
	boss_bar_bg.size = Vector2(360, 8)
	boss_bar_bg.z_index = 3000
	hud.add_child(boss_bar_bg)

	boss_bar = ColorRect.new()
	boss_bar.color = Color(0.8, 0.2, 0.2)
	boss_bar.position = Vector2(140, 50)
	boss_bar.size = Vector2(360, 8)
	boss_bar.z_index = 3001
	hud.add_child(boss_bar)

	boss_label = Label.new()
	boss_label.text = "PID 6102  THE CENTRAL BANKER"
	boss_label.position = Vector2(140, 36)
	boss_label.add_theme_font_size_override("font_size", 10)
	boss_label.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	boss_label.z_index = 3001
	hud.add_child(boss_label)

func _create_printer():
	# Money printer — positioned to the right of the boss arena
	printer_visual = Node2D.new()
	printer_visual.global_position = Vector2(global_position.x + 120, global_position.y - 10)
	printer_visual.name = "MoneyPrinter"
	get_parent().add_child(printer_visual)

	# Printer body
	var body = ColorRect.new()
	body.color = Color(0.2, 0.25, 0.3)
	body.size = Vector2(40, 50)
	body.position = Vector2(-20, -52)
	printer_visual.add_child(body)

	# Screen
	var screen = ColorRect.new()
	screen.color = Color(0, 0.6, 0.2)
	screen.size = Vector2(30, 12)
	screen.position = Vector2(-15, -48)
	screen.name = "Screen"
	printer_visual.add_child(screen)

	# Label
	var lbl = Label.new()
	lbl.text = "MONEY\nPRINTER"
	lbl.position = Vector2(-25, -70)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", Color(0, 0.8, 0.3))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(50, 20)
	printer_visual.add_child(lbl)

	# HP bar for printer
	var hud = get_tree().root.get_node_or_null("Level2/HUD")
	if hud:
		printer_label = Label.new()
		printer_label.text = "PRINTER: ████████"
		printer_label.position = Vector2(140, 62)
		printer_label.add_theme_font_size_override("font_size", 9)
		printer_label.add_theme_color_override("font_color", Color(0, 0.8, 0.3))
		printer_label.z_index = 3001
		hud.add_child(printer_label)

	printer_visual.z_index = int(printer_visual.global_position.y)

	# Make printer attackable by player
	printer_visual.add_to_group("destructibles")

func _ai(now: float):
	var target = _find_target()
	if not target:
		return

	var dir = target.global_position - global_position
	var dist = dir.length()
	facing = 1 if dir.x > 0 else -1

	# Phase 1: melee + printer spawns enemies
	if dist > attack_range:
		velocity = dir.normalized() * speed
	else:
		velocity = Vector2.ZERO
		if now - last_attack_time > attack_cooldown:
			last_attack_time = now
			_cane_attack(target)

	# Printer spawns enemies periodically
	if printer_active:
		printer_spawn_timer += get_physics_process_delta_time()
		if printer_spawn_timer > printer_spawn_interval:
			printer_spawn_timer = 0
			_printer_spawn()

		# Boss heals while printer is active
		if hp < max_hp:
			hp = min(max_hp, hp + 1)

	# Gold bar throw in phase 2
	if phase == 2:
		gold_throw_timer += get_physics_process_delta_time()
		if gold_throw_timer > gold_throw_interval:
			gold_throw_timer = 0
			_throw_gold_bar(target)

	# Check printer damage (player attacks near printer)
	_check_printer_hits()

func _cane_attack(target: Node2D):
	if target.has_method("take_hit"):
		var from_dir = 1 if global_position.x < target.global_position.x else -1
		target.take_hit(int(damage * GameState.enemy_dmg_mult()), from_dir)
		SFX.hit_heavy(get_tree())
		CombatJuice.hit_sparks(get_parent(), target.global_position + Vector2(0, -20), Color(1, 0.8, 0.2))

func _printer_spawn():
	if not printer_visual or not is_instance_valid(printer_visual):
		printer_active = false
		return

	SFX.special(get_tree())

	# Show "BRRR" text
	var lbl = Label.new()
	lbl.text = "BRRR"
	lbl.global_position = printer_visual.global_position + Vector2(-15, -80)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(0, 0.8, 0.3))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)

	# Spawn enemy near printer
	var spawn_pos = printer_visual.global_position + Vector2(randf_range(-30, 30), randf_range(-5, 5))
	var e = CharacterBody2D.new()
	e.position = spawn_pos

	if phase == 1:
		e.set_script(load("res://scripts/enemy.gd"))
		e.set("enemy_name", "TELLER")
		e.set("max_hp", 15)
		e.set("speed", 70.0)
		e.set("drop_sats", 50)
	else:
		e.set_script(load("res://scripts/enemies/cbdc_enforcer.gd"))

	e.add_to_group("enemies")

	# Collision
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 8)
	col.shape = shape
	e.add_child(col)

	# Visual
	var body_color = Color(0.2, 0.4, 0.2) if phase == 1 else Color(0.13, 0.13, 0.2)
	var body = ColorRect.new()
	body.color = body_color
	body.size = Vector2(22, 36)
	body.position = Vector2(-11, -40)
	e.add_child(body)

	var head = ColorRect.new()
	head.color = body_color
	head.size = Vector2(16, 12)
	head.position = Vector2(-8, -54)
	e.add_child(head)

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

	var name_lbl = Label.new()
	name_lbl.text = "TELLER" if phase == 1 else "ENFORCER"
	name_lbl.position = Vector2(-20, -74)
	name_lbl.add_theme_font_size_override("font_size", 9)
	name_lbl.add_theme_color_override("font_color", Color(0.53, 0.67, 1.0))
	name_lbl.name = "Label"
	e.add_child(name_lbl)

	# Flash in
	e.modulate = Color(1, 1, 1, 0)
	get_parent().add_child(e)
	var spawn_tween = e.create_tween()
	spawn_tween.tween_property(e, "modulate:a", 1.0, 0.3)

func _throw_gold_bar(target: Node2D):
	var bar = ColorRect.new()
	bar.color = Color(1, 0.8, 0.2)
	bar.size = Vector2(14, 8)
	bar.global_position = global_position + Vector2(facing * 10, -30)
	bar.z_index = int(global_position.y) + 5
	get_parent().add_child(bar)

	var dir = (target.global_position - global_position).normalized()
	var speed_val = 180.0
	var lifetime = 0.0

	# Show warning
	var warn = Label.new()
	warn.text = "!"
	warn.global_position = global_position + Vector2(-5, -80)
	warn.add_theme_font_size_override("font_size", 16)
	warn.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	warn.z_index = 500
	get_parent().add_child(warn)
	var w_tween = warn.create_tween()
	w_tween.tween_property(warn, "modulate:a", 0.0, 0.5)
	w_tween.tween_callback(warn.queue_free)

	SFX.throw_enemy(get_tree())

	# Animate gold bar
	var tween = bar.create_tween()
	tween.tween_property(bar, "global_position",
		bar.global_position + dir * 300, 1.2)
	tween.tween_callback(bar.queue_free)

	# Collision checks
	var check = func():
		if not is_instance_valid(bar):
			return
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p):
				continue
			var dx = abs(bar.global_position.x - p.global_position.x)
			var dy = abs(bar.global_position.y - (p.global_position.y - 15))
			if dx < 18 and dy < 20:
				if p.has_method("take_hit"):
					p.take_hit(int(18 * GameState.enemy_dmg_mult()), facing)
				CombatJuice.hit_sparks(get_parent(), p.global_position + Vector2(0, -20), Color(1, 0.8, 0.2))
				bar.queue_free()
				return

	for i in range(24):
		get_tree().create_timer(i * 0.05).timeout.connect(check)

func _check_printer_hits():
	if not printer_visual or not is_instance_valid(printer_visual) or not printer_active:
		return

	for player in get_tree().get_nodes_in_group("players"):
		if not player is Player or not is_instance_valid(player):
			continue
		if player.last_attack_time == 0:
			continue
		var now = Time.get_ticks_msec() / 1000.0
		if now - player.last_attack_time > 0.12:
			continue
		var dx = printer_visual.global_position.x - player.global_position.x
		var dy = printer_visual.global_position.y - player.global_position.y
		if abs(dy) > 24:
			continue
		var in_front = (player.facing == 1 and dx > -4 and dx < player.attack_range) or \
					   (player.facing == -1 and dx < 4 and dx > -player.attack_range)
		if in_front:
			printer_hp -= player.base_damage
			SFX.hit(get_tree())
			CombatJuice.hit_sparks(get_parent(), printer_visual.global_position + Vector2(0, -30), Color(0, 0.8, 0.3))
			CombatJuice.damage_number(get_parent(), printer_visual.global_position + Vector2(0, -40), player.base_damage, Color(0, 0.8, 0.3))

			# Flash printer
			var screen = printer_visual.get_node_or_null("Screen")
			if screen:
				screen.color = Color.WHITE
				get_tree().create_timer(0.06).timeout.connect(func():
					if is_instance_valid(screen):
						screen.color = Color(0, 0.6, 0.2) if phase == 1 else Color(1, 0.3, 0.1)
				)

			if printer_hp <= 0:
				_destroy_printer()

func _destroy_printer():
	printer_active = false
	if printer_visual and is_instance_valid(printer_visual):
		CombatJuice.death_burst(get_parent(), printer_visual.global_position + Vector2(0, -25), Color(0, 0.8, 0.3))
		SFX.enemy_die(get_tree())
		printer_visual.queue_free()
		printer_visual = null

	if printer_label and is_instance_valid(printer_label):
		printer_label.text = "PRINTER: DESTROYED"
		printer_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))

	# Enter phase 2 if not already
	if phase == 1:
		_enter_phase_2()

func _enter_phase_2():
	phase = 2
	gold_throw_interval = 2.5
	speed = 70
	printer_spawn_interval = 8.0

	# Rebuild printer (malfunctioning)
	get_tree().create_timer(2.0).timeout.connect(func():
		if not is_instance_valid(self):
			return
		printer_hp = int(printer_max_hp * 0.6)
		printer_active = true
		_create_printer()
		if printer_visual:
			var screen = printer_visual.get_node_or_null("Screen")
			if screen:
				screen.color = Color(1, 0.3, 0.1)  # Malfunctioning orange
	)

	# Announcement
	var lbl = Label.new()
	lbl.text = "PHASE 2: MONETARY POLICY SHIFT"
	lbl.global_position = global_position + Vector2(-100, -90)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tween.tween_callback(lbl.queue_free)

	SFX.super_move(get_tree())
	CombatJuice.shake(get_viewport().get_camera_2d(), 10.0, 0.5)

# Override take_hit for phase transitions
func take_hit(dmg: int, from_dir: int):
	super.take_hit(dmg, from_dir)

	# Update boss bar
	if boss_bar and is_instance_valid(boss_bar):
		var pct = float(hp) / float(max_hp)
		boss_bar.size.x = 360.0 * pct

	# Update printer bar
	if printer_label and is_instance_valid(printer_label) and printer_active:
		var p_pct = float(printer_hp) / float(printer_max_hp)
		var blocks = int(p_pct * 8)
		printer_label.text = "PRINTER: %s%s" % ["█".repeat(blocks), "░".repeat(8 - blocks)]

	# Phase 2 at 50% HP
	if phase == 1 and get_hp_pct() <= 0.5:
		_enter_phase_2()

func _die():
	# Clean up boss UI
	if boss_bar and is_instance_valid(boss_bar):
		boss_bar.queue_free()
	if boss_bar_bg and is_instance_valid(boss_bar_bg):
		boss_bar_bg.queue_free()
	if boss_label and is_instance_valid(boss_label):
		boss_label.queue_free()
	if printer_label and is_instance_valid(printer_label):
		printer_label.queue_free()

	# Destroy printer
	if printer_visual and is_instance_valid(printer_visual):
		CombatJuice.death_burst(get_parent(), printer_visual.global_position + Vector2(0, -25), Color(0, 0.8, 0.3))
		printer_visual.queue_free()

	# Show death text
	var lbl = Label.new()
	lbl.text = "ACCOUNT CLOSED"
	lbl.global_position = global_position + Vector2(-50, -90)
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tween.tween_callback(lbl.queue_free)

	super._die()
