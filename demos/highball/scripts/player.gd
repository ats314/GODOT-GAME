class_name Crew
extends CharacterBody3D
## First-person crew member. Ordinary FPS movement plus the two things that
## sell a moving train: constant vibration through the camera, and a hard
## lateral shove whenever you are out on an open gangway.

const SPEED := 4.4
const SPRINT := 7.4
const ACCEL := 14.0
const MOUSE_SENS := 0.0022
const STICK_SENS := 2.6

var camera: Camera3D
var exposed := false        ## true while standing on a gangway plate
var speed_fraction := 0.0   ## train speed / max, drives vibration amplitude

var _yaw := 0.0
var _pitch := 0.0
var _bob := 0.0
var _sway := 0.0


func _ready() -> void:
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.height = 1.75
	capsule.radius = 0.35
	shape.shape = capsule
	shape.position = Vector3(0, 0.875, 0)
	add_child(shape)

	camera = Camera3D.new()
	camera.position = Vector3(0, 1.62, 0)
	camera.fov = 78.0
	camera.far = 900.0
	add_child(camera)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		_yaw -= event.relative.x * MOUSE_SENS
		_pitch = clampf(_pitch - event.relative.y * MOUSE_SENS, -1.45, 1.45)


func _physics_process(delta: float) -> void:
	var look := Input.get_vector(&"look_left", &"look_right", &"look_up", &"look_down")
	if look.length() > 0.15:
		_yaw -= look.x * STICK_SENS * delta
		_pitch = clampf(_pitch - look.y * STICK_SENS * delta, -1.45, 1.45)

	var input := Input.get_vector(&"move_left", &"move_right", &"move_forward", &"move_back")
	var basis_dir := Vector3(input.x, 0.0, input.y).rotated(Vector3.UP, _yaw)
	var target_speed := SPRINT if Input.is_action_pressed(&"sprint") else SPEED
	var wanted := basis_dir * target_speed

	velocity.x = move_toward(velocity.x, wanted.x, ACCEL * delta)
	velocity.z = move_toward(velocity.z, wanted.z, ACCEL * delta)
	if not is_on_floor():
		velocity.y -= 22.0 * delta
	else:
		velocity.y = 0.0

	# Out on the plates the slipstream shoves you sideways. It will not kill
	# you in the demo, but it is the reason crossing at speed reads as a risk.
	if exposed:
		var gust := sin(_sway * 2.3) * 0.6 + sin(_sway * 7.1) * 0.25
		velocity.x += gust * speed_fraction * 5.0 * delta
	_sway += delta * (1.0 + speed_fraction)

	move_and_slide()

	rotation.y = _yaw
	_apply_camera(delta)


func _apply_camera(delta: float) -> void:
	var moving := Vector2(velocity.x, velocity.z).length()
	_bob += delta * (6.0 + moving * 1.3)

	# Track rumble: two out-of-phase sines so it never reads as a clean loop,
	# scaled by how fast the train is actually running.
	var rumble := speed_fraction * (1.0 if not exposed else 2.1)
	var shake_x := sin(_bob * 3.1) * 0.0016 * rumble + sin(_bob * 11.7) * 0.0009 * rumble
	var shake_y := sin(_bob * 4.7) * 0.0022 * rumble + sin(_bob * 17.3) * 0.0011 * rumble
	var bob_y := sin(_bob * 2.0) * 0.035 * clampf(moving / SPEED, 0.0, 1.4)

	camera.rotation = Vector3(_pitch + shake_y, 0.0, sin(_bob * 1.7) * 0.01 * rumble + shake_x)
	camera.position = Vector3(shake_x * 6.0, 1.62 + bob_y + shake_y * 4.0, 0.0)
	camera.fov = lerpf(camera.fov, 78.0 + speed_fraction * 6.0 + (5.0 if exposed else 0.0), delta * 3.0)
