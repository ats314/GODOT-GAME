# Performance: what actually costs frames in Godot 4.7

Answers "why is this slow, how do I prove it, and is the fix worth the complexity?" for a Godot 4.7.1
project shipping to **desktop PC and Steam Deck** (see `../../docs/PLATFORM_TARGETS.md`). Read it before
proposing any optimization and before writing per-frame code. Every backticked symbol was checked against
`third_party/godot-class-reference/classes/*.xml` (tag `4.7.1-stable`); magnitudes are `[doc]` when the
manual states them and `[measure]` when they are folklore you must verify on your own scene.

**The one rule: measure, change one thing, measure again.** Bottlenecks are hardware-specific — a Steam
Deck at 15W is a different machine from your desktop. Three failure shapes, three tools
(`third_party/godot-docs/tutorials/performance/general_optimization.rst`):

| Symptom | Likely cause | Look at |
| --- | --- | --- |
| Continuously low FPS | per-frame work scaling with object count | profiler frame time, draw calls |
| Intermittent spikes | allocation, `load()` mid-gameplay, pipeline compilation, navmesh bake | profiler graph spike + `PIPELINE_COMPILATIONS_*` |
| Slow level load | synchronous loading, navmesh baking, texture decode | `--verbose`, threaded `ResourceLoader` |

## 1. Measuring

### 1.1 Editor profiler
**Debugger > Profiler > Start** (off by default; measuring is itself expensive).
Source: `.../scripting/debug/the_profiler.rst`. **Frame Time** includes rendering; **Physics Time** is
`_physics_process` + nodes on physics update; **Idle Time** is `_process`, timers, cameras on idle. The
setting everyone forgets: **Self** vs **Inclusive** — Inclusive blames the caller, Self blames the
actually-slow function; check Self first. It does **not** profile C#, and time waiting on servers may
not be attributed (known bug).

### 1.2 `Performance` monitors
`Performance.get_monitor(monitor: int) -> float`. Works in exported builds, so you can ship a debug
overlay. `Performance.MONITOR_MAX == 59`.

| Constant | # | Note from the class XML |
| --- | --- | --- |
| `TIME_FPS` / `TIME_PROCESS` / `TIME_PHYSICS_PROCESS` / `TIME_NAVIGATION_PROCESS` | 0–3 | frames last second; then seconds per frame / physics frame / nav step |
| `MEMORY_STATIC` / `MEMORY_STATIC_MAX` | 4–5 | **not available in release builds** |
| `MEMORY_MESSAGE_BUFFER_MAX` | 6 | peak `call_deferred` queue |
| `OBJECT_COUNT` / `OBJECT_RESOURCE_COUNT` / `OBJECT_NODE_COUNT` | 7–9 | `OBJECT_NODE_COUNT` is your scene-tree budget number |
| `OBJECT_ORPHAN_NODE_COUNT` | 10 | **debug only, 0 in release**; non-zero = leak |
| `RENDER_TOTAL_OBJECTS_IN_FRAME` | 11 | |
| `RENDER_TOTAL_PRIMITIVES_IN_FRAME` | 12 | excludes culled; depth prepass + shadow passes make it 2–3× raw vertex count |
| `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | 13 | excludes culled objects |
| `RENDER_VIDEO_MEM_USED` / `RENDER_TEXTURE_MEM_USED` / `RENDER_BUFFER_MEM_USED` | 14–16 | video mem > texture + buffer (includes misc allocations) |
| `PHYSICS_2D_ACTIVE_OBJECTS` / `_COLLISION_PAIRS` / `_ISLAND_COUNT` | 17–19 | sleeping bodies excluded from active — pairs is the O(n²) canary |
| `PHYSICS_3D_ACTIVE_OBJECTS` / `_COLLISION_PAIRS` / `_ISLAND_COUNT` | 20–22 | |
| `AUDIO_OUTPUT_LATENCY` | 23 | |
| `NAVIGATION_ACTIVE_MAPS` … `NAVIGATION_OBSTACLE_COUNT` | 24–33 | combined 2D+3D nav counters |
| `PIPELINE_COMPILATIONS_CANVAS` / `_MESH` / `_SURFACE` / `_DRAW` / `_SPECIALIZATION` | 34–38 | non-zero *during gameplay* = shader stutter |
| `NAVIGATION_2D_ACTIVE_MAPS` … `NAVIGATION_2D_OBSTACLE_COUNT` | 39–48 | 2D-only split |
| `NAVIGATION_3D_ACTIVE_MAPS` … `NAVIGATION_3D_OBSTACLE_COUNT` | 49–58 | 3D-only split |

All are `Performance.`-prefixed (enum `Monitor`). Both nav sets exist in 4.7.1; prefer the split ones.
Each nav family has: `ACTIVE_MAPS`, `REGION_COUNT`, `AGENT_COUNT`, `LINK_COUNT`, `POLYGON_COUNT`,
`EDGE_COUNT`, `EDGE_MERGE_COUNT`, `EDGE_CONNECTION_COUNT`, `EDGE_FREE_COUNT`, `OBSTACLE_COUNT`.

### 1.3 Custom monitors
`Performance.add_custom_monitor(id: StringName, callable: Callable, arguments: Array = [], type: int = 0)`
— slash in `id` makes a category, callable must return a number ≥ 0. Read back with
`Performance.get_custom_monitor("game/enemies")`, which **works in exported release builds**. Also
`remove_custom_monitor`, `has_custom_monitor`, `get_custom_monitor_names`; types `MONITOR_TYPE_QUANTITY`
0, `_MEMORY` 1, `_TIME` 2, `_PERCENTAGE` 3. (`.../scripting/debug/custom_performance_monitors.rst`)

```gdscript
func _ready() -> void:
    Performance.add_custom_monitor(&"game/pool_live", _get_pool_live)
    Performance.add_custom_monitor(&"game/draw_calls", func() -> int:
        return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME))
```

### 1.4 `RenderingServer.get_rendering_info(info: int) -> int`
`RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME` 0, `_TOTAL_PRIMITIVES_IN_FRAME` 1, `_TOTAL_DRAW_CALLS_IN_FRAME` 2,
`_TEXTURE_MEM_USED` 3, `_BUFFER_MEM_USED` 4, `_VIDEO_MEM_USED` 5, `_PIPELINE_COMPILATIONS_*` 6–10.
**Caveat stated in the XML:** the object/primitive/draw-call counters describe *the current 3D scene*.
They are not a 2D draw-call meter — for 2D, hypothesis-test by adding and removing sprites.

### 1.5 Manual timing
```gdscript
var t0 := Time.get_ticks_usec()
update_enemies()
print("update_enemies() took %d us" % (Time.get_ticks_usec() - t0))
```
Run it ≥1000× and average: timer resolution is limited and the first run pays cache misses
(`cpu_optimization.rst`, "Caches").

### 1.6 Command line and `--headless`
From `third_party/godot-docs/tutorials/editor/command_line_tutorial.rst`:

| Flag | Use |
| --- | --- |
| `--headless` | `--display-driver headless --audio-driver Dummy`. **No rendering** — measures script + physics only, never draw calls. |
| `--print-fps` | FPS to stdout; cheapest CI regression signal |
| `--disable-vsync` | required for any FPS comparison; with V-Sync you measure the monitor |
| `--fixed-fps <n>` | disables real-time sync — makes runs deterministic and comparable |
| `--quit-after <n>` | quit after N iterations; bounds a headless benchmark |
| `--time-scale <s>` | fast-forward a scripted scenario |
| `--frame-delay <ms>` | simulate CPU load; **not** an FPS limiter |
| `--gpu-profile` | GPU tasks that took longest in frame rendering |
| `--gpu-index <n>` | pick a GPU (Forward+/Mobile only); list with `--verbose` |

Canonical benchmark: `godot --headless --fixed-fps 60 --quit-after 3600 --path . res://benchmarks/stress.tscn`.
Because rendering is stubbed, a headless regression points at GDScript or physics, never the renderer.

## 2. Frame budget vs physics budget

At 60 FPS the whole frame is **16.66 ms**, covering `_process`, renderer CPU work, *and* however many
physics ticks land in this frame.

- `Engine.physics_ticks_per_second` (60) = `physics/common/physics_ticks_per_second`.
- `Engine.max_physics_steps_per_frame` (8) = `physics/common/max_physics_steps_per_frame`. Below the
  tick rate the engine runs several ticks per frame — making it slower — until this cap engages.
  XML warning: the game *appears* to slow down once FPS falls below
  `physics_ticks_per_second / max_physics_steps_per_frame`, even with correct `delta` use. Raise this
  if you raise the tick rate above 60.
- `Engine.max_fps` (0 = uncapped) = `application/run/max_fps`; `display/window/vsync/vsync_mode` (1)
  takes precedence and caps at the refresh rate. With V-Sync **off**, an FPS cap you can consistently
  hit *reduces* input lag — but only in GPU-bottlenecked scenarios `[doc: Engine.xml]`.
- `Engine.time_scale`, `Engine.physics_jitter_fix` (0.5; values above 2 are not recommended).

Halving the tick rate 60→30 roughly halves physics CPU `[doc: cpu_optimization.rst]`, at the price of
jitter and **more input lag**. The manual's advice: keep 60 Hz for real-time player movement and fix
jitter with physics interpolation (§16), not with a higher tick rate.
`Engine.max_fps = 60` on menus, or `OS.low_processor_usage_mode = true` (with
`OS.low_processor_usage_mode_sleep_usec`, 6900), is a free battery/thermal win.

## 3. `_process` vs `_physics_process` vs timers vs `await`

| Mechanism | Runs | Use for |
| --- | --- | --- |
| `_process(delta)` | once per rendered frame, variable rate | camera smoothing, UI, visual-only lerps |
| `_physics_process(delta)` | fixed rate; **may run several times in one frame** | anything touching bodies, `move_and_slide`, casts, logic under interpolation |
| `Timer` node | on `timeout` | recurring events ≥ ~50 ms apart; zero per-frame script cost |
| `SceneTree.create_timer(time_sec, process_always := true, process_in_physics := false, ignore_time_scale := false)` | one-shot | fire-and-forget delays; no node |
| `await` on a signal | when it fires | sequencing, cutscenes; no polling |

1. With physics interpolation on, **all** motion must happen in `_physics_process`, directly or
   indirectly. `debug/settings/physics_interpolation/enable_warnings` (true) points at violations.
2. Turn processing off rather than early-returning: `set_process(false)`, `set_physics_process(false)`,
   `set_process_input(false)`, `set_process_unhandled_input(false)`, or
   `process_mode = Node.PROCESS_MODE_DISABLED` (4). An empty `_process` guarded by `if not active: return`
   still pays virtual dispatch per node per frame — measurable at ~10k nodes `[measure]`.
3. A 4 Hz poll should be a `Timer`, not `_process` with an accumulator you can get wrong.
4. `Node.process_priority` / `process_physics_priority` control ordering, not cost.

## 4. Per-frame allocation

GDScript allocates on `Array`/`Dictionary` literals, `String` concatenation and formatting, `.new()`,
`instantiate()`, `duplicate()`, and every method returning a new array (`get_nodes_in_group`,
`get_overlapping_bodies`, `intersect_shape`). None are free at 60 Hz × N.

```gdscript
# BAD: allocates every frame, per node
func _process(_d: float) -> void:
    var nearby := get_tree().get_nodes_in_group("enemies")   # new Array each frame
    label.text = "HP: " + str(hp) + "/" + str(max_hp)        # new Strings each frame

# GOOD: cache the list, update text only on change
func _on_hp_changed(new_hp: int) -> void:
    label.text = "HP: %d/%d" % [new_hp, max_hp]
```

- Cache `get_nodes_in_group` results and refresh on spawn/despawn signals; or use
  `SceneTree.get_first_node_in_group` / `get_node_count_in_group` when you need one/count.
- `PackedVector2Array` / `PackedFloat32Array` / `PackedInt32Array` for bulk numerics — contiguous and
  cache-friendly (`cpu_optimization.rst`), unlike `Array[Vector2]`. `resize()` once, don't `append()` in
  a loop.
- `preload()` (constant, resolved at script load) not `load()` in gameplay code — `load()` mid-frame is
  the classic spike (`best_practices/logic_preferences.rst`).
- Set node properties **before** `add_child()`; some setters run expensive update code once parented.

Magnitude: over thousands of items this is usually the single largest GDScript win `[measure]`; on 20 UI
nodes it is noise.

## 5. `get_node` caching

`Node.get_node(path)` walks the tree and parses the `NodePath` per call.
`Node.find_child(pattern, recursive := true, owned := true)` is far worse — a recursive pattern match.

```gdscript
@onready var _sprite: Sprite2D = $Visual/Sprite2D
@onready var _hitbox: Area2D = %Hitbox        # scene-unique names need caching too
```

Never call `get_node` / `$` / `%` / `find_child` inside `_process` or `_physics_process`. Use `@onready`,
or `get_node_or_null` once in `_ready()` when the node is optional. Small constant win for a handful of
uses `[measure]`, large inside a loop over 1000 entities; premature for a lookup that already runs once.

## 6. Signals vs direct calls

A signal goes through `Object.emit_signal` and dispatches to every connection; a direct call on a cached
reference does not. Signals are strictly more expensive per emission — but the cost is per emission, not
per frame, and decoupling usually wins.

- Signals for **events** (died, level_completed) — tens of fires, not 60/s × N.
- Direct calls on cached references for **per-frame data flow**.
- `Object.connect(signal, callable, flags)` with `Object.CONNECT_DEFERRED` (1) defers to idle time —
  good for thread safety and physics-callback reentrancy, but it queues through the message buffer
  (watch `MEMORY_MESSAGE_BUFFER_MAX`). `Object.CONNECT_ONE_SHOT` (4) auto-disconnects.
- `SceneTree.call_group(group, method, ...)` iterates the group each call; for per-frame broadcasts
  iterate a cached array instead.

I could not verify any published signal-vs-direct-call ratio for 4.7. Do not quote one — time it with
`Time.get_ticks_usec()` over 100k iterations on the target platform.

## 7. Object pooling — full pattern (known gap in this repo)

Nothing under `third_party/` implements pooling: `grep -i pool library/code/scripts.tsv` returns zero
rows across 1422 vendored `.gd` files. The canonical pattern in full:

```gdscript
# res://systems/node_pool.gd
class_name NodePool
extends RefCounted

## Recycles instances of one PackedScene. Pooled nodes implement `pool_reset()`
## and must never free themselves.

var _scene: PackedScene
var _parent: Node
var _free: Array[Node] = []
var _live := 0

func _init(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
    _scene = scene
    _parent = parent
    for _i in prewarm:
        _free.push_back(_make())

func _make() -> Node:
    var n: Node = _scene.instantiate()
    # Configure BEFORE parenting; some setters run expensive update code once in-tree.
    n.set_process(false)
    n.set_physics_process(false)
    return n

func acquire() -> Node:
    var n: Node = _free.pop_back() if not _free.is_empty() else _make()
    _live += 1
    if n.get_parent() == null:
        _parent.add_child(n)
    n.set_process(true)
    n.set_physics_process(true)
    if n is CanvasItem: (n as CanvasItem).show()
    elif n is Node3D: (n as Node3D).show()
    if n.has_method(&"pool_reset"):
        n.call(&"pool_reset")
    n.reset_physics_interpolation()   # else the recycled node streaks from its old transform
    return n

func release(n: Node) -> void:
    if n == null or not is_instance_valid(n):
        return
    n.set_process(false)
    n.set_physics_process(false)
    if n is CanvasItem: (n as CanvasItem).hide()
    elif n is Node3D: (n as Node3D).hide()
    _live -= 1
    _free.push_back(n)   # stays parented but inert

func live_count() -> int:
    return _live

func destroy() -> void:
    for n in _free: n.queue_free()
    _free.clear()
```

```gdscript
const BULLET := preload("res://actors/bullet.tscn")
var _bullets: NodePool

func _ready() -> void:
    _bullets = NodePool.new(BULLET, self, 64)

func fire(at: Vector2, dir: Vector2) -> void:
    var b := _bullets.acquire()
    b.global_position = at
    b.velocity = dir * 900.0
    b.expired.connect(_bullets.release.bind(b), Object.CONNECT_ONE_SHOT)
```

Rules encoded above: pooled nodes never `queue_free()` themselves, they signal; reset **all** mutable
state in `pool_reset()` (velocity, timers, `modulate`, `Area2D.monitoring`, animation state — leaked
state is the #1 pooling bug); call `Node.reset_physics_interpolation()` after repositioning; use
`CONNECT_ONE_SHOT` or disconnect, since accumulated connections leak; expose `live_count()` as a custom
monitor so an unbounded pool (a missing `release()`) is visible. Documented alternative
(`cpu_optimization.rst`, "SceneTree"): `Node.remove_child()` + re-attach later is sometimes much faster
than pausing or hiding, at the cost of a tree edit per acquire — measure both.

**Magnitude / when premature.** Pooling removes instantiate + `queue_free` churn: worth it for objects
created and destroyed many times per second (bullets, hit sparks, damage numbers, chunks). For enemies
spawning once per wave it is pure complexity — `instantiate()` is fast and `queue_free()` is already
deferred to end-of-frame. Do not pool on principle.

## 8. 2D: draw calls and batching

Godot 4 batches similar canvas items into one draw call (`gpu_optimization.rst`, "2D batching"). A batch
**breaks** on a state change: different texture, different material/shader, different blend mode, or a
non-batchable item interleaved in z-order.

- Keep co-drawn sprites on one texture. Reference regions with `AtlasTexture` (`atlas`, `region`,
  `margin`, `filter_clip` — set `filter_clip = true` if neighbours bleed).
- Do not interleave: A(t1) B(t2) A(t1) B(t2) = 4 draw calls; A A B B = 2.
- Reuse one `ShaderMaterial` across items; per-instance variation goes through uniforms, not new materials.
- Rarely the answer, but they exist: `rendering/2d/batching/item_buffer_size` (16384 canvas item commands
  per draw call), `rendering/2d/batching/uniform_set_cache_size` (4096).
- `TileMapLayer.rendering_quadrant_size` (16) and `physics_quadrant_size` (16) group tiles for rendering
  and collision — larger = fewer, bigger batches and coarser culling. `TileMapLayer.collision_enabled`,
  `navigation_enabled`, `occlusion_enabled`, `enabled` each switch off a whole subsystem per layer.
- Drawing N items in one node's `_draw()` (`CanvasItem.draw_texture`, `draw_multimesh`) collapses N nodes
  into 1 — exactly what `third_party/godot-demo-projects/2d/bullet_shower/bullets.gd` does.

Premature below a few hundred canvas items: atlas discipline costs pipeline work.

## 9. `MultiMesh`, `MultiMeshInstance2D` / `MultiMeshInstance3D`

One draw primitive for up to millions of instances of one mesh
(`third_party/godot-docs/tutorials/performance/using_multimesh.rst`). `MultiMeshInstance2D` extends
`Node2D`; `MultiMeshInstance3D` extends `GeometryInstance3D`. The **only** drawback the manual names:
no per-instance frustum or screen culling — the whole MultiMesh draws or doesn't. Split the world into
several MultiMeshes, or set `MultiMesh.custom_aabb`.

```gdscript
extends MultiMeshInstance3D

func _ready() -> void:
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D   # format FIRST
    multimesh.mesh = BoxMesh.new()
    multimesh.instance_count = 10000                      # then allocate
    multimesh.visible_instance_count = 1000               # draw only some
    for i in multimesh.visible_instance_count:
        multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(i * 2.0, 0, 0)))
```

Changing `transform_format` after allocation is not allowed. Also: `use_colors` + `set_instance_color`;
`use_custom_data` + `set_instance_custom_data` (a `Color` of four floats per instance, read as
`INSTANCE_CUSTOM` in the shader); `buffer` / `set_buffer_interpolated`; `physics_interpolation_quality`
(`INTERP_QUALITY_FAST` 0 / `INTERP_QUALITY_HIGH` 1); `reset_instance_physics_interpolation(i)`;
`visible_instance_count` (-1 = all). For 2D: `transform_format = MultiMesh.TRANSFORM_2D`,
`set_instance_transform_2d`, `MultiMeshInstance2D.texture`; `CanvasItem.draw_multimesh(mm, texture)`.

**When it beats many nodes** `[doc: using_multimesh.rst]`: hundreds → nodes are fine; **thousands**
needing per-frame processing → prefer servers (§10); **hundreds of thousands to millions** → MultiMesh
is the only option. But first: identical `MeshInstance3D` nodes sharing mesh + material are already
auto-instanced by **Forward+** with zero setup — opaque or alpha-tested materials only, never
alpha-blended (`optimizing_3d_performance.rst`). Setting transforms one-by-one from GDScript is itself a
cost; for large counts write the whole `PackedFloat32Array` once via
`RenderingServer.multimesh_set_buffer(mm, buffer)`. Demos:
`third_party/godot-demo-projects/3d/occlusion_culling_mesh_lod`, `.../3d/visibility_ranges`; manual
`performance/vertex_animation/animating_thousands_of_fish.rst` drives one from the vertex shader alone.

## 10. Servers: `RenderingServer`, `PhysicsServer2D` / `PhysicsServer3D`

The scene tree is optional; servers are the layer beneath it
(`third_party/godot-docs/tutorials/performance/using_servers.rst`). You trade `_ready`/signals/editor
visibility for a much smaller per-object cost and thread access.

- Everything is an `RID`, allocated and freed **manually** (`RenderingServer.free_rid`,
  `PhysicsServer2D.free_rid`). Leaks print errors on exit.
- Keep a GDScript reference to any `Resource` handed to a server — RIDs do not hold one; if the
  `Texture2D`/`Mesh` is collected, the RID dies with it.
- World handles: `get_world_2d().space` / `.canvas` / `.direct_space_state`,
  `get_world_3d().space` / `.scenario`. Node-owned RIDs come from `CanvasItem.get_canvas_item()`,
  `Viewport.get_viewport_rid()` — but create your own rather than driving a node's.
- **Never read back from a server in a hot path.** Getters stall the (asynchronous) server and force a
  flush; the manual is blunt about this.

Working sketch, verified against `third_party/godot-demo-projects/2d/bullet_shower/bullets.gd`
(500 bullets, zero nodes, one `_draw`):

```gdscript
extends Node2D

const COUNT := 500
const BULLET_TEX := preload("res://bullet.png")

class Bullet:
    var position := Vector2()
    var speed := 1.0
    var body := RID()

var _bullets: Array[Bullet] = []
var _shape := RID()

func _ready() -> void:
    _shape = PhysicsServer2D.circle_shape_create()
    PhysicsServer2D.shape_set_data(_shape, 8)                  # radius in pixels
    for _i in COUNT:
        var b := Bullet.new()
        b.speed = randf_range(20.0, 80.0)
        b.body = PhysicsServer2D.body_create()
        PhysicsServer2D.body_set_space(b.body, get_world_2d().space)
        PhysicsServer2D.body_add_shape(b.body, _shape)
        PhysicsServer2D.body_set_collision_mask(b.body, 0)     # bullets ignore each other
        _bullets.push_back(b)

func _physics_process(delta: float) -> void:
    var xf := Transform2D()
    for b in _bullets:
        b.position.x -= b.speed * delta
        xf.origin = b.position
        PhysicsServer2D.body_set_state(b.body, PhysicsServer2D.BODY_STATE_TRANSFORM, xf)

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:                                          # one node draws all 500
    var offset := -BULLET_TEX.get_size() * 0.5
    for b in _bullets:
        draw_texture(BULLET_TEX, b.position + offset)

func _exit_tree() -> void:                                     # mandatory cleanup
    for b in _bullets:
        PhysicsServer2D.free_rid(b.body)
    PhysicsServer2D.free_rid(_shape)
    _bullets.clear()
```

Pure-rendering variant: `canvas_item_create()` → `canvas_item_set_parent(ci, get_canvas_item())` →
`canvas_item_add_texture_rect(ci, rect, texture_rid)` → `canvas_item_set_transform(ci, xform)`, plus
`canvas_item_reset_physics_interpolation(ci)` on the first frame or the item teleports in. Primitives
added to a canvas item cannot be edited — `canvas_item_clear(ci)` and re-add; transforms change freely.
3D: `instance_create()` → `instance_set_scenario(inst, get_world_3d().scenario)` →
`instance_set_base(inst, mesh)` → `instance_set_transform(inst, xform)`. `PhysicsServer3D` mirrors the
2D API (`body_create`, `body_set_space`, `body_add_shape`, `box_shape_create`, `sphere_shape_create`,
`body_set_state`, `free_rid`).

**Magnitude / when premature.** The manual scopes servers to "tens of thousands of instances processed
every frame". Below ~1000 objects nodes are simpler and fast enough; server code costs bugs (manual RID
lifetime, no signals, no editor view), not frames. `physics/2d/run_on_separate_thread` and
`physics/3d/run_on_separate_thread` are both `false` by default; thread-safe rendering/physics must be
enabled in project settings before driving servers from a thread (`performance/thread_safe_apis.rst`).

## 11. Physics cost

What costs: **active** bodies and **collision pairs**. Watch `PHYSICS_*_ACTIVE_OBJECTS` and
`PHYSICS_*_COLLISION_PAIRS`.

| Thing | Cost |
| --- | --- |
| `RigidBody2D`/`3D` | full simulation; sleeps at rest and drops out of the active count |
| `CharacterBody2D`/`3D` | you move it; cost is the `move_and_slide` sweep, not solver work |
| `StaticBody2D`/`3D` | cheapest; broadphase only |
| `Area2D`/`Area3D` | `monitoring` (detect entering) and `monitorable` (be detected) are **separate** costs — turn off whichever you don't need |
| Concave/trimesh shapes | far more than primitives; use simplified collision geometry `[doc]` |

**Layers and masks are a culling tool, not just a filter.** A body whose `collision_mask` excludes a
layer never generates a pair against it. bullet_shower sets `body_set_collision_mask(body, 0)` precisely
so 500 bullets do not test 124,750 pairs against each other — an O(n²) → O(n) change and the largest
single physics win available. Audit the layer matrix before touching anything else.

Casts and queries: `RayCast2D`/`3D` and `ShapeCast2D`/`3D` update once per physics tick — set
`enabled = false` when unused, and reserve `force_raycast_update()` / `force_shapecast_update()` (a full
query) for genuine mid-tick answers. `ShapeCast*.max_results` (32) caps work; lower it when you want the
first hit. `collide_with_areas` defaults `false` on casts and query params, `collide_with_bodies` `true`.
One-off queries need no node:
`get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, mask, exclude))`;
also `intersect_shape(params, max_results := 32)`, `intersect_point`, `cast_motion`, `collide_shape`,
`get_rest_info`, all mirrored in 3D — valid only inside `_physics_process` / physics callbacks.
Also per `cpu_optimization.rst`: remove distant objects from physics rather than hiding them, and reuse a
fixed budget of physics objects per area.
Demos: `third_party/godot-demo-projects/2d/physics_tests`, `.../3d/physics_tests`.

## 12. Navigation cost

Source: `third_party/godot-docs/tutorials/navigation/navigation_optimizing_performance.rst`. Watch
`TIME_NAVIGATION_PROCESS`, `NAVIGATION_*_POLYGON_COUNT`, `_EDGE_COUNT`, `_EDGE_FREE_COUNT`, `_AGENT_COUNT`.

Path search cost scales with **polygon and edge count, not world size**. A huge world on a coarse navmesh
is cheap; a small world tiled into thousands of tiny polygons (naive TileMap navigation) is expensive.
A sudden spike when a target is *unreachable* is the tell: reachable searches exit early and hide an
unoptimized mesh; unreachable ones must exhaust it.

The four mistakes, by frequency:
1. Setting `NavigationAgent*.target_position` to the player's position **every frame** — each set queries
   a new path. Compare distance; re-target only when the player has moved far enough.
2. "Is this reachable?" checks every frame — that is a full path query. Query the path once and inspect
   its last point. Doing both is two full queries per agent per frame.
3. All agents re-pathing on the same frame. Split into update groups or randomize timers.
4. Baking navmesh from detailed **visual meshes** at runtime — mesh data must be pulled from the GPU,
   locking the RenderingServer thread; can freeze the game for seconds. Use collision shapes as source
   geometry, raise `NavigationMesh` `cell_size`/`cell_height`, use `monotone`/`layers` partition types,
   and always bake on a background thread. Never scale source geometry with nodes.

Avoidance (`NavigationAgent*.avoidance_enabled`, default `false`) is separate additive RVO cost per agent
per tick, scaled by `max_neighbors` (10), `neighbor_distance` (50.0), `time_horizon_agents` (1.0) — off
for agents that don't need it. Batched/threaded API:
`NavigationServer2D.query_path(parameters, result, callback := Callable())` and its 3D twin, with
`NavigationPathQueryParameters2D/3D` + `NavigationPathQueryResult2D/3D`; stats via
`NavigationServer*.get_process_info(...)`. Avoid `map_force_update(map)` in gameplay — full resync.

## 13. Particles: counts, GPU vs CPU

`GPUParticles2D`/`3D` simulate on the GPU; `CPUParticles2D`/`3D` on the CPU. Prefer GPU except where the
target lacks support (older Compatibility/WebGL paths) or you need 2D physics interpolation (§16).

| Property | Default | Effect |
| --- | --- | --- |
| `amount` | 8 | **the real cost knob.** Raises GPU requirements even if not all particles are visible. Changing it **restarts the system** — set once. |
| `amount_ratio` | 1.0 | changes emitted count without restarting, but the XML says plainly **"Reducing `amount_ratio` has no performance benefit"** — resources are allocated and processed for the full `amount`. Art direction only; lower `amount` for perf. |
| `fixed_fps` | 30 (0 on `CPUParticles2D`) | update rate. XML notes it does *not* slow the simulation itself, so treat "lower = cheaper" as unverified `[measure]`. |
| `interpolate` | true | smooths motion when `fixed_fps` is below the refresh rate |
| `visibility_rect` (2D) | `Rect2(-100,-100,200,200)` | region that must be on screen for the system to be **active**. Too small = particles pop; too large = offscreen systems keep simulating. Generate it with **Particles → Generate Visibility Rect**. |
| `visibility_aabb` (3D) | `AABB(-4,-4,-4,8,8,8)` | same for 3D |
| `trail_enabled` / `trail_sections` / `trail_section_subdivisions` | false / 8 / 4 | mesh skinning per particle; expensive |
| `sub_emitter` | — | multiplies particle counts; audit before shipping |
| `collision_base_size` (2D) | 1.0 | particle collision is not free |
| `draw_order` | 1 (2D) / 0 (3D) | lifetime/index order is cheaper than view-depth sorting |

Particles are usually **fill-rate** bound, not simulation bound — large soft additive quads overlapping
is the killer. `gpu_optimization.rst` recommends forcing vertex shading in the particle material and
keeping transparent areas small. **Diagnosis:** shrink the window; if FPS jumps you are fill-rate limited
and the fix is fewer transparent pixels, not fewer particles.
Demos: `third_party/godot-demo-projects/2d/particles`, `.../3d/particles`.

## 14. Texture memory and atlases

Watch `RENDER_TEXTURE_MEM_USED` and `RENDER_VIDEO_MEM_USED`.
- VRAM compression is on by default for imported 3D textures. Worse than PNG on disk, far better in
  memory→GPU bandwidth — that is the entire point `[doc: gpu_optimization.rst]`.
- **Disable** it for pixel art (2D or 3D): visible artifacts, negligible gain at low resolution `[doc]`.
- Most Android devices cannot VRAM-compress textures **with transparency** — opaque only `[doc]`.
- Our targets are desktop and Steam Deck, so the desktop VRAM-compression path applies throughout and
  the Android caveat above never bites us. Still verify on the Deck, which is the weakest GPU we ship to.
- Fewer larger textures beat many small ones (§8). Reading textures is expensive per fragment, and
  trilinear filtering across mipmaps adds more — a 6-sample shader costs ~6× a 1-sample one `[doc]`.
- `PortableCompressedTexture2D` (`create_from_image`, `keep_compressed_buffer`,
  `set_basisu_compressor_params`) exists for runtime-generated textures that must stay compressed.

## 15. 3D: culling, LOD, visibility

Frustum culling is automatic; the rest you opt into.

**Occlusion culling** — off by default (`rendering/occlusion_culling/use_occlusion_culling` = `false`).
Add `OccluderInstance3D` nodes (`occluder`, `bake_mask`, `bake_simplification_distance`);
`GeometryInstance3D.ignore_occlusion_culling` opts an instance out. Tuning:
`occlusion_rays_per_thread` (512), `bvh_build_quality` (2), `jitter_projection` (true).
Magnitude: large indoors with many small rooms, near zero (net loss — the occlusion buffer costs CPU)
in open scenes. Forward+ already does a depth prepass, so the **biggest wins are on the Mobile
renderer**, which does not `[doc: occlusion_culling.rst]`.

**Mesh LOD** — automatic on import via meshoptimizer; works with `MeshInstance3D`, `MultiMeshInstance3D`,
`GPUParticles3D`, `CPUParticles3D`. Bias per instance with `GeometryInstance3D.lod_bias` (1.0), per
viewport with `Viewport.mesh_lod_threshold` (1.0), globally with
`rendering/mesh_lod/lod_change/threshold_pixels` (1.0). No setup cost — leave it on.

**Visibility ranges (HLOD)** — manual, artist-authored: `GeometryInstance3D.visibility_range_begin` /
`_end` / `_begin_margin` / `_end_margin` / `visibility_range_fade_mode`
(`VISIBILITY_RANGE_FADE_DISABLED` 0 / `_SELF` 1 / `_DEPENDENCIES` 2). Use for impostors and for hiding
distant particle effects. Demo: `third_party/godot-demo-projects/3d/visibility_ranges`.

**`VisibleOnScreenNotifier2D`/`3D`** — signals `screen_entered` / `screen_exited`, method `is_on_screen()`,
bounds via `rect` (2D, `Rect2(-10,-10,20,20)`) / `aabb` (3D, `AABB(-1,-1,-1,2,2,2)`). These do **not** cull
rendering (the renderer already does); they let *you* stop AI, animation, or `_process` for offscreen
actors. `VisibleOnScreenEnabler2D`/`3D` automate it via `enable_node_path` (default `".."`) and
`enable_mode` (`ENABLE_MODE_INHERIT` 0 / `_ALWAYS` 1 / `_WHEN_PAUSED` 2). The 3.x names
`VisibilityNotifier` / `VisibilityEnabler` do not exist in 4.7.

**Other levers, roughly by value:** reuse materials (20k objects with 100 materials is far faster than
20k with 20k `[doc]`); minimize transparent surfaces (no Z-buffer, must sort back to front);
`GeometryInstance3D.cast_shadow = SHADOW_CASTING_SETTING_OFF` on small/distant casters; bake lighting
with omni/spot lights on Static bake mode while keeping `DirectionalLight3D` dynamic; shrink shadow maps.
`Viewport` resolution levers: `scaling_3d_scale` (1.0), `scaling_3d_mode`, `fsr_sharpness` (0.2),
`msaa_3d`/`msaa_2d` (0), `use_taa` (false), `screen_space_aa` (0), `use_debanding` (false).
Demo: `third_party/godot-demo-projects/3d/occlusion_culling_mesh_lod`.

## 16. Physics interpolation and tick rate

Exists in 4.7 for **both 2D and 3D**, off by default: `physics/common/physics_interpolation` = `false`,
mirrored at runtime as `SceneTree.physics_interpolation`.

Per-node: `Node.physics_interpolation_mode` — `PHYSICS_INTERPOLATION_MODE_INHERIT` 0, `_ON` 1, `_OFF` 2.
Class defaults that surprise people: `Viewport` is `_ON`; `Control`, `CPUParticles2D`, `Parallax2D`,
`ParallaxLayer`, `BoneAttachment3D`, `VehicleWheel3D`, `XRCamera3D`, `XRNode3D` are `_OFF`.

- `Node.reset_physics_interpolation()` after teleporting/placing, or the node streaks from its old
  transform. Delivered as `Node.NOTIFICATION_RESET_PHYSICS_INTERPOLATION` (2001).
- `Node3D.get_global_transform_interpolated()` — the *displayed* transform. **3D only**; no 2D equivalent
  in 4.7 (`2d_and_3d_physics_interpolation.rst`).
- `Engine.get_physics_interpolation_fraction()` — position within the current tick.
- Servers: `RenderingServer.canvas_item_reset_physics_interpolation(item)`,
  `canvas_item_transform_physics_interpolation(item, xform)`, plus `canvas_light*`,
  `canvas_light_occluder*` and `multimesh_instance*` equivalents.
- `physics/3d/physics_interpolation/scene_traversal` (default `"DEFAULT"`).

Documented asymmetries you will trip over:
- **2D interpolation is server-side** and therefore *does* cover bodies created via `PhysicsServer2D`.
  **3D is scene-side** and does **not** cover `PhysicsServer3D`-created bodies — interpolate those
  yourself. The 3D redesign is GH-104269, which in 4.5 removed
  `RenderingServer.instance_set_interpolated` and `instance_reset_physics_interpolation`; both are
  absent from the 4.7.1 class reference.
- In 2D only `CPUParticles2D` is interpolated; `GPUParticles2D` is not yet. Keep ≥20–30 ticks/sec for
  fluid CPU particles.
- `MultiMesh` is supported in both 2D and 3D.

**Why it's a performance technique, not just a smoothness one:** interpolation is "orders of magnitude
faster" than a physics tick `[doc: cpu_optimization.rst]`, so enabling it lets you drop
`physics_ticks_per_second` 60→30 (lower for non-twitchy games) while keeping smooth motion — roughly
halving physics CPU for a small constant cost. Price: input lag, plus the discipline of putting *all*
motion in `_physics_process`. Never lower the tick rate on a real-time-movement game without measuring
the feel.

## 17. Web (HTML5) specifics

- `rendering/renderer/rendering_method.web` defaults to `"gl_compatibility"` — you are on Compatibility,
  so Forward+ assumptions (depth prepass, automatic instancing) do not hold. Measure in a browser.
- Since 4.3 a single-threaded web export exists, avoiding the `SharedArrayBuffer` / cross-origin-isolation
  headers that GitHub Pages makes awkward. It is documented as **less performant**, and `Thread` is
  unavailable (`third_party/godot-docs/tutorials/export/exporting_for_web.rst`). Every threading-based
  optimization — background navmesh baking, threaded `ResourceLoader`, `physics/*/run_on_separate_thread`
  — is therefore desktop-only unless you ship the threaded export with the required headers.
- Pipeline/shader compilation stutter is worse on web. Watch `PIPELINE_COMPILATIONS_*` and warm materials
  during loading screens; see `third_party/godot-docs/tutorials/performance/pipeline_compilations.rst`.
- WebAssembly is slower than native, so §4 and §5 matter proportionally more.

## 18. Order of attack, and when each step is premature

| # | Step | Typical magnitude | Premature when |
| --- | --- | --- | --- |
| 1 | Fix collision layers/masks | O(n²) → O(n) on pair count | never — do this first |
| 2 | Kill per-frame allocation in hot loops | large on 1000s of items `[measure]` | fewer than a few hundred iterations |
| 3 | `set_process(false)` on idle nodes | scales with node count | fewer than ~1000 nodes |
| 4 | Cache `get_node` with `@onready` | small constant, free to do | it already runs once in `_ready()` |
| 5 | Atlas + material reuse (2D batching) | draw calls ÷ 2–10 `[measure]` | under a few hundred canvas items |
| 6 | Mesh LOD + visibility ranges (3D) | large in open scenes `[doc]` | small/indoor scenes |
| 7 | Occlusion culling (3D) | large indoors, **negative** outdoors `[doc]` | open scenes; Forward+ with few occluders |
| 8 | Lower tick rate + physics interpolation | ~½ physics CPU `[doc]` | twitch gameplay; input-lag budget |
| 9 | Object pooling | removes spawn spikes | fewer than a few spawns/second |
| 10 | `MultiMesh` | thousands→millions of instances `[doc]` | under ~1000, or you need per-instance culling |
| 11 | Servers API | tens of thousands of objects `[doc]` | under ~1000 — the cost is bugs, not frames |
| 12 | Move work to C#/GDExtension | language-dependent `[doc]` | anything you have not profiled |

## 19. Things I could not verify

- Any numeric ratio for **signal emission vs direct call** in 4.7 — the manual states none. Measure
  before quoting one.
- Whether lowering `GPUParticles*.fixed_fps` reduces GPU cost. The XML says it changes the render rate
  and "does not slow down the simulation of the particle system itself", which reads against the common
  claim. Measure.
- The 4.x minor that introduced the `Performance.NAVIGATION_2D_*` / `NAVIGATION_3D_*` split; both these
  and the legacy combined constants exist in 4.7.1.
- The minor that first shipped **2D** physics interpolation (3D's scene-side redesign is GH-104269 on the
  4.5 migration page). 4.7.1 has both.
- Concrete node counts at which SceneTree housekeeping becomes the bottleneck. The manual says only
  "thousands to tens of thousands, depending on target platform" and tells you to profile per platform.
  Do not put a number in a code review comment.
- Whether tuning `rendering/2d/batching/item_buffer_size` ever pays off; no vendored demo changes it.
