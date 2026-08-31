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
	# every kill damages nearby enemies — draw that blast at its real radius so
	# the Bigger Kill Blast card describes something the player has seen
	_shockwave(pos, GameState.mods.nova_radius,
			clampf(GameState.mods.nova_power / 26.0, 0.22, 0.85))

func _on_core_damaged(_hp: int, _max_hp: int) -> void:
	var core := get_tree().get_first_node_in_group(&"core_group") as Node2D
	if core != null:
		_burst(core.global_position, 40, Color(1.8, 0.4, 0.35), 420.0, 0.6)

func _on_ring_level_up(_level: int) -> void:
	var core := get_tree().get_first_node_in_group(&"core_group") as Node2D
	if core != null:
		_burst(core.global_position, 60, Color(0.6, 1.6, 1.8), 500.0, 0.8)

## Expanding ring that traces the kill blast's actual reach. Brightness scales
## with nova_power, so upgrading it is legible on screen, not just on the card.
func _shockwave(pos: Vector2, radius: float, strength: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var ring := Node2D.new()
	ring.process_mode = Node.PROCESS_MODE_PAUSABLE
	ring.global_position = pos
	ring.z_index = 5
	var state := {t = 0.0}
	ring.draw.connect(func() -> void:
		var f: float = state.t
		ring.draw_arc(Vector2.ZERO, radius * (0.15 + 0.85 * f), 0.0, TAU, 40,
				Color(1.0, 0.62, 0.42, strength * (1.0 - f)), 1.0 + 3.0 * (1.0 - f), true))
	scene.add_child(ring)
	var tw := ring.create_tween()
	tw.tween_method(func(v: float) -> void:
		state.t = v
		ring.queue_redraw(), 0.0, 1.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tw.tween_callback(ring.queue_free)

func _burst(pos: Vector2, amount: int, color: Color, speed: float, life: float) -> void:
	var scene := get_tree().current_scene
	if scene == null:
		return
	var p := CPUParticles2D.new()
	p.process_mode = Node.PROCESS_MODE_PAUSABLE
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
