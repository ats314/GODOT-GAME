extends CanvasLayer
## In-run HUD. Everything hangs off one full-rect Control so anchors work
## (Controls parented directly to a CanvasLayer have no parent rect —
## review finding: pips/banner were rendering off-screen).

var mass_label: Label
var level_bar: ProgressBar
var wave_label: Label
var hp_row: HBoxContainer
var best_label: Label
var build_box: VBoxContainer
var toast_box: VBoxContainer
var toast_title: Label
var toast_detail: Label
var _toast_tween: Tween

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
	var hp_col := VBoxContainer.new()
	hp_col.add_theme_constant_override(&"separation", 4)
	bottom.add_child(hp_col)
	# named so the "Integrity" number on the Thicker Plating card points at
	# something the player can find on screen
	var hp_caption := _label(15, Color(0.5, 0.66, 0.74))
	hp_caption.text = "INTEGRITY"
	hp_col.add_child(hp_caption)
	hp_row = HBoxContainer.new()
	hp_row.add_theme_constant_override(&"separation", 8)
	hp_col.add_child(hp_row)

	# --- what you've picked so far, so upgrades don't vanish once the card closes
	var right := VBoxContainer.new()
	right.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	right.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	right.offset_left = -320
	right.offset_right = -28
	right.offset_top = 20
	right.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_theme_constant_override(&"separation", 4)
	root.add_child(right)
	var build_caption := _label(15, Color(0.5, 0.66, 0.74))
	build_caption.text = "YOUR BUILD"
	build_caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	right.add_child(build_caption)
	build_box = VBoxContainer.new()
	build_box.add_theme_constant_override(&"separation", 2)
	build_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	right.add_child(build_box)

	# --- confirmation of the pick that just landed, in the card's own numbers
	var toast_anchor := CenterContainer.new()
	toast_anchor.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	toast_anchor.offset_top = -156
	toast_anchor.offset_bottom = -76
	toast_anchor.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(toast_anchor)
	toast_box = VBoxContainer.new()
	toast_box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	toast_box.add_theme_constant_override(&"separation", 2)
	toast_box.modulate.a = 0.0
	toast_anchor.add_child(toast_box)
	toast_title = _label(28, Color(1, 1, 1))
	toast_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(toast_title)
	toast_detail = _label(20, Color(0.72, 0.84, 0.9))
	toast_detail.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_box.add_child(toast_detail)

	Events.mass_changed.connect(func(_m: float, _d: float) -> void: _refresh())
	Events.ring_level_up.connect(func(_l: int) -> void: _refresh())
	Events.core_damaged.connect(func(_hp: int, _max: int) -> void: _refresh_hp())
	Events.core_healed.connect(func(_hp: int, _max: int) -> void: _refresh_hp())
	Events.wave_started.connect(_on_wave)
	Events.upgrade_chosen.connect(_on_upgrade_chosen)
	_refresh()
	_refresh_hp()
	_refresh_build()

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

func _on_upgrade_chosen(id: StringName) -> void:
	_refresh()
	_refresh_hp()
	_refresh_build()
	_show_toast(id)

func _refresh_build() -> void:
	for c in build_box.get_children():
		# detach before freeing: queue_free() alone leaves the old rows in the
		# container for a frame, which shows the list doubled
		build_box.remove_child(c)
		c.queue_free()
	for row in GameState.build_summary():
		var color: Color = Upgrades.CATEGORIES[row.cat].color
		var l := _label(18, color)
		l.text = row.title if row.count == 1 else "%s ×%d" % [row.title, row.count]
		l.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		build_box.add_child(l)

## Echo the card's own before/after back on screen, so the pick visibly does
## something even when the effect itself is off-screen or subtle.
func _show_toast(id: StringName) -> void:
	var upgrade := Upgrades.by_id(id)
	if upgrade.is_empty():
		return
	toast_title.text = upgrade.title
	toast_title.add_theme_color_override(&"font_color", Upgrades.CATEGORIES[upgrade.cat].color)
	toast_detail.text = Upgrades.change_line(GameState.last_change)
	if _toast_tween != null and _toast_tween.is_valid():
		_toast_tween.kill()
	toast_box.modulate.a = 0.0
	_toast_tween = create_tween()
	_toast_tween.tween_property(toast_box, ^"modulate:a", 1.0, 0.15)
	_toast_tween.tween_interval(2.0)
	_toast_tween.tween_property(toast_box, ^"modulate:a", 0.0, 0.7)

func _on_wave(wave: int) -> void:
	wave_label.text = "SURGE  •  wave %d" % wave if wave % 5 == 0 else "wave %d" % wave
	var tw := create_tween()
	tw.tween_property(wave_label, ^"modulate:a", 1.0, 0.2)
	tw.tween_interval(1.2)
	tw.tween_property(wave_label, ^"modulate:a", 0.0, 0.6)
