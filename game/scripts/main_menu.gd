extends Control
## Title screen: animated core preview + play/quit. Kept deliberately tiny —
## the Maaack shell (options/credits/pause) integrates in Milestone 2.

var _t := 0.0
var _preview: Node2D

func _ready() -> void:
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_theme_constant_override(&"separation", 20)
	add_child(box)

	var title := Label.new()
	title.text = "A C C R E T E"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 96)
	title.add_theme_color_override(&"font_color", Color(0.8, 1.35, 1.5))
	box.add_child(title)

	var tag := Label.new()
	tag.text = "everything you destroy becomes part of your star"
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.add_theme_font_size_override(&"font_size", 22)
	tag.add_theme_color_override(&"font_color", Color(0.5, 0.68, 0.75))
	box.add_child(tag)

	if GameState.best_mass > 0.0:
		var best := Label.new()
		best.text = "best run: %s mass  •  wave %d" % [
				GameState.fmt(GameState.best_mass), GameState.best_wave]
		best.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		best.add_theme_color_override(&"font_color", Color(1.0, 0.85, 0.5))
		box.add_child(best)

	var play := Button.new()
	play.text = "  IGNITE  "
	play.add_theme_font_size_override(&"font_size", 34)
	play.pressed.connect(func() -> void:
		Sfx.play(&"ui", 1.3)
		get_tree().change_scene_to_file("res://scenes/run.tscn"))
	box.add_child(play)

	var quit := Button.new()
	quit.text = "quit"
	quit.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit)

	play.grab_focus()

	_preview = Node2D.new()
	_preview.draw.connect(_draw_preview)
	add_child(_preview)
	_preview.z_index = -1

func _process(delta: float) -> void:
	_t += delta
	_preview.position = get_viewport_rect().size / 2.0 + Vector2(0, -320)
	_preview.queue_redraw()

func _draw_preview() -> void:
	var breathe := 1.0 + sin(_t * 2.0) * 0.05
	for i in 3:
		_preview.draw_arc(Vector2.ZERO, (60 + i * 22) * breathe, 0, TAU, 48,
				Color(0.2, 0.55, 0.7, 0.4 - i * 0.1), 2.0, true)
	_preview.draw_circle(Vector2.ZERO, 30 * breathe, Color(0.9, 1.7, 1.9))
	_preview.draw_circle(Vector2.ZERO, 15 * breathe, Color(2.4, 2.7, 2.7))
