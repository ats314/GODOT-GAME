extends CanvasLayer
## In-run HUD, built in code: mass counter, ring-level progress, wave banner,
## and core integrity pips. Lives on a CanvasLayer so glow never touches it.

var mass_label: Label
var level_bar: ProgressBar
var wave_label: Label
var hp_row: HBoxContainer
var best_label: Label

func _ready() -> void:
	layer = 10
	var root := MarginContainer.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.add_theme_constant_override(&"margin_left", 24)
	root.add_theme_constant_override(&"margin_top", 16)
	root.add_theme_constant_override(&"margin_right", 24)
	root.add_theme_constant_override(&"margin_bottom", 16)
	add_child(root)

	var top := VBoxContainer.new()
	top.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
	root.add_child(top)

	mass_label = _label(44, Color(0.75, 0.97, 1.0))
	top.add_child(mass_label)

	level_bar = ProgressBar.new()
	level_bar.custom_minimum_size = Vector2(340, 10)
	level_bar.show_percentage = false
	level_bar.max_value = 1.0
	top.add_child(level_bar)

	best_label = _label(16, Color(0.45, 0.6, 0.68))
	top.add_child(best_label)

	wave_label = _label(26, Color(1.0, 0.85, 0.5))
	wave_label.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_label.modulate.a = 0.0
	add_child(wave_label)

	hp_row = HBoxContainer.new()
	hp_row.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	hp_row.position = Vector2(24, -48)
	hp_row.grow_vertical = Control.GROW_DIRECTION_BEGIN
	add_child(hp_row)

	Events.mass_changed.connect(func(_m: float, _d: float) -> void: _refresh())
	Events.ring_level_up.connect(func(_l: int) -> void: _refresh())
	Events.core_damaged.connect(func(_hp: int, _max: int) -> void: _refresh_hp())
	Events.wave_started.connect(_on_wave)
	Events.upgrade_chosen.connect(func(_id: StringName) -> void: _refresh_hp())
	_refresh()
	_refresh_hp()

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l

func _refresh() -> void:
	mass_label.text = GameState.fmt(GameState.mass) + " mass"
	level_bar.value = GameState.mass / GameState.next_level_cost()
	best_label.text = "ring level %d   •   best run %s" % [
			GameState.ring_level, GameState.fmt(GameState.best_mass)]

func _refresh_hp() -> void:
	for c in hp_row.get_children():
		c.queue_free()
	var core := get_tree().get_first_node_in_group(&"core_group") as Core
	var hp: int = core.hp if core != null else GameState.mods.max_hp
	for i in GameState.mods.max_hp:
		var pip := ColorRect.new()
		pip.custom_minimum_size = Vector2(26, 12)
		pip.color = Color(0.4, 1.15, 1.3) if i < hp else Color(0.15, 0.2, 0.25)
		hp_row.add_child(pip)

func _on_wave(wave: int) -> void:
	wave_label.text = "SURGE  •  wave %d" % wave if wave % 5 == 0 else "wave %d" % wave
	wave_label.reset_size()
	wave_label.position.x = -wave_label.size.x / 2.0
	wave_label.position.y = 70
	var tw := create_tween()
	tw.tween_property(wave_label, ^"modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(wave_label, ^"modulate:a", 0.0, 0.6)
