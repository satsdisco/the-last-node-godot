extends Player
class_name Cypherpunk
## The Cypherpunk — fastest character, glass cannon, devastating combos.

var is_invisible: bool = false
var invisible_until: float = 0.0
var stealth_damage_bonus: float = 1.8

func _ready():
	character_name = "CYPHERPUNK"
	speed = 200.0
	max_hp = 70
	base_damage = 7
	combo_length = 6
	attack_range = 38.0
	attack_cooldown = 0.12
	finisher_taunt = "DECRYPTED."
	special_1_cost = 500
	special_2_cost = 1000
	super_cost = 5000
	super._ready()

func _physics_process(delta):
	super._physics_process(delta)
	# Check invisibility expiry
	var now = Time.get_ticks_msec() / 1000.0
	if is_invisible and now > invisible_until:
		is_invisible = false
		modulate.a = 1.0

func do_special_1():
	# Zero Knowledge — 3s invisibility, enemies lose aggro, bonus damage on exit
	_show_move_name("ZERO KNOWLEDGE")
	var now = Time.get_ticks_msec() / 1000.0
	is_invisible = true
	invisible_until = now + 3.0
	invuln_until = now + 3.0
	modulate.a = 0.2  # Nearly invisible
	damage_buff_mult = stealth_damage_bonus
	damage_buff_until = now + 3.5  # Slightly longer than invisibility

	CombatJuice.hitstop(get_tree(), 0.04)
	# Smoke puff effect
	for i in range(6):
		CombatJuice.hit_sparks(get_parent(), global_position + Vector2(randf_range(-15, 15), randf_range(-40, -10)), Color(0.5, 0, 1, 0.5))

func do_special_2():
	# Tor Route — teleport-dash through up to 3 enemies, hitting each
	_show_move_name("TOR ROUTE")
	CombatJuice.hitstop(get_tree(), 0.06)

	var targets = []
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if global_position.distance_to(enemy.global_position) < 200:
			targets.append(enemy)
		if targets.size() >= 3:
			break

	if targets.is_empty():
		# No targets — just dash forward
		velocity = Vector2(facing * 400, 0)
		return

	# Sequential teleport hits
	var i = 0
	for target in targets:
		var idx = i
		get_tree().create_timer(idx * 0.15).timeout.connect(func():
			if not is_instance_valid(self) or not is_instance_valid(target):
				return
			# Teleport to enemy
			global_position = target.global_position + Vector2(-facing * 20, 0)
			# Hit them
			if target.has_method("take_hit"):
				target.take_hit(int(base_damage * 2.0), facing)
			CombatJuice.hit_sparks(get_parent(), target.global_position + Vector2(0, -20), Color(0.5, 0, 1), 8)
			CombatJuice.damage_number(get_parent(), target.global_position + Vector2(0, -30), int(base_damage * 2.0), Color(0.5, 0, 1))
			CombatJuice.shake(get_viewport().get_camera_2d(), 3.0, 0.06)
			# Purple trail
			var trail = ColorRect.new()
			trail.color = Color(0.5, 0, 1, 0.4)
			trail.size = Vector2(4, 40)
			trail.global_position = target.global_position + Vector2(-2, -40)
			trail.z_index = int(target.global_position.y) + 5
			get_parent().add_child(trail)
			var t = trail.create_tween()
			t.tween_property(trail, "modulate:a", 0.0, 0.3)
			t.tween_callback(trail.queue_free)
		)
		i += 1

func do_super():
	# End-to-End Encryption — time freeze 4s, free hits on everything
	_show_move_name("END-TO-END ENCRYPTION")
	CombatJuice.hitstop(get_tree(), 0.1)
	CombatJuice.shake(get_viewport().get_camera_2d(), 8.0, 0.3)

	# Freeze all enemies for 4 seconds
	for enemy in get_tree().get_nodes_in_group("enemies"):
		if not is_instance_valid(enemy):
			continue
		if enemy.has_method("stun"):
			enemy.stun(4000)
		# Visual: purple tint on frozen enemies
		enemy.modulate = Color(0.6, 0.4, 1.0)
		get_tree().create_timer(4.0).timeout.connect(func():
			if is_instance_valid(enemy):
				enemy.modulate = Color.WHITE
		)

	# Speed + damage boost during freeze
	var now = Time.get_ticks_msec() / 1000.0
	speed_buff_mult = 1.5
	speed_buff_until = now + 4.0
	damage_buff_mult = 1.5
	damage_buff_until = now + 4.0

	# Purple flash
	var flash = ColorRect.new()
	flash.color = Color(0.4, 0, 0.8, 0.4)
	flash.size = Vector2(640, 360)
	flash.z_index = 3400
	var hud = get_tree().root.get_child(get_tree().root.get_child_count() - 1).get_node_or_null("HUD")
	if hud:
		hud.add_child(flash)
		var t = flash.create_tween()
		t.tween_property(flash, "modulate:a", 0.0, 0.5)
		t.tween_callback(flash.queue_free)

func _update_visuals():
	super._update_visuals()
	# Override: preserve invisibility alpha during Zero Knowledge
	if is_invisible:
		modulate.a = 0.2
