extends CharacterBody2D
class_name Player

## Base player class for THE LAST NODE.
## Movement is 2.5D: X is horizontal, Y is depth (not gravity).
## Jump is a visual Z offset on child nodes.

# Stats
@export var speed: float = 160.0
@export var max_hp: int = 100
@export var base_damage: int = 10
@export var attack_range: float = 44.0
@export var attack_cooldown: float = 0.18
@export var combo_length: int = 4
@export var character_name: String = "NODE RUNNER"

# State
var hp: int
var facing: int = 1
var is_attacking: bool = false
var is_jumping: bool = false
var jump_z: float = 0.0
var jump_vz: float = 0.0
var invuln_until: float = 0.0

# Combat
var combo_count: int = 0
var last_attack_time: float = 0.0
var last_combo_time: float = 0.0
const COMBO_WINDOW: float = 0.4

signal died
signal hit_taken(damage: int)

func _ready():
	hp = max_hp
	add_to_group("players")
	# Player keeps processing during hitstop so input feels responsive
	process_mode = Node.PROCESS_MODE_ALWAYS

func _physics_process(delta: float):
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
	velocity = input_dir * speed

	# Jump (visual only)
	if Input.is_action_just_pressed("jump") and not is_jumping:
		is_jumping = true
		jump_vz = 260.0

	if is_jumping:
		jump_z += jump_vz * delta
		jump_vz -= 720.0 * delta
		if jump_z <= 0:
			jump_z = 0
			jump_vz = 0
			is_jumping = false

	# Attack
	if Input.is_action_just_pressed("attack"):
		try_attack()

	# Apply jump Z to visual children (not the physics body)
	for child in get_children():
		if child is CollisionShape2D:
			continue
		if child.name == "Shadow":
			# Shadow stays on ground, squashes during jump
			child.scale.x = max(0.5, 1.0 - jump_z / 80.0) * 2.5
			continue
		if child is Camera2D:
			continue
		# Everything else floats up with jump
		child.position.y = child.get_meta("base_y", child.position.y) - jump_z
		if not child.has_meta("base_y"):
			child.set_meta("base_y", child.position.y)

	# Facing — flip visual children
	for child in get_children():
		if child is ColorRect and child.name != "Shadow":
			# Flip by mirroring position around center
			pass  # We'll handle this with proper sprites later

	# Depth sort
	z_index = int(global_position.y)

	move_and_slide()

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

	is_attacking = true

	# Find and hit enemies in range
	var dmg = base_damage
	if combo_count >= combo_length:
		dmg = int(dmg * 1.5)

	var hit_any = false
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is CharacterBody2D:
			continue
		var dx = enemy.global_position.x - global_position.x
		var dy = enemy.global_position.y - global_position.y
		if abs(dy) > 24:
			continue
		var in_front = false
		if facing == 1:
			in_front = dx > -4 and dx < attack_range
		else:
			in_front = dx < 4 and dx > -attack_range

		if in_front and enemy.has_method("take_hit"):
			enemy.take_hit(dmg, facing)
			hit_any = true
			CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20))
			CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -30), dmg)

	# Slash arc visual
	CombatJuice.slash_arc(get_parent(), global_position + Vector2(0, -22), facing, attack_range)

	if hit_any:
		# HIT-STOP — THE secret to great combat feel
		CombatJuice.hitstop(get_tree(), 0.04 if combo_count < combo_length else 0.08)
		# Screen shake
		var cam = get_viewport().get_camera_2d()
		var intensity = 6.0 if combo_count >= combo_length else 3.0
		CombatJuice.shake(cam, intensity, 0.12)

	if combo_count >= combo_length:
		combo_count = 0

	# Reset attack state
	get_tree().create_timer(0.15).timeout.connect(func(): is_attacking = false)

func take_hit(damage: int, from_dir: int):
	var now = Time.get_ticks_msec() / 1000.0
	if now < invuln_until:
		return
	invuln_until = now + 0.5
	hp = max(0, hp - damage)

	velocity = Vector2(from_dir * 240, 0)

	# Flash all visible children white
	for child in get_children():
		if child is ColorRect and child.name != "Shadow":
			var orig_color = child.color
			child.color = Color.WHITE
			get_tree().create_timer(0.08).timeout.connect(func():
				if is_instance_valid(child): child.color = orig_color
			)

	hit_taken.emit(damage)
	if hp <= 0:
		die()

func die():
	died.emit()
