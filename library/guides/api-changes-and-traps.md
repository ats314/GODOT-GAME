# Godot 4.7 API traps: what a model remembers wrong

This file catalogues the Godot APIs that a language model most reliably gets wrong, because its
training corpus is dominated by Godot 3.x tutorials and early-4.x blog posts. Read it before
writing or reviewing any GDScript in this repo; every symbol in backticks below was checked
against `third_party/godot-class-reference/classes/*.xml` (engine tag `4.7.1-stable`), and
"absent" means the XML has no such entry, so the call will fail at parse or run time.

## How to check a claim yourself

```bash
ls third_party/godot-class-reference/classes/CharacterBody2D.xml  # does the class exist?
grep -P '^CharacterBody2D\t' library/api/symbols.tsv              # every member, with signature
grep -i 'move_and_collide' library/api/symbols.tsv                # which class owns this method?
grep -rn 'move_and_slide' third_party/godot-docs/tutorials/       # prose and rationale
```

Version-specific breakage lives in `third_party/godot-docs/tutorials/migrating/`:
`upgrading_to_godot_4.rst` (3.x → 4.0) and `upgrading_to_godot_4.{1,2,3,4,5,6,7}.rst`.
Those pages are the authority for "which minor broke this".

---

## 1. Class renames: Godot 3 names that do not exist in 4.7

Every "Old" name below returns **no file** in the class reference. The general 3D rule is a `3D`
suffix (`Area` → `Area3D`, `RayCast` → `RayCast3D`, `CollisionShape` → `CollisionShape3D`,
`Camera` → `Camera3D`, `RigidBody` → `RigidBody3D`, `StaticBody` → `StaticBody3D`); this table
lists the renames that are *not* just a suffix. Source: `upgrading_to_godot_4.rst`.

| Godot 3 (absent in 4.7) | Godot 4.7 | Spot it by |
| --- | --- | --- |
| `Spatial` | `Node3D` | `extends Spatial` at the top of a 3D script |
| `KinematicBody` / `KinematicBody2D` | `CharacterBody3D` / `CharacterBody2D` | any `move_and_slide(velocity, ...)` call |
| `Reference` | `RefCounted` | `extends Reference` on a plain data class |
| `Directory` / `File` | `DirAccess` / `FileAccess` | `Directory.new()`, `File.new()`, `.open(path, File.READ)` |
| `YSort` | none — use `CanvasItem.y_sort_enabled` on `Node2D` | a `YSort` node in a `.tscn` |
| `ARVRServer` / `ARVRCamera` / `ARVRController` / `ARVROrigin` / `ARVRAnchor` / `ARVRInterface` | `XRServer` / `XRCamera3D` / `XRController3D` / `XROrigin3D` / `XRAnchor3D` / `XRInterface` | the `ARVR` prefix, full stop |
| `Sprite` / `AnimatedSprite` | `Sprite2D` / `AnimatedSprite2D` | missing `2D` on a 2D node |
| `Position2D` / `Position3D` | `Marker2D` / `Marker3D` | `Position2D.new()` |
| `Viewport` (child of a container) / `ViewportContainer` | `SubViewport` / `SubViewportContainer` | `Viewport` used as a *node you add* rather than the root |
| `VisualServer` | `RenderingServer` | `VisualServer.` anywhere |
| `Physics2DServer` / `Physics2DDirectSpaceState` / `Physics2DShapeQueryParameters` | `PhysicsServer2D` / `PhysicsDirectSpaceState2D` / `PhysicsShapeQueryParameters2D` | number before the word, not after |
| `Navigation2DServer` | `NavigationServer2D` | same pattern |
| `NavigationMeshInstance` / `NavigationPolygonInstance` | `NavigationRegion3D` / `NavigationRegion2D` | `Instance` suffix |
| `SpatialMaterial` | `StandardMaterial3D` | `SpatialMaterial.new()` |
| `Particles` / `Particles2D` / `ParticlesMaterial` | `GPUParticles3D` / `GPUParticles2D` / `ParticleProcessMaterial` | no `GPU`/`CPU` prefix |
| `PlaneShape` / `LineShape2D` | `WorldBoundaryShape3D` / `WorldBoundaryShape2D` | |
| `RayShape` / `RayShape2D` | `SeparationRayShape3D` / `SeparationRayShape2D` | |
| `GIProbe` → `VoxelGI`; `Listener` → `AudioListener3D` | | |
| `TextureProgress` → `TextureProgressBar`; `VideoPlayer` → `VideoStreamPlayer` | | |
| `StreamTexture` → `CompressedTexture2D`; `GradientTexture` → `GradientTexture1D`; `CubeMesh` → `BoxMesh` | | |
| `VisibilityNotifier` / `VisibilityNotifier2D` / `VisibilityEnabler` | `VisibleOnScreenNotifier3D` / `VisibleOnScreenNotifier2D` / `VisibleOnScreenEnabler3D` | |
| `ShortCut` → `Shortcut`; `EditorSpatialGizmo(Plugin)` → `EditorNode3DGizmo(Plugin)` | | capital `C` on Shortcut |

## 2. Nodes deleted outright in 4.0 (no drop-in replacement)

`AnimationTreePlayer` → `AnimationTree`. `BakedLightmap`/`BakedLightmapData` → `LightmapGI`/`LightmapGIData`.
`BitmapFont`/`DynamicFont`/`DynamicFontData` → `FontFile`. `ClippedCamera`/`InterpolatedCamera` → plain `Camera3D`.
`Navigation2D`/`Navigation3D` → the `NavigationRegion*`/`NavigationAgent*` node family.
`OpenSimplexNoise` → `FastNoiseLite` (different parameters; no 4D noise). `ToolButton` → `Button` with `flat = true`.
`ProximityGroup` → `Node3D` (`VisibleOnScreenNotifier3D` is the closest behaviour).
`Portal`/`Room`/`RoomManager`/`RoomGroup`/`Occluder`/`OccluderShapeSphere` → raster occlusion culling via `OccluderInstance3D`.

## 3. Classes deprecated *inside* 4.7 — still exist, do not emit them

Extracted from `deprecated="…"` attributes in the class XMLs:

| Deprecated in 4.7 | Use instead |
| --- | --- |
| `TileMap` | multiple `TileMapLayer` nodes (split happened in 4.3) |
| `ParallaxBackground`, `ParallaxLayer` | `Parallax2D` |
| `AudioEffectLimiter` | `AudioEffectHardLimiter` |
| `AnimatedTexture` | "does not work properly in current versions"; no replacement named |
| `OpenXRHand` | `XRHandModifier3D` |
| `OpenXRExtensionWrapperExtension` | `OpenXRExtensionWrapper` |
| `PackedDataContainer`, `PackedDataContainerRef` | `var_to_bytes()` / `FileAccess.store_var()` |
| `VisualShaderNodeComment` | nothing — compatibility stub |

Deprecated *members* worth knowing: `Control.auto_translate` and `Window.auto_translate` →
`Node.auto_translate_mode`; `Image.create()` → `Image.create_empty()`;
`String.is_valid_identifier()` → `String.is_valid_ascii_identifier()`;
`Viewport.push_unhandled_input()` → `Viewport.push_input()`;
`Window.move_to_foreground()` → `Window.grab_focus()`;
`AStarGrid2D.size` → `region`; `SplitContainer.split_offset` → `split_offsets` (plural, array);
`TreeItem.set_custom_draw()` → `set_custom_draw_callback()`;
`RichTextLabel.is_ready()` → `is_finished()`;
`AnimationPlayer.set_process_callback()` → `AnimationMixer.callback_mode_process`;
`GeometryInstance3D.gi_lightmap_scale` → `gi_lightmap_texel_scale`;
`@GDScript.convert()` → `type_convert()`; `@GDScript.Color8()` → `Color.from_rgba8()`;
`@GDScript.type_exists()` → `ClassDB.class_exists()`.
`MultiMesh.transform_array` / `color_array` / `custom_data_array` are marked deprecated *for
performance*: use `set_instance_transform()` / `set_instance_color()` / `set_instance_custom_data()`.

## 4. GDScript language surface

| Model writes (3.x) | Correct 4.7 | Spot it by |
| --- | --- | --- |
| `export var hp = 10` | `@export var hp := 10` | bare `export` keyword |
| `export(int, 0, 100) var x` | `@export_range(0, 100) var x: int` | parenthesised export hint |
| `export(String, FILE) var p` | `@export_file var p: String` (or `@export_file_path`, see §11) | |
| `onready var s = $Sprite` | `@onready var s := $Sprite2D` | bare `onready` |
| `tool` | `@tool` (must be the *first* line) | |
| `var hp setget set_hp, get_hp` | `var hp: int: set(v): …` / `get: …`, or `var hp: get = get_hp, set = set_hp` | `setget` |
| `yield(get_tree(), "idle_frame")` | `await get_tree().process_frame` | `yield` — still a reserved word, but non-functional |
| `yield(get_tree().create_timer(1.0), "timeout")` | `await get_tree().create_timer(1.0).timeout` | |
| `func _ready(): ._ready()` | `func _ready(): super()` | leading `.` for parent calls |
| implicit parent `_ready()` call | **none** — 4.x does not auto-call the parent's lifecycle method; you must write `super()` | silently missing base-class init |
| `extends Node` then `class_name Foo` | `class_name Foo` then `extends Node`, or `class_name Foo extends Node` on one line | order swapped (see `gdscript_styleguide.rst` code order list) |
| `remote func f()` / `master func` / `puppet func` | `@rpc("any_peer", "call_local", "reliable") func f()` | `remote`/`master`/`puppet` keywords |
| `funcref(self, "f")` | `self.f` (already a `Callable`) or `Callable(self, "f")` | `funcref` — absent from `@GDScript` and `@GlobalScope` |
| `PoolByteArray`, `PoolIntArray`, `PoolRealArray`, `PoolStringArray`, `PoolVector2Array`, `PoolColorArray` | `PackedByteArray`, `PackedInt32Array`/`PackedInt64Array`, `PackedFloat32Array`/`PackedFloat64Array`, `PackedStringArray`, `PackedVector2Array`, `PackedColorArray` | the `Pool` prefix. There is no `PackedRealArray`; pick the bit width. `PackedVector4Array` exists in 4.7 |

Constants that **survived** 3.x → 4.x unchanged: `Vector2.ZERO/ONE/INF/LEFT/RIGHT/UP/DOWN`,
`Vector3.ZERO/ONE/INF/LEFT/RIGHT/UP/DOWN/FORWARD/BACK` (4.x also adds `Vector3.MODEL_LEFT`,
`MODEL_RIGHT`, `MODEL_TOP`, `MODEL_BOTTOM`, `MODEL_FRONT`, `MODEL_REAR`), and `PI`, `TAU`, `INF`, `NAN`.

Language features added *within* 4.x that a model trained on 4.0 material will not produce:
typed arrays `Array[int]` (4.0), typed loop variables `for i: int in …` (4.2),
typed dictionaries `Dictionary[String, int]` (4.4), variadic functions (4.5),
`@abstract` classes and methods (4.5). Nested typed collections
(`Array[Array[int]]`, `Dictionary[String, Dictionary[String, int]]`) are **not** supported.

## 5. Signals, `Callable`, `Signal`

`Object.connect` in 4.7 is `int connect(signal: StringName, callable: Callable, flags: int = 0)` —
three parameters, not five. The old `connect(sig, target, "method", binds_array, flags)` shape is gone.

```gdscript
# Wrong (Godot 3): connect("timeout", self, "_on_timeout", [id], CONNECT_ONESHOT)
# Right (4.7), preferred Signal-object form:
$Timer.timeout.connect(_on_timeout.bind(id), CONNECT_ONE_SHOT)
$Timer.timeout.disconnect(_on_timeout)          # must pass the SAME Callable
print($Timer.timeout.is_connected(_on_timeout)) # Signal.is_connected(callable)

signal died(cause: String)      # typed signal params are allowed in 4.x
died.emit("fall")               # NOT emit_signal("died", "fall") — that still works but is stringly-typed
```

- The flag is `CONNECT_ONE_SHOT` (`Object.ConnectFlags`, value 4). `CONNECT_ONESHOT` (no underscore)
  is the Godot 3 spelling and does not exist. Other flags: `CONNECT_DEFERRED` (1),
  `CONNECT_PERSIST` (2), `CONNECT_REFERENCE_COUNTED` (8), `CONNECT_APPEND_SOURCE_OBJECT` (16).
- `Callable.bind(...)` is vararg and **appends** bound args after the signal's own args;
  `Callable.bindv(arguments: Array)` takes them from an array. `Callable.unbind(argcount: int)`
  drops trailing args — this is how you connect a 1-arg signal to a 0-arg method.
- `Callable(object, "method_name")` is the constructor; for built-in `Variant` types use the
  static `Callable.create(variant, method)`.
- Deferred calling: `callable.call_deferred(...)`, `Object.call_deferred(method_name, ...)`,
  `Object.set_deferred(property, value)`. Godot 3's `call_deferred("set", …)` idiom still parses
  but `set_deferred` is the correct form.
- `SceneTree.call_group()`, `set_group()` and `notify_group()` are **immediate** in 4.x (they were
  deferred in 3.x). For the old behaviour use `call_group_flags(SceneTree.GROUP_CALL_DEFERRED, …)`.

## 6. Tweens

There is no `SceneTreeTween` class in 4.7 and no `Tween` *node*. `Tween` is a `RefCounted`-ish
object obtained from `Node.create_tween()` or `SceneTree.create_tween()`. All the Godot 3
`Tween` methods (`interpolate_property`, `interpolate_method`, `start`, `remove_all`,
`follow_property`, `tween_completed` signal) are absent.

```gdscript
var t := create_tween()                       # bound to this node; dies with it
t.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
t.tween_property(self, ^"position", target, 0.4).as_relative()
t.parallel().tween_property(self, ^"modulate:a", 0.0, 0.4)
t.tween_callback(queue_free)
await t.finished
```

Full 4.7 method set: `tween_property`, `tween_method`, `tween_callback`, `tween_interval`,
`tween_subtween`, `tween_await`; chaining/ordering with `parallel()`, `chain()`, `set_parallel()`;
lifecycle `play()`, `pause()`, `stop()`, `kill()`, `is_running()`, `is_valid()`, `custom_step(delta)`;
config `set_loops()`, `set_speed_scale()`, `set_trans()`, `set_ease()`, `set_process_mode()`,
`set_pause_mode()`, `set_ignore_time_scale()`, `bind_node()`. Signals: `finished`,
`loop_finished(loop_count)`, `step_finished(idx)` — **not** `tween_completed`.
Tweener modifiers: `PropertyTweener.from()`, `from_current()`, `as_relative()`,
`set_custom_interpolator(Callable)`, `set_delay()`; `AwaitTweener.set_timeout()`.
`tween_subtween` and `tween_await` are recent additions — they are present in 4.7 but I could not
determine from the vendored docs which 4.x minor introduced them; do not assume 4.0 has them.
Working example: `third_party/godot-demo-projects/2d/tween/main.gd`.

## 7. Physics

```gdscript
extends CharacterBody2D

func _physics_process(delta: float) -> void:
    velocity.y += gravity * delta
    velocity.x = Input.get_axis(&"move_left", &"move_right") * SPEED
    move_and_slide()                 # no arguments, returns bool
    if is_on_floor() and Input.is_action_just_pressed(&"jump"):
        velocity.y = -JUMP_SPEED
```

| Model writes | Correct 4.7 |
| --- | --- |
| `velocity = move_and_slide(velocity, Vector2.UP)` | set the `velocity` property, then `move_and_slide()`; it returns `bool` "did I collide" |
| `move_and_slide_with_snap(...)` | `floor_snap_length` property + `apply_floor_snap()` |
| `is_on_floor()` before moving | `is_on_floor()`/`is_on_wall()`/`is_on_ceiling()` reflect the **last** `move_and_slide()`; call them after |
| `get_slide_count()` | `get_slide_collision_count()` |
| `get_slide_collision(i)` returning a Dictionary | returns `KinematicCollision2D`/`KinematicCollision3D`; also `get_last_slide_collision()` |
| `KinematicCollision.collider` | `get_collider()`, `get_normal()`, `get_position()`, `get_travel()`, `get_remainder()`, `get_depth()`, `get_angle()` — methods, not properties |
| `space_state.intersect_ray(from, to, exclude)` | build a `PhysicsRayQueryParameters2D`/`3D` (e.g. `PhysicsRayQueryParameters3D.create(from, to)`) and pass it to `intersect_ray(parameters)` |
| `Area.body_entered` | `Area2D`/`Area3D` — the signals themselves (`body_entered`, `body_exited`, `area_entered`, `area_exited`, `body_shape_entered`, …) kept their names |
| `RigidBody.add_force` | `apply_force(force, position)` / `apply_central_force()` / `apply_impulse()` / `add_constant_force()` |

Other 4.x specifics:
- `move_and_slide()` multiplies by the physics delta internally; `move_and_collide(motion)` does
  **not** — you must pass `velocity * delta`. Documented in `PhysicsBody2D.xml`.
- Body tuning lives on properties, not arguments: `up_direction`, `floor_max_angle`,
  `floor_stop_on_slope`, `floor_block_on_wall`, `floor_constant_speed`, `floor_snap_length`,
  `max_slides`, `slide_on_ceiling`, `wall_min_slide_angle`, `safe_margin`, `motion_mode`
  (`MOTION_MODE_GROUNDED` / `MOTION_MODE_FLOATING`), `platform_on_leave`.
- 4.6 changed the default 3D physics engine for **newly created** projects to Jolt
  (`physics/3d/physics_engine`). 4.7 then changed Jolt behaviour for `WorldBoundaryShape3D.plane.d`
  sign, `SoftBody3D` mass/stiffness defaults, and made `Area3D` report `SoftBody3D` overlaps.
  If a bug report mentions 3D physics behaviour changing, check which engine is selected first.

## 8. Time, Engine, OS, DisplayServer

`OS` lost every time, window and screen method in 4.0. Verified absent from `OS.xml`:
`get_ticks_msec`, `get_ticks_usec`, `get_datetime`, `get_time`, `get_system_time_secs`,
`get_unix_time`, `window_size`, `window_fullscreen`, `get_screen_size`, `get_real_window_size`,
`set_window_title`, `get_current_video_driver`.

| Model writes | Correct 4.7 |
| --- | --- |
| `OS.get_ticks_msec()` | `Time.get_ticks_msec()` (also `Time.get_ticks_usec()`) |
| `OS.get_datetime()` | `Time.get_datetime_dict_from_system(utc)` |
| `OS.get_unix_time()` | `Time.get_unix_time_from_system()` |
| `OS.get_system_time_secs()` | `Time.get_time_dict_from_system()["second"]` |
| `OS.window_size` | `DisplayServer.window_get_size()` / `window_set_size()` |
| `OS.window_fullscreen = true` | `DisplayServer.window_set_mode(DisplayServer.WINDOW_MODE_FULLSCREEN)` |
| `OS.get_screen_size()` | `DisplayServer.screen_get_size()` |
| `OS.set_clipboard()` | `DisplayServer.clipboard_set()` / `clipboard_get()` |
| `Engine.target_fps` | `Engine.max_fps` |
| `Engine.iterations_per_second` | `Engine.physics_ticks_per_second` |
| `Engine.editor_hint` | `Engine.is_editor_hint()` |

`Engine.get_frames_per_second()` **survives** and returns `float`. Also useful and often forgotten:
`Engine.time_scale`, `Engine.max_physics_steps_per_frame`, `Engine.physics_jitter_fix`,
`Engine.get_physics_interpolation_fraction()`, `Engine.is_in_physics_frame()`,
`Engine.get_process_frames()`, `Engine.get_physics_frames()`, and
`Performance.get_monitor(Performance.TIME_FPS)`.
`OS.delay_msec()`/`delay_usec()` still exist — they block; never call them in `_process`.

## 9. Randomness

`randomize()` is called automatically at project start in 4.x, so a script that wants
deterministic output must call `seed(value)` itself.

| Model writes | Correct 4.7 |
| --- | --- |
| `rand_range(a, b)` | `randf_range(a, b)` (float) or `randi_range(a, b)` (int, inclusive) |
| `randi() % n` | works, but `randi_range(0, n - 1)` is clearer |
| `rand_seed(s)` | `rand_from_seed(seed)` |
| `array[randi() % array.size()]` | `array.pick_random()` |

Full global set in `@GlobalScope`: `randi`, `randf`, `randi_range`, `randf_range`, `randfn`,
`randomize`, `seed`, `rand_from_seed`. For an isolated stream use `RandomNumberGenerator`
(`seed`, `state`, `randi`, `randf`, `randi_range`, `randf_range`, `randfn`, `rand_weighted`,
`randomize`). See `third_party/godot-docs/tutorials/math/random_number_generation.rst`.

## 10. Global function and String renames

Absent from `@GlobalScope` in 4.7 (all Godot 3 names): `deg2rad`, `rad2deg`, `linear2db`, `db2linear`,
`str2var`, `var2str`, `bytes2var`, `var2bytes`, `stepify`, `range_lerp`, `dectime`, `decimals`,
`polar2cartesian`, `cartesian2polar`, `funcref`, `dict2inst`, `inst2dict`.

| Gone | 4.7 |
| --- | --- |
| `deg2rad` / `rad2deg` | `deg_to_rad` / `rad_to_deg` |
| `linear2db` / `db2linear` | `linear_to_db` / `db_to_linear` |
| `str2var` / `var2str` | `str_to_var` / `var_to_str` |
| `bytes2var` / `var2bytes` | `bytes_to_var` / `var_to_bytes` (plus `*_with_objects` variants) |
| `stepify(x, s)` | `snapped(x, s)` (`snappedf`, `snappedi`) |
| `range_lerp(v, a, b, c, d)` | `remap(v, a, b, c, d)` |
| `dectime(v, amount, delta)` | `move_toward(v, 0.0, amount * delta)` |
| `decimals(x)` | `step_decimals(x)` |
| `polar2cartesian` / `cartesian2polar` | removed; use `Vector2.from_angle()` / `Vector2.angle()` and `length()` |
| `dict2inst` / `inst2dict` | `dict_to_inst` / `inst_to_dict` — both marked **deprecated** in 4.7; prefer `JSON.to_native()` / `JSON.from_native()` |

`String`: `empty()` → `is_empty()`; `percent_encode()`/`percent_decode()` → `uri_encode()`/`uri_decode()`;
`is_valid_integer()` → `is_valid_int()`; `is_valid_identifier()` → `is_valid_ascii_identifier()`;
`right(pos)` changed meaning in 4.0 (now "N characters from the right", not "from index to end") —
use `substr()` for the old behaviour.

`Array`: `remove(i)` → `remove_at(i)`; `invert()` → `reverse()`; `empty()` → `is_empty()`;
`sort_custom(obj, "fn")` → `sort_custom(callable)`; `bsearch_custom(v, obj, "fn")` →
`bsearch_custom(value, callable, before)`. `slice(begin, end)`'s `end` is **exclusive** in 4.x
(`[1,2,3].slice(0, 1) == [1]`). Higher-order methods all take `Callable`: `map`, `filter`,
`reduce`, `any`, `all`, `find_custom`, `rfind_custom`.

`Dictionary`: `empty()` → `is_empty()`. 4.7 has `get_or_add`, `merge`, `merged`, `sort`,
`duplicate_deep`, `recursive_equal`.

## 11. Resource loading, `.tres`/`.res`, and `uid://`

- `preload(path)` is resolved at parse time and needs a **constant** path; `load(path)` is runtime.
  Both live in `@GDScript`. `ResourceLoader.load(path, type_hint, cache_mode)` gives you cache control
  (`CACHE_MODE_REUSE` default, plus `CACHE_MODE_IGNORE`, `CACHE_MODE_REPLACE`, `CACHE_MODE_IGNORE_DEEP`,
  `CACHE_MODE_REPLACE_DEEP`).
- `PackedScene.instance()` is Godot 3. 4.x is `PackedScene.instantiate(edit_state: int = 0)`.
  Same rename family: `PackedScene.can_instantiate()`, `Node.DUPLICATE_USE_INSTANTIATION`.
- `.tres` = text resource, `.res` = binary resource, `.tscn`/`.scn` the scene equivalents.
  `ResourceSaver.save()` had its arguments **swapped** in 4.0: it is now
  `save(resource: Resource, path: String = "", flags: int = 0)`. `ResourceSaver.set_uid(path, uid)`
  and `ResourceSaver.get_resource_id_for_path(path, generate)` exist if you must script UID handling.
  Format details: `third_party/godot-docs/engine_details/file_formats/tscn.rst`.
- Threaded loading, verified signatures:

```gdscript
ResourceLoader.load_threaded_request("res://big.tscn")            # returns Error
var progress := []
match ResourceLoader.load_threaded_get_status("res://big.tscn", progress):
    ResourceLoader.THREAD_LOAD_IN_PROGRESS: pass                  # progress[0] is 0.0..1.0
    ResourceLoader.THREAD_LOAD_LOADED:
        var scene: PackedScene = ResourceLoader.load_threaded_get("res://big.tscn")
    ResourceLoader.THREAD_LOAD_FAILED, ResourceLoader.THREAD_LOAD_INVALID_RESOURCE: push_error("…")
```

  Working example: `third_party/godot-demo-projects/loading/load_threaded/load_threaded.gd`.
  `load_threaded_request` also takes `use_sub_threads: bool = false` — leave it false for web builds
  unless thread support is enabled in the export preset.
- `Resource.duplicate(true)` changed in 4.5: deep duplication no longer follows **external**
  resources. `Resource.duplicate_deep(DEEP_DUPLICATE_ALL)` restores the 4.4 behaviour.

### `.gd.uid` sidecar files (Godot 4.4+) — rules for agents

Every script and importable resource has a UID like `uid://birx25108riec`. For `.gd` files the UID
is stored in a sidecar file next to it (`player.gd` → `player.gd.uid`, one line, nothing else); for
`.tscn`/`.tres` it is an attribute inside the file
(`[gd_scene format=3 uid="uid://cecaux1sm7mo0"]`). Scenes reference their dependencies by UID *and*
path: `[ext_resource type="Texture2D" uid="uid://ccbm14ebjmpy1" path="res://gradient.tres" id="2_eorut"]`.
The point is that moving or renaming a file does not break references, even if the editor is closed,
without any central metadata database. `ResourceUID` exposes `uid_to_path()`, `path_to_uid()`,
`ensure_path()` (all static), plus `text_to_id()`, `id_to_text()`, `has_id()`, `get_id_path()`.

Rules:
1. **Commit `.uid` files.** `version_control_systems.rst` lists only `.godot/` and `*.translation`
   as things to gitignore — `.uid` files are project sources.
2. **Never hand-write, renumber, or copy-paste a UID.** Duplicated UIDs across two files cause the
   editor to resolve references to the wrong resource.
3. **Never delete a `.uid` casually.** Deleting one makes the editor mint a fresh UID on next import,
   silently breaking every `uid://` reference to that script.
4. When you move a script with `git mv`, move its `.uid` in the same commit.
5. `uid://…` is a valid path for `load()`/`preload()`, but prefer `res://` paths in hand-written code:
   they are greppable and reviewable. `@export_file` returns `uid://` since 4.4; use
   `@export_file_path` (added 4.5) when you specifically need a raw `res://` string.

## 12. Input and controllers

- `Input.get_axis(negative_action, positive_action)` and
  `Input.get_vector(neg_x, pos_x, neg_y, pos_y, deadzone := -1.0)` are 4.x-only conveniences;
  models tend to hand-roll `is_action_pressed` arithmetic instead.
- Action names are `StringName`: write `&"jump"`, not `"jump"`, in hot paths.
- 4.7 changed mouse/keyboard device IDs from `0` to `InputEvent.DEVICE_ID_MOUSE` (32) and
  `InputEvent.DEVICE_ID_KEYBOARD` (16), because some joypads report device `0`. Any code doing
  `if event.device == 0:` to mean "keyboard" is now wrong. `InputEvent.DEVICE_ID_EMULATION` is `-1`.
- Joypad constants are `JOY_BUTTON_A`, `JOY_BUTTON_DPAD_UP`, `JOY_BUTTON_LEFT_SHOULDER`,
  `JOY_BUTTON_MISC1`, `JOY_BUTTON_PADDLE1`, … in `@GlobalScope` — not the 3.x `JOY_XBOX_A` family.
- Rumble: `Input.start_joy_vibration(device, weak, strong, duration)`, `stop_joy_vibration(device)`,
  `Input.vibrate_handheld(duration_ms, amplitude)`. Presence checks: `Input.has_joy_vibration()`,
  `Input.has_joy_light()`, `Input.has_joy_motion_sensors()`.
- `Input.mouse_mode` is a property (`MOUSE_MODE_CAPTURED`, …), not `set_mouse_mode()`.
- 4.1 behaviour change: a `SubViewportContainer` needs `mouse_filter` set to `MOUSE_FILTER_STOP` or
  `MOUSE_FILTER_PASS` for input to reach its `SubViewport`, and a `Viewport` with physics picking
  enabled now marks input events handled automatically.

## 13. Accessibility and UI (4.5–4.7) — newer than most training data

`Control` gained `accessibility_name`, `accessibility_description`, `accessibility_live`,
`accessibility_labeled_by_nodes`, `accessibility_described_by_nodes`, `accessibility_controls_nodes`,
`accessibility_flow_to_nodes`. `Node` has `_get_accessibility_configuration_warnings()`,
`get_accessibility_element()`, `queue_accessibility_update()`. `SceneTree` has
`is_accessibility_supported()` and `is_accessibility_enabled()`. In **4.7** the accessibility roles,
flags and live-region constants moved off `DisplayServer` onto the new `AccessibilityServer`
singleton — every `DisplayServer.ROLE_*`, `FLAG_*`, `ACTION_*`, `LIVE_*` constant is marked
deprecated with "Use `AccessibilityServer` instead", and `Control.accessibility_live` changed type
from `DisplayServer.AccessibilityLiveMode` to `AccessibilityServer.AccessibilityLiveMode`.

Also 4.6+: `Control.grab_focus(hide_focus: bool = false)` and
`Control.has_focus(ignore_hidden_focus: bool = false)` gained parameters;
`Control.focus_behavior_recursive` and `mouse_behavior_recursive` are new properties.
Layout names are 4.x-wide: `position`/`size` (not `rect_position`/`rect_size`),
`offset_left`/`offset_top`/`offset_right`/`offset_bottom` (not `margin_*`),
`custom_minimum_size` (not `rect_min_size`), `pivot_offset` (not `rect_pivot_offset`).

## 14. Breakage *within* 4.x, by version

Only the items that can silently change behaviour in a genre-neutral project. Full tables:
`third_party/godot-docs/tutorials/migrating/upgrading_to_godot_4.N.rst`.

| Version | Change | Why it bites |
| --- | --- | --- |
| 4.1 | `NavigationAgent2D/3D.set_velocity()` replaced by the `velocity` property; `agent_height_offset` → `path_height_offset`; `get_rid()` → `get_agent_rid()` | navigation code from 4.0 tutorials fails to run |
| 4.1 | GDExtensions built for 4.0 do **not** load in 4.1+ | vendored addons must target ≥ 4.1 |
| 4.2 | `AnimationPlayer` signals/properties moved to `AnimationMixer` (`animation_finished`, `animation_started`, `callback_mode_process`, `root_node`) | still works from GDScript, but docs links and C# break |
| 4.3 | `TileMap` layers became separate `TileMapLayer` nodes | `TileMap` is deprecated; new code must use `TileMapLayer` |
| 4.3 | Reverse-Z depth buffer | custom shaders touching depth need rewriting |
| 4.3 | `Node.auto_translate` deprecated for `Node.auto_translate_mode` (default `AUTO_TRANSLATE_INHERIT`) | a child of a non-translating node stops translating |
| 4.3 | Web exports default to audio **samples**, not streams | audio effects do not apply on web |
| 4.4 | `@export_file` stores `uid://` instead of `res://` | string comparisons against `res://…` break |
| 4.4 | `FileAccess.store_*` return `bool` instead of `void` | source-compatible in GDScript; C# breaks |
| 4.4 | CSG switched to the Manifold library; non-manifold meshes unsupported | quads/planes as CSG stop working |
| 4.5 | `Resource.duplicate(true)` no longer duplicates external resources | see §11 |
| 4.5 | `Node.get_rpc_config()` renamed `get_node_rpc_config()` | GDScript-incompatible rename |
| 4.5 | `TileMapLayer` physics chunking on by default; `get_coords_for_body_rid()` less precise | set `physics_quadrant_size = 1` for 4.4 behaviour |
| 4.5 | Navigation region updates are async by default (`navigation/world/region_use_async_iterations`) | paths may be one frame stale |
| 4.6 | `.tscn` format: `load_steps` no longer written; unique node IDs added | big, expected VCS diffs on first save |
| 4.6 | `AnimationPlayer.current_animation`/`assigned_animation`/`autoplay` became `StringName` | fine in GDScript, breaks C# |
| 4.6 | Glow defaults changed (blend mode Screen, `glow_intensity` 0.8 → 0.3, level weights) | scenes look much brighter |
| 4.6 | Default Windows rendering driver for **new** projects is D3D12 | `rendering/rendering_device/driver.windows` |
| 4.6 | `MeshInstance3D.skeleton` default `NodePath("..")` → `NodePath("")` | re-enable `animation/compatibility/default_parent_skeleton_in_mesh_instance_3d` if needed |
| 4.7 | Mouse/keyboard device IDs changed (§12) | `event.device == 0` checks |
| 4.7 | `CanvasItem` no longer adds an antialiasing feather to lines | lines look thinner; increase width |
| 4.7 | `AudioStreamPlayer2D`/`3D` `area_mask` default `1` → `0` | `Area2D`/`Area3D` `audio_bus_override` stops working. The upgrade page says "AudioStreamPlayer", but the property only exists on the 2D/3D variants |
| 4.7 | Setting one element of a packed-array property no longer invokes the property's setter | setters that validated whole arrays stop firing |
| 4.7 | Overriding a method with a typed return now inherits the return type; an explicit `return` is required | add `return null` |
| 4.7 | `AnimationNodeBlendSpace1D/2D` `sync` bool replaced by `sync_mode` enum | blend spaces transition differently |
| 4.7 | New projects default to stretch mode `canvas_items` + aspect `expand` (was `disabled`/`keep`) | |
| 4.7 | Minimum macOS raised to 11 (Big Sur) | |

## 15. Web (HTML5) traps, since we ship to GitHub Pages

From `third_party/godot-docs/tutorials/export/exporting_for_web.rst`:

- Forward+ and Mobile renderers are **not supported** on web. Use the Compatibility renderer.
- `Thread` and `WorkerThreadPool` only work if the export preset's **Thread Support** is enabled,
  which requires `SharedArrayBuffer`, which requires cross-origin isolation headers
  (COOP/COEP) that GitHub Pages cannot set. Assume single-threaded on web and never make a
  feature depend on `Thread`.
- Audio effects (`AudioEffect*`), reverb/doppler buses and procedural audio generation are
  unsupported on web; since 4.3 web audio uses samples by default.
- Only `HTTPClient`, `HTTPRequest`, WebSocket client and WebRTC are available. `HTTPRequest` on web
  cannot use threaded/blocking mode, cannot progress more than once per frame, gets no chunked
  responses, and is subject to same-origin policy.
- Microphone and clipboard require a secure context; clipboard sync is asynchronous and unreliable
  from GDScript.
- `JavaScriptBridge` is the singleton name in 4.7 (`eval`, `get_interface`, `create_object`,
  `create_callback`, `download_buffer`, `force_fs_sync`, `pwa_needs_update`, `pwa_update`).
  A bare `JavaScript` singleton does **not** exist in the 4.7 reference. I could not verify from
  the vendored docs which 4.x minor performed that rename — the 4.1 upgrade page does not list it.
- Guard platform code with `OS.has_feature("web")`, and keep `JavaScriptBridge` calls behind that guard.

## 16. Misc, high-frequency

- `Object.free()` is immediate; `Node.queue_free()` defers to end of frame. `SceneTree.queue_delete()`
  exists too. Check liveness with `is_instance_valid(obj)` — Godot 3's `weakref(o).get_ref()` pattern
  still works (`weakref` and `WeakRef` both exist) but `is_instance_valid` is clearer.
- `SceneTree.change_scene(path)` is gone. Use `change_scene_to_file(path)`,
  `change_scene_to_packed(packed_scene)` or `change_scene_to_node(node)`. Also
  `reload_current_scene()` and `unload_current_scene()`.
- `Thread.start(callable, priority)` — no `(object, "method", userdata)` form. `Thread.is_active()`
  is gone; use `is_alive()` or `is_started()`. Bind arguments with `Callable.bind()`.
- `Node.print_stray_nodes()` → `Node.print_orphan_nodes()` (static in 4.7, alongside
  `get_orphan_node_ids()`).
- `AnimatedSprite2D` has no `playing` property and no `frames` property: use `is_playing()`,
  `play()`, `stop()`, `pause()`, and `sprite_frames`.
- `Camera2D.zoom` was **inverted** in 4.0 (higher = more zoomed in) and `rotating` became
  `ignore_rotation` with inverted meaning.
- `rotation` is radians everywhere; `rotation_degrees` exists on `Node2D`, `Node3D` and `Control`
  but the Inspector edits `rotation` and shows degrees.
- `AABB.has_no_surface()` → `has_surface()` (inverted); `AABB`/`Rect2` `has_no_area()` → `has_area()` (inverted).
- `BaseButton`: the *state property* is `button_pressed` (Godot 3 called it `pressed`). `pressed` still
  exists but is a **signal**, alongside `button_up`, `button_down` and `toggled`. Writing
  `button.pressed = true` therefore assigns to a signal name and does not press the button.
- `String` vs `StringName`: `is_same("x", &"x")` is `false` even though `"x" == &"x"` is `true`.
  Node paths accept `^"path"` literals. Prefer `&""`/`^""` for constants used every frame.
- Scene-unique nodes: `%RedButton` / `get_node("%RedButton")`, resolvable only within the same scene.
- In `_get_property_list()`, the hint strings are `or_less` and `no_slider` (were `or_lesser`, `noslider`).

## 17. Pre-commit checklist for generated GDScript

1. No `Directory`, `File`, `Spatial`, `KinematicBody`, `Reference`, `YSort`, `ARVR*`, `Pool*Array`.
2. No bare `export`, `onready`, `tool`, `setget`, `yield`, `remote`/`master`/`puppet`.
3. Every `connect(` has exactly a `StringName`/`Callable`(+flags) shape, and any custom signal is
   emitted with `my_signal.emit(...)`.
4. `move_and_slide()` takes no arguments; `velocity` is assigned first.
5. `instantiate()`, not `instance()`.
6. Tween is `create_tween()` + `tween_property(...)`, never a `Tween` node.
7. Any new `.gd` file's `.gd.uid` sidecar is staged in the same commit; none were edited by hand.
8. Nothing depends on `Thread` on the web build.
9. Every class/method named exists: `grep -P '^ClassName\t' library/api/symbols.tsv`.

## 18. Claims I could not verify from the vendored sources

- Which 4.x minor renamed the `JavaScript` singleton to `JavaScriptBridge` (§15).
- Which 4.x minor added `Tween.tween_subtween()` and `Tween.tween_await()` (§6) — both are present
  in 4.7 but absent from the vendored `.rst` prose entirely.
- Whether the Godot 3 declaration order `extends X` followed by `class_name Y` is a hard parse error
  in 4.7 or merely non-idiomatic. `gdscript_styleguide.rst` prescribes `class_name` before `extends`
  (or the single-line `class_name Y extends X`); the vendored docs do not state what the parser does
  with the reverse order.
- Exact 4.x minor for `Engine.target_fps` → `Engine.max_fps` and
  `Engine.iterations_per_second` → `Engine.physics_ticks_per_second`. Only the 4.7 endpoint names
  are verified (`max_fps` and `physics_ticks_per_second` exist; the old names do not).
