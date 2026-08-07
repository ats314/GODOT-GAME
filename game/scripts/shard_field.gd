class_name ShardField
extends Node2D
## Batched mass-shard simulation: plain arrays + a single _draw() pass.
## Shards always drift home eventually (gentle pull outside the magnet
## radius) so mass is never stranded off in the dark.

const SHARD_VALUE := 1.0
const MAGNET_ACCEL := 2600.0
const DRIFT_PULL := 260.0
const ABSORB_RADIUS := 40.0

var _pos: PackedVector2Array = []
var _vel: PackedVector2Array = []
var _age: PackedFloat32Array = []
var core: Core

func spawn_burst(at: Vector2, count: int) -> void:
	for i in count:
		_pos.append(at)
		_vel.append(Vector2.from_angle(randf() * TAU) * randf_range(120.0, 340.0))
		_age.append(0.0)

func count() -> int:
	return _pos.size()

func _process(delta: float) -> void:
	if core == null:
		return
	var absorbed := 0
	var i := 0
	while i < _pos.size():
		_age[i] += delta
		var to_core := core.global_position - _pos[i]
		var dist := to_core.length()
		if _age[i] > 0.25 and dist < GameState.mods.magnet_radius:
			_vel[i] = _vel[i].lerp(to_core.normalized() * (MAGNET_ACCEL * 0.35 + dist * 2.0), delta * 6.0)
		elif _age[i] > 0.9:
			# gentle homeward drift so distant shards are never lost
			_vel[i] = _vel[i].lerp(to_core.normalized() * DRIFT_PULL, delta * 1.5)
		else:
			_vel[i] *= pow(0.15, delta)
		_pos[i] += _vel[i] * delta
		if dist < ABSORB_RADIUS + core.ring_radius() * 0.3:
			absorbed += 1
			_pos.remove_at(i)
			_vel.remove_at(i)
			_age.remove_at(i)
		else:
			i += 1
	if absorbed > 0:
		GameState.add_mass(SHARD_VALUE * absorbed)
		for j in mini(absorbed, 4):
			Sfx.play_pickup()
	queue_redraw()

func _draw() -> void:
	for i in _pos.size():
		var p := to_local(_pos[i])
		var flicker := 0.8 + 0.4 * sin(_age[i] * 9.0 + float(i))
		# velocity streak
		var v := _vel[i]
		if v.length_squared() > 400.0:
			var tail := p - v.normalized() * clampf(v.length() * 0.06, 6.0, 26.0)
			draw_line(tail, p, Color(0.35, 0.9, 1.0, 0.35), 2.0)
		# painted glow dot
		draw_circle(p, 7.0, Color(0.25, 0.7, 0.85, 0.18 * flicker))
		draw_circle(p, 4.2, Color(0.4 * flicker, 0.95 * flicker, 1.0 * flicker, 0.85))
		draw_circle(p, 1.9, Color(1.0, 1.0, 1.0))
