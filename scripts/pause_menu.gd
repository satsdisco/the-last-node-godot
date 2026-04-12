extends CanvasLayer

## Pause menu — ESC to toggle. Shows controls + resume/quit.

var is_paused: bool = false
var overlay: ColorRect
var menu_container: Control

func _ready():
	process_mode = Node.PROCESS_MODE_ALWAYS
	layer = 100

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ESCAPE or event.keycode == KEY_P:
			toggle_pause()

func toggle_pause():
	is_paused = !is_paused
	get_tree().paused = is_paused

	if is_paused:
		_show_menu()
	else:
		_hide_menu()

func _show_menu():
	overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.85)
	overlay.size = Vector2(640, 360)
	add_child(overlay)

	menu_container = Control.new()
	menu_container.size = Vector2(640, 360)
	add_child(menu_container)

	var green = Color(0, 1, 0.4)
	var orange = Color(1, 0.6, 0)
	var cyan = Color(0.4, 0.8, 1)

	# Title
	_add_label("== PAUSED ==", Vector2(170, 20), 22, orange)

	# P1 controls
	_add_label("> CONTROLS", Vector2(40, 60), 12, orange)
	var controls = [
		["MOVE", "WASD"],
		["ATTACK", "Z (mash for combos)"],
		["  FWD+Z", "Lunge"],
		["  DOWN+Z", "Sweep"],
		["  UP+Z", "Launcher"],
		["  AIR+Z", "Dive"],
		["SPECIAL", "X (500 sats)"],
		["  DOWN+X", "Heavy (1000 sats)"],
		["  UP+X", "Super (5000 sats)"],
		["JUMP", "C"],
		["GRAB", "V near enemy"],
		["  Z grab", "Strike"],
		["  V grab", "Throw"],
	]
	for i in range(controls.size()):
		_add_label(controls[i][0], Vector2(50, 80 + i * 16), 9, green)
		_add_label(controls[i][1], Vector2(160, 80 + i * 16), 9, Color.WHITE)

	# Items
	_add_label("> POWER-UPS (walk over)", Vector2(340, 60), 12, orange)
	var items = [
		["ORANGE PILL", "+25% HP"],
		["COLD STORAGE", "Invincible 5s"],
		["FULL NODE", "Damage up"],
		["WHITEPAPER", "Screen clear"],
		["LIGHTNING", "Speed up"],
	]
	for i in range(items.size()):
		_add_label(items[i][0], Vector2(350, 80 + i * 16), 9, green)
		_add_label(items[i][1], Vector2(470, 80 + i * 16), 9, Color.WHITE)

	# Resume/quit
	_add_label("[ESC] RESUME    [Q] QUIT TO TITLE", Vector2(140, 320), 11, cyan)

func _add_label(text: String, pos: Vector2, size: int, color: Color):
	var lbl = Label.new()
	lbl.text = text
	lbl.position = pos
	lbl.add_theme_font_size_override("font_size", size)
	lbl.add_theme_color_override("font_color", color)
	menu_container.add_child(lbl)

func _hide_menu():
	if overlay:
		overlay.queue_free()
		overlay = null
	if menu_container:
		menu_container.queue_free()
		menu_container = null
