# GODOT-GAME

A Godot 4 game project, built on a foundation of the best freely licensed
Godot code available. The repository is structured so the game itself stays
cleanly separated from the reference code it learns from and borrows from.

## Repository layout

```
game/                      The game (to be built) — our own MIT-licensed code
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
  CONSTRAINTS.md           What is actually a constraint on this project (and
                           what is not) — check design assumptions here first
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
- [x] Constraints established — see `docs/CONSTRAINTS.md` (only controller-only
      accessibility is a hard rule; art and everything else are open)
- [~] ~~Master game design: ACCRETE~~ — **rejected by the owner, 2026-08-09.**
      `docs/GAME_DESIGN.md` is retained for its research only. `game/` and
      `play/` are orphaned prototypes of a dead design.
- [ ] Direction: pick the next game, with the field no longer pre-filtered by
      the mistaken no-artist assumption
- [ ] Game: build it
