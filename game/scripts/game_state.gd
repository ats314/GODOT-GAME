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
var owned: Dictionary = {}          # upgrade id -> times picked (shown on cards + HUD)
var last_upgrade: StringName = &""  # what the confirmation toast reports
var last_change: Array = []         # before/after rows for that pick

const DEFAULT_MODS := {
	beam_power = 26.0,      # beam damage per second
	beam_width = 10.0,
	beam_pierce = 0.35,     # damage fraction carried to enemies behind the first
	magnet_radius = 220.0,
	turret_power = 14.0,    # damage per shot
	turret_rate = 0.9,      # seconds between shots
	turret_count = 1,
	shard_bounty = 0,       # extra shards per kill
	nova_power = 8.0,       # area damage dealt by every kill (chain reactions)
	nova_radius = 85.0,
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
	owned = {}
	last_upgrade = &""
	last_change = []

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
	# snapshot the before/after the card just promised, so the HUD can echo the
	# exact same numbers back once the pick lands
	last_upgrade = id
	last_change = Upgrades.preview(id, mods)
	Upgrades.apply_to(mods, id)
	owned[id] = int(owned.get(id, 0)) + 1
	Events.upgrade_chosen.emit(id)

## Owned upgrades as {id, title, cat, count}, in the order they were first
## picked — the player's build, for the HUD readout and the end-of-run recap.
func build_summary() -> Array:
	var rows := []
	for id in owned:
		var u := Upgrades.by_id(id)
		if u.is_empty():
			continue
		rows.append({id = id, title = u.title, cat = u.cat, count = int(owned[id])})
	return rows

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
