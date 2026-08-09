# GDScript: static typing, style, and the performance of both

Mechanical rules for writing GDScript in **Godot 4.7.1 stable** on a **desktop (Windows/Linux/Steam Deck)** target:
naming, declaration order, formatting, the full static-typing syntax, the annotations that exist in 4.7, and the
subset of style choices that actually change runtime cost. Read it before writing or reviewing any `.gd` file, and
whenever you are about to claim "typing is just documentation" (it is not) or "typed arrays are fastest" (they are not).

Sources, all vendored here. In `third_party/godot-docs/tutorials/scripting/gdscript/`: `gdscript_styleguide.rst`,
`static_typing.rst`, `gdscript_basics.rst`, `gdscript_exports.rst`, `warning_system.rst`,
`gdscript_documentation_comments.rst`, `gdscript_format_string.rst`. Plus
`third_party/godot-docs/tutorials/best_practices/{godot_interfaces,data_preferences}.rst`,
`third_party/godot-docs/tutorials/performance/cpu_optimization.rst`,
`third_party/godot-docs/tutorials/migrating/upgrading_to_godot_4.7.rst`, and the 4.7.1-stable class XMLs under
`third_party/godot-class-reference/classes/`. Bare `.rst` filenames below refer to the gdscript/ directory.

## Version gates — which 4.x added what

Do not write these into a 4.0/4.1 codebase; do use them here, we are on 4.7.1.

| Feature | Added in | Source |
|---|---|---|
| Typed arrays `Array[T]` | 4.0 (present since the 4.x class ref) | `gdscript_basics.rst` "Typed arrays" |
| Typed `for` loop variable `for x: T in arr` | **4.2** | `static_typing.rst` line 244 |
| **Typed dictionaries** `Dictionary[K, V]` | **4.4** | `gdscript_basics.rst` line 1003: "Godot 4.4 added support for typed dictionaries" |
| `@warning_ignore_start` / `@warning_ignore_restore` | present in 4.7 class ref; exact introduction version **I could not verify offline** | `@GDScript.xml` |
| Variadic functions (`...args` rest parameter) | **4.5** | `gdscript_basics.rst` line 1617 |
| `@abstract` classes and methods | **4.5** | `gdscript_basics.rst` line 2185 |
| Overriding a method with a typed return **inherits that return type** and now requires an explicit `return`; and setting one element of a packed array no longer calls the setter for the whole packed-array property | **4.7** | `upgrading_to_godot_4.7.rst` (GH-115763, GH-113228) |

The 4.7 return-type change is a real breaking change. If a base declares `func f() -> Node:` and your override
previously ended without `return`, add `return null` (the migration doc's own fix).

## Naming and file conventions

From `gdscript_styleguide.rst` "Naming conventions".

| Thing | Convention | Example |
|---|---|---|
| File names | `snake_case` | `yaml_parser.gd` |
| Class names (`class_name`) | `PascalCase` | `class_name YAMLParser` |
| Node names | `PascalCase` | `Camera3D`, `Player` |
| Functions | `snake_case` | `func load_level():` |
| Variables | `snake_case` | `var particle_effect` |
| Signals | `snake_case`, **past tense** | `signal door_opened`, `signal score_changed` |
| Constants | `CONSTANT_CASE` | `const MAX_SPEED = 200` |
| Enum names | `PascalCase`, singular | `enum Element` |
| Enum members | `CONSTANT_CASE` | `{EARTH, WATER, AIR, FIRE}` |

- A file holding `class_name Weapon` is saved as `weapon.gd`; `class_name YAMLParser` → `yaml_parser.gd`. The style
  guide's reasons: consistency with Godot's C++ sources, and avoiding case-sensitivity breakage when a project
  authored on Windows is exported elsewhere — for us, Linux and Steam Deck.
- Prefix private functions, private variables, and virtual methods the user must override with a single `_`.
  Use `PascalCase` when loading a class into a const/var: `const Weapon = preload("res://weapon.gd")`.

## Canonical declaration order

Verbatim from `gdscript_styleguide.rst` "Code order". Agents should emit scripts in exactly this order.

```
01. @tool, @icon, @static_unload   02. class_name   03. extends   04. ## doc comment
05. signals   06. enums   07. constants   08. static variables
09. @export variables   10. remaining regular variables   11. @onready variables
12. _static_init()   13. remaining static methods
14. overridden built-in virtuals, in this order:
    _init(), _enter_tree(), _ready(), _process(), _physics_process(), remaining virtuals
15. overridden custom methods   16. remaining methods   17. inner classes
```

Within each group: **public before private**. `@abstract` goes *before* `class_name`. Enums come after signals
specifically so they can be used as export hints on the properties below them.

```gdscript
@abstract
class_name MyNode
extends Node
## A brief description of the class's role and functionality.
##
## The description of the script, what it can do, and any further detail.
```

Two more rules from the same page: do not declare a member variable that is only used inside one method (make it
local), and declare local variables as close as possible to first use.

## Formatting rules

| Rule | Value |
|---|---|
| Indentation | **Tabs**, one level per block |
| Continuation lines | **2** indent levels (arrays / dictionaries / enums: **1**) |
| Line length | under **100** chars; prefer under 80 |
| Line endings | LF, one trailing newline, UTF-8 without BOM |
| Blank lines | **2** between functions and class definitions; 1 inside a function to split sections |
| Trailing comma | required on multi-line array/dict/enum literals; forbidden on single-line ones |
| Boolean operators | `and` / `or` / `not`, never `&&` / `\|\|` / `!` |
| Quotes | double quotes, unless single quotes escape fewer characters |
| Comments | `# text` and `## doc text` start with a space; `#region`/`#endregion` do **not**; commented-out code has no space |
| Numbers | never `.234` or `13.` — write `0.234`, `13.0`; lowercase hex (`0xfb8c0b`); `_` separators above 1 000 000 (`1_234_567_890`) |
| Statements | one per line, the ternary `a if cond else b` being the only exception; omit parentheses unless needed for precedence or wrapping |
| Whitespace | one space around operators and after commas; no space inside `dict["key"]` or `print("foo")`; single-line dict literals get inner spaces: `{ key = "value" }`; never align with padding spaces |

Wrapping a long condition: use parentheses (not backslashes — the style guide prefers them because refactoring
does not have to police a trailing `\`), and put `and`/`or` at the *start* of the continuation line:

```gdscript
if (
		position.x > 200 and position.x < 400
		and position.y > 300 and position.y < 400
):
	pass
```

Line continuation with `\` is legal (`gdscript_basics.rst` "Line continuation") but the style guide disfavours it.
`#region NAME` / `#endregion` create foldable regions in the built-in editor; do not wrap a single function in one
(functions fold already), and note that external editors generally ignore them.

## Static typing syntax

```gdscript
var damage: float = 10.5
const MOVE_SPEED: float = 50.0

func sum(a: float = 0.0, b: float = 0.0) -> float:
	return a + b
```

The complete list of legal type hints (`static_typing.rst` "What can be a type hint"): `Variant` (any type; as a
*return* type it forces an explicit return); `void` (return position only); built-in types (`int`, `float`, `bool`,
`String`, `StringName`, `NodePath`, `Vector2`, `Color`, …); native classes (`Object`, `Node`, `Area2D`, …); global
classes declared with `class_name`; inner classes; global, native and custom named enums; and constants (including
local ones) holding a preloaded class or enum. **An enum type is just an `int`** — nothing guarantees at runtime
that the value is a member of the enum.

Two ways to name your own class as a type: `const Rifle = preload("res://player/weapons/rifle.gd")` then
`var my_rifle: Rifle`, or put `class_name Rifle` in `rifle.gd` and use `Rifle` anywhere with no preload.

**Covariance / contravariance.** Overrides may narrow the return type and widen a parameter type. If the parent
declares `func get_property(param: Label) -> Node:`, a child may declare
`func get_property(param: Control) -> Node2D:` — `Control` is a supertype of `Label`, `Node2D` a subtype of `Node`.
In 4.7, an override of a method whose base declares a typed return **inherits that return type**, so the override
must return a value on every path.

## `Array[T]` and `Dictionary[K, V]`

```gdscript
var scores: Array[int] = [10, 20, 30]
var vehicles: Array[Node] = [$Car, $Plane]
var array_of_arrays: Array[Array] = [[], []]
# var arrays: Array[Array[int]]  # ERROR: nested types are not supported.

var fruit_costs: Dictionary[String, int] = { "apple": 5, "orange": 10 }
var item_tiles: Dictionary[Vector2i, Item] = { Vector2i(0, 0): Item.new() }
# var dicts: Dictionary[String, Dictionary[String, int]]  # ERROR: not supported.
```

Rules that repeatedly trip agents up:

- `Array` ≡ `Array[Variant]`; `Dictionary` ≡ `Dictionary[Variant, Variant]`. For dictionaries **both** parameters
  must be written; use `Variant` explicitly to leave one open (`Dictionary[String, Variant]`).
- Typing applies to `for` loop variables and to some operators — `[]`, `[...] =`, and `+` for arrays. It does **not**
  apply to methods: `Array.front()`, `Array.back()`, `Array.map()`, and every value-returning `Dictionary` method
  still return `Variant`.
- Element types are a property of the *in-memory container*, not just of the variable. You cannot assign
  `Array[Node2D]` to an `Array[Node]` variable even though `Node2D` extends `Node` — `b = a` is an error, but
  `b.assign(a)` works because `Array.assign()` copies contents rather than the reference.
- Constants default to *untyped* arrays, so annotate when you want a typed one: `const A: Array[int] = [1, 2, 3]`.
- Since 4.2 you can type the loop variable without typing the array: `for name: String in names:`.
- Nested typed collections are a **syntax error**, not a warning.

Real 4.x examples here: `third_party/godot-demo-projects/3d/voxel/world/terrain_generator.gd`
(`Dictionary[Vector3i, int]` as a static return type) and
`third_party/godot-demo-projects/networking/websocket_chat/websocket/WebSocketServer.gd` (`Array[PendingPeer]`).

## Inference with `:=`, and where it fails

Style guide rule: **prefer `:=` when the type is written on the same line as the assignment; otherwise write the
type explicitly.** State the type when it is ambiguous; omit it when it is redundant.

```gdscript
var health: int = 0                # Good: 0 could have meant float.
var direction := Vector3(1, 2, 3)  # Good: obviously Vector3.
var health := 0                    # Bad: silently int.
var direction: Vector3 = Vector3(1, 2, 3)  # Bad: redundant.
var value := complex_function()    # Bad: reader cannot see the type.

# get_node() cannot infer unless the scene/file is loaded in memory, so inference is
# actively wrong here — the compiler only sees Node.
@onready var health_bar := get_node("UI/LifeBar")                 # Bad.
@onready var health_bar: ProgressBar = get_node("UI/LifeBar")     # Good: explicit.
@onready var health_bar := get_node("UI/LifeBar") as ProgressBar  # Good: cast supplies it.
```

For constants there is no difference between `=` and `:=`; Godot sets a constant's type from its value anyway.

## `is`, `as`, safe lines

`as` **silently yields `null`** on a type mismatch at runtime — no error, no warning. That makes the line "safe"
(green line number in the editor) but *less* null-safe:

```gdscript
@onready var node_1 := $Node1 as Type1  # Safe line, silently null if wrong.
@onready var node_2: Type2 = $Node2     # Unsafe line, but errors loudly at scene load.
```

The docs explicitly call `node_2` the more reliable of the two. Prefer `is` / `is not`, or `assert`:

```gdscript
func _on_body_entered(body: PhysicsBody2D) -> void:
	if body is not PlayerController:
		push_error("Bug: body is not PlayerController")
		return
	var player: PlayerController = body  # Narrowed; safe to use.
```

For `UNSAFE_PROPERTY_ACCESS` / `UNSAFE_METHOD_ACCESS` on a loosely typed reference, narrow with `is` and assign to
a typed local first (`if node_2d is MyScript:` → `var my_script: MyScript = node_2d`). To pull a property of unknown
type off an object without an `UNSAFE_CAST` warning, go through `Object.get()`, which returns `Variant` or `null`:

```gdscript
var label_variant: Variant = body.get("label")
if label_variant is Label:
	var label: Label = label_variant
	label.text = name
```

## `@export` variants (all verified present in 4.7's `@GDScript.xml`)

An exported variable must be initialised to a constant expression or carry a type specifier; some export annotations
imply the type themselves.

| Annotation | Signature | Effect |
|---|---|---|
| `@export` | — | Property is serialised into the scene/resource, shown in the inspector, and transferred over RPCs |
| `@export_range` | `(min, max, step, ...extra_hints)` | Slider. Extra hints include `"or_greater"`, `"or_less"`, `"exp"`, `"prefer_slider"`, `"hide_control"` |
| `@export_enum` / `@export_flags` | `(names, ...)` vararg | Dropdown from string names; bit-flag checkboxes |
| `@export_flags_2d_physics` / `_2d_render` / `_2d_navigation` / `_3d_physics` / `_3d_render` / `_3d_navigation` / `@export_flags_avoidance` | — | Layer pickers using the project's layer names |
| `@export_file` / `@export_dir` / `@export_global_file` / `@export_global_dir` / `@export_file_path` | filter varargs | Path pickers |
| `@export_multiline` / `@export_placeholder` / `@export_color_no_alpha` / `@export_exp_easing` | see XML | Multi-line box; ghost text; alpha-less colour picker; easing widget |
| `@export_node_path` | `(type, ...)` | `NodePath` restricted to given node types |
| `@export_group` / `@export_subgroup` / `@export_category` | `(name, prefix)` | Inspector organisation only |
| `@export_storage` | — | **Serialised but hidden** from the inspector; also copied by `Resource.duplicate()` / `Node.duplicate()`, unlike a plain `var` |
| `@export_custom` | `(hint, hint_string, usage)` | Raw hint/usage passthrough. **No validation is performed in GDScript** |
| `@export_tool_button` | `(text, icon)` | Exports a `Callable` as a clickable inspector button; pair with `@tool` |

```gdscript
@export_range(1, 100, 1, "or_greater") var ranged_var: int = 50
@export_node_path("Button", "TouchScreenButton") var many_buttons: Array[NodePath]
@export_custom(PROPERTY_HINT_NONE, "suffix:m") var suffix: Vector3
```

Annotation arguments may be any constant expression of the right type — except `@icon`, `@warning_ignore_start` and
`@warning_ignore_restore`, whose arguments must be **string literals**. Exported properties are editable in the
inspector even when the script is not `@tool`, but **setters and getters only run in the editor if it is**.

## `@onready` ordering hazards

`@onready` defers initialisation to just before `Node._ready()`. Member initialisation order
(`gdscript_basics.rst` "Initialization order"):

1. Default value by static type (`null` for untyped/objects, `0` for `int`, `false` for `bool`, …).
2. Initialisers run **top to bottom in source order** — except `@onready` ones, deferred to step 5.
3. `_init()`. → 4. Exported values applied (scene/resource instantiation). → 5. `@onready` variables initialise.
   → 6. `_ready()`.

Consequences an agent must respect:

- **Never combine `@onready` and `@export` on the same variable.** `@onready` runs *after* the exported value is
  applied and overwrites it. This produces `ONREADY_WITH_EXPORT`, which is **treated as an error by default**;
  the docs say do not disable or ignore it.
- Because plain initialisers run in source order, an initialiser that calls a method touching a later-declared
  member sees that member's *default*, and the later declaration then clobbers whatever the method wrote. Move
  the dependency above its user, or drop the redundant `= {}`.
- `@onready` only exists for `Node`-derived classes. A `Resource` or `RefCounted` gets steps 1–3 only.
- A variable's initialiser is written **directly** to the backing store: setters/getters are not called, even with
  `@onready` or `@export` present.

## `class_name`, `@icon`, inner classes, `@abstract`

```gdscript
@icon("res://interface/icons/item.png")
class_name Item
extends Node

@abstract
class_name Shape
extends Node2D
@abstract func draw() -> void
```

- `class_name` registers the type globally in the editor; no `preload` needed to use it as a type elsewhere.
- `@icon` must precede the class definition and inheritance, takes a **string literal**, and **does not work on
  inner classes**.
- Inner classes are declared with `class`, instantiated with `ClassName.new()`, and per the style guide use
  **single-line declarations**: `@abstract class MyNode extends Node:`.
- A script file loaded via `load()`/`preload()` is a `GDScript` resource; `const MyClass = preload("myclass.gd")`
  resolves at compile time, `load()` at runtime.
- `@abstract` (4.5+): an abstract class cannot be instantiated; an abstract method has no body, so a newline or `;`
  follows the header. Any class with at least one abstract method (its own or an unimplemented inherited one)
  **must itself** be `@abstract`; the converse does not hold. Inner and unnamed classes can be abstract too.
  Worked example: `third_party/beehave/addons/gdUnit4/src/GdUnitVectorAssert.gd`.

## Signals with typed parameters

`signal health_changed(old_value: int, new_value: int)`, emitted as `health_changed.emit(old_health, health)`.

- Emit with `Signal.emit(...)` and connect with `Signal.connect(callable, flags)` — the 4.x member-access form.
  `Object.emit_signal(name, ...)`, `Object.connect(name, callable, flags)` and `Object.disconnect()` still exist but
  take a `StringName` first and are the untyped path.
- Parameter names/types show in the editor's Signals dock and drive generated callbacks, but the docs are explicit:
  *"you can still emit any number of arguments when you emit signals; it's up to you to emit the correct values."*
  Treat signal parameter types as documentation plus editor tooling, not a runtime contract.
- Extra context goes through `Callable.bind()`; the bound values arrive as trailing parameters. Connect flags:
  `Object.CONNECT_DEFERRED`, `CONNECT_ONE_SHOT`, `CONNECT_PERSIST`, `CONNECT_REFERENCE_COUNTED`,
  `CONNECT_APPEND_SOURCE_OBJECT`. Real usage:
  `third_party/godot-demo-projects/networking/websocket_chat/websocket/WebSocketServer.gd`.

## Lambdas and `Callable`

`var square := func (x: int) -> int: return x ** 2`, called as `square.call(2)`.

- Referencing a function by name without calling it yields a `Callable` automatically.
- **Callables must be invoked with `Callable.call()`; the `()` operator is not available on them.** The docs state
  this is deliberate, "to avoid performance issues on direct function calls".
- Lambdas may be named for the debugger (`func my_lambda(x):`), and need an explicit `return` — there is no
  implicit last-expression return.
- **Locals are captured by value, once, at creation.** Reassigning the outer local afterwards does not update the
  lambda. Assigning inside the lambda shadows rather than writes through, and raises
  `CONFUSABLE_CAPTURE_REASSIGNMENT`. Reference types (arrays, dictionaries, objects) share *contents* until
  reassigned.
- `Callable.callv(array)` applies an argument array; GDScript has no spread syntax.

## `await`

- `await signal_or_coroutine` returns control to the caller and resumes on emission/completion. A function
  containing `await` is a coroutine, and callers who need its return value must `await` it too.
- Calling a coroutine and using its result without `await` is an error; calling it and *ignoring* the result is
  legal fire-and-forget and does not make the caller a coroutine. `await` on a non-signal non-coroutine returns
  immediately and does **not** make the function a coroutine.
- Awaited value shape: one signal parameter → that value; more than one → an `Array`; zero → `null`.
- Returning a signal from a non-coroutine makes the *caller's* `await` wait on it.
- There is no function-state object (unlike Godot 3's `yield`); this is deliberate, for type safety. Relevant
  warnings: `missing_await`, `redundant_await`.

## `assert`

```gdscript
assert(enemy_power < 256, "Enemy is too powerful!")
```

- `assert` is **compiled out of non-debug builds** — the expression is not evaluated in a release export.
  Therefore an assert condition must be **free of side effects**, or debug and release behaviour diverge. This is a
  shipping concern for us: the Steam build is a release export.
- In the editor, a failed assertion pauses the project. Warnings `assert_always_true` / `assert_always_false` catch
  constant conditions.

## Annotation reference (existence verified in `third_party/godot-class-reference/classes/@GDScript.xml`)

| Annotation | Notes |
|---|---|
| `@tool` | Script loads and runs in the editor. Must precede the class definition and inheritance. Guard editor-only branches with `Engine.is_editor_hint()` |
| `@icon(icon_path)` | Custom Scene-dock icon. Literal string only. Script-level only, not inner classes |
| `@static_unload` | Static variables do not persist once all references are dropped. Applies to the whole script including inner classes. **The class reference carries a standing warning: due to a bug, scripts are currently never freed even with this annotation.** Related warning: `redundant_static_unload` |
| `@abstract` | 4.5+. Classes and methods; see above |
| `@onready` | Node-derived classes only; see ordering hazards |
| `@warning_ignore(warning, ...)` | Suppresses on the **next statement** |
| `@warning_ignore_start(warning, ...)` | Suppresses to end of file or matching restore. Literal strings only |
| `@warning_ignore_restore(warning, ...)` | Ends a start-region; resets to project settings. Literal strings only |
| `@rpc(mode, sync, transfer_mode, transfer_channel)` | Multiplayer only |
| `@export…` | See the export table above |

Warning names match the project settings under `debug/gdscript/warnings/*`, e.g. `@warning_ignore("unused_variable")`
matches `debug/gdscript/warnings/unused_variable`. Annotations stack, one per line or several on one line, and
apply to the next non-annotation statement.

Warnings worth turning on for a typed codebase (Project Settings → Debug → GDScript, Advanced Settings on):
`untyped_declaration`, `inferred_declaration`, `unsafe_call_argument`, `unsafe_cast`, `unsafe_method_access`,
`unsafe_property_access`, `unsafe_void_return`, `inference_on_variant`, `get_node_default_without_onready`,
`integer_division`, `narrowing_conversion`, `shadowed_variable`, `return_value_discarded`, `standalone_expression`.
Any warning can be escalated to a hard error per-warning in the same settings page.

## Documentation comments

`##` above a member (or above its annotations) documents it; `##` at the top of the file documents the script, and
must precede all member documentation. Order inside a script docstring: brief line, blank `##` line, detailed
description, then tags. Tags: `@tutorial:` / `@tutorial(Title):`, `@deprecated` / `@deprecated: text`,
`@experimental` / `@experimental: text`. Members may carry `@deprecated` and `@experimental`. Documentable members:
signals, enums, enum values, constants, variables, functions, inner classes.

## What actually costs performance

The manual's framing, not folklore. Measure before acting: `Time.get_ticks_usec()` around a suspect block, run it
1000+ times and average, because timer granularity and CPU cache state dominate single runs
(`tutorials/performance/cpu_optimization.rst`).

### Typed vs untyped code paths — a real speedup, not just readability

`static_typing.rst`: *"typed GDScript improves performance by using optimized opcodes when operand/argument types
are known at compile time."* The win is compile-time — knowing both operand types lets the compiler emit a
specialised instruction instead of a generic Variant one. Typing therefore pays off exactly where the hot arithmetic
is, and it is why the untyped global math functions have typed counterparts. **Prefer the typed variants inside
loops**; the same page concludes they "ensure you have safe lines and benefit from typed instructions for better
performance":

- `abs()` → `absf()`, `absi()`, `Vector2.abs()`, `Vector3.abs()`, …
- `ceil()`/`floor()`/`round()` → `ceilf()`/`ceili()`, `floorf()`/`floori()`, `roundf()`/`roundi()`, plus the
  per-vector `Vector2.ceil()` family.
- `clamp()` → `clampf()`, `clampi()`, `Vector2.clamp()`, `Color.clamp()` (untyped `clamp()` does not work on
  `Color` at all).
- `lerp()` → `lerpf()`, `Vector2.lerp()`, `Quaternion.slerp()`, `Basis.slerp()`, `Transform3D.interpolate_with()`.
- `sign()` → `signf()`, `signi()`; `snapped()` → `snappedf()`, `snappedi()`.

Ceiling on all of this: every GDScript operation goes through the scripting API's lookup chain
(`data_preferences.rst`) — the class's own data, then each base class, up to `Object`. That indirection is why
`cpu_optimization.rst` says plainly that in GDScript "ease of use is considered more important than performance",
and why heavy numeric work belongs in engine-side calls (servers, built-in methods, `Curve`/`Tween`/physics) rather
than in a GDScript loop. Built-in engine functions run at the same speed regardless of scripting language.

### Array vs typed array vs packed array

Ordering from `gdscript_basics.rst` "Packed arrays" and the `PackedStringArray` / `PackedVector2Array` class docs:
**packed types (`PackedInt64Array`, `PackedVector2Array`, …) > `Array[T]` > `Array`** for iteration and
modification speed, and packed arrays also use less memory. Worst case, a packed array is *as fast as* an untyped
`Array`. If the element type is known (including your own classes), a typed array beats an untyped one; there is no
case where leaving it untyped is the faster choice.

The trade-off is API surface: packed arrays lack conveniences like `Array.map()`. The manual's own threshold —
below roughly tens of thousands of elements, prefer regular or typed arrays, because the convenience methods make
the code easier to write and can be faster if you use them a lot. Above that, or where memory fragmentation
matters, switch to a packed type if the element type fits.

Packed arrays are always passed by reference — but a packed array returned from a *built-in property or method* is a
copy, so mutate it and assign it back. In 4.7 setting one element of a packed-array property no longer invokes the
whole property's setter.

### Dictionary lookup

`Dictionary` is a `HashMap<Variant, Variant, ...>` (`data_preferences.rst`). Get / set / insert / erase **by key**
are the fastest operations — hash, then one offset computation, constant time. Iteration is fast and preserves
insertion order. Finding a key **by value** is the slowest case: a linear scan, and Godot does not ship a method
for it. It grows by powers of two from an initial 8 records and rebuilds on growth, so it deliberately trades memory for
speed. `Array` is the mirror image: index access is O(1), `find` is a linear scan.

Key choice matters. `int` comparisons are constant-time, string comparisons linear. `StringName` is *slower to
create* and can block on locks under multithreading, but is "extremely fast to compare" because equal names are the
same object — the class docs call it a good dictionary-key candidate. Hoist `&"literal"` StringNames out of loops.

### String building in loops

`String` is reference-counted and **copy-on-write: every modification returns a new `String`**. So `s += x` inside a
loop allocates each iteration. Accumulate into a `PackedStringArray` and join once:

```gdscript
var out := ""                        # Bad in a hot loop: one allocation per iteration.
for row in rows:
	out += str(row) + "\n"

var parts := PackedStringArray()     # Good: one join at the end.
for row in rows:
	parts.append(str(row))
var out := "\n".join(parts)
```

`String.join()` takes a `PackedStringArray`, which is why that is the natural accumulator. For formatting, the manual
prefers `%` format strings or `String.format()` over `+`: concatenation forces `str()` on every non-string operand,
offers no formatting control, and is usually less readable (`gdscript_format_string.rst` "String concatenation").

### `get_node` in `_process`

The explicit ranking from `tutorials/best_practices/godot_interfaces.rst`, with the doc's own labels:

```gdscript
get_node("Child")          # "Slow." String parsed into a NodePath on every call.
$Child                     # "Faster. GDScript only." — cached nodepath, still walks the tree.
@onready var child = $Child   # "Fastest." Resolves once.
@export var child: Node       # "Fastest", and survives moves in the Scene tree dock.
```

Never call `get_node()`, `$`, `%`, or `Node.find_child()` from `_process()` / `_physics_process()` — cache the
reference at `_ready` time. `%UniqueName` is sugar for `get_node("%UniqueName")` with the same per-call cost, and
resolves only within the same scene.

Adjacent cheap wins: turn processing off on idle nodes with `Node.set_process(false)` /
`Node.set_physics_process(false)` rather than early-returning inside the callback; batch deferred work with
`Object.call_deferred()` or `Object.CONNECT_DEFERRED` rather than polling.

## Godot 3 memories that are wrong here

Every left-hand item below is absent from the 4.7.1 class reference. Do not emit them.

| Godot 3 | Godot 4.7 |
|---|---|
| `export var x`, `onready var x`, bare `tool` | `@export var x`, `@onready var x`, `@tool` |
| `var x setget set_x, get_x` | `var x: set = set_x, get = get_x`, or inline `set(value): / get:` blocks |
| `yield(obj, "signal")` | `await obj.signal` — and there is no function-state object |
| `emit_signal("health_changed", a, b)` | `health_changed.emit(a, b)` |
| `connect("pressed", self, "_on_pressed")` | `pressed.connect(_on_pressed)` |
| `PoolStringArray`, `PoolByteArray`, … | `PackedStringArray`, `PackedByteArray`, … |
| `Reference`, `Spatial`, `KinematicBody2D` | `RefCounted`, `Node3D`, `CharacterBody2D` |

Other 4.x traps worth remembering: `int / int` is integer division (`5 / 2 == 2`); `%` is integers only, use
`fmod()` for floats and `posmod()` / `fposmod()` when you want a non-negative remainder; compare floats with
`is_equal_approx()` / `is_zero_approx()`, and use `is_same()` when operand types are uncertain.

## Pre-commit checklist for generated GDScript

1. Declarations in the canonical order; tabs; two blank lines between functions; lines under 100 chars.
2. Every `func` has parameter types and a `->` return type (`void` when it returns nothing).
3. No `@onready` on an `@export` variable. No `get_node`/`$`/`%`/`find_child` inside `_process`/`_physics_process`.
4. `:=` only where the type is obvious on the same line; explicit type on every `get_node()` result.
5. `is` / `is not` for narrowing, not bare `as`, unless a silent `null` is genuinely what you want.
6. Typed `Array[T]` / `Dictionary[K, V]` wherever the element type is known; no nested typed collections.
7. Typed math functions (`absf`, `clampi`, `lerpf`, …) inside loops.
8. No side effects inside `assert()`.
9. Signals named in the past tense; emitted with `.emit()`, connected with `.connect()`.
10. String accumulation goes through `PackedStringArray` + `String.join()`, not `+=` in a loop.
