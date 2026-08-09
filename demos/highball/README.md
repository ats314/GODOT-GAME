# HIGHBALL — playable vertical slice

*Railroad term: "proceed at maximum authorized speed."*

A freight train that cannot stop. Everything that goes wrong has to be fixed
while it runs, and the only way to save the train is to cut cars off the back —
including, if you panic, the one car you need to win.

## Run it

**On your own machine** — open Godot 4.7.x → **Import** → select
`demos/highball/project.godot` → **F5**. Or `godot --path demos/highball`.

**In a Codespace** — create one on this branch and the devcontainer installs the
pinned engine for you (`.devcontainer/devcontainer.json` →
`tools/setup_environment.sh`). Then:

```bash
~/.cache/godot-bin/Godot_v4.7.1-stable_linux.x86_64 --path demos/highball
```

Open the forwarded **port 6080** ("Godot editor (noVNC)", password `godot`) and the
game window is on that desktop. Be warned: a Codespace has no GPU, so this renders
through Mesa's software rasterizer — expect single-digit frame rates. It is enough
to confirm the demo runs and to look at it. It is **not** enough to judge how it
feels, which is the entire question this slice exists to answer
(`docs/CODESPACES.md` is explicit about this line).

**Verify it headlessly** — no display needed, and this is what CI runs:

```bash
tools/godot_smoke_test.sh demos/highball res://scenes/main.tscn
tools/godot_smoke_test.sh demos/highball res://scenes/main.tscn --render   # saves a frame
```

## Controls

| Action | Keyboard / mouse | Controller |
| --- | --- | --- |
| Move | WASD | Left stick |
| Look | Mouse | Right stick |
| Run | Left Shift | L3 |
| Repair (hold) | E | A |
| Cut coupling (hold) | F | X |
| Restart | R | Y |
| Release mouse | Esc | Start |

Full controller parity, no twitch input, nothing to mash — per
`docs/CONSTRAINTS.md`.

## What is actually implemented

- **A twelve-car train you walk end to end**, built from primitives at runtime:
  window openings, open gangway plates between cars, a maintenance station in
  every car, a generator in the engine and the payload crate in car 8.
- **The world moves, not the train.** The consist sits at the origin and
  scenery is recycled past it — no drift, no streaming, and the player's
  physics never has to reconcile with a moving platform. Sleepers carry the
  speed read; poles, scrub and two parallax ridge layers carry the distance.
- **Three fault types that behave differently.** Fire drains fuel and, left for
  thirty seconds, burns the car out permanently and spreads to another.
  A seized bearing adds drag that *grows the longer you ignore it*. A coolant
  leak overheats the plant and cuts power everywhere, which you see as the
  interior lights dimming and flickering car by car.
- **Cutting couplings.** Hold F/X inside the car ahead of a coupling to drop
  everything behind it: less drag, less fuel burn, more speed — and whatever
  was back there is gone for good.
- **The payload rule.** Car 8 carries the gear that relights the plant. Cut it
  and the run continues exactly as before, except you can no longer win. The
  HUD says so, and the ending changes to *YOU ARRIVED EMPTY*.
- **Both endings.** Reach 4 km with the payload → **HIGHBALL**. Stall for three
  seconds, get caught by whatever is behind you, or arrive without the payload
  → you lose.
- **Vibration and slipstream.** The camera shake scales with speed and roughly
  doubles out on the plates, where a lateral gust also shoves you around.

## Balance

Tuned so a clean run with the whole consist arrives with roughly 10% fuel left.
That means one untended fire is a genuine threat, and cutting cars is a real
fuel strategy rather than pure loss — which is the tension the design is
about. `TARGET_DISTANCE`, `MAX_TRACTIVE` and the burn curve are all constants
at the top of `scripts/main.gd`.

## Tests

```
~/.cache/godot-bin/Godot_v4.7.1-stable_linux.x86_64 \
    --headless --path demos/highball res://scenes/soak.tscn
```

Runs three headless phases at 40× time scale and asserts that all three
endings are reachable: a clean run wins, a starved plant stalls, and a run that
drops the payload arrives but does not win. Prints `SOAK PASS` on success and
exits non-zero on failure. CI gates on it.

## What this slice does not do

No audio, no crew NPCs, no route choice, no boarders, no cargo trading at
speed, no exterior traversal along the hull. Art is untextured primitives —
that is a prototyping choice, not the art direction (`docs/CONSTRAINTS.md`);
dressing the interiors with the vendored Kenney kits is a later job.

The question this slice exists to answer is narrower: **is walking a train
that cannot stop, triaging faults against a fuel clock, and deciding what to
cut, fun for ten minutes?**
