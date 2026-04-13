extends Enemy
class_name Banker

## Banker — keeps distance and throws fiat bill projectiles.
## Taunts the player with anti-bitcoin rhetoric.

var ideal_distance: float = 80.0
var last_taunt_at: float = 0

const TAUNTS = [
	"BITCOIN IS DEAD",
	"ITS A BUBBLE",
	"TULIPS",
	"WHAT BACKS IT",
	"TOO VOLATILE",
	"PONZI SCHEME",
]

func _ready():
	super._ready()
	speed = 60
	max_hp = int(20 * GameState.enemy_hp_mult())
	hp = max_hp
	damage = 4
	attack_range = 140
	attack_cooldown = 1.4
	drop_sats = 100
	enemy_name = "BANKER"


func _ai(now: float):
	var target = _find_target()
	if not target:
		return

	var dx = target.global_position.x - global_position.x
	var dist = abs(dx)
	var dir_x = sign(dx)
	facing = 1 if dx > 0 else -1

	# Keep ideal distance — back away if too close, approach if too far
	if dist < ideal_distance - 20:
		velocity = Vector2(-dir_x * speed, 0)
	elif dist > ideal_distance + 20:
		velocity = Vector2(dir_x * speed * 0.5, 0)
	else:
		velocity = Vector2.ZERO
		# Throw bills when in range
		if now - last_attack_time > attack_cooldown:
			last_attack_time = now
			_throw_bill(target, dir_x)

	# Taunt every 4 seconds
	if now - last_taunt_at > 4.0:
		last_taunt_at = now
		_taunt()

func _throw_bill(_target: Node2D, dir: int):
	enemy_state = EnemyState.ATTACK
	last_attack_time = Time.get_ticks_msec() / 1000.0
	var bill = _BillProjectile.new()
	bill.dir = dir
	bill.bill_damage = int(damage * GameState.enemy_dmg_mult())
	bill.global_position = global_position + Vector2(dir * 10, -20)
	bill.z_index = int(global_position.y) + 5
	get_parent().add_child(bill)
	# Small screen shake on throw
	CombatJuice.shake(get_viewport().get_camera_2d(), 2.0, 0.08)
	# Reset attack state after brief window
	get_tree().create_timer(0.4).timeout.connect(func(): enemy_state = EnemyState.IDLE)


## Inner class for bill projectile — uses _process for reliable collision
class _BillProjectile extends ColorRect:
	var dir: int = 1
	var bill_damage: int = 4
	var bill_speed: float = 200.0
	var lifetime: float = 0.0

	func _ready():
		color = Color(0, 0.9, 0.3)
		size = Vector2(14, 7)
		rotation = dir * 0.15  # Slight angle for flair
		# Pulse/flash as it travels
		var pulse_tween = create_tween().set_loops()
		pulse_tween.tween_property(self, "modulate", Color(1.4, 1.4, 1.0), 0.1)
		pulse_tween.tween_property(self, "modulate", Color(1.0, 1.0, 1.0), 0.1)

	func _process(delta):
		lifetime += delta
		global_position.x += dir * bill_speed * delta
		rotation += dir * delta * 1.5  # Slow spin in flight

		# Check collision with players — use X and Y separately for 2.5D
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p):
				continue
			var dx = abs(global_position.x - p.global_position.x)
			var dy = abs(global_position.y - (p.global_position.y - 15))
			if dx < 20 and dy < 24:
				if p.has_method("take_hit"):
					p.take_hit(bill_damage, dir)
				queue_free()
				return

		# Auto-expire after 2 seconds
		if lifetime > 2.0:
			queue_free()

func _taunt():
	var text = TAUNTS.pick_random()
	var lbl = Label.new()
	lbl.text = text
	lbl.global_position = global_position + Vector2(-40, -70)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(0, 0.8, 0.3))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 2.0)
	tween.tween_callback(lbl.queue_free)
