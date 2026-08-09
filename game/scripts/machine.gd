class_name Machine
extends RefCounted

## The machine you are keeping alive.
##
## Pure simulation: no nodes, no rendering, no input. Everything here can be run
## headlessly at speed, which is how the balance gets tested without a human.
##
## The design tension lives in one scarce resource. The reactor makes power;
## weapons, coolant and servos all want it, and none of them can be starved for
## free. Weapons win the fight but make heat. Coolant removes heat but does
## nothing to end the engagement. Servos avoid damage but only if you can spare
## the power, and everything you lose stays lost until you spend time fixing it.

signal component_failed(failure: int, system: int)
signal component_repaired(system: int)
signal thermal_warning(active: bool)
signal destroyed(reason: String)

enum System { WEAPONS, COOLANT, SERVOS }

enum Failure {
	BREAKER_TRIPPED,  ## System gets no power until the breaker is reset.
	LINE_RUPTURED,  ## System runs at reduced efficiency until patched.
	FIRE,  ## Adds heat continuously until extinguished.
	REACTOR_SCRAM,  ## Total power output collapses until the reactor is restarted.
}

const SYSTEM_COUNT := 3

## Seconds of held repair to clear each failure. Repairs are slow enough that
## choosing what to fix first is a real decision under fire.
const REPAIR_SECONDS := {
	Failure.BREAKER_TRIPPED: 1.2,
	Failure.LINE_RUPTURED: 3.0,
	Failure.FIRE: 2.0,
	Failure.REACTOR_SCRAM: 4.0,
}

var structure := Balance.max_structure
var heat := 0.0
var alive := true

## Power allocation per system, always renormalised to sum to 1.0. The player
## never adds power, only decides who goes without.
var allocation := [0.34, 0.33, 0.33]

var breaker_tripped := [false, false, false]
var line_ruptured := [false, false, false]
var fires := [false, false, false]
var reactor_scrammed := false

var vent_cooldown := 0.0
var weapon_lockout := 0.0

var _repair_system := -1
var _repair_progress := 0.0
var _thermal_warned := false


## Fraction of nominal power the reactor is actually producing.
func power_output() -> float:
	return Balance.scram_power_factor if reactor_scrammed else 1.0


## Effective output of one system, 0.0 to 1.0, after allocation and damage.
## This is the number every gameplay effect reads, so all damage lands here.
func system_output(system: int) -> float:
	if breaker_tripped[system]:
		return 0.0
	var out: float = allocation[system] * power_output()
	if line_ruptured[system]:
		out *= Balance.rupture_efficiency
	if system == System.WEAPONS and weapon_lockout > 0.0:
		return 0.0
	return out


## Chance an incoming shot misses entirely.
func evasion() -> float:
	return Balance.max_evasion * system_output(System.SERVOS)


## Damage per second currently being delivered to the enemy.
func weapon_damage() -> float:
	return Balance.weapon_damage_rate * system_output(System.WEAPONS)


## Shift power toward one system, taking it proportionally from the others.
## Allocation always sums to 1.0, so there is no "more power" button.
func adjust(system: int, amount: float) -> void:
	var target: float = clampf(allocation[system] + amount, 0.0, 1.0)
	var remainder := 1.0 - target
	var others_total := 0.0
	for i in SYSTEM_COUNT:
		if i != system:
			others_total += allocation[i]
	for i in SYSTEM_COUNT:
		if i == system:
			allocation[i] = target
		elif others_total > 0.0:
			allocation[i] = allocation[i] / others_total * remainder
		else:
			allocation[i] = remainder / (SYSTEM_COUNT - 1)


## Dump heat overboard. Cheap in the moment, expensive immediately after,
## because the weapons go cold exactly when you were winning.
func vent() -> bool:
	if vent_cooldown > 0.0 or not alive:
		return false
	heat = maxf(0.0, heat - Balance.vent_heat_removed)
	weapon_lockout = Balance.vent_weapon_lockout
	vent_cooldown = Balance.vent_cooldown
	return true


## True when this system has something the player could repair.
func has_failure(system: int) -> bool:
	return (
		breaker_tripped[system]
		or line_ruptured[system]
		or fires[system]
		or (reactor_scrammed and system == System.WEAPONS)
	)


## The failure a repair on this system would address, worst first.
func pending_failure(system: int) -> int:
	if reactor_scrammed and system == System.WEAPONS:
		return Failure.REACTOR_SCRAM
	if fires[system]:
		return Failure.FIRE
	if breaker_tripped[system]:
		return Failure.BREAKER_TRIPPED
	if line_ruptured[system]:
		return Failure.LINE_RUPTURED
	return -1


## Hold a repair on one system. Releasing loses the progress, which is what
## makes a long repair under fire a gamble rather than a chore.
func repair(system: int, delta: float) -> void:
	if not has_failure(system):
		_repair_system = -1
		_repair_progress = 0.0
		return
	if system != _repair_system:
		_repair_system = system
		_repair_progress = 0.0
	_repair_progress += delta
	var failure := pending_failure(system)
	if _repair_progress < float(REPAIR_SECONDS[failure]):
		return
	match failure:
		Failure.REACTOR_SCRAM:
			reactor_scrammed = false
		Failure.FIRE:
			fires[system] = false
		Failure.BREAKER_TRIPPED:
			breaker_tripped[system] = false
		Failure.LINE_RUPTURED:
			line_ruptured[system] = false
	_repair_progress = 0.0
	component_repaired.emit(system)


func cancel_repair() -> void:
	_repair_system = -1
	_repair_progress = 0.0


func repair_fraction() -> float:
	if _repair_system < 0:
		return 0.0
	var failure := pending_failure(_repair_system)
	if failure < 0:
		return 0.0
	return clampf(_repair_progress / float(REPAIR_SECONDS[failure]), 0.0, 1.0)


func repairing_system() -> int:
	return _repair_system


## Apply an incoming hit. Structure loss is the visible cost; the component
## failure is the one that actually decides the fight.
func take_hit(damage: float, failure: int, system: int) -> void:
	if not alive:
		return
	structure = maxf(0.0, structure - damage)
	match failure:
		Failure.BREAKER_TRIPPED:
			breaker_tripped[system] = true
		Failure.LINE_RUPTURED:
			line_ruptured[system] = true
		Failure.FIRE:
			fires[system] = true
		Failure.REACTOR_SCRAM:
			reactor_scrammed = true
	component_failed.emit(failure, system)
	if structure <= 0.0:
		alive = false
		destroyed.emit("structural failure")


func step(delta: float) -> void:
	if not alive:
		return

	vent_cooldown = maxf(0.0, vent_cooldown - delta)
	weapon_lockout = maxf(0.0, weapon_lockout - delta)

	var generated := Balance.reactor_heat_rate * power_output()
	generated += Balance.weapon_heat_rate * system_output(System.WEAPONS)
	for system in SYSTEM_COUNT:
		if fires[system]:
			generated += Balance.fire_heat_rate
	var removed := Balance.coolant_heat_rate * system_output(System.COOLANT)
	heat = clampf(heat + (generated - removed) * delta, 0.0, Balance.max_heat)

	var warning := heat >= Balance.max_heat * 0.75
	if warning != _thermal_warned:
		_thermal_warned = warning
		thermal_warning.emit(warning)

	# Overheating does not kill you directly. It cooks the structure, which
	# gives you a few seconds to do something about it and makes the death a
	# consequence you watched arrive rather than a rule you tripped over.
	if heat >= Balance.max_heat:
		structure = maxf(0.0, structure - Balance.overheat_damage * delta)
		if structure <= 0.0:
			alive = false
			destroyed.emit("thermal runaway")


## Compact state for logging and headless balance runs.
func snapshot() -> Dictionary:
	return {
		"structure": structure,
		"heat": heat,
		"alive": alive,
		"power": power_output(),
		"weapons": system_output(System.WEAPONS),
		"coolant": system_output(System.COOLANT),
		"servos": system_output(System.SERVOS),
		"dps": weapon_damage(),
		"evasion": evasion(),
	}
