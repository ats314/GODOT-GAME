# GDScript: static typing, style, and the performance of both

Mechanical rules for writing GDScript in this Godot **4.7.1** project — naming, declaration
order, formatting, the full static-typing syntax, and every annotation worth knowing. The last
third covers what most style guides omit: which of these choices change *runtime* behaviour or
frame cost, and which are purely cosmetic. Read this before writing or reviewing any `.gd` file.

Every API in backticks was checked against `third_party/godot-class-reference/classes/*.xml`
(engine tag `4.7.1-stable`). Prose sources, all vendored under `third_party/godot-docs/tutorials/`:
`scripting/gdscript/{gdscript_styleguide,gdscript_basics,static_typing,gdscript_exports,warning_system,gdscript_documentation_comments,gdscript_format_string}.rst`,
`best_practices/{data_preferences,godot_interfaces,logic_preferences}.rst`,
`performance/cpu_optimization.rst`.

## Version scope

Only these version claims are documented in the vendored manual. Do not invent others.

| Feature | Version | Source |
| --- | --- | --- |
| Typed `for` variable `for x: T in …` | **4.2** | `static_typing.rst:244` |
| Typed dictionaries `Dictionary[K, V]` | **4.4** | `gdscript_basics.rst:1003` |
| Variadic functions (`...args`) | **4.5** | `gdscript_basics.rst:1617` |
| `@abstract` classes and methods | **4.5** | `gdscript_basics.rst:2185` |
| `match` + `continue` fallthrough | **removed in 4.0** | `gdscript_basics.rst:1931` |

Godot 3 APIs an agent may remember and must never emit: `setget` (now `set:`/`get:` blocks),
`yield` (now `await`; the function-state object was removed deliberately — `gdscript_basics.rst:2888`),
`export(int)` (now `@export var x: int`), `PoolIntArray` (now `PackedInt32Array`),
`connect("sig", self, "method")` (now `sig.connect(method)`).

---

## Naming

| Kind | Convention | Example |
| --- | --- | --- |
| File names | `snake_case` | `yaml_parser.gd` |
| `class_name` | `PascalCase` | `class_name YAMLParser` |
| Node names in the tree | `PascalCase` | `Camera3D`, `Player` |
| Functions, variables | `snake_case` | `func load_level():` |
| Signals | `snake_case`, **past tense** | `signal door_opened` |
| Constants | `CONSTANT_CASE` | `const MAX_SPEED = 200` |
| Enum names | `PascalCase`, **singular** | `enum Element` |
| Enum members | `CONSTANT_CASE` | `{EARTH, WATER, AIR, FIRE}` |

- Private members and methods take one leading `_`: `var _counter = 0`, `func _recalculate_path():`.
- A file's name is the `snake_case` of its `class_name`. This matches Godot's C++ naming and
  avoids case-sensitivity breakage exporting from Windows to Linux or web.
- Use `PascalCase` for a script bound to a constant: `const Weapon = preload("res://weapon.gd")`.
- The editor **hides** `class_name` types starting with `Editor` from the Create-Node dialogs;
  they still instantiate at runtime (`gdscript_basics.rst:2172`).

## Canonical declaration order

Verbatim from the style guide's "Code order". Follow it mechanically.

```
01. @tool, @icon, @static_unload      12. _static_init()
02. class_name  (@abstract precedes)  13. remaining static methods
03. extends                           14. virtual methods, in this order:
04. ## doc comment                        _init, _enter_tree, _ready,
                                          _process, _physics_process, rest
05. signals                           15. overridden custom methods
06. enums                             16. remaining methods
07. constants                         17. inner classes
08. static variables
09. @export variables
10. remaining regular variables
11. @onready variables
```

Within each group: **public before private**. Enums come after signals so they can be used as
export hints on the properties below. Don't declare a member variable used in only one method
(make it a local); declare locals as close to first use as possible.

## Formatting

| Rule | Value |
| --- | --- |
| Indentation | **Tabs**, one level per block (editor default; matches `game/scripts/*.gd`) |
| Line endings / encoding | LF, one trailing LF, UTF-8 **without** BOM |
| Line length | hard < 100 chars, prefer < 80 |
| Blank lines between funcs/classes | **two**; one inside a func to separate sections |
| Continuation lines | **two** indent levels |
| Continuation inside `[]`, `{}`, `enum {}` | **one** indent level |
| Trailing comma | required in multi-line literals, forbidden in single-line ones |
| Quotes | double, unless single quotes avoid more escapes |
| Booleans | `and` / `or` / `not`, never `&&` / `\|\|` / `!` |

Numbers: never drop a leading or trailing zero (`0.234`, `13.0` — not `.234`, `13.`); lowercase
hex digits (`0xfb8c0b`); underscore-separate literals over a million (`1_234_567_890`,
`0xffff_f8f8_0000`) but not below it.

One space around operators and after commas; no space inside `dict["key"]` or `print("foo")`;
**exception:** single-line dictionary literals get inner padding — `{ key = "value" }` — so they
read differently from arrays. Never align `=` vertically. One statement per line, the ternary
being the sole exception (`next_state = "idle" if is_on_floor() else "fall"`). Avoid parentheses
not required by precedence. Wrap long conditions in parentheses (not backslashes — parens survive
refactoring), with `and`/`or` at the **start** of the continuation:

```gdscript
if (
		position.x > 200 and position.x < 400
		and position.y > 300 and position.y < 400
):
	pass
```

**Comments.** `# ` and `## ` start with a space; commented-out *code* does not (`#print("x")`) —
that is how you distinguish prose from disabled code. `#region`/`#endregion` take no space (exact
syntax required for folding). Prefer own-line comments. `##` is a documentation comment feeding
the in-editor class docs and, above an `@export var`, the Inspector tooltip; it must sit directly
above its item or at the top of the file. Doc tags: `@tutorial: <url>`, `@tutorial(Title): <url>`,
`@deprecated[: reason]`, `@experimental[: reason]`; `[br]` forces a line break. Uppercase
`ALERT ATTENTION CAUTION CRITICAL DANGER SECURITY` (red), `BUG DEPRECATED FIXME HACK TASK TBD
TODO WARNING` (yellow), `INFO NOTE NOTICE TEST TESTING` (green) are highlighted in comments.

---

## Static typing syntax

```gdscript
var damage: float = 10.5
const MOVE_SPEED: float = 50.0

func sum(a: float = 0.0, b: float = 0.0) -> float:
	return a + b
```

`void` is a **return type only**. `Variant` is legal anywhere; as a return type it *forces* the
function to explicitly return a value. **Legal type hints** (exhaustive, `static_typing.rst:112`):
`Variant`; `void` (return only); built-in types; native classes (`Object`, `Node`, `Area2D`…);
global `class_name` classes; inner classes; global/native/custom named enums — **an enum type is
just an `int`**, with no runtime guarantee the value is a member; and constants holding a
preloaded class or enum.

### Typed arrays — `Array[T]`

```gdscript
var scores: Array[int] = [10, 20, 30]
var array_of_arrays: Array[Array] = [[], []]
# var arrays: Array[Array[int]]   # DISALLOWED — nested types unsupported in 4.7
```

The element type propagates to `for` variables and to `[]`, `[…] =` and `+`, but **not** through
array *methods*: `front()`, `back()`, `pop_back()` still return `Variant`. Arrays are passed by
reference and the element type is part of the referenced structure, so you **cannot** assign an
`Array[Node2D]` to an `Array[Node]` variable even though `Node2D` extends `Node`. Convert with
`Array.assign()`:

```gdscript
var a: Array[Node2D] = [Node2D.new()]
var b: Array[Node] = []
b.assign(a)
```

Since 4.2 you can type only the loop variable, leaving the array untyped: `for name: String in names:`.

### Typed dictionaries — `Dictionary[K, V]` (4.4+)

```gdscript
var fruit_costs: Dictionary[String, int] = { "apple": 5, "orange": 10 }
var any_value: Dictionary[String, Variant] = {}   # keys typed, values open
# var nested: Dictionary[String, Dictionary[String, int]]   # DISALLOWED
```

Both key and value types must be written; use `Variant` to leave either open. `Dictionary` and
`Dictionary[Variant, Variant]` are the same type. Keys and values are checked **on write, at
runtime**; methods that return values still return `Variant`. Working examples in this repo:
`third_party/godot-demo-projects/3d/voxel/world/chunk.gd` (`const DIRECTIONS: Array[Vector3i]`,
`var data: Dictionary[Vector3i, int] = {}`) and
`third_party/godot-demo-projects/2d/finite_state_machine/player/player_state.gd`
(`const PLAYER_STATE: Dictionary[StringName, StringName]` with `&"literal"` keys).

### Inference with `:=`

**Use `:=` when the type is obvious on the same line; write the type explicitly when it is not.**

```gdscript
var health: int = 0                        # GOOD — int or float? state it
var direction := Vector3(1, 2, 3)          # GOOD — unambiguous
var health := 0                            # BAD  — infers int; maybe float was meant
var direction: Vector3 = Vector3(1, 2, 3)  # BAD  — redundant
var value := complex_function()            # BAD  — reader cannot see the type
```

**Where inference fails:** `get_node()` / `$` are declared to return `Node`, so the compiler
infers `Node`, not the concrete class.

```gdscript
@onready var health_bar: ProgressBar = get_node("UI/LifeBar")   # GOOD
@onready var health_bar := get_node("UI/LifeBar")               # BAD — typed Node
@onready var health_bar := get_node("UI/LifeBar") as ProgressBar # valid, but see below
```

The `as` form produces a green "safe line" in the editor but is **less null-safe**: on mismatch
it silently yields `null` with no error, so the bug surfaces far from its cause. The
`: ProgressBar =` form is marked unsafe yet fails loudly at scene load — prefer it
(`static_typing.rst:384`). Constants need no hints (`=` and `:=` are identical for them) — except
for typed collections, since untyped is the default: `const A: Array[int] = [1, 2, 3]`.

### Narrowing: `is`, `is not`, `as`, `assert`

```gdscript
func _on_body_entered(body: PhysicsBody2D) -> void:
	if body is not PlayerController:
		return
	var player: PlayerController = body   # narrowed, checked, no silent null
	player.damage()
```

`as` on a **built-in** type that cannot convert raises an error; `as` on an **object** type that
does not match yields `null` silently. `is` supports typed arrays and dictionaries;
`is_instance_of(value, type)` accepts a non-constant `type` but supports fewer features.
**Covariance/contravariance:** when overriding you may narrow the return type and widen a
parameter type — a parent `func get_property(param: Label) -> Node:` may be overridden as
`func get_property(param: Control) -> Node2D:`.

### Typed replacements for untyped globals

These return `Variant`, which poisons inference and forces the slow opcode path
(`static_typing.rst:489`):

| Untyped | Typed replacements |
| --- | --- |
| `abs()` | `absf()`, `absi()`, `Vector2.abs()`, `Vector3.abs()`, … |
| `ceil()` / `floor()` / `round()` | `ceilf`/`ceili`, `floorf`/`floori`, `roundf`/`roundi`, plus `VectorN.ceil()` etc. |
| `clamp()` | `clampf()`, `clampi()`, `Vector2.clamp()`, `Color.clamp()` (untyped `clamp()` does **not** work on `Color`) |
| `lerp()` | `lerpf()`, `Vector2.lerp()`, `Color.lerp()`, `Quaternion.slerp()`, `Basis.slerp()`, `Transform3D.interpolate_with()` |
| `sign()` / `snapped()` | `signf`/`signi`, `snappedf`/`snappedi`, plus vector variants |

`min()`/`max()` likewise have `minf`/`mini`/`maxf`/`maxi`.

---

## Warnings: the enforceable half of the style guide

**Project Settings → Debug → GDScript** (needs Advanced Settings). Values: `0` Ignore, `1` Warn,
`2` Error. Suppress with `@warning_ignore("name")`, or a region with
`@warning_ignore_start("name")` … `@warning_ignore_restore("name")`. The warning name equals the
project-setting key. Engine defaults worth knowing:

| Warning | Default | Meaning |
| --- | --- | --- |
| `onready_with_export` | **Error** | `@onready` + `@export` on one var; the onready default overwrites the exported value |
| `get_node_default_without_onready` | **Error** | `$Node` as a class-var default without `@onready` |
| `native_method_override` | **Error** | a method shadows an engine method |
| `inference_on_variant` | **Error** | `:=` from a `Variant`, silently making the var `Variant` |
| `untyped_declaration` | Ignore | turn **on** to require static types everywhere |
| `inferred_declaration` | Ignore | turn on to require explicit types even where inferable |
| `unsafe_property_access`, `unsafe_method_access`, `unsafe_cast`, `unsafe_call_argument` | Ignore | the `UNSAFE_*` family; enable when adopting typed style |
| `missing_await` | Ignore | calling a coroutine without `await` |
| `integer_division` | Warn | `int / int` truncates |
| `narrowing_conversion` | Warn | float passed where int expected |
| `confusable_capture_reassignment` | Warn | reassigning a lambda-captured local (does not affect the outer local) |
| `confusable_temporary_modification` | Warn | mutating a `Packed*Array` **property** in place — you edit a temporary; the property is unchanged |
| `static_called_on_instance` | Warn | call statics on the class, not an instance |
| `redundant_static_unload` | Warn | `@static_unload` with no static vars |

`debug/gdscript/warnings/directory_rules` (default `{ "res://addons": 0 }`) excludes vendored
addons from your warning config; include your own addons, leave third-party ones out.
All 48 names, for grep: `assert_always_false assert_always_true confusable_capture_reassignment
confusable_identifier confusable_local_declaration confusable_local_usage
confusable_temporary_modification deprecated_keyword directory_rules empty_file
enum_variable_without_default get_node_default_without_onready incompatible_ternary
inference_on_variant inferred_declaration int_as_enum_without_cast int_as_enum_without_match
integer_division missing_await missing_tool narrowing_conversion native_method_override
onready_with_export redundant_await redundant_static_unload renamed_in_godot_4_hint
return_value_discarded shadowed_global_identifier shadowed_variable shadowed_variable_base_class
standalone_expression standalone_ternary static_called_on_instance unassigned_variable
unassigned_variable_op_assign unreachable_code unreachable_pattern unsafe_call_argument
unsafe_cast unsafe_method_access unsafe_property_access unsafe_void_return untyped_declaration
unused_local_constant unused_parameter unused_private_class_variable unused_signal unused_variable`

---

## `@export` variants

All verified present in 4.7. Exporting sets `PROPERTY_USAGE_STORAGE` (saved to `.tscn`/`.tres`)
**and** `PROPERTY_USAGE_EDITOR` (shown in the Inspector); exported values also transfer by RPC.

| Annotation | Editor effect |
| --- | --- |
| `@export` | Inspector widget matching the declared/inferred type |
| `@export_range(min, max, step, …)` | Slider. Hints: `"or_less"`, `"or_greater"`, `"exp"`, `"hide_slider"`, `"prefer_slider"`, `"suffix:m"`, `"degrees"`, `"radians_as_degrees"` |
| `@export_enum("A", "B:30", …)` | Dropdown; stores `int` index (or the `String` if the var is `String`) |
| `@export_flags("Fire", "Water", …)` | Checkbox bitfield into one `int` |
| `@export_flags_2d_physics` / `_2d_render` / `_2d_navigation` / `_3d_physics` / `_3d_render` / `_3d_navigation` / `_avoidance` | Layer pickers using Project Settings layer names |
| `@export_file("*.json")`, `@export_dir` | `res://`-limited path picker |
| `@export_global_file`, `@export_global_dir` | Whole-filesystem path picker |
| `@export_file_path` | Like `@export_file` but stores a **raw** path — breaks if the file moves |
| `@export_multiline` | `TextEdit` widget instead of a one-line field |
| `@export_placeholder("text")` | Grey placeholder in an empty `String` field |
| `@export_color_no_alpha` | `Color` picker with alpha locked |
| `@export_exp_easing` | Easing-curve widget |
| `@export_node_path("Button", "TouchScreenButton")` | `NodePath` restricted to those types |
| `@export_storage` | Serialized but **hidden** from the Inspector; also copied by `Node.duplicate()` / `Resource.duplicate()` |
| `@export_custom(PROPERTY_HINT_*, "hint", usage)` | Raw hint passthrough — **no syntax validation** |
| `@export_tool_button("Label", "Icon")` | Clickable Inspector button bound to a `Callable`; not stored (a `Callable` cannot serialize) |
| `@export_category` / `@export_group` / `@export_subgroup` | Inspector organization only; groups cannot nest |

Rules that bite:

- An exported var must be **initialized to a constant expression** or carry a type specifier.
- Prefer exporting a typed node (`@export var some_button: BaseButton`) over exporting a
  `NodePath` and calling `get_node()`: editor-checked, and no runtime lookup.
- Packed arrays export **only if initialized empty**: `@export var strings = PackedStringArray()`.
- Reading an exported var in `_init()` returns the **annotation default**, not the inspector
  value — saved values are applied after construction. Read it in `_ready()`, or in the
  property's own setter (the only option for `Resource` subclasses, which have no `_ready()`).
- Setters/getters on exported vars run in the editor only if the script is `@tool`.
- Changing an exported var from a `@tool` script does not refresh the Inspector; call
  `Object.notify_property_list_changed()`.
- `@export` and `@onready` cannot be applied to a `static var`.

## `@onready` and initialization order

From `gdscript_basics.rst:1106`:

1. Every var gets its type's zero value (`0`, `false`, `""`) — or `null` if untyped or an object type.
2. Initializer expressions run **top to bottom in declaration order**. `@onready` vars skip this.
3. `_init()` runs.
4. For instantiated scenes/resources, exported values are applied.
5. `@onready` vars initialize (Node-derived classes only).
6. `_ready()` runs.

Hazards:

- **Ordering within step 2.** A plain `var` initializer calling a function that touches a member
  declared *below* it sees that member's zero value. The manual's worked example
  (`gdscript_basics.rst:1122`) shows a `Dictionary` silently reset by its own `= {}` initializer
  running after the calls that filled it.
- **`@onready` vars also initialize in declaration order** — one cannot read another declared below it.
- **`@onready` + `@export` on one var is broken by design.** The onready default is written
  *after* the exported value, clobbering it. `ONREADY_WITH_EXPORT` is an **error** by default;
  do not disable it.
- **`$Node` as a plain class-var default** raises `GET_NODE_DEFAULT_WITHOUT_ONREADY`, also an
  error by default — at construction the node is not in the tree yet.

---

## `class_name`, `@abstract`, inner classes, statics

```gdscript
@tool
@icon("res://ui/icons/item.svg")
@abstract
class_name Item
extends Node
## One-line summary shown in the class docs.
```

`@tool`, `@icon`, `@static_unload` and `@abstract` **must precede** `class_name`/`extends` — an
annotation describes what follows it. `@icon`'s argument must be a **string literal**, and only
the outer script may have an icon (not inner classes). `class_name X extends Y` on one line is
idiomatic when there is no doc comment. Named classes are global — no `preload` needed elsewhere.

**`@abstract` (4.5+).** An abstract class cannot be instantiated and cannot be attached to a node
(`Cannot set object script. Script '<path>' should not be abstract.`). An abstract method has no
body — a newline or `;` follows the header. Any class with an unimplemented abstract method (own
or inherited) must itself be `@abstract`; the converse is not required. With no `class_name`,
`@abstract` goes above `extends`.

```gdscript
@abstract class Shape:
	@abstract func draw()


class Circle extends Shape:
	func draw():
		print("Drawing a circle.")
```

**Inner classes** use `class`, instantiate as `Outer.Inner.new()`, go **last** in the file, and
are declared on a single line. They are usable as type hints.

**Static variables** belong to the class and are readable through subclasses (`B.x` reads `A.x`;
assigning through `B` writes `A`); they support type hints, setters and getters. Because GDScript
classes are `Resource`s, a script holding static variables **never unloads**. `@static_unload` is
the documented remedy, but the class reference itself warns that due to a bug scripts are never
freed even with it — treat static state as permanently resident and clear it manually.
Referencing a static var from a `@tool` script requires the *other* script to be `@tool` too.

## Properties: `set` / `get`

```gdscript
var milliseconds: int = 0
var seconds: int:
	get:
		return milliseconds / 1000
	set(value):
		milliseconds = value * 1000

var my_prop: get = get_my_prop, set = set_my_prop   # alternative, reusable form
```

- Setters/getters are **always** called, including inside the same class and with or without
  `self.` — unlike Godot 3's `setget`. **Exception:** using the variable's own name inside its own
  setter/getter hits the backing field directly, so no infinite recursion. That exception does
  **not** propagate — calling a *helper* that assigns the property from within the setter recurses
  forever.
- Initializers bypass the setter, including `@onready` and `@export` initializers.
- Inline setters/getters cannot carry type hints (the setter parameter inherits the variable's
  type). Separate functions can; their types must match or be wider.

## Signals

```gdscript
signal health_changed(old_value: int, new_value: int)

health_changed.emit(old_health, health)
character.health_changed.connect(_on_hp_changed)              # plain
character.health_changed.connect(log._on_hp.bind(character.name))  # with bound extra arg
```

Parameter names **and types** are supported and used throughout the vendored demos (e.g.
`signal note_hit(beat: float, hit_type: Enums.HitType, hit_error: float)`). The declared list is
what the editor's Signals dock uses to generate callbacks, but arity is not enforced at emit time.
`Signal` members in 4.7: `connect(callable, flags)`, `disconnect(callable)`, `emit()`,
`get_connections()`, `get_name()`, `get_object()`, `get_object_id()`, `has_connections()`,
`is_connected(callable)`, `is_null()`.

`Object.ConnectFlags`: `CONNECT_DEFERRED` (fires at end of frame), `CONNECT_PERSIST`
(serialized with the object), `CONNECT_ONE_SHOT` (auto-disconnects), `CONNECT_REFERENCE_COUNTED`,
`CONNECT_APPEND_SOURCE_OBJECT` (appends the emitter after the signal's own arguments).

Name signals in the **past tense**; name handlers `_on_<source>_<signal>`.

## Lambdas and `Callable`

```gdscript
var square := func (x: int) -> int: return x ** 2
print(square.call(2))                       # 4
var named = func my_lambda(x): print(x)     # named lambdas show up in the debugger
```

- A lambda evaluates to a `Callable`; invoke it with `.call()`. An explicit `return` is required
  to return a value.
- Lambdas **cannot be declared static**. They *can* take a rest parameter.
- **Captures are by value, once, at creation.** Reassigning the outer local afterwards does not
  update the lambda. Assigning to a captured name *inside* the lambda mutates only the capture
  and raises `CONFUSABLE_CAPTURE_REASSIGNMENT`.
- Pass-by-reference values (arrays, dictionaries, objects) share **contents** with the capture,
  so `a.append(1)` inside a lambda is visible outside — until you reassign `a`.
- **Do not store lambda callables in member variables of `RefCounted`-derived classes** (that
  includes every `Resource`): the class reference warns this leaks memory. Store method callables
  plus `Callable.bind()` / `Callable.unbind()` instead.

`Callable` members: `call()`, `callv(array)`, `call_deferred()`, `bind()`, `bindv(array)`,
`unbind(argcount)`, `is_valid()`, `is_null()`, `is_custom()`, `is_standard()`, `get_object()`,
`get_method()`, `get_argument_count()`, `get_bound_arguments()`.

Variadic functions (4.5+) use a rest parameter: last in the list, no default, and typed arrays are
**not** allowed as its type (`...values: Array`, never `...values: Array[int]`). There is no
spread syntax at the call site — use `callv()`.

## `await`

`await $Button.button_up` suspends until the signal fires.

- `await` on a signal or coroutine returns control to the caller and resumes on emission.
- A function containing `await` **becomes a coroutine**; callers needing its return value must
  `await` it too. Calling without `await` and reading the result is an error; calling without
  `await` and ignoring the result is legal fire-and-forget.
- `await` on a non-signal, non-coroutine expression returns immediately and does **not** make the
  function a coroutine (`REDUNDANT_AWAIT` warning).
- The awaited value depends on the signal's arity: **one** parameter → that value; **more than
  one** → an `Array`; **zero** → `null`.
- Returning a signal from a non-coroutine makes the caller's `await` wait on that signal.
- Unlike Godot 3's `yield`, there is **no function-state object** — removed so a function
  declared `-> int` cannot return a state object at runtime.

## `assert`

`assert(cond, "message")` — e.g. `assert(body is PlayerController, "Bug: not a PlayerController.")`.
`assert()` is **compiled out of release builds** — the condition is not evaluated at all, so it
must never contain side effects. On failure in the editor it triggers a debugger break and the
current method returns a default value. The `assert_always_true` / `assert_always_false` warnings
(Warn by default) catch constant conditions. For a check that must survive export, use
`push_error()` / `push_warning()`.

---

# Performance: what these choices actually cost

**The cost model.** Every GDScript operation goes through the `Variant` scripting API: to touch a
property or method the engine walks the object's class, then each base class up to `Object`,
doing hash-map lookups at each level. `data_preferences.rst` states it plainly: *"The reason
GDScript is slow is because every operation it performs passes through this system."* So the
optimization goal is **fewer dynamic lookups per frame**, not clever arithmetic.
`cpu_optimization.rst` adds that built-in engine functions run at the same speed regardless of
scripting language — pushing work *into* engine calls (servers, `Tween`, shaders, physics) beats
a GDScript loop.

### 1. Static types change the generated bytecode

`static_typing.rst:66`: *"typed GDScript improves performance by using optimized opcodes when
operand/argument types are known at compile time."* That is the whole mechanism — there is no
JIT/AOT in 4.7 (the docs list it as planned). Consequences:

- A type annotation only helps if the compiler can prove the type **at that line**.
  `var x := get_node("A")` types `x` as `Node`; every later `.foo` on it is a dynamic lookup.
- `clamp()` instead of `clampf()` returns `Variant` and un-types everything downstream.
- A green gutter ("safe line") is the editor's signal that the typed opcode path was taken.
  Enable the `UNSAFE_*` warnings to find the rest.

Static types also change **runtime semantics**, not only speed:

| Construct | Untyped | Typed |
| --- | --- | --- |
| `var x` vs `var x: int` | initial value `null` | initial value `0` |
| `var a = []` vs `var a: Array[int] = []` | any element accepted | **runtime type check on every write** |
| `var d = {}` vs `var d: Dictionary[String, int] = {}` | any key/value | **runtime check on every write** (4.4+) |
| `b = a` between arrays | always allowed | rejected unless element types match exactly |
| `var n = $X as Player` | — | silently `null` on mismatch |
| `var n: Player = $X` | — | loud error at the assignment |

The typed-container write check is a real per-write cost and is worth paying: it turns "wrong
thing in the list" from a crash three systems away into an error at the `append`.

### 2. `Array` vs `Packed*Array`

`Array` is a `Vector<Variant>` — contiguous, but each slot is a full `Variant`. The
`Packed*Array` family (`PackedByteArray`, `PackedInt32Array`, `PackedInt64Array`,
`PackedFloat32Array`, `PackedFloat64Array`, `PackedStringArray`, `PackedVector2Array`,
`PackedVector3Array`, `PackedVector4Array`, `PackedColorArray`) stores the raw type; the class
reference says each *"packs data tightly, so it saves memory for large array sizes."*

Use a packed array when data is homogeneous, large, and fed to an engine API (`ArrayMesh`,
`Line2D.points`, `Image`, audio buffers, `FileAccess`). Use a typed `Array` when you need
arbitrary insert/remove or heterogeneous contents. Costs (`data_preferences.rst`) apply to both:

| Op | Cost |
| --- | --- |
| Iterate; get/set by index | fastest — pointer increment |
| Append/remove at the **end** | fast |
| Insert/remove at an arbitrary index | slow — shifts the tail |
| Insert/remove at the **front** | slowest |
| `find()` | slowest — linear scan |

For many front insertions: reverse, append in a loop, reverse back — two copies instead of N shifts.

**Trap specific to packed arrays:** a built-in *property* of packed type returns a **copy**, so
`polygon.append(v)` on a node property mutates a temporary and is silently lost. Read into a
local, mutate, assign back. `confusable_temporary_modification` (Warn by default) catches the
common shapes. Note `PackedInt32Array` wraps at ±2³¹ while GDScript's `int` is 64-bit — use
`PackedInt64Array` if values can exceed that.

### 3. `Dictionary` lookups

`Dictionary` is a `HashMap<Variant, Variant, VariantHasher, StringLikeVariantComparator>`.
Insert, erase, get and set are **constant time**; iteration is fast and preserves insertion
order. Only find-by-value is linear, and the engine does not provide it.

- Key by `StringName`, not `String`, for repeated lookups: `StringName`s are interned, so *"Two
  `StringName`s with the same value are the same object. Comparing them is extremely fast
  compared to regular `String`s."* Write the literal as `&"key"` to prevent a per-call
  `String`→`StringName` conversion.
- Integer comparisons are constant time, string comparisons linear — prefer `int`-backed enums
  over string keys in hot code. The cost is that printing an enum shows a number; pay that in a
  debug-only lookup table, not in the data model.
- Don't reach for a `Dictionary` when a typed `Array` indexed by an `int` id will do.
- An `Object`/`Resource` with declared properties is *slower* to read than either, because every
  property access walks the class hierarchy — choose it for structure, signals and compile-time
  checking, not for speed.

### 4. String building in loops

`+` on `String` allocates a new string each time; in a loop that is quadratic in total bytes.
Collect and join once:

```gdscript
# BAD in a hot loop
var out := ""
for line in lines:
	out += line + "\n"

# GOOD — one allocation for the result
var parts := PackedStringArray()
for line in lines:
	parts.append(line)
var out := "\n".join(parts)
```

`String.join(parts: PackedStringArray)` is the verified 4.7 signature. Prefer
`"%s took %d damage" % [name, dmg]` or `String.format()` over `"a" + str(x) + "b"` — the docs note
concatenation is harder to read and forces `str()` conversions (`gdscript_format_string.rst:325`).
For per-frame text (`Label.text`, debug overlays) the cheapest fix is not to build the string at
all: rebuild only when the value changed.

### 5. `get_node()` in `_process()`

Ranked by `godot_interfaces.rst:136`, fastest last:

```gdscript
func _process(_delta): print(get_node("Child"))  # Slow — parses the path, walks the tree, every call
func _process(_delta): print($Child)             # Faster — path compiled once, still walks the tree
@onready var child: Node = $Child                # Fastest — one lookup, at _ready
@export var child: Node                          # Fastest, and survives moving the node in the dock
```

- **Never call `get_node()`, `$`, `%`, `find_child()`, or `get_tree().get_nodes_in_group()`
  inside `_process` / `_physics_process` / `_draw`.** Cache in `@onready` or `@export`.
- `@export var child: Node` is the most robust: a direct object reference set in the editor, it
  type-checks and does not break when the node is renamed or reparented.
- `%UniqueName` (backed by `Node.unique_name_in_owner`) is still a tree search — cache it too.
- `get_node_or_null()` avoids error spam when absence is expected, but costs the same lookup.

### 6. `_process` itself has a cost

`cpu_optimization.rst`: *"every node has a cost. Built-in functions such as `_process()` and
`_physics_process()` propagate through the tree."*

- Do not define `_process()` at all if the body is `pass` or usually a no-op — an empty override
  still costs a per-frame call across every instance.
- Turn processing off when idle: `set_process(false)`, `set_physics_process(false)`,
  `set_process_unhandled_input(false)`, `set_block_signals(true)`. The style guide's own
  `StateMachine` example does exactly this from an `is_active` setter.

### 7. Loops, allocation, loading

- `for i in range(n)` does **not** allocate an array — stated explicitly for `range(n)`,
  `range(a, b)` and `range(a, b, step)` (`gdscript_basics.rst:1850`). But `var a = range(n)`
  **does**: `range()` is documented as returning an `Array`. `for i in n` (a bare int) is
  equivalent to `for i in range(n)`.
- To write back while iterating, loop the index: `for i in array.size():`. The loop variable is a
  copy for value types (`for s in strings: s = "x"` does nothing), though method calls on object
  elements do take effect since those are references.
- `preload()` resolves at parse time and takes a constant path; `load()` hits disk (or the
  resource cache) at the statement. Never `load()` in a hot path. `const X = preload(...)` is the
  idiomatic "import"; but a preloaded constant can only be unloaded by unloading the whole script.
- `logic_preferences.rst`: set a node's properties **before** `add_child()`. Some setters do extra
  work once in the tree; for procedural generation this is the difference between a hitch and a
  crawl. Exceptions exist where a value needs tree membership (e.g. `global_position`).

### 8. Measure, don't guess

`var t0 := Time.get_ticks_usec()` … `print("took %d us" % (Time.get_ticks_usec() - t0))`. Run the
block ≥1000 times and average — timer granularity and cache state dominate a single sample. This
project also ships to web, where the budget is tighter than desktop: measure on the real target.

---

## Copy-paste skeleton

```gdscript
@tool
@icon("res://ui/icons/state_machine.svg")
class_name StateMachine
extends Node
## Hierarchical state machine. Delegates engine callbacks to the active state.

signal state_changed(previous: StringName, new: StringName)

enum Mode {
	IDLE,
	ACTIVE,
}

const MAX_DEPTH := 8

static var _instances := 0

@export var initial_state: Node
@export_range(0.0, 1.0, 0.01) var blend: float = 0.5

var is_active := true:
	set(value):
		is_active = value
		set_physics_process(value)   # stop paying the per-frame cost when idle

var _speed := 300.0

@onready var _state: Node = initial_state
@onready var _state_name: StringName = _state.name


func _physics_process(delta: float) -> void:
	_state.physics_process(delta)


func transition_to(target: Node, msg: Dictionary[StringName, Variant] = {}) -> void:
	if target == null:
		return
	_state.exit()
	_state = target
	_state.enter(msg)
	state_changed.emit(_state_name, target.name)


class State:
	var foo := 0
```

---

## Claims I could not verify from the vendored sources

- **Which 4.x version introduced typed arrays.** `Array[T]` is documented with no version note
  and is present in the 4.7.1 reference. Do not write "since 4.x" without checking upstream.
- **Which version added `@export_tool_button`, `@export_file_path`, `@warning_ignore_start` /
  `@warning_ignore_restore`, `CONNECT_APPEND_SOURCE_OBJECT`, or the `directory_rules` warning
  setting.** All exist in the 4.7.1 reference; the vendored docs carry no "since" marker.
- **Numeric speedup factors.** The docs assert "optimized opcodes" with no benchmark. Do not
  quote a multiplier.
- **Per-element memory sizes** for `Variant` vs packed storage — the reference says packed arrays
  "save memory for large array sizes" without figures.
- **Whether typed-collection write checks are measurably costly.** The check is documented as
  happening; its cost is not quantified anywhere in the vendored sources.
- **Web/HTML5-specific GDScript performance differences.** Nothing in the vendored manual
  addresses GDScript cost on the web export specifically.
