extends Enemy
class_name Banker

## Banker — keeps distance and throws fiat bill projectiles.
## Taunts the player with anti-bitcoin rhetoric.

var ideal_distance: float = 120.0
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

	# Recolor to money green
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			child.color = Color(0, 0.5, 0.2)

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

func _throw_bill(target: Node2D, dir: int):
	var bill = ColorRect.new()
	bill.color = Color(0, 0.8, 0.3)
	bill.size = Vector2(10, 5)
	bill.global_position = global_position + Vector2(dir * 10, -20)
	bill.z_index = int(global_position.y) + 5
	get_parent().add_child(bill)

	var speed_x = dir * 200.0
	var target_ref = target

	# Animate the bill flying
	var timer = get_tree().create_timer(2.0)
	var tick_fn: Callable

	tick_fn = func():
		if not is_instance_valid(bill):
			return
		bill.global_position.x += speed_x * get_process_delta_time()

		# Check collision with players
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p):
				continue
			if bill.global_position.distance_to(p.global_position + Vector2(0, -15)) < 18:
				if p.has_method("take_hit"):
					p.take_hit(int(damage * GameState.enemy_dmg_mult()), dir)
				bill.queue_free()
				return

	# Use process to move the bill
	bill.set_meta("speed", speed_x)
	bill.set_meta("timer", 0.0)
	bill.set_process(true)

	# Simple: just tween it and check collision manually
	var tween = bill.create_tween()
	tween.tween_property(bill, "global_position:x", bill.global_position.x + dir * 300, 1.5)
	tween.tween_callback(bill.queue_free)

	# Collision check via timer
	var check = func():
		if not is_instance_valid(bill):
			return
		for p in get_tree().get_nodes_in_group("players"):
			if not is_instance_valid(p):
				continue
			if bill.global_position.distance_to(p.global_position + Vector2(0, -15)) < 20:
				if p.has_method("take_hit"):
					p.take_hit(int(damage * GameState.enemy_dmg_mult()), dir)
				bill.queue_free()
				return

	# Check collision every frame for 1.5 seconds
	for i in range(30):
		get_tree().create_timer(i * 0.05).timeout.connect(check)

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
