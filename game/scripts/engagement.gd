class_name Engagement
extends RefCounted

## The fight happening outside, which you do not control.
##
## The player never aims and never chooses a target. This drives the machine's
## damage into the enemy automatically and fires back on a telegraphed rhythm:
## charge, then impact. The telegraph is the point — it gives you a window to
## dump power into the servos and brace, at the cost of whatever you took it
## from. Without it the game would be pure reaction; with it, every incoming
## shot is a small bet.
##
## Fully seeded, so a headless run reproduces exactly.

signal charging(seconds_to_impact: float)
signal shot_missed
signal shot_hit(damage: float, failure: int, system: int)
signal enemy_destroyed

var enemy_hp := Balance.enemy_hp
var elapsed := 0.0
var charging_now := false
var time_to_impact := 0.0
var shots_fired := 0
var shots_landed := 0

var _rng := RandomNumberGenerator.new()
var _next_shot := 3.0


func _init(seed_value: int = 0) -> void:
	_rng.seed = seed_value


func enemy_fraction() -> float:
	return enemy_hp / Balance.enemy_hp


## Interval between shots right now, shortening as the engagement drags on.
func current_interval() -> float:
	var t := clampf(elapsed / Balance.ramp_seconds, 0.0, 1.0)
	return lerpf(Balance.first_interval, Balance.final_interval, t)


## Which component a landed hit breaks. Weighted so that the cheap-to-fix
## failures are common and the run-ending one is rare but always possible.
func _roll_failure() -> Array:
	var roll := _rng.randf()
	var system := _rng.randi_range(0, Machine.SYSTEM_COUNT - 1)
	if roll < 0.40:
		return [Machine.Failure.BREAKER_TRIPPED, system]
	if roll < 0.72:
		return [Machine.Failure.LINE_RUPTURED, system]
	if roll < 0.92:
		return [Machine.Failure.FIRE, system]
	return [Machine.Failure.REACTOR_SCRAM, Machine.System.WEAPONS]


func step(delta: float, machine: Machine) -> void:
	if enemy_hp <= 0.0 or not machine.alive:
		return

	elapsed += delta

	enemy_hp = maxf(0.0, enemy_hp - machine.weapon_damage() * delta)
	if enemy_hp <= 0.0:
		enemy_destroyed.emit()
		return

	if charging_now:
		time_to_impact -= delta
		if time_to_impact > 0.0:
			return
		charging_now = false
		shots_fired += 1
		# Evasion is read at the moment of impact, not when the shot started,
		# so power moved during the telegraph genuinely matters.
		if _rng.randf() < machine.evasion():
			shot_missed.emit()
		else:
			shots_landed += 1
			var damage := Balance.base_damage + _rng.randf() * Balance.damage_variance
			var failure: Array = _roll_failure()
			machine.take_hit(damage, failure[0], failure[1])
			shot_hit.emit(damage, failure[0], failure[1])
		_next_shot = current_interval()
		return

	_next_shot -= delta
	if _next_shot <= 0.0:
		charging_now = true
		time_to_impact = Balance.telegraph_seconds
		charging.emit(Balance.telegraph_seconds)
