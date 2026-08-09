extends Node
## Procedural audio — zero asset files. All sounds synthesized at startup.

var _players: Dictionary = {}   # name -> AudioStreamPlayer

func _ready() -> void:
	_generate("jump",    0.10, 600.0,  900.0,  0.4, "sine")
	_generate("land",    0.06, 200.0,  80.0,   0.3, "noise")
	_generate("die",     0.30, 400.0,  60.0,   0.6, "square")
	_generate("goal",    0.25, 523.0,  1047.0, 0.5, "sine")
	_generate("cheat",   0.08, 180.0,  40.0,   0.15, "noise")
	_generate("text",    0.03, 800.0,  800.0,  0.12, "sine")
	_generate("menu",    0.08, 660.0,  880.0,  0.3, "sine")
	_generate("tick",    0.02, 1200.0, 1200.0, 0.1, "sine")
	_generate("whoosh",  0.20, 300.0,  80.0,   0.25, "noise")

func play(sound_name: String, pitch_shift: float = 1.0) -> void:
	if sound_name in _players:
		var p: AudioStreamPlayer = _players[sound_name]
		p.pitch_scale = pitch_shift
		p.play()

func _generate(snd_name: String, duration: float, freq_start: float,
		freq_end: float, volume: float, wave: String) -> void:
	var rate := 22050
	var samples := int(duration * rate)
	var data := PackedByteArray()
	data.resize(samples * 2)

	for i in samples:
		var t := float(i) / rate
		var progress := float(i) / samples
		var freq := lerpf(freq_start, freq_end, progress)
		var phase := t * freq * TAU
		var sample_f: float

		match wave:
			"sine":
				sample_f = sin(phase)
			"square":
				sample_f = 1.0 if fmod(phase, TAU) < PI else -1.0
			"noise":
				sample_f = randf_range(-1.0, 1.0)
			_:
				sample_f = sin(phase)

		# Envelope: attack 5%, sustain 50%, release 45%
		var env: float
		if progress < 0.05:
			env = progress / 0.05
		elif progress < 0.55:
			env = 1.0
		else:
			env = 1.0 - (progress - 0.55) / 0.45

		var val := int(sample_f * env * volume * 32000.0)
		val = clampi(val, -32768, 32767)
		var idx := i * 2
		data[idx] = val & 0xFF
		data[idx + 1] = (val >> 8) & 0xFF

	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = data

	var player := AudioStreamPlayer.new()
	player.stream = stream
	player.bus = "Master"
	add_child(player)
	_players[snd_name] = player
