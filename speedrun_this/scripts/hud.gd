class_name Hud
extends CanvasLayer
## In-run HUD: level name, attempt counter, timer, narrator text,
## death counter, and the cheat reveal on level completion.

var _level_label: Label
var _attempt_label: Label
var _timer_label: Label
var _death_label: Label
var _narrator_label: Label
var _narrator_bg: ColorRect
var _cheats_reveal: VBoxContainer
var _controls_hint: Label
var _banner_label: Label
var _banner_tween: Tween

func _ready() -> void:
	layer = 10
	_build_ui()
	Narrator.text_changed.connect(_on_narrator_text)
	Narrator.text_cleared.connect(_on_narrator_cleared)

func _build_ui() -> void:
	var margin := MarginContainer.new()
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_theme_constant_override("margin_left", 40)
	margin.add_theme_constant_override("margin_right", 40)
	margin.add_theme_constant_override("margin_top", 30)
	margin.add_theme_constant_override("margin_bottom", 30)
	add_child(margin)

	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	margin.add_child(root)

	# ── Top-left: Level name ──
	_level_label = Label.new()
	_level_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	_level_label.add_theme_font_size_override("font_size", 18)
	_level_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	root.add_child(_level_label)

	# ── Top-left below: Attempt counter ──
	_attempt_label = Label.new()
	_attempt_label.position = Vector2(0, 28)
	_attempt_label.add_theme_font_size_override("font_size", 14)
	_attempt_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.35))
	root.add_child(_attempt_label)

	# ── Top-right: Timer ──
	_timer_label = Label.new()
	_timer_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_timer_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_timer_label.add_theme_font_size_override("font_size", 22)
	_timer_label.add_theme_color_override("font_color", Color(1, 1, 1, 0.6))
	root.add_child(_timer_label)

	# ── Top-right below: Death counter ──
	_death_label = Label.new()
	_death_label.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_death_label.position.y = 32
	_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_death_label.add_theme_font_size_override("font_size", 13)
	_death_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4, 0.5))
	root.add_child(_death_label)

	# ── Bottom-center: Narrator ──
	_narrator_bg = ColorRect.new()
	_narrator_bg.color = Color(0, 0, 0, 0.5)
	_narrator_bg.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	_narrator_bg.custom_minimum_size = Vector2(0, 70)
	_narrator_bg.size = Vector2(1920, 70)
	_narrator_bg.position.y = -70
	_narrator_bg.visible = false
	root.add_child(_narrator_bg)

	_narrator_label = Label.new()
	_narrator_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_narrator_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_narrator_label.add_theme_font_size_override("font_size", 20)
	_narrator_label.add_theme_color_override("font_color", Color(0.9, 0.88, 0.82))
	_narrator_label.position = Vector2(-400, -20)
	_narrator_label.size = Vector2(800, 40)
	_narrator_bg.add_child(_narrator_label)

	# ── Center: Banner (level name splash) ──
	_banner_label = Label.new()
	_banner_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_banner_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner_label.add_theme_font_size_override("font_size", 48)
	_banner_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_banner_label.position = Vector2(-400, -120)
	_banner_label.size = Vector2(800, 60)
	root.add_child(_banner_label)

	# ── Bottom-left: Controls hint ──
	_controls_hint = Label.new()
	_controls_hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	_controls_hint.position.y = -10
	_controls_hint.add_theme_font_size_override("font_size", 11)
	_controls_hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.2))
	_controls_hint.text = "A/D or ←/→ Move  ·  SPACE or W Jump  ·  R Restart"
	root.add_child(_controls_hint)

	# ── Cheats reveal overlay (hidden until level end) ──
	_cheats_reveal = VBoxContainer.new()
	_cheats_reveal.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	_cheats_reveal.position = Vector2(-300, -200)
	_cheats_reveal.size = Vector2(600, 400)
	_cheats_reveal.visible = false
	root.add_child(_cheats_reveal)

func _process(_delta: float) -> void:
	_timer_label.text = GameState.format_time(GameState.level_timer)
	if GameState.total_deaths > 0:
		_death_label.text = "☠ %d" % GameState.total_deaths
	else:
		_death_label.text = ""

func set_level(idx: int, name_str: String) -> void:
	_level_label.text = "LEVEL %d — %s" % [idx + 1, name_str]
	_attempt_label.text = ""
	show_banner(name_str)

func set_attempt(num: int) -> void:
	if num <= 1:
		_attempt_label.text = ""
	else:
		_attempt_label.text = "Attempt #%d" % num

func show_banner(text: String) -> void:
	_banner_label.text = text
	if _banner_tween:
		_banner_tween.kill()
	_banner_tween = create_tween()
	_banner_label.add_theme_color_override("font_color", Color(1, 1, 1, 0))
	_banner_tween.tween_property(
		_banner_label, "theme_override_colors/font_color",
		Color(1, 1, 1, 0.9), 0.4
	).set_ease(Tween.EASE_OUT)
	_banner_tween.tween_interval(1.5)
	_banner_tween.tween_property(
		_banner_label, "theme_override_colors/font_color",
		Color(1, 1, 1, 0), 0.6
	)

func show_cheats_reveal(cheats: Array[String], attempts: int) -> void:
	_cheats_reveal.visible = true
	# Clear old
	for child in _cheats_reveal.get_children():
		child.queue_free()

	var title := Label.new()
	title.text = "☑ CHEATS DETECTED"
	title.add_theme_font_size_override("font_size", 28)
	title.add_theme_color_override("font_color", Color(1, 0.44, 0.26))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cheats_reveal.add_child(title)

	var sub := Label.new()
	sub.text = "The game used these against you (%d attempts):" % attempts
	sub.add_theme_font_size_override("font_size", 14)
	sub.add_theme_color_override("font_color", Color(1, 1, 1, 0.5))
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cheats_reveal.add_child(sub)

	var spacer := Control.new()
	spacer.custom_minimum_size = Vector2(0, 10)
	_cheats_reveal.add_child(spacer)

	for cheat_name in cheats:
		var lbl := Label.new()
		lbl.text = "• %s" % cheat_name
		lbl.add_theme_font_size_override("font_size", 18)
		lbl.add_theme_color_override("font_color", Color(1, 0.85, 0.7))
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_cheats_reveal.add_child(lbl)

	var hint := Label.new()
	hint.text = "\nPress SPACE to continue"
	hint.add_theme_font_size_override("font_size", 14)
	hint.add_theme_color_override("font_color", Color(1, 1, 1, 0.3))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_cheats_reveal.add_child(hint)

func hide_cheats_reveal() -> void:
	_cheats_reveal.visible = false

func _on_narrator_text(full_text: String, visible_count: int) -> void:
	_narrator_bg.visible = true
	_narrator_label.text = full_text.substr(0, visible_count)
	if visible_count % 2 == 0:
		Sfx.play("text", randf_range(0.8, 1.2))

func _on_narrator_cleared() -> void:
	_narrator_bg.visible = false
	_narrator_label.text = ""
