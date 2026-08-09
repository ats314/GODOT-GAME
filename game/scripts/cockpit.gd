extends Control

## The cockpit. Everything the player sees and does.
##
## Drawn entirely in code — no textures, no sprites, no fonts beyond the engine
## fallback. That is not a placeholder: a panel of gauges and warning lights IS
## the art direction, and drawing it directly keeps every pixel under control.
##
## The view deliberately shows consequences, not instructions. The heat gauge
## climbing while you hold a repair is the game telling you what your choice
## cost, and it should be readable in peripheral vision because your attention
## is somewhere else.

const PANEL_NAMES := ["WEAPONS", "COOLANT", "SERVOS"]

const COLOR_BG := Color(0.026, 0.028, 0.035)
const COLOR_PANEL := Color(0.10, 0.108, 0.128)
const COLOR_EDGE := Color(0.26, 0.28, 0.33)
const COLOR_TEXT := Color(0.78, 0.82, 0.88)
const COLOR_TEXT_DIM := Color(0.46, 0.50, 0.57)
const COLOR_AMBER := Color(1.0, 0.68, 0.18)
const COLOR_CYAN := Color(0.35, 0.85, 1.0)
const COLOR_GREEN := Color(0.4, 0.9, 0.55)
const COLOR_RED := Color(1.0, 0.28, 0.25)
const COLOR_SELECT := Color(0.95, 0.95, 1.0)

const SYSTEM_COLORS := [COLOR_AMBER, COLOR_CYAN, COLOR_GREEN]

## How fast holding the stick moves power. Slow enough that a big reallocation
## is a commitment you can be caught halfway through.
const SLEW_RATE := 0.85

var machine: Machine
var fight: Engagement

var _selected := 0
var _shake := 0.0
var _flash := 0.0
var _outcome := ""
var _log: Array[String] = []
var _elapsed := 0.0

@onready var _font: Font = ThemeDB.fallback_font


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	_start_engagement()


func _start_engagement() -> void:
	machine = Machine.new()
	fight = Engagement.new(randi())
	_outcome = ""
	_log.clear()
	_elapsed = 0.0
	_selected = 0
	machine.component_failed.connect(_on_component_failed)
	machine.destroyed.connect(func(reason: String) -> void: _outcome = "LOST — " + reason)
	fight.enemy_destroyed.connect(func() -> void: _outcome = "TARGET DESTROYED")
	fight.shot_hit.connect(
		func(_d: float, _f: int, _s: int) -> void:
			_shake = 1.0
			_flash = 1.0
	)
	fight.shot_missed.connect(func() -> void: _push_log("evaded"))


func _on_component_failed(failure: int, system: int) -> void:
	var names := {
		Machine.Failure.BREAKER_TRIPPED: "breaker tripped",
		Machine.Failure.LINE_RUPTURED: "line ruptured",
		Machine.Failure.FIRE: "FIRE",
		Machine.Failure.REACTOR_SCRAM: "REACTOR SCRAM",
	}
	_push_log("%s — %s" % [PANEL_NAMES[system], names[failure]])


func _push_log(text: String) -> void:
	_log.push_front(text)
	if _log.size() > 5:
		_log.resize(5)


func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 3.0)
	_flash = maxf(0.0, _flash - delta * 2.2)

	if _outcome != "":
		if Input.is_action_just_pressed("restart"):
			_start_engagement()
		queue_redraw()
		return

	_elapsed += delta
	_handle_input(delta)
	machine.step(delta)
	fight.step(delta, machine)
	queue_redraw()


func _handle_input(delta: float) -> void:
	if Input.is_action_just_pressed("select_next"):
		_selected = (_selected + 1) % Machine.SYSTEM_COUNT
	if Input.is_action_just_pressed("select_prev"):
		_selected = (_selected - 1 + Machine.SYSTEM_COUNT) % Machine.SYSTEM_COUNT

	var shift := Input.get_action_strength("power_up") - Input.get_action_strength("power_down")
	if absf(shift) > 0.05:
		machine.adjust(_selected, shift * SLEW_RATE * delta)

	# Repair is a hold, and letting go loses the progress. That is what turns
	# "fix the fire" into a bet against the next incoming shot.
	if Input.is_action_pressed("repair"):
		machine.repair(_selected, delta)
	else:
		machine.cancel_repair()

	if Input.is_action_just_pressed("vent"):
		if machine.vent():
			_push_log("heat vented — weapons cold")


func _draw() -> void:
	var full := size
	var offset := Vector2.ZERO
	if _shake > 0.0:
		offset = Vector2(randf_range(-1.0, 1.0), randf_range(-1.0, 1.0)) * _shake * 7.0
	draw_set_transform(offset)

	draw_rect(Rect2(Vector2.ZERO, full), COLOR_BG)
	if _flash > 0.0:
		draw_rect(Rect2(Vector2.ZERO, full), Color(COLOR_RED, _flash * 0.16))

	var margin := 28.0
	var gap := 16.0

	# Three bands: what is happening to you, what you are choosing, what it cost.
	var slit_height := full.y * 0.24
	var panel_height := full.y * 0.46
	var strip_top := margin + slit_height + gap + panel_height + gap

	_draw_viewport_slit(Rect2(margin, margin, full.x - margin * 2.0, slit_height))

	var panel_top := margin + slit_height + gap
	var panel_width := (full.x - margin * 2.0 - gap * 2.0) / 3.0
	for i in Machine.SYSTEM_COUNT:
		var rect := Rect2(margin + (panel_width + gap) * i, panel_top, panel_width, panel_height)
		_draw_system_panel(rect, i)

	_draw_status_strip(Rect2(margin, strip_top, full.x - margin * 2.0, full.y - strip_top - margin))

	if _outcome != "":
		_draw_outcome(full)


## The world outside, glimpsed. Deliberately minimal: the enemy is a shape and
## a health bar, because looking out of the window is not the game.
func _draw_viewport_slit(rect: Rect2) -> void:
	draw_rect(rect, Color(0.015, 0.02, 0.03))
	draw_rect(rect, COLOR_EDGE, false, 2.0)

	var centre := rect.position + rect.size * 0.5
	var enemy_size: float = 26.0 + 18.0 * fight.enemy_fraction()
	var enemy_colour := COLOR_RED if fight.charging_now else Color(0.55, 0.3, 0.32)
	draw_circle(centre + Vector2(0.0, -6.0), enemy_size, enemy_colour, false, 3.0)
	draw_line(
		centre + Vector2(-enemy_size, 10.0), centre + Vector2(enemy_size, 10.0), enemy_colour, 2.0
	)

	# Enemy integrity, top-left of the slit.
	var bar := Rect2(rect.position + Vector2(14.0, 14.0), Vector2(rect.size.x * 0.32, 8.0))
	draw_rect(bar, Color(0.12, 0.06, 0.06))
	draw_rect(
		Rect2(bar.position, Vector2(bar.size.x * fight.enemy_fraction(), bar.size.y)), COLOR_RED
	)
	draw_string(
		_font,
		bar.position + Vector2(0.0, -6.0),
		"TARGET",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		COLOR_TEXT_DIM
	)

	# The telegraph. This is the most important element on the screen: it is the
	# only warning you get, and reacting to it is the core decision.
	if fight.charging_now:
		var progress := 1.0 - fight.time_to_impact / Balance.telegraph_seconds
		var warn := Rect2(
			rect.position + Vector2(0.0, rect.size.y - 8.0), Vector2(rect.size.x * progress, 8.0)
		)
		draw_rect(warn, COLOR_RED)
		draw_string(
			_font,
			centre + Vector2(-56.0, rect.size.y * 0.5 - 12.0),
			"INCOMING",
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			20,
			COLOR_RED
		)


func _draw_system_panel(rect: Rect2, system: int) -> void:
	var selected := system == _selected
	draw_rect(rect, COLOR_PANEL)
	draw_rect(rect, COLOR_SELECT if selected else COLOR_EDGE, false, 2.0 if selected else 1.0)

	var colour: Color = SYSTEM_COLORS[system]
	var pad := 18.0
	draw_string(
		_font,
		rect.position + Vector2(pad, 28.0),
		PANEL_NAMES[system],
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		19,
		colour if selected else COLOR_TEXT
	)
	if selected:
		draw_rect(Rect2(rect.position + Vector2(pad, 36.0), Vector2(46.0, 2.0)), colour)

	# Allocation is what you asked for; output is what survives the damage. The
	# gap between the two IS the damage, so both are drawn on the same dial.
	var allocation: float = machine.allocation[system]
	var output := machine.system_output(system)

	var dial := rect.position + Vector2(rect.size.x * 0.5, rect.size.y * 0.46)
	var radius: float = minf(rect.size.x, rect.size.y) * 0.29
	var start := PI * 0.75
	var sweep := PI * 1.5

	draw_arc(dial, radius, start, start + sweep, 48, Color(0.05, 0.05, 0.062), 12.0, true)
	draw_arc(dial, radius, start, start + sweep * allocation, 40, Color(colour, 0.22), 12.0, true)
	draw_arc(dial, radius, start, start + sweep * output, 40, colour, 12.0, true)

	# Tick marks make it a gauge rather than a progress bar.
	for tick in 6:
		var angle := start + sweep * (float(tick) / 5.0)
		var dir := Vector2(cos(angle), sin(angle))
		draw_line(dial + dir * (radius + 9.0), dial + dir * (radius + 15.0), COLOR_EDGE, 1.5)

	var needle := start + sweep * output
	draw_line(
		dial, dial + Vector2(cos(needle), sin(needle)) * (radius - 4.0), COLOR_SELECT, 2.0, true
	)
	draw_circle(dial, 4.0, COLOR_SELECT)

	var readout := "%d%%" % int(round(output * 100.0))
	draw_string(
		_font,
		dial + Vector2(-26.0, radius * 0.92),
		readout,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		30,
		colour
	)

	var light_y := rect.position.y + rect.size.y - 44.0
	var light_x := rect.position.x + pad + 10.0
	_draw_light(Vector2(light_x, light_y), "BRK", machine.breaker_tripped[system])
	_draw_light(Vector2(light_x + 62.0, light_y), "LINE", machine.line_ruptured[system])
	_draw_light(Vector2(light_x + 128.0, light_y), "FIRE", machine.fires[system])

	if machine.repairing_system() == system and machine.repair_fraction() > 0.0:
		var track := Rect2(
			rect.position.x + pad,
			rect.position.y + rect.size.y - 20.0,
			rect.size.x - pad * 2.0,
			6.0
		)
		draw_rect(track, Color(0.04, 0.04, 0.05))
		draw_rect(
			Rect2(track.position, Vector2(track.size.x * machine.repair_fraction(), track.size.y)),
			COLOR_SELECT
		)


func _draw_light(centre: Vector2, label: String, active: bool) -> void:
	# Active warnings pulse. A steady light is easy to stop seeing.
	var colour := COLOR_RED if active else Color(0.15, 0.16, 0.19)
	if active:
		colour = colour.lerp(Color.WHITE, 0.35 + 0.35 * sin(_elapsed * 9.0))
	draw_circle(centre, 7.0, colour)
	draw_circle(centre, 7.0, COLOR_EDGE, false, 1.0)
	draw_string(
		_font,
		centre + Vector2(11.0, 5.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		COLOR_TEXT if active else COLOR_TEXT_DIM
	)


func _draw_status_strip(rect: Rect2) -> void:
	var column := rect.size.x * 0.36

	_draw_meter(
		Rect2(rect.position, Vector2(column, 18.0)),
		"HEAT",
		machine.heat / Balance.max_heat,
		COLOR_RED if machine.heat > Balance.max_heat * 0.75 else COLOR_AMBER
	)
	_draw_meter(
		Rect2(rect.position + Vector2(0.0, 34.0), Vector2(column, 18.0)),
		"STRUCTURE",
		machine.structure / Balance.max_structure,
		COLOR_CYAN
	)

	# Middle column: the things that are temporarily true and easy to forget.
	var mid := rect.position + Vector2(column + 48.0, 12.0)
	var vent_ready := machine.vent_cooldown <= 0.0
	draw_string(
		_font,
		mid,
		"VENT  %s" % ("READY" if vent_ready else "%.0fs" % machine.vent_cooldown),
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		COLOR_GREEN if vent_ready else COLOR_TEXT_DIM
	)
	if machine.weapon_lockout > 0.0:
		draw_string(
			_font,
			mid + Vector2(0.0, 22.0),
			"WEAPONS COLD  %.1fs" % machine.weapon_lockout,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			COLOR_RED
		)
	if machine.reactor_scrammed:
		draw_string(
			_font,
			mid + Vector2(0.0, 44.0),
			"REACTOR SCRAMMED — %d%% POWER" % int(machine.power_output() * 100.0),
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			16,
			COLOR_RED
		)

	# Right column: the last few things that went wrong, newest brightest.
	var log_x := rect.position.x + rect.size.x * 0.70
	draw_string(
		_font,
		Vector2(log_x, rect.position.y),
		"FAULT LOG",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		12,
		COLOR_TEXT_DIM
	)
	for i in _log.size():
		draw_string(
			_font,
			Vector2(log_x, rect.position.y + 18.0 + 15.0 * i),
			_log[i],
			HORIZONTAL_ALIGNMENT_LEFT,
			-1,
			13,
			Color(COLOR_TEXT, 0.9 - 0.15 * i)
		)

	draw_string(
		_font,
		Vector2(rect.position.x, rect.position.y + rect.size.y - 2.0),
		"[LB/RB] select   [LT/RT] power   [A] hold to repair   [B] vent   [Y] restart",
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		COLOR_TEXT_DIM
	)


func _draw_meter(rect: Rect2, label: String, fraction: float, colour: Color) -> void:
	draw_string(
		_font,
		rect.position + Vector2(0.0, 12.0),
		label,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		13,
		COLOR_TEXT_DIM
	)
	var bar := Rect2(rect.position + Vector2(96.0, 0.0), Vector2(rect.size.x - 96.0, 16.0))
	draw_rect(bar, Color(0.03, 0.03, 0.04))
	draw_rect(
		Rect2(bar.position, Vector2(bar.size.x * clampf(fraction, 0.0, 1.0), bar.size.y)), colour
	)
	draw_rect(bar, COLOR_EDGE, false, 1.0)


func _draw_outcome(full: Vector2) -> void:
	draw_rect(Rect2(Vector2.ZERO, full), Color(0.0, 0.0, 0.0, 0.62))
	var won := _outcome.begins_with("TARGET")
	draw_string(
		_font,
		full * 0.5 + Vector2(-190.0, -10.0),
		_outcome,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		34,
		COLOR_GREEN if won else COLOR_RED
	)
	draw_string(
		_font,
		full * 0.5 + Vector2(-190.0, 26.0),
		"%.0f seconds   —   [Y] or R to run it again" % _elapsed,
		HORIZONTAL_ALIGNMENT_LEFT,
		-1,
		16,
		COLOR_TEXT
	)
