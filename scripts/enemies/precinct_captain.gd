extends Enemy
class_name PrecinctCaptain

## Level 1 Boss — decorated officer with megaphone commands.
## Megaphone: FREEZE / COMPLY / DISPERSE
## Destroy surveillance cameras to remove commands from rotation.
## Phase 2: helicopter spotlight tracks the player, reinforcements spawn.

var phase: int = 1
var last_command_at: float = 0
var cameras: Array = []
var spotlight: ColorRect = null
var boss_bar_bg: ColorRect = null
var boss_bar: ColorRect = null
var boss_label: Label = null
var boss_pid: int
var _is_shouting: bool = false
var _shout_until: float = 0.0
var _phase_transition_active: bool = false
var _is_dead: bool = false
var _shield_bash_cooldown: float = 0.0

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

		# Pulsing red light on each camera
		var light = ColorRect.new()
		light.color = Color(1, 0, 0)
		light.size = Vector2(4, 4)
		light.position = Vector2(5, 3)
		light.name = "CamLight"
		cam_rect.add_child(light)

		# Pulse the red light
		var pulse_tween = light.create_tween().set_loops()
		pulse_tween.tween_property(light, "modulate:a", 0.2, 0.6)
		pulse_tween.tween_property(light, "modulate:a", 1.0, 0.6)

		# Red glow halo around camera
		var glow = ColorRect.new()
		glow.color = Color(1, 0, 0, 0.15)
		glow.size = Vector2(24, 20)
		glow.position = Vector2(-5, -5)
		glow.z_index = int(pos.y) - 1
		cam_rect.add_child(glow)

		var glow_tween = glow.create_tween().set_loops()
		glow_tween.tween_property(glow, "modulate:a", 0.3, 0.8)
		glow_tween.tween_property(glow, "modulate:a", 1.0, 0.8)

		cameras.append({"node": cam_rect, "alive": true, "pos": pos})

func _physics_process(delta):
	if _is_dead:
		return
	var now = Time.get_ticks_msec() / 1000.0

	# Update boss bar
	if boss_bar:
		boss_bar.size.x = 480.0 * (float(hp) / float(max_hp))

	# Phase transition — skip normal AI
	if _phase_transition_active:
		velocity = Vector2.ZERO
		move_and_slide()
		_update_visuals()
		return

	# Phase 2 at 50%
	if phase == 1 and float(hp) / float(max_hp) <= 0.5:
		phase = 2
		_enter_phase_2()
		return

	# Shouting — hold position while shout is active
	if _is_shouting:
		velocity = Vector2.ZERO
		if now > _shout_until:
			_is_shouting = false
		move_and_slide()
		_update_visuals()
		return

	# Issue commands every 5s (faster in phase 2)
	var cmd_interval = 5.0 if phase == 1 else 3.5
	if now - last_command_at > cmd_interval:
		last_command_at = now
		_issue_command()

	# Shield bash — melee attack when close to player
	_shield_bash_cooldown -= delta
	var target = _find_target()
	if target and not _is_shouting:
		var dist = global_position.distance_to(target.global_position)
		if dist < 60 and _shield_bash_cooldown <= 0:
			_shield_bash(target)

	# Phase 2: spotlight
	if phase == 2 and spotlight:
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

# ==== MEGAPHONE SHOUT ATTACK ====

func _issue_command():
	var available_commands: Array = []
	var alive_cams = cameras.filter(func(c): return c["alive"]).size()

	if alive_cams >= 1: available_commands.append("FREEZE")
	if alive_cams >= 2: available_commands.append("COMPLY")
	if alive_cams >= 3: available_commands.append("DISPERSE")

	# No cameras = melee only, blind and furious
	if available_commands.is_empty():
		return

	var cmd = available_commands.pick_random()

	# Boss stops and shouts for 0.8s
	_is_shouting = true
	_shout_until = Time.get_ticks_msec() / 1000.0 + 0.8
	velocity = Vector2.ZERO

	# Set attack animation
	enemy_state = EnemyState.ATTACK
	last_attack_time = Time.get_ticks_msec() / 1000.0

	# Show command text
	_show_command_text(cmd)

	# Sound wave cone visual
	_spawn_sound_waves(cmd)

	# Delayed effect — hits after 0.4s (gives player a tiny window)
	get_tree().create_timer(0.4).timeout.connect(func():
		if not is_instance_valid(self) or _is_dead:
			return
		_apply_command_effect(cmd)
	)

	CombatJuice.shake(get_viewport().get_camera_2d(), 4.0, 0.15)

func _spawn_sound_waves(cmd: String):
	var target = _find_target()
	if not target:
		return

	# Direction toward player
	var dir = 1 if target.global_position.x > global_position.x else -1

	# Color per command type
	var wave_color: Color
	match cmd:
		"FREEZE": wave_color = Color(0.3, 0.5, 1.0, 0.5)
		"COMPLY": wave_color = Color(1.0, 0.2, 0.2, 0.5)
		"DISPERSE": wave_color = Color(1.0, 0.8, 0.0, 0.5)
		_: wave_color = Color(1, 1, 1, 0.5)

	# Spawn 4 expanding semicircular arcs
	for i in range(4):
		get_tree().create_timer(i * 0.12).timeout.connect(func():
			if not is_instance_valid(self):
				return
			_spawn_single_wave(dir, wave_color, i)
		)

func _spawn_single_wave(dir: int, color: Color, index: int):
	# Each wave is a set of small rects arranged in an arc
	var origin = global_position + Vector2(dir * 20, -50)
	var arc_count = 7  # Number of segments per arc

	for j in range(arc_count):
		var rect = ColorRect.new()
		rect.color = color
		rect.size = Vector2(6, 3)
		rect.global_position = origin
		rect.z_index = int(global_position.y) + 10
		rect.pivot_offset = Vector2(3, 1.5)
		get_parent().add_child(rect)

		# Arc angle: spread from -50 to +50 degrees in front
		var angle_deg = -50 + (100.0 / (arc_count - 1)) * j
		var angle_rad = deg_to_rad(angle_deg)
		var expand_dir = Vector2(dir * cos(angle_rad), sin(angle_rad))
		var end_pos = origin + expand_dir * (60 + index * 15)

		rect.rotation = angle_rad if dir == 1 else PI - angle_rad

		var tween = rect.create_tween()
		tween.tween_property(rect, "global_position", end_pos, 0.35)
		tween.parallel().tween_property(rect, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(rect, "scale", Vector2(2.5, 1.5), 0.35)
		tween.tween_callback(rect.queue_free)

func _apply_command_effect(cmd: String):
	var target = _find_target()
	if not target:
		return

	# Check if player is in the cone (in front of boss, within range)
	var dx = target.global_position.x - global_position.x
	var dy = target.global_position.y - global_position.y
	var dist = global_position.distance_to(target.global_position)
	var in_cone = dist < 160 and abs(dy) < 60
	# Must be in the direction the boss is facing
	if facing == 1 and dx < -20:
		in_cone = false
	elif facing == -1 and dx > 20:
		in_cone = false

	if not in_cone:
		return

	var from_dir = 1 if global_position.x < target.global_position.x else -1

	match cmd:
		"FREEZE":
			# Stun player for 0.8s — freeze in place, flash blue
			if target.has_method("take_hit"):
				target.velocity = Vector2.ZERO
				# Apply stun by setting invuln briefly then locking velocity
				if target is Player:
					target._change_state(Player.State.HIT)
					target.state_timer = -0.5  # Extend hit state duration
				_apply_freeze_effect(target)
		"COMPLY":
			# Damage + drain sats
			if target.has_method("take_hit"):
				target.take_hit(8, from_dir)
			GameState.sats = max(0, GameState.sats - 200)
			# Show sat drain text
			_show_sat_drain(target.global_position)
		"DISPERSE":
			# Massive knockback
			if target.has_method("take_hit"):
				target.take_hit(5, from_dir)
			target.velocity = Vector2(from_dir * 400, 0)

func _apply_freeze_effect(target: Node2D):
	# Flash blue for 0.8s
	var sprite = target.get_node_or_null("Sprite") as Sprite2D
	var flash_count = 8
	for i in range(flash_count):
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if not is_instance_valid(target):
				return
			if sprite and is_instance_valid(sprite):
				sprite.modulate = Color(0.4, 0.6, 1.5) if i % 2 == 0 else Color.WHITE
			# Keep velocity zeroed during freeze
			target.velocity = Vector2.ZERO
		)
	# Reset color after freeze
	get_tree().create_timer(0.8).timeout.connect(func():
		if is_instance_valid(target) and sprite and is_instance_valid(sprite):
			sprite.modulate = Color.WHITE
	)

func _show_sat_drain(pos: Vector2):
	var lbl = Label.new()
	lbl.text = "-200 SATS"
	lbl.global_position = pos + Vector2(-30, -40)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", pos.y - 70, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)

func _show_command_text(cmd: String):
	var text_color: Color
	match cmd:
		"FREEZE": text_color = Color(0.4, 0.6, 1.0)
		"COMPLY": text_color = Color(1, 0.2, 0.2)
		"DISPERSE": text_color = Color(1, 0.8, 0.0)
		_: text_color = Color(1, 0.2, 0.2)

	var lbl = Label.new()
	lbl.text = "%s!" % cmd
	lbl.global_position = global_position + Vector2(-40, -110)
	lbl.add_theme_font_size_override("font_size", 20)
	lbl.add_theme_color_override("font_color", text_color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(80, 30)
	lbl.z_index = 3500
	get_parent().add_child(lbl)

	# Scale in then fade
	lbl.scale = Vector2(0.5, 0.5)
	lbl.pivot_offset = Vector2(40, 15)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.2, 1.2), 0.1)
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.05)
	tween.tween_interval(0.6)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.4)
	tween.tween_callback(lbl.queue_free)

# ==== SHIELD BASH ====

func _shield_bash(target: Node2D):
	_shield_bash_cooldown = attack_cooldown
	enemy_state = EnemyState.ATTACK
	last_attack_time = Time.get_ticks_msec() / 1000.0

	# Charge toward player with velocity burst
	var dir = 1 if target.global_position.x > global_position.x else -1
	facing = dir
	velocity = Vector2(dir * 280, 0)

	# Hit after a brief delay (charge connects)
	get_tree().create_timer(0.15).timeout.connect(func():
		if not is_instance_valid(self) or _is_dead:
			return
		var t = _find_target()
		if not t:
			return
		var dist = global_position.distance_to(t.global_position)
		if dist < 55 and t.has_method("take_hit"):
			var from_dir = 1 if global_position.x < t.global_position.x else -1
			t.take_hit(int(damage * 1.5 * GameState.enemy_dmg_mult()), from_dir)
			t.velocity = Vector2(from_dir * 350, 0)  # Big knockback
			CombatJuice.shake(get_viewport().get_camera_2d(), 8.0, 0.2)
			CombatJuice.hit_sparks(get_parent(), t.global_position + Vector2(0, -50), Color(0.8, 0.8, 1.0), 8)
			SFX.hit_heavy(get_tree())
	)

# ==== CAMERA DESTRUCTION ====

func _check_cameras():
	for cam_data in cameras:
		if not cam_data["alive"]:
			continue
		var cam_node = cam_data["node"]
		if not is_instance_valid(cam_node):
			cam_data["alive"] = false
			continue

		for p in get_tree().get_nodes_in_group("players"):
			if not p is Player:
				continue
			var now = Time.get_ticks_msec() / 1000.0
			if now - p.last_attack_time > 0.12:
				continue
			if p.global_position.distance_to(cam_data["pos"]) < 36:
				cam_data["alive"] = false
				cam_node.queue_free()
				_on_camera_destroyed(cam_data["pos"])

func _on_camera_destroyed(pos: Vector2):
	SFX.enemy_die(get_tree())
	CombatJuice.death_burst(get_parent(), pos, Color(0.6, 0, 0))
	CombatJuice.shake(get_viewport().get_camera_2d(), 6.0, 0.2)

	# Big "SURVEIL OFFLINE" text
	var lbl = Label.new()
	lbl.text = "SURVEIL OFFLINE"
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_color", Color(0, 1, 0.4))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(200, 30)
	lbl.z_index = 3500
	lbl.pivot_offset = Vector2(100, 15)
	lbl.scale = Vector2(1.5, 1.5)

	var hud = get_tree().root.get_node_or_null("TestArena/HUD")
	if hud:
		lbl.position = Vector2(220, 100)
		hud.add_child(lbl)
	else:
		lbl.global_position = pos + Vector2(-100, -40)
		get_parent().add_child(lbl)

	var tween = lbl.create_tween()
	tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.15)
	tween.tween_interval(0.8)
	tween.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tween.tween_callback(lbl.queue_free)

	# Screen-wide green flash
	var flash = ColorRect.new()
	flash.color = Color(0, 1, 0.4, 0.25)
	flash.size = Vector2(640, 360)
	flash.z_index = 3400
	if hud:
		hud.add_child(flash)
	else:
		flash.global_position = Vector2.ZERO
		get_parent().add_child(flash)
	var flash_tween = flash.create_tween()
	flash_tween.tween_property(flash, "modulate:a", 0.0, 0.3)
	flash_tween.tween_callback(flash.queue_free)

	# Report how many cameras remain
	var alive_count = cameras.filter(func(c): return c["alive"]).size()
	if alive_count == 0:
		_show_text("BLIND AND FURIOUS", Color(1, 0.4, 0))

# ==== PHASE 2 TRANSITION ====

func _enter_phase_2():
	_phase_transition_active = true
	velocity = Vector2.ZERO

	# Boss goes invulnerable
	stunned_until = 0
	var orig_hp = hp

	# Screen flash red
	var hud = get_tree().root.get_node_or_null("TestArena/HUD")
	if hud:
		var flash = ColorRect.new()
		flash.color = Color(1, 0, 0, 0.4)
		flash.size = Vector2(640, 360)
		flash.z_index = 3400
		hud.add_child(flash)
		var flash_tween = flash.create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, 0.5)
		flash_tween.tween_callback(flash.queue_free)

	# Camera zoom out then back in
	var cam = get_viewport().get_camera_2d()
	if cam:
		var zoom_tween = cam.create_tween()
		zoom_tween.tween_property(cam, "zoom", Vector2(0.85, 0.85), 0.4)
		zoom_tween.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.3)

	CombatJuice.shake(get_viewport().get_camera_2d(), 10.0, 0.4)
	SFX.super_move(get_tree())

	# "ALL UNITS" shout
	_show_command_text("ALL UNITS")

	# Spawn 2 KYC reinforcements after 1s
	get_tree().create_timer(1.0).timeout.connect(func():
		if not is_instance_valid(self):
			return
		# Spawn reinforcements to the left and right of boss
		var arena = get_parent()
		if arena and arena.has_method("_spawn_enemy"):
			arena._spawn_enemy(global_position + Vector2(-80, 10), "KYC")
			arena._spawn_enemy(global_position + Vector2(80, -10), "KYC")
		_show_text("REINFORCEMENTS DEPLOYED", Color(1, 0.2, 0.2))
	)

	# After 2s, end transition — spawn spotlight, buff boss
	get_tree().create_timer(2.0).timeout.connect(func():
		if not is_instance_valid(self):
			return
		_phase_transition_active = false

		# Restore HP to what it was (invulnerable during transition)
		hp = orig_hp

		# Boss gets faster and more aggressive
		speed = 130
		attack_cooldown = 1.0

		# Spotlight
		spotlight = ColorRect.new()
		spotlight.color = Color(1, 1, 0.6, 0.2)
		spotlight.size = Vector2(32, 32)
		spotlight.global_position = global_position
		spotlight.z_index = 999
		get_parent().add_child(spotlight)

		_show_text("PHASE 2\nHELICOPTER DEPLOYED", Color(1, 0.2, 0.2))
	)

# Make boss invulnerable during phase transition
func take_hit(dmg: int, from_dir: int):
	if _phase_transition_active:
		# Show "INVULNERABLE" text and bounce off
		var lbl = Label.new()
		lbl.text = "INVULNERABLE"
		lbl.global_position = global_position + Vector2(-40, -100)
		lbl.add_theme_font_size_override("font_size", 10)
		lbl.add_theme_color_override("font_color", Color(0.6, 0.6, 0.6))
		lbl.z_index = 500
		get_parent().add_child(lbl)
		var tween = lbl.create_tween()
		tween.tween_property(lbl, "modulate:a", 0.0, 0.4)
		tween.tween_callback(lbl.queue_free)
		return
	if _is_dead:
		return
	super.take_hit(dmg, from_dir)

# ==== BOSS DEATH SEQUENCE ====

func _die():
	if _is_dead:
		return
	_is_dead = true

	# Clean up boss bar
	if boss_bar: boss_bar.queue_free()
	if boss_bar_bg: boss_bar_bg.queue_free()
	if boss_label: boss_label.queue_free()
	if spotlight: spotlight.queue_free()
	for cam_data in cameras:
		if cam_data["alive"] and is_instance_valid(cam_data["node"]):
			cam_data["node"].queue_free()

	# SLOW MOTION for 1.5s
	Engine.time_scale = 0.3

	# Boss flashes white rapidly
	var sprite = get_node_or_null("Sprite") as Sprite2D
	for i in range(15):
		get_tree().create_timer(i * 0.05 * 0.3).timeout.connect(func():  # Adjusted for time_scale
			if is_instance_valid(self) and sprite and is_instance_valid(sprite):
				sprite.modulate = Color(3, 3, 3) if i % 2 == 0 else Color.WHITE
		)

	# Big screen shake
	CombatJuice.shake(get_viewport().get_camera_2d(), 12.0, 0.5)

	# "PROCESS TERMINATED" in huge centered text with orange glow
	var hud = get_tree().root.get_node_or_null("TestArena/HUD")
	if hud:
		# Orange glow background
		var glow = ColorRect.new()
		glow.color = Color(1, 0.6, 0, 0.15)
		glow.size = Vector2(640, 360)
		glow.z_index = 3999
		hud.add_child(glow)

		var lbl = Label.new()
		lbl.text = "PROCESS TERMINATED"
		lbl.position = Vector2(80, 130)
		lbl.add_theme_font_size_override("font_size", 28)
		lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		lbl.size = Vector2(480, 50)
		lbl.z_index = 4000
		lbl.pivot_offset = Vector2(240, 25)
		lbl.scale = Vector2(0.5, 0.5)
		hud.add_child(lbl)

		# Scale in with punch
		var text_tween = lbl.create_tween()
		text_tween.tween_property(lbl, "scale", Vector2(1.15, 1.15), 0.15)
		text_tween.tween_property(lbl, "scale", Vector2(1.0, 1.0), 0.1)
		text_tween.tween_interval(1.5 * 0.3)  # Hold during slow-mo
		text_tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
		text_tween.tween_callback(lbl.queue_free)

		var glow_tween = glow.create_tween()
		glow_tween.tween_property(glow, "modulate:a", 0.0, 2.0 * 0.3)
		glow_tween.tween_callback(glow.queue_free)

	# Sat explosion burst (2000 sats in a spread pattern)
	var pos = global_position
	var parent_node = get_parent()
	for i in range(10):
		get_tree().create_timer(i * 0.05 * 0.3).timeout.connect(func():
			if is_instance_valid(parent_node):
				var offset = Vector2(randf_range(-40, 40), randf_range(-30, 10))
				Pickup.spawn_sats(parent_node, pos + offset + Vector2(0, -8), 200)
		)

	# Return to normal speed after 1.5 real seconds (= 1.5 / 0.3 game seconds)
	get_tree().create_timer(1.5 * 0.3).timeout.connect(func():
		Engine.time_scale = 1.0
	)

	# Standard death sequence (fade out, remove from enemies group)
	SFX.enemy_die(get_tree())
	CombatJuice.death_burst(get_parent(), pos + Vector2(0, -20), Color(0.0, 0.13, 0.4))

	enemy_state = EnemyState.DEAD
	remove_from_group("enemies")
	set_physics_process(false)

	# Signal for encounter system
	died_at.emit(pos, 0)  # Sats handled by burst above

	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)

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
