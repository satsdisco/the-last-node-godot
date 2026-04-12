extends CharacterBody2D
class_name Player

## Base player class for THE LAST NODE.
## Movement is 2.5D: X is horizontal, Y is depth (not gravity).
## Jump is a visual Z offset only.

# Stats — overridden by character subclasses
@export var speed: float = 160.0
@export var max_hp: int = 100
@export var base_damage: int = 10
@export var attack_range: float = 44.0
@export var attack_cooldown: float = 0.18
@export var combo_length: int = 4
@export var character_name: String = "NODE RUNNER"

# State
var hp: int
var sats: int:
	get: return GameState.sats
	set(v): GameState.sats = v
var facing: int = 1  # 1 = right, -1 = left
var is_attacking: bool = false
var is_jumping: bool = false
var jump_z: float = 0.0
var jump_vz: float = 0.0

# Combat
var combo_count: int = 0
var last_attack_time: float = 0.0
var last_combo_time: float = 0.0
var invuln_until: float = 0.0
const COMBO_WINDOW: float = 0.4

# Node references
@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var hitbox: Area2D = $AttackHitbox
@onready var label: Label = $Label

# Signals
signal died
signal hit_taken(damage: int)

func _ready():
	hp = max_hp
	hitbox.monitoring = false
	if label:
		label.text = character_name

func _physics_process(delta: float):
	handle_movement(delta)
	handle_jump(delta)
	handle_attack()
	update_visuals()
	move_and_slide()

func handle_movement(delta: float):
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

func handle_jump(delta: float):
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

func handle_attack():
	if Input.is_action_just_pressed("attack"):
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

		# Play attack animation
		is_attacking = true
		if sprite.sprite_frames and sprite.sprite_frames.has_animation("attack"):
			sprite.play("attack")

		# Activate hitbox briefly
		perform_attack()

		# Camera shake
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.offset = Vector2(randf_range(-2, 2), randf_range(-2, 2))
			get_tree().create_timer(0.05).timeout.connect(func(): cam.offset = Vector2.ZERO)

func perform_attack():
	# Find enemies in range
	var enemies = get_tree().get_nodes_in_group("enemies")
	var dmg = base_damage
	if combo_count >= combo_length:
		dmg = int(dmg * 1.5)

	var hit_any = false
	for enemy in enemies:
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
			spawn_hit_spark(enemy.global_position + Vector2(0, -20))

	if hit_any and combo_count >= combo_length:
		combo_count = 0
		# Big screen shake on combo finisher
		var cam = get_viewport().get_camera_2d()
		if cam:
			cam.offset = Vector2(randf_range(-4, 4), randf_range(-4, 4))
			get_tree().create_timer(0.08).timeout.connect(func(): cam.offset = Vector2.ZERO)

func spawn_hit_spark(pos: Vector2):
	# Simple visual feedback — will be replaced with GPUParticles2D
	var spark = Sprite2D.new()
	spark.modulate = Color(1, 0.6, 0, 1)
	spark.global_position = pos
	spark.z_index = 100
	# Use a simple rect texture
	var img = Image.create(4, 4, false, Image.FORMAT_RGBA8)
	img.fill(Color.WHITE)
	spark.texture = ImageTexture.create_from_image(img)
	get_parent().add_child(spark)

	var tween = create_tween()
	tween.tween_property(spark, "modulate:a", 0.0, 0.2)
	tween.tween_property(spark, "scale", Vector2(3, 3), 0.2)
	tween.tween_callback(spark.queue_free)

func take_hit(damage: int, from_dir: int):
	var now = Time.get_ticks_msec() / 1000.0
	if now < invuln_until:
		return
	invuln_until = now + 0.5
	hp = max(0, hp - damage)

	# Knockback
	velocity = Vector2(from_dir * 240, 0)

	# Flash white
	if sprite:
		sprite.modulate = Color.WHITE
		get_tree().create_timer(0.08).timeout.connect(func():
			sprite.modulate = Color(1, 1, 1, 1)
		)

	# Blink invuln
	var tween = create_tween()
	tween.tween_property(sprite, "modulate:a", 0.3, 0.08)
	tween.tween_property(sprite, "modulate:a", 1.0, 0.08)
	tween.set_loops(3)

	hit_taken.emit(damage)

	if hp <= 0:
		die()

func die():
	died.emit()

func update_visuals():
	# Flip sprite based on facing
	if sprite:
		sprite.flip_h = facing == -1

	# Apply jump Z offset to sprite (visual only)
	if sprite:
		sprite.position.y = -jump_z

	# Shadow squashes during jump
	if shadow:
		shadow.scale.x = max(0.5, 1.0 - jump_z / 80.0)

	# Animation state
	if sprite and sprite.sprite_frames:
		if is_attacking:
			# Attack animation handles itself
			pass
		elif velocity.length() > 10:
			if sprite.sprite_frames.has_animation("walk"):
				if sprite.animation != "walk":
					sprite.play("walk")
		else:
			if sprite.sprite_frames.has_animation("idle"):
				if sprite.animation != "idle":
					sprite.play("idle")

	# Z-sorting by Y position (depth)
	z_index = int(global_position.y)

func _on_sprite_animation_finished():
	if sprite.animation == "attack":
		is_attacking = false
