# Working in this repository

Read this before proposing anything. Most of it exists because an assumption went
wrong once already.

## What we are building

A **desktop PC game, sold on Steam**. Windows and Linux (and therefore Steam Deck)
are the targets. **Not a web/HTML5 game. Not mobile. Not console.** The full target
list and the engineering consequences are in `docs/PLATFORM_TARGETS.md` — read it
before making any decision about renderers, threading, build size, input or storage.

If you find a Web export preset, a `play/` directory or an `index.html` redirect in
this tree, those are leftovers from an abandoned experiment, not a statement of intent.

**The game concept is currently being re-chosen.** `game/` and `docs/GAME_DESIGN.md`
hold a previous concept (ACCRETE, a 2D neon incremental) that is no longer the plan.
Treat them as reference and prior art, not as requirements. Do not extend that game
unless explicitly asked.

## Engine version

Godot **4.7.1 stable**. CI downloads exactly that build. Everything vendored under
`third_party/godot-class-reference/` and `third_party/godot-docs/` is pinned to it.

## Never guess a Godot API — look it up, offline

The class reference for our exact engine version is in this repo. Use it. A remembered
API is the single most common failure mode here, because most Godot material in
training data is 3.x or early 4.x.

```bash
# which class has this member?
grep -i 'pitch_scale' library/api/symbols.tsv

# every member of one class, with signatures
grep -P '^GPUParticles2D\t' library/api/symbols.tsv

# does this class even exist in 4.7?
ls third_party/godot-class-reference/classes/CharacterBody2D.xml

# prose, rationale and tutorials
grep -rl 'object pooling' third_party/godot-docs/tutorials/
```

Before writing GDScript, skim `library/guides/api-changes-and-traps.md`. It catalogues
the APIs models reliably get wrong (`Spatial`, `KinematicBody`, `instance()`,
`yield`, the old `connect()` signature, `move_and_slide(velocity)` — all gone in 4.7).

## Repository layout

```
game/            The game project (currently a prior concept — see above)
library/         The agent-facing resource library
  api/           Generated lookup tables over the class reference (grep these)
  code/          Generated symbol tables over everything in third_party/
  guides/        Distilled Godot 4.7 knowledge, written against the vendored docs
third_party/     Vendored upstream code and references, licences intact
docs/            Project documents: platform targets, design, balance, code survey
tools/           Index generators and validators
```

## Finding existing code before writing new code

~150 Godot projects are already vendored. Search them before implementing anything:

```bash
grep -i 'state_machine' library/code/scripts.tsv   # which vendored scripts do this
cut -f1,2 library/code/addons.tsv                  # addons already available
grep -i 'shader' library/code/shaders.tsv          # 55 vendored shaders
```

`docs/GODOT_CODE_SURVEY.md` describes what each vendored project teaches.

Regenerate the tables after vendoring anything new:

```bash
python3 tools/build_api_index.py
python3 tools/build_code_index.py
python3 tools/build_resource_index.py     # --check to validate only
```

## Licensing rules — these are hard

- **Allowed code**: MIT, Apache-2.0, BSD, ISC, zlib, Unlicense, CC0, MPL-2.0 (flag it).
- **Allowed assets**: CC0, OFL (fonts), CC-BY (only with attribution recorded).
- **Forbidden**: GPL, LGPL, AGPL, CC-BY-SA, CC-BY-NC, CC-BY-ND, "free for
  non-commercial", "credit appreciated" with no formal licence.
- **A public repository with no LICENSE file grants no rights.** Do not import it.
- Code and assets are licensed **separately**. An MIT repo can ship non-free art.
- Every import gets a row in `THIRD_PARTY_LICENSES.md` with the exact upstream commit.
  `tools/build_resource_index.py` fails if a catalogued resource is missing from it.

## Conventions

- GDScript follows the official style guide; static typing everywhere it is possible.
  See `library/guides/gdscript-style-and-typing.md`.
- `.gd.uid` sidecar files are engine-managed. Do not hand-edit or delete them.
- CI (`.github/workflows/godot-ci.yml`) imports the project headlessly and boots its
  scenes on every push to `game/**`, failing on any script error. Keep it green.
- Controller parity and accessibility are project requirements, not polish. Steam Deck
  is a target machine.

## When you are unsure

Say so and cite what you checked. An honest "the class reference has no such method"
is worth more than a confident invention — and every claim in this repo is checkable
against files that are already on disk.
