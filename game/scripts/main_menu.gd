extends Control
## Title screen. Menu lives in a CenterContainer (the previous raw-VBox
## anchoring collapsed to a zero-size rect — review finding).

var _t := 0.0
var _preview: Node2D
var _stars: Node2D

func _ready() -> void:
	_stars = Node2D.new()
	_stars.z_index = -2
	_stars.draw.connect(_draw_stars)
	add_child(_stars)

	_preview = Node2D.new()
	_preview.z_index = -1
	_preview.draw.connect(_draw_preview)
	add_child(_preview)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 22)
	center.add_child(box)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 170)
	box.add_child(spacer)

	var title := Label.new()
	title.text = "A C C R E T E"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 110)
	title.add_theme_color_override(&"font_color", Color(0.72, 0.97, 1.0))
	title.add_theme_color_override(&"font_outline_color", Color(0.1, 0.45, 0.6, 0.9))
	title.add_theme_constant_override(&"outline_size", 16)
	box.add_child(title)

	var tag := Label.new()
	tag.text = "everything you destroy becomes part of your star"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override(&"font_size", 24)
	tag.add_theme_color_override(&"font_color", Color(0.52, 0.7, 0.78))
	box.add_child(tag)

	if GameState.best_mass > 0.0:
		var best := Label.new()
		best.text = "best run: %s mass  •  wave %d" % [
				GameState.fmt(GameState.best_mass), GameState.best_wave]
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_font_size_override(&"font_size", 20)
		best.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.5))
		box.add_child(best)

	var play := Button.new()
	play.text = "  IGNITE  "
	play.add_theme_font_size_override(&"font_size", 36)
	play.pressed.connect(func() -> void:
		Sfx.play(&"ui", 1.3)
		get_tree().change_scene_to_file("res://scenes/run.tscn"))
	box.add_child(play)

	var quit := Button.new()
	quit.text = "quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	play.grab_focus()

func _process(delta: float) -> void:
	_t += delta
	var vp := get_viewport_rect().size
	_preview.position = Vector2(vp.x / 2.0, vp.y * 0.24)
	_stars.position = vp / 2.0
	_preview.queue_redraw()

func _draw_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 3
	for i in 320:
		var p := Vector2(rng.randf_range(-1300, 1300), rng.randf_range(-800, 800))
		var b := rng.randf_range(0.2, 0.85)
		_stars.draw_circle(p, rng.randf_range(0.8, 2.2) * 2.0, Color(b, b, b, 0.10))
		_stars.draw_circle(p, rng.randf_range(0.8, 2.2), Color(b, b, minf(b * 1.15, 1.0), 0.9))

func _draw_preview() -> void:
	var breathe := 1.0 + sin(_t * 2.0) * 0.05
	for i in 5:
		var f := 1.0 - float(i) / 5.0
		_preview.draw_circle(Vector2.ZERO, 120 * breathe * (1.0 - 0.6 * f), Color(0.25, 0.7, 0.9, 0.10 * f * 3.0))
	for i in 3:
		_preview.draw_arc(Vector2.ZERO, (64 + i * 24) * breathe, 0, TAU, 56,
				Color(0.35, 0.85, 1.0, 0.5 - i * 0.12), 3.0, true)
	for m in 5:
		var ang := _t * (0.4 + m * 0.1) + TAU * m / 5.0
		_preview.draw_circle(Vector2.from_angle(ang) * (64 + (m % 3) * 24) * breathe, 4.0,
				Color(0.7, 1.0, 1.0, 0.6))
	_preview.draw_circle(Vector2.ZERO, 34 * breathe, Color(0.55, 1.0, 1.0))
	_preview.draw_circle(Vector2.ZERO, 17 * breathe, Color(1.0, 1.0, 1.0))
