extends Node
## Tracks run-wide state: current level, attempts, deaths, times.

var current_level: int = 0
var current_attempt: int = 0
var total_deaths: int = 0
var level_attempts: Dictionary = {}   # level_idx -> int
var level_times: Dictionary = {}      # level_idx -> float (best)
var level_timer: float = 0.0
var run_timer: float = 0.0
var is_run_active: bool = false
var cheats_log: Array[String] = []    # cheats experienced this attempt

const TOTAL_LEVELS: int = 5

func start_run() -> void:
	current_level = 0
	current_attempt = 0
	total_deaths = 0
	level_attempts.clear()
	level_times.clear()
	run_timer = 0.0
	is_run_active = true

func start_attempt() -> void:
	current_attempt += 1
	level_attempts[current_level] = current_attempt
	level_timer = 0.0
	cheats_log.clear()

func record_death() -> void:
	total_deaths += 1

func record_completion() -> void:
	if current_level not in level_times or level_timer < level_times[current_level]:
		level_times[current_level] = level_timer

func advance_level() -> bool:
	## Returns true if there are more levels; false if game complete.
	current_level += 1
	current_attempt = 0
	return current_level < TOTAL_LEVELS

func log_cheat(cheat_name: String) -> void:
	if cheat_name not in cheats_log:
		cheats_log.append(cheat_name)

func _process(delta: float) -> void:
	if is_run_active:
		run_timer += delta
		level_timer += delta

func format_time(t: float) -> String:
	var mins := int(t) / 60
	var secs := fmod(t, 60.0)
	if mins > 0:
		return "%d:%05.2f" % [mins, secs]
	return "%.2fs" % secs
