extends SceneTree

## Headless balance check for the current shipping numbers.
##
## This is the one thing about a game a GPU-less container can genuinely
## measure. If a scripted competent policy wins every time the fight is a
## formality; if it never wins the fight is a wall. We want it winning most of
## the time and losing when it gets unlucky, because that is the band where the
## player's decisions are what decides the outcome.
##
##   godot --headless --path game --script res://tests/balance_run.gd -- --runs=200
##
## Exits non-zero outside the target band, so CI can hold the line.

const TARGET_LOW := 35.0
const TARGET_HIGH := 90.0


func _initialize() -> void:
	var runs := 200
	var base_seed := 1
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = int(arg.trim_prefix("--runs="))
		elif arg.begins_with("--seed="):
			base_seed = int(arg.trim_prefix("--seed="))

	var result := SimPolicy.measure(runs, base_seed)
	print("runs                %d" % result["runs"])
	print("win rate            %.1f%%" % result["win_rate"])
	if result["wins"] > 0:
		print(
			(
				"avg win time        %.1fs  (fastest %.1fs, slowest %.1fs)"
				% [result["avg_time"], result["shortest"], result["longest"]]
			)
		)
		print("avg structure left  %.0f%%" % result["avg_structure_pct"])
	for reason in result["reasons"]:
		print("loss: %-16s %d" % [reason, result["reasons"][reason]])

	var rate: float = result["win_rate"]
	if rate < TARGET_LOW:
		print("\nVERDICT: too punishing — a competent policy should win more than a third.")
		quit(1)
	elif rate > TARGET_HIGH:
		print("\nVERDICT: too soft — a scripted policy should not nearly always win.")
		quit(1)
	print("\nVERDICT: inside the target band (%.0f-%.0f%%)." % [TARGET_LOW, TARGET_HIGH])
	quit(0)
