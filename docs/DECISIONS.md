# Decisions

Append-only log of what has been settled and what is still open. **Read this before
proposing anything** — several of these were decided the hard way, and re-litigating them
wastes everyone's time.

Newest first. When a decision changes, add a new entry rather than editing an old one;
the reasoning behind a reversal is usually more useful than the reversal itself.

---

## IN PROGRESS — two demos, then a comparison

**Status: building. KEEPALIVE first, the reconstruction concept second.**

The owner picked two concepts to prototype and compare rather than committing to one:

1. **KEEPALIVE** — you never aim; you keep a dying machine alive from its cockpit,
   triaging power between weapons, coolant and servos while damage breaks specific
   components. Built in `game/` — see `../game/README.md`.
2. **The frozen instant** — a disaster stopped one second before it finished, which you
   walk through and rewind to establish what happened. Not started.

Each demo answers exactly one question. For KEEPALIVE it is "is triage under pressure
fun?"; nothing else in that build matters. The comparison happens on the owner's PC with
a controller, because feel is the one thing the container cannot judge.

Both were chosen after three earlier recommendations were rejected. The pattern in the
rejections was consistent and worth remembering: the first pitches led with **mediums and
technologies** rather than with a player, a fantasy and a reason to press retry. A concept
that opens with a rendering technique or a design pattern is not a game concept.

---

## SUPERSEDED — which game to build

**Status: undecided. Do not scaffold a game project yet.**

Two recommendations have been made and one has been rejected:

| Concept | Outcome |
| --- | --- |
| DRAGLINE — physics hauling roguelite, jointed trailers | **Rejected by the owner.** Scored 24/30 from a three-judge panel and was the only concept no judge voted against, but the owner did not want it. Not to be revived. |
| Deterministic hazard tactics — perfect-information grid tactics where the antagonist is a spreading hazard (fire, flooding, decompression) rather than enemy AI | **Proposed, not accepted.** |

The second proposal's argument, for whoever picks this up: strategy/tactics is the deepest
cluster in the resource catalogue (106 usable entries) and roguelite is second (90); the
design is controller-native because it is a grid cursor; turn-based removes feel risk; and
because it is deterministic with perfect information, **generated encounters can be
machine-proven solvable before they ship** — which turns CI into a design instrument. A
retro post-process (Ultimate Retro Shader Collection, MIT; GodotRetro, CC0) supplies a
committed art direction without an artist, and unifies mixed CC0 assets into one look.

Known competition: Flash Point: Fire Rescue occupies the turn-based-firefighting theme as
a dice-driven board-game adaptation, so a firefighting theme invites the comparison; other
hazard themes (derelict spacecraft decompression, reactor containment, flooding) appear
unoccupied but have not been searched properly.

Recorded concept exploration, including the four other concepts and all judge scoring, is
in `GAME_CONCEPT_DECISION.md`.

---

## SETTLED — development hardware reality

The owner has a PC with a high-end GPU and a controller. There is no Steam Deck and no
low-end test machine. Feel and visuals are testable; whether the median buyer can run the
game is not. See the hardware table in `PLATFORM_TARGETS.md`. Buy a Deck or a cheap low-end
laptop before shipping a demo, not before starting work.

---

## SETTLED — platform target: desktop PC, sold on Steam

Windows and Linux, therefore Steam Deck as a shipping target. **Not web, not mobile, not
console.** Full reasoning and engineering consequences in `PLATFORM_TARGETS.md`.

This was settled after the repository spent a period containing a Web-only export preset,
a published HTML5 build and an `index.html` redirect while stating its platform target in
no document at all — so everyone reading it, human and agent, concluded it was a browser
game. The lesson generalises: **if a fact is only encoded in configuration, it will be
misread.** Write it down.

---

## SETTLED — the ACCRETE concept and its web build were deleted

A 2D neon incremental called ACCRETE, its vertical slice under `game/`, its HTML5 build
under `play/`, the root `index.html`, and its design and balance documents were removed
outright rather than archived. They remain in git history if anything needs recovering.

Any reference to `game/`, `play/`, `index.html`, `docs/GAME_DESIGN.md`,
`docs/BALANCE_NOTES.md` or "ACCRETE" outside this log is a stale reference and should be
fixed, not followed.

---

## SETTLED — owner requirements

- **Controller-first.** The owner plays controller-only. Every interaction must work
  without a mouse. A design whose core input is precise pointing, drag-and-drop or heavy
  text entry is fighting the owner's own hardware.
- **Accessibility is a requirement, not polish.** Remappable inputs, no meaning carried by
  colour alone, legible text, reduced-motion options.
- **No dedicated artist.** Art direction must come from engine primitives, shaders,
  procedural generation, CC0 assets, or a deliberately minimal committed style.

---

## SETTLED — licensing policy

MIT / Apache-2.0 / BSD / ISC / zlib / Unlicense / CC0 / OFL / CC-BY (with attribution).
No GPL, LGPL, AGPL, CC-BY-SA, CC-BY-NC, CC-BY-ND, non-commercial terms, or unlicensed
repositories. Code and assets are licensed separately — an MIT repository can ship
non-free art, and `RESOURCES.md` flags 39 resources that are exactly that trap.

Every import gets a row in `../THIRD_PARTY_LICENSES.md` with its exact upstream commit.
