# Project Constraints — what is actually true

This file exists because a constraint that was never stated got treated as fact,
propagated through every design document, and quietly narrowed the field of games
this project would consider. Any document asserting a constraint without a source
here is stating an assumption, not a rule.

## Real constraints (owner-stated)

1. **Controller-only accessibility — hard.** The project owner plays
   controller-only. Every concept must have full controller parity from day one:
   no mouse-only interactions, no forced twitch input, no hold-and-mash, every
   menu and card d-pad navigable with visible focus.
2. **Desktop PC via Steam** is the platform target — see `docs/PLATFORM_TARGETS.md`.

## Explicitly NOT constraints

- **Art is not a constraint.** Drawn sprites, purchased asset packs, commissioned
  work, 3D models and hand-made animation are all available. The owner's words:
  *"Literally nothing is off the table."* Choose an art direction because it
  serves the game, not because it avoids making art.
- Nothing else is off the table either — genre, dimensionality, engine features,
  budget, scope. New constraints must be recorded here, with their source, before
  a design document may cite them.

## The assumption, and where it still survives (2026-08-09)

The deleted `docs/GAME_DESIGN.md` asserted *"our no-artist constraint"* and every
document downstream inherited it. It was never sourced to the owner — unlike the
controller requirement, which was always tagged as owner-stated. When asked
directly, the owner confirmed nothing is off the table.

**It has already recurred.** `docs/GAME_CONCEPT_DECISION.md` describes this as
*"a team that has explicitly declared it has no visual designer"* and treats that
as a fixed input when weighing DRAGLINE's asset-flip risk — the single strongest
argument against the concept it selects. That premise is not established. Whether
the owner wants to commission art is a decision the owner has not been asked to
make, and DRAGLINE's art risk should be re-weighed once they have.

What the assumption cost while it was unexamined: every concept generated under it
was a low-art abstraction, which is a selection bias rather than a conclusion.
