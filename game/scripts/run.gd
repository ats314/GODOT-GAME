extends Node2D
## Run orchestrator: builds the arena at runtime (glow environment, core,
## shard field, spawner, turrets, HUD, overlays), runs the level-up flow,
## camera growth/shake, hit-stop, and game over.

const UPGRADE_POOL := [
	{id = &"beam_power", title = "Focused Beam", desc = "+35% beam damage"},
	{id = &"beam_width", title = "Wide Aperture", desc = "+25% beam width"},
	{id = &"magnet", title = "Deep Gravity", desc = "+30% magnet radius"},
	{id = &"turret_add", title = "New Hardpoint", desc = "Crystallize another turret"},
	{id = &"turret_power", title = "Charged Lattice", desc = "+30% turret damage"},
	{id = &"turret_rate", title = "Rapid Discharge", desc = "Turrets fire 22% faster"},
	{id = &"plating", title = "Core Plating", desc = "+1 max integrity, restore 1"},
	{id = &"bounty", title = "Rich Veins", desc = "+1 shard from every kill"},
]

var core: Core
var shard_field: ShardField
var spawner: Spawner
var enemies_parent: Node2D
var turrets_parent: Node2D
var camera: Camera2D
var hud: CanvasLayer
var upgrade_overlay: CanvasLayer
var game_over_overlay: CanvasLayer

var _shake := 0.0
var _kill_times: Array[float] = []
var _over := false

func _ready() -> void:
	GameState.reset_run()
	_build_world()
	_build_ui()
	Events.ring_level_up.connect(_on_level_up)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.core_damaged.connect(_on_core_damaged)
	Events.upgrade_chosen.connect(_on_upgrade_chosen)

func _build_world() -> void:
	var world_env := WorldEnvironment.new()
	var env := Environment.new()
	env.background_mode = Environment.BG_CANVAS
	env.tonemap_mode = Environment.TONE_MAPPER_AGX
	env.glow_enabled = true
	env.set("glow_levels/3", 0.4)
	env.set("glow_levels/5", 0.8)
	env.set("glow_levels/7", 0.3)
	env.glow_bloom = 0.1
	world_env.environment = env
	add_child(world_env)

	var stars := _make_starfield()
	add_child(stars)

	shard_field = ShardField.new()
	add_child(shard_field)

	core = Core.new()
	add_child(core)
	shard_field.core = core

	enemies_parent = Node2D.new()
	add_child(enemies_parent)

	turrets_parent = Node2D.new()
	add_child(turrets_parent)
	_sync_turrets()

	spawner = Spawner.new()
	spawner.core = core
	spawner.shard_field = shard_field
	spawner.enemies_parent = enemies_parent
	add_child(spawner)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)
	camera.make_current()

func _make_starfield() -> Node2D:
	var stars := Node2D.new()
	stars.z_index = -10
	var draw_stars := func(canvas: Node2D) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 260:
			var p := Vector2(rng.randf_range(-1700, 1700), rng.randf_range(-1100, 1100))
			var b := rng.randf_range(0.15, 0.7)
			canvas.draw_circle(p, rng.randf_range(1.0, 2.4), Color(b, b, b * 1.1, 0.8))
	stars.draw.connect(draw_stars.bind(stars))
	return stars

func _build_ui() -> void:
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	upgrade_overlay = preload("res://scripts/upgrade_overlay.gd").new()
	add_child(upgrade_overlay)
	game_over_overlay = preload("res://scripts/game_over.gd").new()
	add_child(game_over_overlay)

func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 3.5)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
	var target_zoom := clampf(340.0 / (core.ring_radius() + 300.0), 0.55, 1.0)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, delta * 2.0)
	if Input.is_action_just_pressed(&"restart") and not upgrade_overlay.visible:
		_restart()
	if Input.is_action_just_pressed(&"pause") and not _over and not upgrade_overlay.visible:
		get_tree().paused = not get_tree().paused

func _on_enemy_killed(_pos: Vector2) -> void:
	_shake = maxf(_shake, 0.35)
	var now := Time.get_ticks_msec() / 1000.0
	_kill_times.append(now)
	_kill_times = _kill_times.filter(func(t: float) -> bool: return now - t < 0.25)
	if _kill_times.size() >= 3:
		_kill_times.clear()
		_hit_stop()

func _hit_stop() -> void:
	Engine.time_scale = 0.05
	await get_tree().create_timer(0.07, true, false, true).timeout
	Engine.time_scale = 1.0

func _on_core_damaged(hp: int, _max_hp: int) -> void:
	_shake = 1.0
	if hp <= 0 and not _over:
		_game_over()

func _on_level_up(level: int) -> void:
	Sfx.play(&"levelup")
	_sync_turrets()
	var options := []
	var pool := UPGRADE_POOL.duplicate()
	if GameState.mods.turret_count >= 8:
		pool = pool.filter(func(u: Dictionary) -> bool: return u.id != &"turret_add")
	pool.shuffle()
	for i in 3:
		options.append(pool[i])
	get_tree().paused = true
	upgrade_overlay.call(&"show_options", options, level)

func _on_upgrade_chosen(id: StringName) -> void:
	get_tree().paused = false
	if id == &"turret_add":
		_sync_turrets()
	if id == &"plating":
		core.heal_full_segment()
	core.queue_redraw()

func _sync_turrets() -> void:
	while turrets_parent.get_child_count() < GameState.mods.turret_count:
		var t := Turret.new()
		t.core = core
		t.slot_index = turrets_parent.get_child_count()
		turrets_parent.add_child(t)

func _game_over() -> void:
	_over = true
	GameState.finish_run()
	spawner.set_process(false)
	get_tree().paused = true
	game_over_overlay.call(&"show_stats")

func _restart() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
