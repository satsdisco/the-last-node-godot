extends Enemy
class_name CBDCEnforcer

## Riot police with shield. Blocks frontal attacks. Shield bash charge.
## Flank them, grab them, or use specials to break through.

var shield_intact: bool = true
var facing_dir: int = -1
var charge_until: float = 0
var last_charge_at: float = 0

func _ready():
	super._ready()
	speed = 68
	max_hp = int(55 * GameState.enemy_hp_mult())
	hp = max_hp
	damage = 14
	attack_range = 32
	attack_cooldown = 1.2
	drop_sats = 250
	enemy_name = "ENFORCER"

	# Recolor body darker (tactical armor)
	for child in get_children():
		if child is ColorRect and child.name != "Shadow" and child.name != "HPBar" and child.name != "HPBarBG":
			child.color = Color(0.13, 0.13, 0.2)

	# Shield visual
	var shield = ColorRect.new()
	shield.name = "Shield"
	shield.color = Color(0.6, 0.8, 1.0)
	shield.size = Vector2(6, 36)
	shield.position = Vector2(12, -44)
	add_child(shield)

func _physics_process(delta):
	var now = Time.get_ticks_msec() / 1000.0

	# Update shield position
	var target = _find_target()
	if target:
		facing_dir = 1 if target.global_position.x > global_position.x else -1

	if shield_intact:
		var shield = get_node_or_null("Shield")
		if shield:
			shield.position.x = facing_dir * 14
			shield.visible = true

	# Shield bash charge
	if shield_intact and target and now - last_charge_at > 4.0:
		var dx = abs(target.global_position.x - global_position.x)
		var dy = abs(target.global_position.y - global_position.y)
		if dy < 28 and dx < 200 and dx > 56:
			last_charge_at = now
			charge_until = now + 0.65
			# Warning flash
			var shield_node = get_node_or_null("Shield")
			if shield_node:
				shield_node.color = Color(1, 0.67, 0)
				get_tree().create_timer(0.3).timeout.connect(func():
					if is_instance_valid(shield_node) and shield_intact:
						shield_node.color = Color(0.6, 0.8, 1.0)
				)

	if now < charge_until:
		velocity = Vector2(facing_dir * 320, 0)
		# Check charge collision
		if target and global_position.distance_to(target.global_position) < 36:
			if target.has_method("take_hit"):
				target.take_hit(int(damage * 1.3 * GameState.enemy_dmg_mult()), facing_dir)
				CombatJuice.shake(get_viewport().get_camera_2d(), 6.0, 0.15)
			charge_until = 0
		move_and_slide()
		_update_visuals()
		return

	super._physics_process(delta)

func take_hit(dmg: int, from_dir: int):
	# Shield blocks frontal attacks
	if shield_intact and from_dir != facing_dir:
		SFX.hit(get_tree())
		# Block flash
		var shield_node = get_node_or_null("Shield")
		if shield_node:
			shield_node.color = Color.WHITE
			get_tree().create_timer(0.06).timeout.connect(func():
				if is_instance_valid(shield_node):
					shield_node.color = Color(0.6, 0.8, 1.0)
			)

		# Heavy hits break the shield
		if dmg > 20:
			shield_intact = false
			if shield_node:
				shield_node.queue_free()
			_show_text("SHIELD BROKEN", Color.WHITE)
			CombatJuice.death_burst(get_parent(), global_position + Vector2(0, -20), Color(0.6, 0.8, 1.0))
		return

	super.take_hit(dmg, from_dir)

func _show_text(text: String, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.global_position = global_position + Vector2(-30, -70)
	lbl.add_theme_font_size_override("font_size", 10)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(lbl.queue_free)
