# Godot 4.7 guides

Dense, checkable references for writing Godot 4.7.1 GDScript in this project. Written
against the vendored class reference and manual rather than from memory, so every claim
can be re-verified against files already on disk.

## Which one do you need?

| Your question | Read |
| --- | --- |
| "Is this API real in 4.7?" / generated code uses `Spatial`, `yield`, `instance()` | [api-changes-and-traps.md](./api-changes-and-traps.md) |
| "How should this script be written?" — typing, naming, annotations, declaration order | [gdscript-style-and-typing.md](./gdscript-style-and-typing.md) |
| "Why is this slow?" / "should I optimise this?" / object pooling, MultiMesh, servers API | [performance.md](./performance.md) |
| "How should this be structured?" — nodes vs resources, autoloads, signals, saves | [scene-architecture.md](./scene-architecture.md) |
| "Which renderer?" / shaders, glow, materials, viewports, custom drawing | [rendering-and-shaders.md](./rendering-and-shaders.md) |

**Start with `api-changes-and-traps.md` before writing any GDScript.** Most Godot material
in model training data is 3.x or early 4.x, and that file catalogues what a model
reliably gets wrong.

## Not written yet

Three planned guides do not exist: **input and accessibility**, **audio**, and
**export and shipping to Steam**. Until they do, go to the source:

```bash
grep -rl 'input\|accessibility' third_party/godot-docs/tutorials/
grep -P '^AudioStreamPlayer\t' library/api/symbols.tsv
ls third_party/godot-docs/tutorials/export/
```

## How to verify anything these say

```bash
grep -i 'some_method' library/api/symbols.tsv        # which class owns it, and its signature
ls third_party/godot-class-reference/classes/Foo.xml # does the class exist in 4.7.1?
grep -rl 'topic' third_party/godot-docs/tutorials/   # the official prose
```

The class reference is taken from the engine's own `4.7.1-stable` tag, so it is
authoritative for our exact version. If a guide and the class reference disagree, the
class reference wins and the guide is a bug — fix it.

## Known limitations

These were machine-generated and then checked for API correctness and path validity. They
have **not** been through a cross-linking and de-duplication pass, so some topics are
covered in more than one file. Performance magnitudes are marked `[doc]` when the manual
states them and `[measure]` when they are folklore you must verify yourself; treat
`[measure]` claims as untested. Each guide ends with an explicit list of what its author
could not verify — read it.
