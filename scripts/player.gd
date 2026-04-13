extends CharacterBody2D
class_name Player

## Complete player class — full combat system from the design doc.
## State machine driven: IDLE, WALK, ATTACK, HIT, JUMP, GRAB, DOWN.
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

# State machine
enum State { IDLE, WALK, ATTACK, HIT, JUMP, GRAB, DOWN }
var state: State = State.IDLE
var state_timer: float = 0.0

# State
var hp: int
var facing: int = 1
var is_attacking: bool = false
var is_jumping: bool = false
var jump_z: float = 0.0
var jump_vz: float = 0.0
var invuln_until: float = 0.0
var damage_buff_until: float = 0.0
var damage_buff_mult: float = 1.0
var speed_buff_until: float = 0.0
var speed_buff_mult: float = 1.0

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

# Hitbox Area2D — activates during attack frames
var hitbox_area: Area2D = null
var hurtbox_area: Area2D = null

signal died
signal hit_taken(damage: int)
signal state_changed(new_state: State)

func _ready():
	hp = max_hp
	add_to_group("players")
	process_mode = Node.PROCESS_MODE_ALWAYS
	_create_hitbox()
	_create_hurtbox()

func _create_hitbox():
	# Attack hitbox — activated only during ATTACK state
	hitbox_area = Area2D.new()
	hitbox_area.name = "Hitbox"
	hitbox_area.collision_layer = 2  # Layer 2 = player attacks
	hitbox_area.collision_mask = 4   # Mask 4 = enemy hurtboxes
	hitbox_area.monitoring = true
	hitbox_area.monitorable = false

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(attack_range, 20)
	col.shape = shape
	col.position = Vector2(attack_range / 2.0, -50)
	col.name = "HitboxShape"
	hitbox_area.add_child(col)

	# Start disabled
	col.disabled = true
	add_child(hitbox_area)

func _create_hurtbox():
	# Permanent hurtbox — enemies detect this to deal damage
	hurtbox_area = Area2D.new()
	hurtbox_area.name = "Hurtbox"
	hurtbox_area.collision_layer = 8  # Layer 4 = player hurtboxes
	hurtbox_area.collision_mask = 0
	hurtbox_area.monitoring = false
	hurtbox_area.monitorable = true

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(18, 36)
	col.shape = shape
	col.position = Vector2(0, -22)
	col.name = "HurtboxShape"
	hurtbox_area.add_child(col)

	add_child(hurtbox_area)

func _activate_hitbox():
	var shape = hitbox_area.get_node("HitboxShape")
	if shape:
		shape.disabled = false
		# Position hitbox in facing direction
		shape.position.x = facing * attack_range / 2.0

func _deactivate_hitbox():
	var shape = hitbox_area.get_node("HitboxShape")
	if shape:
		shape.disabled = true

func _change_state(new_state: State):
	# Exit old state
	match state:
		State.ATTACK:
			_deactivate_hitbox()
			is_attacking = false
		State.GRAB:
			pass
		State.DOWN:
			pass

	state = new_state
	state_timer = 0.0
	state_changed.emit(new_state)

	# Enter new state
	match new_state:
		State.ATTACK:
			is_attacking = true
			_activate_hitbox()
		State.JUMP:
			is_jumping = true
		State.HIT:
			pass
		State.DOWN:
			pass

func _physics_process(delta: float):
	var now = Time.get_ticks_msec() / 1000.0
	state_timer += delta

	# Release stale grab
	if grabbed_enemy and (now > grab_until or not is_instance_valid(grabbed_enemy)):
		release_grab()
		if state == State.GRAB:
			_change_state(State.IDLE)

	# Expire buffs
	if now > damage_buff_until:
		damage_buff_mult = 1.0
	if now > speed_buff_until:
		speed_buff_mult = 1.0

	# State machine tick
	match state:
		State.IDLE:
			_state_idle(delta, now)
		State.WALK:
			_state_walk(delta, now)
		State.ATTACK:
			_state_attack(delta, now)
		State.HIT:
			_state_hit(delta, now)
		State.JUMP:
			_state_jump(delta, now)
		State.GRAB:
			_state_grab(delta, now)
		State.DOWN:
			_state_down(delta, now)

	# Update grabbed enemy position
	if grabbed_enemy and is_instance_valid(grabbed_enemy):
		grabbed_enemy.global_position = global_position + Vector2(facing * 20, -4)
		grabbed_enemy.velocity = Vector2.ZERO

	# Visual updates
	_update_visuals()
	move_and_slide()

	# Hard clamp to walkable area (safety net)
	global_position.y = clampf(global_position.y, 275, 345)

# ==== STATE HANDLERS ====

func _get_input_dir() -> Vector2:
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
	return input_dir

func _handle_common_input(now: float):
	# Jump
	if Input.is_action_just_pressed("jump") and not grabbed_enemy:
		_change_state(State.JUMP)
		jump_vz = 260.0
		SFX.jump(get_tree())
		return true

	# Grab button
	if Input.is_action_just_pressed("grab"):
		if grabbed_enemy:
			throw_enemy()
		else:
			try_grab()
		return true

	# Attack button
	if Input.is_action_just_pressed("attack"):
		if grabbed_enemy:
			strike_grabbed()
		else:
			try_attack()
		return true

	# Special button
	if Input.is_action_just_pressed("special"):
		if Input.is_action_pressed("move_up"):
			try_super()
		elif Input.is_action_pressed("move_down"):
			try_special_2()
		else:
			try_special_1()
		return true

	return false

func _state_idle(_delta: float, now: float):
	velocity = Vector2.ZERO

	if _handle_common_input(now):
		return

	var input_dir = _get_input_dir()
	if input_dir.length() > 0:
		_change_state(State.WALK)

func _state_walk(_delta: float, now: float):
	if _handle_common_input(now):
		return

	var input_dir = _get_input_dir()
	if input_dir.length() == 0:
		_change_state(State.IDLE)
		return

	var move_speed = speed * speed_buff_mult * (0.6 if grabbed_enemy else 1.0)
	velocity = input_dir * move_speed

func _state_attack(_delta: float, now: float):
	# Attack state lasts for attack_cooldown duration, then returns
	velocity = velocity * 0.85  # Decelerate during attack
	if state_timer > 0.15:
		_change_state(State.IDLE)
		return

	# Allow chaining into next attack during combo window
	if Input.is_action_just_pressed("attack") and state_timer > 0.08:
		if grabbed_enemy:
			strike_grabbed()
		else:
			try_attack()

func _state_hit(_delta: float, _now: float):
	# Knockback deceleration
	velocity = velocity * 0.88
	if state_timer > 0.3:
		if hp <= 0:
			_change_state(State.DOWN)
		else:
			_change_state(State.IDLE)

func _state_jump(delta: float, now: float):
	# Allow movement during jump
	var input_dir = _get_input_dir()
	var move_speed = speed * speed_buff_mult
	velocity = input_dir * move_speed

	jump_z += jump_vz * delta
	jump_vz -= 720.0 * delta

	# Attack during jump
	if Input.is_action_just_pressed("attack"):
		try_attack()

	if jump_z <= 0:
		jump_z = 0
		jump_vz = 0
		is_jumping = false
		_change_state(State.IDLE)

func _state_grab(_delta: float, now: float):
	# Move slowly while grabbing
	var input_dir = _get_input_dir()
	var move_speed = speed * speed_buff_mult * 0.6
	velocity = input_dir * move_speed

	# Grab input
	if Input.is_action_just_pressed("grab"):
		throw_enemy()
		return
	if Input.is_action_just_pressed("attack"):
		strike_grabbed()
		return

	# Auto-release after hold time
	if not grabbed_enemy or not is_instance_valid(grabbed_enemy):
		_change_state(State.IDLE)

func _state_down(_delta: float, _now: float):
	velocity = velocity * 0.9
	# DOWN state — player is knocked out
	# Will be extended with revive logic for co-op
	if state_timer > 1.0:
		die()

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

	var dmg = int(base_damage * damage_buff_mult)
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
	CombatJuice.slash_arc(get_parent(), global_position + Vector2(facing * 16, -50), facing, range_px, slash_color)

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
		CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -50), slash_color)
		CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -60), dmg)

		# Launcher pops enemy up
		if dir_mode == "launcher" and enemy.has_method("pop_up"):
			enemy.pop_up(0.5)

	if hit_any:
		var intensity = 6.0 if combo_count >= combo_length else 3.0
		CombatJuice.hitstop(get_tree(), 0.04 if combo_count < combo_length else 0.08)
		CombatJuice.shake(get_viewport().get_camera_2d(), intensity, 0.12)
		# Knockback dust at hit position
		CombatJuice.knockback_dust(get_parent(), global_position + Vector2(facing * 20, 0), facing)
		# Combo popup at milestone hits
		if combo_count >= 3 and combo_count % 2 == 1:
			CombatJuice.combo_popup(get_parent(), global_position + Vector2(0, -40), combo_count)

	if combo_count >= combo_length:
		combo_count = 0

	SFX.attack(get_tree())
	# Transition to ATTACK state (handles hitbox activation + timer)
	_change_state(State.ATTACK)

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

	SFX.finisher(get_tree())
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
		SFX.grab(get_tree())
		_change_state(State.GRAB)

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
	CombatJuice.hit_sparks(get_parent(), grabbed_enemy.global_position + Vector2(0, -50))
	CombatJuice.damage_number(get_parent(), grabbed_enemy.global_position + Vector2(0, -60), dmg)
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
		_change_state(State.IDLE)
		return
	var thrown = grabbed_enemy
	release_grab()
	if thrown.has_method("be_thrown"):
		thrown.be_thrown(facing * THROW_SPEED)
	SFX.throw_enemy(get_tree())
	CombatJuice.shake(get_viewport().get_camera_2d(), 4.0, 0.1)
	_change_state(State.IDLE)

# ==== SPECIALS ====

func try_special_1():
	if GameState.sats < special_1_cost:
		SFX.no_sats(get_tree())
		_no_sats_flash()
		return
	GameState.sats -= special_1_cost
	SFX.special(get_tree())
	do_special_1()

func try_special_2():
	if GameState.sats < special_2_cost:
		_no_sats_flash()
		return
	GameState.sats -= special_2_cost
	SFX.special(get_tree())
	do_special_2()

func try_super():
	if GameState.sats < super_cost:
		_no_sats_flash()
		return
	GameState.sats -= super_cost
	SFX.super_move(get_tree())
	do_super()

func do_special_1():
	# Full Validation — parry ring + stun + invincibility
	_show_move_name("FULL VALIDATION")
	invuln_until = Time.get_ticks_msec() / 1000.0 + 0.7
	CombatJuice.hitstop(get_tree(), 0.06)

	# Green expanding parry ring
	_spawn_ring(Color(0, 1, 0.4, 0.5), 96)

	# Invalid transaction marks on stunned enemies
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 96:
			if enemy.has_method("take_hit"):
				enemy.take_hit(10, facing)
			if enemy.has_method("stun"):
				enemy.stun(800)
			CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -50), Color(0, 1, 0.4))
			_spawn_invalid_mark(enemy.global_position + Vector2(0, -40))

func do_special_2():
	# Broadcast — expanding orange pulse ring
	_show_move_name("BROADCAST")
	CombatJuice.hitstop(get_tree(), 0.08)
	CombatJuice.shake(get_viewport().get_camera_2d(), 6.0, 0.2)

	# Orange expanding ring
	_spawn_ring(Color(1, 0.6, 0, 0.6), 96)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 96:
			if enemy.has_method("take_hit"):
				enemy.take_hit(22, facing)
			CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -50), Color(1, 0.6, 0), 8)
			CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -60), 22, Color(1, 0.6, 0))

func do_super():
	# Consensus — screen flash + sequential orbital hits
	_show_move_name("CONSENSUS")
	CombatJuice.hitstop(get_tree(), 0.2)
	CombatJuice.shake(get_viewport().get_camera_2d(), 12.0, 0.4)

	# Screen flash orange
	var flash = ColorRect.new()
	flash.color = Color(1, 0.6, 0, 0.4)
	flash.size = Vector2(640, 360)
	flash.z_index = 3400
	var hud = get_tree().root.get_node_or_null("TestArena/HUD")
	if hud:
		hud.add_child(flash)
		var flash_tween = flash.create_tween()
		flash_tween.tween_property(flash, "modulate:a", 0.0, 0.3)
		flash_tween.tween_callback(flash.queue_free)

	# Sequential hits with orange targeting circles
	var targets = get_tree().get_nodes_in_group("enemies")
	var i = 0
	for enemy in targets:
		if not is_instance_valid(enemy):
			continue
		var idx = i
		get_tree().create_timer(idx * 0.12).timeout.connect(func():
			if not is_instance_valid(enemy):
				return
			# Targeting circle
			var circle = ColorRect.new()
			circle.color = Color(1, 0.6, 0, 0.7)
			circle.size = Vector2(40, 40)
			circle.global_position = enemy.global_position - Vector2(20, 30)
			circle.z_index = int(enemy.global_position.y) + 5
			get_parent().add_child(circle)

			var c_tween = circle.create_tween()
			c_tween.tween_property(circle, "scale", Vector2(0.2, 0.2), 0.15)
			c_tween.parallel().tween_property(circle, "modulate:a", 0.0, 0.15)
			c_tween.tween_callback(circle.queue_free)

			if enemy.has_method("take_hit"):
				enemy.take_hit(40, facing)
			CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -50), Color(1, 0.6, 0), 10)
			CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -60), 40, Color(1, 0.6, 0))
			CombatJuice.shake(get_viewport().get_camera_2d(), 4.0, 0.08)
		)
		i += 1

func _spawn_ring(color: Color, radius: float):
	# Expanding ring effect centered on player
	var ring = ColorRect.new()
	ring.color = color
	ring.size = Vector2(16, 16)
	ring.global_position = global_position - Vector2(8, 16)
	ring.z_index = int(global_position.y) + 5
	ring.pivot_offset = Vector2(8, 8)
	get_parent().add_child(ring)

	var tween = ring.create_tween()
	tween.tween_property(ring, "scale", Vector2(radius / 8.0, radius / 8.0), 0.3)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.3)
	tween.tween_callback(ring.queue_free)

func _spawn_invalid_mark(pos: Vector2):
	var mark = Label.new()
	mark.text = "✗ INVALID"
	mark.global_position = pos
	mark.add_theme_font_size_override("font_size", 10)
	mark.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	mark.z_index = 500
	get_parent().add_child(mark)
	var tween = mark.create_tween()
	tween.tween_property(mark, "modulate:a", 0.0, 0.5)
	tween.tween_callback(mark.queue_free)

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
	if state == State.DOWN:
		return
	invuln_until = now + 0.5
	hp = max(0, hp - damage)
	velocity = Vector2(from_dir * 240, 0)
	SFX.player_hurt(get_tree())

	# Transition to HIT state (interrupts any current state)
	_change_state(State.HIT)

	# Flash white on hit
	var sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite:
		sprite.modulate = Color.WHITE * 3.0  # Bright flash
		get_tree().create_timer(0.08).timeout.connect(func():
			if is_instance_valid(sprite): sprite.modulate = Color.WHITE
		)
	else:
		for child in get_children():
			if child is ColorRect and child.name != "Shadow":
				var orig = child.color
				child.color = Color.WHITE
				get_tree().create_timer(0.08).timeout.connect(func():
					if is_instance_valid(child): child.color = orig
				)

	hit_taken.emit(damage)

func die():
	died.emit()

# ==== SPRITE ANIMATION ====

# Frame indices in the sprite sheet (node_runner_sheet.png)
# 0: idle, 1-4: walk, 5-8: attack1-4, 9: hit, 10: down, 11: jump, 12: grab, 13: throw
var _anim_timer: float = 0.0
var _walk_frame_idx: int = 0

func _update_sprite_animation(delta: float):
	var sprite = get_node_or_null("Sprite") as Sprite2D
	if not sprite:
		return

	# Flip sprite based on facing direction
	sprite.flip_h = (facing == -1)

	match state:
		State.IDLE:
			sprite.frame = 0
		State.WALK:
			# Cycle through walk frames 1-4
			_anim_timer += delta
			if _anim_timer > 0.12:
				_anim_timer = 0.0
				_walk_frame_idx = (_walk_frame_idx + 1) % 4
			sprite.frame = 1 + _walk_frame_idx
		State.ATTACK:
			# Show attack frame based on combo count
			var attack_frame = clampi(combo_count, 1, 4)
			sprite.frame = 4 + attack_frame  # frames 5-8
		State.HIT:
			sprite.frame = 9
		State.DOWN:
			sprite.frame = 10
		State.JUMP:
			sprite.frame = 11
		State.GRAB:
			if grabbed_enemy and is_instance_valid(grabbed_enemy):
				sprite.frame = 12  # holding
			else:
				sprite.frame = 12  # reaching
		_:
			sprite.frame = 0

# ==== VISUALS ====

func _update_visuals():
	# Update sprite animation
	_update_sprite_animation(get_physics_process_delta_time())

	# Jump Z offset on visual children
	for child in get_children():
		if child is CollisionShape2D or child is Camera2D or child is Area2D:
			continue
		if child.name == "Shadow":
			child.scale.x = max(0.5, 1.0 - jump_z / 80.0) * 2.5
			continue
		if not child.has_meta("base_y"):
			child.set_meta("base_y", child.position.y)
		child.position.y = child.get_meta("base_y") - jump_z

	# Buff color tint
	if damage_buff_mult > 1.0:
		modulate = Color(0.5, 1, 0.5)
	elif speed_buff_mult > 1.0:
		modulate = Color(1, 1, 0.5)
	else:
		modulate = Color.WHITE

	z_index = int(global_position.y)
