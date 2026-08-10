# GODOT-GAME

A Godot 4 game project, built on a foundation of the best freely licensed
Godot code available. The repository is structured so the game itself stays
cleanly separated from the reference code it learns from and borrows from.

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
docs/
  GODOT_CODE_SURVEY.md     Deep-dive survey: what every vendored project
                           teaches and what we reuse from it
  RESOURCES.md             Curated index of useful Godot information online
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
- [ ] Game design: concept not yet chosen
- [ ] Game: build in `game/` (vertical slice → systems → content → ship)

No game is currently in development. The previous concept was removed; the
foundation above is intact and ready for the next one. Design constraints
carried forward: no artist (procedural / primitives / CC0 art only),
controller-first with full parity from day one, and a solo part-time scope
of roughly 2–3 months.
