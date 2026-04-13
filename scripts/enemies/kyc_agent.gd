extends Enemy
class_name KYCAgent

## KYC Agent — cheap suit, clipboard, face scanner.
## Walks toward you and tries to scan your face. If scan lands,
## player is stunned briefly ("IDENTITY VERIFIED - FLAGGED").
## Easy to dodge, annoying in groups. They come in swarms.

var scan_range: float = 80.0
var scan_duration: float = 1.2
var scan_cooldown: float = 4.0
var last_scan_at: float = 0.0
var scanning: bool = false
var scan_timer: float = 0.0
var scan_beam: ColorRect = null
var scan_target: Node2D = null

const SCAN_TAUNTS = [
	"SHOW ID",
	"FACE SCAN",
	"COMPLY",
	"PAPERS PLEASE",
	"VERIFICATION REQUIRED",
]

func _ready():
	super._ready()
	speed = 80
	max_hp = int(25 * GameState.enemy_hp_mult())
	hp = max_hp
	damage = 6
	attack_range = 32
	attack_cooldown = 1.0
	drop_sats = 100
	enemy_name = "KYC AGENT"


func _ai(now: float):
	# Spawn delay — idle briefly before chasing
	if now - _spawn_time < 0.4:
		velocity = Vector2.ZERO
		return

	var target = _find_target()
	if not target:
		return

	var dir = target.global_position - global_position
	var dist = dir.length()
	facing = 1 if dir.x > 0 else -1

	# Currently scanning — hold still and track
	if scanning:
		velocity = Vector2.ZERO
		scan_timer -= get_physics_process_delta_time()

		# Update beam visual
		if scan_beam and is_instance_valid(scan_beam):
			var beam_dir = (target.global_position - global_position).normalized()
			scan_beam.global_position = global_position + Vector2(facing * 8, -24)
			scan_beam.size.x = min(dist, scan_range)
			if facing == -1:
				scan_beam.global_position.x = global_position.x - min(dist, scan_range) - 8

		# Check if scan hits player
		var dx = abs(target.global_position.x - global_position.x)
		var dy = abs(target.global_position.y - global_position.y)
		if dx < scan_range and dy < 20:
			# Player is in scan beam — accumulate scan
			if scan_timer <= 0:
				_scan_hit(target)
				scanning = false
				enemy_state = EnemyState.IDLE
				_remove_scan_beam()
		elif scan_timer <= 0:
			# Scan expired without hitting
			scanning = false
			enemy_state = EnemyState.IDLE
			_remove_scan_beam()
		return

	# Normal AI — chase and try to scan
	if dist > attack_range:
		velocity = dir.normalized() * speed
	else:
		velocity = Vector2.ZERO
		# Melee attack at close range
		if now - last_attack_time > attack_cooldown:
			last_attack_time = now
			enemy_state = EnemyState.ATTACK
			if target.has_method("take_hit"):
				var from_dir = 1 if global_position.x < target.global_position.x else -1
				target.take_hit(int(damage * GameState.enemy_dmg_mult()), from_dir)
			# Reset attack state after brief window
			get_tree().create_timer(0.4).timeout.connect(func(): enemy_state = EnemyState.IDLE)

	# Try to initiate scan when in range
	if dist < scan_range and dist > attack_range and now - last_scan_at > scan_cooldown:
		last_scan_at = now
		_start_scan(target)

func _start_scan(target: Node2D):
	scanning = true
	scan_timer = scan_duration
	scan_target = target
	enemy_state = EnemyState.ATTACK
	last_attack_time = Time.get_ticks_msec() / 1000.0

	# Show scan warning
	var warn = Label.new()
	warn.text = SCAN_TAUNTS.pick_random()
	warn.global_position = global_position + Vector2(-30, -70)
	warn.add_theme_font_size_override("font_size", 9)
	warn.add_theme_color_override("font_color", Color(1, 0.2, 0.2))
	warn.z_index = 500
	get_parent().add_child(warn)
	var tween = warn.create_tween()
	tween.tween_property(warn, "modulate:a", 0.0, scan_duration)
	tween.tween_callback(warn.queue_free)

	# Create scan beam visual — double beam for threatening look
	scan_beam = ColorRect.new()
	scan_beam.color = Color(1, 0.15, 0.15, 0.4)
	scan_beam.size = Vector2(scan_range, 8)
	scan_beam.global_position = global_position + Vector2(facing * 8, -24)
	scan_beam.z_index = int(global_position.y) + 2
	get_parent().add_child(scan_beam)

	# Second beam line offset slightly — double scan effect
	var beam2 = ColorRect.new()
	beam2.color = Color(1, 0.3, 0.2, 0.3)
	beam2.size = Vector2(scan_range, 4)
	beam2.position = Vector2(0, -6)
	scan_beam.add_child(beam2)

	# Pulsing beam
	var beam_tween = scan_beam.create_tween().set_loops()
	beam_tween.tween_property(scan_beam, "modulate:a", 0.4, 0.15)
	beam_tween.tween_property(scan_beam, "modulate:a", 1.0, 0.15)

	SFX.gate_lock(get_tree())

func _scan_hit(target: Node2D):
	# Scan lands — stun the player briefly
	if target.has_method("take_hit"):
		target.take_hit(int(3 * GameState.enemy_dmg_mult()), facing)

	# Screen shake on scan hit
	CombatJuice.shake(get_viewport().get_camera_2d(), 5.0, 0.2)

	# Show dramatic "FLAGGED" text on player — larger, bolder
	var flag_lbl = Label.new()
	flag_lbl.text = ">> IDENTITY VERIFIED <<\n!!! FLAGGED !!!"
	flag_lbl.global_position = target.global_position + Vector2(-55, -80)
	flag_lbl.add_theme_font_size_override("font_size", 12)
	flag_lbl.add_theme_color_override("font_color", Color(1, 0.1, 0.1))
	flag_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	flag_lbl.size = Vector2(110, 40)
	flag_lbl.z_index = 500
	get_parent().add_child(flag_lbl)
	# Flash the label before fading
	var tween = flag_lbl.create_tween()
	tween.tween_property(flag_lbl, "modulate:a", 0.3, 0.1)
	tween.tween_property(flag_lbl, "modulate:a", 1.0, 0.1)
	tween.tween_property(flag_lbl, "modulate:a", 0.3, 0.1)
	tween.tween_property(flag_lbl, "modulate:a", 1.0, 0.1)
	tween.tween_property(flag_lbl, "modulate:a", 0.0, 1.0)
	tween.tween_callback(flag_lbl.queue_free)

	# Screen flash red
	CombatJuice.hit_sparks(get_parent(), target.global_position + Vector2(0, -20), Color(1, 0.2, 0.2), 6)
	SFX.hit(get_tree())

func _remove_scan_beam():
	if scan_beam and is_instance_valid(scan_beam):
		scan_beam.queue_free()
		scan_beam = null

func take_hit(dmg: int, from_dir: int):
	# Getting hit interrupts scanning
	if scanning:
		scanning = false
		enemy_state = EnemyState.IDLE
		_remove_scan_beam()
	super.take_hit(dmg, from_dir)

func _die():
	_remove_scan_beam()
	# Clipboard snap + papers scatter
	for i in range(4):
		var paper = ColorRect.new()
		paper.color = Color(0.9, 0.9, 0.85)
		paper.size = Vector2(6, 8)
		paper.global_position = global_position + Vector2(randf_range(-10, 10), randf_range(-30, -10))
		paper.z_index = int(global_position.y) + 3
		get_parent().add_child(paper)

		var angle = randf() * TAU
		var dist = randf_range(20, 50)
		var tween = paper.create_tween()
		tween.tween_property(paper, "global_position",
			paper.global_position + Vector2(cos(angle) * dist, sin(angle) * dist + 20), 0.6)
		tween.parallel().tween_property(paper, "rotation", randf_range(-3, 3), 0.6)
		tween.parallel().tween_property(paper, "modulate:a", 0.0, 0.6)
		tween.tween_callback(paper.queue_free)
	super._die()
