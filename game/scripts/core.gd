class_name Core
extends Node2D
## The player star: layered glowing circle, accretion ring strata, and the
## aimed mining beam. All glow is drawn (layered alpha falloff), so the look
## survives renderers without HDR bloom; real bloom stacks on top on desktop.

const CORE_RADIUS := 34.0
const STRATA_GAP := 18.0
const IFRAMES := 0.6

var hp: int
var beam_on := false
var beam_end := Vector2.ZERO
var beam_target: Node2D = null
var _aim_dir := Vector2.RIGHT  # persists so controller aim never snaps to zero
var _mouse_aim := true         # last input source decides how aim updates
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
		_mouse_aim = false
		dir = stick.normalized()
	else:
		if Input.get_last_mouse_velocity().length() > 2.0:
			_mouse_aim = true
		if _mouse_aim:
			# mouse users track the cursor continuously, even when it's still
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
		if not is_instance_valid(enemy) or enemy.is_queued_for_deletion():
			continue
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
	Events.core_healed.emit(hp, GameState.mods.max_hp)

func _on_level_up(_level: int) -> void:
	_glow_punch = 1.0

func _soft_circle(pos: Vector2, r: float, c: Color, steps: int = 4) -> void:
	# painted bloom: stacked translucent discs, brightest in the middle
	for i in steps:
		var f := 1.0 - float(i) / steps
		var col := c
		col.a = c.a * (0.28 + 0.72 * f * f)
		draw_circle(pos, r * (1.0 - 0.62 * f), col)

func _draw() -> void:
	var breathe := 1.0 + sin(_pulse * 2.4) * 0.03
	var boost := 1.0 + _glow_punch * 1.2

	# wide painted halo so the star reads as luminous on every renderer
	_soft_circle(Vector2.ZERO, CORE_RADIUS * 3.2 * breathe, Color(0.25, 0.75, 0.95, 0.10 + _glow_punch * 0.12), 5)

	# accretion strata (older = dimmer); faint fill between strata
	for i in GameState.ring_level + 1:
		var r := CORE_RADIUS + STRATA_GAP * (1.0 + i * 0.35)
		var age := float(GameState.ring_level - i)
		var a := clampf(0.65 - age * 0.05, 0.12, 0.65)
		draw_arc(Vector2.ZERO, r * breathe, 0.0, TAU, 72, Color(0.16, 0.5, 0.68, a * 0.35), 7.0, true)
		draw_arc(Vector2.ZERO, r * breathe, 0.0, TAU, 72, Color(0.45, 0.95, 1.1, a), 3.0, true)

	# orbiting motes on the outer stratum
	var rr := ring_radius() * breathe
	for m in 5:
		var ang := _pulse * (0.5 + m * 0.13) + TAU * m / 5.0
		_soft_circle(Vector2.from_angle(ang) * rr, 6.0, Color(0.7, 1.3, 1.4, 0.5), 3)

	# magnet radius hint
	draw_arc(Vector2.ZERO, GameState.mods.magnet_radius, 0.0, TAU, 96,
			Color(0.3, 0.7, 0.8, 0.05), 2.0, true)

	# beam: painted glow stack + hot white core
	if beam_on:
		var local_end := to_local(beam_end)
		var w: float = GameState.mods.beam_width
		var flick := 1.0 + sin(_pulse * 43.0) * 0.12
		draw_line(Vector2.ZERO, local_end, Color(0.2, 0.65, 0.9, 0.16), w * 4.6 * flick)
		draw_line(Vector2.ZERO, local_end, Color(0.35, 0.95, 1.15, 0.45), w * 2.2)
		draw_line(Vector2.ZERO, local_end, Color(0.75, 1.25, 1.35, 0.9), w * 1.0)
		draw_line(Vector2.ZERO, local_end, Color(1.0, 1.0, 1.0, 0.95), w * 0.42)
		_soft_circle(Vector2.ZERO, w * 1.6, Color(0.8, 1.2, 1.3, 0.8), 3)
		if beam_target != null:
			_soft_circle(local_end, w * 1.7 * flick, Color(1.0, 1.0, 1.0, 0.85), 4)
			for s in 4:
				var sd := Vector2.from_angle(randf() * TAU) * randf_range(8.0, 26.0)
				draw_line(local_end, local_end + sd, Color(0.9, 1.2, 1.3, 0.7), 2.0)

	# core body
	draw_circle(Vector2.ZERO, CORE_RADIUS * breathe, Color(0.30 * boost, 0.85 * boost, 1.0 * boost, 0.75))
	draw_circle(Vector2.ZERO, CORE_RADIUS * 0.74 * breathe, Color(0.55 * boost, 1.0 * boost, 1.0 * boost))
	draw_circle(Vector2.ZERO, CORE_RADIUS * 0.44 * breathe, Color(1.0, 1.0, 1.0))
