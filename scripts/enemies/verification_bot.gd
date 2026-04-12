extends Enemy
class_name VerificationBot

## Verification Bot — walking ID verification kiosk.
## Projects verification field that damages players who stand in it too long.
## Tanky, slow. Screen shows progressive damage states.

var field_radius: float = 64.0
var field_active: bool = false
var field_cooldown: float = 5.0
var field_duration: float = 3.5
var field_timer: float = 0.0
var last_field_time: float = 0.0
var player_in_field_time: float = 0.0
var flag_threshold: float = 1.5  # seconds before player gets "flagged"
var field_visual: ColorRect = null
var screen_label: Label = null

const SCREEN_STATES = ["VERIFY\nYOUR ID", "VERIFICATION\nFAILED", "SYSTEM\nERROR"]

func _ready():
	super._ready()
	speed = 35
	max_hp = int(60 * GameState.enemy_hp_mult())
	hp = max_hp
	damage = 3  # Field tick damage when flagged
	attack_range = 28
	attack_cooldown = 1.6
	drop_sats = 200
	enemy_name = "VERIBOT"

	# Recolor to grey kiosk
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			child.color = Color(0.35, 0.4, 0.45)

	# Add screen display
	screen_label = Label.new()
	screen_label.text = "VERIFY\nYOUR ID"
	screen_label.position = Vector2(-16, -42)
	screen_label.add_theme_font_size_override("font_size", 7)
	screen_label.add_theme_color_override("font_color", Color(0, 0.8, 1))
	screen_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	screen_label.size = Vector2(32, 20)
	screen_label.name = "Screen"
	add_child(screen_label)

func _ai(now: float):
	var target = _find_target()
	if not target:
		return

	var dir = target.global_position - global_position
	var dist = dir.length()
	facing = 1 if dir.x > 0 else -1

	# Slow approach
	if dist > field_radius * 0.8 and not field_active:
		velocity = dir.normalized() * speed
	else:
		velocity = Vector2.ZERO

	# Deploy verification field periodically
	if not field_active and now - last_field_time > field_cooldown:
		_deploy_field(now)

	# Update field
	if field_active:
		field_timer -= get_physics_process_delta_time()
		if field_timer <= 0:
			_retract_field()
		else:
			_check_field_damage(target)

func _deploy_field(now: float):
	field_active = true
	field_timer = field_duration
	last_field_time = now
	player_in_field_time = 0.0

	SFX.gate_lock(get_tree())

	# Visual: pulsing circle on the ground
	field_visual = ColorRect.new()
	field_visual.color = Color(0, 0.6, 1, 0.15)
	field_visual.size = Vector2(field_radius * 2, field_radius * 0.6)
	field_visual.position = Vector2(-field_radius, -field_radius * 0.15)
	field_visual.name = "Field"
	add_child(field_visual)

	# Pulse animation
	var tween = field_visual.create_tween().set_loops()
	tween.tween_property(field_visual, "modulate:a", 0.5, 0.4)
	tween.tween_property(field_visual, "modulate:a", 1.0, 0.4)

	# Warning text
	var warn = Label.new()
	warn.text = "SCANNING AREA"
	warn.global_position = global_position + Vector2(-40, -70)
	warn.add_theme_font_size_override("font_size", 9)
	warn.add_theme_color_override("font_color", Color(0, 0.8, 1))
	warn.z_index = 500
	get_parent().add_child(warn)
	var warn_tween = warn.create_tween()
	warn_tween.tween_property(warn, "modulate:a", 0.0, 1.5)
	warn_tween.tween_callback(warn.queue_free)

func _retract_field():
	field_active = false
	player_in_field_time = 0.0
	if field_visual and is_instance_valid(field_visual):
		field_visual.queue_free()
		field_visual = null

func _check_field_damage(target: Node2D):
	var dx = abs(target.global_position.x - global_position.x)
	var dy = abs(target.global_position.y - global_position.y)

	if dx < field_radius and dy < field_radius * 0.3:
		player_in_field_time += get_physics_process_delta_time()

		if player_in_field_time > flag_threshold:
			# Player is "flagged" — take damage
			if target.has_method("take_hit"):
				# Tick damage every 0.5s
				if fmod(player_in_field_time, 0.5) < get_physics_process_delta_time():
					target.take_hit(int(damage * GameState.enemy_dmg_mult()), facing)
					# Flash field red
					if field_visual and is_instance_valid(field_visual):
						field_visual.color = Color(1, 0.1, 0.1, 0.2)
						get_tree().create_timer(0.1).timeout.connect(func():
							if is_instance_valid(field_visual):
								field_visual.color = Color(0, 0.6, 1, 0.15)
						)

			# Show "FLAGGED" warning on player
			if player_in_field_time - get_physics_process_delta_time() <= flag_threshold:
				var flag_lbl = Label.new()
				flag_lbl.text = "FLAGGED"
				flag_lbl.global_position = target.global_position + Vector2(-30, -75)
				flag_lbl.add_theme_font_size_override("font_size", 11)
				flag_lbl.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
				flag_lbl.z_index = 500
				get_parent().add_child(flag_lbl)
				var tween = flag_lbl.create_tween()
				tween.tween_property(flag_lbl, "modulate:a", 0.0, 1.0)
				tween.tween_callback(flag_lbl.queue_free)
	else:
		# Player left the field
		player_in_field_time = max(0, player_in_field_time - get_physics_process_delta_time() * 2)

# Override take_hit to update screen damage state
func take_hit(dmg: int, from_dir: int):
	super.take_hit(dmg, from_dir)
	_update_screen_state()

func _update_screen_state():
	if not screen_label or not is_instance_valid(screen_label):
		return
	var pct = get_hp_pct()
	if pct > 0.6:
		screen_label.text = SCREEN_STATES[0]
		screen_label.add_theme_color_override("font_color", Color(0, 0.8, 1))
	elif pct > 0.3:
		screen_label.text = SCREEN_STATES[1]
		screen_label.add_theme_color_override("font_color", Color(1, 0.6, 0))
	else:
		screen_label.text = SCREEN_STATES[2]
		screen_label.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
		# Flicker effect
		if randf() < 0.3:
			screen_label.modulate.a = 0.3
		else:
			screen_label.modulate.a = 1.0

func _die():
	# Clean up field
	_retract_field()
	# Show BSOD
	var bsod = Label.new()
	bsod.text = "BLUE SCREEN\nOF DEATH"
	bsod.global_position = global_position + Vector2(-30, -50)
	bsod.add_theme_font_size_override("font_size", 10)
	bsod.add_theme_color_override("font_color", Color(0.3, 0.5, 1))
	bsod.z_index = 500
	get_parent().add_child(bsod)
	var tween = bsod.create_tween()
	tween.tween_property(bsod, "modulate:a", 0.0, 1.5)
	tween.tween_callback(bsod.queue_free)
	super._die()
