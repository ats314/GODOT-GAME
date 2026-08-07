class_name Spawner
extends Node
## Wave director: timer-driven edge spawning that escalates, with periodic
## surge waves. Spawn distance tracks the camera so enemies appear just
## beyond the visible edge instead of a fixed far ring (review finding).

var core: Core
var shard_field: ShardField
var enemies_parent: Node2D
var camera: Camera2D
var _wave_timer := 0.0
var _trickle_timer := 0.0

func _process(delta: float) -> void:
	_wave_timer -= delta
	_trickle_timer -= delta
	GameState.run_time += delta
	if _wave_timer <= 0.0:
		GameState.wave += 1
		Events.wave_started.emit(GameState.wave)
		_wave_timer = maxf(9.0, 16.0 - GameState.wave * 0.4)
		if GameState.wave % 5 == 0:
			_surge(4 + GameState.wave)
		else:
			_batch(2 + GameState.wave / 2)
	if _trickle_timer <= 0.0:
		_trickle_timer = maxf(0.55, 2.4 - GameState.wave * 0.1)
		_spawn_at(randf() * TAU)

func _spawn_distance() -> float:
	# just beyond the visible half-diagonal at the current zoom
	var half := get_viewport().get_visible_rect().size * 0.5
	var zoom_x: float = camera.zoom.x if camera != null else 1.0
	return (half / maxf(zoom_x, 0.05)).length() + 110.0

func _batch(n: int) -> void:
	var base := randf() * TAU
	for i in n:
		_spawn_at(base + randf_range(-0.7, 0.7))

func _surge(n: int) -> void:
	for i in n:
		_spawn_at(TAU * i / n)

func _spawn_at(angle: float) -> void:
	var e := Enemy.make(core, shard_field, GameState.wave)
	e.global_position = core.global_position + Vector2.from_angle(angle) * _spawn_distance()
	enemies_parent.add_child(e)
