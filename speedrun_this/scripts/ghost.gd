class_name Ghost
extends Node2D
## The ghost replay — a translucent "perfect run" that shows the level
## is trivially easy. Plays BEFORE the player gets control. No cheats.

var _path: Array = []        # [{t: float, pos: Vector2}, ...]
var _elapsed: float = 0.0
var _playing: bool = false
var _finished: bool = false
var _current_pos: Vector2

const COLOR := Color(0.29, 0.87, 0.50, 0.25)
const SIZE := Vector2(28, 44)
const LABEL_COLOR := Color(1, 1, 1, 0.4)

func load_path(path: Array) -> void:
	_path = path
	_elapsed = 0.0
	_playing = false
	_finished = false
	if _path.size() > 0:
		_current_pos = _path[0].pos
		global_position = _current_pos
	visible = false

func start() -> void:
	if _path.is_empty():
		_finish()
		return
	_playing = true
	_finished = false
	_elapsed = 0.0
	visible = true
	Events.ghost_started.emit()

func _finish() -> void:
	_playing = false
	_finished = true
	visible = false
	Events.ghost_finished.emit()

func is_done() -> bool:
	return _finished

func _process(delta: float) -> void:
	if not _playing:
		return
	_elapsed += delta

	# Find position along path
	if _path.is_empty():
		_finish()
		return

	var last_entry: Dictionary = _path[-1]
	if _elapsed >= last_entry.t:
		_current_pos = last_entry.pos
		_finish()
		return

	# Interpolate between surrounding keyframes
	var a_idx := 0
	for i in _path.size() - 1:
		if _path[i + 1].t >= _elapsed:
			a_idx = i
			break

	var a: Dictionary = _path[a_idx]
	var b: Dictionary = _path[min(a_idx + 1, _path.size() - 1)]
	var seg_t := 0.0
	if b.t > a.t:
		seg_t = (_elapsed - a.t) / (b.t - a.t)
	_current_pos = (a.pos as Vector2).lerp(b.pos, seg_t)
	global_position = _current_pos
	queue_redraw()

func _draw() -> void:
	if not _playing:
		return
	# Ghost body
	draw_rect(Rect2(-SIZE.x * 0.5, -SIZE.y, SIZE.x, SIZE.y), COLOR)
	# "GHOST" label
	draw_string(
		ThemeDB.fallback_font, Vector2(-20, -SIZE.y - 8),
		"GHOST", HORIZONTAL_ALIGNMENT_LEFT, -1, 10, LABEL_COLOR
	)
