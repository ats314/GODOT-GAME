extends Control
## Title screen: SPEEDRUN THIS with animated fake-glitch title,
## a preview "ghost" running across the bottom, and a START button.

var _stars: Array[Dictionary] = []
var _glitch_timer: float = 0.0
var _glitch_offset: Vector2 = Vector2.ZERO
var _ghost_x: float = -100.0

func _ready() -> void:
	# Generate starfield
	var rng := RandomNumberGenerator.new()
	rng.seed = 42
	for i in 300:
		_stars.append({
			"pos": Vector2(rng.randf_range(0, 1920), rng.randf_range(0, 1080)),
			"bright": rng.randf_range(0.1, 0.6),
			"size": rng.randf_range(1.0, 2.5),
		})

	_build_ui()

func _build_ui() -> void:
	# Title
	var title := Label.new()
	title.text = "SPEEDRUN THIS"
	title.add_theme_font_size_override("font_size", 72)
	title.add_theme_color_override("font_color", Color(0.29, 0.87, 0.50))
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	title.position = Vector2(-400, 180)
	title.size = Vector2(800, 100)
	add_child(title)

	# Tagline
	var tag := Label.new()
	tag.text = "The game is fair. The game is FAIR."
	tag.add_theme_font_size_override("font_size", 18)
	tag.add_theme_color_override("font_color", Color(1, 1, 1, 0.4))
	tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	tag.set_anchors_and_offsets_preset(PRESET_CENTER_TOP)
	tag.position = Vector2(-400, 270)
	tag.size = Vector2(800, 40)
	add_child(tag)

	# Buttons container
	var vbox := VBoxContainer.new()
	vbox.set_anchors_and_offsets_preset(PRESET_CENTER)
	vbox.position = Vector2(-120, 20)
	vbox.size = Vector2(240, 120)
	vbox.add_theme_constant_override("separation", 16)
	add_child(vbox)

	var start_btn := Button.new()
	start_btn.text = "START"
	start_btn.add_theme_font_size_override("font_size", 24)
	start_btn.custom_minimum_size = Vector2(240, 50)
	start_btn.pressed.connect(_on_start)
	start_btn.grab_focus()
	vbox.add_child(start_btn)

	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.add_theme_font_size_override("font_size", 18)
	quit_btn.custom_minimum_size = Vector2(240, 40)
	quit_btn.pressed.connect(func(): get_tree().quit())
	vbox.add_child(quit_btn)

	# Bottom credit
	var credit := Label.new()
	credit.text = "A game that definitely doesn't cheat."
	credit.add_theme_font_size_override("font_size", 12)
	credit.add_theme_color_override("font_color", Color(1, 1, 1, 0.15))
	credit.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	credit.set_anchors_and_offsets_preset(PRESET_BOTTOM_WIDE)
	credit.position.y = -50
	add_child(credit)

func _process(delta: float) -> void:
	# Occasional title glitch
	_glitch_timer -= delta
	if _glitch_timer <= 0:
		_glitch_timer = randf_range(1.5, 4.0)
		_glitch_offset = Vector2(randf_range(-4, 4), randf_range(-2, 2))
		# Reset after brief moment
		get_tree().create_timer(0.08).timeout.connect(
			func(): _glitch_offset = Vector2.ZERO
		)

	# Animate ghost running across bottom
	_ghost_x += 180.0 * delta
	if _ghost_x > 2020:
		_ghost_x = -100.0

	queue_redraw()

func _draw() -> void:
	# Starfield
	for star in _stars:
		var c := Color(0.7, 0.75, 0.9, star.bright)
		draw_circle(star.pos, star.size, c)

	# Ground line
	draw_line(Vector2(0, 880), Vector2(1920, 880), Color(1, 1, 1, 0.08), 1.0)

	# Ghost running
	var ghost_color := Color(0.29, 0.87, 0.50, 0.2)
	draw_rect(Rect2(_ghost_x - 14, 836, 28, 44), ghost_color)
	# Ghost trail
	for i in 6:
		var a := 0.2 * (1.0 - float(i) / 6.0) * 0.5
		draw_rect(Rect2(_ghost_x - 14 - (i + 1) * 30, 836, 28, 44), Color(0.29, 0.87, 0.50, a))

	# Glitch effect on title area
	if _glitch_offset != Vector2.ZERO:
		var r := Rect2(160 + _glitch_offset.x, 180 + _glitch_offset.y, 400, 80)
		draw_rect(r, Color(0.29, 0.87, 0.50, 0.03))

func _on_start() -> void:
	Sfx.play("menu")
	get_tree().change_scene_to_file("res://scenes/run.tscn")

func _input(event: InputEvent) -> void:
	if event.is_action_pressed("jump") or event.is_action_pressed("restart"):
		_on_start()
