extends Node
## Global signal bus. Systems talk through these instead of node paths.

signal mass_changed(mass: float, delta: float)
signal ring_level_up(level: int)
signal upgrade_options(options: Array)
signal upgrade_chosen(id: StringName)
signal enemy_killed(pos: Vector2)
signal core_damaged(hp: int, max_hp: int)
signal wave_started(wave: int)
signal run_over(stats: Dictionary)
