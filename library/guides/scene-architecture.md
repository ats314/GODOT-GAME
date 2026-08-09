# Scene and code architecture that survives contact with a real game

How to lay out nodes, scenes, resources, scripts and folders in a Godot **4.7.1** project so
that month three does not become a rewrite. Read this before creating a new system, adding an
autoload, or deciding whether a thing should be a `Node`, a `Resource`, or a plain object.
Genre-neutral: nothing here assumes 2D or 3D.

Every class, method, property, signal and constant in backticks was checked against
`third_party/godot-class-reference/classes/*.xml` (engine tag `4.7.1-stable`). Prose sources,
all vendored: `third_party/godot-docs/tutorials/best_practices/*.rst`,
`tutorials/scripting/{scene_unique_nodes,groups,singletons_autoload,resources,change_scenes_manually,instancing_with_signals,nodes_and_scene_instances,pausing_games}.rst`,
`tutorials/io/{saving_games,background_loading,data_paths}.rst`.
Companion guides: `library/guides/gdscript-style-and-typing.md`, `library/guides/api-changes-and-traps.md`.

---

## 1. `Node` vs `Resource` vs `RefCounted` vs `Object` — the decision rule

Source: `best_practices/node_alternatives.rst`, `best_practices/what_are_godot_classes.rst`.

| You need… | Use | Memory | Inspector | Serializes |
| --- | --- | --- | --- | --- |
| Something in the tree that ticks, draws, collides, receives input | `Node` (subclass) | tree-owned; `queue_free()` | yes, as a node | via `PackedScene` |
| A data container edited in the Inspector and saved as `.tres` | `Resource` | refcounted | **yes** | `.tres` / `.res` natively |
| A plain helper/value object used only from code | `RefCounted` | refcounted, auto-freed | no | no |
| A hand-managed internal structure (rare) | `Object` | **manual `free()`** | no | no |

Decision rule, in order:

1. Does it need `_process`, `_physics_process`, `_input`, `_draw`, or a transform? → `Node`.
2. Does a designer need to author variants of it in the Inspector, or does it need to be saved
   to disk as authored data? → `Resource` with `class_name`.
3. Otherwise → `RefCounted` (this is the default for "a class"). A GDScript file with no
   `extends` implicitly extends `RefCounted` (`what_are_godot_classes.rst`), so it can be
   `.new()`-ed but **cannot** be attached to a node.
4. `Object` only when you deliberately want manual lifetime. The manual's own example is
   `TreeItem` under `Tree`. References to a raw `Object` can go stale without warning; guard
   with `is_instance_valid()`.

Nodes are cheap but not free. `node_alternatives.rst`: "A project may have tens of thousands of
nodes… The more complex their behavior, the larger the strain each one adds." One `Node` per
particle / inventory slot / grid cell is the signal to drop to `Resource`/`RefCounted` plus one
node that renders them.

Scripts are not classes. A `.gd` file is a `Resource` that tells the engine a sequence of
initializations to perform on a built-in class; `ClassDB` answers "does this object have that
method" (`what_are_godot_classes.rst`).

## 2. Composition over inheritance in the node tree

A scene *is* the composition. `what_are_godot_classes.rst`: "The scene is always an extension of
the script attached to its root node." Children are the parts; the root script is the behaviour.

Prefer adding a child node with one job over deepening a script inheritance chain:

```gdscript
# GOOD: Actor.tscn — root script is thin, capabilities are children.
#   Actor (Node2D, actor.gd)
#     Health          (health.gd — signal died, damaged(amount))
#     Hurtbox         (Area2D)
#     StateMachine    (state_machine.gd, with State children)
#     Visuals         (AnimatedSprite2D)
```

The vendored FSM demo does exactly this split:
`third_party/godot-demo-projects/2d/finite_state_machine/player/player_controller.gd` is a
`CharacterBody2D` that owns `$Health` and `$States/Stagger` and knows nothing about *how* states
work — "the body and the state machine are separate" (its own comment).

Godot's tree is aggregation, not composition (`scene_organization.rst`, final paragraph: "Does
this mean nodes themselves are components? Not at all"), so do not build a strict ECS out of
nodes. Use children as *capabilities* the root delegates to. Inheritance stays correct for
**is-a** relations with a shared interface (`State` → `PlayerState` → `Idle`); mark the base
`@abstract` (added **4.5**) so it cannot be instantiated by mistake.

**Structural rule from `scene_organization.rst`:** "Does removing the parent reasonably mean that
the children should also be removed? If not, then it should have its own place in the hierarchy
as a sibling." Spatially-coupled but lifetime-independent nodes are what `RemoteTransform2D` /
`RemoteTransform3D` exist for.

## 3. Dependency direction: "call down, signal up"

The community shorthand is *call down, signal up*. **That exact phrase does not appear in the
vendored manual** — I checked all 517 pages. The manual states the same rule as two bullets in
`scene_organization.rst`:

> 1. Connect to a signal. Extremely safe, but should be used only to "respond" to behavior, not
>    start it. By convention, signal names are usually past-tense verbs…
> 2. Call a method. Used to start behavior.

Combine with its headline rule — "If at all possible, you should design scenes to have no
dependencies… If a scene must interact with an external context, use Dependency Injection" —
and you get the practical law:

| Direction | Mechanism | Why |
| --- | --- | --- |
| Parent → child | direct call, `$Child.do()`, exported reference | parent owns child; the path is stable inside the scene |
| Child → parent/world | `signal`, emitted past-tense | child stays reusable; it never names its environment |
| Sibling ↔ sibling | mediated by a common ancestor | "Nodes which are siblings should only be aware of their own hierarchies while an ancestor mediates" |
| Anything → a global system | autoload, sparingly (§6) | last resort, not first |

`get_parent()` in a child script is the smell. `instancing_with_signals.rst` opens with it:
"One sign that a signal might be called for is when you find yourself using `get_parent()`."

The five injection forms the manual sanctions (`scene_organization.rst`): connect a signal; call
a method; set a `Callable` property; set a `Node`/`Object` reference; set a `NodePath`. A
`Callable` property is safer than a method-name string — ownership of the method is unnecessary.

Worked example in this repo: `game/scripts/run.gd:236-241` injects everything the spawner needs
rather than letting it search the tree.

```gdscript
spawner = Spawner.new()
spawner.core = core
spawner.shard_field = shard_field
spawner.enemies_parent = enemies_parent
spawner.camera = camera
```

`game/scripts/spawner.gd` correspondingly declares `var core: Core` etc. and calls no
`get_parent()`, no `get_node("../..")`. That node can be re-hosted anywhere.

Self-document injected dependencies with `_get_configuration_warnings()` on a `@tool` script:
returning a non-empty `PackedStringArray` puts a warning triangle in the Scene dock, replacing
prose documentation. Call `update_configuration_warnings()` when the condition changes.

## 4. Signals: the mechanics worth knowing

```gdscript
signal health_changed(old: int, new: int)   # past tense, typed params

health_changed.connect(_on_health_changed)               # 4.x Callable syntax
health_changed.connect(_on_x, CONNECT_ONE_SHOT)          # auto-disconnects after one emit
health_changed.emit(old, health)
if health_changed.is_connected(_on_x): health_changed.disconnect(_on_x)
```

`connect("sig", self, "method")` is the Godot 3 form and **does not exist** in 4.x.

| Flag (`Object.ConnectFlags`) | Effect |
| --- | --- |
| `CONNECT_DEFERRED` | callback runs at idle time, not inside the emit — use when the callback mutates the tree |
| `CONNECT_ONE_SHOT` | disconnects itself after the first emission |
| `CONNECT_PERSIST` | connection is serialized into the `PackedScene` (what the editor uses) |
| `CONNECT_REFERENCE_COUNTED` | duplicate connects are counted instead of erroring |
| `CONNECT_APPEND_SOURCE_OBJECT` | appends the emitter as a trailing argument |

Practical rules:

- Connecting a lambda makes the connection un-`disconnect`-able by name. `game/scripts/hud.gd:60-67`
  does this; fine there because the HUD outlives every emitter, a hazard on short-lived nodes.
- The connection dies with the receiver, so you need no `_exit_tree()` disconnect merely to avoid
  dangling — only when the receiver outlives the emitter and should stop reacting.
- Type signal parameters. They document the contract and are checked at emit time.
- Do not use a signal to *start* behaviour you own. `spawner.start()` is a call, not an emit.

## 5. Groups

`Node.add_to_group(group: StringName, persistent: bool = false)` — with `persistent = true` the
membership is stored in the `PackedScene`; the editor's Groups dock always writes persistent
groups. `SceneTree` side: `get_nodes_in_group()`, `get_first_node_in_group()`,
`get_node_count_in_group()`, `has_group()`, `call_group()`, `call_group_flags()`,
`notify_group()`, `set_group()`.

Three facts from `Node.xml` that bite:

1. **Order is not guaranteed** — "the order of group names is *not* guaranteed and may vary
   between project runs. Therefore, do not rely on the group order." Never index
   `get_nodes_in_group()[0]` and expect stability; `get_first_node_in_group()` returns in *scene
   hierarchy* order, which is the only ordering you may rely on.
2. Group methods **do not work on a node outside the tree** (`is_inside_tree()`).
3. `get_nodes_in_group()` allocates an array each call. In `_process` over a large group this
   shows up. `game/scripts/turret.gd:34` and `core.gd:59` both scan `&"enemies"` every frame —
   acceptable at this scale, the first thing to cache if enemy counts grow.

Use `&"snake_case"` `StringName` literals for group names (`groups.rst` recommends snake_case;
the repo uses `StringName` consistently). Groups are right when the set is dynamic and
cross-scene (all enemies, all save-persistent nodes) and wrong for "the one HUD" — that is a
scene-unique node or an injected reference.

## 6. Autoloads: what they are legitimately for, and the failure mode

An autoload is a node added under `SceneTree.root` before the main scene, surviving
`change_scene_to_file()`. It is **not** a true singleton — `singletons_autoload.rst`: "Nothing
prevents you from instantiating copies of an autoloaded node." Access is by the name in
**Project → Project Settings → Globals → Autoload**, or `get_node("/root/Sound")`.

> **Hard rule from the manual:** "Autoloads must **not** be removed using `free()` or
> `queue_free()` at runtime, or the engine will crash."

`autoloads_versus_regular_nodes.rst` gives the three failure modes of the "manager singleton"
habit — global **state** (one object owns everyone's data), global **access** (a bug's search
domain becomes the whole project), global **resource allocation** (a fixed pool is either too
small or wasteful). Its verdict on when an autoload is right:

> "If the autoload is managing its own information and not invading the data of other objects,
> then it's a great way to create systems that handle broad-scoped tasks."

Alternatives to reach for first: a `class_name` node type for shared *behaviour*; a custom
`Resource` for shared *data*; `static func` / `static var` (static variables added in **4.1**)
for stateless helpers; the `owner` property to reach a scene root without a global.

### 6.1 Worked example — this repo's four autoloads

`game/project.godot` registers `Events`, `GameState`, `Sfx`, `Vfx`. Read them at
`game/scripts/`. They are a useful spread of good and bad.

| Autoload | File | Verdict |
| --- | --- | --- |
| `Events` | `events.gd` (12 lines) | **Good.** Pure signal bus: nine `signal` declarations, zero state, zero methods. Nothing to corrupt. |
| `Vfx` | `vfx.gd` (48 lines) | **Good.** Connects to `Events` in `_ready()` and spawns `CPUParticles2D` into `get_tree().current_scene`. Nothing calls it; deleting it removes juice and breaks nothing. This is the "system with a wide scope managing its own information" the manual endorses. |
| `Sfx` | `sfx.gd` (95 lines) | **Textbook of the manual's own cutting-audio example — accepted deliberately.** It is exactly the `Sound.play("…")` pool the manual warns about, including the fixed `POOL := 10`: request 11 overlapping sounds and the 11th is silently dropped (`play()` returns after the loop finds no free player). Justified here because SFX are procedurally synthesized once at startup and every caller wants the same six sounds. If sounds become per-scene assets, move `AudioStreamPlayer` nodes into the scenes that own them. |
| `GameState` | `game_state.gd` (99 lines) | **The one to watch.** It holds run economy *and* upgrade modifiers *and* persistent records *and* the save file *and* a static string formatter. Eight of the fourteen scripts read `GameState.mods.*` directly — `core.gd`, `turret.gd`, `enemy.gd`, `hud.gd`, `run.gd`, `spawner.gd`, `main_menu.gd`, `game_over.gd`. |

The `GameState` failure mode is concrete and worth internalising, because it is what "month
three" looks like:

- `mods` is an untyped `Dictionary` built from `DEFAULT_MODS.duplicate()` (`game_state.gd:44`).
  `GameState.mods.beam_widht` is a runtime `nil`, not a parse error. A typed custom `Resource`
  (§7) would have failed at parse time.
- Balance data lives in GDScript constants, so no one can tune it without editing code and
  nobody can ship two difficulty presets.
- Because every system reads the global, none of them can be exercised without booting the
  whole autoload set. `Turret` cannot be unit-tested with a fake stat block.
- `duplicate()` on `DEFAULT_MODS` is a **shallow** copy. It happens to be safe because every
  value is a `float`/`int`; add one nested `Dictionary` or `Array` and every run mutates the
  shared default.

The refactor, when this project grows: `GameState` keeps run lifecycle and emits through
`Events`; `mods` becomes an `@export`ed `RunModifiers` resource injected into `Run`; saving
moves to a `SaveData` resource (§9).

**Autoload budget.** A useful rule of thumb, not from the manual: if an autoload has *callers*
rather than *listeners*, every new caller widens the blast radius. Autoloads with only listeners
(`Events`, `Vfx`) scale; autoloads with many callers (`GameState`) become the file everyone
edits and nobody understands.

## 7. Event-bus autoload versus direct signal wiring

An event bus is an autoload whose entire body is `signal` declarations. Emitters call
`Events.thing_happened.emit(...)`; listeners call `Events.thing_happened.connect(...)`.

Vendored examples: `game/scripts/events.gd` (this repo),
`third_party/godot-open-rpg/src/field/field_events.gd` and `src/combat/combat_events.gd` (a
larger project doing the same, with `@warning_ignore("unused_signal")` on each declaration —
copy that, or the parser warns about signals never emitted from within the bus script itself).

| | Direct signal wiring | Event bus autoload |
| --- | --- | --- |
| Coupling | emitter and listener must be reachable from a common ancestor | none; either side can be anywhere |
| Discoverability | `Ctrl+F` the emitter finds every listener | you must grep the whole project for the signal name |
| Lifetime | connection dies with either party | listeners must survive, or reconnect on scene load |
| Editor support | connections visible in the Node dock | invisible; code-only |
| Verdict | **default** | for genuinely global, cross-scene facts |

Rules that keep a bus from rotting:

- Bus signals describe **facts that happened**, past tense, never commands. `enemy_killed`, not
  `kill_enemy`.
- The bus must contain no state and no methods. `events.gd` in this repo is correct: 12 lines,
  all signals.
- If both parties are in the same scene, wire them directly. Routing a parent↔child message
  through a global is how you lose the ability to reason about a scene in isolation.
- Beware ordering: multiple listeners on one bus signal fire in connection order, which depends
  on autoload order and scene construction order. If order matters, you have a design problem —
  make one listener the coordinator.

`game/scripts/run.gd:190-193` connects four `Events` signals and is also the node that *causes*
most of them, which is a mild smell — a coordinator both emitting into and listening to a global
bus is round-tripping messages it could have handled directly.

## 8. Node paths, `%` unique names, and `get_node` fragility

`get_node("Foo/Bar/Baz")` encodes tree structure in a string. Move `Baz` in the Scene dock and
the script silently starts returning `null`, and `get_node` "generates an error and returns
`null`" — the crash surfaces later as *"Attempt to call \<method\> on a null instance."*

Ranked from best to worst (`best_practices/godot_interfaces.rst`, `scene_unique_nodes.rst`):

| Form | When |
| --- | --- |
| `@export var target: Node` | best when a designer or a parent should choose the target; survives any move |
| `@onready var hp := %HealthBar as ProgressBar` | best inside one scene; `%` follows the node when it moves |
| `@onready var child := $Child` | fine for a direct child you own |
| `get_node("A/B/C")` in `_process` | worst: re-resolves the path every frame *and* is structurally brittle |
| `find_child("Name")` | **slow** — checks every descendant, every call. Manual's word, not mine |

`%Name` requires `Node.unique_name_in_owner = true` (Scene dock → *Access as Unique Name*, or
prefix the name with `%` while renaming). Two limits from `Node.xml` and `scene_unique_nodes.rst`:

1. Resolution is scoped to the **same `owner`** — i.e. the same scene file. A `%Hilt` marked
   inside `Sword.tscn` returns `null` from `Player.tscn`'s script. Cross the boundary explicitly:
   `get_node("Hand/Sword/%Hilt")`.
2. If two nodes with the same `owner` share a name, "the other node will no longer be accessible
   as unique."

Unique names *can* appear mid-path: `get_node("%Sword/%Hilt")` is valid.

Cache lookups in `@onready` or `_ready()`; never resolve a path in `_process`.

## 9. `class_name`, and when to register

`class_name Foo` makes the type global: it appears in the Create-Node/Create-Resource dialogs,
is usable as a type hint, and its constants and `static func`s are reachable without loading the
script (`scenes_versus_scripts.rst`). Register when:

- The type is instantiated from other scripts (`Enemy.make(...)` in `game/scripts/enemy.gd:223`
  requires it).
- It is a custom `Resource` you want in the Inspector's create dialog — the manual is explicit:
  "To make the new resource class appear in the Create Resource GUI you need to provide a class
  name."
- It is used as a type annotation or in an `is` check.

Do **not** register one-off scripts attached to a single scene root; you are polluting a global
namespace with `Hud`, `Menu`, `Level`. `scenes_versus_scripts.rst` closes with the alternative —
a `class_name` on a `RefCounted` acting as a namespace holding `const MyScene = preload(...)`.

Two gotchas: `@icon("res://…svg")` above `class_name` sets the dialog/dock icon; and the editor
**hides** `class_name` types beginning with `Editor` from creation dialogs (they still work at
runtime).

## 10. Scene instancing and scene inheritance

```gdscript
const EnemyScene := preload("res://actors/enemy/enemy.tscn")   # PascalCase for a scene const
var e := EnemyScene.instantiate()
e.position = spawn_point            # set properties BEFORE add_child — see below
parent.add_child(e)
```

`logic_preferences.rst` is unambiguous: "it is usually best practice to set the initial values of
a node before adding it to the scene tree. Some properties' setters have code to update other
corresponding values, and that code can be slow." The exception is anything global-transform
based, which needs a parent first.

`preload` vs `load`: `preload` is compile-time and requires a constant path, so it front-loads
the cost and gives you autocompletion; `load` is a runtime alias for `ResourceLoader.load()`.
`logic_preferences.rst` warns against `@export var scn: PackedScene = preload(...)` — the scene
instantiation overwrites the preloaded default anyway, "It's usually better to provide `null`,
empty, or otherwise invalid default values for exports."

Loading a resource returns the **cached** instance. To get an independent copy you must
`duplicate()` it or `new()` one (`godot_interfaces.rst`).

**Scene inheritance.** The vendored 4.7 manual has no dedicated page on inherited scenes — I
could not find one, and I am not going to invent its guidance. What the class reference does
confirm:

- `PackedScene.instantiate(edit_state)` takes `GEN_EDIT_STATE_DISABLED` (default, runtime),
  `GEN_EDIT_STATE_INSTANCE`, `GEN_EDIT_STATE_MAIN`, `GEN_EDIT_STATE_MAIN_INHERITED`.
  `scenes_versus_scripts.rst` shows `MyScene.instantiate(PackedScene.GEN_EDIT_STATE_MAIN)` with
  the comment "Create scene inheriting from MyScene."
- `SceneState.get_base_scene_state()` exists, so an inherited scene's base is introspectable at
  runtime via `PackedScene.get_state()`.
- `InstancePlaceholder` plus `Node.set_scene_instance_load_placeholder(true)` lets a `.tscn`
  reference a sub-scene without loading it until `InstancePlaceholder.create_instance()` is
  called. Useful for large optional content.

Practical guidance (mine, flagged as such): inherited scenes give you one editable base with
per-variant overrides, which is genuinely good for UI panels and enemy variants. They are also
the single most fragile refactoring surface in Godot — renaming or reparenting a node in the
base silently drops the override in every derived scene. Prefer a data-driven variant
(one scene + a `Resource` per variant, §11) whenever the variants differ only in *values*.
Reserve scene inheritance for variants that differ in *structure*.

## 11. Custom `Resource` as the data container (data-driven design)

This is the highest-leverage pattern in the engine and the one models under-use. From
`scripting/resources.rst`, a custom `Resource` beats JSON/CSV/`Dictionary` because it can define
constants, methods, setters, and **signals**; its properties are guaranteed to exist; it
serializes and deserializes for free; sub-resources nest recursively; `.tres` is
version-control-friendly text; and the Inspector edits it with zero extra code. The manual's own
comparison: "Resource scripts are similar to Unity's ScriptableObjects."

```gdscript
class_name EnemyStats
extends Resource

@export var display_name: String = "Grunt"
@export_range(1, 999) var max_health: int = 20
@export_range(0.0, 400.0) var speed: float = 90.0
@export var loot: Array[LootEntry] = []          # nested custom Resources
@export var death_sound: AudioStream
```

```gdscript
class_name Enemy
extends Node2D

@export var stats: EnemyStats                     # drag a .tres in the Inspector
var _health: int

func _ready() -> void:
    assert(stats != null, "Enemy requires stats")
    _health = stats.max_health
```

Rules and traps:

- **Give every `@export` a default.** The manual: "Make sure that every parameter has a default
  value. Otherwise, there will be problems with creating and editing your resource via the
  inspector."
- **Inner classes cannot back a `.tres`.** A `.tres` stores the *path* of its script; a `class`
  declared inside another script is not addressable, and its properties will not serialize.
  Every custom Resource needs its own file with `class_name`.
- **Loaded resources are shared.** Two enemies with the same `stats.tres` hold the *same object*.
  Mutating `stats.max_health` at runtime changes it for every enemy and, in the editor, can write
  back to disk. Either treat exported resources as immutable and keep mutable state on the node
  (as above), or `stats = stats.duplicate()` in `_ready()`.
- **`duplicate(true)` semantics changed in 4.5.** It now deep-duplicates only resources
  *internal* to the file; in 4.4 it duplicated external references too. To get the old behaviour
  call `Resource.duplicate_deep(Resource.DEEP_DUPLICATE_ALL)`
  (`migrating/upgrading_to_godot_4.5.rst`).
- `resource_local_to_scene = true` makes each scene instance get its own copy, with
  `_setup_local_to_scene()` called on it. This is the declarative fix for shared-mutable-state.
- Resources emit `changed`. Call `emit_changed()` from setters so UI can react without polling —
  see `third_party/godot-demo-projects/audio/rhythm_game/game_state/play_stats.gd`, which does
  exactly that on every field.

Vendored examples to copy from: `third_party/Starter-Kit-FPS/scripts/weapon.gd` (a `Weapon`
resource carrying model, cooldown, damage, spread, crosshair — the whole weapon is data),
`third_party/Starter-Kit-City-Builder/scripts/structure.gd`,
`third_party/godot-demo-projects/3d/voxel/world/terrain_generator.gd`.

## 12. State machines

Read `third_party/godot-demo-projects/2d/finite_state_machine/` end to end; it is the reference
implementation and it is hierarchical plus pushdown, which most tutorials are not.

Shape (`state_machine/state.gd`, `state_machine/state_machine.gd`):

```gdscript
# state.gd — the interface. Every state is a Node child of the machine.
extends Node
signal finished(next_state_name: StringName)
func enter() -> void: pass
func exit() -> void: pass
func handle_input(_e: InputEvent) -> void: pass
func update(_delta: float) -> void: pass
```

The machine (`state_machine.gd`) keeps `states_map`, a `states_stack`, and `current_state`;
connects every child's `finished` signal to `_change_state` in `_enter_tree()`; forwards
`_unhandled_input` and `_physics_process` to the current state; and toggles
`set_physics_process()` / `set_process_input()` when deactivated. `_change_state("previous")`
pops the stack — that is the pushdown automaton, used for jump/stagger/attack in
`player/player_state_machine.gd:25-27`.

Why this design and not a `match` on an enum:

- Each state is one file with one responsibility; the FileSystem dock becomes the documentation
  of what the actor can do (the demo's README makes exactly this argument).
- States are `Node`s, so they can hold `@export`ed tuning and their own `Timer` children.
- Transitions are signals, so a state never names its successor's implementation.

Two details worth stealing: the machine resolves its initial state in `_enter_tree()` and
comments *why* it uses `get_child(0)` rather than `get_path()` ("Children have not entered the
tree yet during their parent's `_enter_tree()`"); and states reach shared nodes through `owner`
(`owner.get_node(^"AnimationPlayer")` in `states/motion/on_ground/idle.gd`), which is the manual's
sanctioned alternative to a global (`autoloads_versus_regular_nodes.rst`: "Store the data in an
object to which each node has access, for example using the `owner` property").

Costs, stated honestly: one `Node` per state is heavier than an enum, and node-per-state
machines are awkward when many actors share one machine. For hundreds of simple agents, a
`RefCounted` state object or a plain enum + `match` is the right call.

## 13. Save/load architecture and versioned save data

Three storage mechanisms, all in the class reference:

| Mechanism | Use for | Notes |
| --- | --- | --- |
| `ConfigFile` | settings, key rebinds, small records | INI-like text; stores any Variant **except** `Signal`/`Callable`; `set_value`/`get_value(section, key, default)` |
| `FileAccess.store_var()` / `get_var()` | game state, compactly | binary; handles `Vector2`, `Color`, etc. natively |
| `JSON.stringify()` / `JSON.parse()` | debuggable / interchange saves | **cannot** represent `Vector2`, `Vector3`, `Color`, `Rect2`, `Quaternion`; larger files |

`io/saving_games.rst` documents the group-based approach: mark savable nodes into a `Persist`
group, have each expose `save() -> Dictionary`, iterate `get_tree().get_nodes_in_group("Persist")`,
skip nodes whose `scene_file_path` is empty (they cannot be re-instantiated), and store
`scene_file_path` + parent path so load can rebuild them. Its own caveats: nested Persist objects
break the recorded `NodePath`s, so load parents in a first pass; and reverting existing state
before loading "will vary wildly depending on the needs of a project."

Vendored working code: `third_party/godot-demo-projects/loading/serialization/` has
`save_load_config_file.gd` and `save_load_json.gd` side by side over the same game.

**Security.** From that demo's own comment: `ConfigFile` "can even store Objects, but be extra
careful where you deserialize them from, because they can include (potentially malicious)
scripts." Both `FileAccess.get_var(allow_objects)` and `JSON.to_native(json, allow_objects)`
default to `false`. Never pass `true` for save files a user could edit or download.

**Versioning — do this from commit one.** Nothing in the manual covers it; this is the pattern,
flagged as mine:

```gdscript
class_name SaveData
extends Resource

const CURRENT_VERSION := 3
@export var version: int = CURRENT_VERSION
@export var slot_name: String = ""
@export var stats: Dictionary = {}

static func load_from(path: String) -> SaveData:
    if not FileAccess.file_exists(path):
        return SaveData.new()
    var data := ResourceLoader.load(path, "SaveData", ResourceLoader.CACHE_MODE_IGNORE) as SaveData
    if data == null:
        push_warning("Corrupt save at %s; starting fresh" % path)
        return SaveData.new()
    return _migrate(data)

static func _migrate(data: SaveData) -> SaveData:
    # One if-block per version bump. Never delete an old branch.
    if data.version < 2:
        data.stats["best_wave"] = data.stats.get("wave", 0)
        data.version = 2
    if data.version < 3:
        data.stats.erase("deprecated_field")
        data.version = 3
    return data
```

Non-negotiables: write `version` first and read it first; every load path must survive a missing
file, a truncated file, and a *newer* version than the build understands (refuse, don't crash);
save atomically (write `user://save.tmp`, then rename) so a crash mid-write does not destroy the
only save.

**Paths.** Always `user://` for saves — `res://` is read-only in an exported build. On HTML5
`user://` is a virtual filesystem in IndexedDB (`io/data_paths.rst`), which means it is
per-origin, wiped by "clear site data", and requires the user to allow cookies
(`export/exporting_for_web.rst`). Since this project ships to GitHub Pages, treat browser saves
as *best effort* and never as the only copy of anything.

This repo's current implementation, `game/scripts/game_state.gd:79-89`, is a two-key `ConfigFile`
at `user://accrete.cfg` with **no version key**. That is fine for two integers and is exactly
the thing to replace before the first save format that matters.

## 14. Scene transitions and loading

Four options, all real (`SceneTree`):

| Call | Behaviour |
| --- | --- |
| `change_scene_to_file(path)` | loads the `.tscn` into a `PackedScene` and swaps. Returns `Error` — check it |
| `change_scene_to_packed(ps)` | same, from an already-loaded `PackedScene` (thread-loadable) |
| `change_scene_to_node(node)` | swap to a node you built and configured yourself |
| `reload_current_scene()` | re-instantiates `current_scene` from its original `PackedScene` |
| `unload_current_scene()` | unloads without replacing |

`change_scene_to_node()`'s documented ordering is the one to internalise, and it applies to the
file/packed variants too (their docs point at it):

> 1. The current scene node is immediately removed from the tree. From that point,
>    `Node.get_tree()` called on the outgoing scene will return `null`. `current_scene` will be
>    `null` too. 2. At the end of the frame, the former scene is freed and the new scene node is
>    added.

Consequences: never assume `get_tree()` is valid in code running after you requested a change;
`await get_tree().scene_changed` if you need the new scene; and any reference you held to the
node passed to `change_scene_to_node()` becomes invalid once `SceneTree` takes ownership.

Manual swapping — when you need a fade, a loading screen, or to keep the player alive across
levels — is `scripting/change_scenes_manually.rst`, and the canonical implementation is vendored
at `third_party/godot-demo-projects/loading/autoload/global.gd`. Its critical move is deferral:

```gdscript
func goto_scene(path: String) -> void:
    _deferred_goto_scene.call_deferred(path)   # never free a scene from inside its own callback

func _deferred_goto_scene(path: String) -> void:
    get_tree().current_scene.free()
    var scene := (ResourceLoader.load(path) as PackedScene).instantiate()
    get_tree().root.add_child(scene)
    get_tree().current_scene = scene            # only after add_child
```

`change_scenes_manually.rst` also enumerates the three ways to retire a scene — free it
(unloads memory, loses data), hide it (`CanvasItem.hide()`; keeps memory *and* processing —
"will become a problem on memory-sensitive platforms like web"), or `remove_child()` it (keeps
memory, stops processing, easiest to restore). For a web build, free.

**Background loading** (`io/background_loading.rst`): `ResourceLoader.load_threaded_request(path)`,
poll `load_threaded_get_status(path, progress_array)` — the docs say to poll "during different
frames (e.g., in `Node._process`, instead of a loop)" — then `load_threaded_get(path)`. Status is
one of `THREAD_LOAD_INVALID_RESOURCE`, `THREAD_LOAD_IN_PROGRESS`, `THREAD_LOAD_FAILED`,
`THREAD_LOAD_LOADED`. Calling `load_threaded_get()` early blocks exactly like `load()`.

> **Web caveat.** Since **4.3** Godot supports a single-threaded web export, and that export
> "cannot use threads" (`export/exporting_for_web.rst`). If this project ships the
> single-threaded web build to avoid the `SharedArrayBuffer` COOP/COEP header requirement, treat
> threaded loading as a desktop-only optimisation and make sure the loading screen still works
> when the load completes synchronously.

Working reference: `third_party/godot-demo-projects/loading/load_threaded/load_threaded.gd`.

## 15. Folder layout

`best_practices/project_organization.rst`, verbatim rules:

- **`snake_case`** for all folder and file names. Windows/macOS are case-insensitive by default,
  Linux is not, and Godot's exported PCK filesystem *is* case-sensitive — mismatched case works
  locally and 404s after export.
- **`PascalCase`** for node names in the tree.
- Third-party code in a top-level **`addons/`**, "even if they aren't editor plugins", so it is
  obvious what you do not own.
- Group assets **as close to the scenes that use them as possible**; a separate folder for
  built levels.
- An empty **`.gdignore`** file makes Godot skip a folder entirely (contents ignored, no
  patterns supported); those files can then no longer be `load()`ed.

A layout that satisfies all of the above and does not assume a genre:

```
game/
  project.godot
  autoloads/          events.gd, game_state.gd, …    # one file per autoload, all tiny
  actors/
    player/           player.tscn, player.gd, states/, art/
    enemy/            enemy.tscn, enemy.gd, stats/*.tres
  systems/            save/, audio/, input/           # class_name nodes, not autoloads
  data/               *.tres authored content
  ui/                 hud.tscn, menus/, theme.tres
  levels/             level_01.tscn, …
  addons/             third-party only
```

Keep a script beside the scene it drives (`player.tscn` + `player.gd`), not in a global
`scripts/` bucket. This repo's `game/scripts/*.gd` with `game/scenes/*.tscn` is the bucket
layout; it is survivable at 14 files and stops scaling around 40, because "which scene owns this
script" becomes a grep.

Also from `project_organization.rst`: Godot uses the filesystem as-is with no asset database, so
**moving a file in the OS breaks references**. Move files from inside the Godot editor, which
rewrites dependents. Since **4.4**, `.tscn`/`.tres` reference dependencies by `uid://` (see the
`.uid` sidecar files next to every `.gd` in `game/scripts/`), which makes renames far safer —
commit the `.uid` files.

## 16. Keeping systems testable headlessly

`godot --headless` implies `--display-driver headless --audio-driver Dummy`
(`tutorials/editor/command_line_tutorial.rst`), and is combinable with `--script`, `--quit`,
`--quit-after <frames>`, `--check-only`, and `--import`. This repo's CI
(`.github/workflows/godot-ci.yml`) already does the cheap version: import the project, boot each
scene for 300 frames headless, and fail the build if the log contains `SCRIPT ERROR`, `Parse
Error`, or `ERROR:` (filtering GPU/audio noise). That catches every null-path and typo'd
property in code that actually runs — which is most of the fragility this guide is about.

To go further than smoke-booting, architecture has to cooperate:

| Rule | Consequence |
| --- | --- |
| Business logic in `RefCounted`/`Resource`, not in `Node._process` | testable with `.new()`, no `SceneTree` needed |
| Dependencies injected (§3), not fetched from autoloads | a test can pass a fake |
| No `get_node()` above `self` | the unit can be instantiated alone |
| Deterministic randomness via an injected `RandomNumberGenerator` with an explicit `seed` | reproducible failures |
| Audio/particles behind a listener-only autoload (`Vfx`) | headless runs never touch them |
| Guard editor-only work with `Engine.is_editor_hint()` | `@tool` scripts don't run game logic in the editor |

The dependency direction that makes all of this work is one-way:
**data (`Resource`) ← logic (`RefCounted` / `class_name` nodes) ← scenes ← autoloads**.
Nothing lower may reference anything higher. An `EnemyStats` resource that reads `GameState` has
inverted the arrow, and every test, every headless boot, and every future refactor pays for it.

Godot ships no unit-test framework. `third_party/beehave/addons/gdUnit4/` is vendored here and is
one option (`--headless -s` runner); I have not verified it against 4.7.1 in this repo, so treat
adopting it as a task with its own spike.

## 17. Review checklist

Reject a change that does any of these without a written reason:

- [ ] Adds a fifth autoload, or adds a *caller*-style method to an existing one.
- [ ] Calls `get_parent()`, `owner`, or an absolute `/root/...` path from a reusable child scene.
- [ ] Uses `get_node("A/B/C")` where `@export` or `%Name` would do — or calls either in `_process`.
- [ ] Stores balance/content values as GDScript constants instead of an `@export`ed `Resource`.
- [ ] Mutates a `@export`ed `Resource` at runtime without `duplicate()` or `resource_local_to_scene`.
- [ ] Writes a save file with no `version` field, or reads one without handling absence/corruption.
- [ ] Indexes `get_tree().get_nodes_in_group(...)` and assumes an order.
- [ ] `free()`s or `queue_free()`s an autoload.
- [ ] Uses a bus signal as a command (`do_thing`) rather than a fact (`thing_done`).
- [ ] Adds a node to the tree and *then* sets its initial properties.
- [ ] Introduces a `class_name` for a script attached to exactly one scene root.

## 18. What I could not verify

- **"Call down, signal up"** as a phrase appears nowhere in the vendored 517-page manual. The
  underlying rule is documented (`scene_organization.rst`, quoted in §3); the slogan is community
  usage.
- **Scene inheritance** has no dedicated page in the vendored 4.7 docs (the only "inherited
  scene" hits are in the 3D-import and visual-shader pages). §10's structural-vs-value guidance
  is my judgement, flagged as such; the API facts in it are from the class reference.
- **Autoload count guidance** ("callers vs listeners") is mine. The manual gives criteria, not
  numbers.
- **Save versioning and atomic writes** (§13) are not covered by the vendored manual at all. The
  APIs used are verified; the pattern is mine.
- **gdUnit4 under Godot 4.7.1** — vendored at `third_party/beehave/addons/gdUnit4/`, not run or
  verified in this repo.
- Whether this project's web export uses the **threaded or single-threaded** template — check
  `game/export_presets.cfg` before relying on `ResourceLoader.load_threaded_request()` on web.
