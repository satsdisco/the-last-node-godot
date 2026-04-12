extends CharacterBody2D
class_name Player

## Complete player class — full combat system from the design doc.
## Movement, combos, directional attacks, grabs, specials, finishers.

# Stats — overridden by character subclasses
@export var speed: float = 160.0
@export var max_hp: int = 100
@export var base_damage: int = 10
@export var attack_range: float = 44.0
@export var attack_cooldown: float = 0.18
@export var combo_length: int = 4
@export var character_name: String = "NODE RUNNER"
@export var finisher_taunt: String = "VALIDATED."
@export var special_1_cost: int = 500
@export var special_2_cost: int = 1000
@export var super_cost: int = 5000

# State
var hp: int
var facing: int = 1
var is_attacking: bool = false
var is_jumping: bool = false
var jump_z: float = 0.0
var jump_vz: float = 0.0
var invuln_until: float = 0.0

# Grab state
var grabbed_enemy: Enemy = null
var grab_until: float = 0.0
const GRAB_RANGE: float = 28.0
const GRAB_HOLD_TIME: float = 3.0
const THROW_SPEED: float = 480.0

# Combat
var combo_count: int = 0
var last_attack_time: float = 0.0
var last_combo_time: float = 0.0
const COMBO_WINDOW: float = 0.4
const FINISHING_THRESHOLD: float = 0.1

signal died
signal hit_taken(damage: int)

func _ready():
	hp = max_hp
	add_to_group("players")
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(delta: float):
	var now = Time.get_ticks_msec() / 1000.0

	# Release stale grab
	if grabbed_enemy and (now > grab_until or not is_instance_valid(grabbed_enemy)):
		release_grab()

	# Movement
	var input_dir = Vector2.ZERO
	if Input.is_action_pressed("move_left"):
		input_dir.x -= 1
		facing = -1
	if Input.is_action_pressed("move_right"):
		input_dir.x += 1
		facing = 1
	if Input.is_action_pressed("move_up"):
		input_dir.y -= 1
	if Input.is_action_pressed("move_down"):
		input_dir.y += 1

	if input_dir.length() > 0:
		input_dir = input_dir.normalized()

	var move_speed = speed * (0.6 if grabbed_enemy else 1.0)
	velocity = input_dir * move_speed

	# Jump
	if Input.is_action_just_pressed("jump") and not is_jumping and not grabbed_enemy:
		is_jumping = true
		jump_vz = 260.0

	if is_jumping:
		jump_z += jump_vz * delta
		jump_vz -= 720.0 * delta
		if jump_z <= 0:
			jump_z = 0
			jump_vz = 0
			is_jumping = false

	# Grab button
	if Input.is_action_just_pressed("grab"):
		if grabbed_enemy:
			# Throw in facing direction
			throw_enemy()
		else:
			try_grab()

	# Attack button
	if Input.is_action_just_pressed("attack"):
		if grabbed_enemy:
			strike_grabbed()
		else:
			try_attack()

	# Special button
	if Input.is_action_just_pressed("special"):
		if Input.is_action_pressed("move_up"):
			try_super()
		elif Input.is_action_pressed("move_down"):
			try_special_2()
		else:
			try_special_1()

	# Update grabbed enemy position
	if grabbed_enemy and is_instance_valid(grabbed_enemy):
		grabbed_enemy.global_position = global_position + Vector2(facing * 20, -4)
		grabbed_enemy.velocity = Vector2.ZERO

	# Visual updates
	_update_visuals()
	move_and_slide()

# ==== ATTACKS ====

func try_attack():
	var now = Time.get_ticks_msec() / 1000.0
	if now - last_attack_time < attack_cooldown:
		return
	last_attack_time = now

	# Combo tracking
	if now - last_combo_time < COMBO_WINDOW:
		combo_count += 1
	else:
		combo_count = 1
	last_combo_time = now

	# Detect directional modifier
	var is_air = is_jumping and jump_z > 12
	var forward = (facing == 1 and Input.is_action_pressed("move_right")) or \
				  (facing == -1 and Input.is_action_pressed("move_left"))

	var dir_mode = "normal"
	if is_air:
		dir_mode = "dive"
	elif Input.is_action_pressed("move_down"):
		dir_mode = "sweep"
	elif Input.is_action_pressed("move_up"):
		dir_mode = "launcher"
	elif forward:
		dir_mode = "lunge"

	var dmg = base_damage
	var range_px = attack_range
	var slash_color = Color(1, 0.6, 0, 0.8)

	match dir_mode:
		"lunge":
			dmg = int(dmg * 1.3)
			velocity = Vector2(facing * 240, 0)
			slash_color = Color(1, 0.8, 0.2, 0.8)
		"sweep":
			range_px = attack_range * 1.2
			dmg = int(dmg * 0.9)
			slash_color = Color(0.4, 0.8, 1.0, 0.8)
		"launcher":
			dmg = int(dmg * 0.8)
			slash_color = Color(0.7, 0.4, 1.0, 0.8)
		"dive":
			dmg = int(dmg * 1.5)
			slash_color = Color(1, 0.2, 0.2, 0.8)

	# Combo finisher bonus
	if combo_count >= combo_length:
		dmg = int(dmg * 1.5)

	# Slash visual
	CombatJuice.slash_arc(get_parent(), global_position + Vector2(0, -22), facing, range_px, slash_color)

	# Hit all enemies in range (CLEAVE)
	var hit_any = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is CharacterBody2D or not is_instance_valid(enemy):
			continue
		var dx = enemy.global_position.x - global_position.x
		var dy = enemy.global_position.y - global_position.y
		if abs(dy) > 24:
			continue
		var in_front = (facing == 1 and dx > -4 and dx < range_px) or \
					   (facing == -1 and dx < 4 and dx > -range_px)
		if not in_front:
			continue
		if not enemy.has_method("take_hit"):
			continue

		# Finishing move check
		if enemy.has_method("get_hp_pct") and enemy.get_hp_pct() <= FINISHING_THRESHOLD:
			_trigger_finisher(enemy)
			hit_any = true
			continue

		enemy.take_hit(dmg, facing)
		hit_any = true
		CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20), slash_color)
		CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -30), dmg)

		# Launcher pops enemy up
		if dir_mode == "launcher" and enemy.has_method("pop_up"):
			enemy.pop_up(0.5)

	if hit_any:
		var intensity = 6.0 if combo_count >= combo_length else 3.0
		CombatJuice.hitstop(get_tree(), 0.04 if combo_count < combo_length else 0.08)
		CombatJuice.shake(get_viewport().get_camera_2d(), intensity, 0.12)

	if combo_count >= combo_length:
		combo_count = 0

	is_attacking = true
	get_tree().create_timer(0.15).timeout.connect(func(): is_attacking = false)

func _trigger_finisher(enemy: Node):
	# Instant kill + taunt text popup
	CombatJuice.hitstop(get_tree(), 0.12)
	CombatJuice.shake(get_viewport().get_camera_2d(), 8.0, 0.2)

	# Taunt text
	var taunt_lbl = Label.new()
	taunt_lbl.text = finisher_taunt
	taunt_lbl.global_position = global_position + Vector2(-40, -70)
	taunt_lbl.add_theme_font_size_override("font_size", 16)
	taunt_lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	taunt_lbl.z_index = 500
	get_parent().add_child(taunt_lbl)

	var tween = taunt_lbl.create_tween()
	tween.tween_property(taunt_lbl, "global_position:y", global_position.y - 90, 0.8)
	tween.parallel().tween_property(taunt_lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(taunt_lbl.queue_free)

	# Camera flash
	# Kill the enemy
	if enemy.has_method("take_hit"):
		enemy.take_hit(9999, facing)

# ==== GRAB SYSTEM ====

func try_grab():
	var nearest: Enemy = null
	var nearest_dist = GRAB_RANGE

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Enemy or not is_instance_valid(enemy):
			continue
		var dx = enemy.global_position.x - global_position.x
		var dy = enemy.global_position.y - global_position.y
		if abs(dy) > 20:
			continue
		var in_front = (facing == 1 and dx > 0 and dx < GRAB_RANGE) or \
					   (facing == -1 and dx < 0 and dx > -GRAB_RANGE)
		if in_front:
			var dist = abs(dx)
			if dist < nearest_dist:
				nearest = enemy
				nearest_dist = dist

	if nearest:
		grabbed_enemy = nearest
		grab_until = Time.get_ticks_msec() / 1000.0 + GRAB_HOLD_TIME
		if nearest.has_method("set_grabbed"):
			nearest.set_grabbed(true)

func release_grab():
	if grabbed_enemy and is_instance_valid(grabbed_enemy):
		if grabbed_enemy.has_method("set_grabbed"):
			grabbed_enemy.set_grabbed(false)
	grabbed_enemy = null

func strike_grabbed():
	if not grabbed_enemy or not is_instance_valid(grabbed_enemy):
		return
	var dmg = int(base_damage * 1.5)
	grabbed_enemy.take_hit(dmg, facing)
	CombatJuice.hit_sparks(get_parent(), grabbed_enemy.global_position + Vector2(0, -20))
	CombatJuice.damage_number(get_parent(), grabbed_enemy.global_position + Vector2(0, -30), dmg)
	CombatJuice.hitstop(get_tree(), 0.05)

	# Cleave: hit nearby enemies too
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if enemy == grabbed_enemy or not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 48:
			enemy.take_hit(int(dmg * 0.4), facing)

func throw_enemy():
	if not grabbed_enemy or not is_instance_valid(grabbed_enemy):
		release_grab()
		return
	var thrown = grabbed_enemy
	release_grab()
	if thrown.has_method("be_thrown"):
		thrown.be_thrown(facing * THROW_SPEED)
	CombatJuice.shake(get_viewport().get_camera_2d(), 4.0, 0.1)

# ==== SPECIALS ====

func try_special_1():
	if GameState.sats < special_1_cost:
		_no_sats_flash()
		return
	GameState.sats -= special_1_cost
	do_special_1()

func try_special_2():
	if GameState.sats < special_2_cost:
		_no_sats_flash()
		return
	GameState.sats -= special_2_cost
	do_special_2()

func try_super():
	if GameState.sats < super_cost:
		_no_sats_flash()
		return
	GameState.sats -= super_cost
	do_super()

func do_special_1():
	# Full Validation — parry + stun nearby enemies
	_show_move_name("FULL VALIDATION")
	invuln_until = Time.get_ticks_msec() / 1000.0 + 0.7

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 96:
			if enemy.has_method("take_hit"):
				enemy.take_hit(10, facing)
			CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20), Color(0, 1, 0.4))

func do_special_2():
	# Broadcast — radial pulse
	_show_move_name("BROADCAST")
	CombatJuice.shake(get_viewport().get_camera_2d(), 5.0, 0.15)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 96:
			if enemy.has_method("take_hit"):
				enemy.take_hit(22, facing)
			CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20), Color(1, 0.6, 0))

func do_super():
	# Consensus — sequential hits across all visible enemies
	_show_move_name("CONSENSUS")
	CombatJuice.hitstop(get_tree(), 0.15)
	CombatJuice.shake(get_viewport().get_camera_2d(), 10.0, 0.3)

	var targets = get_tree().get_nodes_in_group("enemies")
	var i = 0
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		get_tree().create_timer(i * 0.1).timeout.connect(func():
			if is_instance_valid(enemy) and enemy.has_method("take_hit"):
				enemy.take_hit(40, facing)
				CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20), Color(1, 0.6, 0))
				CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -30), 40, Color(1, 0.6, 0))
		)
		i += 1

func _no_sats_flash():
	var lbl = Label.new()
	lbl.text = "INSUFFICIENT SATS"
	lbl.global_position = global_position + Vector2(-50, -60)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(lbl.queue_free)

func _show_move_name(move_name: String):
	var lbl = Label.new()
	lbl.text = move_name
	lbl.global_position = global_position + Vector2(-40, -70)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", global_position.y - 90, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)

# ==== DAMAGE ====

func take_hit(damage: int, from_dir: int):
	var now = Time.get_ticks_msec() / 1000.0
	if now < invuln_until:
		return
	invuln_until = now + 0.5
	hp = max(0, hp - damage)
	velocity = Vector2(from_dir * 240, 0)

	# Flash visual children white
	for child in get_children():
		if child is ColorRect and child.name != "Shadow":
			var orig = child.color
			child.color = Color.WHITE
			get_tree().create_timer(0.08).timeout.connect(func():
				if is_instance_valid(child): child.color = orig
			)

	hit_taken.emit(damage)
	if hp <= 0:
		die()

func die():
	died.emit()

# ==== VISUALS ====

func _update_visuals():
	# Jump Z offset on visual children
	for child in get_children():
		if child is CollisionShape2D or child is Camera2D:
			continue
		if child.name == "Shadow":
			child.scale.x = max(0.5, 1.0 - jump_z / 80.0) * 2.5
			continue
		if not child.has_meta("base_y"):
			child.set_meta("base_y", child.position.y)
		child.position.y = child.get_meta("base_y") - jump_z

	z_index = int(global_position.y)
