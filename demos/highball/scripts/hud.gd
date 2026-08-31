class_name Hud
extends CanvasLayer
## Readouts only. Everything here is information the crew would actually have:
## a speedometer, a fuel gauge, a power meter, and a list of what is wrong.

var _left: Label
var _right: Label
var _faults: Label
var _prompt: Label
var _banner: Label
var _sub: Label
var _bar_bg: ColorRect
var _bar: ColorRect


func _ready() -> void:
	layer = 10
	_left = _label(Vector2(28, 22), 20, HORIZONTAL_ALIGNMENT_LEFT)
	_right = _label(Vector2(-360, 22), 20, HORIZONTAL_ALIGNMENT_RIGHT)
	_right.anchor_left = 1.0
	_right.anchor_right = 1.0
	_right.offset_left = -360.0
	_right.offset_right = -28.0
	_faults = _label(Vector2(28, 150), 17, HORIZONTAL_ALIGNMENT_LEFT)

	_prompt = _label(Vector2(0, 0), 20, HORIZONTAL_ALIGNMENT_CENTER)
	_prompt.anchor_left = 0.0
	_prompt.anchor_right = 1.0
	_prompt.anchor_top = 1.0
	_prompt.anchor_bottom = 1.0
	_prompt.offset_top = -140.0
	_prompt.offset_bottom = -110.0

	_bar_bg = ColorRect.new()
	_bar_bg.color = Color(1, 1, 1, 0.12)
	_bar_bg.anchor_left = 0.5
	_bar_bg.anchor_right = 0.5
	_bar_bg.anchor_top = 1.0
	_bar_bg.anchor_bottom = 1.0
	_bar_bg.offset_left = -170.0
	_bar_bg.offset_right = 170.0
	_bar_bg.offset_top = -100.0
	_bar_bg.offset_bottom = -92.0
	_bar_bg.visible = false
	add_child(_bar_bg)

	_bar = ColorRect.new()
	_bar.color = Color(1.0, 0.72, 0.3, 0.95)
	_bar.anchor_bottom = 1.0
	_bar.offset_right = 0.0
	_bar_bg.add_child(_bar)

	_banner = _label(Vector2(0, 0), 54, HORIZONTAL_ALIGNMENT_CENTER)
	_banner.anchor_left = 0.0
	_banner.anchor_right = 1.0
	_banner.anchor_top = 0.5
	_banner.anchor_bottom = 0.5
	_banner.offset_top = -70.0
	_banner.offset_bottom = -10.0

	_sub = _label(Vector2(0, 0), 20, HORIZONTAL_ALIGNMENT_CENTER)
	_sub.anchor_left = 0.0
	_sub.anchor_right = 1.0
	_sub.anchor_top = 0.5
	_sub.anchor_bottom = 0.5
	_sub.offset_top = 4.0
	_sub.offset_bottom = 40.0

	var dot := ColorRect.new()
	dot.color = Color(1, 1, 1, 0.5)
	dot.anchor_left = 0.5
	dot.anchor_right = 0.5
	dot.anchor_top = 0.5
	dot.anchor_bottom = 0.5
	dot.offset_left = -2.0
	dot.offset_right = 2.0
	dot.offset_top = -2.0
	dot.offset_bottom = 2.0
	add_child(dot)


func _label(pos: Vector2, size: int, align: int) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", Color(0.92, 0.94, 0.98))
	l.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.8))
	l.add_theme_constant_override("shadow_offset_x", 1)
	l.add_theme_constant_override("shadow_offset_y", 2)
	l.horizontal_alignment = align
	add_child(l)
	return l


func set_readouts(speed: float, max_speed: float, power: float, fuel: float,
		cars: int, distance: float, target: float, chase: float, payload: bool) -> void:
	_left.text = "SPEED   %5.1f km/h\nPOWER   %3d%%\nFUEL    %3d%%\nCARS    %d" % [
		speed * 3.6, int(round(power * 100.0)), int(round(fuel)), cars]
	_left.add_theme_color_override("font_color",
			Color(1.0, 0.45, 0.35) if speed < max_speed * 0.25 else Color(0.92, 0.94, 0.98))

	var payload_line := "PAYLOAD  ABOARD" if payload else "PAYLOAD  LOST"
	_right.text = "TO YARD  %.1f km\nPURSUIT  %4d m\n%s" % [
		maxf(0.0, (target - distance)) * 0.001, int(chase), payload_line]
	_right.add_theme_color_override("font_color",
			Color(0.92, 0.94, 0.98) if payload else Color(1.0, 0.55, 0.35))


func set_faults(lines: PackedStringArray) -> void:
	if lines.is_empty():
		_faults.text = ""
		return
	_faults.text = "FAULTS\n" + "\n".join(lines)
	_faults.add_theme_color_override("font_color", Color(1.0, 0.62, 0.35))


func set_prompt(text: String, progress := -1.0) -> void:
	_prompt.text = text
	_bar_bg.visible = progress >= 0.0
	if progress >= 0.0:
		_bar.anchor_right = clampf(progress, 0.0, 1.0)


func set_banner(text: String, sub := "", color := Color(0.95, 0.95, 1.0)) -> void:
	_banner.text = text
	_banner.add_theme_color_override("font_color", color)
	_sub.text = sub
