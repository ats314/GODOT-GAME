extends Node
## Headless soak test: proves both endings are actually reachable and that the
## payload rule bites. Run with:
##   godot --headless --path demos/highball res://scenes/soak.tscn
## Exits non-zero on failure so CI can gate on it.

const TIME_SCALE := 40.0
const GAME_SECONDS_LIMIT := 420.0

var phase := 0
var main: Node3D = null
var elapsed := 0.0
var failures: PackedStringArray = []


func _ready() -> void:
	Engine.time_scale = TIME_SCALE
	_start_phase()


func _start_phase() -> void:
	elapsed = 0.0
	main = load("res://scenes/main.tscn").instantiate()
	add_child(main)
	match phase:
		0:  # clean run: no faults, payload aboard — must reach the yard and win
			main.next_fault_at = 1.0e9
		1:  # plant starved: no fuel, no faults — must stall and lose
			main.next_fault_at = 1.0e9
			main.fuel = 5.0
		2:  # payload cut before the yard — survives the run, loses the game
			main.next_fault_at = 1.0e9
			main._cut(PAYLOAD_CUT_INDEX)


const PAYLOAD_CUT_INDEX := 7  ## cutting here drops cars 8..11, payload included


func _process(delta: float) -> void:
	if main == null:
		return
	elapsed += delta

	if elapsed > GAME_SECONDS_LIMIT:
		failures.append("phase %d: never resolved within %d game-seconds" % [phase, GAME_SECONDS_LIMIT])
		_next_phase()
		return
	if not main.over:
		return

	match phase:
		0:
			if not main.won:
				failures.append("phase 0: a clean run failed to win")
			else:
				print("phase 0 OK — clean run reached the yard in %.0fs, %d cars" % [elapsed, main.cars.size()])
		1:
			if main.won:
				failures.append("phase 1: won with a dead plant")
			else:
				print("phase 1 OK — starved plant stalled the train after %.0fs" % elapsed)
		2:
			if main.won:
				failures.append("phase 2: won without the payload")
			elif main.payload_aboard:
				failures.append("phase 2: cut did not drop the payload car")
			else:
				print("phase 2 OK — arrived without the payload, correctly not a win")
	_next_phase()


func _next_phase() -> void:
	main.queue_free()
	main = null
	phase += 1
	if phase > 2:
		_report()
		return
	await get_tree().process_frame
	_start_phase()


func _report() -> void:
	if failures.is_empty():
		print("SOAK PASS — win, loss and payload-loss endings all reachable")
		get_tree().quit(0)
	else:
		for f in failures:
			printerr("SOAK FAIL: %s" % f)
		get_tree().quit(1)
