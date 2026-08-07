extends CanvasLayer
## Ring-level-up card picker. Pauses the tree while open (this layer keeps
## processing), emits Events.upgrade_chosen with the picked id.

var _panel: CenterContainer
var _cards: HBoxContainer
var _title: Label

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.72)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_panel = CenterContainer.new()
	_panel.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 24)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 40)
	_title.add_theme_color_override(&"font_color", Color(0.8, 1.0, 1.0))
	box.add_child(_title)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 20)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_cards)

func show_options(options: Array, level: int) -> void:
	_title.text = "RING LEVEL %d — CHOOSE" % level
	for c in _cards.get_children():
		c.queue_free()
	for opt in options:
		_cards.add_child(_make_card(opt))
	visible = true

func _make_card(opt: Dictionary) -> Button:
	var b := Button.new()
	b.custom_minimum_size = Vector2(260, 150)
	b.text = "%s\n\n%s" % [opt.title, opt.desc]
	b.add_theme_font_size_override(&"font_size", 20)
	b.pressed.connect(func() -> void:
		visible = false
		Sfx.play(&"ui", 1.2)
		GameState.apply_upgrade(opt.id))
	return b
