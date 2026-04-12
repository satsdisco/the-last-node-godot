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
			_spawn_hit_effect(enemy.global_position + Vector2(0, -20))

	# Slash visual
	_spawn_slash()

	# Screen shake on hit
	if hit_any:
		var cam = get_viewport().get_camera_2d()
		if cam:
			var shake_amount = 4.0 if combo_count >= combo_length else 2.0
			cam.offset = Vector2(randf_range(-shake_amount, shake_amount), randf_range(-shake_amount, shake_amount))
			get_tree().create_timer(0.06).timeout.connect(func():
				if cam: cam.offset = Vector2.ZERO
			)

	if combo_count >= combo_length:
		combo_count = 0

	# Reset attack state after brief delay
	get_tree().create_timer(0.15).timeout.connect(func(): is_attacking = false)

func _spawn_slash():
	var slash = ColorRect.new()
	slash.color = Color(1, 0.6, 0, 0.7)
	slash.size = Vector2(attack_range, 6)
	slash.position = global_position + Vector2(facing * attack_range * 0.25, -24)
	slash.rotation = deg_to_rad(-25 * facing)
	slash.z_index = int(global_position.y) + 10
	get_parent().add_child(slash)

	var tween = create_tween()
	tween.tween_property(slash, "rotation", deg_to_rad(20.0 * facing), 0.1)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(slash.queue_free)

func _spawn_hit_effect(pos: Vector2):
	for i in range(5):
		var spark = ColorRect.new()
		spark.color = Color(1, 0.6, 0)
		spark.size = Vector2(3, 3)
		spark.global_position = pos
		spark.z_index = 200
		get_parent().add_child(spark)

		var angle = randf() * TAU
		var dist = randf_range(6, 18)
		var tween = create_tween()
		tween.tween_property(spark, "global_position", pos + Vector2(cos(angle) * dist, sin(angle) * dist), 0.2)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.2)
		tween.tween_callback(spark.queue_free)

	# Impact ring
	var ring = ColorRect.new()
	ring.color = Color(1, 1, 1, 0.8)
	ring.size = Vector2(6, 6)
	ring.global_position = pos - Vector2(3, 3)
	ring.z_index = 200
	get_parent().add_child(ring)

	var tween = create_tween()
	tween.tween_property(ring, "scale", Vector2(4, 4), 0.15)
	tween.parallel().tween_property(ring, "modulate:a", 0.0, 0.15)
	tween.tween_callback(ring.queue_free)

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
