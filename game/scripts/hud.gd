extends CanvasLayer
## In-run HUD. Everything hangs off one full-rect Control so anchors work
## (Controls parented directly to a CanvasLayer have no parent rect —
## review finding: pips/banner were rendering off-screen).

var mass_label: Label
var level_bar: ProgressBar
var wave_label: Label
var hp_row: HBoxContainer
var best_label: Label

func _ready() -> void:
	layer = 10
	var root := Control.new()
	root.set_anchors_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	var top := VBoxContainer.new()
	top.set_anchors_preset(Control.PRESET_TOP_LEFT)
	top.position = Vector2(28, 20)
	top.add_theme_constant_override(&"separation", 6)
	root.add_child(top)

	mass_label = _label(52, Color(0.78, 0.98, 1.0))
	top.add_child(mass_label)

	level_bar = ProgressBar.new()
	level_bar.custom_minimum_size = Vector2(360, 12)
	level_bar.show_percentage = false
	level_bar.max_value = 1.0
	top.add_child(level_bar)

	best_label = _label(17, Color(0.5, 0.66, 0.74))
	top.add_child(best_label)

	var wave_anchor := CenterContainer.new()
	wave_anchor.set_anchors_preset(Control.PRESET_CENTER_TOP)
	wave_anchor.anchor_left = 0.0
	wave_anchor.anchor_right = 1.0
	wave_anchor.offset_top = 70
	wave_anchor.offset_bottom = 130
	wave_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(wave_anchor)
	wave_label = _label(30, Color(1.0, 0.85, 0.5))
	wave_label.modulate.a = 0.0
	wave_anchor.add_child(wave_label)

	var bottom := MarginContainer.new()
	bottom.set_anchors_preset(Control.PRESET_BOTTOM_LEFT)
	bottom.anchor_top = 1.0
	bottom.offset_left = 28
	bottom.offset_top = -60
	bottom.offset_bottom = -22
	root.add_child(bottom)
	hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override(&"separation", 8)
	bottom.add_child(hp_row)

	Events.mass_changed.connect(func(_m: float, _d: float) -> void: _refresh())
	Events.ring_level_up.connect(func(_l: int) -> void: _refresh())
	Events.core_damaged.connect(func(_hp: int, _max: int) -> void: _refresh_hp())
	Events.wave_started.connect(_on_wave)
	Events.upgrade_chosen.connect(func(_id: StringName) -> void:
		_refresh()
		_refresh_hp())
	_refresh()
	_refresh_hp()

func _label(size: int, color: Color) -> Label:
	var l := Label.new()
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	l.add_theme_color_override(&"font_outline_color", Color(0.0, 0.05, 0.1, 0.85))
	l.add_theme_constant_override(&"outline_size", 8)
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
		pip.custom_minimum_size = Vector2(30, 14)
		pip.color = Color(0.4, 1.0, 1.0) if i < hp else Color(0.14, 0.2, 0.26)
		hp_row.add_child(pip)

func _on_wave(wave: int) -> void:
	wave_label.text = "SURGE  •  wave %d" % wave if wave % 5 == 0 else "wave %d" % wave
	var tw := create_tween()
	tw.tween_property(wave_label, ^"modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(wave_label, ^"modulate:a", 0.0, 0.6)
