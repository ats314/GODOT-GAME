class_name Core
extends Node2D
## The player star: layered glowing circle, accretion ring strata, and the
## mouse-aimed mining beam. Fully drawn in _draw() — no sprites.

const CORE_RADIUS := 26.0
const STRATA_GAP := 16.0
const IFRAMES := 0.6

var hp: int
var beam_on := false
var beam_end := Vector2.ZERO
var beam_target: Node2D = null
var _aim_dir := Vector2.RIGHT  # persists so controller aim never snaps to zero
var _invuln_until := 0.0
var _pulse := 0.0
var _glow_punch := 0.0

func _ready() -> void:
	add_to_group(&"core_group")
	hp = GameState.mods.max_hp
	Events.ring_level_up.connect(_on_level_up)

func ring_radius() -> float:
	return CORE_RADIUS + STRATA_GAP * (1.0 + GameState.ring_level * 0.35)

func _process(delta: float) -> void:
	_pulse += delta
	_glow_punch = maxf(0.0, _glow_punch - delta * 3.0)
	beam_on = Input.is_action_pressed(&"focus_fire")
	if beam_on:
		_update_beam(delta)
	else:
		beam_target = null
	queue_redraw()

func _update_beam(delta: float) -> void:
	var dir := _aim_dir
	var stick := Input.get_vector(&"aim_left", &"aim_right", &"aim_up", &"aim_down")
	if stick.length() > 0.25:
		dir = stick.normalized()
	elif Input.get_last_mouse_velocity().length() > 2.0:
		var to_mouse := get_global_mouse_position() - global_position
		if to_mouse.length() > 1.0:
			dir = to_mouse.normalized()
	_aim_dir = dir
	var reach := 1400.0
	beam_end = global_position + dir * reach
	beam_target = null
	var best_d := INF
	for e in get_tree().get_nodes_in_group(&"enemies"):
		var enemy := e as Node2D
		var to_e := enemy.global_position - global_position
		var along := to_e.dot(dir)
		if along < 0.0 or along > reach:
			continue
		var off := absf(to_e.cross(dir))
		if off <= GameState.mods.beam_width * 0.5 + enemy.get(&"radius") and along < best_d:
			best_d = along
			beam_target = enemy
	if beam_target != null:
		beam_end = global_position + dir * best_d
		beam_target.call(&"take_damage", GameState.mods.beam_power * delta)

func take_hit() -> void:
	var now := Time.get_ticks_msec() / 1000.0
	if now < _invuln_until:
		return
	_invuln_until = now + IFRAMES
	hp -= 1
	Sfx.play(&"hurt", randf_range(0.95, 1.05), -2.0)
	Events.core_damaged.emit(hp, GameState.mods.max_hp)

func heal_full_segment() -> void:
	hp = mini(hp + 1, GameState.mods.max_hp)
	Events.core_damaged.emit(hp, GameState.mods.max_hp)

func _on_level_up(_level: int) -> void:
	_glow_punch = 1.0

func _draw() -> void:
	var breathe := 1.0 + sin(_pulse * 2.4) * 0.03
	# accretion strata (older = dimmer, cooler)
	for i in GameState.ring_level + 1:
		var r := CORE_RADIUS + STRATA_GAP * (1.0 + i * 0.35)
		var age := float(GameState.ring_level - i)
		var c := Color(0.18, 0.55, 0.75, clampf(0.5 - age * 0.04, 0.08, 0.5))
		draw_arc(Vector2.ZERO, r * breathe, 0.0, TAU, 64, c, 2.5, true)
	# magnet radius hint
	draw_arc(Vector2.ZERO, GameState.mods.magnet_radius, 0.0, TAU, 96,
			Color(0.2, 0.5, 0.6, 0.06), 1.5, true)
	# beam
	if beam_on:
		var local_end := to_local(beam_end)
		var w: float = GameState.mods.beam_width
		var hot := 1.6 + _glow_punch
		draw_line(Vector2.ZERO, local_end, Color(0.25 * hot, 0.9 * hot, 1.1 * hot, 0.35), w * 1.8)
		draw_line(Vector2.ZERO, local_end, Color(0.5 * hot, 1.2 * hot, 1.4 * hot, 0.9), w)
		draw_line(Vector2.ZERO, local_end, Color(2.0, 2.0, 2.0, 0.9), w * 0.3)
		if beam_target != null:
			draw_circle(local_end, w * 0.9, Color(2.2, 2.2, 2.4, 0.8))
	# core body: over-unity colors bloom under HDR-2D glow
	var boost := 1.0 + _glow_punch * 1.2
	draw_circle(Vector2.ZERO, CORE_RADIUS * breathe, Color(0.35 * boost, 1.1 * boost, 1.35 * boost, 0.55))
	draw_circle(Vector2.ZERO, CORE_RADIUS * 0.72 * breathe, Color(0.9 * boost, 1.7 * boost, 1.9 * boost))
	draw_circle(Vector2.ZERO, CORE_RADIUS * 0.4 * breathe, Color(2.5, 2.8, 2.8))
