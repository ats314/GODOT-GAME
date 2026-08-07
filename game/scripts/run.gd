extends Node2D
## Run orchestrator. This root node runs ALWAYS so pause can be un-paused
## (a pausable node that pauses the tree freezes itself — review finding);
## gameplay children are explicitly PAUSABLE.

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
var pause_overlay: CanvasLayer

var _shake := 0.0
var _kill_times: Array[float] = []
var _over := false
var _pending_cards := 0

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	GameState.reset_run()
	_build_world()
	_build_ui()
	Events.ring_level_up.connect(_on_level_up)
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.core_damaged.connect(_on_core_damaged)
	Events.upgrade_chosen.connect(_on_upgrade_chosen)

func _gameplay(node: Node) -> Node:
	# children of an ALWAYS root inherit ALWAYS; gameplay must pause
	node.process_mode = Node.PROCESS_MODE_PAUSABLE
	add_child(node)
	return node

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

	add_child(_make_nebula())
	add_child(_make_starfield())

	shard_field = ShardField.new()
	_gameplay(shard_field)

	core = Core.new()
	_gameplay(core)
	shard_field.core = core

	enemies_parent = Node2D.new()
	_gameplay(enemies_parent)

	turrets_parent = Node2D.new()
	_gameplay(turrets_parent)
	_sync_turrets()

	spawner = Spawner.new()
	spawner.core = core
	spawner.shard_field = shard_field
	spawner.enemies_parent = enemies_parent
	_gameplay(spawner)

	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	add_child(camera)
	camera.make_current()

func _make_nebula() -> Node2D:
	# two tinted seamless-noise clouds; generated once, no assets
	var holder := Node2D.new()
	holder.z_index = -20
	var noise := FastNoiseLite.new()
	noise.seed = 11
	noise.frequency = 0.006
	noise.fractal_octaves = 4
	var img := noise.get_seamless_image(256, 256)
	for layer in 2:
		var tinted := Image.create(256, 256, false, Image.FORMAT_RGBA8)
		var tint := Color(0.10, 0.25, 0.38) if layer == 0 else Color(0.22, 0.12, 0.34)
		for y in 256:
			for x in 256:
				var v := img.get_pixel((x + layer * 97) % 256, y).r
				var a := clampf(pow(v, 2.2) * 0.9, 0.0, 0.55)
				tinted.set_pixel(x, y, Color(tint.r, tint.g, tint.b, a))
		var spr := Sprite2D.new()
		spr.texture = ImageTexture.create_from_image(tinted)
		spr.scale = Vector2.ONE * (14.0 + layer * 6.0)
		spr.rotation = layer * 1.9
		spr.modulate.a = 0.75
		holder.add_child(spr)
	return holder

func _make_starfield() -> Node2D:
	var stars := Node2D.new()
	stars.z_index = -10
	var draw_stars := func(canvas: Node2D) -> void:
		var rng := RandomNumberGenerator.new()
		rng.seed = 7
		for i in 700:
			var p := Vector2(rng.randf_range(-2400, 2400), rng.randf_range(-1500, 1500))
			var b := rng.randf_range(0.2, 0.9)
			var r := rng.randf_range(0.8, 2.6)
			canvas.draw_circle(p, r * 2.2, Color(b, b, b, 0.10))
			canvas.draw_circle(p, r, Color(b, b * 0.98, minf(b * 1.15, 1.0), 0.9))
	stars.draw.connect(draw_stars.bind(stars))
	return stars

func _build_ui() -> void:
	hud = preload("res://scripts/hud.gd").new()
	add_child(hud)
	upgrade_overlay = preload("res://scripts/upgrade_overlay.gd").new()
	add_child(upgrade_overlay)
	game_over_overlay = preload("res://scripts/game_over.gd").new()
	add_child(game_over_overlay)
	pause_overlay = _make_pause_overlay()
	add_child(pause_overlay)

func _make_pause_overlay() -> CanvasLayer:
	var layer_node := CanvasLayer.new()
	layer_node.layer = 15
	layer_node.visible = false
	var dim := ColorRect.new()
	dim.color = Color(0.0, 0.02, 0.05, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_node.add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	layer_node.add_child(center)
	var l := Label.new()
	l.text = "PAUSED\nStart / Esc to resume"
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.add_theme_font_size_override(&"font_size", 42)
	l.add_theme_color_override(&"font_color", Color(0.75, 0.97, 1.0))
	center.add_child(l)
	return layer_node

func _process(delta: float) -> void:
	_shake = maxf(0.0, _shake - delta * 3.5)
	camera.offset = Vector2(randf_range(-1, 1), randf_range(-1, 1)) * _shake * 14.0
	var target_zoom := clampf(560.0 / (core.ring_radius() + 360.0), 0.85, 1.45)
	camera.zoom = camera.zoom.lerp(Vector2.ONE * target_zoom, delta * 2.0)
	if Input.is_action_just_pressed(&"restart") and not upgrade_overlay.visible:
		_restart()
	if Input.is_action_just_pressed(&"pause") and not _over and not upgrade_overlay.visible:
		var paused := not get_tree().paused
		get_tree().paused = paused
		pause_overlay.visible = paused
		Sfx.play(&"ui", 0.8 if paused else 1.2, -6.0)

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

func _on_level_up(_level: int) -> void:
	Sfx.play(&"levelup")
	_sync_turrets()
	_pending_cards += 1
	if not upgrade_overlay.visible:
		_show_next_cards()

func _show_next_cards() -> void:
	var options := []
	var pool := UPGRADE_POOL.duplicate()
	if GameState.mods.turret_count >= 8:
		pool = pool.filter(func(u: Dictionary) -> bool: return u.id != &"turret_add")
	pool.shuffle()
	for i in 3:
		options.append(pool[i])
	get_tree().paused = true
	var shown_level: int = GameState.ring_level - _pending_cards + 1
	upgrade_overlay.call(&"show_options", options, shown_level)

func _on_upgrade_chosen(id: StringName) -> void:
	_pending_cards -= 1
	if id == &"turret_add":
		_sync_turrets()
	if id == &"plating":
		core.heal_full_segment()
	core.queue_redraw()
	if _pending_cards > 0:
		_show_next_cards()
	else:
		get_tree().paused = false

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
