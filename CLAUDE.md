# Working in this repository

Read this before proposing anything. Most of it exists because an assumption went
wrong once already.

## What we are building

A **desktop PC game, sold on Steam**. Windows and Linux (and therefore Steam Deck)
are the targets. **Not a web/HTML5 game. Not mobile. Not console.** The full target
list and the engineering consequences are in `docs/PLATFORM_TARGETS.md` — read it
before making any decision about renderers, threading, build size, input or storage.

**There is no game project in this repository yet, deliberately.** A previous concept
(ACCRETE, a 2D neon incremental) and its HTML5 build were deleted, not archived —
if you find a reference to `game/`, `play/`, `index.html`, `docs/GAME_DESIGN.md` or
"ACCRETE" anywhere, it is a stale reference and should be fixed, not followed. (The
files remain in git history if anything ever needs recovering.)

What this repository currently *is*: a vendored, indexed reference library for
building a Godot 4.7 game, waiting on a concept to be chosen.

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

## Verify your work — the container can check most of it

This repository is set up so claims can be checked rather than asserted. A cloud
container with no GPU can still import a project, boot it, render real frames through a
software rasterizer, and lint. `docs/CODESPACES.md` has the full picture; the short form:

```bash
tools/setup_environment.sh --verify        # what can this machine do?
tools/godot_smoke_test.sh <project> <scene>              # import + headless boot
tools/godot_smoke_test.sh <project> <scene> --render     # + render a frame, screenshot
gdlint path/to/file.gd                                   # style check
python3 tools/build_api_index.py && python3 tools/build_code_index.py
```

Before reporting that a change works: boot it, lint what you touched, and if the change
is visual, render it and actually look at the screenshot.

What the container **cannot** tell you: performance (software rasterization is orders of
magnitude off — profile on a Steam Deck), driver behaviour, audio output, or game feel.
When you could not check something, say so plainly instead of implying it was verified.

## Owner requirements

- **Controller-first.** The project owner plays on a controller, and Steam Deck is a
  target machine. Every interaction must work without a mouse — full menu and UI focus
  navigation, no mouse-only affordances, no precision-pointer-dependent mechanics.
- **Accessibility is a requirement, not polish.** Remappable inputs, no meaning conveyed
  by colour alone, legible text at 1280x800, and reduced-motion options.
- **No dedicated artist.** Art direction has to be achievable with engine primitives,
  shaders, procedural generation or CC0 assets.

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
- CI (`.github/workflows/godot-ci.yml`) regenerates the indexes and fails if the
  committed ones are stale. Re-run the generators and commit their output whenever you
  vendor something. When a game project lands, add a headless import/boot job to it.
- Controller parity and accessibility are project requirements, not polish. Steam Deck
  is a target machine.

## When you are unsure

Say so and cite what you checked. An honest "the class reference has no such method"
is worth more than a confident invention — and every claim in this repo is checkable
against files that are already on disk.
