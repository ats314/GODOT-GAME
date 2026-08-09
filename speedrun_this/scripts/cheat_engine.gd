class_name CheatEngine
extends Node2D
## The heart of the game. Reads the cheat list for the current level
## and attempt, then silently sabotages the player every frame.
## Nothing here is visible to the player — that's the joke.

var _player: Player
var _active_cheats: Array = []
var _wall_bodies: Array[StaticBody2D] = []
var _gap_zones: Array[Dictionary] = []
var _original_platforms: Array[Dictionary] = []   # index -> {body, orig_size, orig_pos}
var _platform_bodies: Array[StaticBody2D] = []

# Per-cheat transient state
var _speed_drain_applied: float = 0.0
var _gravity_spiked: bool = false
var _input_flip_timer: float = 0.0
var _input_flip_triggered: bool = false
var _goal_node: Node2D = null
var _goal_original_pos: Vector2
var _goal_fleeing: bool = false
var _ceiling_bodies: Array[StaticBody2D] = []
var _bounce_zones: Array[Dictionary] = []
var _wind_applied: bool = false

func setup(player: Player, platform_bodies: Array[StaticBody2D],
		goal: Node2D) -> void:
	_player = player
	_platform_bodies = platform_bodies
	_goal_node = goal
	_goal_original_pos = goal.global_position
	_save_original_platforms()

func _save_original_platforms() -> void:
	_original_platforms.clear()
	for body in _platform_bodies:
		var col: CollisionShape2D = body.get_child(0) as CollisionShape2D
		var shape: RectangleShape2D = col.shape as RectangleShape2D
		_original_platforms.append({
			"body": body,
			"col": col,
			"orig_size": shape.size,
			"orig_pos": body.global_position,
		})

func load_cheats(cheat_list: Array) -> void:
	_clear_runtime_nodes()
	_active_cheats = cheat_list
	_speed_drain_applied = 0.0
	_gravity_spiked = false
	_input_flip_timer = 0.0
	_input_flip_triggered = false
	_goal_fleeing = false
	_wind_applied = false
	_bounce_zones.clear()

	if _goal_node:
		_goal_node.global_position = _goal_original_pos

	# Restore original platform sizes
	for entry in _original_platforms:
		var col: CollisionShape2D = entry.col
		var shape: RectangleShape2D = col.shape.duplicate() as RectangleShape2D
		shape.size = entry.orig_size
		col.shape = shape
		entry.body.global_position = entry.orig_pos

	# Pre-spawn persistent cheat nodes
	for cheat in _active_cheats:
		match cheat.type:
			"invisible_wall":
				_spawn_invisible_wall(cheat.pos, cheat.size)
				GameState.log_cheat("Invisible walls")
			"floor_gap":
				_gap_zones.append({"x_start": cheat.x_start, "x_end": cheat.x_end})
				_apply_floor_gap(cheat.x_start, cheat.x_end)
				GameState.log_cheat("Hidden floor gaps")
			"platform_shrink":
				_apply_platform_shrink(cheat["index"], cheat.amount)
				GameState.log_cheat("Shrunken platforms")
			"floor_bounce":
				_bounce_zones = cheat.zones
				GameState.log_cheat("Bouncy floor sections")

func process_cheats(delta: float) -> void:
	if not is_instance_valid(_player) or not _player._alive:
		return

	for cheat in _active_cheats:
		match cheat.type:
			"speed_drain":
				_do_speed_drain(cheat, delta)
			"gravity_spike":
				_do_gravity_spike(cheat)
			"input_flip_burst":
				_do_input_flip(cheat, delta)
			"goal_flee":
				_do_goal_flee(cheat, delta)
			"wind":
				_do_wind(cheat)
			"platform_slide":
				_do_platform_slide(cheat, delta)
			"ceiling_drop":
				_do_ceiling_drop(cheat)
			"coyote_kill":
				_do_coyote_kill()
			"floor_bounce":
				_do_floor_bounce()

	# Apply accumulated modifiers
	if _input_flip_timer > 0:
		_player.input_flip = true
		_input_flip_timer -= delta
	else:
		_player.input_flip = false

func _clear_runtime_nodes() -> void:
	for body in _wall_bodies:
		if is_instance_valid(body):
			body.queue_free()
	_wall_bodies.clear()
	for body in _ceiling_bodies:
		if is_instance_valid(body):
			body.queue_free()
	_ceiling_bodies.clear()
	_gap_zones.clear()
	_active_cheats.clear()

# ── Cheat implementations ─────────────────────────────────────────

func _spawn_invisible_wall(pos: Vector2, size: Vector2) -> void:
	var body := StaticBody2D.new()
	var col := CollisionShape2D.new()
	var shape := RectangleShape2D.new()
	shape.size = size
	col.shape = shape
	body.add_child(col)
	body.global_position = pos
	# Invisible — no visual representation at all
	add_child(body)
	_wall_bodies.append(body)

func _apply_floor_gap(x_start: float, x_end: float) -> void:
	# Split the floor platform to create a hidden gap.
	# We modify collision shapes so the visual stays intact but the
	# player falls through.
	for entry in _original_platforms:
		var body: StaticBody2D = entry.body
		var col: CollisionShape2D = entry.col
		var shape: RectangleShape2D = col.shape as RectangleShape2D
		var plat_left := body.global_position.x - shape.size.x * 0.5
		var plat_right := body.global_position.x + shape.size.x * 0.5

		if plat_left < x_start and plat_right > x_end:
			# This platform spans the gap — shrink it to the left side only
			var new_width := x_start - plat_left
			var new_shape := shape.duplicate() as RectangleShape2D
			new_shape.size.x = new_width
			col.shape = new_shape
			col.position.x = -(shape.size.x * 0.5 - new_width * 0.5)

			# Spawn a right-side piece
			var right_width := plat_right - x_end
			if right_width > 10:
				var rbody := StaticBody2D.new()
				var rcol := CollisionShape2D.new()
				var rshape := RectangleShape2D.new()
				rshape.size = Vector2(right_width, shape.size.y)
				rcol.shape = rshape
				rbody.add_child(rcol)
				rbody.global_position = Vector2(x_end + right_width * 0.5, body.global_position.y)
				add_child(rbody)
				_wall_bodies.append(rbody)   # track for cleanup
			break

func _apply_platform_shrink(index: int, amount: float) -> void:
	if index < 0 or index >= _original_platforms.size():
		return
	var entry: Dictionary = _original_platforms[index]
	var col: CollisionShape2D = entry.col
	var shape: RectangleShape2D = col.shape.duplicate() as RectangleShape2D
	shape.size.x = maxf(shape.size.x - amount, 30.0)
	col.shape = shape

func _do_speed_drain(cheat: Dictionary, delta: float) -> void:
	_speed_drain_applied += cheat.rate * delta
	_player.speed_mod = maxf(1.0 - _speed_drain_applied, 0.25)
	if not _wind_applied:
		# Only log once when noticeable
		if _speed_drain_applied > 0.15:
			GameState.log_cheat("Gradual speed drain")

func _do_gravity_spike(cheat: Dictionary) -> void:
	# When the player is above trigger_y and moving upward → spike gravity
	if _player.global_position.y < cheat.trigger_y and _player.velocity.y < 0:
		_player.gravity_mod = cheat.multiplier
		if not _gravity_spiked:
			_gravity_spiked = true
			Events.cheat_activated.emit("gravity_spike")
			Sfx.play("cheat")
			GameState.log_cheat("Gravity spikes mid-jump")
	else:
		_player.gravity_mod = 1.0

func _do_input_flip(cheat: Dictionary, delta: float) -> void:
	if not _input_flip_triggered and _player.global_position.x > cheat.trigger_x:
		_input_flip_triggered = true
		_input_flip_timer = cheat.duration
		Events.cheat_activated.emit("input_flip")
		Sfx.play("cheat")
		GameState.log_cheat("Controls reversed mid-run")

func _do_goal_flee(cheat: Dictionary, delta: float) -> void:
	if not is_instance_valid(_goal_node):
		return
	var dist := _player.global_position.distance_to(_goal_node.global_position)
	if dist < cheat.range:
		var away := (_goal_node.global_position - _player.global_position).normalized()
		_goal_node.global_position += away * cheat.speed * delta
		# Clamp to screen-ish bounds
		_goal_node.global_position.x = clampf(_goal_node.global_position.x, 100, 1850)
		if not _goal_fleeing:
			_goal_fleeing = true
			GameState.log_cheat("Goal runs away from you")

func _do_wind(cheat: Dictionary) -> void:
	if (_player.global_position.x > cheat.zone_x_start and
			_player.global_position.x < cheat.zone_x_end):
		_player.extra_velocity.x = cheat.force
		_wind_applied = true
		GameState.log_cheat("Invisible headwind")
	else:
		if _wind_applied:
			_player.extra_velocity.x = 0.0

func _do_platform_slide(cheat: Dictionary, delta: float) -> void:
	var index: int = cheat["index"]
	if index < 0 or index >= _platform_bodies.size():
		return
	_platform_bodies[index].global_position.x += cheat.speed * delta
	GameState.log_cheat("Platforms drift sideways")

func _do_ceiling_drop(cheat: Dictionary) -> void:
	# Move ceiling segments down when player approaches
	if _ceiling_bodies.is_empty():
		# Find the ceiling platform (second platform in corridor levels)
		if _platform_bodies.size() >= 2:
			for x_pos in cheat.x_positions:
				# We don't add real bodies — we just modify the ceiling platform
				pass
	# Simpler approach: push the player down when near x positions
	for x_pos in cheat.x_positions:
		var dist_x := absf(_player.global_position.x - x_pos)
		if dist_x < cheat.range:
			var crush_factor := 1.0 - (dist_x / cheat.range)
			_player.extra_velocity.y = cheat.amount * crush_factor * 10.0
			GameState.log_cheat("Ceiling pushes you down")
			return
	# Reset if not near any
	if _player.extra_velocity.y > 0 and _player.is_on_floor():
		_player.extra_velocity.y = 0.0

func _do_coyote_kill() -> void:
	# Disable coyote time — player can't jump after walking off edge
	_player._coyote_timer = 0.0
	GameState.log_cheat("Coyote time removed")

func _do_floor_bounce() -> void:
	for zone in _bounce_zones:
		var zx: float = zone.x
		var zw: float = zone.w
		if (_player.global_position.x > zx - zw * 0.5 and
				_player.global_position.x < zx + zw * 0.5 and
				_player.is_on_floor()):
			_player.velocity.y = -400.0
			GameState.log_cheat("Bouncy floor patches")
			break

func cleanup() -> void:
	_clear_runtime_nodes()
	if is_instance_valid(_player):
		_player.reset_mods()
