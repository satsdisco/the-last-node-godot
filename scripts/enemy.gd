extends CharacterBody2D
class_name Enemy

## Base enemy. Chases nearest player, attacks in range.

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

var hp_bar_node: ColorRect = null

signal died_at(pos: Vector2, sats: int)

func _ready():
	hp = int(max_hp * GameState.enemy_hp_mult())
	max_hp = hp
	add_to_group("enemies")
	# Find HP bar child
	hp_bar_node = get_node_or_null("HPBar")

func _physics_process(delta: float):
	var now = Time.get_ticks_msec() / 1000.0

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

	if hp <= 0:
		_die()

func stun(duration_ms: float):
	stunned_until = max(stunned_until, Time.get_ticks_msec() / 1000.0 + duration_ms / 1000.0)

func _die():
	var pos = global_position
	var sats = int(drop_sats * GameState.sat_drop_mult())

	# Death burst particles
	CombatJuice.death_burst(get_parent(), pos + Vector2(0, -20))

	# Sat drop popup
	CombatJuice.sat_popup(get_parent(), pos, sats)
	GameState.sats += sats

	died_at.emit(pos, sats)
	queue_free()

func _update_visuals():
	# HP bar
	if hp_bar_node:
		var pct = float(hp) / float(max_hp)
		hp_bar_node.size.x = 32.0 * pct

	# Critical flash
	if float(hp) / float(max_hp) < 0.1:
		var flash = fmod(Time.get_ticks_msec(), 160) < 80
		for child in get_children():
			if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
				child.modulate = Color.WHITE if flash else Color(1, 1, 1)

	z_index = int(global_position.y)
