extends SceneTree

## Sweep the two dials that decide difficulty and print the grid.
##
## Enemy HP sets how long the fight lasts; structure sets how much punishment
## the machine absorbs while it does. Everything else is downstream of those
## two, so sweeping them finds the shape of the difficulty surface rather than
## one lucky point on it.
##
##   godot --headless --path game --script res://tests/balance_sweep.gd
##
## Optional: --runs=N (per cell; default 60)

const TARGET_LOW := 45.0
const TARGET_HIGH := 70.0

const ENEMY_HP_VALUES: Array[float] = [330.0, 380.0, 430.0, 480.0]
const STRUCTURE_VALUES: Array[float] = [100.0, 120.0, 140.0, 160.0]


func _initialize() -> void:
	var runs := 60
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--runs="):
			runs = int(arg.trim_prefix("--runs="))

	print("win%% by enemy HP (rows) x structure (cols), %d runs per cell" % runs)
	var header := "        "
	for structure in STRUCTURE_VALUES:
		header += "%9s" % ("str %d" % int(structure))
	print(header)

	var best := {}
	var best_distance := INF

	for enemy_hp in ENEMY_HP_VALUES:
		var line := "hp %-5d" % int(enemy_hp)
		for structure in STRUCTURE_VALUES:
			Balance.reset()
			Balance.enemy_hp = enemy_hp
			Balance.max_structure = structure
			var result := SimPolicy.measure(runs)
			var rate: float = result["win_rate"]
			line += "%8.0f%%" % rate

			# Prefer the cell nearest the middle of the target band, and among
			# equals prefer the longer fight — a 90-second engagement has room
			# for a story, a 40-second one does not.
			var midpoint := (TARGET_LOW + TARGET_HIGH) * 0.5
			var distance: float = absf(rate - midpoint)
			if distance < best_distance:
				best_distance = distance
				best = {
					"enemy_hp": enemy_hp,
					"structure": structure,
					"rate": rate,
					"avg_time": result["avg_time"],
					"avg_structure_pct": result["avg_structure_pct"],
					"reasons": result["reasons"],
				}
		print(line)

	Balance.reset()

	print("\nbest cell: enemy_hp=%d structure=%d" % [int(best["enemy_hp"]), int(best["structure"])])
	print(
		(
			"  win rate          %.0f%%   (target %.0f-%.0f%%)"
			% [best["rate"], TARGET_LOW, TARGET_HIGH]
		)
	)
	print("  avg win time      %.0fs" % best["avg_time"])
	print("  avg structure at win  %.0f%%" % best["avg_structure_pct"])
	print("  losses            %s" % [best["reasons"]])
	quit(0)
