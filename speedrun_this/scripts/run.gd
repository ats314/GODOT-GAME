extends Node2D
## Run orchestrator — builds the world, manages the level flow,
## coordinates ghost → player → death → cheat-escalation → retry loop.

# ── Nodes (built in _ready) ───────────────────────────────────────
var _player: Player
var _ghost: Ghost
var _cheat_engine: CheatEngine
var _hud: Hud
var _goal: Node2D
var _goal_sprite: Node2D
var _platforms_node: Node2D
var _platform_bodies: Array[StaticBody2D] = []
var _platform_visuals: Array[Dictionary] = []   # {pos, size} for drawing
var _camera: Camera2D

# ── State ─────────────────────────────────────────────────────────
enum Phase { GHOST_PLAYING, PLAYER_ACTIVE, DEAD, LEVEL_COMPLETE, GAME_OVER }
var _phase: Phase = Phase.GHOST_PLAYING
var _current_level_data: Dictionary = {}
var _respawn_timer: float = 0.0
var _level_complete_timer: float = 0.0
var _stars: Array[Dictionary] = []
var _grid_offset: Vector2 = Vector2.ZERO
var _death_particles: Array[Dictionary] = []
var _shake_amount: float = 0.0
var _shake_timer: float = 0.0
var _goal_pulse: float = 0.0

# ── Lifecycle ──────────────────────────────────────────────────────
func _ready() -> void:
	_generate_stars()
	_build_world()
	GameState.start_run()
	_load_level(0)

func _build_world() -> void:
	# Camera
	_camera = Camera2D.new()
	_camera.position = Vector2(960, 540)
	_camera.zoom = Vector2(1, 1)
	add_child(_camera)
	_camera.make_current()

	# Platforms container
	_platforms_node = Node2D.new()
	add_child(_platforms_node)

	# Goal
	_goal = Node2D.new()
	_goal_sprite = Node2D.new()
	_goal.add_child(_goal_sprite)
	add_child(_goal)

	# Goal collision (Area2D to detect player arrival)
	var goal_area := Area2D.new()
	var goal_col := CollisionShape2D.new()
	var goal_shape := RectangleShape2D.new()
	goal_shape.size = Vector2(40, 60)
	goal_col.shape = goal_shape
	goal_col.position = Vector2(0, -30)
	goal_area.add_child(goal_col)
	goal_area.collision_layer = 0
	goal_area.collision_mask = 1
	goal_area.body_entered.connect(_on_goal_reached)
	_goal.add_child(goal_area)

	# Ghost
	_ghost = Ghost.new()
	add_child(_ghost)

	# Player
	_player = Player.new()
	_player.collision_layer = 1
	_player.collision_mask = 1
	add_child(_player)
	_player.visible = false

	# Cheat engine
	_cheat_engine = CheatEngine.new()
	add_child(_cheat_engine)

	# HUD
	_hud = Hud.new()
	add_child(_hud)

	# Connect signals
	Events.player_died.connect(_on_player_died)
	Events.ghost_finished.connect(_on_ghost_finished)

# ── Level loading ──────────────────────────────────────────────────
func _load_level(idx: int) -> void:
	GameState.current_level = idx
	GameState.current_attempt = 0
	_current_level_data = LevelData.get_level(idx)

	# Clear old platforms
	for child in _platforms_node.get_children():
		child.queue_free()
	_platform_bodies.clear()
	_platform_visuals.clear()

	# Build platforms
	for plat in _current_level_data.platforms:
		var body := StaticBody2D.new()
		body.collision_layer = 1
		var col := CollisionShape2D.new()
		var shape := RectangleShape2D.new()
		shape.size = plat.size
		col.shape = shape
		body.add_child(col)
		body.global_position = plat.pos
		_platforms_node.add_child(body)
		_platform_bodies.append(body)
		_platform_visuals.append({"pos": plat.pos, "size": plat.size})

	# Goal position
	_goal.global_position = _current_level_data.goal

	# Setup cheat engine
	_cheat_engine.setup(_player, _platform_bodies, _goal)

	# Ghost replay
	_ghost.load_path(_current_level_data.ghost_path)

	# HUD
	_hud.set_level(idx, LevelData.get_level_name(idx))
	_hud.hide_cheats_reveal()

	# Narrator intro
	Narrator.clear()
	Narrator.say_intro(idx)

	# Position player at spawn but hidden
	_player.revive(_current_level_data.spawn)
	_player.visible = false
	_player.frozen = true

	# Play ghost first
	_phase = Phase.GHOST_PLAYING
	_ghost.start()

	Events.level_started.emit(idx)

func _start_attempt() -> void:
	GameState.start_attempt()
	_hud.set_attempt(GameState.current_attempt)
	_hud.hide_cheats_reveal()

	# Revive player
	_player.revive(_current_level_data.spawn)
	_player.visible = true
	_player.frozen = false

	# Load cheats for this attempt
	var cheats := LevelData.get_cheats_for_attempt(_current_level_data, GameState.current_attempt)
	_cheat_engine.load_cheats(cheats)

	_phase = Phase.PLAYER_ACTIVE
	Events.attempt_started.emit(GameState.current_attempt)

# ── Frame ──────────────────────────────────────────────────────────
func _physics_process(delta: float) -> void:
	match _phase:
		Phase.PLAYER_ACTIVE:
			_cheat_engine.process_cheats(delta)
			_check_goal_proximity()
		Phase.DEAD:
			_respawn_timer -= delta
			if _respawn_timer <= 0:
				_start_attempt()
		Phase.LEVEL_COMPLETE:
			_level_complete_timer -= delta
			if _level_complete_timer <= 0 and Input.is_action_just_pressed("jump"):
				_advance_to_next_level()

	# Shake decay
	if _shake_timer > 0:
		_shake_timer -= delta
		_camera.offset = Vector2(
			randf_range(-_shake_amount, _shake_amount),
			randf_range(-_shake_amount, _shake_amount)
		) * (_shake_timer / 0.3)
	else:
		_camera.offset = Vector2.ZERO

	# Goal pulse animation
	_goal_pulse += delta * 3.0

	# Death particles
	for i in range(_death_particles.size() - 1, -1, -1):
		var p: Dictionary = _death_particles[i]
		p.pos += p.vel * delta
		p.vel.y += 600.0 * delta
		p.life -= delta
		if p.life <= 0:
			_death_particles.remove_at(i)

	queue_redraw()

func _process(_delta: float) -> void:
	if Input.is_action_just_pressed("restart"):
		if _phase == Phase.PLAYER_ACTIVE or _phase == Phase.DEAD:
			_player.die()
		elif _phase == Phase.GAME_OVER:
			_restart_game()

	if Input.is_action_just_pressed("pause"):
		if _phase == Phase.GAME_OVER:
			get_tree().change_scene_to_file("res://scenes/main_menu.tscn")

# ── Events ─────────────────────────────────────────────────────────
func _on_ghost_finished() -> void:
	# Ghost done — give control to player
	_start_attempt()

func _on_player_died(pos: Vector2) -> void:
	if _phase != Phase.PLAYER_ACTIVE:
		return
	_phase = Phase.DEAD
	GameState.record_death()
	_player.visible = false

	# Death particles
	_spawn_death_particles(pos)
	_do_shake(8.0, 0.25)

	# Narrator death comment
	Narrator.say_death(GameState.current_level, GameState.current_attempt)

	_respawn_timer = 1.0

	# Reset cheat transient state
	_cheat_engine.cleanup()

func _on_goal_reached(body: Node2D) -> void:
	if body != _player or _phase != Phase.PLAYER_ACTIVE:
		return
	_phase = Phase.LEVEL_COMPLETE
	_player.frozen = true
	GameState.record_completion()

	Sfx.play("goal")
	_do_shake(4.0, 0.2)

	# Narrator victory
	Narrator.say_victory(GameState.current_level, GameState.current_attempt)

	# Show cheats reveal after a beat
	_level_complete_timer = 1.5
	if GameState.cheats_log.size() > 0:
		get_tree().create_timer(1.8).timeout.connect(func():
			_hud.show_cheats_reveal(
				GameState.cheats_log,
				GameState.current_attempt
			)
		)
	elif GameState.current_attempt <= 1:
		get_tree().create_timer(1.5).timeout.connect(func():
			_hud.show_banner("FIRST TRY?!")
		)

func _advance_to_next_level() -> void:
	_cheat_engine.cleanup()
	Narrator.clear()
	_hud.hide_cheats_reveal()

	if GameState.advance_level():
		_load_level(GameState.current_level)
	else:
		_show_game_over()

func _show_game_over() -> void:
	_phase = Phase.GAME_OVER
	GameState.is_run_active = false
	_player.visible = false

	Narrator.clear()
	Narrator.say("You beat a game that was actively cheating against you. I have nothing left.", 6.0)

	_hud.show_banner("YOU WIN")

	Events.game_completed.emit(GameState.total_deaths, GameState.run_timer)

	# Show final stats after narrator
	get_tree().create_timer(7.0).timeout.connect(func():
		var cheats_all: Array[String] = [
			"Invisible walls", "Hidden floor gaps", "Gravity spikes mid-jump",
			"Controls reversed mid-run", "Goal runs away from you",
			"Gradual speed drain", "Shrunken platforms", "Platforms drift sideways",
			"Invisible headwind", "Coyote time removed", "Ceiling pushes you down",
			"Bouncy floor patches",
		]
		_hud.show_cheats_reveal(cheats_all, GameState.total_deaths)
		Narrator.say("Press ESC for menu. Or R to suffer again.", 10.0)
	)

func _restart_game() -> void:
	_cheat_engine.cleanup()
	Narrator.clear()
	_hud.hide_cheats_reveal()
	GameState.start_run()
	_load_level(0)

func _check_goal_proximity() -> void:
	if not is_instance_valid(_player) or not is_instance_valid(_goal):
		return
	var dist := _player.global_position.distance_to(_goal.global_position)
	if dist < 200:
		_goal_pulse += 0.05   # faster pulse when close

# ── VFX ────────────────────────────────────────────────────────────
func _spawn_death_particles(pos: Vector2) -> void:
	for i in 20:
		_death_particles.append({
			"pos": pos,
			"vel": Vector2(randf_range(-300, 300), randf_range(-500, -100)),
			"life": randf_range(0.3, 0.8),
			"max_life": 0.8,
			"color": Color(1, 0.3, 0.2) if randf() > 0.3 else Color(1, 0.7, 0.3),
			"size": randf_range(3, 8),
		})

func _do_shake(strength: float, duration: float) -> void:
	_shake_amount = strength
	_shake_timer = duration

# ── Draw ───────────────────────────────────────────────────────────
func _draw() -> void:
	_draw_background()
	_draw_grid()
	_draw_platforms()
	_draw_goal()
	_draw_death_particles()

func _draw_background() -> void:
	# Stars
	for star in _stars:
		draw_circle(star.pos, star.size, Color(0.7, 0.75, 0.9, star.bright))

func _draw_grid() -> void:
	var grid_color := Color(1, 1, 1, 0.025)
	var spacing := 80.0
	for x in range(0, 1921, int(spacing)):
		draw_line(Vector2(x, 0), Vector2(x, 1080), grid_color, 1.0)
	for y in range(0, 1081, int(spacing)):
		draw_line(Vector2(0, y), Vector2(1920, y), grid_color, 1.0)

func _draw_platforms() -> void:
	# Draw the VISUAL platforms (not the collision — which may be cheated)
	for plat in _platform_visuals:
		var pos: Vector2 = plat.pos
		var sz: Vector2 = plat.size
		var rect := Rect2(pos - sz * 0.5, sz)

		# Main platform
		draw_rect(rect, Color(0.85, 0.83, 0.78, 0.9))
		# Top edge highlight
		draw_line(
			Vector2(rect.position.x, rect.position.y),
			Vector2(rect.position.x + rect.size.x, rect.position.y),
			Color(1, 1, 1, 0.3), 2.0
		)
		# Subtle bottom shadow
		draw_line(
			Vector2(rect.position.x, rect.end.y),
			Vector2(rect.end.x, rect.end.y),
			Color(0, 0, 0, 0.2), 1.0
		)

func _draw_goal() -> void:
	if not is_instance_valid(_goal):
		return
	var gp := _goal.global_position
	var pulse := sin(_goal_pulse) * 0.3 + 0.7

	# Glow
	var glow_size := 30.0 + pulse * 8.0
	draw_circle(Vector2(gp.x, gp.y - 30), glow_size, Color(1.0, 0.85, 0.2, 0.08 * pulse))
	draw_circle(Vector2(gp.x, gp.y - 30), glow_size * 0.6, Color(1.0, 0.85, 0.2, 0.12 * pulse))

	# Flag pole
	draw_line(Vector2(gp.x, gp.y), Vector2(gp.x, gp.y - 60), Color(0.8, 0.8, 0.8, 0.8), 2.0)
	# Flag
	var flag_color := Color(1.0, 0.8, 0.1, pulse)
	var flag_points := PackedVector2Array([
		Vector2(gp.x, gp.y - 60),
		Vector2(gp.x + 24, gp.y - 50),
		Vector2(gp.x, gp.y - 40),
	])
	draw_colored_polygon(flag_points, flag_color)

	# "GOAL" label
	draw_string(
		ThemeDB.fallback_font,
		Vector2(gp.x - 16, gp.y - 68),
		"GOAL", HORIZONTAL_ALIGNMENT_LEFT, -1, 10,
		Color(1, 0.9, 0.4, 0.5 * pulse)
	)

func _draw_death_particles() -> void:
	for p in _death_particles:
		var alpha := p.life / p.max_life
		draw_circle(p.pos, p.size * alpha, Color(p.color, alpha))

func _generate_stars() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 12345
	for i in 400:
		_stars.append({
			"pos": Vector2(rng.randf_range(0, 1920), rng.randf_range(0, 1080)),
			"bright": rng.randf_range(0.05, 0.4),
			"size": rng.randf_range(0.8, 2.0),
		})
