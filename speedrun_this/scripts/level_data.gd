class_name LevelData
extends RefCounted
## Static level definitions. Each level looks trivially simple.
## The cheat engine reads from `cheats` to know what to do per attempt.

## A platform: {pos: Vector2, size: Vector2}
## The goal:   Vector2
## Spawn:      Vector2

static func get_level(idx: int) -> Dictionary:
	match idx:
		0: return _level_walk_right()
		1: return _level_the_jump()
		2: return _level_stairs()
		3: return _level_corridor()
		4: return _level_walk_right_again()
		_: return _level_walk_right()

static func get_level_name(idx: int) -> String:
	match idx:
		0: return "WALK RIGHT"
		1: return "THE JUMP"
		2: return "STAIRS"
		3: return "THE CORRIDOR"
		4: return "WALK RIGHT (AGAIN)"
		_: return "???"

# ═══════════════════════════════════════════════════════════════════
# Level 1: Walk Right — flat ground, flag on the right.
# ═══════════════════════════════════════════════════════════════════
static func _level_walk_right() -> Dictionary:
	return {
		"spawn": Vector2(200, 830),
		"goal": Vector2(1700, 830),
		"platforms": [
			{"pos": Vector2(960, 880), "size": Vector2(1920, 100)},   # floor
		],
		"ghost_path": _make_ghost_walk(Vector2(200, 830), Vector2(1700, 830), 4.0),
		"cheats": {
			# attempt -> array of cheat dicts
			2: [{"type": "invisible_wall", "pos": Vector2(1000, 780), "size": Vector2(20, 160)}],
			3: [
				{"type": "invisible_wall", "pos": Vector2(1000, 780), "size": Vector2(20, 160)},
				{"type": "speed_drain", "rate": 0.15},
			],
			4: [
				{"type": "invisible_wall", "pos": Vector2(900, 780), "size": Vector2(20, 160)},
				{"type": "invisible_wall", "pos": Vector2(1300, 780), "size": Vector2(20, 160)},
				{"type": "speed_drain", "rate": 0.25},
			],
			6: [
				{"type": "invisible_wall", "pos": Vector2(800, 780), "size": Vector2(20, 160)},
				{"type": "floor_gap", "x_start": 1200.0, "x_end": 1400.0},
				{"type": "speed_drain", "rate": 0.3},
			],
			9: [
				{"type": "goal_flee", "speed": 100.0, "range": 300.0},
				{"type": "invisible_wall", "pos": Vector2(700, 780), "size": Vector2(20, 160)},
				{"type": "floor_gap", "x_start": 1100.0, "x_end": 1350.0},
				{"type": "speed_drain", "rate": 0.35},
			],
		},
	}

# ═══════════════════════════════════════════════════════════════════
# Level 2: The Jump — one gap to jump over.
# ═══════════════════════════════════════════════════════════════════
static func _level_the_jump() -> Dictionary:
	return {
		"spawn": Vector2(200, 830),
		"goal": Vector2(1600, 830),
		"platforms": [
			{"pos": Vector2(400, 880),  "size": Vector2(800, 100)},    # left ground
			{"pos": Vector2(1400, 880), "size": Vector2(800, 100)},    # right ground
		],
		"ghost_path": _make_ghost_jump(
			Vector2(200, 830), Vector2(1600, 830),
			Vector2(900, 830), Vector2(1100, 830), 5.0
		),
		"cheats": {
			2: [{"type": "gravity_spike", "multiplier": 1.5, "trigger_y": 700.0}],
			4: [
				{"type": "gravity_spike", "multiplier": 1.8, "trigger_y": 680.0},
				{"type": "platform_shrink", "index": 1, "amount": 80.0},
			],
			6: [
				{"type": "gravity_spike", "multiplier": 2.0, "trigger_y": 700.0},
				{"type": "platform_shrink", "index": 1, "amount": 120.0},
				{"type": "input_flip_burst", "trigger_x": 950.0, "duration": 0.25},
			],
			9: [
				{"type": "gravity_spike", "multiplier": 2.2, "trigger_y": 700.0},
				{"type": "platform_shrink", "index": 1, "amount": 150.0},
				{"type": "input_flip_burst", "trigger_x": 950.0, "duration": 0.35},
				{"type": "wind", "force": -200.0, "zone_x_start": 800.0, "zone_x_end": 1200.0},
			],
			13: [
				{"type": "gravity_spike", "multiplier": 2.5, "trigger_y": 720.0},
				{"type": "platform_shrink", "index": 1, "amount": 200.0},
				{"type": "input_flip_burst", "trigger_x": 900.0, "duration": 0.5},
				{"type": "wind", "force": -350.0, "zone_x_start": 700.0, "zone_x_end": 1300.0},
				{"type": "platform_slide", "index": 1, "speed": -60.0},
			],
		},
	}

# ═══════════════════════════════════════════════════════════════════
# Level 3: Stairs — four platforms ascending.
# ═══════════════════════════════════════════════════════════════════
static func _level_stairs() -> Dictionary:
	return {
		"spawn": Vector2(160, 830),
		"goal": Vector2(1660, 350),
		"platforms": [
			{"pos": Vector2(250, 880),  "size": Vector2(500, 100)},    # ground
			{"pos": Vector2(660, 720),  "size": Vector2(280, 24)},     # step 1
			{"pos": Vector2(1060, 560), "size": Vector2(280, 24)},     # step 2
			{"pos": Vector2(1460, 400), "size": Vector2(400, 24)},     # top
		],
		"ghost_path": _make_ghost_stairs(),
		"cheats": {
			2: [{"type": "platform_shrink", "index": 1, "amount": 40.0}],
			4: [
				{"type": "platform_shrink", "index": 1, "amount": 50.0},
				{"type": "platform_shrink", "index": 2, "amount": 50.0},
				{"type": "platform_slide", "index": 2, "speed": -30.0},
			],
			7: [
				{"type": "platform_shrink", "index": 1, "amount": 60.0},
				{"type": "platform_shrink", "index": 2, "amount": 70.0},
				{"type": "platform_slide", "index": 2, "speed": -50.0},
				{"type": "gravity_spike", "multiplier": 1.4, "trigger_y": 500.0},
				{"type": "coyote_kill"},
			],
			10: [
				{"type": "platform_shrink", "index": 1, "amount": 80.0},
				{"type": "platform_shrink", "index": 2, "amount": 90.0},
				{"type": "platform_slide", "index": 2, "speed": -70.0},
				{"type": "platform_slide", "index": 3, "speed": 40.0},
				{"type": "gravity_spike", "multiplier": 1.6, "trigger_y": 450.0},
				{"type": "coyote_kill"},
				{"type": "input_flip_burst", "trigger_x": 1000.0, "duration": 0.3},
			],
			15: [
				{"type": "platform_shrink", "index": 1, "amount": 100.0},
				{"type": "platform_shrink", "index": 2, "amount": 100.0},
				{"type": "platform_slide", "index": 1, "speed": -40.0},
				{"type": "platform_slide", "index": 2, "speed": -80.0},
				{"type": "platform_slide", "index": 3, "speed": 60.0},
				{"type": "gravity_spike", "multiplier": 1.8, "trigger_y": 400.0},
				{"type": "coyote_kill"},
				{"type": "input_flip_burst", "trigger_x": 900.0, "duration": 0.4},
			],
		},
	}

# ═══════════════════════════════════════════════════════════════════
# Level 4: The Corridor — ceiling + floor, walk to the end.
# ═══════════════════════════════════════════════════════════════════
static func _level_corridor() -> Dictionary:
	return {
		"spawn": Vector2(200, 630),
		"goal": Vector2(1750, 630),
		"platforms": [
			{"pos": Vector2(960, 680), "size": Vector2(1920, 60)},     # floor
			{"pos": Vector2(960, 440), "size": Vector2(1920, 60)},     # ceiling
		],
		"ghost_path": _make_ghost_walk(Vector2(200, 630), Vector2(1750, 630), 4.5),
		"cheats": {
			2: [{"type": "speed_drain", "rate": 0.2}],
			4: [
				{"type": "speed_drain", "rate": 0.3},
				{"type": "goal_flee", "speed": 80.0, "range": 250.0},
			],
			7: [
				{"type": "speed_drain", "rate": 0.35},
				{"type": "goal_flee", "speed": 120.0, "range": 300.0},
				{"type": "ceiling_drop", "x_positions": [600.0, 1000.0, 1400.0], "amount": 60.0, "range": 250.0},
			],
			10: [
				{"type": "speed_drain", "rate": 0.4},
				{"type": "goal_flee", "speed": 150.0, "range": 350.0},
				{"type": "ceiling_drop", "x_positions": [500.0, 800.0, 1100.0, 1400.0], "amount": 90.0, "range": 200.0},
				{"type": "floor_bounce", "zones": [{"x": 700.0, "w": 200.0}, {"x": 1200.0, "w": 200.0}]},
			],
			14: [
				{"type": "speed_drain", "rate": 0.5},
				{"type": "goal_flee", "speed": 180.0, "range": 400.0},
				{"type": "ceiling_drop", "x_positions": [400.0, 700.0, 1000.0, 1300.0, 1600.0], "amount": 110.0, "range": 180.0},
				{"type": "floor_bounce", "zones": [{"x": 600.0, "w": 250.0}, {"x": 1000.0, "w": 250.0}, {"x": 1400.0, "w": 250.0}]},
				{"type": "input_flip_burst", "trigger_x": 1200.0, "duration": 0.5},
			],
		},
	}

# ═══════════════════════════════════════════════════════════════════
# Level 5: Walk Right (Again) — looks like Level 1. Everything cheats.
# ═══════════════════════════════════════════════════════════════════
static func _level_walk_right_again() -> Dictionary:
	return {
		"spawn": Vector2(200, 830),
		"goal": Vector2(1700, 830),
		"platforms": [
			{"pos": Vector2(960, 880), "size": Vector2(1920, 100)},
		],
		"ghost_path": _make_ghost_walk(Vector2(200, 830), Vector2(1700, 830), 4.0),
		"cheats": {
			# Cheats from attempt 1 — the kitchen sink
			1: [
				{"type": "invisible_wall", "pos": Vector2(900, 780), "size": Vector2(20, 160)},
				{"type": "speed_drain", "rate": 0.2},
				{"type": "gravity_spike", "multiplier": 1.3, "trigger_y": 750.0},
			],
			3: [
				{"type": "invisible_wall", "pos": Vector2(700, 780), "size": Vector2(20, 160)},
				{"type": "invisible_wall", "pos": Vector2(1200, 780), "size": Vector2(20, 160)},
				{"type": "speed_drain", "rate": 0.35},
				{"type": "floor_gap", "x_start": 1000.0, "x_end": 1150.0},
				{"type": "input_flip_burst", "trigger_x": 600.0, "duration": 0.3},
			],
			6: [
				{"type": "invisible_wall", "pos": Vector2(600, 780), "size": Vector2(20, 160)},
				{"type": "invisible_wall", "pos": Vector2(1100, 780), "size": Vector2(20, 160)},
				{"type": "floor_gap", "x_start": 900.0, "x_end": 1100.0},
				{"type": "goal_flee", "speed": 130.0, "range": 300.0},
				{"type": "speed_drain", "rate": 0.4},
				{"type": "input_flip_burst", "trigger_x": 500.0, "duration": 0.4},
				{"type": "gravity_spike", "multiplier": 2.0, "trigger_y": 700.0},
			],
			10: [
				{"type": "invisible_wall", "pos": Vector2(500, 780), "size": Vector2(20, 160)},
				{"type": "invisible_wall", "pos": Vector2(800, 780), "size": Vector2(20, 160)},
				{"type": "invisible_wall", "pos": Vector2(1100, 780), "size": Vector2(20, 160)},
				{"type": "floor_gap", "x_start": 850.0, "x_end": 1050.0},
				{"type": "floor_gap", "x_start": 1300.0, "x_end": 1450.0},
				{"type": "goal_flee", "speed": 170.0, "range": 350.0},
				{"type": "speed_drain", "rate": 0.5},
				{"type": "input_flip_burst", "trigger_x": 450.0, "duration": 0.5},
				{"type": "wind", "force": -250.0, "zone_x_start": 400.0, "zone_x_end": 1600.0},
				{"type": "gravity_spike", "multiplier": 2.5, "trigger_y": 700.0},
			],
		},
	}

# ═══════════════════════════════════════════════════════════════════
# Ghost path helpers
# ═══════════════════════════════════════════════════════════════════

static func _make_ghost_walk(from: Vector2, to: Vector2, duration: float) -> Array:
	## Straight walk from A to B over `duration` seconds.
	var path: Array = []
	var steps := int(duration * 30)   # 30 samples/sec
	for i in steps + 1:
		var t := float(i) / steps
		path.append({"t": t * duration, "pos": from.lerp(to, t)})
	return path

static func _make_ghost_jump(from: Vector2, to: Vector2,
		jump_start: Vector2, jump_land: Vector2, duration: float) -> Array:
	var path: Array = []
	var steps := int(duration * 30)
	var gap_mid_x := (jump_start.x + jump_land.x) * 0.5
	for i in steps + 1:
		var t := float(i) / steps
		var time := t * duration
		var x := lerpf(from.x, to.x, t)
		var y := from.y
		# Parabolic arc over the gap
		if x > jump_start.x and x < jump_land.x:
			var gap_t := (x - jump_start.x) / (jump_land.x - jump_start.x)
			y = from.y - sin(gap_t * PI) * 220.0
		path.append({"t": time, "pos": Vector2(x, y)})
	return path

static func _make_ghost_stairs() -> Array:
	# Hand-craft a path up the stairs
	var waypoints: Array[Dictionary] = [
		{"t": 0.0,  "pos": Vector2(160, 830)},
		{"t": 1.0,  "pos": Vector2(550, 830)},
		{"t": 1.3,  "pos": Vector2(620, 680)},    # jump to step 1
		{"t": 1.8,  "pos": Vector2(730, 680)},
		{"t": 2.1,  "pos": Vector2(960, 520)},    # jump to step 2
		{"t": 2.6,  "pos": Vector2(1140, 520)},
		{"t": 2.9,  "pos": Vector2(1360, 360)},   # jump to top
		{"t": 3.5,  "pos": Vector2(1660, 350)},   # reach goal
	]
	# Interpolate to smooth path
	var path: Array = []
	var total_t: float = waypoints[-1].t
	var steps := int(total_t * 30)
	for i in steps + 1:
		var time := float(i) / steps * total_t
		# Find surrounding waypoints
		var a_idx := 0
		for j in waypoints.size() - 1:
			if waypoints[j + 1].t >= time:
				a_idx = j
				break
		var a: Dictionary = waypoints[a_idx]
		var b: Dictionary = waypoints[min(a_idx + 1, waypoints.size() - 1)]
		var seg_t := 0.0
		if b.t > a.t:
			seg_t = (time - a.t) / (b.t - a.t)
		var pos: Vector2 = (a.pos as Vector2).lerp(b.pos, seg_t)
		path.append({"t": time, "pos": pos})
	return path

## Resolve cheats for a given attempt. Picks the highest-threshold
## cheat set that the attempt has reached.
static func get_cheats_for_attempt(level_data: Dictionary, attempt: int) -> Array:
	var cheat_table: Dictionary = level_data.get("cheats", {})
	var best_key := 0
	for key in cheat_table:
		var k := int(key)
		if attempt >= k and k > best_key:
			best_key = k
	if best_key > 0:
		return cheat_table[best_key]
	return []
