extends Node3D
## HIGHBALL — vertical slice.
##
## The whole pitch in one runnable scene: a train that cannot stop, faults that
## must be fixed while it runs, couplings you can cut to save yourself, and a
## win condition that is a delivery rather than a survival timer — so the
## survival-optimal play and the winning play come apart under pressure.

const CAR_COUNT := 12
const PAYLOAD_INDEX := 8
const TARGET_DISTANCE := 4000.0
const MAX_TRACTIVE := 34.0
const CHASE_MATCH_SPEED := 19.0   ## below this, the thing behind gains
const START_GAP := 520.0
const STALL_SECONDS := 3.0
const REACH := 2.4                ## how close you must be to work on something

var cars: Array[TrainCar] = []
var dropped: Array[TrainCar] = []
var drop_speed: Array[float] = []

var speed := 24.0
var distance := 0.0
var fuel := 100.0
var overheat := 0.0
var damage := 0.0                 ## permanent power loss from burnt-out cars
var chase_gap := START_GAP
var payload_aboard := true
var over := false
var won := false
var stalled_for := 0.0
var time := 0.0
var next_fault_at := 12.0

var player: Crew
var world: World
var hud: Hud
var train: Node3D
var rear_stop: StaticBody3D

var _rng := RandomNumberGenerator.new()
var _repairing: TrainCar = null
var _cut_hold := 0.0
var _intro := 7.0


func _ready() -> void:
	_rng.randomize()
	_build_environment()

	world = World.new()
	add_child(world)

	train = Node3D.new()
	add_child(train)
	for i in CAR_COUNT:
		var car := TrainCar.make(i, _kind_for(i))
		train.add_child(car)
		cars.append(car)

	rear_stop = StaticBody3D.new()
	var stop_shape := CollisionShape3D.new()
	var stop_box := BoxShape3D.new()
	stop_box.size = Vector3(4.0, 3.0, 0.3)
	stop_shape.shape = stop_box
	rear_stop.add_child(stop_shape)
	train.add_child(rear_stop)
	_place_rear_stop()

	var nose := StaticBody3D.new()
	var nose_shape := CollisionShape3D.new()
	var nose_box := BoxShape3D.new()
	nose_box.size = Vector3(4.0, 3.0, 0.3)
	nose_shape.shape = nose_box
	nose.add_child(nose_shape)
	nose.position = Vector3(0, 1.5, 0.15)
	train.add_child(nose)

	player = Crew.new()
	player.position = Vector3(0, 0.2, -5.0)
	add_child(player)

	hud = Hud.new()
	add_child(hud)
	hud.set_banner("HIGHBALL", "You cannot stop. Fix it at speed.\nWASD / stick — move.  Hold E / A — repair.  Hold F / X — cut coupling.")

	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _kind_for(i: int) -> TrainCar.Kind:
	if i == 0:
		return TrainCar.Kind.ENGINE
	if i == CAR_COUNT - 1:
		return TrainCar.Kind.CABOOSE
	if i == PAYLOAD_INDEX:
		return TrainCar.Kind.PAYLOAD
	if i == 1 or i == 5:
		return TrainCar.Kind.TANKER
	return TrainCar.Kind.CARGO


func _build_environment() -> void:
	var env := Environment.new()
	env.background_mode = Environment.BG_COLOR
	env.background_color = Color(0.020, 0.024, 0.038)
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color(0.13, 0.16, 0.24)
	env.ambient_light_energy = 0.75
	env.fog_enabled = true
	env.fog_light_color = Color(0.06, 0.07, 0.11)
	env.fog_density = 0.006
	env.fog_sky_affect = 0.0
	env.glow_enabled = true
	env.glow_intensity = 0.32
	env.glow_bloom = 0.12
	env.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	var we := WorldEnvironment.new()
	we.environment = env
	add_child(we)

	var moon := DirectionalLight3D.new()
	moon.light_color = Color(0.55, 0.65, 0.9)
	moon.light_energy = 0.55
	moon.rotation_degrees = Vector3(-32, 38, 0)
	moon.shadow_enabled = true
	add_child(moon)


func _process(delta: float) -> void:
	time += delta
	if _intro > 0.0:
		_intro -= delta
		if _intro <= 0.0 and not over:
			hud.set_banner("", "")

	if Input.is_action_just_pressed(&"restart"):
		get_tree().reload_current_scene()
		return
	if Input.is_action_just_pressed(&"release_mouse"):
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED \
				else Input.MOUSE_MODE_CAPTURED

	if not over:
		_tick_faults(delta)
		_tick_plant(delta)
		_tick_motion(delta)
		_tick_interaction(delta)
		_check_end(delta)

	_tick_dropped(delta)
	world.advance(speed * delta, chase_gap)
	_update_player_state()
	_update_hud()


## Faults arrive on a timer, escalate if ignored, and pick on whichever car
## you are least likely to be standing in.
func _tick_faults(delta: float) -> void:
	if time >= next_fault_at:
		next_fault_at = time + _rng.randf_range(15.0, 25.0)
		_spawn_fault()

	for car in cars:
		if car.fault == TrainCar.Fault.NONE:
			continue
		car.fault_age += delta
		match car.fault:
			TrainCar.Fault.FIRE:
				fuel -= 0.55 * delta
				if car.fault_age > 30.0:
					# it stops being one car's problem
					damage = minf(0.45, damage + 0.12)
					car.set_fault(TrainCar.Fault.NONE)
					_spawn_fault(TrainCar.Fault.FIRE)
			TrainCar.Fault.COOLANT:
				overheat = minf(0.85, overheat + 0.048 * delta)


func _spawn_fault(forced := TrainCar.Fault.NONE) -> void:
	var healthy: Array[TrainCar] = []
	for car in cars:
		if car.fault == TrainCar.Fault.NONE:
			healthy.append(car)
	if healthy.is_empty():
		return
	var car: TrainCar = healthy[_rng.randi_range(0, healthy.size() - 1)]
	if forced != TrainCar.Fault.NONE:
		car.set_fault(forced)
		return
	var roll := _rng.randf()
	if roll < 0.42:
		car.set_fault(TrainCar.Fault.FIRE)
	elif roll < 0.78:
		car.set_fault(TrainCar.Fault.BEARING)
	else:
		car.set_fault(TrainCar.Fault.COOLANT)


func _tick_plant(delta: float) -> void:
	# Tuned against the soak test: a clean run with the whole consist reaches the
	# yard with roughly 10% in the tank, so any untended fire is a real threat and
	# cutting cars is a genuine fuel strategy rather than pure loss.
	var burn := 0.28 + 0.028 * float(cars.size())
	fuel = maxf(0.0, fuel - burn * delta)
	var leaking := false
	for car in cars:
		if car.fault == TrainCar.Fault.COOLANT:
			leaking = true
	if not leaking:
		overheat = maxf(0.0, overheat - 0.035 * delta)


func power() -> float:
	var fuel_factor := 1.0 if fuel > 12.0 else fuel / 12.0
	return clampf((1.0 - overheat - damage) * fuel_factor, 0.0, 1.0)


func _tick_motion(delta: float) -> void:
	var drag := 0.55 * float(cars.size())
	for car in cars:
		if car.fault == TrainCar.Fault.BEARING:
			drag += 2.4 + car.fault_age * 0.055   # a bearing does not wait
		elif car.fault == TrainCar.Fault.FIRE:
			drag += 0.7
	var target := clampf(MAX_TRACTIVE * power() - drag, 0.0, MAX_TRACTIVE)
	var rate := 1.7 if target > speed else 3.2
	speed = move_toward(speed, target, rate * delta)
	distance += speed * delta
	chase_gap = clampf(chase_gap + (speed - CHASE_MATCH_SPEED) * delta, 0.0, 900.0)


## Repairs and coupling cuts, both hold-to-commit so nothing is a reflex press.
func _tick_interaction(delta: float) -> void:
	var pos := player.global_position

	var near_car: TrainCar = null
	var best := REACH
	for car in cars:
		if car.fault == TrainCar.Fault.NONE:
			continue
		var d := pos.distance_to(car.station.global_position + Vector3(0, 1.0, 0))
		if d < best:
			best = d
			near_car = car

	if near_car != null and Input.is_action_pressed(&"interact"):
		if _repairing != near_car:
			_repairing = near_car
		var seconds: float = TrainCar.REPAIR_SECONDS[near_car.fault]
		near_car.repair_progress += delta / seconds
		if near_car.repair_progress >= 1.0:
			near_car.set_fault(TrainCar.Fault.NONE)
			_repairing = null
	else:
		if _repairing != null:
			_repairing.repair_progress = maxf(0.0, _repairing.repair_progress - delta * 0.6)
		_repairing = null

	# Couplings: you must be forward of the cut, which is the whole reason the
	# rear of the train is a place you have to be brave to go.
	var cut_index := -1
	for i in cars.size() - 1:
		var cz: float = cars[i].coupling_z()
		# You must be standing inside the car ahead of the coupling — never out
		# on the plate that is about to become the back of nothing.
		var body_end: float = -float(cars[i].index) * TrainCar.PITCH - TrainCar.LENGTH
		if absf(pos.z - cz) < 2.2 and absf(pos.x) < 1.4 and pos.z > body_end + 0.15:
			cut_index = i
			break

	if cut_index >= 0 and Input.is_action_pressed(&"cut_coupling"):
		_cut_hold += delta
		if _cut_hold >= 1.5:
			_cut(cut_index)
			_cut_hold = 0.0
	else:
		_cut_hold = maxf(0.0, _cut_hold - delta * 1.5)

	_update_prompt(near_car, cut_index)


func _update_prompt(near_car: TrainCar, cut_index: int) -> void:
	if over:
		hud.set_prompt("[R] run it again", -1.0)
		return
	if near_car != null:
		hud.set_prompt("HOLD  E / (A)   %s — CAR %d" % [near_car.fault_name(), near_car.index],
				near_car.repair_progress)
		return
	if cut_index >= 0:
		var losing := cars.size() - 1 - cut_index
		var takes_payload := false
		for i in range(cut_index + 1, cars.size()):
			if cars[i].kind == TrainCar.Kind.PAYLOAD:
				takes_payload = true
		var warn := "  — INCLUDING THE PAYLOAD" if takes_payload else ""
		hud.set_prompt("HOLD  F / (X)   CUT COUPLING — drops %d cars%s" % [losing, warn],
				_cut_hold / 1.5)
		return
	hud.set_prompt("", -1.0)


func _cut(index: int) -> void:
	for i in range(cars.size() - 1, index, -1):
		var car: TrainCar = cars[i]
		if car.kind == TrainCar.Kind.PAYLOAD:
			payload_aboard = false
		car.detached = true
		car.set_fault(TrainCar.Fault.NONE)
		cars.remove_at(i)
		dropped.append(car)
		drop_speed.append(0.0)
	cars[cars.size() - 1].drop_gangway()
	_place_rear_stop()
	if not payload_aboard:
		hud.set_banner("PAYLOAD GONE", "You can still run. You can no longer win.",
				Color(1.0, 0.6, 0.3))
		_intro = 5.0


## Cut cars fall behind: they are decelerating and you are not.
func _tick_dropped(delta: float) -> void:
	for i in range(dropped.size() - 1, -1, -1):
		drop_speed[i] += 7.0 * delta
		dropped[i].position.z += drop_speed[i] * delta
		if dropped[i].position.z > 320.0:
			dropped[i].queue_free()
			dropped.remove_at(i)
			drop_speed.remove_at(i)


func _place_rear_stop() -> void:
	if cars.is_empty():
		return
	var last: TrainCar = cars[cars.size() - 1]
	rear_stop.position = Vector3(0, 1.5,
			-float(last.index) * TrainCar.PITCH - TrainCar.LENGTH - 0.15)


func _update_player_state() -> void:
	player.speed_fraction = clampf(speed / MAX_TRACTIVE, 0.0, 1.0)
	var u := -player.global_position.z
	player.exposed = u > 0.0 and fposmod(u, TrainCar.PITCH) > TrainCar.LENGTH
	for car in cars:
		car.set_power(power(), time)


func _check_end(delta: float) -> void:
	if speed < 0.6:
		stalled_for += delta
	else:
		stalled_for = 0.0

	if distance >= TARGET_DISTANCE and payload_aboard:
		_finish(true, "HIGHBALL", "You made the yard with the gear. The plant can be relit.")
	elif distance >= TARGET_DISTANCE and not payload_aboard:
		_finish(false, "YOU ARRIVED EMPTY",
				"The yard is here. What it needed is forty kilometres back.")
	elif stalled_for >= STALL_SECONDS:
		_finish(false, "THE TRAIN STOPPED", "It will not light again.")
	elif chase_gap <= 0.0:
		_finish(false, "CAUGHT", "It was always going to be quicker than you.")


func _finish(victory: bool, title: String, sub: String) -> void:
	over = true
	won = victory
	hud.set_banner(title, sub, Color(0.75, 1.0, 0.8) if victory else Color(1.0, 0.5, 0.4))
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func _update_hud() -> void:
	var lines := PackedStringArray()
	for car in cars:
		if car.fault != TrainCar.Fault.NONE:
			lines.append("CAR %-2d  %-14s %ds" % [car.index, car.fault_name(), int(car.fault_age)])
	hud.set_faults(lines)
	hud.set_readouts(speed, MAX_TRACTIVE, power(), fuel, cars.size(),
			distance, TARGET_DISTANCE, chase_gap, payload_aboard)
