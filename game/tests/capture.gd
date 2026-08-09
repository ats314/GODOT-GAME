extends SceneTree

## Run the cockpit for a few seconds and save a screenshot.
##
## Rendering works in a GPU-less container through Mesa's software rasterizer,
## so this is how a visual change gets checked without a human — and the basis
## for visual regression tests against committed reference frames later.
##
##   xvfb-run -a godot --path game --rendering-driver vulkan \
##     --script res://tests/capture.gd -- --seconds=8 --out=/tmp/shot.png
##
## Simulated input can be injected with --repair / --power, so the capture can
## show the cockpit mid-repair rather than in its opening state.

const DEFAULT_SECONDS := 8.0

var _elapsed := 0.0
var _seconds := DEFAULT_SECONDS
var _out := "user://cockpit.png"
var _hold_repair := false
var _hold_power := false


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--seconds="):
			_seconds = float(arg.trim_prefix("--seconds="))
		elif arg.begins_with("--out="):
			_out = arg.trim_prefix("--out=")
		elif arg == "--repair":
			_hold_repair = true
		elif arg == "--power":
			_hold_power = true

	var scene: PackedScene = load("res://scenes/cockpit.tscn")
	if scene == null:
		push_error("could not load res://scenes/cockpit.tscn")
		quit(2)
		return
	root.add_child(scene.instantiate())


func _process(delta: float) -> bool:
	_elapsed += delta

	# Hold inputs so the capture shows the panel doing something. Action_press
	# is the supported way to synthesise held input without fabricating events.
	if _hold_repair:
		Input.action_press("repair")
	if _hold_power:
		Input.action_press("power_up")

	if _elapsed < _seconds:
		return false

	var image := root.get_texture().get_image()
	if image == null:
		push_error("no framebuffer — is this running headless rather than under Xvfb?")
		quit(1)
		return true
	var error := image.save_png(_out)
	if error != OK:
		push_error("could not write %s (error %d)" % [_out, error])
		quit(1)
		return true
	print(
		"captured %s  %dx%d after %.1fs" % [_out, image.get_width(), image.get_height(), _elapsed]
	)
	quit(0)
	return true
