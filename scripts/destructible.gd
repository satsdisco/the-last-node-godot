extends StaticBody2D
class_name Destructible

## Smashable world object — vending machines, ATMs, checkpoints, crates, billboards.
## Attack to break. Drops sats + chance of power-up.

enum PropType { VENDING, CHECKPOINT, BILLBOARD, ATM, CRATE }

@export var prop_type: PropType = PropType.VENDING
@export var prop_hp: int = 20
@export var drop_sats: int = 300
@export var drops_power_up: bool = true

var _hp: int
var _last_hit_time: float = 0
var _sprite: Sprite2D

# Texture paths for each prop type
const PROP_TEXTURES = {
	PropType.VENDING: "res://assets/sprites/props/prop_vending.png",
	PropType.CHECKPOINT: "res://assets/sprites/props/prop_checkpoint.png",
	PropType.BILLBOARD: "res://assets/sprites/props/prop_billboard.png",
	PropType.ATM: "res://assets/sprites/props/prop_atm.png",
	PropType.CRATE: "res://assets/sprites/props/prop_crate.png",
}

# Collision shapes (width, height) — taller so player can't walk through
# Y-position of collision shape offset so sprite base sits at body origin
const PROP_COLLISION = {
	PropType.VENDING: Vector2(32, 24),
	PropType.CHECKPOINT: Vector2(40, 24),
	PropType.BILLBOARD: Vector2(14, 14),  # Billboards are background, small collision
	PropType.ATM: Vector2(32, 24),
	PropType.CRATE: Vector2(26, 22),
}

func _ready():
	_hp = prop_hp
	add_to_group("destructibles")

	# Collision shape — taller to actually block player movement
	# Positioned above the body origin so it spans the prop's lower body
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	var col_size = PROP_COLLISION.get(prop_type, Vector2(32, 24))
	shape.size = col_size
	col.shape = shape
	col.position = Vector2(0, -col_size.y / 2.0)  # center above body origin
	add_child(col)

	# Load prop sprite from texture
	_sprite = Sprite2D.new()
	var tex = load(PROP_TEXTURES.get(prop_type, ""))
	if tex:
		_sprite.texture = tex
		_sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		# Position sprite so its bottom aligns with the collision (feet on ground)
		_sprite.offset = Vector2(0, -tex.get_height() / 2.0)
		_sprite.name = "Sprite"
		add_child(_sprite)
	else:
		# Fallback colored rect
		var fallback = ColorRect.new()
		fallback.size = Vector2(32, 40)
		fallback.color = Color(0.3, 0.3, 0.5)
		fallback.position = Vector2(-16, -42)
		fallback.name = "Sprite"
		add_child(fallback)

	z_index = int(global_position.y)

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
	if _sprite:
		_sprite.modulate = Color.WHITE * 3.0  # Bright flash
		get_tree().create_timer(0.06).timeout.connect(func():
			if is_instance_valid(_sprite): _sprite.modulate = Color.WHITE
		)

	SFX.hit(get_tree())

	if _hp <= 0:
		_shatter()

func _shatter():
	var pos = global_position

	# Debris burst — color matches prop theme
	var debris_color: Color
	match prop_type:
		PropType.VENDING: debris_color = Color(0.15, 0.25, 0.5)
		PropType.ATM: debris_color = Color(0.2, 0.3, 0.4)
		PropType.CHECKPOINT: debris_color = Color(0.4, 0.35, 0.3)
		PropType.CRATE: debris_color = Color(0.5, 0.35, 0.2)
		PropType.BILLBOARD: debris_color = Color(0.5, 0.15, 0.15)
	CombatJuice.death_burst(get_parent(), pos + Vector2(0, -20), debris_color)

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
		PropType.ATM:
			d.drop_sats = 400
			d.prop_hp = 25
			d.drops_power_up = true
		PropType.CHECKPOINT:
			d.drop_sats = 200
			d.drops_power_up = false
		PropType.CRATE:
			d.drop_sats = 250
			d.prop_hp = 12
			d.drops_power_up = true
		PropType.BILLBOARD:
			d.drop_sats = 100
			d.prop_hp = 15
			d.drops_power_up = false
	parent.add_child(d)
	return d

func _build_prop_visual():
	# Container for all visual parts — sits above collision at feet
	var container = Node2D.new()
	container.name = "Sprite"
	add_child(container)

	match prop_type:
		PropType.VENDING:
			# Dark blue vending machine with glowing slot
			var body = ColorRect.new()
			body.size = Vector2(28, 48)
			body.position = Vector2(-14, -50)
			body.color = Color(0.1, 0.15, 0.3)
			container.add_child(body)
			# Glass front
			var glass = ColorRect.new()
			glass.size = Vector2(22, 28)
			glass.position = Vector2(-11, -46)
			glass.color = Color(0.15, 0.2, 0.35)
			container.add_child(glass)
			# Glowing slot
			var slot = ColorRect.new()
			slot.size = Vector2(12, 3)
			slot.position = Vector2(-6, -14)
			slot.color = Color(0.0, 0.8, 0.4)
			container.add_child(slot)
			# "FIAT TEARS" label
			var lbl = Label.new()
			lbl.text = "FIAT\nTEARS"
			lbl.position = Vector2(-10, -44)
			lbl.add_theme_font_size_override("font_size", 6)
			lbl.add_theme_color_override("font_color", Color(0.4, 0.6, 0.9))
			container.add_child(lbl)

		PropType.CHECKPOINT:
			# KYC checkpoint gate — two posts with a red barrier
			var post_l = ColorRect.new()
			post_l.size = Vector2(6, 44)
			post_l.position = Vector2(-24, -46)
			post_l.color = Color(0.35, 0.35, 0.4)
			container.add_child(post_l)
			var post_r = ColorRect.new()
			post_r.size = Vector2(6, 44)
			post_r.position = Vector2(18, -46)
			post_r.color = Color(0.35, 0.35, 0.4)
			container.add_child(post_r)
			# Red barrier bar
			var bar = ColorRect.new()
			bar.size = Vector2(36, 4)
			bar.position = Vector2(-18, -30)
			bar.color = Color(0.9, 0.15, 0.1)
			container.add_child(bar)
			# Scanner light (blinking red)
			var scanner = ColorRect.new()
			scanner.size = Vector2(4, 4)
			scanner.position = Vector2(-2, -44)
			scanner.color = Color(1.0, 0.2, 0.1)
			container.add_child(scanner)
			# KYC sign
			var lbl = Label.new()
			lbl.text = "KYC"
			lbl.position = Vector2(-10, -46)
			lbl.add_theme_font_size_override("font_size", 7)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.3, 0.2))
			container.add_child(lbl)

		PropType.ATM:
			# Bitcoin ATM — dark body with orange B logo
			var body = ColorRect.new()
			body.size = Vector2(32, 52)
			body.position = Vector2(-16, -54)
			body.color = Color(0.12, 0.14, 0.2)
			container.add_child(body)
			# Screen
			var screen = ColorRect.new()
			screen.size = Vector2(24, 16)
			screen.position = Vector2(-12, -48)
			screen.color = Color(0.05, 0.1, 0.15)
			container.add_child(screen)
			# Bitcoin logo on screen
			var btc = Label.new()
			btc.text = "₿"
			btc.position = Vector2(-6, -50)
			btc.add_theme_font_size_override("font_size", 12)
			btc.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0))
			container.add_child(btc)
			# Card slot
			var card_slot = ColorRect.new()
			card_slot.size = Vector2(14, 2)
			card_slot.position = Vector2(-7, -26)
			card_slot.color = Color(0.05, 0.05, 0.05)
			container.add_child(card_slot)
			# "NO KYC" graffiti
			var graffiti = Label.new()
			graffiti.text = "NO KYC"
			graffiti.position = Vector2(-14, -16)
			graffiti.add_theme_font_size_override("font_size", 5)
			graffiti.add_theme_color_override("font_color", Color(1.0, 0.5, 0.0, 0.6))
			container.add_child(graffiti)

		PropType.CRATE:
			# Bitcoin crate — wooden with B stamp
			var body = ColorRect.new()
			body.size = Vector2(26, 26)
			body.position = Vector2(-13, -28)
			body.color = Color(0.4, 0.28, 0.15)
			container.add_child(body)
			# Darker planks
			var plank1 = ColorRect.new()
			plank1.size = Vector2(26, 2)
			plank1.position = Vector2(-13, -20)
			plank1.color = Color(0.3, 0.2, 0.1)
			container.add_child(plank1)
			var plank2 = ColorRect.new()
			plank2.size = Vector2(26, 2)
			plank2.position = Vector2(-13, -12)
			plank2.color = Color(0.3, 0.2, 0.1)
			container.add_child(plank2)
			# B stamp
			var stamp = Label.new()
			stamp.text = "₿"
			stamp.position = Vector2(-6, -26)
			stamp.add_theme_font_size_override("font_size", 10)
			stamp.add_theme_color_override("font_color", Color(1.0, 0.6, 0.0, 0.5))
			container.add_child(stamp)

		PropType.BILLBOARD:
			# Propaganda billboard
			var pole = ColorRect.new()
			pole.size = Vector2(3, 50)
			pole.position = Vector2(-1, -52)
			pole.color = Color(0.3, 0.3, 0.35)
			container.add_child(pole)
			var sign_bg = ColorRect.new()
			sign_bg.size = Vector2(40, 20)
			sign_bg.position = Vector2(-20, -54)
			sign_bg.color = Color(0.5, 0.12, 0.1)
			container.add_child(sign_bg)
			var lbl = Label.new()
			lbl.text = "YOUR MONEY\nOUR RULES"
			lbl.position = Vector2(-18, -54)
			lbl.add_theme_font_size_override("font_size", 5)
			lbl.add_theme_color_override("font_color", Color(1.0, 0.9, 0.8))
			container.add_child(lbl)
