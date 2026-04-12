extends Player
class_name Miner
## The Miner — slow tank, heavy hits, crowd control king.

var _overclock_until: float = 0.0

func _ready():
	character_name = "MINER"
	speed = 120.0
	max_hp = 140
	base_damage = 15
	combo_length = 3
	attack_range = 50.0
	attack_cooldown = 0.25
	finisher_taunt = "PROOF OF WORK."
	special_1_cost = 500
	special_2_cost = 1000
	super_cost = 5000
	super._ready()

func do_special_1():
	# Overclock — superheats fists, next 3 hits do 2x damage and knock down
	_show_move_name("OVERCLOCK")
	var now = Time.get_ticks_msec() / 1000.0
	damage_buff_mult = 2.0
	damage_buff_until = now + 6.0
	invuln_until = now + 0.5
	_overclock_until = now + 6.0
	CombatJuice.hitstop(get_tree(), 0.06)

	# Hit sparks around player
	for i in range(4):
		CombatJuice.hit_sparks(get_parent(), global_position + Vector2(randf_range(-20, 20), randf_range(-40, -10)), Color(1, 0.4, 0.1))

func do_special_2():
	# Ground Pound — shockwave hits all grounded enemies
	_show_move_name("GROUND POUND")
	CombatJuice.hitstop(get_tree(), 0.12)
	CombatJuice.shake(get_viewport().get_camera_2d(), 10.0, 0.3)

	# Expanding shockwave ring
	_spawn_ring(Color(0.8, 0.4, 0.1, 0.6), 120)

	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 120:
			if enemy.has_method("take_hit"):
				enemy.take_hit(int(base_damage * 1.8), facing)
			if enemy.has_method("stun"):
				enemy.stun(600)
			CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20), Color(0.8, 0.4, 0.1), 6)
			CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -30), int(base_damage * 1.8), Color(0.8, 0.4, 0.1))

func do_super():
	# 51% Attack — screen-clearing hashpower flash
	_show_move_name("51% ATTACK")
	CombatJuice.hitstop(get_tree(), 0.25)
	CombatJuice.shake(get_viewport().get_camera_2d(), 15.0, 0.5)

	# Orange flash
	var flash = ColorRect.new()
	flash.color = Color(1, 0.6, 0, 0.6)
	flash.size = Vector2(640, 360)
	flash.z_index = 3400
	var hud = get_tree().root.get_child(get_tree().root.get_child_count() - 1).get_node_or_null("HUD")
	if hud:
		hud.add_child(flash)
		var tween = flash.create_tween()
		tween.tween_property(flash, "modulate:a", 0.0, 0.4)
		tween.tween_callback(flash.queue_free)

	# Damage all enemies heavily
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("take_hit"):
			enemy.take_hit(60, facing)
		CombatJuice.hit_sparks(get_parent(), enemy.global_position + Vector2(0, -20), Color(1, 0.6, 0), 12)
		CombatJuice.damage_number(get_parent(), enemy.global_position + Vector2(0, -30), 60, Color(1, 0.6, 0))

func _update_visuals():
	super._update_visuals()
	# Override buff color with Overclock's orange-red glow
	var now = Time.get_ticks_msec() / 1000.0
	if now < _overclock_until:
		modulate = Color(1.0, 0.4, 0.1)
