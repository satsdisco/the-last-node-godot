extends Player
class_name P2PTrader
## The P2P Trader — trickster, ranged hybrid, controls space.

func _ready():
	character_name = "P2P TRADER"
	speed = 150.0
	max_hp = 90
	base_damage = 8
	combo_length = 3
	attack_range = 40.0
	attack_cooldown = 0.2
	finisher_taunt = "HAVE FUN STAYING POOR."
	special_1_cost = 500
	special_2_cost = 1000
	super_cost = 5000
	super._ready()

func do_special_1():
	# No KYC — tear enemy's ID badge, stun target + nearby flinch
	_show_move_name("NO KYC")
	CombatJuice.hitstop(get_tree(), 0.08)

	# Find nearest enemy
	var nearest: Enemy = null
	var nearest_dist = 80.0
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not enemy is Enemy or not is_instance_valid(enemy):
			continue
		var dist = global_position.distance_to(enemy.global_position)
		if dist < nearest_dist:
			nearest = enemy
			nearest_dist = dist

	if nearest:
		# Stun target
		if nearest.has_method("stun"):
			nearest.stun(1500)
		if nearest.has_method("take_hit"):
			nearest.take_hit(int(base_damage * 1.2), facing)

		# Tear ID visual
		var id_lbl = Label.new()
		id_lbl.text = "ID REVOKED"
		id_lbl.global_position = nearest.global_position + Vector2(-30, -60)
		id_lbl.add_theme_font_size_override("font_size", 11)
		id_lbl.add_theme_color_override("font_color", Color(1, 0.4, 0.1))
		id_lbl.z_index = 500
		get_parent().add_child(id_lbl)
		var tween = id_lbl.create_tween()
		tween.tween_property(id_lbl, "modulate:a", 0.0, 1.0)
		tween.tween_callback(id_lbl.queue_free)

		CombatJuice.hit_sparks(get_parent(), nearest.global_position + Vector2(0, -20), Color(1, 0.4, 0.1))

		# Flinch nearby enemies
		for other in get_tree().get_nodes_in_group("enemies"):
			if other == nearest or not is_instance_valid(other):
				continue
			if global_position.distance_to(other.global_position) < 80:
				if other.has_method("stun"):
					other.stun(400)
	else:
		_show_move_name("NO TARGET")

func do_special_2():
	# Dead Drop — place hardware wallet mine, next enemy to walk over takes damage + extra drops
	_show_move_name("DEAD DROP")
	CombatJuice.hitstop(get_tree(), 0.04)

	# Place mine at current position
	var mine = ColorRect.new()
	mine.color = Color(1, 0.6, 0)
	mine.size = Vector2(10, 8)
	mine.global_position = global_position + Vector2(-5, -4)
	mine.z_index = int(global_position.y) - 1
	get_parent().add_child(mine)

	# Pulse animation
	var pulse = mine.create_tween().set_loops()
	pulse.tween_property(mine, "modulate:a", 0.4, 0.5)
	pulse.tween_property(mine, "modulate:a", 1.0, 0.5)

	var mine_pos = global_position
	var mine_damage = int(base_damage * 2.5)
	var parent_ref = get_parent()
	var tree_ref = get_tree()
	var viewport_ref = get_viewport()

	# Check for enemies walking over it
	var check = func():
		if not is_instance_valid(mine):
			return
		for enemy in tree_ref.get_nodes_in_group("enemies"):
			if not is_instance_valid(enemy):
				continue
			if mine.global_position.distance_to(enemy.global_position) < 20:
				# BOOM
				if enemy.has_method("take_hit"):
					enemy.take_hit(mine_damage, 1)
				CombatJuice.hit_sparks(parent_ref, enemy.global_position + Vector2(0, -20), Color(1, 0.6, 0), 10)
				CombatJuice.damage_number(parent_ref, enemy.global_position + Vector2(0, -30), mine_damage, Color(1, 0.6, 0))
				CombatJuice.shake(viewport_ref.get_camera_2d(), 5.0, 0.15)
				SFX.hit_heavy(tree_ref)
				# Extra drops
				Pickup.spawn_sats(parent_ref, enemy.global_position + Vector2(0, -8), 200)
				if randf() < 0.5:
					Pickup.spawn_random_drop(parent_ref, enemy.global_position + Vector2(randf_range(-15, 15), -8))
				mine.queue_free()
				return

	# Check every 0.1s for 15 seconds
	for i in range(150):
		tree_ref.create_timer(i * 0.1).timeout.connect(check)

	# Auto-expire after 15s
	tree_ref.create_timer(15.0).timeout.connect(func():
		if is_instance_valid(mine):
			mine.queue_free()
	)

func do_super():
	# Rug Pull — all enemies fall into pit, come back dazed
	_show_move_name("RUG PULL")
	CombatJuice.hitstop(get_tree(), 0.15)
	CombatJuice.shake(get_viewport().get_camera_2d(), 12.0, 0.4)

	# All enemies take damage and get stunned
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_hit"):
			enemy.take_hit(30, facing)
		if enemy.has_method("stun"):
			enemy.stun(2500)

		# Visual: enemy falls down then comes back
		var fall_tween = enemy.create_tween()
		fall_tween.tween_property(enemy, "modulate:a", 0.0, 0.2)
		fall_tween.tween_interval(1.5)
		fall_tween.tween_property(enemy, "modulate:a", 1.0, 0.3)

		CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20), Color(1, 0.4, 0.1), 6)
		CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -30), 30, Color(1, 0.4, 0.1))

	# Visual: ground cracks
	var crack = Label.new()
	crack.text = "//////////////////////"
	crack.global_position = global_position + Vector2(-80, 0)
	crack.add_theme_font_size_override("font_size", 14)
	crack.add_theme_color_override("font_color", Color(0.4, 0.2, 0.1))
	crack.z_index = int(global_position.y) - 1
	get_parent().add_child(crack)
	var c_tween = crack.create_tween()
	c_tween.tween_property(crack, "modulate:a", 0.0, 2.0)
	c_tween.tween_callback(crack.queue_free)
