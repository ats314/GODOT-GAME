# ACCRETE — Milestone 1 vertical slice

Everything you destroy becomes part of your star. Design: `../docs/GAME_DESIGN.md`.

## Run it

Open Godot 4.7.x → Import → select `game/project.godot` → press Play (F5).

## Controls

| Action | Controller | Mouse / keyboard |
| --- | --- | --- |
| Aim beam | Right stick | Move mouse |
| Fire beam | Right trigger or A | Hold left mouse button |
| Browse upgrade cards | D-pad / stick | Move mouse |
| Read a card in full | A | Click the card |
| Take the upgrade | A on TAKE THIS | Click TAKE THIS |
| Back out of a card | B | Esc, or click BACK |
| Pause | Start | Esc |
| Restart run | Y | R |

Controller-first is a hard project requirement — every interaction must work
without a mouse (see design doc, grafted requirement #5).

## What's in the slice

Stationary star core with a mining beam; chaser/tank enemies in escalating
waves (every 5th is a surge); kills burst into shards that magnet into your
ring as mass; mass levels the ring; each level pauses for a 3-card upgrade
pick, where every card names the system it changes, shows the live before/after
of the stat it moves, and expands to a full explanation before you commit;
auto-firing turrets crystallize onto the ring; neon glow (HDR 2D),
screen shake, multi-kill hit-stop; procedurally synthesized SFX (no audio
files); persistent best run; instant restart.

## Validation

CI (`.github/workflows/godot-ci.yml`) imports the project and boots both
scenes headless under Godot 4.7.1 on every push, failing on any script error.
