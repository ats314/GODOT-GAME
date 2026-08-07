class_name Enemy
extends Node2D
## A chaser critter: glowing polygon with a fading motion trail. Halo and
## fill are painted (no HDR dependency). Death is guarded against re-entry.

var radius := 20.0
var speed := 90.0
var hp := 20.0
var max_hp := 20.0
var sides := 3
var hue := Color(1.0, 0.42, 0.34)
var core: Core
var shard_field: ShardField
var _flash := 0.0
var _spin := 0.0
var _dead := false
var _trail: PackedVector2Array = []
var _trail_timer := 0.0

static func make(p_core: Core, p_shards: ShardField, wave: int) -> Enemy:
	var e := Enemy.new()
	e.core = p_core
	e.shard_field = p_shards
	var toughness := 1.0 + wave * 0.13
	e.hp = 20.0 * toughness
	e.max_hp = e.hp
	e.speed = randf_range(70.0, 110.0) + wave * 1.2
	if wave >= 4 and randf() < 0.25:
		e.sides = 4  # tank: slower, bigger, tougher
		e.radius = 30.0
		e.speed *= 0.6
		e.hp *= 2.6
		e.max_hp = e.hp
		e.hue = Color(1.0, 0.72, 0.25)
	return e

func _ready() -> void:
	add_to_group(&"enemies")
	_spin = randf() * TAU

func _process(delta: float) -> void:
	if _dead or core == null or not is_instance_valid(core):
		return
	var to_core := core.global_position - global_position
	global_position += to_core.normalized() * speed * delta
	_spin += delta * (2.0 if sides == 3 else 0.7)
	_flash = maxf(0.0, _flash - delta * 8.0)
	_trail_timer -= delta
	if _trail_timer <= 0.0:
		_trail_timer = 0.045
		_trail.append(global_position)
		if _trail.size() > 8:
			_trail.remove_at(0)
	if to_core.length() < core.ring_radius() + radius:
		core.take_hit()
		_die(false)
		return
	queue_redraw()

func take_damage(amount: float) -> void:
	if _dead:
		return
	hp -= amount
	_flash = 1.0
	if hp <= 0.0:
		_die(true)

func _die(drop_shards: bool) -> void:
	if _dead:
		return
	_dead = true
	if drop_shards and shard_field != null:
		var burst: int = (4 if sides == 3 else 9) + GameState.mods.shard_bounty
		shard_field.spawn_burst(global_position, burst)
		# kill nova: every real kill damages nearby enemies, so dense crowds
		# chain-react instead of overwhelming two single-target weapons
		var nova: float = GameState.mods.nova_power * (1.6 if sides == 4 else 1.0)
		for e in get_tree().get_nodes_in_group(&"enemies"):
			if e == self or e.is_queued_for_deletion():
				continue
			if (e as Node2D).global_position.distance_to(global_position) <= GameState.mods.nova_radius:
				e.call(&"take_damage", nova)
	Sfx.play(&"pop", randf_range(0.85, 1.25), -4.0)
	Events.enemy_killed.emit(global_position)
	queue_free()

func _draw() -> void:
	# fading motion trail
	for i in _trail.size():
		var f := float(i + 1) / (_trail.size() + 1)
		var tp := to_local(_trail[i])
		draw_circle(tp, radius * 0.42 * f, Color(hue.r, hue.g, hue.b, 0.10 * f))

	var pts := PackedVector2Array()
	for i in sides:
		pts.append(Vector2.from_angle(_spin + TAU * i / sides) * radius)
	var c := hue.lerp(Color(1.0, 1.0, 1.0), _flash)

	# painted halo
	draw_circle(Vector2.ZERO, radius * 2.0, Color(c.r, c.g, c.b, 0.10))
	draw_circle(Vector2.ZERO, radius * 1.4, Color(c.r, c.g, c.b, 0.14))
	# body fill + bright rim + hot center
	draw_colored_polygon(pts, Color(c.r * 0.55, c.g * 0.55, c.b * 0.55, 0.95))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, Color(minf(c.r * 1.4, 1.0), minf(c.g * 1.4, 1.0), minf(c.b * 1.4, 1.0)), 3.0, true)
	draw_circle(Vector2.ZERO, radius * 0.28, Color(1.0, 0.95, 0.9, 0.9))

	var hurt := hp / max_hp
	if hurt < 0.999:
		draw_arc(Vector2.ZERO, radius + 7.0, -PI / 2, -PI / 2 + TAU * hurt, 28,
				Color(0.5, 1.0, 1.0, 0.6), 2.5, true)
