# Performance: what actually costs frames in Godot 4.7

This file answers "why is this slow, how do I prove it, and what is the fix that is actually worth
the complexity?" for a Godot 4.7.1 project shipping to desktop and web. Read it before proposing any
optimization, and before writing per-frame code in `_process` / `_physics_process`. Every symbol in
backticks was checked against `third_party/godot-class-reference/classes/*.xml` (engine tag
`4.7.1-stable`); claims about magnitude are labelled `[doc]` when the manual states them and
`[measure]` when they are folklore you must verify on your own scene.

## The only rule that always applies

**Measure, change one thing, measure again.** The manual quotes Knuth in
`third_party/godot-docs/tutorials/performance/general_optimization.rst` and then adds the practical
corollary: bottlenecks are hardware-specific, so measure on every target platform (a web export on a
2-core laptop is a *different* machine from your desktop). An optimization applied without a before
number is a guess that also costs you readability.

Three distinct failure shapes, each needing a different tool
(`general_optimization.rst`, "The nature of slowness"):

| Symptom | Likely cause | Where to look first |
| --- | --- | --- |
| Continuously low FPS | per-frame work that scales with object count | profiler frame time, draw calls |
| Intermittent spikes / stalls | allocation, `load()` mid-gameplay, shader/pipeline compilation, navmesh bake | profiler graph spike + `PIPELINE_COMPILATIONS_*` monitors |
| Slow level load | synchronous resource loading, navmesh baking, texture decode | `--verbose`, `ResourceLoader` threaded load |

---

## 1. Measuring

### 1.1 The editor profiler

**Debugger > Profiler**, then **Start** (it is off by default because measuring is itself expensive).
Source: `third_party/godot-docs/tutorials/scripting/debug/the_profiler.rst`.

- **Frame Time** includes rendering. **Physics Time** is `_physics_process` plus built-in nodes set to
  physics update. **Idle Time** is `_process`, timers, cameras on idle.
- The **Measure** dropdown switches milliseconds ↔ Frame % ↔ Physics %.
- **Self** vs **Inclusive** is the setting people forget. Inclusive blames the caller; Self blames the
  actual slow function. Always check Self before optimizing anything.
- The profiler **does not profile C#** scripts, and time spent waiting on servers may not be
  attributed (documented as a known bug).

### 1.2 `Performance` singleton monitors

`Performance.get_monitor(monitor: int) -> float` — real constants in 4.7.1, `Performance.MONITOR_MAX == 59`.
These work in exported builds too, so you can build an in-game debug overlay.

| Constant | Value | Notes from the class XML |
| --- | --- | --- |
| `Performance.TIME_FPS` | 0 | frames rendered in the last second |
| `Performance.TIME_PROCESS` | 1 | seconds to complete one frame |
| `Performance.TIME_PHYSICS_PROCESS` | 2 | seconds to complete one physics frame |
| `Performance.TIME_NAVIGATION_PROCESS` | 3 | seconds for one navigation step |
| `Performance.MEMORY_STATIC` | 4 | **not available in release builds** |
| `Performance.MEMORY_STATIC_MAX` | 5 | |
| `Performance.MEMORY_MESSAGE_BUFFER_MAX` | 6 | peak `call_deferred` queue size |
| `Performance.OBJECT_COUNT` | 7 | all `Object`s including nodes |
| `Performance.OBJECT_RESOURCE_COUNT` | 8 | |
| `Performance.OBJECT_NODE_COUNT` | 9 | your scene-tree budget number |
| `Performance.OBJECT_ORPHAN_NODE_COUNT` | 10 | **debug only, returns 0 in release**; non-zero = leak |
| `Performance.RENDER_TOTAL_OBJECTS_IN_FRAME` | 11 | |
| `Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME` | 12 | excludes culled; depth prepass + shadow passes make it 2–3× the raw vertex count |
| `Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME` | 13 | excludes culled objects |
| `Performance.RENDER_VIDEO_MEM_USED` | 14 | > texture + buffer, includes misc allocations |
| `Performance.RENDER_TEXTURE_MEM_USED` | 15 | |
| `Performance.RENDER_BUFFER_MEM_USED` | 16 | |
| `Performance.PHYSICS_2D_ACTIVE_OBJECTS` | 17 | sleeping bodies are excluded — this is the real cost driver |
| `Performance.PHYSICS_2D_COLLISION_PAIRS` | 18 | grows quadratically with bad layer masks |
| `Performance.PHYSICS_2D_ISLAND_COUNT` | 19 | |
| `Performance.PHYSICS_3D_ACTIVE_OBJECTS` | 20 | |
| `Performance.PHYSICS_3D_COLLISION_PAIRS` | 21 | |
| `Performance.PHYSICS_3D_ISLAND_COUNT` | 22 | |
| `Performance.AUDIO_OUTPUT_LATENCY` | 23 | |
| `Performance.NAVIGATION_ACTIVE_MAPS` … `NAVIGATION_OBSTACLE_COUNT` | 24–33 | combined 2D+3D navigation counters |
| `Performance.PIPELINE_COMPILATIONS_CANVAS` | 34 | non-zero *during gameplay* = shader stutter |
| `Performance.PIPELINE_COMPILATIONS_MESH` | 35 | |
| `Performance.PIPELINE_COMPILATIONS_SURFACE` | 36 | |
| `Performance.PIPELINE_COMPILATIONS_DRAW` | 37 | |
| `Performance.PIPELINE_COMPILATIONS_SPECIALIZATION` | 38 | |
| `Performance.NAVIGATION_2D_ACTIVE_MAPS` … `NAVIGATION_2D_OBSTACLE_COUNT` | 39–48 | 2D-only split |
| `Performance.NAVIGATION_3D_ACTIVE_MAPS` … `NAVIGATION_3D_OBSTACLE_COUNT` | 49–58 | 3D-only split |

I could not verify which 4.x minor introduced the `NAVIGATION_2D_*` / `NAVIGATION_3D_*` split; both
the combined (24–33) and split (39–58) sets exist in 4.7.1. If you target only 4.7 use the split ones.

### 1.3 Custom monitors

`Performance.add_custom_monitor(id: StringName, callable: Callable, arguments: Array = [], type: int = 0)`.
A slash in `id` makes a category. The callable must return a number ≥ 0. Read the value back in the
running game with `Performance.get_custom_monitor("game/enemies")` — this works in **exported release
builds**, which is how you build a shipped debug overlay.
Source: `third_party/godot-docs/tutorials/scripting/debug/custom_performance_monitors.rst`.

```gdscript
extends Node

var _pool_live := 0

func _ready() -> void:
    Performance.add_custom_monitor(&"game/pool_live", _get_pool_live)
    Performance.add_custom_monitor(&"game/draw_calls", _get_draw_calls)

func _get_pool_live() -> int:
    return _pool_live

func _get_draw_calls() -> int:
    return RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME)
```

### 1.4 `RenderingServer.get_rendering_info`

`RenderingServer.get_rendering_info(info: int) -> int`. Constants:
`RENDERING_INFO_TOTAL_OBJECTS_IN_FRAME` (0), `RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME` (1),
`RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME` (2), `RENDERING_INFO_TEXTURE_MEM_USED` (3),
`RENDERING_INFO_BUFFER_MEM_USED` (4), `RENDERING_INFO_VIDEO_MEM_USED` (5), and
`RENDERING_INFO_PIPELINE_COMPILATIONS_*` (6–10).

Caveat the class XML states explicitly: the draw-call / object / primitive counters describe
**the current 3D scene**. Do not use them as a 2D draw-call meter; for 2D, hypothesis-test by
adding and removing sprites (`general_optimization.rst`, "Hypothesis testing").

### 1.5 Manual timing

```gdscript
var t0 := Time.get_ticks_usec()
update_enemies()
var t1 := Time.get_ticks_usec()
print("update_enemies() took %d us" % (t1 - t0))
```

`Time.get_ticks_usec()` and `Time.get_ticks_msec()` both exist in 4.7. Run the code ≥1000 times and
average: timer resolution is limited and the first run pays cache misses (`cpu_optimization.rst`,
"Caches").

### 1.6 Command-line measurement and `--headless`

From `third_party/godot-docs/tutorials/editor/command_line_tutorial.rst`:

| Flag | Use |
| --- | --- |
| `--headless` | `--display-driver headless --audio-driver Dummy`. **No rendering happens**, so it measures script + physics only. Do not use it to benchmark draw calls. |
| `--print-fps` | prints FPS to stdout — the cheapest CI regression signal |
| `--disable-vsync` | required for any FPS comparison; with V-Sync on you measure the monitor |
| `--fixed-fps <fps>` | disables real-time sync; makes runs deterministic and comparable |
| `--quit-after <n>` | quit after N iterations — bounds a headless benchmark |
| `--time-scale <s>` | fast-forward a scripted scenario |
| `--frame-delay <ms>` | simulate CPU load; **not** an FPS limiter |
| `--gpu-profile` | GPU tasks that took the most time in frame rendering |
| `--gpu-index <n>` | pick a GPU (Forward+/Mobile only); list with `--verbose` |
| `-v` / `--verbose` | load-time detective work |

Canonical headless benchmark: `godot --headless --fixed-fps 60 --quit-after 3600 --path . res://benchmarks/spawn_stress.tscn`.
Because rendering is stubbed, a headless number that regresses points at GDScript or physics, never
at the renderer.

---

## 2. Frame budget vs physics budget

At 60 FPS the whole frame is **16.66 ms**. That budget covers your `_process`, the renderer's CPU-side
work, *and* however many physics ticks happen to fall in this frame.

- `Engine.physics_ticks_per_second` (default `60`, project setting `physics/common/physics_ticks_per_second`).
- `Engine.max_physics_steps_per_frame` (default `8`, `physics/common/max_physics_steps_per_frame`).
  When the frame rate drops below the tick rate, the engine runs multiple physics ticks per frame —
  which makes it slower — until this cap kicks in and the simulation slows down instead of spiralling.
  The XML's warning: the game *appears* to slow down once rendering FPS falls below
  `physics_ticks_per_second / max_physics_steps_per_frame`, even with correct `delta` use. If you raise
  the tick rate significantly above 60, raise this too.
- `Engine.max_fps` / `application/run/max_fps` (default `0` = uncapped) and
  `display/window/vsync/vsync_mode` (default `1`).
- `Engine.time_scale`, `Engine.physics_jitter_fix` (default `0.5`).

Halving `physics_ticks_per_second` from 60 to 30 roughly halves physics CPU cost `[doc: cpu_optimization.rst
"can greatly reduce the CPU load"]`, at the price of jitter and **increased input lag**. The manual's
recommendation: keep 60 Hz for anything with real-time player movement, and fix jitter with physics
interpolation (§10) rather than by raising the tick rate.

`Engine.max_fps = 60` on a menu screen, or `OS.low_processor_usage_mode = true` (with
`OS.low_processor_usage_mode_sleep_usec`, default `6900`) for a tool-like app, is the cheapest
battery/thermal win available and costs nothing in gameplay.

---

## 3. `_process` vs `_physics_process` vs timers vs `await`

| Mechanism | Runs | Use for | Cost |
| --- | --- | --- | --- |
| `_process(delta)` | once per rendered frame, variable rate | camera smoothing, UI, visual-only lerps | one virtual call per node per frame |
| `_physics_process(delta)` | `physics_ticks_per_second` times/sec, fixed | anything touching bodies, `move_and_slide`, raycasts, game logic under physics interpolation | same, plus it may run several times in one frame |
| `Timer` node | on `timeout` signal | recurring gameplay events ≥ ~50 ms apart | one node; zero per-frame script cost |
| `SceneTree.create_timer(time_sec, process_always := true, process_in_physics := false, ignore_time_scale := false)` | one-shot | fire-and-forget delays | a `SceneTreeTimer`, no node |
| `await` on a signal | when the signal fires | sequencing, cutscenes, "wait for animation" | a coroutine frame, no polling |

Rules that matter:

1. If physics interpolation is on, **all** motion must happen in `_physics_process`, directly or
   indirectly (`physics_interpolation_quick_start_guide.rst`). Moving a node in `_process` under
   interpolation produces glitches, and `debug/settings/physics_interpolation/enable_warnings`
   (default `true`) will warn you.
2. Turn processing off rather than early-returning: `set_process(false)`, `set_physics_process(false)`,
   `set_process_input(false)`, `set_process_unhandled_input(false)`, or `process_mode = Node.PROCESS_MODE_DISABLED`.
   An empty `_process` that does `if not active: return` still pays the virtual dispatch for every
   node, every frame. At 10k nodes this is measurable `[measure]`.
3. A poll loop that only needs to run 4×/sec should be a `Timer`, not `_process` with an accumulator —
   same result, and the accumulator is code you can get wrong.
4. `Node.process_priority` / `Node.process_physics_priority` control ordering, not cost.

---

## 4. Per-frame allocation

GDScript allocates on: `Array`/`Dictionary` literals, `String` concatenation and formatting, `.new()`,
`instantiate()`, `duplicate()`, and every method returning a new array (`get_nodes_in_group`,
`get_overlapping_bodies`, `intersect_shape`). None of these are free at 60 Hz × N objects.

```gdscript
# BAD: three allocations per frame per node
func _process(_d: float) -> void:
    var nearby := get_tree().get_nodes_in_group("enemies")     # new Array every frame
    label.text = "HP: " + str(hp) + "/" + str(max_hp)          # new Strings every frame

# GOOD: reuse buffers, update text only on change
var _nearby: Array[Node] = []

func _on_hp_changed(new_hp: int) -> void:
    label.text = "HP: %d/%d" % [new_hp, max_hp]
```

Cheap wins, in order:
- Cache `get_tree().get_nodes_in_group(...)` results and refresh them on spawn/despawn signals, or use
  `SceneTree.get_first_node_in_group` / `SceneTree.get_node_count_in_group` when you only need one/count.
- Use `PackedVector2Array`/`PackedFloat32Array`/`PackedInt32Array` for bulk numeric data — they are
  contiguous and cache-friendly (`cpu_optimization.rst`, "Caches"), unlike `Array[Vector2]`.
- Preallocate with `resize()` once instead of `append()` in a loop.
- `preload()` (a constant, resolved when the script loads) rather than `load()` inside gameplay code —
  `load()` mid-frame is a classic spike (`best_practices/logic_preferences.rst`).
- Set node properties **before** `add_child()`; some setters run expensive update code once parented
  (`logic_preferences.rst`, "Adding nodes and changing properties").

Magnitude: on a hot loop over thousands of items, removing allocation is typically the single largest
GDScript win available `[measure]`. On 20 UI nodes it is noise — that is premature.

---

## 5. `get_node` caching

`Node.get_node(path)` walks the tree and parses the `NodePath` each call. `Node.find_child(pattern, recursive := true, owned := true)`
is far worse — it is a recursive pattern match.

```gdscript
# Resolved once, when the node enters the tree.
@onready var _sprite: Sprite2D = $Visual/Sprite2D
@onready var _hitbox: Area2D = %Hitbox          # scene-unique name

func _physics_process(_d: float) -> void:
    _sprite.rotation = velocity.angle()          # no lookup
```

Never call `get_node`/`$`/`find_child` inside `_process` or `_physics_process`. Use `@onready`, or
`get_node_or_null` once in `_ready()` when the node is optional. Scene-unique names (`%Name`) are
resolved the same way and should also be cached via `@onready`.

Magnitude: converting a handful of per-frame `$Path/To/Node` uses to `@onready` is a small constant
win `[measure]`; doing it inside a loop over 1000 entities is a large one. Caching a lookup that runs
once in `_ready()` is premature.

---

## 6. Signals vs direct calls

A signal emission goes through `Object.emit_signal` and dispatches to every connection; a direct
method call on a cached reference does not. A signal is therefore **strictly more expensive** than the
equivalent direct call — but the difference is per-emission, not per-frame, and the decoupling is
usually worth more than the cycles.

Guidance:
- Signals for **events** (died, level_completed, item_picked_up) — these fire tens of times, not
  60×/second×N.
- Direct calls on a cached reference for **per-frame data flow** (a controller driving its own sprite).
- `Object.connect(signal, callable, flags)` with `Object.CONNECT_DEFERRED` (1) moves the callback to
  idle time — useful for thread safety and for avoiding physics-callback reentrancy, but it queues
  through the message buffer (watch `Performance.MEMORY_MESSAGE_BUFFER_MAX`).
- `Object.CONNECT_ONE_SHOT` (4) disconnects after the first emission — cheaper and safer than
  disconnecting by hand.
- `SceneTree.call_group(group, method, ...)` iterates the group each call. For a per-frame broadcast to
  many nodes, iterate a cached array instead.

I could not verify a published signal-vs-direct-call ratio for 4.7. Do not quote one; if it matters,
time it with `Time.get_ticks_usec()` over 100k iterations on your target platform.

---

## 7. Object pooling — full pattern (known gap in this repo)

Nothing under `third_party/` implements pooling: `grep -i pool library/code/scripts.tsv` returns zero
rows across 1422 vendored `.gd` files. The canonical pattern, written out in full:

```gdscript
# res://systems/node_pool.gd
class_name NodePool
extends RefCounted

## Recycles instances of one PackedScene. Pooled nodes must implement
## `pool_reset()` (called on acquire) and must not free themselves.

var _scene: PackedScene
var _parent: Node
var _free: Array[Node] = []
var _live_count := 0

func _init(scene: PackedScene, parent: Node, prewarm: int = 0) -> void:
    _scene = scene
    _parent = parent
    _free.resize(0)
    for i in prewarm:
        var n := _make()
        _free.push_back(n)

func _make() -> Node:
    var n: Node = _scene.instantiate()
    # Configure BEFORE parenting; some setters run expensive update code once in-tree.
    n.set_process(false)
    n.set_physics_process(false)
    return n

func acquire() -> Node:
    var n: Node = _free.pop_back() if not _free.is_empty() else _make()
    _live_count += 1
    if n.get_parent() == null:
        _parent.add_child(n)
    n.set_process(true)
    n.set_physics_process(true)
    if n is CanvasItem:
        (n as CanvasItem).show()
    elif n is Node3D:
        (n as Node3D).show()
    if n.has_method(&"pool_reset"):
        n.call(&"pool_reset")
    # Under physics interpolation, teleporting a recycled node streaks unless reset.
    n.reset_physics_interpolation()
    return n

func release(n: Node) -> void:
    if n == null or not is_instance_valid(n):
        return
    n.set_process(false)
    n.set_physics_process(false)
    if n is CanvasItem:
        (n as CanvasItem).hide()
    elif n is Node3D:
        (n as Node3D).hide()
    # Keep it parented but inert. Detaching with remove_child() is cheaper per-frame
    # (see cpu_optimization.rst "SceneTree") but costs a tree edit on every acquire.
    _live_count -= 1
    _free.push_back(n)

func live_count() -> int:
    return _live_count

func destroy() -> void:
    for n in _free:
        n.queue_free()
    _free.clear()
```

Usage:

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

Rules the pattern encodes:
- Pooled nodes **must not** call `queue_free()` on themselves; they signal and the pool reclaims them.
- Reset *all* mutable state in `pool_reset()` — velocity, timers, modulate, `Area2D.monitoring`,
  animation state. Leaked state is the #1 pooling bug.
- Call `Node.reset_physics_interpolation()` after repositioning, or the recycled node streaks across
  the screen from its previous position for one physics tick.
- Disconnect or use `CONNECT_ONE_SHOT`; a pooled node that accumulates connections leaks.
- If the pool grows without bound you have a `release()` you never call — track `live_count()` as a
  custom monitor.

**Magnitude and when it is premature.** Pooling removes instantiation + `queue_free` churn. It is worth
it for objects created and destroyed *many times per second* — bullets, hit sparks, damage numbers,
voxel chunks. For enemies that spawn once per wave, or anything created fewer than a few times per
second, it is pure complexity: `PackedScene.instantiate()` is fast and `queue_free()` is deferred to
end-of-frame. Do not pool "on principle."

---

## 8. 2D: draw calls and batching

Godot 4 batches similar canvas items into one draw call automatically
(`gpu_optimization.rst`, "2D batching"). A batch **breaks** on a state change: a different texture, a
different material/shader, a different blend mode, or a canvas item interleaved in z-order between two
otherwise-batchable items.

Practical consequences:
- Keep sprites that draw together on the same texture. Ship a texture atlas and reference regions with
  `AtlasTexture` (`atlas`, `region`, `margin`, `filter_clip`), or use the editor's atlas import.
- Do not interleave: A(tex1) B(tex2) A(tex1) B(tex2) is 4 draw calls; A A B B is 2.
- Reuse one `ShaderMaterial` instance across items instead of one per item. Per-instance variation
  goes through shader uniforms / instance data, not through new materials.
- Tuning knobs exist but are rarely the answer: `rendering/2d/batching/item_buffer_size` (default
  `16384`, max canvas item commands per draw call) and `rendering/2d/batching/uniform_set_cache_size`
  (default `4096`).
- `TileMapLayer.rendering_quadrant_size` (default `16`) and `TileMapLayer.physics_quadrant_size`
  (default `16`) control how tiles are grouped for rendering and collision. Larger quadrants = fewer,
  bigger batches and coarser culling.
- Drawing N items yourself in a single node's `_draw()` (via `CanvasItem.draw_texture` etc.) collapses
  N nodes into 1 — this is exactly what
  `third_party/godot-demo-projects/2d/bullet_shower/bullets.gd` does.

Premature when: you have fewer than a few hundred canvas items. Atlas discipline costs pipeline work;
buy it when `RENDER_TOTAL_DRAW_CALLS_IN_FRAME` (or an add/remove hypothesis test) says so.

---

## 9. `MultiMesh`, `MultiMeshInstance2D` / `MultiMeshInstance3D`

`MultiMesh` is one draw primitive that draws up to millions of instances of one mesh
(`third_party/godot-docs/tutorials/performance/using_multimesh.rst`). `MultiMeshInstance2D` extends
`Node2D`; `MultiMeshInstance3D` extends `GeometryInstance3D`.

The **only** drawback the manual names: no per-instance frustum or screen culling. The whole
MultiMesh is drawn or not drawn. Workaround: split the world into several MultiMeshes, or set
`MultiMesh.custom_aabb`.

```gdscript
extends MultiMeshInstance3D

func _ready() -> void:
    multimesh = MultiMesh.new()
    multimesh.transform_format = MultiMesh.TRANSFORM_3D   # set format FIRST
    multimesh.mesh = BoxMesh.new()
    multimesh.instance_count = 10000                      # then resize
    multimesh.visible_instance_count = 1000               # draw only some
    for i in multimesh.visible_instance_count:
        multimesh.set_instance_transform(i, Transform3D(Basis(), Vector3(i * 2.0, 0, 0)))
```

Order matters: `transform_format` before `instance_count`; changing the format after allocation is not
allowed. Other members you will want: `MultiMesh.use_colors` + `set_instance_color`,
`MultiMesh.use_custom_data` + `set_instance_custom_data` (a `Color` of four floats per instance, read
in the shader as `INSTANCE_CUSTOM`), `MultiMesh.buffer` / `set_buffer_interpolated`,
`MultiMesh.physics_interpolation_quality` (`INTERP_QUALITY_FAST` = 0, `INTERP_QUALITY_HIGH` = 1),
`MultiMesh.reset_instance_physics_interpolation(i)` / `reset_instances_physics_interpolation()`.
For 2D, set `transform_format = MultiMesh.TRANSFORM_2D`, use `set_instance_transform_2d`, and set
`MultiMeshInstance2D.texture`. `CanvasItem.draw_multimesh(multimesh, texture)` draws one manually.

**When MultiMesh beats many nodes.** The manual's own thresholds: hundreds of instances → nodes are
fine; **thousands** that need per-frame processing → prefer the servers API (§10); **hundreds of
thousands to millions** → MultiMesh is the only viable approach `[doc: using_multimesh.rst]`.
Identical `MeshInstance3D` nodes sharing mesh + material are already auto-instanced by the **Forward+**
renderer with no setup — but only for opaque or alpha-tested materials, never alpha-blended
(`optimizing_3d_performance.rst`). If you are on Forward+ with opaque materials, try that first.

Setting per-instance transforms one-by-one from GDScript is itself a cost. For large counts write the
whole `PackedFloat32Array` once via `RenderingServer.multimesh_set_buffer(multimesh, buffer)`.

Demos in this repo: `third_party/godot-demo-projects/3d/occlusion_culling_mesh_lod`,
`third_party/godot-demo-projects/3d/visibility_ranges`. Manual: `performance/vertex_animation/animating_thousands_of_fish.rst`
shows driving a MultiMesh entirely from the vertex shader.

---

## 10. The servers API: `RenderingServer`, `PhysicsServer2D` / `PhysicsServer3D`

The scene tree is optional. Servers are the layer underneath it
(`third_party/godot-docs/tutorials/performance/using_servers.rst`). You trade ease of use and
`_ready`/signals for a much smaller per-object cost and access from threads.

Key concepts:
- Everything is an `RID`, allocated and freed **manually** (`RenderingServer.free_rid`,
  `PhysicsServer2D.free_rid`). Leaks print errors on exit.
- Keep a GDScript reference to any `Resource` you hand a server. RIDs do **not** hold a reference;
  if the `Texture2D` or `Mesh` is collected, the RID dies with it.
- Get the space/canvas/scenario from the world: `get_world_2d().space`, `get_world_2d().canvas`,
  `get_world_3d().space`, `get_world_3d().scenario`, `get_world_2d().direct_space_state`.
  `CanvasItem.get_canvas_item()`, `Viewport.get_viewport_rid()` give you node-owned RIDs — but do not
  drive RIDs that already belong to a node; create your own.
- **Never read back from a server in a hot path.** Getter calls stall the (possibly asynchronous)
  server and force it to flush. The manual is blunt about this.

Working sketch, verified against `third_party/godot-demo-projects/2d/bullet_shower/bullets.gd`
(500 bullets, no nodes, one `_draw`):

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
    PhysicsServer2D.shape_set_data(_shape, 8)          # radius, in pixels
    for _i in COUNT:
        var b := Bullet.new()
        b.speed = randf_range(20.0, 80.0)
        b.body = PhysicsServer2D.body_create()
        PhysicsServer2D.body_set_space(b.body, get_world_2d().space)
        PhysicsServer2D.body_add_shape(b.body, _shape)
        PhysicsServer2D.body_set_collision_mask(b.body, 0)   # bullets ignore each other
        _bullets.push_back(b)

func _physics_process(delta: float) -> void:
    var xf := Transform2D()
    for b in _bullets:
        b.position.x -= b.speed * delta
        xf.origin = b.position
        PhysicsServer2D.body_set_state(b.body, PhysicsServer2D.BODY_STATE_TRANSFORM, xf)

func _process(_delta: float) -> void:
    queue_redraw()

func _draw() -> void:                                   # one node draws all 500
    var offset := -BULLET_TEX.get_size() * 0.5
    for b in _bullets:
        draw_texture(BULLET_TEX, b.position + offset)

func _exit_tree() -> void:                              # mandatory cleanup
    for b in _bullets:
        PhysicsServer2D.free_rid(b.body)
    PhysicsServer2D.free_rid(_shape)
    _bullets.clear()
```

Pure-rendering variant: `RenderingServer.canvas_item_create()`,
`canvas_item_set_parent(ci, get_canvas_item())`, `canvas_item_add_texture_rect(ci, rect, texture_rid)`,
`canvas_item_set_transform(ci, xform)`, and — per the manual — `canvas_item_reset_physics_interpolation(ci)`
on the first frame, or the item appears to teleport in. Primitives added to a canvas item cannot be
edited; call `canvas_item_clear(ci)` and re-add. Transforms *can* be changed freely.
3D equivalent: `instance_create()` → `instance_set_scenario(inst, get_world_3d().scenario)` →
`instance_set_base(inst, mesh)` → `instance_set_transform(inst, xform)`.

**Magnitude and when premature.** The manual scopes servers to "tens of thousands of instances
processed every frame". Below ~1000 objects, nodes are simpler and fast enough; server code is
error-prone (manual RID lifetime, no editor visibility, no signals) and is a poor default. Also note
`physics/2d/run_on_separate_thread` and `physics/3d/run_on_separate_thread` (both default `false`) —
server APIs are threadable, but thread-safe rendering/physics must be enabled in project settings
first (`performance/thread_safe_apis.rst`).

---

## 11. Physics cost

What actually costs: **active** bodies and **collision pairs**. Watch `PHYSICS_2D_ACTIVE_OBJECTS` /
`PHYSICS_3D_ACTIVE_OBJECTS` and `PHYSICS_*_COLLISION_PAIRS`.

| Thing | Cost note |
| --- | --- |
| `RigidBody2D`/`3D` | full simulation; sleeps when at rest — sleeping bodies drop out of the active count |
| `CharacterBody2D`/`3D` | you move it; cost is your `move_and_slide` sweep, not solver work |
| `StaticBody2D`/`3D` | cheapest; broadphase only |
| `Area2D`/`Area3D` | `monitoring` (detect entering bodies/areas) and `monitorable` (be detected) are **separate** costs — turn off whichever you do not need |
| Concave/trimesh shapes | far more expensive than primitives; use simplified collision geometry (`cpu_optimization.rst`) |

**Collision layers and masks are a culling tool, not just a filter.** A body whose `collision_mask`
excludes a layer never generates a pair against it. The bullet_shower demo sets
`PhysicsServer2D.body_set_collision_mask(body, 0)` precisely so 500 bullets do not test 124,750 pairs
against each other — that is an O(n²) → O(n) change, the largest single physics win available `[doc:
demo comment "to improve performance"]`. Audit every layer/mask matrix before optimizing anything else
in physics.

Node casts vs direct queries:
- `RayCast2D`/`RayCast3D` and `ShapeCast2D`/`ShapeCast3D` update automatically once per physics tick.
  Set `enabled = false` when unused; call `force_raycast_update()` / `force_shapecast_update()` only
  when you genuinely need a mid-tick result (it costs a full query).
- `ShapeCast*.max_results` (default `32`) caps work — lower it when you only care about the first hit.
- `collide_with_areas` defaults to `false` on both casts and query parameters; leave it off unless
  needed. `collide_with_bodies` defaults to `true`.
- For one-off queries, skip the node: `get_world_2d().direct_space_state.intersect_ray(PhysicsRayQueryParameters2D.create(from, to, mask, exclude))`.
  Also available: `intersect_shape(params, max_results := 32)`, `intersect_point`, `cast_motion`,
  `collide_shape`, `get_rest_info`. 3D mirrors all of these.
- Space-state queries are only valid inside `_physics_process` (or a physics callback).

Other levers: remove distant objects from physics entirely rather than hiding them; reuse a fixed
budget of physics objects per area (`cpu_optimization.rst`). Removing a node from the tree with
`Node.remove_child()` and re-adding later is documented as sometimes much faster than pausing or
hiding.

Demos: `third_party/godot-demo-projects/2d/physics_tests`, `third_party/godot-demo-projects/3d/physics_tests`.

---

## 12. Navigation cost

Source: `third_party/godot-docs/tutorials/navigation/navigation_optimizing_performance.rst`.
Watch `Performance.TIME_NAVIGATION_PROCESS`, `NAVIGATION_*_POLYGON_COUNT`, `NAVIGATION_*_EDGE_COUNT`,
`NAVIGATION_*_EDGE_FREE_COUNT`, `NAVIGATION_*_AGENT_COUNT`.

Path search cost scales with **polygon and edge count**, not world size. A huge world with a coarse
navmesh is cheap; a small world tiled into thousands of tiny polygons (typical of naive TileMap
navigation) is expensive.

The four mistakes, in order of how often they appear:
1. Setting `NavigationAgent*.target_position` to the player's position **every frame** — each set
   queries a new path. Compare distance and only re-target when the player has moved far enough.
2. "Is this reachable?" checks every frame — that is a full path query behind the scenes. Query the
   path once and inspect its last point instead. Doing both costs two full queries per agent per frame.
3. All agents re-pathing on the same frame. Split agents into update groups or randomize timers.
4. Baking navmesh from detailed visual meshes at runtime. Mesh data must be pulled from the GPU, which
   locks the RenderingServer thread and can freeze the game for seconds. Use collision shapes as
   source geometry, raise `NavigationMesh` `cell_size`/`cell_height`, use the `monotone`/`layers`
   partition types, and **always bake on a background thread**.

Avoidance (`NavigationAgent*.avoidance_enabled`, default `false`) runs RVO per agent per tick and is a
separate, additive cost. `max_neighbors` (10), `neighbor_distance` (50.0) and `time_horizon_agents`
(1.0) all scale it. Turn avoidance off for agents that do not need it.

Batched/threaded API: `NavigationServer2D.query_path(parameters, result, callback := Callable())` and
the 3D twin, with `NavigationPathQueryParameters2D/3D` + `NavigationPathQueryResult2D/3D`. Statistics:
`NavigationServer2D.get_process_info(...)` / `NavigationServer3D.get_process_info(...)`.
Avoid `NavigationServer*.map_force_update(map)` in gameplay — full map resync is expensive.

---

## 13. Particles: counts, GPU vs CPU

`GPUParticles2D` / `GPUParticles3D` simulate on the GPU. `CPUParticles2D` / `CPUParticles3D` simulate
on the CPU. Prefer GPU everywhere it works; use CPU when the target has no compute support (older
WebGL/Compatibility paths) or when you need physics interpolation in 2D (see §14).

Cost levers on `GPUParticles2D`/`3D`:

| Property | Default | Effect on cost |
| --- | --- | --- |
| `amount` | `8` | **the only real cost knob.** Higher values increase GPU requirements even if not all particles are visible. Changing it **restarts the system**, so set it once. |
| `amount_ratio` | `1.0` | changes how many are emitted without restarting — but the XML says plainly: **"Reducing `amount_ratio` has no performance benefit,"** because resources are allocated and processed for the full `amount` regardless. Use it for art direction, not for perf; lower `amount` instead. |
| `fixed_fps` | `30` (0 on `CPUParticles2D`) | update rate. The XML notes it does *not* slow the simulation itself, so treat "lower `fixed_fps` = cheaper" as unverified `[measure]`. |
| `interpolate` | `true` | smooths motion when `fixed_fps` is below the refresh rate — keeps a low `fixed_fps` from looking stepped |
| `visibility_rect` (2D) | `Rect2(-100,-100,200,200)` | region that must be on screen for the system to be **active** — wrong values keep offscreen systems simulating, or clip visible ones |
| `visibility_aabb` (3D) | `AABB(-4,-4,-4,8,8,8)` | same for 3D |
| `trail_enabled` / `trail_sections` / `trail_section_subdivisions` | `false` / `8` / `4` | mesh skinning per particle; expensive |
| `sub_emitter` | — | multiplies particle counts; audit before shipping |
| `collision_base_size` (2D) | `1.0` | particle collision is not free |
| `draw_order` | 1 (2D) / 0 (3D) | lifetime/index ordering is cheaper than view-depth sorting |

Shading: particles are usually **fill-rate** bound, not simulation bound — large soft additive quads
overlapping is the classic killer. `gpu_optimization.rst` recommends forcing vertex shading in the
particle material to cut per-pixel cost, and keeping transparent areas as small as possible.

Diagnosis: shrink the game window. If FPS jumps, you are fill-rate limited and the fix is smaller/
fewer transparent pixels, not fewer particles (`gpu_optimization.rst`, "Pixel/fragment shaders and fill rate").

Demos: `third_party/godot-demo-projects/2d/particles`, `third_party/godot-demo-projects/3d/particles`.

---

## 14. Texture memory and atlases

Watch `Performance.RENDER_TEXTURE_MEM_USED` and `RENDER_VIDEO_MEM_USED`.

- VRAM compression is on by default for 3D model textures. It is *worse* than PNG on disk but hugely
  better in bandwidth between memory and GPU — that is the point (`gpu_optimization.rst`).
- Disable VRAM compression for pixel art (2D or 3D): the artifacts are visible and the perf gain is
  negligible at low resolution `[doc]`.
- Most Android devices cannot VRAM-compress textures **with transparency** — opaque only `[doc]`.
- Web: `rendering/renderer/rendering_method.web` defaults to `"gl_compatibility"`. Test texture
  formats on the actual web export; the desktop result tells you nothing.
- Fewer, larger textures beat many small ones for batching (§8). Atlas with `AtlasTexture`
  (`atlas` + `region`); set `filter_clip = true` if you see neighbouring-pixel bleed.
- Reading textures is expensive per fragment; a shader sampling 6 textures costs roughly 6× the
  sampling of one, and filtering (trilinear across mipmaps) adds more `[doc: gpu_optimization.rst]`.
- `PortableCompressedTexture2D` (`create_from_image`, `keep_compressed_buffer`,
  `set_basisu_compressor_params`) exists for runtime-generated textures that must stay compressed.

---

## 15. 3D: culling, LOD, visibility

Frustum culling is automatic. The rest you opt into.

**Occlusion culling.** Off by default: `rendering/occlusion_culling/use_occlusion_culling` = `false`.
Turn it on, add `OccluderInstance3D` nodes (with `occluder`, `bake_mask`, `bake_simplification_distance`).
`GeometryInstance3D.ignore_occlusion_culling` opts an instance out. Tuning:
`rendering/occlusion_culling/occlusion_rays_per_thread` (512), `bvh_build_quality` (2),
`jitter_projection` (true).
Magnitude: large in indoor scenes with many small rooms; near zero in open scenes, where it is a net
loss because the occlusion buffer costs CPU. Forward+ already does a depth prepass, so the biggest
wins are on the **Mobile** renderer, which does not `[doc: occlusion_culling.rst]`.

**Mesh LOD.** Automatic on import via meshoptimizer, works with `MeshInstance3D`,
`MultiMeshInstance3D`, `GPUParticles3D`, `CPUParticles3D`. Bias per instance with
`GeometryInstance3D.lod_bias` (1.0), per viewport with `Viewport.mesh_lod_threshold` (1.0), globally
with `rendering/mesh_lod/lod_change/threshold_pixels` (1.0). No setup cost; leave it on.

**Visibility ranges (HLOD).** Manual, artist-authored: `GeometryInstance3D.visibility_range_begin` /
`visibility_range_end` / `..._margin` / `visibility_range_fade_mode`
(`VISIBILITY_RANGE_FADE_DISABLED`/`_SELF`/`_DEPENDENCIES`). Use for impostors and for hiding distant
particle effects entirely. Demo: `third_party/godot-demo-projects/3d/visibility_ranges`.

**`VisibleOnScreenNotifier2D` / `3D`** — signals `screen_entered` / `screen_exited`, method
`is_on_screen()`, bounds via `rect` (2D, default `Rect2(-10,-10,20,20)`) or `aabb` (3D, default
`AABB(-1,-1,-1,2,2,2)`). These do **not** cull rendering (the renderer already does); they let *you*
stop doing work — pausing AI, animation, or `_process` for offscreen actors.
`VisibleOnScreenEnabler2D`/`3D` automate it: `enable_node_path` (default `".."`) and `enable_mode`
(`ENABLE_MODE_INHERIT` 0 / `ENABLE_MODE_ALWAYS` 1 / `ENABLE_MODE_WHEN_PAUSED` 2). Note the 3.x names
`VisibilityNotifier`/`VisibilityEnabler` do not exist in 4.7.

**Other 3D levers, roughly in value order:** reuse materials (20k objects with 100 materials is far
faster than 20k with 20k materials `[doc]`); minimize transparent surfaces; disable shadows on small
or distant lights (`GeometryInstance3D.cast_shadow = SHADOW_CASTING_SETTING_OFF`); bake lighting and
set omni/spot lights to Static bake mode while keeping `DirectionalLight3D` dynamic; reduce shadow map
size. Resolution levers on `Viewport`: `scaling_3d_scale` (1.0), `scaling_3d_mode`, `fsr_sharpness`
(0.2), `msaa_3d`/`msaa_2d` (0), `use_taa` (false), `screen_space_aa` (0), `use_debanding` (false).

Demo: `third_party/godot-demo-projects/3d/occlusion_culling_mesh_lod`.

---

## 16. Physics interpolation and tick rate

Exists in 4.7 for **both 2D and 3D**. Off by default:
`physics/common/physics_interpolation` = `false`, mirrored at runtime as `SceneTree.physics_interpolation`.

Per-node control: `Node.physics_interpolation_mode` with `Node.PHYSICS_INTERPOLATION_MODE_INHERIT` (0),
`_ON` (1), `_OFF` (2). Note the defaults baked into specific classes: `Viewport` defaults to `_ON` (1);
`Control`, `CPUParticles2D`, `Parallax2D`, `ParallaxLayer`, `BoneAttachment3D`, `VehicleWheel3D`,
`XRCamera3D`, `XRNode3D` default to `_OFF` (2).

Essential API:
- `Node.reset_physics_interpolation()` — call after teleporting/placing a node, or it streaks from its
  old transform. Delivered as `Node.NOTIFICATION_RESET_PHYSICS_INTERPOLATION` (2001).
- `Node3D.get_global_transform_interpolated()` — the *displayed* transform. **3D only**; there is no 2D
  equivalent in 4.7 (`2d_and_3d_physics_interpolation.rst`).
- `Engine.get_physics_interpolation_fraction()` — where in the tick the current frame sits.
- `MultiMesh.physics_interpolation_quality`, `set_buffer_interpolated(buffer_curr, buffer_prev)`,
  `reset_instance_physics_interpolation(i)`.
- Servers: `RenderingServer.canvas_item_reset_physics_interpolation(item)`,
  `canvas_item_transform_physics_interpolation(item, xform)`, and the `canvas_light*` /
  `multimesh_instance*` equivalents.
- `debug/settings/physics_interpolation/enable_warnings` (default `true`) points at nodes updated in
  the wrong place.
- `physics/3d/physics_interpolation/scene_traversal` (default `"DEFAULT"`).

Documented asymmetries you will trip over:
- **2D interpolation is server-side**, so it *does* cover bodies you created with `PhysicsServer2D`.
  **3D interpolation is scene-side**, so it does **not** cover `PhysicsServer3D`-created bodies —
  interpolate those yourself. (`2d_and_3d_physics_interpolation.rst`; the 3D redesign is GH-104269,
  which in 4.5 removed `RenderingServer.instance_set_interpolated` and
  `instance_reset_physics_interpolation` — both are absent from the 4.7.1 class reference.)
- In 2D only `CPUParticles2D` is interpolated; `GPUParticles2D` is not yet. Keep a tick rate of
  20–30 Hz minimum for fluid-looking CPU particles.
- `MultiMesh` is supported in both 2D and 3D.

**Why it is a performance technique, not just a smoothness one:** interpolation is "orders of magnitude
faster" than running a physics tick `[doc: cpu_optimization.rst]`. Turning it on lets you drop
`physics_ticks_per_second` from 60 to 30 (or lower for a non-twitchy game) and keep smooth motion —
roughly halving physics CPU for a small constant interpolation cost. The costs are input lag and the
discipline of putting *all* motion in `_physics_process`. Do not lower the tick rate on a game with
real-time player movement without measuring the feel.

---

## 17. Web (HTML5) specifics

- `rendering/renderer/rendering_method.web` defaults to `"gl_compatibility"`. You are on the
  Compatibility renderer: no depth prepass tuning assumptions from Forward+, and occlusion-culling
  economics differ. Measure in a browser, not in the editor.
- Since 4.3, single-threaded web export exists and avoids the `SharedArrayBuffer` /
  cross-origin-isolation headers that GitHub Pages makes awkward. Single-threaded is documented as
  **less performant** than the threaded export, and `Thread` is unavailable
  (`third_party/godot-docs/tutorials/export/exporting_for_web.rst`). Any threading-based optimization
  (background navmesh baking, `ResourceLoader` threaded load, `physics/*/run_on_separate_thread`) is
  therefore a desktop-only win unless you ship the threaded export with the required headers.
- Shader/pipeline compilation stutter is worse on web. Watch `PIPELINE_COMPILATIONS_*` and warm
  materials during loading screens; see `third_party/godot-docs/tutorials/performance/pipeline_compilations.rst`.
- WebAssembly is slower than native, so GDScript-side costs (§4, §5) matter proportionally more.

---

## 18. Order of attack, and when each step is premature

| # | Step | Typical magnitude | Premature when |
| --- | --- | --- | --- |
| 1 | Fix collision layers/masks | O(n²) → O(n) on pair count | never — do this first |
| 2 | Stop per-frame allocation in hot loops | large on 1000s of items `[measure]` | fewer than a few hundred iterations |
| 3 | `set_process(false)` on idle nodes | scales with node count | fewer than ~1000 nodes |
| 4 | Cache `get_node` with `@onready` | small constant, free to do | it already runs once in `_ready()` |
| 5 | Atlas + material reuse (2D batching) | draw calls ÷ 2–10 `[measure]` | under a few hundred canvas items |
| 6 | Mesh LOD + visibility ranges (3D) | large in open scenes `[doc]` | small/indoor scenes |
| 7 | Occlusion culling (3D) | large indoors, negative outdoors `[doc]` | open scenes; Forward+ with few occluders |
| 8 | Lower `physics_ticks_per_second` + interpolation | ~½ physics CPU `[doc]` | twitch gameplay; input lag budget |
| 9 | Object pooling | removes spawn spikes | spawns fewer than a few per second |
| 10 | `MultiMesh` | thousands→millions of instances `[doc]` | under ~1000 instances, or you need per-instance culling |
| 11 | Servers API | tens of thousands of objects `[doc]` | under ~1000 objects — cost is bugs, not frames |
| 12 | Move work to C#/GDExtension | language-dependent `[doc]` | anything you have not profiled |

---

## 19. Things I could not verify

- Any numeric ratio for **signal emission vs direct call** in 4.7 — the manual states no figure.
  Measure with `Time.get_ticks_usec()` before quoting one.
- The exact 4.x minor that introduced the `Performance.NAVIGATION_2D_*` / `NAVIGATION_3D_*` monitor
  split; both these and the legacy combined constants exist in 4.7.1.
- The exact minor that first shipped **2D** physics interpolation (3D's scene-side redesign is
  GH-104269, listed on the 4.5 migration page). 4.7.1 has both.
- Concrete node-count thresholds where SceneTree housekeeping becomes the bottleneck. The manual says
  only "thousands to tens of thousands, depending on target platform" and tells you to profile on each
  platform. Do not put a number in code review comments.
- Whether `rendering/2d/batching/item_buffer_size` tuning ever pays off in practice; no vendored demo
  changes it from the default.
