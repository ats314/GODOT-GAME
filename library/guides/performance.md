# Performance: what actually costs frames in Godot 4.7

What to measure, what to fix, and what to leave alone in **Godot 4.7.1 stable** on our targets — desktop Windows/Linux and **Steam Deck**, the weakest machine we promise to run on. Read it before optimising anything, before adding a fourth thousand nodes to a scene, and before trusting a remembered claim about `MultiMesh`, pooling or signal cost. Every class, method, property, constant and project setting in backticks was grepped out of the vendored `4.7.1-stable` reference in `third_party/godot-class-reference/classes/`; magnitudes are tagged `[doc]` when a vendored manual page states them and `[measure]` when they are folklore you must confirm on hardware.

Platform is settled — `docs/PLATFORM_TARGETS.md`. Forward+ is available, `user://` is a real directory, **threads are available**; none of the single-threaded or tile-renderer advice in the vendored GPU docs applies to us except where noted. Sources, all vendored: `third_party/godot-docs/tutorials/performance/*.rst`, `tutorials/scripting/debug/{the_profiler,custom_performance_monitors,objectdb_profiler}.rst`, `tutorials/scripting/idle_and_physics_processing.rst`, `tutorials/physics/interpolation/*.rst`, `tutorials/3d/{mesh_lod,occlusion_culling}.rst`, `tutorials/navigation/navigation_optimizing_performance.rst`, `tutorials/assets_pipeline/importing_images.rst`, `tutorials/best_practices/node_alternatives.rst`.

## 0. Budgets, and the Deck as the floor

60 FPS = **16.67 ms** for CPU *and* GPU each; 30 FPS = 33.3 ms; 120 FPS = 8.3 ms. CPU and GPU run independently and **frame time is the slower of the two**, so optimising the CPU while GPU-bound changes nothing `[doc]` (`general_optimization.rst`: 9 ms → 1 ms on a 10 ms frame is 5×; the same fix on a 59 ms frame is 1.16×).

The Deck is a fixed machine — one shared ~15 W APU budget, low native resolution, 60 Hz default — and that changes four answers. **CPU and GPU compete for the same watts**, so a CPU spike down-clocks the GPU for following frames and fixing a CPU hotspot can raise GPU throughput, an effect invisible on desktop `[measure]`. **Sustained load matters, not peak**: 60 FPS for ten seconds and 45 after two minutes is thermal throttling, so benchmark for minutes `[measure]`. **Low resolution hides fill-rate bugs** that reappear at desktop 1440p/4K — test both ends. And battery is a shippable feature: cap frames (§17) rather than rendering 300 uncapped FPS in a menu.

> Deck hardware figures come from Valve's documentation, **not** the vendored Godot corpus. I could not verify them offline. Confirm on device.

## 1. The built-in profiler

**Debugger > Profiler > Start.** Off by default because profiling is itself expensive `[doc]`. Rows: **Frame Time** (everything for one image, *including rendering*), **Physics Frame** (time allocated between physics updates, 16.66 ms at 60 TPS), **Idle Time** (`_process`, timers), **Physics Time** (`_physics_process`) `[doc]`. The **Measure** dropdown switches ms / Frame % / Physics %. **Inclusive vs Self** matters: Inclusive counts nested calls, **Self** is the body alone, so a row that is slow Inclusive and cheap Self is not the bottleneck — its callee is `[doc]`. Stated limits: server wait time **may not be counted** (called a known bug) and **C# is unsupported** `[doc]`, so a slow frame with no script row is GPU, driver or server time. The **ObjectDB Profiler** (Debugger panel, **since 4.6** `[doc]`) snapshots and diffs every allocated `Object` — for leaks, not frame time.

## 2. `Performance` monitors — the real constants

`Performance.get_monitor(id)` returns a `float`. This is the complete `Performance.Monitor` enum in 4.7.1:

| Constant(s) | Meaning |
| --- | --- |
| `TIME_FPS`, `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, `TIME_NAVIGATION_PROCESS` | FPS; seconds per frame / physics frame / navigation step |
| `MEMORY_STATIC`, `MEMORY_STATIC_MAX`, `MEMORY_MESSAGE_BUFFER_MAX` | static memory used/available; peak deferred-call buffer |
| `OBJECT_COUNT`, `OBJECT_RESOURCE_COUNT`, `OBJECT_NODE_COUNT` | live objects / resources / nodes |
| `OBJECT_ORPHAN_NODE_COUNT` | nodes alive but outside the tree — **watch when pooling (§8)** |
| `RENDER_TOTAL_OBJECTS_IN_FRAME`, `RENDER_TOTAL_PRIMITIVES_IN_FRAME`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | last-frame objects, vertices/indices, **draw calls** |
| `RENDER_VIDEO_MEM_USED`, `RENDER_TEXTURE_MEM_USED`, `RENDER_BUFFER_MEM_USED` | VRAM in bytes |
| `PHYSICS_2D_ACTIVE_OBJECTS`, `PHYSICS_2D_COLLISION_PAIRS`, `PHYSICS_2D_ISLAND_COUNT` (and `PHYSICS_3D_*`) | physics load; **pairs predicts cost, not body count** |
| `AUDIO_OUTPUT_LATENCY` | output latency |
| `NAVIGATION_ACTIVE_MAPS`, `_REGION_COUNT`, `_AGENT_COUNT`, `_LINK_COUNT`, `_POLYGON_COUNT`, `_EDGE_COUNT`, `_EDGE_MERGE_COUNT`, `_EDGE_CONNECTION_COUNT`, `_EDGE_FREE_COUNT`, `_OBSTACLE_COUNT` | combined navigation; the same ten also exist as `NAVIGATION_2D_*` and `NAVIGATION_3D_*` |
| `PIPELINE_COMPILATIONS_CANVAS`, `_MESH`, `_SURFACE`, `_DRAW`, `_SPECIALIZATION` | shader stutter sources (§19) |
| `MONITOR_MAX` | enum size — never read it |

The `NAVIGATION_2D_*`/`NAVIGATION_3D_*` split exists in 4.7; I could not verify which 4.x added it. Polling a handful of `get_monitor()` reads per frame is fine `[measure]`. Custom monitors: the callback must return a number `>= 0` and the editor polls it **once per second** `[doc]`; `get_custom_monitor()` works in exported release builds too `[doc]`.

```gdscript
func _ready() -> void:   # a slash makes a category; without one it lands under "Custom"
    Performance.add_custom_monitor("game/enemies", _count_enemies)
    Performance.add_custom_monitor("pool/live", _pool.live_count, [], Performance.MONITOR_TYPE_QUANTITY)

func _count_enemies() -> int:
    return get_tree().get_nodes_in_group(&"enemies").size()
```

Rest of that API: `get_custom_monitor()`, `get_custom_monitor_names()`, `get_custom_monitor_types()`, `has_custom_monitor()`, `remove_custom_monitor()`, `get_monitor_modification_time()`; `MonitorType` values `MONITOR_TYPE_QUANTITY`, `MONITOR_TYPE_MEMORY`, `MONITOR_TYPE_TIME`, `MONITOR_TYPE_PERCENTAGE`.

```gdscript
var vp := get_viewport()
var canvas_draws := vp.get_render_info(Viewport.RENDER_INFO_TYPE_CANVAS, Viewport.RENDER_INFO_DRAW_CALLS_IN_FRAME)
RenderingServer.viewport_set_measure_render_time(vp.get_viewport_rid(), true)   # opt-in, per viewport
var gpu_ms := RenderingServer.viewport_get_measured_render_time_gpu(vp.get_viewport_rid())
var cpu_ms := RenderingServer.viewport_get_measured_render_time_cpu(vp.get_viewport_rid())
```

`Viewport.RenderInfoType` is `RENDER_INFO_TYPE_VISIBLE` / `_SHADOW` / `_CANVAS`; `Viewport.RenderInfo` is `RENDER_INFO_OBJECTS_IN_FRAME` / `_PRIMITIVES_IN_FRAME` / `_DRAW_CALLS_IN_FRAME`. `RenderingServer.get_rendering_info()` accepts `RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME`, `RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME`, `RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME`, `RENDERING_INFO_TEXTURE_MEM_USED`, `RENDERING_INFO_BUFFER_MEM_USED`, `RENDERING_INFO_VIDEO_MEM_USED`, and the five `RENDERING_INFO_PIPELINE_COMPILATIONS_*`.

**Manual and headless timing.** Run many iterations and average — timer granularity, scheduling and first-run cache misses make one sample noise `[doc]` (`cpu_optimization.rst`, "Caches").

```gdscript
const ITERATIONS := 1000
var t0 := Time.get_ticks_usec()
for _i in ITERATIONS: update_enemies()
print("update_enemies(): %.2f us" % (float(Time.get_ticks_usec() - t0) / ITERATIONS))
```

`godot --headless --path . --script res://your_benchmark.gd` implies `--display-driver headless --audio-driver Dummy` `[doc]`; add `--fixed-fps <n>` (disables real-time sync, makes runs comparable) and `--print-fps`. Headless measures logic only — nothing about draw calls or fill rate.

**Three-minute triage.** (1) Disable V-Sync and run windowed large, then tiny: a big FPS jump when small means fill-rate bound `[doc]`. (2) Compare `viewport_get_measured_render_time_gpu` to Frame Time for CPU-vs-GPU. (3) Idle Time vs Physics Time splits the CPU. (4) Binary-search by commenting out half the per-frame work `[doc]`.

## 3. `_process` vs `_physics_process` vs timers vs `await`

| Mechanism | Rate | Use for | Cost |
| --- | --- | --- | --- |
| `_process(delta)` | every rendered frame | cameras, UI, visual lerps | runs **after** the physics step in single-threaded games `[doc]` |
| `_physics_process(delta)` | fixed, `physics/common/physics_ticks_per_second` (60) | anything touching bodies; deterministic logic | with interpolation on, **all** movement belongs here `[doc]` |
| `Timer` / `SceneTree.create_timer(sec, process_always, process_in_physics, ignore_time_scale)` | on demand | cooldowns, staggered work | a node each, versus one `SceneTreeTimer` object |
| `await` a signal | on demand | sequencing without a state machine | no per-frame cost while suspended `[measure]` |

The biggest per-frame CPU win in a node-heavy scene is **not having a callback at all**: `_process` and `_physics_process` propagate through the whole tree, and an empty override still pays traversal `[doc]`. So call `set_process(false)` / `set_physics_process(false)` in `_ready()` and re-enable on activation — do not early-return inside the callback. Ordering is `Node.process_priority` (for `_process`, `_input`, …) and `Node.process_physics_priority`; `Node.process_mode` takes `PROCESS_MODE_INHERIT`, `_PAUSABLE`, `_WHEN_PAUSED`, `_ALWAYS`, `_DISABLED`. One manager iterating an array of 500 `RefCounted` records beats 500 nodes each running `_process`: that is the difference between "thousands to tens of thousands" of nodes being viable and not `[doc]`, and is typically several times cheaper `[measure]`. **Premature when** you have under a few hundred active nodes.

## 4. Nodes are not free — and hiding is not removing

From `cpu_optimization.rst` and `best_practices/node_alternatives.rst`: the node ceiling is "thousands to tens of thousands", target-dependent `[doc]`, so profile on the Deck; the renderer handles each node individually, making **fewer nodes each doing more** faster `[doc]`; **removing from the tree beats hiding or pausing** `[doc]` — keep the reference, call `Node.remove_child()`, re-attach with `Node.add_child()`, which is the basis of §8; and the lighter alternatives ascending are `Object` (manual `free()`), `RefCounted` (automatic), `Resource` (serialisable and Inspector-visible) `[doc]`. Vendored "one node, many things": `third_party/godot-demo-projects/2d/bullet_shower/bullets.gd` draws 500 bullets from a single `_draw()`.

## 5. 2D draw calls and batching

Godot batches similar 2D items into one draw call, minimising state/material/texture changes `[doc]` (`gpu_optimization.rst`). Batching breaks on any change of material, shader, texture or blend state between consecutively drawn items, so: **atlas sprites** to share a source texture (`AtlasTexture` crops a region of one `Texture2D`); **reuse materials** — a `ShaderMaterial` clone per instance defeats batching, share one and vary per instance via `CanvasItem.self_modulate` or shader instance uniforms; **do not interleave** (A/B/A with different textures forces three batches — sort by texture, remembering `z_index` and `y_sort_enabled` decide the real order); and **prefer one custom `_draw()` over many nodes**, since one `CanvasItem` issuing N `draw_texture()` calls removes the node overhead and still batches.

Verify with `RENDER_INFO_TYPE_CANVAS` + `RENDER_INFO_DRAW_CALLS_IN_FRAME`; a well-atlased 2D scene should sit in the **tens** of canvas draw calls `[measure]`. **Premature when** already under a few hundred draw calls, or when fill-rate bound — batching does not reduce shaded pixels.

## 6. `MultiMesh`, `MultiMeshInstance2D`, `MultiMeshInstance3D`

One draw primitive that can draw "up to millions of objects in one go" via GPU instancing `[doc]` (`using_multimesh.rst`) — grass, flocks, debris, bullet swarms: thousands of copies sharing one `Mesh` and material.

```gdscript
extends MultiMeshInstance3D
const MAX_INSTANCES := 10000

func _ready() -> void:
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D   # format and use_colors BEFORE sizing
    multimesh.use_colors = true
    multimesh.mesh = BoxMesh.new()
    multimesh.instance_count = MAX_INSTANCES              # allocate the ceiling once
    multimesh.visible_instance_count = 0                  # then reveal what you need

func spawn(index: int, xform: Transform3D, tint: Color) -> void:
    multimesh.set_instance_transform(index, xform)
    multimesh.set_instance_color(index, tint)
    multimesh.visible_instance_count = maxi(multimesh.visible_instance_count, index + 1)
```

4.7 surface: properties `instance_count`, `visible_instance_count`, `transform_format` (`MultiMesh.TRANSFORM_2D` / `TRANSFORM_3D`), `mesh`, `use_colors`, `use_custom_data`, `custom_aabb`, `buffer`, `transform_array`, `transform_2d_array`, `color_array`, `custom_data_array`, `physics_interpolation_quality` (`INTERP_QUALITY_FAST` / `INTERP_QUALITY_HIGH`); methods `set_instance_transform()`, `set_instance_transform_2d()`, `set_instance_color()`, `set_instance_custom_data()`, matching getters, `get_aabb()`, `set_buffer_interpolated()`, `reset_instance_physics_interpolation()`, `reset_instances_physics_interpolation()`. The 2D node is `MultiMeshInstance2D` (`multimesh`, `texture`, signal `texture_changed`).

**The catch: no per-instance frustum or screen culling** — the whole `MultiMesh` draws or does not `[doc]`; the documented workaround is splitting the world into several `MultiMesh`es by region `[doc]`. **Try automatic instancing first:** in Forward+, `MeshInstance3D` nodes sharing a mesh **and** material are instanced with zero setup — but only for **opaque or alpha-tested** materials, never alpha-blended or depth-prepass ones, which is exactly when `MultiMesh` becomes necessary `[doc]`. Automatic instancing is **Forward+ only** `[doc]`. **Premature when** under ~100 copies, or when copies need distinct materials; the docs put the **servers API** (§7) ahead of `MultiMesh` when thousands of objects need per-object logic *and* individual control, and `MultiMesh` ahead at hundreds of thousands to millions `[doc]`. Demos: `third_party/godot-demo-projects/2d/instancing`, `.../3d/visibility_ranges`.

## 7. The servers API — bypassing the scene tree

`RenderingServer`, `PhysicsServer2D`, `PhysicsServer3D` and `AudioServer` are the low-level APIs the scene tree is built on. Going direct removes node and memory overhead and is **the only way to drive rendering/physics from threads** `[doc]`. Everything is an opaque `RID` you allocate and free **manually**, and two rules bite: **resources are ref-counted, their `RID`s are not**, so keep a GDScript reference to any `Texture2D`/`Mesh` handed to a server or both it and its `RID` are erased under you `[doc]`; and **never read back** from these servers — they run asynchronously, so any getter stalls them and flushes pending work, which is catastrophic per frame and invisible in a profiler `[doc]`.

Adapted from `third_party/godot-demo-projects/2d/bullet_shower/bullets.gd` — 500 collidable bullets, no nodes:

```gdscript
extends Node2D
const BULLET_COUNT := 500
const BULLET_TEX: Texture2D = preload("res://bullet.png")   # keep the reference alive

class Bullet:
    var position := Vector2.ZERO
    var speed := 1.0
    var body := RID()

var _bullets: Array[Bullet] = []
var _shape := RID()

func _ready() -> void:
    _shape = PhysicsServer2D.circle_shape_create()
    PhysicsServer2D.shape_set_data(_shape, 8.0)             # radius, px
    for _i in BULLET_COUNT:
        var b := Bullet.new()
        b.speed = randf_range(20.0, 80.0)
        b.body = PhysicsServer2D.body_create()
        PhysicsServer2D.body_set_space(b.body, get_world_2d().space)
        PhysicsServer2D.body_add_shape(b.body, _shape)
        PhysicsServer2D.body_set_collision_mask(b.body, 0)  # bullets ignore each other: huge win
        _bullets.push_back(b)

func _physics_process(delta: float) -> void:
    var xform := Transform2D()
    for b: Bullet in _bullets:
        b.position.x -= b.speed * delta
        xform.origin = b.position
        PhysicsServer2D.body_set_state(b.body, PhysicsServer2D.BODY_STATE_TRANSFORM, xform)

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:                                        # ONE canvas item draws all 500
    var offset := -BULLET_TEX.get_size() * 0.5
    for b: Bullet in _bullets:
        draw_texture(BULLET_TEX, b.position + offset)

func _exit_tree() -> void:                                   # mandatory: RIDs are not collected
    for b: Bullet in _bullets:
        PhysicsServer2D.free_rid(b.body)
    PhysicsServer2D.free_rid(_shape)
    _bullets.clear()
```

Handles into the servers: `CanvasItem.get_canvas_item()`, `CanvasLayer.get_canvas()`, `Viewport.get_viewport_rid()`, `World2D.space` / `.canvas` / `.navigation_map`, `World3D.scenario` / `.space`, `VisualInstance3D.get_instance()` / `.get_base()` `[doc]`. A purely visual 2D object is `RenderingServer.canvas_item_create()` + `canvas_item_set_parent()` + `canvas_item_add_texture_rect()` + `canvas_item_set_transform()`, then `RenderingServer.canvas_item_reset_physics_interpolation()` on the first frame or it visibly teleports in `[doc]`; the 3D path is `instance_create()` (or `instance_create2(base, scenario)`) + `instance_set_scenario()` + `instance_set_base()` + `instance_set_transform()`. Canvas primitives are immutable once added — `canvas_item_clear()` and re-add — while transforms may be set freely `[doc]`. **Magnitude:** the docs position this as the fix for "tens of thousands of instances processed every frame" `[doc]`. **Premature when** below a few thousand objects, or when they need editor authoring, signals or per-object scripts — you trade all engine ergonomics for it.

## 8. Object pooling — the canonical pattern

**Nothing in `third_party/` implements pooling** (`grep -i pool library/code/scripts.tsv` → 0 rows), so this is where our pattern lives. Copy it; do not reinvent it per system. GDScript has no GC to placate, but `instantiate()` allocates nodes, scripts and resources and runs `_ready()` while `queue_free()` frees at end of frame — doing that 60 times a second produces allocation churn and an `OBJECT_COUNT` sawtooth. The vendored docs endorse the shape: reuse physics objects rather than creating them, and detach rather than hide `[doc]` (`cpu_optimization.rst`).

```gdscript
class_name NodePool
extends RefCounted
## Fixed-capacity pool of instances of one PackedScene. Free nodes live OUTSIDE the tree
## (detaching beats hiding, per cpu_optimization.rst). Pooled nodes may optionally implement
## `_pool_acquire()` / `_pool_release()` to reset their own state.

var _scene: PackedScene
var _free: Array[Node] = []
var _live: Array[Node] = []
var _capacity: int
var _grow: bool

func _init(scene: PackedScene, capacity: int, prewarm: bool = true, grow: bool = false) -> void:
    _scene = scene
    _capacity = capacity
    _grow = grow
    if prewarm:
        for _i in capacity:
            _free.push_back(_make())

func _make() -> Node:
    var n := _scene.instantiate()
    n.set_process(false)          # a detached node must not tick; re-enabled in _pool_acquire()
    n.set_physics_process(false)
    return n

## Take a node and attach it under `parent`. Returns null when exhausted and not growing.
func acquire(parent: Node) -> Node:
    var n: Node
    if not _free.is_empty():
        n = _free.pop_back()
    elif _grow or _live.size() < _capacity:
        n = _make()
    else:
        return null               # hard cap: drop the spawn, never stall the frame
    _live.push_back(n)
    parent.add_child(n)
    if n.has_method(&"_pool_acquire"):
        n.call(&"_pool_acquire")
    return n

## Return a node. Safe from inside the node's own signal handler.
func release(n: Node) -> void:
    var i := _live.find(n)
    if i == -1:
        return                    # double release: ignore rather than corrupt the pool
    _live.remove_at(i)
    if n.has_method(&"_pool_release"):
        n.call(&"_pool_release")
    n.set_process(false)
    n.set_physics_process(false)
    var parent := n.get_parent()
    if parent != null:
        parent.remove_child.call_deferred(n)   # deferred: never reparent mid-callback
    _free.push_back(n)

func live_count() -> int: return _live.size()
func free_count() -> int: return _free.size()

## MANDATORY. Detached nodes are orphans and leak unless freed explicitly.
func destroy() -> void:
    for n: Node in _free:
        n.free()
    for n: Node in _live:
        if n.get_parent() != null:
            n.get_parent().remove_child(n)
        n.free()
    _free.clear()
    _live.clear()
```

The pooled node opts in by implementing the two hooks — `_pool_acquire()` re-enables processing and monitoring and resets visuals; `_pool_release()` sets `monitoring = false` (an `Area2D`/`Area3D` keeps generating collision pairs otherwise) and zeroes velocity — and calls `_pool.release(self)` where it would have called `queue_free()`.

Rules that make or break it: **free the pool** — detached nodes are *orphans* and nothing frees them, so call `destroy()` from the owner's `_exit_tree()` and treat a rising `Performance.OBJECT_ORPHAN_NODE_COUNT` as a leak, not noise. **Prewarm during loading**, never mid-combat, since the whole point is moving allocation out of the frame. **Cap hard** — `grow = true` unbounded is a memory leak in costume; prefer dropping a spawn to a hitch. **Reset everything** in `_pool_release()` (velocity, timers, tweens, `monitoring`, shader params, animation state): pooling bugs are almost always stale state, not performance. **Double `release()` is a real hazard**, hence the `find()` guard — a node released by both a timeout and a collision handler would otherwise sit twice in `_free`. **Do not pool what you rarely free**; pooling a boss costs complexity and saves nothing. And if the pooled thing needs no visuals or UI, skip nodes entirely: a `RefCounted` record plus one server `RID` (§7) is strictly cheaper than a pooled node.

**Magnitude:** for high-churn objects (bullets, hit sparks, damage numbers) this removes per-spawn allocation entirely; expect the win as **fewer spikes**, not higher average FPS `[measure]`. **Premature when** spawn rate is a few per second, or the profiler shows no allocation-shaped spikes — pooling is the classic cargo-cult optimisation.

## 9. Per-frame allocation

Modern CPUs are usually memory-bandwidth bound, and linear, cache-local data beats clever algorithms on scattered data `[doc]` (`general_optimization.rst`). In a `_process`/`_physics_process` body: do not build `Array`s or `Dictionary`s per frame (allocate once, `clear()`, reuse); use `Packed*Array` (`PackedVector2Array`, `PackedFloat32Array`) for bulk numerics since they are contiguous; hoist invariants out of loops and flatten nested loops when a dimension is known `[doc]`; precompute at load time or bake into a constant `[doc]`; and avoid per-frame `String` concatenation. Deferred calls queue into the message buffer, so `MEMORY_MESSAGE_BUFFER_MAX` is the monitor that catches `call_deferred` abuse.

## 10. Signals vs direct calls, and `get_node` caching

Both are real but small — hygiene, not optimisation. `Object.connect(signal, callable, flags)` takes `ConnectFlags` `CONNECT_DEFERRED`, `CONNECT_PERSIST`, `CONNECT_ONE_SHOT`, `CONNECT_REFERENCE_COUNTED`, `CONNECT_APPEND_SOURCE_OBJECT`. An emission walks a connection list and dispatches through `Callable`s where a direct call does not, so expect a signal to cost noticeably more per invocation but to be irrelevant below thousands of emissions per frame `[measure]` — no vendored doc quantifies it. Keep signals for cross-system decoupling; replace them with direct calls **only** in an inner loop the profiler already flagged. `CONNECT_DEFERRED` is a correctness tool (thread/tree safety), not a performance one.

`get_node()` / `$Path` walks the tree **every call**; cache with `@onready`, which costs nothing extra — `@onready var _sprite: Sprite2D = $Visuals/Sprite2D`, or `get_node_or_null(^"../Body")` for optional nodes. Use `&"name"` / `^"path"` literals to avoid re-allocating a `StringName`/`NodePath` per call. `get_tree().get_nodes_in_group()` **allocates and scans** — call it once per frame in a manager, never per node.

## 11. Physics cost

`PHYSICS_2D_COLLISION_PAIRS` / `PHYSICS_3D_COLLISION_PAIRS` predicts cost better than body count.

| Lever | Effect |
| --- | --- |
| Simplified collision shapes (primitives, not render meshes) | large, usually invisible to players `[doc]` |
| **Collision layers/masks as culling** | cheapest possible fix — a masked-out pair is never generated. `bullet_shower` uses `body_set_collision_mask(body, 0)` so bullets ignore bullets |
| Remove out-of-area bodies; reuse a fixed budget of bodies | recommended explicitly `[doc]` |
| `Area2D`/`Area3D` `monitoring` / `monitorable` off when parked | areas cost per-pair monitoring even with no handlers |
| Lower `physics_ticks_per_second` | proportional saving, but see §17 |
| `physics/2d/solver/solver_iterations`, `physics/3d/solver/solver_iterations` (default 16) | trades stability for time |
| `physics/2d/time_before_sleep`, `sleep_threshold_linear`, `sleep_threshold_angular` | sleeping bodies leave `*_ACTIVE_OBJECTS` |

**Bodies versus areas.** A `StaticBody2D`/`RigidBody2D`/`CharacterBody2D` (and the `3D` equivalents) participates in solving, while an `Area2D`/`Area3D` only monitors overlaps — so "did something enter this region" is much cheaper as an area with a tight `collision_mask`, though a large area still generates a pair per overlapping shape. Use `set_collision_layer_value(n, bool)` / `set_collision_mask_value(n, bool)` (1-indexed) rather than hand-computed bitmasks.

**Casts versus direct queries.** `RayCast2D`/`RayCast3D` and `ShapeCast2D`/`ShapeCast3D` are **nodes that query every physics tick while `enabled`**. A shape cast sweeps volume and costs materially more than a ray; a `ShapeCast3D` with the default `max_results = 32` and `collide_with_areas = true` is expensive. Set `enabled = false` and call `force_raycast_update()` / `force_shapecast_update()` on demand. For occasional queries skip the node entirely: `get_world_2d().direct_space_state` (or `PhysicsServer2D.space_get_direct_state(space)`) gives a `PhysicsDirectSpaceState2D` with `intersect_ray()`, `intersect_shape()`, `intersect_point()`, `collide_shape()`, `cast_motion()`, `get_rest_info()`. Narrow the query parameters' `collision_mask`, `collide_with_bodies`, `collide_with_areas` — an unmasked query tests the whole world — and remember space-state queries are **only valid inside `_physics_process`**. Demos: `third_party/godot-demo-projects/{2d,3d}/physics_tests`.

## 12. Navigation cost

From `navigation_optimizing_performance.rst`. **Agent query storms** are the usual culprit: never set `target_position` to a moving player every frame, since that is a path query per frame — compare distance and re-target only past a threshold `[doc]`; never poll "is this reachable?", which costs a full path query, so query the path and inspect its last point instead `[doc]`; and **stagger agents** into update groups or random timers so they do not all re-path on one frame `[doc]`. **Search cost scales with polygon and edge count, not world size** `[doc]`, so a huge world with a coarse navmesh is fine while a small world diced into per-tile navmeshes is not, and an **unreachable** target is the worst case because there is no early exit `[doc]`. **Baking** belongs on a background thread at runtime `[doc]`: raise `cell_size`/`cell_height`, switch `SamplePartitionType` from watershed to monotone or layers `[doc]`, use **physics collision shapes rather than visual meshes** as source geometry (parsing a visual mesh pulls data back from the GPU and locks the `RenderingServer` thread, which can hitch or freeze) `[doc]`, and never scale source geometry via node scale `[doc]`. **Map synchronisation**: vertex merges are cheap and edge-connection merges are not, so author navmeshes whose edges share vertices `[doc]` — the diagnostic is `NAVIGATION_EDGE_MERGE_COUNT` dominating `NAVIGATION_EDGE_CONNECTION_COUNT` `[doc]`.

`NavigationServer2D`/`NavigationServer3D` are thread-safe and truly parallel `[doc]`; raise `navigation/pathfinding/max_threads` (default 4) if saturated. `AStar2D`, `AStar3D`, `AStarGrid2D` are **not** thread-safe — one dedicated thread per object at most `[doc]`. Demos: `third_party/godot-demo-projects/2d/navigation_astar`, `.../{2d,3d}/navigation_mesh_chunks`.

## 13. Particles: GPU vs CPU, and counts

`GPUParticles2D`/`GPUParticles3D` process on the GPU via `ParticleProcessMaterial`; `CPUParticles2D`/`CPUParticles3D` have near-parity but **lower performance at large counts** `[doc]`, while possibly winning on low-end systems or when **GPU-bottlenecked** `[doc]`. The docs recommend GPU particles unless you have an explicit reason otherwise, and no new features are planned for the CPU variants `[doc]`. For us: GPU by default. The Deck is where the GPU-bottleneck exception could bite — but if particles are the **fill-rate** cost, moving them to CPU does not help, because the pixels are the cost; reduce `amount`, shrink the emitter, or force **vertex shading** in the particle material to cut per-pixel cost `[doc]`.

Levers: `amount`, `amount_ratio` (scale live count without reallocating), `lifetime`, `explosiveness`, `fixed_fps` (default **30** — halving simulation rate is nearly free), `interpolate`, `interp_to_end`, `fract_delta`, `speed_scale`, `preprocess`, `draw_order`, `local_coords`, `sub_emitter`, `trail_enabled`/`trail_lifetime`/`trail_sections`/`trail_section_subdivisions`, `use_fixed_seed`/`seed`. **`visibility_rect` (2D) and `visibility_aabb` (3D) are the culling bounds and are performance-critical**: too small and particles pop out, too large and the system never culls. Transparency is the real cost — overlapping alpha-blended quads cannot use the Z-buffer, must draw back-to-front, and each shades every pixel `[doc]`; many large overlapping particles is the commonest way to lose the Deck's budget `[measure]`. Demos: `third_party/godot-demo-projects/2d/particles`, `.../3d/particles`.

## 14. Texture memory, atlases, VRAM compression

| Compress Mode | On disk | In VRAM | Use for |
| --- | --- | --- | --- |
| **Lossless** (default) | lossless WebP/PNG | **uncompressed** | 2D art, pixel art, UI `[doc]` |
| **Lossy** | lossy WebP | **uncompressed — same VRAM as Lossless** `[doc]` | disk size only (irrelevant to us) |
| **VRAM Compressed** | S3TC / BPTC on desktop | **~4:1, 6:1 for opaque S3TC** `[doc]` | 3D textures — the 3D default `[doc]` |
| **VRAM Uncompressed** | raw pixels | uncompressed | data textures, precision-critical |
| **Basis Universal** | transcoded to a VRAM format | ≈ VRAM Compressed `[doc]` | smaller downloads, lower quality, slow compression `[doc]` — not for us |

**Disk size is nearly free for us** (`PLATFORM_TARGETS.md`) but VRAM is not, so choose modes for **VRAM and bandwidth**, never to shrink the installer. `rendering/textures/vram_compression/import_s3tc_bptc` must be on for desktop VRAM-compressed textures; `import_etc2_astc` is the mobile path and is irrelevant. BPTC means higher quality and HDR at higher cost, S3TC is faster and lower quality with no HDR `[doc]` — decide once, project-wide. **Pixel art must not use VRAM compression** even in 3D, since it damages appearance without meaningful gain `[doc]`. **Detect 3D** auto-switches a texture to VRAM Compressed the first time it is used in 3D `[doc]`, so check it when a 2D texture suddenly looks wrong. Texture reads are expensive in fragment shaders and fewer samplers per shader is a real win `[doc]`. Atlasing (`AtlasTexture`) is a **draw-call** optimisation (§5), not a VRAM one. Watch `RENDER_TEXTURE_MEM_USED` and `RENDER_VIDEO_MEM_USED`; Deck VRAM is shared with system memory, so overcommit shows up as stutter rather than an error `[measure]`.

## 15. 3D culling: occlusion, LOD, visibility ranges, on-screen notifiers

Frustum culling is automatic `[doc]`. Beyond it, in reach-for order:

1. **Mesh LOD** (`mesh_lod.rst`) — automatic on import for glTF/.blend/Collada/FBX via meshoptimizer, transparent to you `[doc]`. **Not** automatic for `.obj`: set **Import As: Scene** and reimport (needs an editor restart) `[doc]`. Works for `MeshInstance3D`, `MultiMeshInstance3D`, `GPUParticles3D`, `CPUParticles3D` `[doc]`. Tune with `GeometryInstance3D.lod_bias` (default `1.0`).
2. **Visibility ranges / HLOD** — `GeometryInstance3D.visibility_range_begin`, `visibility_range_end`, their `_margin` variants and `visibility_range_fade_mode` (`VISIBILITY_RANGE_FADE_DISABLED` / `_SELF` / `_DEPENDENCIES`), for artist-authored LODs and impostors `[doc]`. Demo: `third_party/godot-demo-projects/3d/visibility_ranges`.
3. **Occlusion culling** (`occlusion_culling.rst`) — enable `rendering/occlusion_culling/use_occlusion_culling` (default **off**), then place `OccluderInstance3D` geometry. Godot rasterises occluders to a low-resolution CPU buffer (Embree) and culls occludees whose **whole AABB** is covered, so **big occluders, small occludees** cull best `[doc]`. Forward+ already runs a depth prepass, so the win here is fewer draw calls and vertices rather than fewer shaded pixels — the docs say the *greatest* benefit is on Mobile, and that in scenes with few occlusion opportunities it may not be worth the CPU cost `[doc]`. Settings: `rendering/occlusion_culling/bvh_build_quality`, `occlusion_rays_per_thread` (512), `jitter_projection`; escape hatch `GeometryInstance3D.ignore_occlusion_culling`. Demo: `third_party/godot-demo-projects/3d/occlusion_culling_mesh_lod`.
4. **`VisibleOnScreenNotifier3D` / `VisibleOnScreenEnabler3D`** (and the 2D pair). The notifier emits `screen_entered` / `screen_exited` and answers `is_on_screen()`, with bounds `aabb` (3D) or `rect` (2D); the enabler drives a target's process mode via `enable_node_path` and `enable_mode` (`ENABLE_MODE_INHERIT` / `_ALWAYS` / `_WHEN_PAUSED`). This is how you stop paying for **animation and skinning** off-screen — the docs name skinning and morphs as expensive vertex work and point at exactly these nodes `[doc]`.

Also `[doc]`: **fewer materials, aggressively** — 20,000 objects with 20,000 materials is slow, the same objects with 100 materials "much faster", and `StandardMaterial3D` already shares shaders across instances with identical feature toggles even at different parameters. **Shadows cost fragment work twice** (write and read), so shrink shadow maps and disable shadows on small or distant omni/spot lights. **Bake lighting**: Static bake mode for most omni/spot lights and Dynamic for `DirectionalLight3D` is the balance the docs recommend. **Transparency**: give a mostly-opaque mesh a separate small transparent surface rather than making the whole thing transparent. The per-instance switch is `GeometryInstance3D.cast_shadow` (`SHADOW_CASTING_SETTING_OFF` / `_ON` / `_DOUBLE_SIDED` / `_SHADOWS_ONLY`). Deck-specific: `rendering/scaling_3d/mode` with `rendering/scaling_3d/scale` (FSR, plus `rendering/scaling_3d/fsr_sharpness`) is the largest single fill-rate lever and the one most worth exposing as a user option — demo `third_party/godot-demo-projects/3d/graphics_settings`.

## 16. Physics interpolation

**Off by default**: `physics/common/physics_interpolation`. It smooths rendered transforms between fixed physics ticks and the docs call it *"orders of magnitude faster"* than an extra physics tick — a genuine performance win as well as a smoothness fix `[doc]` (`cpu_optimization.rst`). Quick start `[doc]`: enable the setting; move objects and run game logic in `_physics_process()`, **not** `_process()`, including indirect movement such as moving a parent; call `Node.reset_physics_interpolation()` **after** teleporting or first positioning a node or it visibly streaks; and to sanity-check, temporarily set `physics_ticks_per_second` to 10 and look.

Per node: `Node.physics_interpolation_mode` (`PHYSICS_INTERPOLATION_MODE_INHERIT` / `_ON` / `_OFF`), `Node.is_physics_interpolated()`, `Node.is_physics_interpolated_and_enabled()`; `Engine.get_physics_interpolation_fraction()` gives the fraction through the current tick. Server side: `RenderingServer.canvas_item_reset_physics_interpolation()`, `MultiMesh.physics_interpolation_quality`, `MultiMesh.set_buffer_interpolated()` / `RenderingServer.multimesh_set_buffer_interpolated()`, `MultiMesh.reset_instance_physics_interpolation()`. `physics/3d/physics_interpolation/scene_traversal` exists in 4.7 (default `"DEFAULT"`); I could not verify which version added it or what its other values do. Demo: `third_party/godot-demo-projects/3d/physics_interpolation`. Never premature — but it is a **commitment**: turning it on in a codebase that moves things in `_process` makes things worse.

## 17. Tick rate, `Engine.max_fps`, vsync

| Knob | Setting / default | Notes |
| --- | --- | --- |
| `Engine.physics_ticks_per_second` | `physics/common/physics_ticks_per_second`, 60 | halving roughly halves physics CPU `[doc]`, at the price of input lag and jitter |
| `Engine.max_physics_steps_per_frame` | `physics/common/max_physics_steps_per_frame`, 8 | spiral-of-death guard: caps catch-up ticks after an overrun |
| `Engine.physics_jitter_fix` | 0.5 | how tightly ticks track real time |
| `Engine.time_scale` | 1.0 | slow-mo; does **not** reduce cost |
| `Engine.max_fps` | `application/run/max_fps`, 0 (unlimited) | the Deck battery lever |
| `DisplayServer.window_set_vsync_mode()` | `display/window/vsync/vsync_mode`, 1 | modes below |

The docs are blunt: **stick to 60 Hz physics for anything with real-time player movement**, because a lower tick rate adds input lag and jitter and the right fix for jitter is interpolation, not a higher tick rate `[doc]`. Lowering it is legitimate only for simulation-heavy, low-twitch designs. `DisplayServer.VSyncMode` values are `VSYNC_DISABLED` (tearing, uncapped — use when benchmarking), `VSYNC_ENABLED` (default), `VSYNC_ADAPTIVE` (behaves as disabled below refresh, reducing stutter) and `VSYNC_MAILBOX` (most recent image at vblank, no tearing, higher power draw). Ship `VSYNC_ENABLED` plus a user-settable `Engine.max_fps`; on the Deck a stable capped 30 or 40 usually beats an unstable 60 and costs far less battery `[measure]`. **Always disable V-Sync when measuring**, or every result is quantised to the refresh rate `[doc]`.

## 18. Threading — available to us, and its hazards

`thread_safe_apis.rst` is the authority:

| Area | Thread-safe? |
| --- | --- |
| Most `@GlobalScope` singletons / servers | yes `[doc]` |
| `RenderingServer` | only with `rendering/driver/threads/thread_model` = **Separate** `[doc]` |
| `PhysicsServer2D`/`3D` | only with `physics/2d/run_on_separate_thread` / `physics/3d/run_on_separate_thread` `[doc]` |
| `NavigationServer2D`/`3D` | yes, truly parallel `[doc]` |
| **Active scene tree** | **no** `[doc]` — use `call_deferred` / `set_deferred` |
| Building detached node trees off-tree | yes, from **one** thread `[doc]` |
| Loading/handling resources | yes, from **one** thread; never the same resource from two `[doc]` |
| `AStar2D` / `AStar3D` / `AStarGrid2D` | **no** `[doc]` |
| GDScript `Array`/`Dictionary` | element reads/writes OK; **any resize needs a `Mutex`** `[doc]` |

**Threaded `ResourceLoader`** is the lowest-risk, highest-value threading in the engine: it removes loading hitches with no shared-state hazards.

```gdscript
const LEVEL := "res://levels/level_02.tscn"

func begin_load() -> void:
    ResourceLoader.load_threaded_request(LEVEL)   # (path, type_hint, use_sub_threads, cache_mode)

func _process(_delta: float) -> void:
    var progress: Array = []
    match ResourceLoader.load_threaded_get_status(LEVEL, progress):
        ResourceLoader.THREAD_LOAD_IN_PROGRESS:
            $Bar.value = progress[0] * 100.0                        # progress[0] is 0.0 .. 1.0
        ResourceLoader.THREAD_LOAD_LOADED:
            set_process(false)
            get_tree().change_scene_to_packed(ResourceLoader.load_threaded_get(LEVEL))
        ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE:
            set_process(false)
            push_error("load failed: %s" % LEVEL)
```

Cache modes: `CACHE_MODE_IGNORE`, `CACHE_MODE_REUSE` (default), `CACHE_MODE_REPLACE`, `CACHE_MODE_IGNORE_DEEP`, `CACHE_MODE_REPLACE_DEEP`. Bonus since 4.4: loading meshes on a background thread lets pipeline precompilation happen there too, moving shader stutter off the gameplay frame `[doc]` (§19). Demos: `third_party/godot-demo-projects/loading/load_threaded`, `.../loading/threads`.

**`WorkerThreadPool`** beats a raw `Thread` for short parallel work, because the pool's threads already exist and **creating a `Thread` is slow, especially on Windows** `[doc]`.

```gdscript
var _results: PackedFloat32Array

func recompute_field(cells: PackedVector2Array) -> void:
    _results.resize(cells.size())                    # size fixed up-front, so no Mutex needed
    var group := WorkerThreadPool.add_group_task(_compute_cell, cells.size(), -1, false, "field")
    WorkerThreadPool.wait_for_group_task_completion(group)   # blocks the caller

func _compute_cell(i: int) -> void:
    _results[i] = expensive(i)                       # distinct index per task: safe [doc]
```

API: `add_task(callable, high_priority, description)`, `add_group_task(callable, elements, tasks_needed, high_priority, description)`, `is_task_completed()`, `is_group_task_completed()`, `wait_for_task_completion()`, `wait_for_group_task_completion()`, `get_group_processed_element_count()`, `get_caller_task_id()`, `get_caller_group_id()`. Sizing: `threading/worker_pool/max_threads` (default `-1` = auto) and `threading/worker_pool/low_priority_thread_ratio` (0.3), with `OS.get_processor_count()` reporting what you have. Hazards: **never touch the scene tree from a task**; resize shared containers only under a `Mutex` `[doc]`; and `wait_for_*_completion` blocks the caller, so calling it from `_process` converts parallelism into a stall unless the work genuinely exceeds one core's frame budget.

Raw primitives: `Thread` (`start(callable, priority)` with `PRIORITY_LOW`/`_NORMAL`/`_HIGH`, `wait_to_finish()`, `is_alive()`, `is_started()`, `is_main_thread()`, `set_thread_safety_checks_enabled()`), `Mutex` (`lock()`, `unlock()`, `try_lock()`), `Semaphore` (`wait()`, `post(count)`, `try_wait()`). **Every started `Thread` must be joined with `wait_to_finish()`**, in `_exit_tree()` `[doc]`, and locking is itself expensive — lock rarely and briefly `[doc]`.

**`run_on_separate_thread` physics** (`physics/2d/…` and `physics/3d/…`, both default `false`) moves the physics servers onto their own thread, which is what *makes them thread-safe* `[doc]`; on a Deck this can reclaim frame time by overlapping physics with rendering `[measure]`. Turn it on early and keep it on — flipping it late changes ordering assumptions across the codebase. **`rendering/driver/threads/thread_model` = Separate** is required to instance rendering nodes from threads, but the docs warn it **has several known bugs and may not be usable in all scenarios** `[doc]`, so do not enable it speculatively. Even with threads, avoid direct GPU interaction off the main thread (creating textures, reading back `Image` data): it forces `RenderingServer` synchronisation and stalls `[doc]`.

## 19. Shader/pipeline compilation stutter

Forward+ and Mobile only, not Compatibility `[doc]`. Since **4.4**, ubershaders plus load-time pipeline precompilation largely remove first-playthrough shader hitches `[doc]`. Watch the five monitors:

| Monitor | Trigger | Stutter risk |
| --- | --- | --- |
| `PIPELINE_COMPILATIONS_CANVAS` | first draw of a 2D node | **yes** — 2D has no precompilation `[doc]` |
| `PIPELINE_COMPILATIONS_MESH` | loading a 3D mesh | only mid-gameplay; mitigate by loading on a background thread `[doc]` |
| `PIPELINE_COMPILATIONS_SURFACE` | first frame a 3D object is in the tree | mild, hidden by a loading screen `[doc]` |
| `PIPELINE_COMPILATIONS_DRAW` | ubershader was *not* precompiled | **yes — and should never happen**; report upstream `[doc]` |
| `PIPELINE_COMPILATIONS_SPECIALIZATION` | background optimisation during play | no stutter, but many per frame lowers FPS `[doc]` |

These counters only ever increase `[doc]`, and a jump **outside a loading screen** is a first-play hitch your warm driver cache is hiding from you `[doc]`. Enabling MSAA or instancing a `VoxelGI` at runtime also triggers recompilation `[doc]`.

## 20. Order of operations

**Design for performance up front** — the docs are blunt that late polishing cannot rescue a bad design, and that a good design with no low-level optimisation beats a mediocre design with it `[doc]`. Then **profile, fix the top bottleneck, profile again** `[doc]`, preferring in order: fewer nodes and callbacks → fewer draw calls and materials → less overdraw and transparency → culling and LOD → servers or `MultiMesh` → threading → micro-optimisation. **Re-measure after every change**, because some "optimisations" are slower and some are faster but not worth the readability `[doc]`. Take **every measurement on the Deck**, since relative costs differ across hardware `[doc]`. Engine built-ins run at the same speed regardless of scripting language `[doc]`; GDScript trades speed for iteration, so move only *heavy computation* elsewhere, and reaching for GDScript micro-optimisation before asking whether the work belongs on a thread, in a server or on the GPU is optimising the wrong layer. See `library/guides/gdscript-style-and-typing.md` for the typing costs that are real.

## 21. What I could not verify offline

- **All Steam Deck hardware figures** (15 W envelope, resolution, refresh, shared VRAM) — not in the vendored corpus.
- **Numeric cost of a signal emission vs a direct call**, and of `get_node()` vs a cached reference. No vendored doc quantifies either; both are `[measure]`.
- **Object-pooling speedups.** Nothing in `third_party/` pools anything, and the vendored docs mention pooling only in passing as a C# garbage-collection workaround, explicitly "outside the scope" of their guide `[doc]`.
- **Which 4.x added** the `NAVIGATION_2D_*`/`NAVIGATION_3D_*` monitor split, or `physics/3d/physics_interpolation/scene_traversal` and its non-default values.
- **The integer value** of the "Separate" option for `rendering/driver/threads/thread_model` (the class reference gives the default as `1` but does not enumerate names offline).
- Whether `run_on_separate_thread` is a net win for a given scene — `[measure]`, dependent on how much physics work there is to overlap.
