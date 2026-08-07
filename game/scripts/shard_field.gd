class_name ShardField
extends Node2D
## Batched mass-shard simulation: plain arrays + a single _draw() pass, the
## bullet_shower pattern minus physics (pure math, hundreds of shards cheap).

const SHARD_VALUE := 1.0
const MAGNET_ACCEL := 2600.0
const ABSORB_RADIUS := 30.0

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
		else:
			_vel[i] *= pow(0.15, delta)  # frictional drift
		_pos[i] += _vel[i] * delta
		if dist < ABSORB_RADIUS:
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
		draw_circle(p, 4.0, Color(0.4 * flicker, 1.2 * flicker, 1.3 * flicker, 0.9))
		draw_circle(p, 1.8, Color(1.8, 2.0, 2.0))
