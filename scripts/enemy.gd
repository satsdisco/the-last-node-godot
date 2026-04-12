extends CharacterBody2D
class_name Enemy

## Base enemy — chase, attack, get grabbed, get thrown, die spectacularly.

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
var is_grabbed: bool = false
var popped_until: float = 0.0
var pop_z: float = 0.0
var thrown_until: float = 0.0
var thrown_dmg: int = 0

signal died_at(pos: Vector2, sats: int)

func _ready():
	hp = int(max_hp * GameState.enemy_hp_mult())
	max_hp = hp
	add_to_group("enemies")

func _physics_process(delta: float):
	var now = Time.get_ticks_msec() / 1000.0

	# Thrown — travel and damage anything in path
	if now < thrown_until:
		move_and_slide()
		_check_thrown_collisions()
		_update_visuals()
		return

	# Grabbed — fully controlled by player
	if is_grabbed:
		_update_visuals()
		return

	# Popped up (launcher)
	if now < popped_until:
		var phase = (popped_until - now) / 0.5
		pop_z = sin(phase * PI) * 28
		velocity = Vector2.ZERO
		move_and_slide()
		_update_visuals()
		return
	else:
		pop_z = 0

	# Stunned — decay velocity
	if now < stunned_until:
		velocity = velocity * 0.85
		move_and_slide()
		_update_visuals()
		return

	_ai(now)
	move_and_slide()
	_update_visuals()

func _ai(now: float):
	var target = _find_target()
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
			if target.has_method("take_hit"):
				var from_dir = 1 if global_position.x < target.global_position.x else -1
				target.take_hit(int(damage * GameState.enemy_dmg_mult()), from_dir)

func _find_target() -> Node2D:
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
	velocity = Vector2(from_dir * 360, 0)

	# Flash white
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			var orig = child.color
			child.color = Color.WHITE
			get_tree().create_timer(0.07).timeout.connect(func():
				if is_instance_valid(child): child.color = orig
			)

	SFX.hit(get_tree())
	if hp <= 0:
		_die()

func get_hp_pct() -> float:
	return float(hp) / float(max_hp) if max_hp > 0 else 0.0

func stun(duration_ms: float):
	stunned_until = max(stunned_until, Time.get_ticks_msec() / 1000.0 + duration_ms / 1000.0)

func pop_up(duration: float):
	popped_until = Time.get_ticks_msec() / 1000.0 + duration

func set_grabbed(grabbed: bool):
	is_grabbed = grabbed
	if grabbed:
		velocity = Vector2.ZERO

func be_thrown(vx: float):
	is_grabbed = false
	velocity = Vector2(vx, 0)
	thrown_until = Time.get_ticks_msec() / 1000.0 + 0.6
	thrown_dmg = 15
	take_hit(int(thrown_dmg * 0.5), 1 if vx > 0 else -1)

func _check_thrown_collisions():
	for other in get_tree().get_nodes_in_group("enemies"):
		if other == self or not is_instance_valid(other):
			continue
		if global_position.distance_to(other.global_position) < 24:
			other.take_hit(thrown_dmg, 1 if velocity.x > 0 else -1)
			CombatJuice.hit_sparks(get_parent(), other.global_position + Vector2(0, -20))
			thrown_until = 0

func _die():
	var pos = global_position
	var sats = int(drop_sats * GameState.sat_drop_mult())

	SFX.enemy_die(get_tree())
	SFX.sat_pickup(get_tree())
	CombatJuice.death_burst(get_parent(), pos + Vector2(0, -20))
	CombatJuice.sat_popup(get_parent(), pos, sats)
	GameState.sats += sats

	died_at.emit(pos, sats)
	queue_free()

func _update_visuals():
	# HP bar
	var hp_bar = get_node_or_null("HPBar")
	if hp_bar:
		var pct = float(hp) / float(max_hp)
		hp_bar.size.x = 32.0 * pct

	# Critical flash
	if get_hp_pct() < 0.1 and get_hp_pct() > 0:
		var flash = fmod(Time.get_ticks_msec(), 160) < 80
		for child in get_children():
			if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
				child.modulate = Color.WHITE if flash else Color(1, 1, 1)

	# Pop Z offset on visual children
	for child in get_children():
		if child is CollisionShape2D:
			continue
		if child.name == "Shadow":
			child.scale.x = max(0.5, 1.0 - pop_z / 40.0) * 2.0
			continue
		if not child.has_meta("base_y"):
			child.set_meta("base_y", child.position.y)
		child.position.y = child.get_meta("base_y") - pop_z

	z_index = int(global_position.y)
