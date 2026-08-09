class_name SimPolicy
extends RefCounted

## A scripted "competent player" used by the headless harnesses.
##
## Deliberately simple: triage the worst failure, cool down when hot, brace when
## a shot is incoming, otherwise shoot. No lookahead and no cleverness, so it is
## a floor for what a human should manage rather than a ceiling. If this policy
## cannot win, the fight is unfair; if it always wins, the fight is a formality.

const DELTA := 1.0 / 60.0
const TIMEOUT_SECONDS := 300.0

## Heat at which the policy stops shooting and starts cooling.
const COOL_THRESHOLD := 72.0
const VENT_THRESHOLD := 88.0

## How fast the policy slews power. A human on a stick is not instant either.
const SLEW_RATE := 2.5


static func play_once(seed_value: int) -> Dictionary:
	var machine := Machine.new()
	var fight := Engagement.new(seed_value)
	var time := 0.0

	while time < TIMEOUT_SECONDS:
		var target := _choose_priority(machine, fight)
		if target >= 0:
			machine.adjust(target, SLEW_RATE * DELTA)

		var repair_target := _choose_repair(machine)
		if repair_target >= 0:
			machine.repair(repair_target, DELTA)
		else:
			machine.cancel_repair()

		if machine.heat > VENT_THRESHOLD:
			machine.vent()

		machine.step(DELTA)
		fight.step(DELTA, machine)
		time += DELTA

		if not machine.alive:
			var reason := "thermal" if machine.heat >= Balance.max_heat else "structure"
			return {"won": false, "reason": reason, "time": time, "structure": 0.0}
		if fight.enemy_hp <= 0.0:
			return {"won": true, "reason": "", "time": time, "structure": machine.structure}

	return {"won": false, "reason": "timeout", "time": time, "structure": machine.structure}


## Run many seeds and summarise. Returns win rate, timings and loss causes.
static func measure(runs: int, base_seed: int = 1) -> Dictionary:
	var wins := 0
	var total_time := 0.0
	var total_structure := 0.0
	var reasons := {}
	var shortest := INF
	var longest := 0.0

	for i in runs:
		var result := play_once(base_seed + i)
		if result["won"]:
			wins += 1
			total_time += result["time"]
			total_structure += result["structure"]
			shortest = minf(shortest, result["time"])
			longest = maxf(longest, result["time"])
		else:
			var reason: String = result["reason"]
			reasons[reason] = int(reasons.get(reason, 0)) + 1

	return {
		"runs": runs,
		"wins": wins,
		"win_rate": float(wins) / float(runs) * 100.0,
		"avg_time": total_time / float(wins) if wins > 0 else 0.0,
		"shortest": shortest if wins > 0 else 0.0,
		"longest": longest,
		"avg_structure_pct":
		(total_structure / float(wins)) / Balance.max_structure * 100.0 if wins > 0 else 0.0,
		"reasons": reasons,
	}


static func _choose_priority(machine: Machine, fight: Engagement) -> int:
	if machine.heat > COOL_THRESHOLD:
		return Machine.System.COOLANT
	if fight.charging_now:
		return Machine.System.SERVOS
	return Machine.System.WEAPONS


static func _choose_repair(machine: Machine) -> int:
	if machine.reactor_scrammed:
		return Machine.System.WEAPONS
	for system in Machine.SYSTEM_COUNT:
		if machine.fires[system]:
			return system
	for system in Machine.SYSTEM_COUNT:
		if machine.breaker_tripped[system]:
			return system
	for system in Machine.SYSTEM_COUNT:
		if machine.line_ruptured[system]:
			return system
	return -1
