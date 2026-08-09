class_name TrainCar
extends Node3D
## One car of the train, built from primitives at runtime.
##
## The car is a walkable box with window openings cut into the sides, an open
## gangway at its rear end, and one fixed maintenance station where failures
## appear. Geometry is procedural so the demo has no asset dependencies —
## dressing it with the vendored Kenney kits is a later job, not a design
## commitment.

enum Kind { ENGINE, CARGO, TANKER, PAYLOAD, CABOOSE }

enum Fault { NONE, FIRE, BEARING, COOLANT }

const LENGTH := 12.0     ## body length
const PITCH := 13.6      ## body + gangway, car-to-car spacing
const HALF_W := 1.75     ## inner wall offset
const HEIGHT := 3.0
const WINDOW_LOW := 1.15
const WINDOW_HIGH := 2.25

## How long a fault takes to repair, and what it costs while it is live.
const REPAIR_SECONDS := {
	Fault.FIRE: 3.6,
	Fault.BEARING: 4.6,
	Fault.COOLANT: 2.6,
}

const FAULT_NAMES := {
	Fault.FIRE: "FIRE",
	Fault.BEARING: "SEIZED BEARING",
	Fault.COOLANT: "COOLANT LEAK",
}

var index := 0
var kind: Kind = Kind.CARGO
var fault: Fault = Fault.NONE
var fault_age := 0.0        ## seconds this fault has been burning unattended
var repair_progress := 0.0  ## 0..1
var detached := false
var drift := 0.0            ## metres this car has fallen behind after a cut

var station: Node3D          ## where the fault appears and repairs happen
var gangway: Node3D          ## the open plate behind this car, gone once it is last
var _lamp: OmniLight3D
var _fault_mesh: MeshInstance3D
var _fault_fx: GPUParticles3D
var _strip: MeshInstance3D

static var _mats: Dictionary = {}


static func _mat(key: String, albedo: Color, rough := 0.85, emission := Color.BLACK, energy := 0.0) -> StandardMaterial3D:
	if _mats.has(key):
		return _mats[key]
	var m := StandardMaterial3D.new()
	m.albedo_color = albedo
	m.roughness = rough
	m.metallic = 0.15
	if energy > 0.0:
		m.emission_enabled = true
		m.emission = emission
		m.emission_energy_multiplier = energy
	_mats[key] = m
	return m


static func make(p_index: int, p_kind: Kind) -> TrainCar:
	var car := TrainCar.new()
	car.index = p_index
	car.kind = p_kind
	car.name = "Car%d" % p_index
	return car


func _ready() -> void:
	position = Vector3(0.0, 0.0, -float(index) * PITCH)
	_build_shell()
	_build_gangway()
	_build_station()
	_build_props()


## Body: floor, ceiling, and two side walls with window openings. Visual
## geometry is split around the windows; collision is one solid slab a side so
## nobody falls out of a window at 90 km/h.
func _build_shell() -> void:
	var body := _mat("body", Color(0.20, 0.21, 0.24))
	var deck := _mat("deck", Color(0.13, 0.12, 0.12), 0.95)

	_box(Vector3(0, -0.1, -LENGTH * 0.5), Vector3(HALF_W * 2.0 + 0.3, 0.2, LENGTH), deck)
	_box(Vector3(0, HEIGHT + 0.1, -LENGTH * 0.5), Vector3(HALF_W * 2.0 + 0.3, 0.2, LENGTH), body)

	for side: float in [-1.0, 1.0]:
		var x := side * (HALF_W + 0.07)
		# sill and header run the full length; the gap between them is windows
		_box(Vector3(x, WINDOW_LOW * 0.5, -LENGTH * 0.5), Vector3(0.14, WINDOW_LOW, LENGTH), body)
		_box(Vector3(x, (WINDOW_HIGH + HEIGHT) * 0.5, -LENGTH * 0.5),
				Vector3(0.14, HEIGHT - WINDOW_HIGH, LENGTH), body)
		# pillars between the four window bays
		for i in 5:
			var z := -0.6 - float(i) * ((LENGTH - 1.2) / 4.0)
			_box(Vector3(x, (WINDOW_LOW + WINDOW_HIGH) * 0.5, z),
					Vector3(0.16, WINDOW_HIGH - WINDOW_LOW, 0.35), body)

		var wall := StaticBody3D.new()
		var shape := CollisionShape3D.new()
		var box := BoxShape3D.new()
		box.size = Vector3(0.2, HEIGHT, LENGTH)
		shape.shape = box
		wall.add_child(shape)
		wall.position = Vector3(x, HEIGHT * 0.5, -LENGTH * 0.5)
		add_child(wall)

	var floor_body := StaticBody3D.new()
	var floor_shape := CollisionShape3D.new()
	var floor_box := BoxShape3D.new()
	floor_box.size = Vector3(HALF_W * 2.0 + 0.3, 0.2, LENGTH)
	floor_shape.shape = floor_box
	floor_body.add_child(floor_shape)
	floor_body.position = Vector3(0, -0.1, -LENGTH * 0.5)
	add_child(floor_body)

	# ceiling light strip — the emissive that carries the interior at night.
	# Unique per car: the cached materials are shared, and these flicker apart.
	var strip_mat := _mat("strip", Color(0.9, 0.75, 0.5), 0.4, Color(1.0, 0.78, 0.45), 0.8).duplicate()
	_strip = _box(Vector3(0, HEIGHT - 0.06, -LENGTH * 0.5), Vector3(0.5, 0.06, LENGTH - 1.0), strip_mat)

	_lamp = OmniLight3D.new()
	_lamp.position = Vector3(0, HEIGHT - 0.35, -LENGTH * 0.5)
	_lamp.light_color = Color(1.0, 0.82, 0.6)
	_lamp.light_energy = 1.05
	_lamp.omni_range = 9.0
	_lamp.shadow_enabled = false
	add_child(_lamp)


## The open plate between this car and the next one. No walls, no roof — this
## is where the game is loudest and least safe.
func _build_gangway() -> void:
	if kind == Kind.CABOOSE:
		return
	gangway = Node3D.new()
	add_child(gangway)
	var plate := _mat("plate", Color(0.16, 0.16, 0.18), 0.7)
	var z := -LENGTH - (PITCH - LENGTH) * 0.5
	_box_on(gangway, Vector3(0, -0.1, z), Vector3(2.2, 0.16, PITCH - LENGTH + 0.2), plate)

	var body := StaticBody3D.new()
	var shape := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(2.2, 0.16, PITCH - LENGTH + 0.2)
	shape.shape = box
	body.add_child(shape)
	body.position = Vector3(0, -0.1, z)
	gangway.add_child(body)

	for side: float in [-1.0, 1.0]:
		_box_on(gangway, Vector3(side * 1.0, 0.95, z), Vector3(0.07, 0.07, PITCH - LENGTH + 0.2), plate)
		for e: float in [-1.0, 1.0]:
			_box_on(gangway, Vector3(side * 1.0, 0.5, z + e * (PITCH - LENGTH) * 0.5),
					Vector3(0.07, 1.0, 0.07), plate)


## Called when a cut makes this the last car: the plate went with the rest.
func drop_gangway() -> void:
	if gangway != null:
		gangway.queue_free()
		gangway = null


## The maintenance station: a console against the left wall. Faults appear here
## and repairs happen here, so every fault is a place you have to walk to.
func _build_station() -> void:
	station = Node3D.new()
	station.position = Vector3(-HALF_W + 0.5, 0.0, -LENGTH * 0.5)
	add_child(station)

	var steel := _mat("steel", Color(0.26, 0.27, 0.30), 0.6)
	var cabinet := MeshInstance3D.new()
	var cabinet_mesh := BoxMesh.new()
	cabinet_mesh.size = Vector3(0.7, 1.5, 1.8)
	cabinet.mesh = cabinet_mesh
	cabinet.material_override = steel
	cabinet.position = Vector3(0, 0.75, 0)
	station.add_child(cabinet)

	_fault_mesh = MeshInstance3D.new()
	var warn := BoxMesh.new()
	warn.size = Vector3(0.35, 0.35, 0.35)
	_fault_mesh.mesh = warn
	_fault_mesh.position = Vector3(0.2, 1.75, 0)
	_fault_mesh.visible = false
	station.add_child(_fault_mesh)

	_fault_fx = _make_particles()
	_fault_fx.position = Vector3(0.2, 1.75, 0)
	_fault_fx.emitting = false
	station.add_child(_fault_fx)


func _build_props() -> void:
	var steel := _mat("steel", Color(0.26, 0.27, 0.30), 0.6)
	match kind:
		Kind.ENGINE:
			# generator block: the thing whose death ends the run
			_box(Vector3(HALF_W - 0.7, 0.9, -LENGTH * 0.5), Vector3(1.1, 1.8, 4.5),
					_mat("gen", Color(0.32, 0.30, 0.26), 0.5))
			_box(Vector3(HALF_W - 0.7, 1.9, -LENGTH * 0.5), Vector3(1.16, 0.08, 3.0),
					_mat("genglow", Color(0.9, 0.5, 0.2), 0.4, Color(1.0, 0.45, 0.15), 0.6))
		Kind.TANKER:
			var tank := MeshInstance3D.new()
			var cyl := CylinderMesh.new()
			cyl.top_radius = 1.0
			cyl.bottom_radius = 1.0
			cyl.height = LENGTH - 2.0
			tank.mesh = cyl
			tank.material_override = _mat("tank", Color(0.30, 0.24, 0.20), 0.7)
			tank.rotation_degrees = Vector3(90, 0, 0)
			tank.position = Vector3(0.6, 1.4, -LENGTH * 0.5)
			add_child(tank)
		Kind.PAYLOAD:
			# the relight gear. Lose this and you can still survive; you cannot win.
			_box(Vector3(0.5, 0.9, -LENGTH * 0.5), Vector3(1.6, 1.8, 3.2),
					_mat("payload", Color(0.55, 0.44, 0.18), 0.45, Color(0.9, 0.65, 0.2), 0.55))
		Kind.CABOOSE:
			_box(Vector3(0, 1.2, -LENGTH + 0.4), Vector3(2.6, 2.4, 0.2), steel)
		_:
			for i in 3:
				_box(Vector3(0.7, 0.55, -2.5 - float(i) * 3.4), Vector3(1.5, 1.1, 2.2), steel)


func _box_on(parent: Node3D, pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	parent.add_child(mi)
	return mi


func _box(pos: Vector3, size: Vector3, mat: Material) -> MeshInstance3D:
	var mi := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	add_child(mi)
	return mi


func _make_particles() -> GPUParticles3D:
	var p := GPUParticles3D.new()
	p.amount = 40
	p.lifetime = 1.1
	p.explosiveness = 0.0

	var pm := ParticleProcessMaterial.new()
	pm.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
	pm.emission_sphere_radius = 0.18
	pm.direction = Vector3(0, 1, 0)
	pm.spread = 25.0
	pm.initial_velocity_min = 0.8
	pm.initial_velocity_max = 2.2
	pm.gravity = Vector3(0, 1.4, 0)
	pm.scale_min = 0.12
	pm.scale_max = 0.36
	pm.color = Color(1.0, 0.55, 0.15)
	p.process_material = pm

	var quad := QuadMesh.new()
	quad.size = Vector2(0.4, 0.4)
	var qm := StandardMaterial3D.new()
	qm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	qm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	qm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED
	qm.vertex_color_use_as_albedo = true
	qm.albedo_color = Color(1.0, 0.6, 0.2, 0.75)
	quad.material = qm
	p.draw_pass_1 = quad
	return p


## Centre of the coupling behind this car, in train-local space.
func coupling_z() -> float:
	return -float(index) * PITCH - LENGTH - (PITCH - LENGTH) * 0.5


func set_fault(f: Fault) -> void:
	fault = f
	fault_age = 0.0
	repair_progress = 0.0
	_fault_mesh.visible = f != Fault.NONE
	_fault_fx.emitting = f == Fault.FIRE
	if f == Fault.NONE:
		return
	var tint := Color(1.0, 0.35, 0.2)
	if f == Fault.BEARING:
		tint = Color(1.0, 0.75, 0.2)
	elif f == Fault.COOLANT:
		tint = Color(0.4, 0.8, 1.0)
	_fault_mesh.material_override = _mat("fault_%d" % f, tint, 0.4, tint, 3.0)


func fault_name() -> String:
	return FAULT_NAMES.get(fault, "")


## Interior lighting tracks available power, and flickers when it is marginal.
func set_power(power: float, time: float) -> void:
	var flicker := 1.0
	if power < 0.55:
		flicker = 0.55 + 0.45 * absf(sin(time * (9.0 + float(index)) * (1.2 - power)))
	_lamp.light_energy = maxf(0.05, 1.05 * power * flicker)
	var strip_mat := _strip.material_override as StandardMaterial3D
	if strip_mat != null:
		strip_mat.emission_energy_multiplier = maxf(0.04, 0.9 * power * flicker)
