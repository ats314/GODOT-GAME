extends CanvasLayer
## End-of-run screen: stats, new-best callout, instant restart.

func _ready() -> void:
	layer = 30
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

func show_stats() -> void:
	var dim := ColorRect.new()
	dim.color = Color(0.03, 0.0, 0.02, 0.82)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 18)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	center.add_child(box)

	var title := Label.new()
	title.text = "CORE BREACH"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override(&"font_size", 64)
	title.add_theme_color_override(&"font_color", Color(1.0, 0.45, 0.4))
	box.add_child(title)

	var is_best := GameState.total_mass >= GameState.best_mass and GameState.total_mass > 0.0
	var stats := Label.new()
	stats.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	stats.add_theme_font_size_override(&"font_size", 26)
	stats.text = "%s mass accreted%s\nring level %d   •   wave %d   •   %d:%02d" % [
		GameState.fmt(GameState.total_mass),
		"   —  NEW BEST" if is_best else "",
		GameState.ring_level, GameState.wave,
		int(GameState.run_time) / 60, int(GameState.run_time) % 60,
	]
	box.add_child(stats)

	var restart := Button.new()
	restart.text = "  RE-IGNITE  (R)  "
	restart.add_theme_font_size_override(&"font_size", 28)
	restart.pressed.connect(_restart)
	box.add_child(restart)

	var menu := Button.new()
	menu.text = "back to menu"
	menu.pressed.connect(func() -> void:
		get_tree().paused = false
		get_tree().change_scene_to_file("res://scenes/main_menu.tscn"))
	box.add_child(menu)

	visible = true
	restart.grab_focus()

func _input(event: InputEvent) -> void:
	if visible and event.is_action_pressed(&"restart"):
		_restart()

func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
