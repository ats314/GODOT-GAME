# GODOT-GAME

A Godot 4 game project, built on a foundation of the best freely licensed
Godot code available. The repository is structured so the game itself stays
cleanly separated from the reference code it learns from and borrows from.

## Target platform

**Desktop PC, sold on Steam** — Windows and Linux, and therefore Steam Deck.
Not web, not mobile, not console. See `docs/PLATFORM_TARGETS.md` for the full
list and for the engineering decisions that follow from it (renderer choice,
threading, build size, input, storage).

There is no game project here yet. A previous concept and its HTML5 build
were deleted when the team reset; what remains is the reference library that
the next game will be built from.

## Repository layout

```
third_party/               Vendored snapshots of freely licensed Godot projects
  godot-demo-projects/     Official Godot demos (MIT) — ~120 projects: 2D, 3D,
                           GUI, audio, networking, shaders, saving, and more
  Godot-Game-Template/     Complete game shell: menus, options, pause, loading
  Starter-Kit-3D-Platformer/  Kenney starter game (MIT code, CC0 art)
  Starter-Kit-FPS/            Kenney starter game (MIT code, CC0 art)
  Starter-Kit-City-Builder/   Kenney starter game (MIT code, CC0 art)
  beehave/                 Behavior-tree AI addon (enemy AI)
  phantom-camera/          Camera addon (follow, transitions, juice)
  godot-open-rpg/          GDQuest open RPG (combat, inventory, dialogs)
  Terrain3D/               High-performance 3D terrain addon (GDExtension)
  ShaderV/                 Visual-shader node collection addon
  godot-class-reference/   Godot 4.7.1 class reference XML (1078 classes) —
                           the offline, authoritative API source
  godot-docs/              The Godot 4.7 manual as text (517 pages)
library/                   The agent-facing resource library
  api/                     Generated lookup tables over the class reference
  code/                    Generated symbol tables over everything vendored
  guides/                  Distilled Godot 4.7 knowledge, written against the
                           vendored docs and fact-checked against the class XML
tools/                     Index generators, environment setup, Godot smoke test
.devcontainer/             Codespaces: a container that can build, run and render
.claude/                   SessionStart hook so web sessions get the same toolchain
docs/
  PLATFORM_TARGETS.md      What we ship and on what — read before deciding
  CODESPACES.md            Working in a cloud container: what it can and cannot prove
  TESTING.md               Headless validation, measured rather than assumed
  GODOT_CODE_SURVEY.md     Deep-dive survey: what every vendored project
                           teaches and what we reuse from it
  RESOURCES.md             Curated index of useful Godot information online
CLAUDE.md                  Entry point for coding agents working here
THIRD_PARTY_LICENSES.md    Provenance and license record for everything vendored
```

## Engine

Target engine: **Godot 4.7.1 stable** (the vendored projects target 4.6/4.7).
Download: https://godotengine.org/download — or grab the headless Linux build
from the official GitHub releases for CI/validation.

To open any vendored demo: launch Godot, click **Import**, and select the
demo's `project.godot` (e.g. `third_party/godot-demo-projects/2d/dodge_the_creeps/project.godot`).

## Licensing

- Our own code (everything outside `third_party/`): **MIT** — see `LICENSE`.
- Vendored code: original licenses preserved in place, recorded in
  `THIRD_PARTY_LICENSES.md`. Everything vendored is MIT code; art in the
  Kenney kits is CC0.
- Policy: MIT/Apache-2.0/CC0 only; code and assets audited separately; no
  GPL source; every import recorded. See `THIRD_PARTY_LICENSES.md`.

## Status

- [x] Foundation: vendored free Godot code + license records + deep-dive survey
- [x] Offline Godot 4.7.1 reference + generated indexes + distilled guides
- [x] Platform target settled: desktop PC / Steam — `docs/PLATFORM_TARGETS.md`
- [x] Previous concept and its web build removed; repository is a clean library
- [ ] **Choose the game concept**
- [ ] Scaffold the project and add a headless import/boot job to CI
