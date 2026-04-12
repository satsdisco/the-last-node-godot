extends Node
class_name CombatJuice

## Static utility for combat feel effects.
## Call these from Player/Enemy scripts for maximum juice.

## Hit-stop: freeze the entire game for a few frames on impact.
## This is THE secret to making combat feel powerful.
static func hitstop(tree: SceneTree, duration: float = 0.05):
	tree.paused = true
	tree.create_timer(duration, true, false, true).timeout.connect(func():
		tree.paused = false
	)

## Screen shake with decay
static func shake(camera: Camera2D, intensity: float = 4.0, duration: float = 0.1):
	if not camera:
		return
	var orig = camera.offset
	var tween = camera.create_tween()
	var steps = int(duration / 0.02)
	for i in range(steps):
		var offset = Vector2(
			randf_range(-intensity, intensity),
			randf_range(-intensity, intensity)
		)
		intensity *= 0.8  # decay
		tween.tween_property(camera, "offset", offset, 0.02)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.02)

## Spawn hit sparks at a position
static func hit_sparks(parent: Node, pos: Vector2, color: Color = Color(1, 0.6, 0), count: int = 6):
	for i in range(count):
		var spark = ColorRect.new()
		spark.color = color
		spark.size = Vector2(3, 3)
		spark.global_position = pos
		spark.z_index = 200
		parent.add_child(spark)

		var angle = randf() * TAU
		var dist = randf_range(8, 22)
		var tween = spark.create_tween()
		tween.tween_property(spark, "global_position",
			pos + Vector2(cos(angle) * dist, sin(angle) * dist), 0.22)
		tween.parallel().tween_property(spark, "modulate:a", 0.0, 0.22)
		tween.tween_callback(spark.queue_free)

	# White impact flash
	var flash = ColorRect.new()
	flash.color = Color(1, 1, 1, 0.9)
	flash.size = Vector2(8, 8)
	flash.global_position = pos - Vector2(4, 4)
	flash.z_index = 201
	parent.add_child(flash)

	var tween = flash.create_tween()
	tween.tween_property(flash, "scale", Vector2(3, 3), 0.12)
	tween.parallel().tween_property(flash, "modulate:a", 0.0, 0.12)
	tween.tween_callback(flash.queue_free)

## Slash arc visual
static func slash_arc(parent: Node, pos: Vector2, facing: int, range_px: float, color: Color = Color(1, 0.6, 0, 0.8)):
	# Main slash line
	var slash = ColorRect.new()
	slash.color = color
	slash.size = Vector2(range_px, 4)
	slash.global_position = pos + Vector2(facing * range_px * 0.1, 0)
	slash.pivot_offset = Vector2(0, 2)
	slash.rotation = deg_to_rad(-30 * facing)
	slash.z_index = int(pos.y) + 10
	parent.add_child(slash)

	# Trail echo
	var echo = ColorRect.new()
	echo.color = Color(1, 1, 1, 0.4)
	echo.size = Vector2(range_px - 8, 2)
	echo.global_position = pos + Vector2(facing * range_px * 0.15, 4)
	echo.pivot_offset = Vector2(0, 1)
	echo.rotation = deg_to_rad(-30 * facing)
	echo.z_index = int(pos.y) + 10
	parent.add_child(echo)

	var tween = parent.create_tween()
	tween.tween_property(slash, "rotation", deg_to_rad(20.0 * facing), 0.1)
	tween.parallel().tween_property(echo, "rotation", deg_to_rad(20.0 * facing), 0.1)
	tween.parallel().tween_property(slash, "modulate:a", 0.0, 0.12)
	tween.parallel().tween_property(echo, "modulate:a", 0.0, 0.12)
	tween.tween_callback(func():
		slash.queue_free()
		echo.queue_free()
	)

	# Tip flash
	var tip = ColorRect.new()
	tip.color = Color(1, 1, 1, 0.9)
	tip.size = Vector2(6, 6)
	tip.global_position = pos + Vector2(facing * range_px * 0.8, -4)
	tip.z_index = int(pos.y) + 11
	parent.add_child(tip)

	var tip_tween = tip.create_tween()
	tip_tween.tween_property(tip, "modulate:a", 0.0, 0.1)
	tip_tween.tween_callback(tip.queue_free)

## Damage number floating up
static func damage_number(parent: Node, pos: Vector2, amount: int, color: Color = Color(1, 1, 1)):
	var lbl = Label.new()
	lbl.text = str(amount)
	lbl.global_position = pos - Vector2(10, 0)
	lbl.add_theme_font_size_override("font_size", 14)
	lbl.add_theme_color_override("font_color", color)
	lbl.z_index = 300
	parent.add_child(lbl)

	var tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", pos.y - 30, 0.6)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.6)
	tween.tween_callback(lbl.queue_free)

## Sat pickup floating text
static func sat_popup(parent: Node, pos: Vector2, amount: int):
	var lbl = Label.new()
	lbl.text = "+%d SATS" % amount
	lbl.global_position = pos - Vector2(30, 10)
	lbl.add_theme_font_size_override("font_size", 11)
	lbl.add_theme_color_override("font_color", Color(1, 0.8, 0.2))
	lbl.z_index = 300
	parent.add_child(lbl)

	var tween = lbl.create_tween()
	tween.tween_property(lbl, "global_position:y", pos.y - 30, 0.8)
	tween.parallel().tween_property(lbl, "modulate:a", 0.0, 0.8)
	tween.tween_callback(lbl.queue_free)

## Enemy death burst
static func death_burst(parent: Node, pos: Vector2, color: Color = Color(0.3, 0.4, 0.7)):
	for i in range(8):
		var chunk = ColorRect.new()
		chunk.color = color
		chunk.size = Vector2(randf_range(3, 6), randf_range(3, 6))
		chunk.global_position = pos + Vector2(randf_range(-8, 8), randf_range(-20, 0))
		chunk.z_index = 150
		parent.add_child(chunk)

		var angle = randf() * TAU
		var dist = randf_range(15, 40)
		var tween = chunk.create_tween()
		tween.tween_property(chunk, "global_position",
			chunk.global_position + Vector2(cos(angle) * dist, sin(angle) * dist + 15), 0.4)
		tween.parallel().tween_property(chunk, "modulate:a", 0.0, 0.4)
		tween.parallel().tween_property(chunk, "rotation", randf_range(-2, 2), 0.4)
		tween.tween_callback(chunk.queue_free)
