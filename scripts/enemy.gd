extends CharacterBody2D
class_name Enemy

## Base enemy class. Chases the nearest player and attacks.

@export var speed: float = 90.0
@export var max_hp: int = 30
@export var damage: int = 8
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.9
@export var drop_sats: int = 100
@export var enemy_name: String = "ENEMY"

var hp: int
var stunned_until: float = 0.0
var last_attack_time: float = 0.0
var facing: int = -1

@onready var sprite: AnimatedSprite2D = $Sprite
@onready var shadow: Sprite2D = $Shadow
@onready var hp_bar: ColorRect = $HPBar
@onready var hp_bar_bg: ColorRect = $HPBarBG
@onready var label: Label = $Label

signal died(pos: Vector2, sats: int)

func _ready():
	hp = int(max_hp * GameState.enemy_hp_mult())
	max_hp = hp
	add_to_group("enemies")
	if label:
		label.text = enemy_name

func _physics_process(delta: float):
	var now = Time.get_ticks_msec() / 1000.0

	if now < stunned_until:
		velocity = velocity * 0.85
		move_and_slide()
		update_visuals()
		return

	ai(delta, now)
	move_and_slide()
	update_visuals()

func ai(_delta: float, now: float):
	# Find nearest player
	var target = find_target()
	if not target:
		return

	var dir = target.global_position - global_position
	var dist = dir.length()

	facing = 1 if dir.x > 0 else -1

	if dist > attack_range - 4:
		velocity = dir.normalized() * speed
	else:
		velocity = Vector2.ZERO
		if now - last_attack_time > attack_cooldown:
			last_attack_time = now
			attack_player(target)

func attack_player(target):
	if target.has_method("take_hit"):
		var from_dir = 1 if global_position.x < target.global_position.x else -1
		target.take_hit(int(damage * GameState.enemy_dmg_mult()), from_dir)

func find_target() -> Node2D:
	var players = get_tree().get_nodes_in_group("players")
	if players.is_empty():
		return null
	var nearest = players[0]
	var nearest_dist = global_position.distance_to(nearest.global_position)
	for p in players:
		var d = global_position.distance_to(p.global_position)
		if d < nearest_dist:
			nearest = p
			nearest_dist = d
	return nearest

func take_hit(dmg: int, from_dir: int):
	hp = max(0, hp - dmg)
	stunned_until = Time.get_ticks_msec() / 1000.0 + 0.22

	# Knockback
	velocity = Vector2(from_dir * 360, 0)

	# Flash white
	if sprite:
		sprite.modulate = Color.WHITE
		get_tree().create_timer(0.07).timeout.connect(func():
			sprite.modulate = Color(1, 1, 1, 1)
		)

	if hp <= 0:
		die()

func stun(duration_ms: float):
	stunned_until = max(stunned_until, Time.get_ticks_msec() / 1000.0 + duration_ms / 1000.0)

func die():
	died.emit(global_position, int(drop_sats * GameState.sat_drop_mult()))
	queue_free()

func update_visuals():
	if sprite:
		sprite.flip_h = facing == 1

	# HP bar
	if hp_bar and hp_bar_bg:
		var pct = float(hp) / float(max_hp)
		hp_bar.size.x = hp_bar_bg.size.x * pct
		if pct < 0.3:
			hp_bar.color = Color(1, 0.2, 0.2)
		elif pct < 0.6:
			hp_bar.color = Color(1, 0.67, 0)
		else:
			hp_bar.color = Color(1, 0.2, 0.2)

		# Flash at critical HP
		if pct < 0.1:
			var flash = fmod(Time.get_ticks_msec(), 160) < 80
			if sprite:
				sprite.modulate = Color.WHITE if flash else Color(1, 1, 1, 1)

	# Depth sort
	z_index = int(global_position.y)

	# Animation
	if sprite and sprite.sprite_frames:
		if velocity.length() > 10:
			if sprite.sprite_frames.has_animation("walk") and sprite.animation != "walk":
				sprite.play("walk")
		else:
			if sprite.sprite_frames.has_animation("idle") and sprite.animation != "idle":
				sprite.play("idle")
