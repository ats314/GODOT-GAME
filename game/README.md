# ACCRETE — Milestone 1 vertical slice

> **Prior concept, not the current plan.** The team has reset and is choosing a new
> game. This slice is kept as working reference code — a shipped-quality example of
> autoloads, procedural SFX, upgrade cards and a wave director — not as the game in
> progress. Design: `../docs/GAME_DESIGN.md` (also superseded).
>
> Platform target for whatever we build next: **desktop PC via Steam**, see
> `../docs/PLATFORM_TARGETS.md`. The `Web` export preset in `export_presets.cfg`
> is a leftover from an abandoned HTML5 experiment.

Everything you destroy becomes part of your star.

## Run it

Open Godot 4.7.x → Import → select `game/project.godot` → press Play (F5).

## Controls

| Action | Controller | Mouse / keyboard |
| --- | --- | --- |
| Aim beam | Right stick | Move mouse |
| Fire beam | Right trigger or A | Hold left mouse button |
| Pick upgrade card | D-pad / stick + A | Click |
| Pause | Start | Esc |
| Restart run | Y | R |

Controller-first is a hard project requirement — every interaction must work
without a mouse (see design doc, grafted requirement #5).

## What's in the slice

Stationary star core with a mining beam; chaser/tank enemies in escalating
waves (every 5th is a surge); kills burst into shards that magnet into your
ring as mass; mass levels the ring; each level pauses for a 3-card upgrade
pick; auto-firing turrets crystallize onto the ring; neon glow (HDR 2D),
screen shake, multi-kill hit-stop; procedurally synthesized SFX (no audio
files); persistent best run; instant restart.

## Validation

CI (`.github/workflows/godot-ci.yml`) imports the project and boots both
scenes headless under Godot 4.7.1 on every push, failing on any script error.
