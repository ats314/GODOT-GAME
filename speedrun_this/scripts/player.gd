class_name Player
extends CharacterBody2D
## Tight, responsive platformer controller with coyote time, jump
## buffering, and variable jump height. The cheat engine modifies
## exposed multipliers to sabotage the player invisibly.

# ── Tuning ─────────────────────────────────────────────────────────
const BASE_SPEED       := 420.0
const BASE_JUMP_VEL    := -620.0
const BASE_GRAVITY     := 1400.0
const FALL_GRAVITY_MUL := 1.6       # heavier on the way down
const COYOTE_TIME      := 0.10
const JUMP_BUFFER_TIME := 0.12
const ACCEL            := 2800.0
const DECEL            := 3200.0

# ── Cheat-engine hooks (1.0 = normal) ─────────────────────────────
var gravity_mod: float = 1.0
var speed_mod: float   = 1.0
var jump_mod: float    = 1.0
var input_flip: bool   = false       # reverses left/right
var frozen: bool       = false       # blocks all input
var extra_velocity: Vector2 = Vector2.ZERO  # wind / push

# ── Internal ───────────────────────────────────────────────────────
var _coyote_timer: float  = 0.0
var _jump_buffer: float   = 0.0
var _was_on_floor: bool   = false
var _alive: bool          = true
var _facing: float        = 1.0       # 1 right, -1 left
var _squash: float        = 1.0       # squash-stretch Y scale

# ── Visual ─────────────────────────────────────────────────────────
const WIDTH  := 28.0
const HEIGHT := 44.0
var player_color := Color(0.29, 0.87, 0.50)       # green
var trail_points: Array[Vector2] = []
const MAX_TRAIL := 8

# ── Lifecycle ──────────────────────────────────────────────────────
func _ready() -> void:
	# Build collision shape
	var shape := RectangleShape2D.new()
	shape.size = Vector2(WIDTH, HEIGHT)
	var col := CollisionShape2D.new()
	col.shape = shape
	col.position = Vector2(0, -HEIGHT * 0.5)
	add_child(col)

func reset_mods() -> void:
	gravity_mod = 1.0
	speed_mod = 1.0
	jump_mod = 1.0
	input_flip = false
	frozen = false
	extra_velocity = Vector2.ZERO

func die() -> void:
	if not _alive:
		return
	_alive = false
	Events.player_died.emit(global_position)
	Sfx.play("die")

func revive(pos: Vector2) -> void:
	global_position = pos
	velocity = Vector2.ZERO
	_alive = true
	_coyote_timer = 0.0
	_jump_buffer = 0.0
	_squash = 1.0
	trail_points.clear()
	reset_mods()
	visible = true

# ── Physics ────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	if not _alive or frozen:
		return

	var on_floor := is_on_floor()

	# ── Coyote time ──
	if on_floor:
		_coyote_timer = COYOTE_TIME
	else:
		_coyote_timer -= delta

	# ── Jump buffer ──
	if Input.is_action_just_pressed("jump"):
		_jump_buffer = JUMP_BUFFER_TIME
	else:
		_jump_buffer -= delta

	# ── Gravity ──
	if not on_floor:
		var grav := BASE_GRAVITY * gravity_mod
		if velocity.y > 0:
			grav *= FALL_GRAVITY_MUL
		velocity.y += grav * delta
	elif not _was_on_floor:
		# Landing
		_squash = 0.75
		Sfx.play("land", randf_range(0.9, 1.1))

	# ── Jump ──
	if _jump_buffer > 0.0 and _coyote_timer > 0.0:
		velocity.y = BASE_JUMP_VEL * jump_mod
		_coyote_timer = 0.0
		_jump_buffer = 0.0
		_squash = 1.3
		Sfx.play("jump", randf_range(0.95, 1.05))

	# Variable jump height: release early = weaker jump
	if Input.is_action_just_released("jump") and velocity.y < 0:
		velocity.y *= 0.45

	# ── Horizontal ──
	var raw_dir := Input.get_axis("move_left", "move_right")
	if input_flip:
		raw_dir = -raw_dir
	var target_speed := raw_dir * BASE_SPEED * speed_mod

	if raw_dir != 0.0:
		velocity.x = move_toward(velocity.x, target_speed, ACCEL * delta)
		_facing = sign(raw_dir)
	else:
		velocity.x = move_toward(velocity.x, 0.0, DECEL * delta)

	# ── Extra velocity (wind/push from cheats) ──
	velocity += extra_velocity * delta

	_was_on_floor = on_floor
	move_and_slide()

	# ── Death: fell off bottom ──
	if global_position.y > 1200:
		die()

	# ── Trail ──
	trail_points.push_front(global_position)
	if trail_points.size() > MAX_TRAIL:
		trail_points.resize(MAX_TRAIL)

	# ── Squash-stretch lerp ──
	_squash = lerpf(_squash, 1.0, 12.0 * delta)

	queue_redraw()

# ── Draw ───────────────────────────────────────────────────────────
func _draw() -> void:
	if not _alive:
		return

	# Trail
	for i in trail_points.size():
		var alpha := (1.0 - float(i) / MAX_TRAIL) * 0.15
		var pt: Vector2 = trail_points[i] - global_position
		draw_rect(
			Rect2(pt.x - WIDTH * 0.4, pt.y - HEIGHT + 2, WIDTH * 0.8, HEIGHT - 4),
			Color(player_color, alpha)
		)

	# Body with squash-stretch
	var w := WIDTH / _squash
	var h := HEIGHT * _squash
	var body_rect := Rect2(-w * 0.5, -h, w, h)
	draw_rect(body_rect, player_color)

	# Glow layer
	var glow_rect := Rect2(body_rect.position - Vector2(3, 3), body_rect.size + Vector2(6, 6))
	draw_rect(glow_rect, Color(player_color, 0.15))

	# Eyes (two small white squares)
	var eye_y := -h * 0.7
	var eye_dx := w * 0.18 * _facing
	draw_rect(Rect2(eye_dx - 3, eye_y - 2, 5, 5), Color.WHITE)
	draw_rect(Rect2(eye_dx + w * 0.22 * _facing - 3, eye_y - 2, 5, 5), Color.WHITE)
