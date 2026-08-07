class_name Enemy
extends Node2D
## A chaser critter: a glowing polygon that drifts toward the core and dies
## into shards. No physics bodies — movement and hits are pure math.

var radius := 14.0
var speed := 90.0
var hp := 20.0
var max_hp := 20.0
var sides := 3
var hue := Color(1.4, 0.5, 0.45)
var core: Core
var shard_field: ShardField
var _flash := 0.0
var _spin := 0.0

static func make(p_core: Core, p_shards: ShardField, wave: int) -> Enemy:
	var e := Enemy.new()
	e.core = p_core
	e.shard_field = p_shards
	var toughness := 1.0 + wave * 0.22
	e.hp = 20.0 * toughness
	e.max_hp = e.hp
	e.speed = randf_range(70.0, 110.0) + wave * 2.0
	if wave >= 4 and randf() < 0.25:
		e.sides = 4  # tank: slower, bigger, tougher
		e.radius = 22.0
		e.speed *= 0.6
		e.hp *= 2.6
		e.max_hp = e.hp
		e.hue = Color(1.5, 0.9, 0.3)
	return e

func _ready() -> void:
	add_to_group(&"enemies")
	_spin = randf() * TAU

func _process(delta: float) -> void:
	if core == null or not is_instance_valid(core):
		return
	var to_core := core.global_position - global_position
	global_position += to_core.normalized() * speed * delta
	_spin += delta * (2.0 if sides == 3 else 0.7)
	_flash = maxf(0.0, _flash - delta * 8.0)
	if to_core.length() < core.ring_radius() + radius:
		core.take_hit()
		_die(false)
		return
	queue_redraw()

func take_damage(amount: float) -> void:
	hp -= amount
	_flash = 1.0
	if hp <= 0.0:
		_die(true)

func _die(drop_shards: bool) -> void:
	if drop_shards and shard_field != null:
		var burst: int = (4 if sides == 3 else 9) + GameState.mods.shard_bounty
		shard_field.spawn_burst(global_position, burst)
	Sfx.play(&"pop", randf_range(0.85, 1.25), -4.0)
	Events.enemy_killed.emit(global_position)
	queue_free()

func _draw() -> void:
	var pts := PackedVector2Array()
	for i in sides:
		pts.append(Vector2.from_angle(_spin + TAU * i / sides) * radius)
	var hurt := hp / max_hp
	var c := hue.lerp(Color(2.0, 2.0, 2.0), _flash)
	c.a = 0.9
	draw_colored_polygon(pts, Color(c.r * 0.25, c.g * 0.25, c.b * 0.25, 0.85))
	var outline := pts.duplicate()
	outline.append(pts[0])
	draw_polyline(outline, c, 2.5, true)
	if hurt < 0.999:
		draw_arc(Vector2.ZERO, radius + 5.0, -PI / 2, -PI / 2 + TAU * hurt, 24,
				Color(0.5, 1.4, 1.5, 0.55), 2.0, true)
