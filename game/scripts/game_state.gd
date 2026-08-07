extends Node
## Run economy + per-run upgrade modifiers + persistent best records.

const SAVE_PATH := "user://accrete.cfg"
const BASE_LEVEL_COST := 25.0
const LEVEL_COST_GROWTH := 1.35

# --- persistent ---
var best_mass: float = 0.0
var best_wave: int = 0

# --- run state ---
var mass: float = 0.0
var total_mass: float = 0.0
var ring_level: int = 0
var wave: int = 0
var run_time: float = 0.0
var mods: Dictionary = {}

const DEFAULT_MODS := {
	beam_power = 26.0,      # beam damage per second
	beam_width = 10.0,
	magnet_radius = 220.0,
	turret_power = 14.0,    # damage per shot
	turret_rate = 0.9,      # seconds between shots
	turret_count = 1,
	shard_bounty = 0,       # extra shards per kill
	max_hp = 5,
}

func _ready() -> void:
	load_persistent()
	reset_run()

func reset_run() -> void:
	mass = 0.0
	total_mass = 0.0
	ring_level = 0
	wave = 0
	run_time = 0.0
	mods = DEFAULT_MODS.duplicate()

func next_level_cost() -> float:
	return BASE_LEVEL_COST * pow(LEVEL_COST_GROWTH, ring_level)

func add_mass(amount: float) -> void:
	mass += amount
	total_mass += amount
	Events.mass_changed.emit(mass, amount)
	while mass >= next_level_cost():
		mass -= next_level_cost()
		ring_level += 1
		Events.ring_level_up.emit(ring_level)

func apply_upgrade(id: StringName) -> void:
	match id:
		&"beam_power": mods.beam_power *= 1.35
		&"beam_width": mods.beam_width *= 1.25
		&"magnet": mods.magnet_radius *= 1.3
		&"turret_add": mods.turret_count += 1
		&"turret_power": mods.turret_power *= 1.3
		&"turret_rate": mods.turret_rate = maxf(0.12, mods.turret_rate * 0.78)
		&"plating": mods.max_hp += 1
		&"bounty": mods.shard_bounty += 1
	Events.upgrade_chosen.emit(id)

func finish_run() -> void:
	best_mass = maxf(best_mass, total_mass)
	best_wave = maxi(best_wave, wave)
	save_persistent()

func load_persistent() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SAVE_PATH) == OK:
		best_mass = cfg.get_value("best", "mass", 0.0)
		best_wave = cfg.get_value("best", "wave", 0)

func save_persistent() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("best", "mass", best_mass)
	cfg.set_value("best", "wave", best_wave)
	cfg.save(SAVE_PATH)

static func fmt(n: float) -> String:
	var suffixes := ["", "k", "M", "B", "T"]
	var i := 0
	while absf(n) >= 1000.0 and i < suffixes.size() - 1:
		n /= 1000.0
		i += 1
	if i == 0:
		return str(int(n))
	return "%.2f%s" % [n, suffixes[i]]
