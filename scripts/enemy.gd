extends CharacterBody2D
class_name Enemy

## Base enemy — chase, attack, get grabbed, get thrown, die spectacularly.
## Has Area2D hurtbox for player hitbox detection.

@export var speed: float = 90.0
@export var max_hp: int = 30
@export var damage: int = 8
@export var attack_range: float = 36.0
@export var attack_cooldown: float = 0.9
@export var drop_sats: int = 100
@export var enemy_name: String = "ENEMY"

# State
enum EnemyState { IDLE, CHASE, ATTACK, HIT, STUNNED, GRABBED, THROWN, DEAD }
var enemy_state: EnemyState = EnemyState.IDLE

var hp: int
var stunned_until: float = 0.0
var last_attack_time: float = 0.0
var facing: int = -1
var is_grabbed: bool = false
var popped_until: float = 0.0
var pop_z: float = 0.0
var thrown_until: float = 0.0
var thrown_dmg: int = 0

# Area2D for hit detection
var hurtbox_area: Area2D = null
var attack_hitbox: Area2D = null

signal died_at(pos: Vector2, sats: int)

func _ready():
	hp = int(max_hp * GameState.enemy_hp_mult())
	max_hp = hp
	add_to_group("enemies")
	_create_hurtbox()
	_create_attack_hitbox()

func _create_hurtbox():
	# Enemy hurtbox — player hitbox detects this
	hurtbox_area = Area2D.new()
	hurtbox_area.name = "Hurtbox"
	hurtbox_area.collision_layer = 4   # Layer 3 = enemy hurtboxes
	hurtbox_area.collision_mask = 0
	hurtbox_area.monitoring = false
	hurtbox_area.monitorable = true

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(20, 36)
	col.shape = shape
	col.position = Vector2(0, -22)
	col.name = "HurtboxShape"
	hurtbox_area.add_child(col)

	add_child(hurtbox_area)

func _create_attack_hitbox():
	# Enemy attack hitbox — detects player hurtboxes
	attack_hitbox = Area2D.new()
	attack_hitbox.name = "AttackHitbox"
	attack_hitbox.collision_layer = 0
	attack_hitbox.collision_mask = 8  # Mask = player hurtboxes
	attack_hitbox.monitoring = true
	attack_hitbox.monitorable = false

	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(attack_range, 16)
	col.shape = shape
	col.position = Vector2(attack_range / 2.0, -20)
	col.name = "AttackShape"
	col.disabled = true  # Only enabled during attack
	attack_hitbox.add_child(col)

	add_child(attack_hitbox)

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

	# Update attack hitbox facing direction
	_update_attack_hitbox_facing()

	_ai(now)
	move_and_slide()
	_update_visuals()

func _update_attack_hitbox_facing():
	if attack_hitbox:
		var shape = attack_hitbox.get_node_or_null("AttackShape")
		if shape:
			shape.position.x = facing * attack_range / 2.0

func _activate_attack_hitbox():
	if attack_hitbox:
		var shape = attack_hitbox.get_node_or_null("AttackShape")
		if shape:
			shape.disabled = false
			# Deactivate after a short window
			get_tree().create_timer(0.15).timeout.connect(func():
				if is_instance_valid(shape):
					shape.disabled = true
			)

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
			_activate_attack_hitbox()
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
	# Knockback scales with damage — heavy hits send them flying
	var knockback_magnitude = min(200 + dmg * 8, 500)
	velocity = Vector2(from_dir * knockback_magnitude, 0)

	# Flash white
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			var orig = child.color
			child.color = Color.WHITE
			get_tree().create_timer(0.07).timeout.connect(func():
				if is_instance_valid(child): child.color = orig
			)

	# Knockback dust on heavy hits
	if dmg >= 10:
		CombatJuice.knockback_dust(get_parent(), global_position + Vector2(0, -2), from_dir)

	# Hit stun visual — brief scale squash on impact
	var orig_scale = scale
	scale = Vector2(1.2, 0.8)  # Squash horizontally
	get_tree().create_timer(0.04).timeout.connect(func():
		if is_instance_valid(self):
			scale = Vector2(0.9, 1.15)  # Stretch vertically
			get_tree().create_timer(0.04).timeout.connect(func():
				if is_instance_valid(self):
					scale = orig_scale  # Back to normal
			)
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
	CombatJuice.death_burst(get_parent(), pos + Vector2(0, -20))

	# Drop sats + random item
	Pickup.spawn_sats(get_parent(), pos + Vector2(0, -8), sats)
	if randf() < 0.15:
		Pickup.spawn_random_drop(get_parent(), pos + Vector2(randf_range(-15, 15), -8))

	died_at.emit(pos, sats)
	queue_free()

var _walk_anim_timer: float = 0.0
var _walk_frame_idx: int = 0

func _update_visuals():
	# HP bar
	var hp_bar = get_node_or_null("HPBar")
	if hp_bar:
		var pct = float(hp) / float(max_hp)
		hp_bar.size.x = 32.0 * pct

	# Sprite animation — maps enemy state to sheet frames
	# Sheet layout: 0=idle, 1=walk1, 2=walk2, 3=attack, 4=hit, 5=death
	var sprite = get_node_or_null("Sprite") as Sprite2D
	if sprite:
		sprite.flip_h = (facing == 1)  # Enemies face left by default in art
		var now = Time.get_ticks_msec() / 1000.0
		if hp <= 0:
			sprite.frame = 5  # death
		elif now < stunned_until or enemy_state == EnemyState.HIT:
			sprite.frame = 4  # hit
		elif enemy_state == EnemyState.ATTACK:
			sprite.frame = 3  # attack
		elif enemy_state == EnemyState.CHASE:
			_walk_anim_timer += get_physics_process_delta_time()
			if _walk_anim_timer > 0.15:
				_walk_anim_timer = 0.0
				_walk_frame_idx = 1 - _walk_frame_idx  # toggle 0/1
			sprite.frame = 1 + _walk_frame_idx  # walk1 or walk2
		else:
			sprite.frame = 0  # idle

		# Critical flash on sprite
		if get_hp_pct() < 0.1 and get_hp_pct() > 0:
			var flash = fmod(Time.get_ticks_msec(), 160) < 80
			sprite.modulate = Color(2, 1, 1) if flash else Color.WHITE
	else:
		# Critical flash on ColorRect fallback
		if get_hp_pct() < 0.1 and get_hp_pct() > 0:
			var flash = fmod(Time.get_ticks_msec(), 160) < 80
			for child in get_children():
				if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
					child.modulate = Color.WHITE if flash else Color(1, 1, 1)

	# Pop Z offset on visual children
	for child in get_children():
		if child is CollisionShape2D or child is Area2D:
			continue
		if child.name == "Shadow":
			child.scale.x = max(0.5, 1.0 - pop_z / 40.0) * 2.0
			continue
		if not child.has_meta("base_y"):
			child.set_meta("base_y", child.position.y)
		child.position.y = child.get_meta("base_y") - pop_z

	z_index = int(global_position.y)
