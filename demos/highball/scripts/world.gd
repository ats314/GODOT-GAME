class_name World
extends Node3D
## The country going past.
##
## The train never moves — the world does. Keeping the train at the origin
## means no floating-point drift over a long run, no streaming, and no
## reconciliation between the player's physics and a moving platform: the
## player just walks around a static building while scenery is recycled past
## the windows at speed.

const TIE_SPAN := 195.0
const ROCK_SPAN := 420.0
const POLE_SPAN := 600.0
const RIDGE_SPAN := 1600.0

var travelled := 0.0

var _ties: MultiMeshInstance3D
var _rocks: MultiMeshInstance3D
var _poles: Array[Node3D] = []
var _pole_base: Array[float] = []
var _ridges: Array[Node3D] = []
var _ridge_base: Array[float] = []
var _chaser: Node3D
var _chaser_light: OmniLight3D


func _ready() -> void:
	_build_ground()
	_build_track()
	_build_ties()
	_build_rocks()
	_build_poles()
	_build_ridges()
	_build_chaser()


func _build_ground() -> void:
	var ground := MeshInstance3D.new()
	var plane := PlaneMesh.new()
	plane.size = Vector2(1400, 3000)
	ground.mesh = plane
	ground.position = Vector3(0, -1.4, -200)
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.055, 0.052, 0.062)
	m.roughness = 1.0
	ground.material_override = m
	add_child(ground)


func _build_track() -> void:
	var ballast := StandardMaterial3D.new()
	ballast.albedo_color = Color(0.10, 0.095, 0.10)
	ballast.roughness = 1.0
	var bed := MeshInstance3D.new()
	var bed_mesh := BoxMesh.new()
	bed_mesh.size = Vector3(6.0, 0.5, 2400.0)
	bed.mesh = bed_mesh
	bed.material_override = ballast
	bed.position = Vector3(0, -1.35, -300)
	add_child(bed)

	var steel := StandardMaterial3D.new()
	steel.albedo_color = Color(0.42, 0.42, 0.46)
	steel.metallic = 0.9
	steel.roughness = 0.25
	for side: float in [-0.75, 0.75]:
		var rail := MeshInstance3D.new()
		var rail_mesh := BoxMesh.new()
		rail_mesh.size = Vector3(0.14, 0.16, 2400.0)
		rail.mesh = rail_mesh
		rail.material_override = steel
		rail.position = Vector3(side, -1.02, -300)
		add_child(rail)


## Sleepers are the whole motion cue — everything else is parallax garnish.
func _build_ties() -> void:
	_ties = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(2.6, 0.16, 0.26)
	mm.mesh = mesh
	mm.instance_count = 300
	_ties.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.15, 0.12, 0.10)
	m.roughness = 1.0
	_ties.material_override = m
	add_child(_ties)


func _build_rocks() -> void:
	_rocks = MultiMeshInstance3D.new()
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var mesh := BoxMesh.new()
	mesh.size = Vector3(1, 1, 1)
	mm.mesh = mesh
	mm.instance_count = 260
	_rocks.multimesh = mm
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.09, 0.088, 0.095)
	m.roughness = 1.0
	_rocks.material_override = m
	add_child(_rocks)

	var rng := RandomNumberGenerator.new()
	rng.seed = 20260809
	for i in mm.instance_count:
		var side: float = 1.0 if rng.randf() < 0.5 else -1.0
		var x: float = side * rng.randf_range(5.0, 90.0)
		var s: float = rng.randf_range(0.5, 3.4)
		var t := Transform3D(Basis().rotated(Vector3.UP, rng.randf() * TAU).scaled(
				Vector3(s, s * rng.randf_range(0.4, 1.2), s)),
				Vector3(x, -1.4 + s * 0.2, 0.0))
		mm.set_instance_transform(i, t)


func _build_poles() -> void:
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(0.11, 0.10, 0.09)
	m.roughness = 1.0
	for i in 24:
		var pole := Node3D.new()
		var post := MeshInstance3D.new()
		var post_mesh := BoxMesh.new()
		post_mesh.size = Vector3(0.28, 9.0, 0.28)
		post.mesh = post_mesh
		post.material_override = m
		post.position = Vector3(0, 3.1, 0)
		pole.add_child(post)
		var arm := MeshInstance3D.new()
		var arm_mesh := BoxMesh.new()
		arm_mesh.size = Vector3(2.2, 0.18, 0.18)
		arm.mesh = arm_mesh
		arm.material_override = m
		arm.position = Vector3(0, 6.9, 0)
		pole.add_child(arm)
		pole.position = Vector3(9.5 if i % 2 == 0 else -9.5, -1.4, 0)
		add_child(pole)
		_poles.append(pole)
		_pole_base.append(float(i) * (POLE_SPAN / 24.0))


## Two slow layers of hills so the horizon does not read as a painted wall.
func _build_ridges() -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 77123
	for i in 26:
		var ridge := MeshInstance3D.new()
		var mesh := BoxMesh.new()
		var w: float = rng.randf_range(120.0, 420.0)
		var h: float = rng.randf_range(30.0, 130.0)
		mesh.size = Vector3(w, h, 60.0)
		ridge.mesh = mesh
		var m := StandardMaterial3D.new()
		var shade: float = rng.randf_range(0.030, 0.055)
		m.albedo_color = Color(shade, shade * 1.02, shade * 1.35)
		m.roughness = 1.0
		ridge.material_override = m
		ridge.position = Vector3(
				(1.0 if i % 2 == 0 else -1.0) * rng.randf_range(180.0, 520.0),
				-1.4 + h * 0.5 - 10.0, 0.0)
		add_child(ridge)
		_ridges.append(ridge)
		_ridge_base.append(float(i) * (RIDGE_SPAN / 26.0))


## Whatever is running the same rails behind you. Never seen clearly — it is a
## headlight and a distance readout, and both get worse when you slow down.
func _build_chaser() -> void:
	_chaser = Node3D.new()
	var lamp := MeshInstance3D.new()
	var sphere := SphereMesh.new()
	sphere.radius = 1.1
	sphere.height = 2.2
	var m := StandardMaterial3D.new()
	m.albedo_color = Color(1.0, 0.92, 0.8)
	m.emission_enabled = true
	m.emission = Color(1.0, 0.9, 0.75)
	m.emission_energy_multiplier = 12.0
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	sphere.material = m
	lamp.mesh = sphere
	lamp.position = Vector3(0, 2.2, 0)
	_chaser.add_child(lamp)

	_chaser_light = OmniLight3D.new()
	_chaser_light.light_color = Color(1.0, 0.9, 0.78)
	_chaser_light.light_energy = 6.0
	_chaser_light.omni_range = 70.0
	_chaser_light.position = Vector3(0, 2.2, 0)
	_chaser.add_child(_chaser_light)
	add_child(_chaser)


func advance(distance: float, chase_gap: float) -> void:
	travelled += distance

	var tie_mm := _ties.multimesh
	for i in tie_mm.instance_count:
		var z := fposmod(float(i) * 0.65 + travelled, TIE_SPAN) - 120.0
		tie_mm.set_instance_transform(i, Transform3D(Basis(), Vector3(0, -1.18, z)))

	var rock_mm := _rocks.multimesh
	for i in rock_mm.instance_count:
		var t := rock_mm.get_instance_transform(i)
		var base := float(i) * (ROCK_SPAN / float(rock_mm.instance_count))
		t.origin.z = fposmod(base + travelled, ROCK_SPAN) - 260.0
		rock_mm.set_instance_transform(i, t)

	for i in _poles.size():
		_poles[i].position.z = fposmod(_pole_base[i] + travelled, POLE_SPAN) - 400.0

	for i in _ridges.size():
		_ridges[i].position.z = fposmod(_ridge_base[i] + travelled * 0.22, RIDGE_SPAN) - 1100.0

	_chaser.position.z = clampf(chase_gap, 0.0, 900.0)
	_chaser_light.light_energy = clampf(9.0 - chase_gap * 0.012, 0.5, 9.0)
