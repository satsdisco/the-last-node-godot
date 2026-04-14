extends CharacterBody2D
class_name Pleb

## Pleb NPC — trapped civilians at KYC checkpoints.
## Walk near one to rescue them: 300 sats drop, celebration animation, grateful quote.

var rescued: bool = false
var _walking_off: bool = false
var _walk_off_dir: int = 1

const RESCUE_RADIUS: float = 32.0
const RESCUE_REWARD: int = 300

# Shared quote pool — "be the meme" tone, no crypto-speak
const THANK_QUOTES := [
	"stay humble stack sats",
	"thanks anon",
	"RUNNING BITCOIN",
	"tyvm fren",
	"NGMI → WAGMI",
	"hodl strong",
]

var _body_rect: ColorRect
var _head_rect: ColorRect
var _wallet_dot: ColorRect
var _eyes_rect: ColorRect
var _shadow: ColorRect

func _ready():
	add_to_group("plebs")
	collision_layer = 0
	collision_mask = 0
	_build_visual()

func _build_visual():
	# Shadow under feet
	_shadow = ColorRect.new()
	_shadow.color = Color(0, 0, 0, 0.35)
	_shadow.size = Vector2(20, 4)
	_shadow.position = Vector2(-10, -2)
	_shadow.name = "Shadow"
	add_child(_shadow)

	# Body — tan/gray civilian
	_body_rect = ColorRect.new()
	_body_rect.color = Color(0.65, 0.55, 0.45)  # warm tan
	_body_rect.size = Vector2(14, 20)
	_body_rect.position = Vector2(-7, -22)
	add_child(_body_rect)

	# Head
	_head_rect = ColorRect.new()
	_head_rect.color = Color(0.82, 0.72, 0.6)
	_head_rect.size = Vector2(10, 10)
	_head_rect.position = Vector2(-5, -32)
	add_child(_head_rect)

	# Eyes — two dark dots
	_eyes_rect = ColorRect.new()
	_eyes_rect.color = Color(0.12, 0.1, 0.08)
	_eyes_rect.size = Vector2(6, 2)
	_eyes_rect.position = Vector2(-3, -28)
	add_child(_eyes_rect)

	# Orange hardware wallet dot on a string around neck
	var string = ColorRect.new()
	string.color = Color(0.3, 0.25, 0.2)
	string.size = Vector2(1, 4)
	string.position = Vector2(0, -22)
	add_child(string)

	_wallet_dot = ColorRect.new()
	_wallet_dot.color = Color(1, 0.55, 0.0)
	_wallet_dot.size = Vector2(4, 4)
	_wallet_dot.position = Vector2(-2, -18)
	add_child(_wallet_dot)

	# Little label so playtesters know it's a pleb
	var tag = Label.new()
	tag.text = "PLEB"
	tag.position = Vector2(-14, -48)
	tag.add_theme_font_size_override("font_size", 8)
	tag.add_theme_color_override("font_color", Color(1, 0.7, 0.2))
	tag.size = Vector2(28, 10)
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	add_child(tag)

	z_index = int(global_position.y)

func _physics_process(delta):
	z_index = int(global_position.y)

	if _walking_off:
		velocity = Vector2(_walk_off_dir * 120, 0)
		move_and_slide()
		# Clean up when off-screen-ish
		if abs(global_position.x) > 99999:
			queue_free()
		return

	if rescued:
		return

	# Check players within rescue radius
	for p in get_tree().get_nodes_in_group("players"):
		if not is_instance_valid(p):
			continue
		if global_position.distance_to(p.global_position) < RESCUE_RADIUS:
			_rescue(p)
			return

	# Idle bob — slight up/down to look alive
	var sway = sin(Time.get_ticks_msec() / 400.0) * 0.5
	if _body_rect:
		_body_rect.position.y = -22 + sway

func _rescue(player: Node):
	rescued = true

	# Eyes flash orange for ~1s
	if _eyes_rect:
		var eye_tween = _eyes_rect.create_tween()
		_eyes_rect.color = Color(1, 0.55, 0.0)
		eye_tween.tween_property(_eyes_rect, "color", Color(0.12, 0.1, 0.08), 1.0)

	# Jump celebration — pop the body up
	_body_rect.pivot_offset = Vector2(7, 20)
	var jump_tween = create_tween()
	jump_tween.tween_property(self, "position:y", position.y - 12, 0.15)
	jump_tween.tween_property(self, "position:y", position.y, 0.15)

	# 300 sats drop
	Pickup.spawn_sats(get_parent(), global_position + Vector2(0, -10), RESCUE_REWARD)

	# Grateful floating text
	var txt = THANK_QUOTES.pick_random()
	_spawn_thanks_label(txt)

	# Nice sound
	SFX.sat_pickup(get_tree())

	# Walk offscreen after a short pause
	_walk_off_dir = 1 if player.global_position.x < global_position.x else -1
	get_tree().create_timer(1.1).timeout.connect(func():
		if is_instance_valid(self):
			_walking_off = true
			var fade = create_tween()
			fade.tween_interval(1.0)
			fade.tween_property(self, "modulate:a", 0.0, 0.6)
			fade.tween_callback(queue_free)
	)

func _spawn_thanks_label(text: String):
	var lbl = Label.new()
	lbl.text = text
	lbl.global_position = global_position + Vector2(-50, -60)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 0.6, 0))
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	lbl.size = Vector2(100, 20)
	lbl.z_index = 500
	get_parent().add_child(lbl)

	var tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", lbl.global_position.y - 40, 1.4)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 1.4)
	tween.tween_callback(lbl.queue_free)

# ==== FACTORY ====

static func spawn(parent: Node, pos: Vector2) -> Pleb:
	var p = Pleb.new()
	p.position = pos
	parent.add_child(p)
	return p
