# Scene and code architecture that survives contact with a real game

How to lay out a Godot 4.7 project — node vs `Resource` vs `RefCounted`, signals, autoloads, groups, node
references, folder layout, state machines, scene transitions, versioned saves, dependency direction — so month
three does not need a rewrite. Read before creating the first scene, before adding an autoload, and before
designing a save format. Every backticked API was checked against the vendored `4.7.1-stable` reference in
`third_party/godot-class-reference/classes/`; every example is a real file in
`third_party/` cited at the lines it was read.

Engine is **Godot 4.7.1 stable**; target is **desktop PC on Steam** (Windows, Linux, Steam Deck) —
`docs/PLATFORM_TARGETS.md`. Threads exist, `user://` is a real directory, Forward+ is
available. **There is no game project in this repo**; the genre is undecided, so all of this is genre-neutral.
Companions: `library/guides/api-changes-and-traps.md`, `gdscript-style-and-typing.md` in
the same directory.

**Path shorthand in this file:** `.../` expands to `third_party/`. Bare `.rst` names
(`best_practices/…`, `scripting/…`, `io/…`, `migrating/…`) are relative to
`third_party/godot-docs/tutorials/`.

## 1. `Object` vs `RefCounted` vs `Resource` vs `Node` — decision rule

Source: `best_practices/node_alternatives.rst`. Ask in order, stop at the first yes.

| Question | Base type | Memory | Inspector | Serializes | In tree |
| --- | --- | --- | --- | --- | --- |
| Needs process ticks, input, transform, children, physics? | `Node` | owned by parent, `queue_free()` | yes | via `PackedScene` | yes |
| Needs saving to `.tres`/`.res`, or Inspector editing? | `Resource` | refcounted | **yes** | **yes** | no |
| Plain data or logic, no serialization, no tree? | `RefCounted` | refcounted | no | no | no |
| Needs manual lifetime, or a node-like structure cheaper than `Node`? | `Object` — you must `free()` | manual, can dangle | no | no | no |

- A `.gd` file with **no `extends`** implicitly extends `RefCounted`: instantiable with `.new()`, **not**
  attachable to a node (`best_practices/what_are_godot_classes.rst`).
- Dangling `Object` refs are the classic crash — guard with `is_instance_valid(obj)` or `weakref(obj)`, and
  prefer `RefCounted` without a measured reason not to.
- `Node` is cheap, not free. 5,000 inventory entries are `Resource`s, not 5,000 `Node`s. The engine does this
  itself: `Tree` is a node, its rows are `TreeItem`, which extends `Object`.

**Scene vs script** (`best_practices/scenes_versus_scripts.rst`): a concept particular to *this* game → a
**scene** (declarative, diffable, and `PackedScene` instantiation is batched engine-side, faster than building
the hierarchy in GDScript). A reusable tool other people drop into scenes → a **script** with `class_name` and
`@icon`. Building authored hierarchies imperatively is the slow path.

## 2. Composition over inheritance in the node tree

The manual is explicit: "Godot's node trees form an **aggregation** relationship, not one of composition"
(`best_practices/scene_organization.rst`). Nodes are not ECS components.

- **Behaviour goes in child nodes** — state machine, health, hurtbox, AI controller — configured via `@export`,
  talking to the entity by signal or injected reference, never `get_parent().get_parent()`.
- **Deep script inheritance is the trap.** Two or three levels is fine; five is not. open-rpg stops at
  `Cutscene` → `Trigger` → `AreaTransition` → `Door` (`.../godot-open-rpg/src/field/cutscenes/`).
- **Ownership test:** does deleting the parent reasonably mean the child dies too? If no, it belongs elsewhere
  as a sibling; use `RemoteTransform2D`/`RemoteTransform3D` when a non-child must still follow a transform. A
  child that must ignore the parent transform gets a plain `Node` in between (declarative) or
  `CanvasItem.top_level` / `Node3D.top_level` (imperative).

## 3. `class_name` registration

```gdscript
@icon("res://interface/icons/action.svg")   # optional; string literal only
@abstract                                   # 4.5+
class_name BattlerAction extends Resource   # one-line form is legal
```

- `class_name` registers the type globally: no `load`/`preload`, a slot in the Create dialog, and the editor
  understands its inheritance (`scripting/gdscript/gdscript_basics.rst:2101`). Annotations describe the class, so
  `@icon`/`@abstract` sit **above** it.
- `@abstract` exists **since Godot 4.5**: `.../godot-open-rpg/src/combat/actions/battler_action.gd:6-7`
  (abstract class) and `:78-79` (`@abstract func execute() -> void`, no body).
- A `class_name` script extending `RefCounted` stays out of the node dialog — that is how you get a namespace:
  `class_name Game extends RefCounted` + `const MAIN_MENU = preload("res://…tscn")`.
- Files `snake_case.gd`, classes and node names `PascalCase` (`best_practices/project_organization.rst`). `class_name` must be
  unique project-wide; colliding with an engine class is a parse error.

## 4. Custom `Resource` as the data container

`Resource` is Godot's ScriptableObject. Over JSON/CSV it gains constants, methods, setters, **signals**,
guaranteed properties, free (de)serialization, recursive sub-resources, VCS-friendly `.tres`, and Inspector
editing for free (`scripting/resources.rst`).

Example: `.../godot-open-rpg/src/combat/battlers/battler_stats.gd` — `class_name BattlerStats extends Resource`
(:2), `signal health_changed()` (:12), `@export_category("Stats")` (:20), validating setters `@export var
base_attack := 10: set(value): …` (:23-25). Consumed by a node at `.../godot-open-rpg/src/combat/battlers/battler.gd:32` —
`@export var stats: BattlerStats = null` and `@export var actions: Array[BattlerAction]`; an exported array of
resources *is* data-driven behaviour.

### The trap: exported resources are SHARED between instances

`load()` returns the **cached** instance. Every scene instance exporting the same `.tres` gets the *same
object*; mutating one enemy's `stats.health` mutates all of them and dirties the file. Fix, from
`battler.gd:147-174`:

```gdscript
func _ready() -> void:
    if not Engine.is_editor_hint():
        assert(stats, "Battler %s does not have stats assigned!" % name)
        stats = stats.duplicate()   # resources are NOT unique: treat the .tres as a prototype
        stats.initialize()
```

- Read-only definitions (weapon stats, loot tables, tuning curves): use directly, never write. Mutable
  per-instance state: `duplicate()` in `_ready()`, always.
- `Resource.duplicate(true)` **changed in 4.5**: it now only duplicates resources internal to the same file. For
  the old deep behaviour call `Resource.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)`
  (`migrating/upgrading_to_godot_4.5.rst`).
- Engine alternative: `Resource.resource_local_to_scene = true` ("Local to Scene") gives each scene instance its
  own copy and calls `_setup_local_to_scene()`. Prefer it for resources authored inside a scene; prefer explicit
  `duplicate()` for shared `.tres` prototypes — the intent is then visible in the script rather than in a
  checkbox.
- `@export_file` returns `uid://` paths **since 4.4**; use `@export_file_path` (4.5+) for `res://` strings. Give
  every `@export`ed property a default or the Inspector cannot construct the resource.

## 5. Instancing and scene inheritance

```gdscript
const ENEMY := preload("res://src/enemies/grunt.tscn")   # PackedScene
var e := ENEMY.instantiate()                              # NOT .instance() — Godot 3
e.position = spawn_point                                  # set properties BEFORE add_child
add_child(e)
```

Set properties before `add_child()`: some setters run expensive in-tree fix-up
(`best_practices/logic_preferences.rst`). Exception: global transform needs the node in-tree.

| Mechanism | How | Use when |
| --- | --- | --- |
| **Instancing** | `PackedScene.instantiate()` | Almost always |
| **Scene inheritance** | Scene dock → New Inherited Scene; runtime `instantiate(PackedScene.GEN_EDIT_STATE_MAIN_INHERITED)` | Many variants of one layout |
| **Editable Children** | right-click instance; `Node.set_editable_instance()` | Rare one-offs. Each use is coupling |
| **Script inheritance** | `extends BaseClass` | Behaviour, not structure. Keep shallow |

`instantiate(edit_state := 0)` constants: `GEN_EDIT_STATE_DISABLED=0`, `_INSTANCE=1`, `_MAIN=2`,
`_MAIN_INHERITED=3`. Inheritance caveat: base-scene structure changes propagate everywhere (the point *and* the
risk), and a property overridden in a child is pinned and stops tracking the base — prefer instancing +
`@export` when variants differ by data rather than shape. `Node.duplicate(flags)` (`DUPLICATE_SIGNALS=1`,
`_GROUPS=2`, `_SCRIPTS=4`, `_USE_INSTANTIATION=8`, `_INTERNAL_STATE=16`, `_DEFAULT=15`) copies only
storage-flagged properties (`@export`); plain `var`s are lost unless you pass `DUPLICATE_INTERNAL_STATE`.

## 6. Node references: `$`, `@onready`, `%`, `@export`, groups

`get_node("../../HUD/Bars/Health")` is the commonest month-three breakage: a hard dependency on a tree shape
someone will change. Ranked best-first (`best_practices/godot_interfaces.rst`,
`scripting/scene_unique_nodes.rst`):

| Technique | Syntax | Scope | Breaks when | Verdict |
| --- | --- | --- | --- | --- |
| Injected by parent | `@export var target: Node` | any | never silently — Inspector slot goes red | **Best cross-scene** |
| Scene unique name | `%HealthBar` | **same scene only** | node deleted/unmarked | **Best in-scene** |
| Cached `@onready` | `@onready var bar := $Bars/Health` | same scene | node moved | Fine for stable paths |
| `$Path` inline | `$Bars/Health.value = 3` | same scene | node moved | OK one-off; re-resolves each call |
| Group lookup | `get_tree().get_first_node_in_group(&"player")` | tree | zero or many members | True singletons-in-world |
| `get_node("/root/Autoload")` | absolute | tree | autoload renamed | Last resort |
| `find_child("Health")` | pattern | descendants | ambiguous match | **Avoid** — documented as slow |

- `%` sets `Node.unique_name_in_owner = true`; resolution is by **scene ownership**, not distance, so from the
  Player scene `%Hilt` inside an instanced Sword returns `null`. Chain instead: `get_node("Hand/Sword/%Hilt")`,
  or `get_node("%Sword/%Hilt")` if Sword is itself unique-named. Unique names are engine-cached and fast;
  `find_child()` walks every descendant.
- `get_node()` errors on a missing path; `get_node_or_null()` returns `null` — use the latter for optional
  wiring and branch explicitly. Prefer `NodePath` literals `^"Bars/Health"` and `StringName` literals
  `&"player"` in hot code (no per-call allocation); real use:
  `.../godot-demo-projects/loading/serialization/save_load_json.gd:30,37`.
- `_enter_tree()` runs **top-down** (parent first); `_ready()` runs **bottom-up** (children first); `@onready`
  resolves at `_ready`. Never read `@onready` vars from `_enter_tree()`. `Node.is_node_ready()` tells you which
  side you are on.
- After `remove_child()` + `add_child()`, `_ready()` does **not** rerun unless you call `Node.request_ready()`
  first — and it affects that node only, not its children.

## 7. Signals: "call down, signal up"

The phrase is community shorthand; `best_practices/scene_organization.rst` states the same rule: *"Connect to a signal … should
be used only to 'respond' to behavior, not start it"* vs *"Call a method. Used to start behavior."*

- **Downward (parent → child): call a method.** The parent knows its children exist; that is a scene.
- **Upward and sideways: emit a signal.** The child must not know who listens. Siblings never talk directly — a
  common ancestor mediates.
- Signal names are **past-tense verbs**: `died`, `item_collected`, `combat_finished`. Naming one `do_thing`
  means it should have been a method call.

```gdscript
# child: health.gd
signal died
signal health_changed(current: int, maximum: int)

func take_damage(amount: int) -> void:
    current = maxi(0, current - amount)
    health_changed.emit(current, maximum)
    if current == 0: died.emit()

# parent: wires its own children, calls down, listens up
func _ready() -> void:
    %Health.died.connect(_on_died)
    %Health.health_changed.connect(%HealthBar.set_values)
```

| Need | API |
| --- | --- |
| Connect | `sig.connect(callable, flags := 0)` — `connect("name", self, "method")` is Godot 3 |
| Emit | `sig.emit(args…)` |
| One shot / deferred | `Object.CONNECT_ONE_SHOT = 4`, `CONNECT_DEFERRED = 1` |
| Extra / dropped args | `sig.connect(_on_x.bind(extra))`, `Callable.unbind(n)` |
| Wait | `await sig`, `await get_tree().process_frame` |
| Inspect | `sig.is_connected(cb)`, `sig.disconnect(cb)`, `sig.has_connections()` |

- Editor-made connections live in the `.tscn`; code-made ones do not. Pick one convention — mixed wiring is
  unsearchable. A declared-but-never-emitted signal warns; suppress deliberately with
  `@warning_ignore("unused_signal")` (every event bus does this).
- Connecting to a node you do not own means disconnecting when it leaves. Hook its `tree_exiting`:
  `.../godot-open-rpg/src/field/gamepieces/gamepiece_registry.gd:33` —
  `gamepiece.tree_exiting.connect(_on_gamepiece_tree_exiting.bind(gamepiece))`.

## 8. Autoloads: legitimate uses and the failure mode

An autoload is a node added under `/root` before the main scene; it survives `change_scene_to_file()` and is
**not** a true singleton — nothing stops a second instance (`scripting/singletons_autoload.rst`). The leading
`*` means enabled, exposing the name as a GDScript global; without it you need `get_node("/root/Name")`.
Autoloading a `.tscn` rather than a `.gd` lets the singleton own editor-configured children (audio players,
timers).

**Legitimate** when a system (1) owns all its own data, (2) genuinely must be globally reachable, and (3) exists
independently of any scene: scene loading/transitions, settings persistence, global save state, a signal bus
(§9), music that survives scene changes, a registry other systems query. Two real, small sets —
`.../Godot-Game-Template/project.godot:18-23`:

```ini
[autoload]
AppConfig="*res://addons/maaacks_game_template/base/nodes/autoloads/app_config/app_config.tscn"
SceneLoader="*res://addons/maaacks_game_template/base/nodes/autoloads/scene_loader/scene_loader.tscn"
ProjectMusicController="*res://addons/.../music_controller/project_music_controller.tscn"
ProjectUISoundController="*res://addons/.../ui_sound_controller/project_ui_sound_controller.tscn"
```

`.../godot-open-rpg/project.godot` `[autoload]`: `Camera`, `CombatEvents`, `FieldEvents`, `Gameboard`,
`GamepieceRegistry`, `Music`, `Player`, `Transition` — eight, each with exactly one job.

**The failure mode** (`best_practices/autoloads_versus_regular_nodes.rst`, walking through a global `Sound`
manager) names three costs: **global state** (one object owns everyone's data, one bug breaks every caller),
**global access** (anything calls it from anywhere, so the bug search space is the whole project — "when you
keep code inside a scene, only one or two scripts may be involved"), and **global resource allocation** (a fixed
pool is either too small or wasteful). Practical limits: **hard cap ≈ 10 autoloads**; an autoload must never
reach *into* other systems' data (a `GameManager` poking the inventory, the UI and the save file is the worst
structure in a Godot project); they initialise top-to-bottom, so one reading another must be listed below it —
better, no inter-autoload deps.

**Cheaper alternatives — try first:**

| Instead of an autoload | Use |
| --- | --- |
| Shared helper functions | `class_name Utils` + `static func` |
| Shared mutable value | `static var` on a `class_name` script — **since Godot 4.1** |
| Shared data | a custom `Resource`, `@export`ed where needed |
| Reaching the scene root | `Node.owner` |
| Finding the one player | `get_tree().get_first_node_in_group(&"player")` |

Static-only "singleton", no autoload entry:
`.../Godot-Game-Template/addons/maaacks_game_template/base/nodes/config/player_config.gd:1-32` — `class_name
PlayerConfig extends Object`, `static var config_file: ConfigFile`, and static `set_config`/`get_config` over
`user://player_config.cfg`.

## 9. Event-bus autoload vs direct wiring

An event bus is an autoload whose whole body is `signal` declarations; emitters and listeners never reference
each other. `.../godot-open-rpg/src/field/field_events.gd` (41 lines, all signals):

```gdscript
## A signal bus to connect distant scenes to various field-exclusive events.
extends Node

@warning_ignore("unused_signal")
signal cell_selected(cell: Vector2i)
@warning_ignore("unused_signal")
signal combat_triggered(arena: PackedScene)
```

plus `src/combat/combat_events.gd` (17 lines: `combat_initiated`, `combat_finished`, `player_battler_selected`).
Note: **two** buses split by domain, not one `Events` god-object.

| | Direct wiring | Event bus |
| --- | --- | --- |
| Both in the same scene / parent wires its children | **yes** | no |
| Sender does not know the receiver exists | no | **yes** |
| Receiver spawns later or lives in another scene | painful | **yes** |
| Cross-cutting state changes (pause, cutscene, combat start) | no | **yes** |
| "Who emitted this?" traceability | high | low — the real cost |

Rules: one bus **per domain**, named for it; **signals only**, no state, no methods; `##`-document every signal
(the bus is the project's event vocabulary); type every parameter; and when both sides are in the same scene,
wire locally instead.

## 10. Groups

Tags. Added in the Groups dock (Scene vs project-wide Global groups) or `Node.add_to_group(&"guards", persistent
:= false)`; convention is `snake_case` (`scripting/groups.rst`).

Verified API surface: `Node.add_to_group(group: StringName, persistent := false)`, `remove_from_group`,
`is_in_group`, `get_groups`; `SceneTree.get_nodes_in_group`, `get_first_node_in_group`,
`get_node_count_in_group`, `call_group(group, method, …)`, `call_group_flags(flags, …)` with
`GROUP_CALL_DEFAULT=0` / `REVERSE=1` / `DEFERRED=2` / `UNIQUE=4`, `notify_group`, `set_group`.

Use for "every enemy", "every persistable object", "the player", "everything that pauses". Do **not** use as a
message bus: `call_group` silently ignores nodes lacking the method or with a mismatched signature, so a typo
produces no error at all, and the reference warns it "acts immediately on all selected nodes at once, which may
cause stuttering". Group scans scale with group size and are not a spatial index — never call
`get_nodes_in_group()` every physics frame.

## 11. Folder layout

The manual (`best_practices/project_organization.rst`) recommends grouping assets **near the scenes that use
them**, `snake_case` files/folders, `PascalCase` node names, third-party code in top-level `addons/`. Shipped
projects often diverge and split code from content: `.../godot-open-rpg/` has `src/` (code + logic scenes by
domain: `src/field/`, `src/combat/`, `src/common/`), `assets/`, and authored content in `overworld/` +
`combat/`; `.../Godot-Game-Template/` splits `scenes/`, `scripts/`, `resources/`, `assets/`.

**Reasoning it out.** Per-feature colocation makes a feature deletable and movable in one operation and keeps
the FileSystem dock navigable at scale. A type-based split (`scripts/`, `scenes/`) is easier to start and harder
to maintain: one feature smears across four trees and nobody can tell what is dead. Recommendation:
**feature-first with a shared root for genuinely cross-cutting code**, i.e. what open-rpg does under `src/`:

```
res://
  src/            # code + scenes, grouped by feature
    core/         # save, config, scene loading, event buses — everyone depends on this
    ui/
    <feature>/    # e.g. src/player/: player.tscn, player.gd, states/, player.png
  assets/         # raw imported art/audio not owned by one feature addons/         # third-party ONLY tests/
```

Non-negotiable regardless of layout: `snake_case` everywhere (Windows/macOS are case-insensitive by default,
Linux is not, and the exported PCK is **case-sensitive** — `Player.tscn` referenced as `player.tscn` works on
the dev box and 404s on Steam Deck); `addons/` stays third-party only so it remains a clean "delete and
re-vendor" boundary; an empty `.gdignore` file stops Godot importing a folder (contents ignored, no patterns,
and `load()`/`preload()` then fail there); commit every `.gd.uid` alongside its `.gd` (4.4+, see the api-traps
guide §11).

## 12. State machines

Reference implementation in this repo:
`third_party/godot-demo-projects/2d/finite_state_machine/`.

`state_machine/state.gd` (28 lines) — the state interface, a plain `Node`:

```gdscript
extends Node

@warning_ignore("unused_signal")
signal finished(next_state_name: StringName)

func enter() -> void: pass
func exit() -> void: pass
func handle_input(_event: InputEvent) -> void: pass
func update(_delta: float) -> void: pass
```

`state_machine/state_machine.gd` (84 lines) — the machine:

- `@export var start_state: NodePath` (:13) — the initial state is data, not hardcoded.
- `_enter_tree()` (:24-37) connects every child's `finished` to `_change_state`, falling back to `get_child(0)`.
  The comment at :27-29 is the subtle bit: children have not entered the tree during the parent's
  `_enter_tree()`, so `get_child(0).get_path()` would be empty — it resolves the `Node` reference directly.
- `set_active()` (:47-52) calls `set_physics_process()` / `set_process_input()`, so a disabled machine costs
  nothing per frame; `_unhandled_input` / `_physics_process` (:55-60) delegate only to `current_state`.
- `states_stack` (:16, :75-84) gives push/pop, so `finished.emit(&"previous")` returns to the caller — a
  pushdown automaton, not a flat FSM.

`player/player_state_machine.gd` shows extension: `extends "res://state_machine/state_machine.gd"`, builds
`states_map` in `_ready()` (:11-18), overrides `_change_state` to push interruptible states, and calls
`super._change_state(state_name)` (:30). **4.x requires the explicit `super`** — lifecycle methods do not chain
implicitly.

Rules: states are **child nodes** of the machine, which is a child of the entity (composition, not a 400-line
`match`); states never know each other — a state emits `finished(next)`, the machine decides; inject the owner
reference rather than climbing `get_parent()`; key states with `StringName` (`&"idle"`). 4.7 alternatives:
`AnimationTree` + `AnimationNodeStateMachine` / `AnimationNodeStateMachinePlayback` for animation-driven states;
behaviour trees for AI (vendored `.../beehave/addons/beehave/`, `BeehaveTree`, `Blackboard`).

## 13. Scene transitions, loading, saving

### 13a. Transitions

| Method | Behaviour |
| --- | --- |
| `SceneTree.change_scene_to_file(path)` | loads + instantiates; `OK` / `ERR_CANT_OPEN` / `ERR_CANT_CREATE` |
| `SceneTree.change_scene_to_packed(packed)` | from an already-loaded `PackedScene`; pair with threaded loading |
| `SceneTree.change_scene_to_node(node)` | you built it; the tree takes ownership and will free it |
| `SceneTree.reload_current_scene()` / `unload_current_scene()` | re-instantiate / unload |

**Order of operations** (from `change_scene_to_node`, applying to all three): the outgoing scene is removed from
the tree *immediately* — from then on its `get_tree()` and `current_scene` are `null` — and only **at end of
frame** is it freed and the new scene added. To touch the new scene reliably, `await get_tree().scene_changed`.
Manual swap when you need ordering control (`.../godot-demo-projects/loading/autoload/global.gd:7-32`):

```gdscript
func goto_scene(path: String) -> void:
    _deferred_goto_scene.call_deferred(path)  # freeing a scene inside its own callback can crash

func _deferred_goto_scene(path: String) -> void:
    get_tree().current_scene.free()
    var scene := (ResourceLoader.load(path) as PackedScene).instantiate()
    get_tree().root.add_child(scene)
    get_tree().current_scene = scene   # only AFTER add_child
```

### 13b. Threaded loading

Threads are available on our targets. `load()` blocks the main thread; use `ResourceLoader` for anything bigger
than a bullet.

| Step | API |
| --- | --- |
| Request | `load_threaded_request(path, type_hint := "", use_sub_threads := false, cache_mode := 1)` |
| Poll | `load_threaded_get_status(path, progress: Array = [])` → `THREAD_LOAD_INVALID_RESOURCE=0`, `IN_PROGRESS=1`, `FAILED=2`, `LOADED=3` |
| Retrieve | `load_threaded_get(path)` — **blocks** if unfinished |
| Skip | `ResourceLoader.has_cached(path)` |

Poll from `_process`, not a loop (class-reference note). `progress` is an out-param: pass an empty `Array`, read
element 0 as a 0.0–1.0 ratio. Minimal demo:
`.../godot-demo-projects/loading/load_threaded/load_threaded.gd:4,15`. Production-shaped loading-screen
autoload: `.../Godot-Game-Template/addons/maaacks_game_template/base/nodes/autoloads/scene_loader/scene_loader.gd` — `load_scene()` (:94-108)
short-circuits on `has_cached()`, else fires `load_threaded_request()`, switches to a loading screen and
`set_process(true)`; `_process` (:118-127) matches on status and calls `change_scene_to_packed()` at
`THREAD_LOAD_LOADED`; `get_progress()` (:37-44) is the correct `progress_array` idiom.

### 13c. Save/load with versioned migrations

`user://` is a real directory on all our targets — `%APPDATA%\Godot\app_userdata\<project>` /
`~/.local/share/godot/app_userdata/<project>` by default; `OS.get_user_data_dir()` for the absolute path,
`ProjectSettings.globalize_path("user://")` to hand to `OS.shell_open` (`io/data_paths.rst`).

Format choice: **`ConfigFile`** (`set_value`/`get_value`/`save`/`load`) for settings and keybinds — it stores
most Variants including `Vector2`; **JSON** (`JSON.stringify`/`parse_string`, plus `from_native`/`to_native`)
for save games you want readable and diffable; **`Resource` `.tres`** (`ResourceSaver.save` /
`ResourceLoader.load`) for state that mirrors your `Resource` classes; **binary Variant**
(`FileAccess.store_var`/`get_var`) for large or hot save data.

- Plain JSON cannot represent `Vector2`, `Vector3`, `Color`, `Rect2`, `Quaternion`, and turns ints into doubles.
  Two fixes, both in-repo: per-field `var_to_str`/`str_to_var`
  (`.../godot-demo-projects/loading/serialization/save_load_json.gd:23,25,49,51`), or the engine round-trip
  `JSON.stringify(JSON.from_native(v))` / `JSON.to_native(JSON.parse_string(s))`.
- **Never** `FileAccess.get_var(true)` or `JSON.to_native(x, true)` on a save file. The class reference:
  *"Deserialized objects can contain code which gets executed … untrusted sources … remote code execution."*
  Steam Cloud syncs saves across machines and players edit them — every save is untrusted. `ConfigFile` has the
  same hazard (`.../godot-demo-projects/loading/serialization/save_load_config_file.gd:2-5`). `store_var` writes only
  `PROPERTY_USAGE_STORAGE` properties — in GDScript, `@export` / `@export_storage`.

Version first, refuse the future, migrate the past, never write in place:

```gdscript
class_name SaveFile extends RefCounted

const PATH := "user://save_0.json"
const TMP := PATH + ".tmp"
const BAK := PATH + ".bak"
const VERSION := 3   # bump on every breaking payload change

static func save(payload: Dictionary) -> Error:
    var doc := {"version": VERSION, "saved_at": int(Time.get_unix_time_from_system()),
        "app": ProjectSettings.get_setting("application/config/version", ""),
        "data": JSON.from_native(payload)}
    var f := FileAccess.open(TMP, FileAccess.WRITE)
    if f == null:
        push_error("save: cannot open temp: %d" % FileAccess.get_open_error())
        return ERR_FILE_CANT_OPEN
    f.store_string(JSON.stringify(doc, "\t"))
    f.flush()                                          # push the buffer out first
    f.close()
    if FileAccess.file_exists(PATH):
        DirAccess.rename_absolute(PATH, BAK)           # keep one generation
    var err := DirAccess.rename_absolute(TMP, PATH)    # rename overwrites the destination
    if err != OK: push_error("save: rename failed: %d" % err)
    return err

static func load_from(path: String = PATH) -> Dictionary:
    if not FileAccess.file_exists(path): return {}
    var doc: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))  # null on failure
    if doc == null or typeof(doc) != TYPE_DICTIONARY or not doc.has("version"):
        push_error("save: corrupt file at %s" % path)
        return load_from(BAK) if path != BAK else {}   # one retry, backup only
    var v := int(doc.version)
    if v > VERSION:                                    # forward-version refusal: do NOT guess
        push_error("save: version %d newer than supported %d" % [v, VERSION])
        return {}
    var data: Dictionary = JSON.to_native(doc.get("data", {}))
    while v < VERSION:
        data = _migrate(data, v)                       # each step only knows n -> n+1
        v += 1
    return data
```

- **Atomic rename**: a crash mid-write leaves a half file. Write `*.tmp`, rename over the target —
  `DirAccess.rename` is documented to overwrite an existing, non-access-protected destination. This buys
  crash-atomicity, **not** durability: 4.7 exposes `FileAccess.flush()` but no `fsync`. **One backup
  generation** turns "save corrupted, run lost" into "lost five minutes".
- **Forward-version refusal**: a beta-branch player or a Steam Cloud sync from a newer build hands you a file
  from the future; loading it half-understood silently deletes progress. Refuse and say so.
- **Version in the file, migrations chained one step at a time** — each `_migrate` step only knows `n` → `n+1`,
  so old steps are never rewritten. Keep the on-disk shape plain `Dictionary` data, not live objects, or every
  refactor becomes a migration.
- In-repo precedent for `Resource` saves with version stamping:
  `.../Godot-Game-Template/addons/maaacks_game_template/base/nodes/state/global_state.gd:4-37` records
  `first_version_opened`/`last_version_opened` from `application/config/version` and persists via
  `ResourceSaver.save`. It has **no** atomic write and no version refusal — take the versioning idea, not the
  write path.
- The manual's group approach (`io/saving_games.rst`) — tag persistables into a `Persist` group, ask each for a
  dict, reinstantiate from `Node.scene_file_path` — is fine for level state, but explicitly does not handle
  nested persistables; load parents first.

## 14. Dependency direction and headless testability

**Dependencies point inward and downward.** Rules and simulation know nothing about nodes; nodes know about
rules; UI knows about both; nothing knows about UI.

`UI ──▶ gameplay nodes ──▶ rules & data (RefCounted / Resource)`, with every arrow back up the chain being a
signal. Damage formulas, inventory rules, progression curves, pathfinding cost and the save schema go in
`RefCounted`/`Resource` with no `get_tree()`, no `get_node()`, no `_process`. Nodes are a thin shell: read
input, call the rules object, render, emit signals. If a class calls `get_tree()`, it cannot be unit-tested
without a tree — that is the tell.

`--headless` (= `--display-driver headless --audio-driver Dummy`) runs with no window and no audio device, which
is what CI has. `-s`/`--script <res:// path>` runs a script — but the reference legend marks `--script`
**editor-builds only** (or templates built with `disable_path_overrides=false`), so CI must use the editor
binary (`editor/command_line_tutorial.rst:119,234`). Vendored working example: gdUnit4 6.1.3 at
`.../beehave/addons/gdUnit4/`, whose runner (`runtest.sh:58`) is `"$godot_binary" --path . -s -d --remote-debug
tcp://127.0.0.1:0 res://addons/gdUnit4/bin/GdUnitCmdTool.gd` — port 0 is deliberate, never bound, so Godot's
interactive `debug>` prompt cannot hang CI on a parse error; the log-copy pass at `:63` adds `--headless`. A
test of a pure logic object, no tree involved (`.../beehave/test/blackboard/blackboard_test.gd:11-14`):

```gdscript
func test_has_value() -> void:
    var blackboard = auto_free(load(__source).new())
    blackboard.set_value("my-key", 123)
    assert_bool(blackboard.has_value("my-key")).is_true()
```

Making autoloads testable: keep the autoload a thin facade over a plain `RefCounted` holding the logic and test
the inner object. `Engine.register_singleton(name, instance)` / `unregister_singleton` / `has_singleton` let a
test install a stub — but these are **engine** singletons, a different namespace from the `[autoload]` list; an
autoload lives at `/root/<Name>`, so a test can also replace that child directly. `Engine.is_editor_hint()`
guards editor-only work in `@tool` scripts (`battler.gd:148`); it is **not** a test guard.

Self-documenting dependencies: implement `Node._get_configuration_warnings() -> PackedStringArray` when a node
requires external configuration. A non-empty return puts a warning triangle on the node in the Scene dock, so
the editor documents the requirement instead of a wiki page that goes stale
(`.../beehave/addons/beehave/nodes/beehave_tree.gd:217-229`); `SceneTree` emits
`node_configuration_warning_changed` when one changes.

## 15. Review checklist — grep these

| Pattern | Problem |
| --- | --- |
| `get_node("../..`, `$"../..` | reaches out of the scene; breaks on any rearrangement |
| `find_child(` | documented as slow; walks every descendant; ambiguous |
| `\.instance\(\)` | Godot 3. It is `PackedScene.instantiate()` |
| `connect\("` with 3+ args | Godot 3 signal API |
| >10 entries under `[autoload]` | global-state soup |
| autoload named `GameManager`, `Global`, `Main`, `Events` | almost always owns other systems' data |
| `@export var x: SomeResource` with no `duplicate()` in `_ready` | shared mutable resource across instances |
| `FileAccess.get_var(` with `true`; `JSON.to_native(.*true` | arbitrary code execution from a save file |
| write to `user://save…` with no temp+rename | non-atomic save; a crash corrupts it |
| save reader with no `version` check | no migration path, no forward-version refusal |
| `get_tree()` inside a rules/formula class | not headlessly testable |
| `func _ready():` in a subclass with no `super()` | 4.x does not chain lifecycle calls |
| `.gd` committed without its `.gd.uid` | breaks references (4.4+) |

## 16. Not verified

- **No dedicated "scene inheritance" page exists in the vendored 4.7 manual.** §5 is assembled from
  `PackedScene.GEN_EDIT_STATE_MAIN_INHERITED`, `Node.set_editable_instance()` and
  `best_practices/scenes_versus_scripts.rst`; the "New Inherited Scene" editor workflow is inferred from those
  constants, not read from a manual page.
- **`fsync`.** No API in the 4.7.1 reference forces an OS-level disk barrier; `FileAccess.flush()` only writes
  the buffer. Temp-write + rename gives crash-atomicity, not durability.
- **Introduction versions** for `SceneTree.unload_current_scene`, `SceneTree.get_node_count_in_group` and
  `Object.cancel_free`: present in 4.7.1, but the reference has no "since" markers and the migration pages do
  not mention them — do not claim a version.
- **`Resource.resource_local_to_scene`** appears nowhere in the vendored `tutorials/` tree; §4's description
  comes from the class reference alone. **Autoload init order relative to the main scene** is stated only as
  "added to the root viewport before any other scenes are loaded" (`scripting/singletons_autoload.rst`); the
  interleaving with `@onready` was not verified.
