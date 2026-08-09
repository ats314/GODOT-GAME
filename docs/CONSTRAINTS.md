# Project Constraints — what is actually true

This file exists because a constraint that was never stated got treated as
fact. Every design doc in `docs/` must check its assumptions against this
file, and anything asserted as a constraint anywhere else in the repo without
a source here should be treated as an assumption, not a rule.

## Real constraints (owner-stated)

1. **Controller-only accessibility — hard.** The project owner plays
   controller-only. Every game concept must have full controller parity from
   day one: no mouse-only interactions, no forced twitch input, no
   hold-and-mash, every menu and card d-pad navigable with visible focus. This
   is the one requirement no design may trade away.

## Explicitly NOT constraints

- **Art is not a constraint.** Drawn sprites, purchased asset packs,
  commissioned work, 3D models, and hand-made animation are all available.
  Choose an art direction because it serves the game, not because it avoids
  making art.
- **Nothing else is off the table** either — genre, dimensionality, engine
  features, budget lines, or scope. Constraints on any of these must be
  recorded here, with their source, before a design doc may cite them.

## Corrected assumption (2026-08-09)

`docs/GAME_DESIGN.md` asserted "our no-artist constraint" and every later doc
inherited it. It was never sourced to the owner — unlike the controller
requirement, which is tagged as owner-stated. The owner has since confirmed
that **literally nothing is off the table**.

Consequences worth acting on:

- The neon-vector direction in ACCRETE and CAUSTIC stays valid — it is a good,
  cheap, fast look that suits both games — but it is now a *choice* those docs
  defend on merit, not a workaround. Both have been reworded.
- The whole idea bank (ACCRETE, LARIAT, DEAD WAX, DEATHSTEP, FLOCKFALL,
  CAUSTIC) is 2D vector abstraction, because that is what the assumption
  allowed. That is a selection bias, not a conclusion.
- Roughly half of the vendored foundation is 3D and entirely unused by every
  concept so far: `Terrain3D`, `Starter-Kit-3D-Platformer`, `Starter-Kit-FPS`,
  `Starter-Kit-City-Builder` (all Kenney, MIT code + CC0 art),
  `phantom-camera`, and `godot-open-rpg`. Concepts built on these should get a
  fair hearing — the next design pass should include at least one.
