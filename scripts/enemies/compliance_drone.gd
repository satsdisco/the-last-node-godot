extends Enemy
class_name ComplianceDrone

## Compliance Drone — hovering surveillance camera.
## Doesn't attack directly. When it spots the player, flashes red and calls reinforcements.
## Low HP but hovers above ground — requires jump attacks to reach.

var hover_height: float = 50.0  # How high above ground it floats
var spot_range: float = 160.0
var has_spotted: bool = false
var summon_delay: float = 1.5
var spot_time: float = 0.0
var _blink_on: bool = false

func _ready():
	super._ready()
	speed = 50
	max_hp = int(15 * GameState.enemy_hp_mult())
	hp = max_hp
	damage = 0  # Doesn't attack
	attack_range = 0
	attack_cooldown = 999.0
	drop_sats = 150
	enemy_name = "DRONE"

	# Recolor to dark grey with red eye
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			child.color = Color(0.25, 0.25, 0.3)

func _ai(now: float):
	var target = _find_target()
	if not target:
		return

	var dx = target.global_position.x - global_position.x
	var dist = abs(dx)
	facing = 1 if dx > 0 else -1

	# Hover patrol — drift slowly toward player but keep some distance
	if dist > 100:
		velocity = Vector2(sign(dx) * speed, 0)
	elif dist < 60:
		velocity = Vector2(-sign(dx) * speed * 0.5, 0)
	else:
		velocity = Vector2.ZERO

	# Spot player when in range
	if dist < spot_range and not has_spotted:
		has_spotted = true
		spot_time = now
		_start_alert()

	# Summon reinforcements after delay
	if has_spotted and now - spot_time > summon_delay:
		_summon_reinforcements()
		has_spotted = false  # Can spot again after cooldown

func _start_alert():
	# Flash red rapidly — warning before summon
	SFX.gate_lock(get_tree())

	# Show "DETECTED" text
	var lbl = Label.new()
	lbl.text = "! DETECTED !"
	lbl.global_position = global_position + Vector2(-35, -hover_height - 20)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.5)
	tween.tween_callback(lbl.queue_free)

	# Blink red for summon_delay duration
	for i in range(int(summon_delay / 0.2)):
		get_tree().create_timer(i * 0.2).timeout.connect(func():
			if is_instance_valid(self):
				_blink_on = !_blink_on
				for child in get_children():
					if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
						child.color = Color(1, 0.1, 0.1) if _blink_on else Color(0.25, 0.25, 0.3)
		)

func _summon_reinforcements():
	# Spawn 2 CBDC Enforcers near this drone's position
	SFX.special(get_tree())

	# Show "CALLING BACKUP" text
	var lbl = Label.new()
	lbl.text = "CALLING BACKUP"
	lbl.global_position = global_position + Vector2(-45, -hover_height - 20)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.1))
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)

	# Spawn enforcers at ground level near drone
	for i in range(2):
		var offset_x = (i * 2 - 1) * 60  # -60 and +60
		var spawn_pos = Vector2(global_position.x + offset_x, global_position.y)

		var e = CharacterBody2D.new()
		e.position = spawn_pos
		e.set_script(load("res://scripts/enemies/cbdc_enforcer.gd"))
		e.add_to_group("enemies")

		# Collision shape
		var col = CollisionShape2D.new()
		var shape = RectangleShape2D.new()
		shape.size = Vector2(22, 10)
		col.shape = shape
		e.add_child(col)

		# Visual body — dark enforcer color
		var body = ColorRect.new()
		body.color = Color(0.13, 0.13, 0.2)
		body.size = Vector2(26, 42)
		body.position = Vector2(-13, -46)
		e.add_child(body)

		var head_rect = ColorRect.new()
		head_rect.color = Color(0.13, 0.13, 0.2)
		head_rect.size = Vector2(18, 14)
		head_rect.position = Vector2(-9, -62)
		e.add_child(head_rect)

		# Red eyes
		var eye = ColorRect.new()
		eye.color = Color(1, 0.1, 0.1)
		eye.size = Vector2(4, 3)
		eye.position = Vector2(-5, -58)
		e.add_child(eye)
		var eye2 = ColorRect.new()
		eye2.color = Color(1, 0.1, 0.1)
		eye2.size = Vector2(4, 3)
		eye2.position = Vector2(2, -58)
		e.add_child(eye2)

		# Shadow
		var shadow = ColorRect.new()
		shadow.color = Color(0, 0, 0, 0.4)
		shadow.size = Vector2(26, 6)
		shadow.position = Vector2(-13, -2)
		shadow.name = "Shadow"
		e.add_child(shadow)

		# HP bars
		var hp_bg = ColorRect.new()
		hp_bg.color = Color(0.2, 0, 0)
		hp_bg.size = Vector2(32, 4)
		hp_bg.position = Vector2(-16, -70)
		hp_bg.name = "HPBarBG"
		e.add_child(hp_bg)

		var hp_bar = ColorRect.new()
		hp_bar.color = Color(1, 0.2, 0.2)
		hp_bar.size = Vector2(32, 4)
		hp_bar.position = Vector2(-16, -70)
		hp_bar.name = "HPBar"
		e.add_child(hp_bar)

		var name_lbl = Label.new()
		name_lbl.text = "ENFORCER"
		name_lbl.position = Vector2(-24, -82)
		name_lbl.add_theme_font_size_override("font_size", 9)
		name_lbl.add_theme_color_override("font_color", Color(0.53, 0.67, 1.0))
		name_lbl.name = "Label"
		e.add_child(name_lbl)

		# Flash in effect
		e.modulate = Color(1, 1, 1, 0)
		get_parent().add_child(e)
		var spawn_tween = e.create_tween()
		spawn_tween.tween_property(e, "modulate:a", 1.0, 0.3)

# Override take_hit — only jump attacks and specials can hit the drone
# (check if player is jumping or if damage is high enough to be a special)
func take_hit(dmg: int, from_dir: int):
	# Allow all hits — the hover height makes it harder to reach naturally
	# but we don't want to block hits that do connect
	super.take_hit(dmg, from_dir)

func _update_visuals():
	super._update_visuals()
	# Apply hover offset to all visual children
	for child in get_children():
		if child is CollisionShape2D:
			continue
		if child.name == "Shadow":
			# Shadow stays on ground, gets smaller with height
			child.scale.x = 1.5
			continue
		if child.has_meta("base_y"):
			child.position.y = child.get_meta("base_y") - hover_height
		elif not child.has_meta("hover_set"):
			child.set_meta("base_y", child.position.y)
			child.set_meta("hover_set", true)
			child.position.y -= hover_height
