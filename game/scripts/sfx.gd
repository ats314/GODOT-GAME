extends Node
## Procedurally synthesized SFX. All sounds are rendered to AudioStreamWAV at
## startup (16-bit PCM) and played through a small pool of players, so the
## game ships with zero audio files.

const RATE := 22050
const POOL := 10

var _players: Array[AudioStreamPlayer] = []
var _streams: Dictionary = {}
var _arpeggio_step: int = 0
var _arpeggio_reset_at: float = 0.0

func _ready() -> void:
	# keep audio alive while the tree is paused (upgrade cards, game over)
	process_mode = Node.PROCESS_MODE_ALWAYS
	for i in POOL:
		var p := AudioStreamPlayer.new()
		p.bus = &"Master"
		add_child(p)
		_players.append(p)
	_streams[&"zap"] = _render(0.05, _gen_zap)
	_streams[&"pop"] = _render(0.09, _gen_pop)
	_streams[&"pickup"] = _render(0.08, _gen_pickup)
	_streams[&"hurt"] = _render(0.25, _gen_hurt)
	_streams[&"ui"] = _render(0.04, _gen_ui)
	_streams[&"levelup"] = _render(0.35, _gen_levelup)

func play(name: StringName, pitch: float = 1.0, volume_db: float = 0.0) -> void:
	if not _streams.has(name):
		return
	for p in _players:
		if not p.playing:
			p.stream = _streams[name]
			p.pitch_scale = pitch
			p.volume_db = volume_db
			p.play()
			return

## Pickup arpeggio: consecutive absorbs climb a pentatonic ladder.
func play_pickup() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now > _arpeggio_reset_at:
		_arpeggio_step = 0
	_arpeggio_reset_at = now + 0.6
	var scale_steps := [0, 2, 4, 7, 9, 12, 14, 16, 19, 21, 24]
	var semis: int = scale_steps[mini(_arpeggio_step, scale_steps.size() - 1)]
	_arpeggio_step += 1
	play(&"pickup", pow(2.0, semis / 12.0), -6.0)

func _render(length: float, gen: Callable) -> AudioStreamWAV:
	var n := int(length * RATE)
	var bytes := PackedByteArray()
	bytes.resize(n * 2)
	for i in n:
		var t := float(i) / RATE
		var v: float = clampf(gen.call(t, length), -1.0, 1.0)
		bytes.encode_s16(i * 2, int(v * 32000.0))
	var wav := AudioStreamWAV.new()
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	wav.mix_rate = RATE
	wav.stereo = false
	wav.data = bytes
	return wav

func _env(t: float, length: float, power: float = 2.0) -> float:
	return pow(1.0 - t / length, power)

func _gen_zap(t: float, l: float) -> float:
	var f := lerpf(1200.0, 240.0, t / l)
	var sq := 1.0 if fmod(t * f, 1.0) < 0.5 else -1.0
	return sq * 0.4 * _env(t, l, 1.5)

func _gen_pop(t: float, l: float) -> float:
	var noise := randf() * 2.0 - 1.0
	var thump := sin(TAU * lerpf(220.0, 60.0, t / l) * t)
	return (noise * 0.35 + thump * 0.6) * _env(t, l)

func _gen_pickup(t: float, l: float) -> float:
	return sin(TAU * 660.0 * t) * 0.5 * _env(t, l, 1.2)

func _gen_hurt(t: float, l: float) -> float:
	var f := 110.0
	var saw := 2.0 * fmod(t * f, 1.0) - 1.0
	var noise := (randf() * 2.0 - 1.0) * 0.3
	return (saw * 0.5 + noise) * _env(t, l, 1.8)

func _gen_ui(t: float, l: float) -> float:
	return sin(TAU * 520.0 * t) * 0.35 * _env(t, l)

func _gen_levelup(t: float, l: float) -> float:
	var steps := [523.25, 659.25, 783.99, 1046.5]
	var idx: int = clampi(int(t / l * steps.size()), 0, steps.size() - 1)
	var seg := fmod(t, l / steps.size()) / (l / steps.size())
	return sin(TAU * steps[idx] * t) * 0.45 * pow(1.0 - seg, 1.2)
