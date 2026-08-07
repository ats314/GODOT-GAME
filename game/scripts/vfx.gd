extends Node
## Self-contained VFX autoload: listens to the Events bus and spawns
## one-shot particle bursts into the current scene. Nothing else needs to
## know it exists — juice stays decoupled from game logic.

func _ready() -> void:
	Events.enemy_killed.connect(_on_enemy_killed)
	Events.core_damaged.connect(_on_core_damaged)
	Events.ring_level_up.connect(_on_ring_level_up)

func _on_enemy_killed(pos: Vector2) -> void:
	_burst(pos, 26, Color(1.6, 0.7, 0.5), 320.0, 0.45)

func _on_core_damaged(_hp: int, _max_hp: int) -> void:
	var core := get_tree().get_first_node_in_group(&"core_group") as Node2D
	if core != null:
		_burst(core.global_position, 40, Color(1.8, 0.4, 0.35), 420.0, 0.6)

func _on_ring_level_up(_level: int) -> void:
	var core := get_tree().get_first_node_in_group(&"core_group") as Node2D
	if core != null:
		_burst(core.global_position, 60, Color(0.6, 1.6, 1.8), 500.0, 0.8)

func _burst(pos: Vector2, amount: int, color: Color, speed: float, life: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.global_position = pos
	p.emitting = false
	p.one_shot = true
	p.explosiveness = 1.0
	p.amount = amount
	p.lifetime = life
	p.direction = Vector2.RIGHT
	p.spread = 180.0
	p.gravity = Vector2.ZERO
	p.initial_velocity_min = speed * 0.35
	p.initial_velocity_max = speed
	p.damping_min = speed * 1.2
	p.damping_max = speed * 2.2
	p.scale_amount_min = 1.6
	p.scale_amount_max = 3.4
	p.color = color
	p.finished.connect(p.queue_free)
	scene.add_child(p)
	p.emitting = true
