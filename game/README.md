# KEEPALIVE — demo 1 of 2

**You never aim. You keep a dying machine alive.**

You are sealed in the cockpit of something enormous. It fights on its own. Your job is
that it keeps working: the reactor makes power, and weapons, coolant and servos all want
more of it than there is. Weapons end the fight but make heat. Coolant removes heat but
does nothing to end the fight. Servos let you dodge, but only if you can spare the power.

Damage does not reduce a health bar — it breaks specific components, and they stay broken
until you spend time fixing them, during which you are not doing anything else.

## The question this demo answers

**Is triage under pressure fun?** Nothing else. If the answer is no, none of the rest
matters, and it took two days to find out rather than three months.

This is one of two demos being compared. The other is the "frozen instant"
reconstruction concept.

## Run it

```bash
tools/godot_smoke_test.sh game res://scenes/cockpit.tscn      # import + boot check
godot --path game                                            # play it
```

| Action | Controller | Keyboard |
| --- | --- | --- |
| Select system | LB / RB | ← / → |
| Move power to it | LT / RT | ↑ / ↓ |
| Repair (hold) | A | Space |
| Emergency heat vent | B | V |
| Restart | Y | R |

Repair is a **hold**, and letting go loses the progress. That is what makes fixing a fire
a bet against the next incoming shot rather than a chore.

Every incoming shot is telegraphed for 1.3 seconds. Evasion is read at the moment of
impact, not when the shot starts, so power moved during the telegraph genuinely counts.

## What the numbers say

Balance is the one thing about a game a GPU-less container can genuinely measure, so it
was measured rather than guessed. A scripted "competent player" policy
(`tests/sim_policy.gd`) plays hundreds of seeded engagements:

```bash
godot --headless --path game --script res://tests/balance_run.gd -- --runs=300
godot --headless --path game --script res://tests/balance_sweep.gd -- --runs=40
```

Current shipping numbers, 300 runs: **64% win rate, 115-second fights, 24% structure left
when you win.** `balance_run.gd` exits non-zero outside a 35–90% band, so CI can hold that
line. The sweep found those numbers — a grid over enemy HP and structure — rather than
anybody tuning by feel.

One finding worth keeping: the difficulty surface has a **cliff**, not a slope. Below ~480
enemy HP the scripted policy wins essentially every time, because the fight ends before
the enemy's fire rate ramps up. Danger comes from the clock, so fights have to last long
enough to reach it. If the fight ever gets shorter, the ramp has to get faster too.

## Layout

```
scripts/machine.gd      the machine: power, heat, damage, repairs. Pure logic, no nodes
scripts/engagement.gd   the fight outside, which you do not control. Seeded, reproducible
scripts/balance.gd      every number that decides fairness, in one place, swept by tests
scripts/cockpit.gd      the view and the input. Drawn entirely in code
tests/sim_policy.gd     scripted competent player, shared by the harnesses
tests/balance_run.gd    is the current build fair?
tests/balance_sweep.gd  which numbers would make it fair?
tests/capture.gd        render a frame and save a PNG, for checking visuals headlessly
```

`machine.gd` holds the rules and is expected to stay still. `balance.gd` holds the dials
and is expected to change constantly.

## Deliberately not here

No audio, no menu, no save, no progression, no second enemy, no persistent damage between
sorties. The persistent-damage idea — where you patch the machine badly between fights and
your bad patches become new failure modes — is the concept's real hook, and it is worth
nothing if the minute-to-minute triage is not already fun. That is the next thing to
build, not the first.

## Verified

- `gdlint` clean, `gdformat` applied
- Imports and boots headless with no script errors
- Renders under both OpenGL and Vulkan in a GPU-less container (`docs/CODESPACES.md`)
- Balance inside the target band across 300 seeded runs

**Not** verified: whether it is fun, how it feels on a pad, and anything about performance.
Those need the owner's PC and a controller.
