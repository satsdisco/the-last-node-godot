extends StaticBody2D
class_name Destructible

## Smashable world object — vending machines, checkpoints, billboards.
## Attack to break. Drops sats + chance of power-up.

enum PropType { VENDING, CHECKPOINT, BILLBOARD }

@export var prop_type: PropType = PropType.VENDING
@export var prop_hp: int = 20
@export var drop_sats: int = 300
@export var drops_power_up: bool = true

var _hp: int
var _last_hit_time: float = 0

func _ready():
	_hp = prop_hp
	add_to_group("destructibles")

	# Collision shape
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()

	var body_rect: ColorRect
	var label_text: String

	match prop_type:
		PropType.VENDING:
			shape.size = Vector2(28, 12)
			body_rect = _make_rect(Vector2(28, 48), Color(0.2, 0.33, 0.65))
			label_text = "CBDC"
		PropType.CHECKPOINT:
			shape.size = Vector2(32, 12)
			body_rect = _make_rect(Vector2(32, 44), Color(0.33, 0.33, 0.47))
			label_text = "CHKPT"
		PropType.BILLBOARD:
			shape.size = Vector2(50, 8)
			body_rect = _make_rect(Vector2(50, 30), Color(0.13, 0.2, 0.33))
			label_text = "CBDC"

	col.shape = shape
	add_child(col)

	body_rect.position = Vector2(-body_rect.size.x / 2, -body_rect.size.y - 2)
	body_rect.name = "Body"
	add_child(body_rect)

	# White border
	var border = ColorRect.new()
	border.color = Color.WHITE
	border.size = body_rect.size + Vector2(2, 2)
	border.position = body_rect.position - Vector2(1, 1)
	border.z_index = -1
	border.name = "Border"
	add_child(border)

	# Label
	var lbl = Label.new()
	lbl.text = label_text
	lbl.position = Vector2(-25, -body_rect.size.y - 18)
	lbl.add_theme_font_size_override("font_size", 9)
	lbl.add_theme_color_override("font_color", Color.WHITE)
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(50, 16)
	add_child(lbl)

	z_index = int(global_position.y)

func _make_rect(sz: Vector2, color: Color) -> ColorRect:
	var r = ColorRect.new()
	r.size = sz
	r.color = color
	return r

func _physics_process(_delta):
	# Check if player attacked near us
	for player in get_tree().get_nodes_in_group("players"):
		if not player is Player or not is_instance_valid(player):
			continue
		var now = Time.get_ticks_msec() / 1000.0
		if player.last_attack_time == _last_hit_time:
			continue
		if now - player.last_attack_time > 0.12:
			continue
		var dx = global_position.x - player.global_position.x
		var dy = global_position.y - player.global_position.y
		if abs(dy) > 24:
			continue
		var in_front = (player.facing == 1 and dx > -4 and dx < player.attack_range) or \
					   (player.facing == -1 and dx < 4 and dx > -player.attack_range)
		if in_front:
			_last_hit_time = player.last_attack_time
			take_hit(player.base_damage)

func take_hit(dmg: int):
	_hp -= dmg

	# Flash white
	var body = get_node_or_null("Body")
	if body:
		var orig = body.color
		body.color = Color.WHITE
		get_tree().create_timer(0.06).timeout.connect(func():
			if is_instance_valid(body): body.color = orig
		)

	SFX.hit(get_tree())

	if _hp <= 0:
		_shatter()

func _shatter():
	var pos = global_position

	# Debris burst
	CombatJuice.death_burst(get_parent(), pos + Vector2(0, -20), Color(0.3, 0.4, 0.6))

	# Drop sats
	Pickup.spawn_sats(get_parent(), pos + Vector2(0, -10), drop_sats)

	# Chance to drop power-up
	if drops_power_up and randf() < 0.4:
		var types = [Pickup.PickupType.ORANGE_PILL, Pickup.PickupType.FULL_NODE, Pickup.PickupType.COLD_STORAGE]
		Pickup.spawn_power_up(get_parent(), pos + Vector2(randf_range(-20, 20), -10), types.pick_random())

	SFX.enemy_die(get_tree())
	queue_free()

# ==== FACTORY ====

static func spawn(parent: Node, pos: Vector2, type: PropType) -> Destructible:
	var d = Destructible.new()
	d.prop_type = type
	d.global_position = pos
	match type:
		PropType.VENDING:
			d.drop_sats = 300
			d.drops_power_up = true
		PropType.CHECKPOINT:
			d.drop_sats = 200
			d.drops_power_up = false
		PropType.BILLBOARD:
			d.drop_sats = 100
			d.prop_hp = 15
			d.drops_power_up = false
	parent.add_child(d)
	return d
