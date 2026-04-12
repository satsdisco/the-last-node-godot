extends Node2D

## Title screen — THE LAST NODE
## Character select, mode select, start game.

var cursor: int = 0
var menu_items: Array = ["START GAME", "HOW TO PLAY", "QUIT"]
var menu_labels: Array = []
var cursor_label: Label

func _ready():
	# Dark background
	var bg = ColorRect.new()
	bg.color = Color(0.02, 0.03, 0.05)
	bg.size = Vector2(640, 360)
	add_child(bg)

	# Scanline overlay
	for i in range(0, 360, 2):
		var line = ColorRect.new()
		line.color = Color(0, 0.04, 0.08, 0.3)
		line.position = Vector2(0, i)
		line.size = Vector2(640, 1)
		line.z_index = 100
		add_child(line)

	# Title
	var title = Label.new()
	title.text = "THE LAST NODE"
	title.position = Vector2(100, 50)
	title.add_theme_font_size_override("font_size", 36)
	title.add_theme_color_override("font_color", Color(1, 0.6, 0))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.size = Vector2(440, 50)
	add_child(title)

	# Blinking cursor after title
	var blink = Label.new()
	blink.text = "_"
	blink.position = Vector2(410, 50)
	blink.add_theme_font_size_override("font_size", 36)
	blink.add_theme_color_override("font_color", Color(1, 0.6, 0))
	add_child(blink)
	var tween = create_tween().set_loops()
	tween.tween_property(blink, "modulate:a", 0.0, 0.5)
	tween.tween_property(blink, "modulate:a", 1.0, 0.5)

	# Tagline
	var tagline = Label.new()
	tagline.text = "> KEEP THE NODE ALIVE"
	tagline.position = Vector2(100, 95)
	tagline.add_theme_font_size_override("font_size", 12)
	tagline.add_theme_color_override("font_color", Color(0, 1, 0.4))
	tagline.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tagline.size = Vector2(440, 20)
	add_child(tagline)

	# Premise
	var premise = Label.new()
	premise.text = "The year is 2030. CBDCs have won. Cash is illegal.\nSomewhere in a basement, the last Bitcoin node is still running.\nFight through the surveillance state to protect it."
	premise.position = Vector2(100, 125)
	premise.add_theme_font_size_override("font_size", 10)
	premise.add_theme_color_override("font_color", Color(0.5, 0.6, 0.7))
	premise.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	premise.size = Vector2(440, 50)
	add_child(premise)

	# Menu items
	for i in range(menu_items.size()):
		var lbl = Label.new()
		lbl.text = "  " + menu_items[i]
		lbl.position = Vector2(220, 200 + i * 28)
		lbl.add_theme_font_size_override("font_size", 16)
		lbl.add_theme_color_override("font_color", Color(1, 1, 1) if i > 0 else Color(1, 0.6, 0))
		lbl.size = Vector2(200, 24)
		add_child(lbl)
		menu_labels.append(lbl)

	# Cursor
	cursor_label = Label.new()
	cursor_label.text = ">"
	cursor_label.position = Vector2(210, 200)
	cursor_label.add_theme_font_size_override("font_size", 16)
	cursor_label.add_theme_color_override("font_color", Color(1, 0.6, 0))
	add_child(cursor_label)

	# Controls
	var controls = Label.new()
	controls.text = "P1: WASD + Z X C V    |    ARROWS to select    |    ENTER to confirm"
	controls.position = Vector2(80, 320)
	controls.add_theme_font_size_override("font_size", 9)
	controls.add_theme_color_override("font_color", Color(0, 0.5, 0.3))
	controls.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	controls.size = Vector2(480, 16)
	add_child(controls)

	# Bitcoin culture
	var quote = Label.new()
	quote.text = '"Running Bitcoin." — Hal Finney, January 10 2009'
	quote.position = Vector2(80, 340)
	quote.add_theme_font_size_override("font_size", 8)
	quote.add_theme_color_override("font_color", Color(0.3, 0.4, 0.5))
	quote.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	quote.size = Vector2(480, 16)
	add_child(quote)

	_update_cursor()

func _unhandled_input(event):
	if event is InputEventKey and event.pressed:
		match event.keycode:
			KEY_UP, KEY_W:
				cursor = (cursor - 1 + menu_items.size()) % menu_items.size()
				_update_cursor()
				SFX.menu_move(get_tree())
			KEY_DOWN, KEY_S:
				cursor = (cursor + 1) % menu_items.size()
				_update_cursor()
				SFX.menu_move(get_tree())
			KEY_ENTER, KEY_KP_ENTER, KEY_Z:
				SFX.menu_select(get_tree())
				_activate()

func _update_cursor():
	cursor_label.position.y = 200 + cursor * 28
	for i in range(menu_labels.size()):
		menu_labels[i].add_theme_color_override("font_color",
			Color(1, 0.6, 0) if i == cursor else Color(0.7, 0.7, 0.7))

func _activate():
	match cursor:
		0:  # Start Game
			GameState.reset()
			get_tree().change_scene_to_file("res://scenes/levels/test_arena.tscn")
		1:  # How to Play
			_show_how_to_play()
		2:  # Quit
			get_tree().quit()

func _show_how_to_play():
	var overlay = ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.9)
	overlay.size = Vector2(640, 360)
	overlay.z_index = 200
	add_child(overlay)

	var controls_text = """CONTROLS

WASD / Arrows    Move
Z                Attack (mash for combos)
  Forward + Z    Lunge (1.3x damage)
  Down + Z       Sweep (wider range)
  Up + Z         Launcher (pop enemy up)
  Jump + Z       Dive (1.5x damage)
X                Special (costs 500 sats)
  Down + X       Heavy special (1000 sats)
  Up + X         Super (5000 sats)
C                Jump
V                Grab (near enemy)
  Z while grab   Strike grabbed enemy
  V while grab   Throw enemy

ITEMS
Walk over to collect. Smash vending machines.
Orange Pill = heal. Cold Storage = invincible.
Whitepaper = screen clear. Full Node = damage up.

[ENTER] BACK"""

	var txt = Label.new()
	txt.text = controls_text
	txt.position = Vector2(120, 20)
	txt.add_theme_font_size_override("font_size", 10)
	txt.add_theme_color_override("font_color", Color(0, 1, 0.4))
	txt.size = Vector2(400, 340)
	txt.z_index = 201
	add_child(txt)

	# Wait for enter to close
	var close_fn = func(event):
		if event is InputEventKey and event.pressed and event.keycode in [KEY_ENTER, KEY_ESCAPE, KEY_Z]:
			overlay.queue_free()
			txt.queue_free()
	set_process_unhandled_input(true)
	overlay.set_meta("close_fn", close_fn)
	# Simple: just remove on next enter
	get_tree().create_timer(0.3).timeout.connect(func():
		var _close = func(ev):
			if ev is InputEventKey and ev.pressed:
				overlay.queue_free()
				txt.queue_free()
		# Override input temporarily
		overlay.gui_input.connect(func(_e): pass)
	)
