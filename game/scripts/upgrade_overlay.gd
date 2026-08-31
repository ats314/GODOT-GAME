extends CanvasLayer
## Ring-level-up card picker. Pauses the tree while open (this layer keeps
## processing), emits Events.upgrade_chosen with the picked id.
##
## Picking is two steps on purpose (playtest note: "the little description
## isn't enough for me to understand"). The browse view answers which system a
## card touches (icon + colour + tag), what number it moves (a live before »
## after read off your actual stats), and roughly what that means. Pressing a
## card expands it into the full explanation, where a second press takes it and
## BACK returns to the three cards. Nothing is committed until TAKE THIS.

const CARD_SIZE := Vector2(420, 320)
const DETAIL_WIDTH := 820

var _browse: CenterContainer
var _detail: CenterContainer
var _cards: HBoxContainer
var _title: Label
var _expanded_from: Button = null

func _ready() -> void:
	layer = 20
	process_mode = Node.PROCESS_MODE_WHEN_PAUSED
	visible = false

	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.78)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)

	_browse = CenterContainer.new()
	_browse.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(_browse)

	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 14)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	_browse.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override(&"font_size", 40)
	_title.add_theme_color_override(&"font_color", Color(0.8, 1.0, 1.0))
	box.add_child(_title)

	var subtitle := _text("Pick one — it stays with you for the rest of the run.", 19, Color(0.55, 0.72, 0.8))
	subtitle.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(subtitle)

	_cards = HBoxContainer.new()
	_cards.add_theme_constant_override(&"separation", 22)
	_cards.alignment = BoxContainer.ALIGNMENT_CENTER
	box.add_child(_cards)

	var hint := _text("stick / d-pad / mouse to browse     •     A or click to read the full description",
			17, Color(0.42, 0.56, 0.64))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	box.add_child(hint)

	_detail = CenterContainer.new()
	_detail.set_anchors_preset(Control.PRESET_FULL_RECT)
	_detail.visible = false
	add_child(_detail)

func show_options(options: Array, level: int) -> void:
	_title.text = "RING LEVEL %d — CHOOSE AN UPGRADE" % level
	for c in _cards.get_children():
		c.queue_free()
	_close_detail_panel()
	var first: Button = null
	for opt in options:
		var card := _make_card(opt)
		_cards.add_child(card)
		if first == null:
			first = card
	visible = true
	if first != null:
		first.grab_focus()  # d-pad/controller navigation starts here

## B / Esc backs out of an expanded card without committing to it.
func _input(event: InputEvent) -> void:
	if visible and _detail.visible and event.is_action_pressed(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		_collapse()

# --- browse view ------------------------------------------------------------

func _make_card(opt: Dictionary) -> Button:
	var cat: Dictionary = Upgrades.CATEGORIES[opt.cat]
	var color: Color = cat.color
	var owned := int(GameState.owned.get(opt.id, 0))

	var b := Button.new()
	b.custom_minimum_size = CARD_SIZE
	b.focus_mode = Control.FOCUS_ALL
	_style_button(b, color)
	# mouse users get the same highlight as the controller cursor, and only one
	# card is ever lit at a time
	b.mouse_entered.connect(b.grab_focus)

	var col := _card_body(b, 18)

	# --- header: icon + which system this touches + how many you already have
	var head := HBoxContainer.new()
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	head.add_theme_constant_override(&"separation", 9)
	col.add_child(head)
	head.add_child(_icon(opt.cat, color, 26))
	var tag := _text(cat.label, 17, color)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	if owned > 0:
		head.add_child(_text("OWNED ×%d" % owned, 17, Color(0.6, 0.74, 0.8)))

	col.add_child(_text(opt.title, 27, Color(0.94, 0.99, 1.0)))
	_add_stat_rows(col, opt, color, 17, 19, 21)
	col.add_child(_rule(color))

	# --- what that actually means while you're playing
	var blurb := _text(opt.blurb, 17, Color(0.74, 0.84, 0.89))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	blurb.size_flags_vertical = Control.SIZE_EXPAND_FILL
	col.add_child(blurb)

	var more := _text("press to read more »", 16, Color(color.r, color.g, color.b, 0.75))
	more.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	col.add_child(more)

	b.pressed.connect(_expand.bind(opt, b))
	return b

# --- detail view ------------------------------------------------------------

func _expand(opt: Dictionary, from: Button) -> void:
	var cat: Dictionary = Upgrades.CATEGORIES[opt.cat]
	var color: Color = cat.color
	var owned := int(GameState.owned.get(opt.id, 0))
	_expanded_from = from
	Sfx.play(&"ui", 0.9, -6.0)
	_close_detail_panel()

	var panel := PanelContainer.new()
	var skin := StyleBoxFlat.new()
	skin.bg_color = Color(0.02, 0.06, 0.10, 0.99)
	skin.set_border_width_all(3)
	skin.border_color = color
	skin.set_corner_radius_all(12)
	skin.shadow_color = Color(color.r, color.g, color.b, 0.25)
	skin.shadow_size = 18
	for side in [&"content_margin_left", &"content_margin_right",
			&"content_margin_top", &"content_margin_bottom"]:
		skin.set(side, 34.0)
	panel.add_theme_stylebox_override(&"panel", skin)
	_detail.add_child(panel)

	var col := VBoxContainer.new()
	col.add_theme_constant_override(&"separation", 14)
	col.custom_minimum_size = Vector2(DETAIL_WIDTH, 0)  # gives the prose its wrap width
	panel.add_child(col)

	var head := HBoxContainer.new()
	head.add_theme_constant_override(&"separation", 12)
	col.add_child(head)
	head.add_child(_icon(opt.cat, color, 36))
	var tag := _text(cat.label, 20, color)
	tag.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	head.add_child(tag)
	if owned > 0:
		head.add_child(_text("ALREADY TAKEN ×%d" % owned, 20, Color(0.6, 0.74, 0.8)))

	col.add_child(_text(opt.title, 42, Color(0.94, 0.99, 1.0)))
	_add_stat_rows(col, opt, color, 20, 22, 28)
	col.add_child(_rule(color))

	var blurb := _text(opt.blurb, 23, Color(0.88, 0.95, 0.98))
	blurb.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(blurb)

	var detail := _text(opt.get("detail", ""), 20, Color(0.68, 0.79, 0.85))
	detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	col.add_child(detail)

	if opt.has("note"):
		col.add_child(_text(opt.note, 20, Color(color.r, color.g, color.b, 0.9)))

	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override(&"separation", 16)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_child(buttons)

	var take := Button.new()
	take.text = "  TAKE THIS  "
	take.custom_minimum_size = Vector2(300, 62)
	take.add_theme_font_size_override(&"font_size", 26)
	take.add_theme_color_override(&"font_color", Color(0.96, 1.0, 1.0))
	_style_button(take, color)
	take.pressed.connect(func() -> void:
		visible = false
		_close_detail_panel()
		Sfx.play(&"ui", 1.2)
		GameState.apply_upgrade(opt.id))
	buttons.add_child(take)

	var back := Button.new()
	back.text = "  BACK  "
	back.custom_minimum_size = Vector2(200, 62)
	back.add_theme_font_size_override(&"font_size", 22)
	back.add_theme_color_override(&"font_color", Color(0.72, 0.84, 0.9))
	_style_button(back, Color(0.55, 0.68, 0.76))
	back.pressed.connect(_collapse)
	buttons.add_child(back)

	var keys := _text("A / click to take it     •     B or Esc to go back", 17, Color(0.42, 0.56, 0.64))
	keys.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	col.add_child(keys)

	_browse.visible = false
	_detail.visible = true
	take.grab_focus()  # a second press on the same button commits the pick

func _collapse() -> void:
	Sfx.play(&"ui", 0.7, -8.0)
	_close_detail_panel()
	_browse.visible = true
	if _expanded_from != null and is_instance_valid(_expanded_from):
		_expanded_from.grab_focus()

func _close_detail_panel() -> void:
	_detail.visible = false
	for c in _detail.get_children():
		c.queue_free()

# --- shared pieces ----------------------------------------------------------

## A Button can't lay out children on its own; this anchors a padded column
## over it and makes every child click-through so the button still takes input.
func _card_body(b: Button, pad: int) -> VBoxContainer:
	var margin := MarginContainer.new()
	margin.set_anchors_preset(Control.PRESET_FULL_RECT)
	margin.mouse_filter = Control.MOUSE_FILTER_IGNORE
	for side in [&"margin_left", &"margin_right", &"margin_top", &"margin_bottom"]:
		margin.add_theme_constant_override(side, pad)
	b.add_child(margin)
	var col := VBoxContainer.new()
	col.mouse_filter = Control.MOUSE_FILTER_IGNORE
	col.add_theme_constant_override(&"separation", 9)
	margin.add_child(col)
	return col

## The numbers, read live off the current run so they're never generic.
func _add_stat_rows(col: VBoxContainer, opt: Dictionary, color: Color,
		label_size: int, from_size: int, to_size: int) -> void:
	for row in Upgrades.preview(opt.id, GameState.mods):
		var stat := HBoxContainer.new()
		stat.mouse_filter = Control.MOUSE_FILTER_IGNORE
		stat.add_theme_constant_override(&"separation", 8)
		col.add_child(stat)
		var label := _text(row.label, label_size, Color(0.62, 0.76, 0.83))
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# the numbers are the point of the row: let the stat's name give up
		# space (and ellipsize) rather than push the values past the card edge
		label.clip_text = true
		label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
		stat.add_child(label)
		stat.add_child(_text(row.from, from_size, Color(0.55, 0.68, 0.75)))
		stat.add_child(_text("»", from_size, Color(0.5, 0.62, 0.7)))
		stat.add_child(_text(row.to, to_size, color))

func _rule(color: Color) -> ColorRect:
	var rule := ColorRect.new()
	rule.color = Color(color.r, color.g, color.b, 0.22)
	rule.custom_minimum_size = Vector2(0, 1)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule

func _text(s: String, size: int, color: Color) -> Label:
	var l := Label.new()
	l.text = s
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_size_override(&"font_size", size)
	l.add_theme_color_override(&"font_color", color)
	return l

func _style_button(b: Button, color: Color) -> void:
	var idle := StyleBoxFlat.new()
	idle.bg_color = Color(0.02, 0.06, 0.10, 0.96)
	idle.set_border_width_all(2)
	idle.border_color = Color(color.r, color.g, color.b, 0.30)
	idle.set_corner_radius_all(10)
	var lit := StyleBoxFlat.new()
	lit.bg_color = Color(color.r * 0.14, color.g * 0.14, color.b * 0.14, 0.99)
	lit.set_border_width_all(4)
	lit.border_color = color
	lit.set_corner_radius_all(10)
	lit.shadow_color = Color(color.r, color.g, color.b, 0.30)
	lit.shadow_size = 14
	b.add_theme_stylebox_override(&"normal", idle)
	b.add_theme_stylebox_override(&"hover", lit)
	b.add_theme_stylebox_override(&"focus", lit)
	b.add_theme_stylebox_override(&"pressed", lit)

## Little drawn glyph per system — the same shapes you see in the arena, so a
## card points at something the player can recognize on screen.
func _icon(cat: StringName, color: Color, size: int) -> Control:
	var c := Control.new()
	c.custom_minimum_size = Vector2(size, size)
	c.mouse_filter = Control.MOUSE_FILTER_IGNORE
	c.draw.connect(_draw_icon.bind(c, cat, color, float(size)))
	return c

func _draw_icon(c: Control, cat: StringName, color: Color, size: float) -> void:
	var s := size / 26.0  # glyphs are authored on a 26px grid
	var mid := Vector2(13, 13) * s
	match cat:
		&"beam":
			c.draw_line(Vector2(1, 13) * s, Vector2(24, 13) * s, Color(color.r, color.g, color.b, 0.35), 7.0 * s)
			c.draw_line(Vector2(1, 13) * s, Vector2(24, 13) * s, color, 2.5 * s)
			c.draw_circle(Vector2(24, 13) * s, 3.0 * s, Color(1, 1, 1, 0.9))
		&"turrets":
			var pts := PackedVector2Array([Vector2(13, 2) * s, Vector2(23, 13) * s,
					Vector2(13, 24) * s, Vector2(3, 13) * s])
			c.draw_colored_polygon(pts, Color(color.r * 0.55, color.g * 0.55, color.b * 0.55, 0.95))
			var outline := pts.duplicate()
			outline.append(pts[0])
			c.draw_polyline(outline, color, 2.0 * s, true)
		&"core":
			c.draw_arc(mid, 11.0 * s, 0.0, TAU, 32, color, 2.0 * s, true)
			c.draw_circle(mid, 5.0 * s, color)
		&"mass":
			c.draw_circle(Vector2(20, 13) * s, 5.0 * s, color)
			for i in 3:
				var p := Vector2(2.0 + i * 2.0, 4.0 + i * 7.0) * s
				c.draw_circle(p, 2.2 * s, Color(color.r, color.g, color.b, 0.5 + i * 0.15))
		&"blast":
			c.draw_arc(mid, 11.0 * s, 0.0, TAU, 32, Color(color.r, color.g, color.b, 0.45), 2.0 * s, true)
			c.draw_arc(mid, 6.5 * s, 0.0, TAU, 24, color, 2.0 * s, true)
			c.draw_circle(mid, 2.5 * s, Color(1, 1, 1, 0.9))
