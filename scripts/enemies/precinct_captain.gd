extends Enemy
class_name PrecinctCaptain

## Level 1 Boss — decorated officer with megaphone commands.
## Megaphone: FREEZE / COMPLY / DISPERSE
## Destroy surveillance cameras to remove commands from rotation.
## Phase 2: helicopter spotlight tracks the player.

var phase: int = 1
var last_command_at: float = 0
var cameras: Array = []
var spotlight: ColorRect = null
var boss_bar_bg: ColorRect = null
var boss_bar: ColorRect = null
var boss_label: Label = null
var boss_pid: int

func _ready():
	super._ready()
	speed = 100
	max_hp = int(220 * GameState.enemy_hp_mult())
	hp = max_hp
	damage = 10
	attack_range = 44
	attack_cooldown = 1.5
	drop_sats = 2000
	enemy_name = "PRECINCT CAPTAIN"
	boss_pid = 1000 + randi() % 9000

	# Bigger body (dark blue)
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			child.color = Color(0.0, 0.13, 0.4)
			child.size *= 1.4

	# Boss health bar (screen-fixed via CanvasLayer)
	_create_boss_bar()

func _create_boss_bar():
	var hud = get_tree().root.get_node_or_null("TestArena/HUD")
	if not hud:
		return

	boss_bar_bg = ColorRect.new()
	boss_bar_bg.color = Color(0.2, 0, 0)
	boss_bar_bg.position = Vector2(80, 55)
	boss_bar_bg.size = Vector2(480, 8)
	hud.add_child(boss_bar_bg)

	boss_bar = ColorRect.new()
	boss_bar.color = Color(1, 0.2, 0.2)
	boss_bar.position = Vector2(80, 55)
	boss_bar.size = Vector2(480, 8)
	boss_bar.name = "BossBar"
	hud.add_child(boss_bar)

	boss_label = Label.new()
	boss_label.text = "PID %d  PRECINCT CAPTAIN" % boss_pid
	boss_label.position = Vector2(80, 40)
	boss_label.add_theme_font_size_override("font_size", 10)
	boss_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	hud.add_child(boss_label)

func register_cameras(positions: Array):
	for pos in positions:
		var cam_rect = ColorRect.new()
		cam_rect.color = Color(0.6, 0, 0)
		cam_rect.size = Vector2(14, 10)
		cam_rect.global_position = pos - Vector2(7, 5)
		cam_rect.z_index = int(pos.y)
		get_parent().add_child(cam_rect)

		# Blinking red light
		var light = ColorRect.new()
		light.color = Color(1, 0, 0)
		light.size = Vector2(4, 4)
		light.position = Vector2(5, 3)
		cam_rect.add_child(light)

		cameras.append({"node": cam_rect, "alive": true, "pos": pos})

func _physics_process(delta):
	var now = Time.get_ticks_msec() / 1000.0

	# Update boss bar
	if boss_bar:
		boss_bar.size.x = 480.0 * (float(hp) / float(max_hp))

	# Phase 2 at 50%
	if phase == 1 and float(hp) / float(max_hp) <= 0.5:
		phase = 2
		_enter_phase_2()

	# Issue commands every 6s
	if now - last_command_at > 6.0:
		last_command_at = now
		_issue_command()

	# Phase 2: spotlight
	if phase == 2 and spotlight:
		var target = _find_target()
		if target:
			spotlight.global_position = spotlight.global_position.lerp(
				target.global_position - Vector2(16, 16), 0.03)
			# Damage if on top of player
			if spotlight.global_position.distance_to(target.global_position) < 20:
				if fmod(now, 0.4) < 0.02 and target.has_method("take_hit"):
					target.take_hit(4, 1)

	# Check camera destruction by player attacks
	_check_cameras()

	super._physics_process(delta)

func _issue_command():
	var available_commands: Array = []
	var alive_cams = cameras.filter(func(c): return c["alive"]).size()

	if alive_cams >= 1: available_commands.append("FREEZE")
	if alive_cams >= 2: available_commands.append("COMPLY")
	if alive_cams >= 3: available_commands.append("DISPERSE")

	if available_commands.is_empty():
		return

	var cmd = available_commands.pick_random()
	_show_command(cmd)

	var target = _find_target()
	if not target:
		return

	match cmd:
		"FREEZE":
			if target.velocity.length() > 10 and target.has_method("take_hit"):
				target.take_hit(3, 1 if global_position.x < target.global_position.x else -1)
		"COMPLY":
			if target.has_method("take_hit"):
				target.take_hit(2, 1 if global_position.x < target.global_position.x else -1)
		"DISPERSE":
			var dir = 1 if target.global_position.x > global_position.x else -1
			target.velocity = Vector2(dir * 280, 0)

func _show_command(cmd: String):
	var lbl = Label.new()
	lbl.text = '"%s"' % cmd
	lbl.global_position = global_position + Vector2(-30, -90)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	lbl.z_index = 3500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.4)
	tween.tween_callback(lbl.queue_free)
	CombatJuice.shake(get_viewport().get_camera_2d(), 3.0, 0.1)

func _check_cameras():
	for cam_data in cameras:
		if not cam_data["alive"]:
			continue
		var cam_node = cam_data["node"]
		if not is_instance_valid(cam_node):
			cam_data["alive"] = false
			continue

		for player in get_tree().get_nodes_in_group("players"):
			if not player is Player:
				continue
			var now = Time.get_ticks_msec() / 1000.0
			if now - player.last_attack_time > 0.12:
				continue
			if player.global_position.distance_to(cam_data["pos"]) < 36:
				cam_data["alive"] = false
				cam_node.queue_free()
				_show_text("SURVEIL OFFLINE", Color(0, 1, 0.4))
				SFX.enemy_die(get_tree())
				CombatJuice.death_burst(get_parent(), cam_data["pos"], Color(0.6, 0, 0))

func _enter_phase_2():
	_show_text("PHASE 2\nHELICOPTER DEPLOYED", Color(1, 0.2, 0.2))
	SFX.super_move(get_tree())
	CombatJuice.shake(get_viewport().get_camera_2d(), 8.0, 0.3)

	# Spotlight
	spotlight = ColorRect.new()
	spotlight.color = Color(1, 1, 0.6, 0.2)
	spotlight.size = Vector2(32, 32)
	spotlight.global_position = global_position
	spotlight.z_index = 999
	get_parent().add_child(spotlight)

func _show_text(text: String, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.global_position = global_position + Vector2(-50, -100)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(100, 40)
	lbl.z_index = 3500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)

func _die():
	# Clean up boss bar
	if boss_bar: boss_bar.queue_free()
	if boss_bar_bg: boss_bar_bg.queue_free()
	if boss_label: boss_label.queue_free()
	if spotlight: spotlight.queue_free()
	for cam_data in cameras:
		if cam_data["alive"] and is_instance_valid(cam_data["node"]):
			cam_data["node"].queue_free()

	# "PROCESS TERMINATED" text
	var lbl = Label.new()
	lbl.text = "PROCESS TERMINATED"
	lbl.position = Vector2(200, 140)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	lbl.z_index = 4000

	var hud = get_tree().root.get_node_or_null("TestArena/HUD")
	if hud:
		hud.add_child(lbl)
		var tween = lbl.create_tween()
		tween.tween_property(lbl, "modulate:a", 0.0, 2.0).set_delay(1.0)
		tween.tween_callback(lbl.queue_free)

	super._die()
