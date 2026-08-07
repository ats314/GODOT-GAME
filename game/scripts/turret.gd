class_name Turret
extends Node2D
## Auto-firing hardpoint crystallized onto the accretion ring. Zaps the
## nearest enemy in range; the tracer is drawn and fades over a few frames.

const RANGE := 520.0

var slot_index := 0
var core: Core
var _cooldown := 0.0
var _tracer_to := Vector2.ZERO
var _tracer_life := 0.0

func _process(delta: float) -> void:
	if core == null:
		return
	var angle := TAU * slot_index / maxi(1, GameState.mods.turret_count) - PI / 2
	global_position = core.global_position + Vector2.from_angle(angle) * core.ring_radius()
	_cooldown -= delta
	_tracer_life = maxf(0.0, _tracer_life - delta * 5.0)
	if _cooldown <= 0.0:
		var target := _nearest_enemy()
		if target != null:
			_cooldown = GameState.mods.turret_rate
			_tracer_to = target.global_position
			_tracer_life = 1.0
			target.take_damage(GameState.mods.turret_power)
			Sfx.play(&"zap", randf_range(0.9, 1.15), -9.0)
	queue_redraw()

func _nearest_enemy() -> Enemy:
	var best: Enemy = null
	var best_d := RANGE
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var d: float = (e as Node2D).global_position.distance_to(global_position)
		if d < best_d:
			best_d = d
			best = e
	return best

func _draw() -> void:
	if _tracer_life > 0.0:
		var a := _tracer_life
		draw_line(Vector2.ZERO, to_local(_tracer_to), Color(1.6, 1.3, 0.5, a * 0.8), 3.0)
		draw_line(Vector2.ZERO, to_local(_tracer_to), Color(2.2, 2.2, 1.8, a), 1.2)
	var pts := PackedVector2Array([Vector2(0, -12), Vector2(9, 0), Vector2(0, 12), Vector2(-9, 0)])
	draw_circle(Vector2.ZERO, 20.0, Color(1.0, 0.85, 0.35, 0.12))
	draw_colored_polygon(pts, Color(0.55, 0.5, 0.18, 0.95))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(1.0, 0.9, 0.45), 2.5, true)
	draw_circle(Vector2.ZERO, 3.5, Color(1.0, 1.0, 0.85))
