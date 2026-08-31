class_name Balance
extends RefCounted

## Every number that decides whether the game is fair, in one place.
##
## These are static so the headless harness can sweep them between runs
## (`tests/balance_sweep.gd`). Balance is the one thing about a game a GPU-less
## container can genuinely measure, so it is worth paying a small indirection
## cost to make it measurable rather than baking constants into the logic.
##
## Anything here is expected to change. Anything in machine.gd is expected not
## to — that file holds the rules, this one holds the dials.

## --- the machine ---
static var max_structure := 100.0
static var max_heat := 100.0

## Per second at FULL allocation to that system. Allocation sums to 1.0 across
## three systems, so an even split runs everything at a third.
static var weapon_heat_rate := 26.0
static var coolant_heat_rate := 34.0
static var reactor_heat_rate := 6.0
static var fire_heat_rate := 9.0

static var weapon_damage_rate := 12.0
static var max_evasion := 0.65

## A ruptured line does not disable a system, it makes it disappointing.
static var rupture_efficiency := 0.4
static var scram_power_factor := 0.55

static var vent_heat_removed := 45.0
static var vent_weapon_lockout := 5.0
static var vent_cooldown := 12.0

## Structure lost per second while fully overheated. Overheating cooks you
## rather than killing you outright, so the death is one you watched arrive.
static var overheat_damage := 9.0

## --- the fight ---
static var enemy_hp := 480.0
static var telegraph_seconds := 1.3
static var first_interval := 7.0
static var final_interval := 3.2
static var ramp_seconds := 105.0
static var base_damage := 8.0
static var damage_variance := 4.0


## Restore the shipping values. The sweep harness mutates these, so anything
## running more than one configuration in a process must reset between them.
static func reset() -> void:
	max_structure = 100.0
	max_heat = 100.0
	weapon_heat_rate = 26.0
	coolant_heat_rate = 34.0
	reactor_heat_rate = 6.0
	fire_heat_rate = 9.0
	weapon_damage_rate = 12.0
	max_evasion = 0.65
	rupture_efficiency = 0.4
	scram_power_factor = 0.55
	vent_heat_removed = 45.0
	vent_weapon_lockout = 5.0
	vent_cooldown = 12.0
	overheat_damage = 9.0
	enemy_hp = 480.0
	telegraph_seconds = 1.3
	first_interval = 7.0
	final_interval = 3.2
	ramp_seconds = 105.0
	base_damage = 8.0
	damage_variance = 4.0
