extends Area2D
class_name Pickup

## Base pickup — sat coins, power-ups, weapons. Auto-collected on player overlap.

enum PickupType { SATS, ORANGE_PILL, FULL_NODE, COLD_STORAGE, LIGHTNING, WHITEPAPER, WEAPON }

@export var pickup_type: PickupType = PickupType.SATS
@export var value: int = 100
@export var weapon_name: String = ""
@export var weapon_damage_bonus: int = 0
@export var weapon_uses: int = 8

var _bob_base_y: float = 0
var _magnet_range: float = 72.0

func _ready():
	_bob_base_y = global_position.y
	collision_layer = 0
	collision_mask = 0
	monitoring = true
	monitorable = true

	# Create collision shape
	var col = CollisionShape2D.new()
	var shape = CircleShape2D.new()
	shape.radius = 20
	col.shape = shape
	add_child(col)

	# Visual based on type
	_create_visual()

	# Auto-expire
	get_tree().create_timer(12.0).timeout.connect(func():
		if is_instance_valid(self): queue_free()
	)

func _create_visual():
	var color: Color
	var label_text: String
	var size_px = Vector2(12, 12)

	match pickup_type:
		PickupType.SATS:
			color = Color(1, 0.8, 0.2)
			label_text = "+%d" % value
			size_px = Vector2(10, 10)
		PickupType.ORANGE_PILL:
			color = Color(1, 0.6, 0)
			label_text = "ORANGE PILL\n+25% HP"
		PickupType.FULL_NODE:
			color = Color(0, 1, 0.4)
			label_text = "FULL NODE\n1.6X DMG"
		PickupType.COLD_STORAGE:
			color = Color(0.4, 0.8, 1)
			label_text = "COLD STORAGE\nINVINCIBLE 5S"
		PickupType.LIGHTNING:
			color = Color(1, 0.93, 0)
			label_text = "LIGHTNING\n1.3X SPEED"
		PickupType.WHITEPAPER:
			color = Color(1, 1, 1)
			label_text = "WHITEPAPER\nSCREEN CLEAR"
		PickupType.WEAPON:
			color = Color(0.7, 0.7, 0.7)
			label_text = weapon_name

	# Glow halo
	var halo = ColorRect.new()
	halo.color = Color(color.r, color.g, color.b, 0.25)
	halo.size = Vector2(24, 24)
	halo.position = Vector2(-12, -16)
	halo.name = "Halo"
	add_child(halo)

	# Item body
	var body = ColorRect.new()
	body.color = color
	body.size = size_px
	body.position = Vector2(-size_px.x / 2, -size_px.y - 4)
	add_child(body)

	# Border
	var border = ColorRect.new()
	border.color = Color.WHITE
	border.size = size_px + Vector2(2, 2)
	border.position = body.position - Vector2(1, 1)
	border.z_index = -1
	add_child(border)

	# Label
	var lbl = Label.new()
	lbl.text = label_text
	lbl.position = Vector2(-40, -size_px.y - 22)
	lbl.add_theme_font_size_override("font_size", 8)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(80, 30)
	add_child(lbl)

	z_index = int(global_position.y)

func _physics_process(delta):
	# Bob animation
	global_position.y = _bob_base_y + sin(Time.get_ticks_msec() / 300.0) * 3

	# Magnet toward nearest player (sats only)
	if pickup_type == PickupType.SATS:
		var players = get_tree().get_nodes_in_group("players")
		for p in players:
			if not is_instance_valid(p):
				continue
			var dist = global_position.distance_to(p.global_position)
			if dist < _magnet_range:
				var dir = (p.global_position - global_position).normalized()
				var pull = 4.0 * (1.0 - dist / _magnet_range)
				global_position += dir * pull
				_bob_base_y = global_position.y

	# Check overlap with players
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p) or not p is Player:
			continue
		if global_position.distance_to(p.global_position) < 24:
			_collect(p)
			return

	z_index = int(global_position.y)

func _collect(player: Player):
	match pickup_type:
		PickupType.SATS:
			GameState.sats += value
			SFX.sat_pickup(get_tree())
			CombatJuice.sat_popup(get_parent(), global_position, value)

		PickupType.ORANGE_PILL:
			player.hp = min(player.max_hp, player.hp + int(player.max_hp * 0.25))
			SFX.sat_pickup(get_tree())
			_show_effect(player, "ORANGE PILL\n+25% HP", Color(1, 0.6, 0))

		PickupType.FULL_NODE:
			player.damage_buff_mult = 1.6
			player.damage_buff_until = Time.get_ticks_msec() / 1000.0 + 10.0
			SFX.special(get_tree())
			_show_effect(player, "FULL NODE\n1.6X DAMAGE 10S", Color(0, 1, 0.4))

		PickupType.COLD_STORAGE:
			player.invuln_until = Time.get_ticks_msec() / 1000.0 + 5.0
			SFX.special(get_tree())
			_show_effect(player, "COLD STORAGE\nINVINCIBLE", Color(0.4, 0.8, 1))

		PickupType.LIGHTNING:
			player.speed_buff_mult = 1.3
			player.speed_buff_until = Time.get_ticks_msec() / 1000.0 + 8.0
			SFX.special(get_tree())
			_show_effect(player, "LIGHTNING\n1.3X SPEED 8S", Color(1, 0.93, 0))

		PickupType.WHITEPAPER:
			# Kill all enemies on screen
			SFX.super_move(get_tree())
			for enemy in get_tree().get_nodes_in_group("enemies"):
				if is_instance_valid(enemy) and enemy.has_method("take_hit"):
					enemy.take_hit(9999, 1)
			_show_effect(player, "WHITEPAPER\nSCREEN CLEAR", Color(1, 1, 1))

		PickupType.WEAPON:
			SFX.grab(get_tree())
			_show_effect(player, weapon_name, Color(0.7, 0.7, 0.7))

	queue_free()

func _show_effect(player: Player, text: String, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.global_position = player.global_position + Vector2(-40, -70)
	lbl.add_theme_font_size_override("font_size", 12)
	lbl.add_theme_color_override("font_color", color)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(80, 40)
	lbl.z_index = 500
	get_parent().add_child(lbl)
	var tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", player.global_position.y - 100, 1.0)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(lbl.queue_free)

# ==== FACTORY METHODS ====

static func spawn_sats(parent: Node, pos: Vector2, amount: int) -> Pickup:
	var p = Pickup.new()
	p.pickup_type = PickupType.SATS
	p.value = amount
	p.global_position = pos
	parent.add_child(p)
	return p

static func spawn_power_up(parent: Node, pos: Vector2, type: PickupType) -> Pickup:
	var p = Pickup.new()
	p.pickup_type = type
	p.global_position = pos
	parent.add_child(p)
	return p

static func spawn_random_drop(parent: Node, pos: Vector2):
	# 60% sats, 25% orange pill, 10% power-up, 5% weapon
	var roll = randf()
	if roll < 0.60:
		spawn_sats(parent, pos, [100, 100, 100, 250, 250, 500].pick_random())
	elif roll < 0.85:
		spawn_power_up(parent, pos, PickupType.ORANGE_PILL)
	elif roll < 0.95:
		var types = [PickupType.FULL_NODE, PickupType.COLD_STORAGE, PickupType.LIGHTNING]
		spawn_power_up(parent, pos, types.pick_random())
	else:
		spawn_power_up(parent, pos, PickupType.WHITEPAPER)
