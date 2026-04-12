extends Node
class_name SFX

## Synthesized sound effects — no asset files needed.
## Uses AudioStreamGenerator to create retro synth tones on the fly.

static func _play_tone(tree: SceneTree, freq: float, duration: float,
		volume: float = 0.3, wave: String = "square",
		freq_end: float = -1, layer_freq: float = 0):

	if not tree or not tree.root:
		return

	var player = AudioStreamPlayer.new()
	var stream = AudioStreamGenerator.new()
	stream.mix_rate = 22050
	stream.buffer_length = duration + 0.1
	player.stream = stream
	player.volume_db = linear_to_db(volume)
	tree.root.add_child(player)
	player.play()

	var playback = player.get_stream_playback()
	var sample_count = int(stream.mix_rate * duration)
	var f = freq
	var f_end = freq_end if freq_end > 0 else freq

	for i in range(sample_count):
		var t = float(i) / float(sample_count)
		var current_freq = lerp(f, f_end, t)
		var phase = float(i) / stream.mix_rate
		var sample: float

		# Envelope: quick attack, sustain, release
		var env = 1.0
		if t < 0.01:
			env = t / 0.01
		elif t > 0.8:
			env = (1.0 - t) / 0.2

		match wave:
			"square":
				sample = 1.0 if fmod(phase * current_freq, 1.0) < 0.5 else -1.0
			"triangle":
				sample = abs(fmod(phase * current_freq, 1.0) * 4.0 - 2.0) - 1.0
			"sawtooth":
				sample = fmod(phase * current_freq, 1.0) * 2.0 - 1.0
			_:
				sample = sin(phase * current_freq * TAU)

		sample *= env * volume
		playback.push_frame(Vector2(sample, sample))

	# Auto-cleanup
	tree.create_timer(duration + 0.2).timeout.connect(func():
		if is_instance_valid(player):
			player.queue_free()
	)

# ==== GAME SFX ====

static func attack(tree: SceneTree):
	_play_tone(tree, 280, 0.08, 0.15, "square", 180)

static func hit(tree: SceneTree):
	_play_tone(tree, 180, 0.10, 0.25, "square", 90)

static func hit_heavy(tree: SceneTree):
	_play_tone(tree, 120, 0.18, 0.3, "sawtooth", 50)

static func sat_pickup(tree: SceneTree):
	_play_tone(tree, 880, 0.10, 0.22, "triangle", 1320)

static func jump(tree: SceneTree):
	_play_tone(tree, 440, 0.08, 0.12, "square", 660)

static func special(tree: SceneTree):
	_play_tone(tree, 220, 0.22, 0.22, "sawtooth", 880)

static func super_move(tree: SceneTree):
	_play_tone(tree, 110, 0.5, 0.3, "sawtooth", 880)

static func finisher(tree: SceneTree):
	_play_tone(tree, 660, 0.35, 0.3, "square", 220)

static func player_hurt(tree: SceneTree):
	_play_tone(tree, 220, 0.18, 0.25, "sawtooth", 110)

static func enemy_die(tree: SceneTree):
	_play_tone(tree, 220, 0.22, 0.18, "square", 55)

static func gate_lock(tree: SceneTree):
	_play_tone(tree, 165, 0.3, 0.22, "square", 110)

static func no_sats(tree: SceneTree):
	_play_tone(tree, 200, 0.12, 0.18, "square", 100)

static func grab(tree: SceneTree):
	_play_tone(tree, 330, 0.08, 0.15, "square", 220)

static func throw_enemy(tree: SceneTree):
	_play_tone(tree, 260, 0.15, 0.2, "sawtooth", 130)

static func menu_move(tree: SceneTree):
	_play_tone(tree, 520, 0.05, 0.15, "square")

static func menu_select(tree: SceneTree):
	_play_tone(tree, 660, 0.1, 0.2, "square", 990)
