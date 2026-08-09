# Godot 4.7 API traps: what a model remembers wrong

A catalogue of the Godot APIs that language models reliably get wrong, because their training
corpus is dominated by Godot 3.x tutorials and early-4.x blog posts. Every symbol in backticks
below was checked against the vendored `4.7.1-stable` class reference in
`/home/user/GODOT-GAME/third_party/godot-class-reference/classes/`; every version claim was
checked against `/home/user/GODOT-GAME/third_party/godot-docs/tutorials/migrating/`. Read it
before writing GDScript, and grep it during review when a snippet "looks like Godot but older".

Engine is **Godot 4.7.1 stable**. Target is **desktop PC on Steam** (Windows, Linux, Steam Deck) —
see `/home/user/GODOT-GAME/docs/PLATFORM_TARGETS.md`. Threads, `user://` as a real directory, and
Forward+ are all available; nothing here needs a web-export caveat.

---

## 0. Fast review checklist — grep for these, they are always wrong

| Grep pattern | Why it is wrong | Fix |
| --- | --- | --- |
| `\.instance()` | Godot 3 name | `PackedScene.instantiate()` |
| `\byield\b` | removed as an operator in 4.0 (kept as a reserved word only) | `await` |
| `^export\b`, `^onready\b`, `^tool\b`, `\bsetget\b` | 3.x keywords | `@export`, `@onready`, `@tool`, `set:`/`get:` |
| `Pool[A-Za-z]*Array` | 3.x | `Packed*Array` |
| `connect\("[^"]+",\s*self` | 3.x 5-arg `connect` | `sig.connect(callable)` |
| `move_and_slide\(.+\)` | 4.x takes **no** arguments | set `velocity`, call `move_and_slide()` |
| `KinematicBody`, `Spatial`, `Sprite\b`, `Position2D`, `YSort`, `VisualServer`, `Physics2DServer`, `Directory`, `File\.new`, `Reference` | classes that do not exist in 4.7 | see §1 |
| `OS\.get_ticks_msec`, `OS\.get_datetime`, `OS\.get_screen_size`, `OS\.window_size` | moved out of `OS` in 4.0 | `Time.*` / `DisplayServer.*` |
| `Tween\.new\(\)`, `interpolate_property` | Tween node removed in 4.0 | `create_tween()` |
| `\.update\(\)` on a CanvasItem | renamed | `queue_redraw()` |
| `\.empty\(\)`, `\.invert\(\)`, `\.remove\(` on Array | renamed | `is_empty()`, `reverse()`, `remove_at()` |
| `Engine\.editor_hint` | property removed | `Engine.is_editor_hint()` |
| `func _ready\(\):` calling parent implicitly | 4.x does not chain lifecycle calls | explicit `super()` |
| a `.gd` added to git without its `.gd.uid` | breaks references (4.4+) | commit both, see §11 |

---

## 1. Godot 3 → 4 class renames and removals

These classes **do not exist** in the 4.7 reference. A generated snippet naming one will not run.
All 3D nodes gained a `3D` suffix (`Area` → `Area3D`, `RayCast` → `RayCast3D`, …); that whole
family is omitted below. Source: `tutorials/migrating/upgrading_to_godot_4.rst`.

| Godot 3.x (does not exist) | Godot 4.7 |
| --- | --- |
| `KinematicBody` / `KinematicBody2D` | `CharacterBody3D` / `CharacterBody2D` |
| `Spatial` | `Node3D` |
| `SpatialMaterial` | `StandardMaterial3D` |
| `Sprite` | `Sprite2D` |
| `AnimatedSprite` | `AnimatedSprite2D` |
| `Position2D` / `Position3D` | `Marker2D` / `Marker3D` |
| `Directory` / `File` | `DirAccess` / `FileAccess` (different API, many static methods) |
| `Reference` | `RefCounted` |
| `VisualServer` | `RenderingServer` |
| `Physics2DServer`, `Physics2DDirectBodyState`, `Physics2DDirectSpaceState`, `Physics2DShapeQueryParameters` | `PhysicsServer2D`, `PhysicsDirectBodyState2D`, `PhysicsDirectSpaceState2D`, `PhysicsShapeQueryParameters2D` |
| `Navigation2DServer`, `NavigationMeshInstance`, `NavigationPolygonInstance` | `NavigationServer2D`, `NavigationRegion3D`, `NavigationRegion2D` |
| `Viewport` as a child node | `SubViewport` (`Viewport` still exists, but is the base/window viewport) |
| `ViewportContainer` | `SubViewportContainer` |
| `ARVRCamera`, `ARVRController`, `ARVRAnchor`, `ARVROrigin` | `XRCamera3D`, `XRController3D`, `XRAnchor3D`, `XROrigin3D` |
| `ARVRServer`, `ARVRInterface`, `ARVRPositionalTracker` | `XRServer`, `XRInterface`, `XRPositionalTracker` |
| `Particles` / `Particles2D` / `ParticlesMaterial` | `GPUParticles3D` / `GPUParticles2D` / `ParticleProcessMaterial` |
| `GIProbe` / `GIProbeData` | `VoxelGI` / `VoxelGIData` |
| `Listener` | `AudioListener3D` |
| `StreamTexture`, `GradientTexture`, `TextureProgress`, `VideoPlayer`, `CubeMesh`, `ShortCut` | `CompressedTexture2D`, `GradientTexture1D`, `TextureProgressBar`, `VideoStreamPlayer`, `BoxMesh`, `Shortcut` |
| `LineShape2D` / `PlaneShape` | `WorldBoundaryShape2D` / `WorldBoundaryShape3D` |
| `RayShape` / `RayShape2D` | `SeparationRayShape3D` / `SeparationRayShape2D` |
| `PanoramaSky` / `ProceduralSky` | `Sky` |
| `VisibilityNotifier` / `VisibilityNotifier2D` / `VisibilityEnabler` | `VisibleOnScreenNotifier3D` / `VisibleOnScreenNotifier2D` / `VisibleOnScreenEnabler3D` |
| `EditorSpatialGizmo(Plugin)` | `EditorNode3DGizmo(Plugin)` |

**Careful:** `Light2D` *does* still exist in 4.7 — as a `Node2D` base class. What changed is that
the concrete 3.x `Light2D` node became `PointLight2D`. Do not "fix" `Light2D` in a class hierarchy.

### Removed with no drop-in replacement

| Removed | Closest 4.7 approach |
| --- | --- |
| `YSort` | any `CanvasItem`'s `y_sort_enabled` property |
| `ToolButton` | `Button` with `flat` enabled |
| `OpenSimplexNoise` | `FastNoiseLite` (different parameters, no 4D noise) |
| `BitmapFont` / `DynamicFont` / `DynamicFontData` | `FontFile` |
| `BakedLightmap` / `BakedLightmapData` | `LightmapGI` / `LightmapGIData` |
| `ClippedCamera` / `InterpolatedCamera` | `Camera3D` (frustum shape moved onto the camera) |
| `Navigation2D` / `Navigation3D` | `NavigationRegion2D`/`3D` + `NavigationServer2D`/`3D` |
| `AnimationTreePlayer` | `AnimationTree` |
| `ImmediateGeometry` | `ImmediateMesh` (`set_normal` → `surface_set_normal`, etc.) |
| `Portal` / `Room` / `RoomManager` / `RoomGroup` / `Occluder` | `OccluderInstance3D` raster occlusion culling |
| `ProximityGroup` | `VisibleOnScreenNotifier3D` |

---

## 2. GDScript syntax: keywords that became annotations

| Godot 3.x | Godot 4.7 | Notes |
| --- | --- | --- |
| `export var hp = 10` | `@export var hp: int = 10` | type comes from the hint, not the annotation |
| `export(int, 0, 100) var x` | `@export_range(0, 100) var x: int` | |
| `export(String, FILE) var p` | `@export_file var p: String` | see §11 — 4.4+ stores a `uid://` here |
| `onready var s = $Sprite` | `@onready var s = $Sprite2D` | |
| `tool` | `@tool` | must be the first line, before `class_name`/`extends` |
| `var x setget set_x, get_x` | `var x: set = set_x, get = get_x` | or an inline `set(value):` / `get:` block |
| `yield(obj, "sig")` | `await obj.sig` | no `GDScriptFunctionState` object exists any more |
| `PoolByteArray` etc. | `PackedByteArray`, `PackedInt32Array`, `PackedInt64Array`, `PackedFloat32Array`, `PackedFloat64Array`, `PackedStringArray`, `PackedVector2Array`, `PackedVector3Array`, `PackedVector4Array`, `PackedColorArray` | note the explicit int/float widths |
| `func _init(a).(a):` | `func _init(a): super(a)` | base-constructor chaining is `super()` |
| implicit parent `_ready()` | explicit `super()` | 4.x does **not** implicitly call the parent lifecycle method |

The complete annotation list in 4.7 (from `@GDScript.xml`, 36 entries) — anything else with an `@` is invented: `@abstract`, `@export`, `@export_category`, `@export_color_no_alpha`, `@export_custom`, `@export_dir`, `@export_enum`, `@export_exp_easing`, `@export_file`, `@export_file_path`, `@export_flags`, `@export_flags_2d_navigation`, `@export_flags_2d_physics`, `@export_flags_2d_render`, `@export_flags_3d_navigation`, `@export_flags_3d_physics`, `@export_flags_3d_render`, `@export_flags_avoidance`, `@export_global_dir`, `@export_global_file`, `@export_group`, `@export_multiline`, `@export_node_path`, `@export_placeholder`, `@export_range`, `@export_storage`, `@export_subgroup`, `@export_tool_button`, `@icon`, `@onready`, `@rpc`, `@static_unload`, `@tool`, `@warning_ignore`, `@warning_ignore_restore`, `@warning_ignore_start`.

`class_name` and `extends` are **keywords, not annotations**. The style guide order is `@tool`/`@icon`/`@static_unload`, then `class_name`, then `extends` (`tutorials/scripting/gdscript/gdscript_styleguide.rst`).

### Setter/getter semantics changed, not just spelling

`setget` in 3.x was skipped for same-class access. In 4.x, `set`/`get` are **always** called, including from inside the class and without `self.`. The one exception: using the variable's own name inside its own setter/getter accesses the backing storage directly (so no infinite recursion), and initializers write directly even under `@export`/`@onready`.

```gdscript
var health: int = 100:
    set(value):
        health = clampi(value, 0, max_health)   # direct write, no recursion
        health_changed.emit(health)
    get:
        return health
```

Typed collections: `Array[int]`, `Dictionary[String, int]`. Nested type args
(`Array[Array[int]]`, `Dictionary[String, Dictionary[String, int]]`) are **disallowed**.

---

## 3. Signals, `Callable`, and the `connect()` signature

The single most common hallucination. Godot 3's `connect(signal, target, method, binds, flags)`
does not exist. In 4.7:

| API | 4.7 signature (verified) |
| --- | --- |
| `Object.connect` | `int connect(signal: StringName, callable: Callable, flags: int = 0)` |
| `Object.disconnect` | `void disconnect(signal: StringName, callable: Callable)` |
| `Object.is_connected` | `bool is_connected(signal: StringName, callable: Callable) const` |
| `Signal.connect` | `int connect(callable: Callable, flags: int = 0)` |
| `Signal.emit` | `void emit() vararg const` |
| `Signal.disconnect` / `is_connected` / `has_connections` / `get_connections` | as named |

```gdscript
# WRONG (Godot 3)
button.connect("pressed", self, "_on_pressed", [extra_arg])

# RIGHT (Godot 4.7) — signal is a first-class Signal object, handler is a Callable
button.pressed.connect(_on_pressed.bind(extra_arg))
button.pressed.connect(_on_pressed, CONNECT_ONE_SHOT)
health_changed.emit(old_value, new_value)
```

- Extra arguments: `Callable.bind()` appends them **after** the signal's own arguments. `Callable.unbind(n)` drops the last `n` signal arguments — use it when the handler takes fewer.
- Connect flags live on `Object`: `CONNECT_DEFERRED`, `CONNECT_PERSIST`, `CONNECT_ONE_SHOT`, `CONNECT_REFERENCE_COUNTED`.
- The string form (`obj.connect("pressed", callable)`) still works, but a wrong name is only caught at runtime. Prefer `obj.pressed.connect(...)`.
- `Callable.call_deferred()` and `Object.call_deferred(method: StringName)` both exist; the `Callable` form is the safer one in new code.

### Signals that moved class

| Wrong owner (common in generated code) | Actual owner in 4.7 |
| --- | --- |
| `AnimationPlayer.animation_finished` | `AnimationMixer.animation_finished` (moved in 4.2) |
| `AnimationPlayer.animation_started`, `caches_cleared`, `animation_list_changed` | `AnimationMixer` (4.2) |
| `CanvasItem`'s `hide` signal | renamed to `hidden` in 4.0 — the `hide()` **method** kept its name |
| `Tween`'s `tween_all_completed` | `Tween.loop_finished` |
| `EditorSettings.changed` | `EditorSettings.settings_changed` |

---

## 4. `await` replaces `yield`

```gdscript
await get_tree().create_timer(1.5).timeout      # SceneTreeTimer.timeout
await animation_player.animation_finished       # AnimationMixer signal
await get_tree().process_frame                  # SceneTree signal
var result = await some_coroutine()             # awaiting another coroutine
```

Traps:
- A function containing `await` becomes a coroutine; **its callers must `await` it too**, or reading its return value errors.
- There is no function-state object. `yield` is still a reserved word purely to make old code fail loudly rather than parse as an identifier.
- `await` on something that is neither a signal nor a coroutine returns the value immediately.
- The awaited value is the signal's single argument, an `Array` if the signal has several, and `null` if it has none.

---

## 5. Physics: `CharacterBody2D` / `CharacterBody3D`

The `move_and_slide()` rewrite is the second most common hallucination.

```gdscript
# WRONG (Godot 3): velocity is passed and returned, and up-vector is an argument
velocity = move_and_slide(velocity, Vector2.UP)

# RIGHT (Godot 4.7): velocity is a property; move_and_slide() takes NO arguments
extends CharacterBody2D

func _physics_process(delta: float) -> void:
    velocity.y += gravity * delta          # acceleration IS scaled by delta
    velocity.x = Input.get_axis("move_left", "move_right") * SPEED
    move_and_slide()                       # do NOT multiply velocity by delta here
```

| Fact | Detail |
| --- | --- |
| `CharacterBody2D.move_and_slide()` | `bool move_and_slide()` — no parameters |
| `CharacterBody2D.velocity` | `Vector2 velocity` property, in px/s; mutated by `move_and_slide()` |
| `CharacterBody3D.velocity` | `Vector3 velocity` property |
| up direction | the `up_direction` property (default `Vector2(0, -1)`), not an argument |
| floor angle | `floor_max_angle` property (radians, default `0.7853982`) |
| slide count | `max_slides` (default `4`), not an argument |
| snapping | `floor_snap_length`, `apply_floor_snap()`; there is no `move_and_slide_with_snap()` |
| queries | `is_on_floor()`, `is_on_wall()`, `is_on_ceiling()` and the `*_only()` variants |
| collisions | `get_slide_collision_count()`, `get_slide_collision(i)` → `KinematicCollision2D` |
| other useful | `get_floor_normal()`, `get_wall_normal()`, `get_real_velocity()`, `get_platform_velocity()`, `get_last_slide_collision()` |
| motion mode | `motion_mode` = `MOTION_MODE_GROUNDED` (0) or `MOTION_MODE_FLOATING` (1) — replaces 3.x top-down hacks |

`move_and_collide()` lives on `PhysicsBody2D`/`PhysicsBody3D`, not on `CharacterBody*`:
`KinematicCollision2D move_and_collide(motion, test_only := false, safe_margin := 0.08, recovery_as_collision := false)`.
It **does** take a per-frame motion vector, so `velocity * delta` is correct there and wrong for
`move_and_slide()`. `KinematicCollision2D` uses `get_travel()` (3.x `get_motion()` on
`PhysicsTestMotionResult2D`), plus `get_normal()`, `get_collider()`, `get_remainder()`, `get_depth()`.

Worked example in this repo:
`/home/user/GODOT-GAME/third_party/godot-demo-projects/2d/platformer/player/player.gd`.

---

## 6. Tweens: the node is gone

There is no `Tween` node to add to a scene and no `Tween.new()` pattern with
`interpolate_property()` / `start()`. In 4.7 `Tween` is a `RefCounted` object created by
`Node.create_tween()` or `SceneTree.create_tween()`, and it is bound to the creating node's
lifetime.

```gdscript
var tw := create_tween()
tw.set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
tw.tween_property(self, "modulate:a", 0.0, 0.4).from_current()
tw.parallel().tween_property(self, "position", target, 0.4).as_relative()
tw.tween_callback(queue_free)
await tw.finished
```

| Available on `Tween` in 4.7 | |
| --- | --- |
| tweeners | `tween_property`, `tween_method`, `tween_callback`, `tween_interval`, `tween_subtween`, `tween_await` |
| chaining | `parallel()`, `chain()`, `set_parallel(bool)` |
| config | `set_loops`, `set_speed_scale`, `set_trans`, `set_ease`, `set_pause_mode`, `set_process_mode`, `set_ignore_time_scale`, `bind_node` |
| control | `play`, `pause`, `stop`, `kill`, `is_running`, `is_valid`, `custom_step`, `has_tweeners` |
| signals | `finished`, `loop_finished`, `step_finished` |
| `PropertyTweener` | `from`, `from_current`, `as_relative`, `set_delay`, `set_trans`, `set_ease`, `set_custom_interpolator` |

`SceneTreeTween` was the transitional 3.5/4.0-beta name and **does not exist** in 4.7 — the class
is just `Tween`. `Tween.tween_subtween` (`SubtweenTweener`) and `Tween.tween_await`
(`AwaitTweener`) are present in the 4.7 reference; the vendored manual does not date their
introduction, so do not claim they exist in 4.0.

---

## 7. Resource loading

| Form | When |
| --- | --- |
| `preload("res://x.tscn")` | compile-time constant path only; resolved when the script loads |
| `load("res://x.tscn")` | runtime path; blocks the calling thread |
| `ResourceLoader.load(path, type_hint := "", cache_mode := 1)` | same, with cache control |
| `ResourceLoader.load_threaded_request(path, type_hint := "", use_sub_threads := false, cache_mode := 1)` | background load — **available to us; desktop target, threads are real** |
| `ResourceLoader.load_threaded_get_status(path, progress := [])` | `progress` is an out-param `Array` that receives one float |
| `ResourceLoader.load_threaded_get(path)` | returns the resource; blocks if it is not ready yet |
| `ResourceLoader.exists(path, type_hint := "")` | check without loading |

`ThreadLoadStatus`: `THREAD_LOAD_INVALID_RESOURCE` (0), `THREAD_LOAD_IN_PROGRESS` (1),
`THREAD_LOAD_FAILED` (2), `THREAD_LOAD_LOADED` (3). Note that `THREAD_LOAD_LOADED` is **3, not 0** —
`if status == 0` is a bug that reads as success.

`CacheMode`: `CACHE_MODE_IGNORE` (0), `CACHE_MODE_REUSE` (1, default), `CACHE_MODE_REPLACE` (2),
`CACHE_MODE_IGNORE_DEEP` (3), `CACHE_MODE_REPLACE_DEEP` (4).

Worked example:
`/home/user/GODOT-GAME/third_party/godot-demo-projects/loading/load_threaded/load_threaded.gd`.

Saving: `ResourceSaver.save(resource: Resource, path: String = "", flags: int = 0)` — **arguments
were swapped in 4.0**; 3.x was `save(path, resource)`. Same for `ResourceFormatSaver._save()`.

`.tres` is the text resource format, `.res` the binary one; `.tscn` is a text scene, `.scn` binary.
`PackedScene.instantiate(edit_state := 0)` replaced `instance()`; `GenEditState` is
`GEN_EDIT_STATE_DISABLED`/`_INSTANCE`/`_MAIN`/`_MAIN_INHERITED`. Scene switching is
`SceneTree.change_scene_to_file(path)` (3.x `change_scene()`) or `change_scene_to_packed(scene)`.

Shaders: the 3.x `.shader` extension is not supported; use `.gdshader`. `hint_albedo` and
`hint_color` both became `source_color`.

---

## 8. Random and time

- `randomize()` is called automatically at project load in 4.x. For deterministic runs you must set a seed yourself with `seed(base)` — or, better, use your own `RandomNumberGenerator`.
- Globals available: `randi()`, `randf()`, `randi_range(from, to)`, `randf_range(from, to)`, `randfn(mean, deviation)`, `randomize()`, `seed(base)`, `rand_from_seed(seed)`.
- `RandomNumberGenerator` has `seed` and `state` **properties** (not `set_seed()`), plus `randi`, `randf`, `randi_range`, `randf_range`, `randfn(mean := 0.0, deviation := 1.0)`, `rand_weighted(weights: PackedFloat32Array)`, `randomize()`.
- All time/date methods left `OS` for the `Time` singleton in 4.0: `Time.get_ticks_msec()`, `Time.get_ticks_usec()`, `Time.get_unix_time_from_system()`, `Time.get_datetime_dict_from_system(utc := false)`, `Time.get_datetime_string_from_system(...)`. `OS.get_ticks_msec()` and `OS.get_datetime()` do not exist.
- All screen/window methods left `OS` for `DisplayServer`, renamed to `<object>_<get/set>_<property>`: `DisplayServer.screen_get_size()`, `DisplayServer.window_get_size()`, `DisplayServer.window_set_mode()`, `DisplayServer.window_set_vsync_mode()`, `DisplayServer.screen_get_refresh_rate()`.
- Frame/engine state is on `Engine`: `Engine.max_fps` (3.x `target_fps`), `Engine.time_scale`, `Engine.physics_ticks_per_second`, `Engine.get_frames_per_second()`, `Engine.get_process_frames()`, `Engine.is_editor_hint()` (the 3.x `editor_hint` property was removed).

---

## 9. Other 3 → 4 renames a model still emits

Methods (`upgrading_to_godot_4.rst`, "manual rename" list):

| 3.x | 4.7 |
| --- | --- |
| `CanvasItem.update()` | `CanvasItem.queue_redraw()` |
| `CanvasItem.raise()` | `CanvasItem.move_to_front()` |
| `Array.empty()` / `invert()` / `remove(i)` | `is_empty()` / `reverse()` / `remove_at(i)` |
| `Control.get_stylebox()` / `set_tooltip()` | `get_theme_stylebox()` / `set_tooltip_text()` |
| `SceneTree.change_scene()` | `change_scene_to_file()` |
| `GridMap`/`TileMap` `map_to_world()` / `world_to_map()` | `map_to_local()` / `local_to_map()` |
| `AnimationPlayer.add_animation()` | `add_animation_library()` (uses `AnimationLibrary`) |
| `AnimationTree.set_process_mode()` | `set_process_callback()` → now `AnimationMixer.callback_mode_process` |
| `Image.get_rect()` | `Image.get_region()` |
| `Transform2D.xform(v)` / `xform_inv(v)` | `mat * v` / `v * mat` |
| `AStar2D/AStar3D.get_points()` | `get_point_ids()` — the migration page calls it `get_points_id()`, but the 4.7 class reference has `get_point_ids`; trust the reference |
| `FileDialog.get_mode()` / `set_mode()` | `get_file_mode()` / `set_file_mode()` |

Properties:

| 3.x | 4.7 |
| --- | --- |
| `Node.filename` | `Node.scene_file_path` |
| `Control.margin_*` | `Control.offset_*` |
| `Camera3D.znear` / `zfar` | `near` / `far` |
| `BaseButton.pressed` | `BaseButton.button_pressed` (signals are `button_up` / `button_down`) |
| `BaseButton.group` | `button_group` |
| `Camera2D.rotating` | `ignore_rotation` (**inverted meaning**) |
| `Camera2D.zoom` | same name, **inverted scale** — higher is now more zoomed in |
| `PathFollow2D/3D.offset` | `progress` (setter `set_progress()`) |
| `RectangleShape2D.extents` | `size` |
| `InputEventWithModifiers.shift`/`control`/`alt`/`meta`/`command` | `shift_pressed`/`ctrl_pressed`/`alt_pressed`/`meta_pressed`/`command_pressed` |
| `InputEventMouseButton.doubleclick` | `double_click` |
| `Label.percent_visible`, `AudioServer.device`, `Window.window_title` | `visible_ratio`, `output_device`, `title` |
| CSG / `VoxelGI` `extents` | `size`, and the value is **no longer halved** |
| `Color.palegreen` | `Color.PALE_GREEN` (uppercase, underscored) |

Behaviour changes that are not renames:
- `Array.slice(begin, end)` — `end` is now **exclusive**. `[1,2,3].slice(0,1)` returns `[1]`.
- `String.right(n)` now returns the last `n` characters, not the tail from index `n`. Use `substr()`
  for the old meaning.
- `SceneTree.call_group()` / `set_group()` / `notify_group()` are **immediate** in 4.x. For the 3.x deferred behaviour use `call_group_flags(SceneTree.GROUP_CALL_DEFERRED, ...)`.
- `AABB.has_no_surface()` → `has_surface()` (inverted); `AABB`/`Rect2` `has_no_area()` → `has_area()` (inverted).
- `rotation` is exposed to the inspector and shown in degrees; `rotation_degrees` is no longer the editor-facing property. This silently breaks 3.x animation tracks.
- `String` and `StringName` are distinct: `is_same("x", &"x")` is `false` even though `"x" == &"x"` is `true`. Use `&"name"` for `StringName` parameters and `^"path"` for `NodePath`.
- Threads: `Thread.start(callable: Callable, priority := 1)` takes a bound `Callable`, not `(object, "method", userdata)`. `Thread.is_active()` is gone; use `Thread.is_alive()`.
- `MainLoop.NOTIFICATION_WM_QUIT_REQUEST` → `Node.NOTIFICATION_WM_CLOSE_REQUEST`. The `MainLoop` notification constants are mirrored on `Node`, so drop the `MainLoop.` prefix.

---

## 10. Changes *within* 4.x — which minor version broke what

Everything here comes from `tutorials/migrating/upgrading_to_godot_4.{1..7}.rst`. A model trained
mostly on 4.0/4.1 material will write the left column.

| Version | Change | Impact |
| --- | --- | --- |
| **4.1** | `NavigationAgent2D/3D.set_velocity()` → `velocity` property; `agent_height_offset` → `path_height_offset` (3D only); `ignore_y` and `estimate_radius` removed | GDScript breaks |
| 4.1 | `NavigationAgent2D/3D.get_rid()` renamed to `get_agent_rid()` — **but 4.7 lists `get_rid()` again** and has no `get_agent_rid`; write `get_rid()` | reverted somewhere between 4.1 and 4.7; exact version unverified |
| 4.1 | `NavigationServer2D/3D.agent_set_callback()` → `agent_set_avoidance_callback()`; `agent_set_target_velocity()` removed | GDScript breaks |
| 4.1 | `SubViewportContainer.mouse_filter` must be `MOUSE_FILTER_STOP` or `MOUSE_FILTER_PASS` for input to reach the `SubViewport` | silent input loss |
| 4.1 | A `Viewport` with physics picking now marks input events handled automatically | silent input loss |
| 4.1 | GDExtension binary compatibility broken (entry symbol takes `GDExtensionInterfaceGetProcAddress`) | addons must be rebuilt |
| **4.2** | Animation API consolidated onto `AnimationMixer`: `animation_finished`, `animation_started`, `add_animation_library`, `advance`, `audio_max_polyphony`, `clear_caches` moved off `AnimationPlayer` | source moves, mostly compatible |
| 4.2 | `AnimationPlayer.playback_process_mode` → `AnimationMixer.callback_mode_process`; `method_call_mode` → `callback_mode_method`; `playback_active` → `active` | old names deprecated |
| 4.2 | `Node.NOTIFICATION_NODE_RECACHE_REQUESTED` removed | breaks |
| 4.2 | `TileMap.cell_quadrant_size` → `rendering_quadrant_size` | breaks |
| 4.2 | Mesh storage format changed; opening an older project prompts a one-way upgrade | version-control hazard |
| **4.3** | `TileMap` layers split into individual `TileMapLayer` nodes; `TileMap` is now **deprecated** | new code must use `TileMapLayer` |
| 4.3 | Reverse-Z depth buffer introduced | custom depth shaders break |
| 4.3 | `Control.auto_translate` deprecated in favour of `Node.auto_translate_mode` (inherits from parent by default) | strings can silently stop translating |
| 4.3 | Default font outline colour changed white → black | visual |
| 4.3 | `AnimationMixer` capture mode reworked; `AnimationNode._process` deprecated | blending differs |
| 4.3 | Binary serialisation and `PackedByteArray` base64 storage changed | older Godot may not open new files |
| **4.4** | **`.gd.uid` sidecar files introduced** — see §11 | version-control rule |
| 4.4 | `@export_file` now stores `uid://` instead of `res://` when set from the Inspector | breaks code expecting `res://` |
| 4.4 | `FileAccess.store_*` all changed return type `void` → `bool` | GDScript unaffected; check the result |
| 4.4 | `OS.read_string_from_stdin` gained a required `buffer_size` (3.x/4.3 default was `1024`) | breaks |
| 4.4 | `Curve` now enforces `min_value`/`max_value`; points outside `[0, 1]` need the range widened | silent clamping |
| 4.4 | CSG switched to the Manifold library; non-manifold meshes unsupported | geometry breaks |
| 4.4 | `GraphEdit.frame_rect_changed` signal parameter `Vector2` → `Rect2` | breaks |
| **4.5** | `@export_file_path` added to opt back out of the `uid://` behaviour | |
| 4.5 | `Node.get_rpc_config()` renamed to `get_node_rpc_config()` | breaks |
| 4.5 | `JSONRPC.set_scope()` replaced by `set_method()` | breaks |
| 4.5 | `Resource.duplicate(true)` no longer deep-duplicates **external** resources; use `duplicate_deep(DEEP_DUPLICATE_ALL)` for the 4.4 behaviour | silent behaviour change |
| 4.5 | `RenderingServer.instance_set_interpolated` / `instance_reset_physics_interpolation` removed | breaks |
| 4.5 | `TileMapLayer` physics chunking on by default; set `physics_quadrant_size = 1` to restore exact `get_coords_for_body_rid()` | silent behaviour change |
| 4.5 | Navigation region updates are async/threaded by default (`navigation/world/region_use_async_iterations`) | timing change |
| **4.6** | `FileAccess.get_as_text()` lost its `skip_cr` parameter | breaks |
| 4.6 | `AnimationPlayer.current_animation` / `assigned_animation` / `autoplay` changed `String` → `StringName` | GDScript fine, C# breaks |
| 4.6 | `.tscn` format: `load_steps` no longer written; unique node IDs now saved | large expected diffs on first save |
| 4.6 | Default 3D physics engine for **new** projects is Jolt | behaviour differs from Godot Physics |
| 4.6 | Default Windows rendering driver for **new** projects is D3D12 | `rendering/rendering_device/driver.windows` |
| 4.6 | Glow defaults changed (blend mode Soft Light → Screen, `glow_intensity` 0.8 → 0.3, level weights changed); volumetric fog now brighter | retune `Environment` |
| 4.6 | `MeshInstance3D.skeleton` default `NodePath("..")` → `NodePath("")` | re-link skeletons |
| 4.6 | `EditorFileDialog` members moved up to `FileDialog` | editor plugins |
| **4.7** | Mouse/keyboard device IDs are `InputEvent.DEVICE_ID_MOUSE` / `DEVICE_ID_KEYBOARD`, no longer `0` — a joypad may legitimately be device `0` | **matters for Steam Deck**: `event.device == 0` is now a bug |
| 4.7 | `CanvasItem` no longer adds an antialiasing feather to lines; lines render thinner | increase widths |
| 4.7 | `AudioStreamPlayer2D.area_mask` / `AudioStreamPlayer3D.area_mask` default `1` → `0`; `Area2D`/`Area3D` `audio_bus_override` stops working until you set it back to layer 1 (the migration page says "AudioStreamPlayer", but only the 2D/3D classes carry the property) | silent audio bug |
| 4.7 | GDScript: setting an element of a packed array no longer calls the whole property's setter | silent behaviour change |
| 4.7 | GDScript: an override of a method with a typed return now inherits that return type and needs an explicit `return` | compile error |
| 4.7 | `AnimationNodeBlendSpace1D/2D` `sync` bool replaced by a `sync_mode` enum | transitions change |
| 4.7 | `RichTextLabel` `ImageUpdateMask.UPDATE_WIDTH_IN_PERCENT` → `UPDATE_WIDTH_UNIT`; `add_image`/`update_image` width/height are floats with `RichTextLabel.ImageUnit` | breaks |
| 4.7 | `AudioEffectSpectrumAnalyzer.tap_back_pos` removed | breaks |
| 4.7 | `Object.is_class()` parameter `String` → `StringName` | GDScript fine |
| 4.7 | New projects default to `canvas_items` stretch mode and `expand` aspect | different from every older tutorial |
| 4.7 | Accessibility moved to the `AccessibilityServer` singleton; the `DisplayServer.accessibility_*` methods are deprecated | **relevant to us — Steam Deck** |

---

## 11. `.gd.uid` sidecars (4.4+)

Since 4.4, saving a `.gd` script writes a sibling `foo.gd.uid` containing a single line such as
`uid://ddbwt6ntihs35`. Scenes and resources reference scripts and assets by that UID
(`[ext_resource type="Script" uid="uid://…" path="res://…"]`) rather than only by path, so a file
can be moved or renamed without breaking references. There are 1406 of these in the vendored demo
projects — e.g. `/home/user/GODOT-GAME/third_party/godot-demo-projects/2d/platformer/player/player.gd.uid`.

Rules for agents:

1. **Never hand-edit a `.gd.uid`.** The value is opaque; a typo silently detaches every reference.
2. **Never delete one** to "clean up". The editor will mint a *new* UID and every `.tscn`/`.tres`
   that referenced the old one now points at nothing.
3. **Always commit the `.gd.uid` alongside its `.gd`.** A `.gd` committed without its sidecar means
   the next person to open the project gets a freshly generated UID and a diff on every scene that
   referenced it. Never add `*.uid` to `.gitignore`.
4. When you create a new script from an agent (writing the file directly rather than through the
   editor), **no sidecar exists yet** — the editor generates it on first import. Note this in the
   PR rather than fabricating a UID.
5. Do not generate UIDs by hand. If you need one programmatically, that is
   `ResourceUID.create_id()` / `ResourceUID.id_to_text(id)`; resolution is
   `ResourceUID.uid_to_path(uid)`, `ResourceUID.path_to_uid(path)`, `ResourceUID.ensure_path(path_or_uid)`.
   `ResourceLoader.get_resource_uid(path)` returns `-1` (`ResourceUID.INVALID_ID`) when none exists.
6. `@export_file` stores `uid://` since 4.4. If a script needs a literal `res://` path, use
   `@export_file_path` (added in 4.5).

Honesty note on sourcing: the vendored manual documents `uid://` in
`engine_details/file_formats/tscn.rst` ("used by the engine to track files that are moved around,
even while the editor is closed … Godot does not use external files to keep track of IDs") and the
`@export_file` → `uid://` change in `upgrading_to_godot_4.4.rst`. It has **no dedicated `.gd.uid`
page**, and the version-control page (`tutorials/best_practices/version_control_systems.rst`)
predates the sidecar — it lists only `.godot/`, `.import/` and `*.translation` as ignorable.
**I could not verify from the vendored docs either the exact minor version that introduced the
script sidecar or a sentence stating the commit rule**; the "4.4+" attribution comes from the
`@export_file` UID change landing in 4.4, and rules 1-4 follow from how UIDs resolve, not from a
quotable line.

---

## 12. Deprecated in 4.7 — still callable, do not write new code against them

| Deprecated | Use instead |
| --- | --- |
| `TileMap` (whole node) | multiple `TileMapLayer` nodes |
| `ParallaxBackground` / `ParallaxLayer` | `Parallax2D` |
| `AudioEffectLimiter` | `AudioEffectHardLimiter` |
| `AnimatedTexture` | (broken in current versions; may be removed) |
| `PackedDataContainer` / `PackedDataContainerRef` | `var_to_bytes()` / `FileAccess.store_var()` |
| `Image.create()` | `Image.create_empty()` |
| `String.is_valid_identifier()` / `StringName.is_valid_identifier()` | `is_valid_ascii_identifier()` |
| `@GDScript.Color8()`, `convert()`, `type_exists()` | `Color.from_rgba8()`, `type_convert()`, `ClassDB.class_exists()` |
| `@GDScript.inst_to_dict()` / `dict_to_inst()` | `JSON.from_native()` / `JSON.to_native()` |
| `Control.auto_translate` / `Window.auto_translate` | `Node.auto_translate_mode` |
| `Viewport.push_unhandled_input()` | `Viewport.push_input()` |
| `Window.move_to_foreground()` | `Window.grab_focus()` |
| `RichTextLabel.is_ready()` | `RichTextLabel.is_finished()` |
| `SplitContainer.split_offset` / `get_drag_area_control()` | `split_offsets` / `get_drag_area_controls()` |
| `TextEdit.get_selection_line()` / `get_selection_column()` | `get_selection_origin_line()` / `get_selection_origin_column()` |
| `SpriteFrames.get_animation_loop()` / `set_animation_loop()` | `get_animation_loop_mode()` / `set_animation_loop_mode()` |
| `PopupMenu.add_submenu_item()` / `set_item_submenu()` | `add_submenu_node_item()` / `set_item_submenu_node()` |
| `TreeItem.set_custom_draw()` | `set_custom_draw_callback()` |
| `NavigationRegion2D/3D.get_region_rid()` | `get_rid()` |
| `NavigationServer2D/3D.map_force_update()` | nothing — incompatible with async region updates |
| `MultiMesh.transform_array` / `color_array` / `custom_data_array` | `set_instance_transform()` / `set_instance_color()` / `set_instance_custom_data()` — the array properties are very slow |
| `GeometryInstance3D.gi_lightmap_scale` | `gi_lightmap_texel_scale` |
| `RenderingDevice.barrier()` / `full_barrier()` / `draw_list_begin_split()` | handled automatically |
| `TextServer.format_number()` / `parse_number()` / `percent_sign()` | `TranslationServer.format_number()` / `parse_number()` / `get_percent_sign()` |
| `DisplayServer.accessibility_*` (all of them) | `AccessibilityServer` |
| `EditorPlugin.add_control_to_dock()` / `add_control_to_bottom_panel()` | `EditorPlugin.add_dock()` with `EditorDock` |
| `EditorPlugin.get_editor_interface()` / `EditorScript.get_editor_interface()` | `EditorInterface` is a global singleton |

---

## 13. Things this file does not settle

- The exact 4.x minor version that introduced `Tween.tween_subtween` / `SubtweenTweener`,
  `Tween.tween_await` / `AwaitTweener`, `SplitContainer.split_offsets`, `@abstract`,
  `@export_tool_button` and `AccessibilityServer`. They exist in the 4.7.1 reference; the vendored
  migration pages only date `@export_file_path` (4.5) and the `AccessibilityServer` move (4.7).
- Whether a given deprecated symbol will be removed in 4.8. Nothing on disk says.
- C# specifics beyond what the migration tables state. This project's language choice is not
  settled here, and the class reference is the GDScript-facing one.
