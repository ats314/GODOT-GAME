class_name Spawner
extends Node
## Wave director: timer-driven edge spawning that escalates, with periodic
## surge waves (a ring of critters all at once).

const SPAWN_DISTANCE := 1250.0

var core: Core
var shard_field: ShardField
var enemies_parent: Node2D
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
			_surge(8 + GameState.wave)
		else:
			_batch(2 + GameState.wave / 2)
	if _trickle_timer <= 0.0:
		_trickle_timer = maxf(0.55, 2.4 - GameState.wave * 0.1)
		_spawn_at(randf() * TAU)

func _batch(n: int) -> void:
	var base := randf() * TAU
	for i in n:
		_spawn_at(base + randf_range(-0.7, 0.7))

func _surge(n: int) -> void:
	for i in n:
		_spawn_at(TAU * i / n)

func _spawn_at(angle: float) -> void:
	var e := Enemy.make(core, shard_field, GameState.wave)
	e.global_position = core.global_position + Vector2.from_angle(angle) * SPAWN_DISTANCE
	enemies_parent.add_child(e)
