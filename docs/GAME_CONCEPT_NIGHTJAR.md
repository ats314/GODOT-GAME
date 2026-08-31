# NIGHTJAR — A Field Guide to Things That Aren't There

**Full game design.** A two-player couch co-op nature-documentation game, built
for a parent and a 7–8 year old to play together as equals, with a generative
image model as the art department.

This document supersedes the earlier CRYPTID FIELD GUIDE / CRYPTID CAMP concept
sketches. It keeps what survived design review — the art pipeline, the paper-and-ink
direction, the single-image animation tricks — and replaces the deckbuilder combat
layer, which failed review for a specific reason recorded in §13.

It is an alternative to `docs/GAME_DESIGN.md` (ACCRETE), not a replacement.
ACCRETE remains the lower-risk ship.

---

## 1. Pitch

You and your partner run a small field station at the edge of somewhere that
isn't properly mapped. Every night you walk out with lamps, lures, and a camera,
and try to document animals that officially do not exist. Every dawn you come
back and write up what you saw. Over a season, a blank guide becomes a
beautiful, complete, illustrated record of a place — and the guide is yours,
with your names in the front and your handwriting in the margins.

There is no combat. The opposition is that the animals are shy, the night is
short, and you don't yet know how they work.

## 2. The design spine: knowledge is the only skill

Every creature obeys a **fixed, discoverable, permanent rule set**. Moths come
to blue light and scatter from white. The ridgeback only surfaces after rain.
The thing in the bramble mimics the call of whatever ate it last, so if you hear
a fen-hare where no fen-hare lives, something else is there.

Nothing is randomized mystery. Nothing changes between seasons or between
players' games. A species' rules are true forever, which means what you learn is
real, transferable knowledge — you can tell a friend, write it down, or remember
it a month later and have it still be true.

This is the load-bearing decision, and everything else serves it:

- **Skill is remembering, not reflexes.** A 7-year-old who plays every night
  will out-know an adult who plays twice a week, inside a fortnight.
- **It cannot be faked.** No adult has to gently lose. When the kid says "not
  the white lamp, Dad" and he's right, he is genuinely, verifiably right, and
  everyone at the table knows it. That moment is the product.
- **It scales without difficulty settings.** See §8.

## 3. Players and roles

Two players, one screen, simultaneous, real-time-but-unhurried. Solo is
supported (you carry both kits and swap with a key) but the game is designed for
two.

The kits are **complementary and non-interchangeable**:

- **The Lure kit** changes the scene: lamps (four colours), scent bait, a call
  whistle, stillness. It draws creatures out but can never document them.
- **The Record kit** captures: camera, sound recorder, plaster cast, sketchbook.
  It documents but can never influence what appears.

So every single successful documentation is literally cooperative — one player
brings it out, the other takes the shot. Neither role is the assistant. Players
swap kits between nights.

Two further rules exist purely to force conversation:

- **Private knowledge.** Each player's guide records only what *they* have
  personally proven. You will know things your partner doesn't and have to say
  them out loud, in the moment, while it matters.
- **Shared disturbance.** Every action either player takes adds to one shared
  noise-and-light meter. Recklessness costs both of you. It is legible, fair,
  and teaches something true about being outdoors at night.

## 4. Structure

- **Season** — a campaign of ~20 nights, 10–15 hours, ending with the region's
  endemic: one rare animal that requires most of what you've learned.
- **Night** — one session, 25–40 minutes. Three to five hides before dawn.
- **Hide** — the core unit, 5–8 minutes. One painted location.

### 4a. Camp (≈3 min, start of night)

Read the weather and the moon (both matter to specific species). Choose the
night's route from the map. Load your kit: six slots drawn from your unlocked
pool of **Techniques**. Techniques are the curated mechanical layer — roughly
60–80 across the whole game, each distinct, each hand-authored. This is where
the planning lives, and both players build their own kit.

### 4b. The Hide (5–8 min, the core)

A layered painted scene. Creatures are present but hidden; you see only
**evidence** — a reed bending against the wind, eyeshine at the treeline, a
sound, a track in the mud. You act on the scene with Lure techniques; creatures
respond according to their rules; the Record player captures what emerges.

Documentation has four types, and they capture different things:

| Tool | Captures | Art treatment |
| --- | --- | --- |
| Camera | Appearance, patterning | Full-colour plate |
| Sound recorder | Call | Sonogram / hand-notated staves |
| Plaster cast | Tracks — proves presence without a sighting | Ink track study |
| Sketchbook | Behaviour — requires sustained watching without acting | Loose gesture sketches |

A species page needs three of the four to be complete. Partial pages are the
pull mechanic: an almost-finished page is the reason you come back tomorrow.

The sketchbook is deliberately the awkward one — it demands that a player do
*nothing* for an uncomfortable stretch while their partner works. It's the
mechanic that teaches patience without ever lecturing about it.

### 4c. Write-up (≈2 min, dawn)

The page assembles itself with an ink-bleed animation: plate, notation, tracks,
sketches, and a handwritten annotation generated from what actually happened
this night. **The player who first documented a species names it**, and that
name is permanent — it appears in the guide, in the index, and in the export,
forever. Authorship beats any reward mechanic at this age.

Proven traits become **knowledge entries** (permanent, consultable) and unlock
new Techniques.

### 4d. The margin hypothesis

At any time a player can write a guess in the margin of a page: *"I think it
comes to the blue lamp."* If a later night proves it, the margin note is inked
in and scores. Predicting correctly is the single best feeling available to a
7-year-old, and this mechanic exists only to manufacture it.

## 5. The rule vocabulary

All creature behaviour is composed from a shared vocabulary of ~30 rules, so
that knowledge compounds instead of being 200 special cases. Examples:

*attracted to <colour> light · repelled by <colour> light · surfaces only after
rain · emerges in the hour before dawn · flees above <noise> · mimics the call
of <species> · follows <species> · appears only when <species> is absent ·
responds to the whistle only if answered twice · will not cross open ground ·
comes to <scent> · masses at the new moon*

A common species gets 2 rules; the season endemic gets 5 that interact. Because
the vocabulary is shared, learning *"blue draws, white scatters"* on a moth pays
off later on something else entirely — which is what makes hour twenty feel
different from hour one without adding a single new system.

## 6. Failure

Dawn comes. That's the whole failure model, and it's real:

- A spooked creature is gone for that night.
- A wasted night is a night you don't get back — a season has finite nights.
- A season can end with an incomplete guide. That is a genuine, legible loss.

Nothing is ever destroyed, no one is ever punished, and the guide persists into
the next season. But it is possible to come home with nothing, and it has to be —
otherwise filling a page means nothing.

## 7. Progression

- **Within a night** — knowing who's out, in this weather, at this hour.
- **Within a season** — Techniques unlocked, routes opened, the guide filling.
- **Across seasons** — the guide is permanent and cumulative. New regions bring
  new rule combinations. **The Register** lists species reported but never
  documented — the long-tail chase.
- **The export** — the completed guide exports as a real multi-page illustrated
  document, both players' names on the title page, their species names and
  margin notes intact.

## 8. Difficulty without a difficulty setting

There is no easy mode, because an easy mode visible to an 8-year-old is an
insult and he will find it.

Instead, **the challenge is self-selected through target choice.** A 2-rule
marsh-hopper and a 5-rule endemic sit in the same hide on the same night. The
adult chases the hard one; the kid chases three easy ones and fills more pages.
Both are playing the same game at full strength, and the kid's page count is
frequently higher — which is the correct outcome and requires nobody to pretend.

The related design rule, stated so it doesn't get lost: **the adult must not be
able to rescue a failing turn.** Separate kits, private knowledge, simultaneous
action. If dad *can* bail him out he will, the kid will notice, and the game
becomes something performed at him rather than played with him.

## 9. Ages

- **7–8, the target.** Reads independently; wants to win and can accept losing;
  rules-lawyers happily; understands rarity and trade; 30–45 minute sessions;
  detects condescension instantly. Everything above is tuned here.
- **6 and under, supported by the fiction not by a mode.** Hand the child the
  Record kit and let the adult run lures. The child's job becomes "point and
  take the picture when it comes out," which is complete and satisfying on its
  own, while the adult carries the systems. No rules change; no toggle exists.
- **9+ / adults solo.** The endemics and the Register are the long game.

## 10. Art direction

Naturalist watercolour and ink on aged rag paper — Audubon and Haeckel by way of
a slightly haunted expedition journal, warmed and rounded for the audience.
Muted paper base, iron-gall line, restrained washes, one saturated accent per
region. Chosen for three engineering reasons as much as taste:

- **It hides model inconsistency.** Watercolour bleed, paper tooth, and
  hand-lettering absorb the small incoherences that make generated art read as
  generated. A crisp vector or photoreal style exposes every one.
- **It composites cleanly.** Ink-on-paper subjects cut out reliably and sit
  believably over any other paper element.
- **It's a moat.** Nobody ships this look, because 200 hand-painted plates is
  unaffordable. That's exactly the gap generative art opens.

**Four treatments per species multiplies apparent variety for free.** The same
creature appears as a colour plate, a sonogram, a track study, and gesture
sketches — four distinct assets, four distinct prompt templates, one design.

### Making stills move

No creature ever needs a second drawn frame:

1. **Single-image Skeleton2D warp** — a 4–6 bone rig over a Polygon2D textured
   with the plate: breathe, emerge, startle, retreat. Highest-leverage trick in
   the project. **Design rule: creatures are always presented frontally or in
   profile, never turning** — the warp breaks on limb occlusion, and this must
   be a rule now rather than a discovery in month three.
2. **Layered parallax hides** — subject, mid-reeds, foreground grass generated
   separately and offset; lamp light rakes across the layers.
3. **Particles and light do the acting** — spore drift, moth swarms, rain,
   lamp-glow, the disturbance meter's rising mist.
4. **Ink-bleed transitions** — page turns dissolving through generated
   paper-fibre noise.

## 11. Production pipeline

The game is downstream of the pipeline. **Build the pipeline first.**

**a. Style bible.** One locked prompt preamble (medium, palette, lighting,
paper, framing, negative constraints) plus 3–5 hand-picked reference plates used
as conditioning on every generation. Consistency comes from reference images and
a fixed preamble, not from asking nicely. Note the known limit: palette-clamping
unifies colour but does nothing for linework weight or rendering density, which
is where cross-batch drift actually shows — so drift is caught at review, not
post-processed away.

**b. Content as data.** `content/species/*.json` — name, region, rules (from the
§5 vocabulary), rarity, and four `art_prompt` fields, one per treatment. One row
per species, versioned in git beside the rules it describes.

**c. Generation harness.** `tools/genart.py` — composes preamble + row prompt +
reference plates, calls the image API, writes `art/raw/<id>/<treatment>/v<N>.png`,
and appends model, prompt, seed, and timestamp to `art/provenance.jsonl`.
Append-only; any plate can be rolled back.

**d. Ingest.** `tools/ingest.py` — background removal, alpha trim, canonical
resize, palette clamp toward the bible's ramp, shadow bake, atlas packing, and
emission of Godot `.import` settings plus one `.tres` per species. Adding a
species becomes: one JSON row, four plates, one command.

**e. Human gate.** Over-generate 4–6 variants and pick from contact sheets in
batches of 40. Generation is cheap; picking is where quality comes from.
Automate everything except the picking.

**f. In-engine validator.** A scene that loads every species resource, renders
all four treatments, and screenshots a grid — catches missing art, bad alpha,
wrong dimensions, and off-palette plates before they reach a build.

### The real cost is design, not generation

Roughly 200 species × 4 treatments × 5 variants ≈ 4,000 generations. That is
cheap, and reviewing it is perhaps 10 hours of contact sheets. **The actual cost
is ~15 minutes of design per species** — rules, rarity, placement, annotation
voice — which is ~50 hours for 200 species before any balance pass. Budget that
number, not the API bill. The pipeline solves the cheap problem; nothing solves
the expensive one except doing it.

## 12. Reuse from vendored code

- `Godot-Game-Template/` — menus, options, pause, save/load, loading screens.
- `godot-open-rpg/` — inventory and data-driven resource patterns for kits,
  Techniques, and the guide.
- `godot-demo-projects/` — Skeleton2D rig, GPUParticles2D, 2D glow, shader
  transitions, FastNoiseLite for paper/weather/maps.
- `phantom-camera/` — hide framing, the push-in when something emerges.
- Genuinely new: the art pipeline (Python, outside the engine), the rule
  evaluator, and the guide export. None carries engine risk.

## 13. What changed after review, and why

The predecessor concept was a monster-collecting **deckbuilder**. It failed
review on one structural point worth preserving here:

> A deckbuilder's quality comes from curation, not count — past ~150 cards the
> marginal card is filler that dilutes every draw. But the entire justification
> for a generative art pipeline was *unlimited unique images*. The genre
> actively punished the thing the pipeline was good at.

NIGHTJAR resolves this by **splitting volume from curation**. Creatures are the
collection: unbounded, and each needs only a picture, a call, a name, and 2–5
rules drawn from a shared vocabulary — no balance pass, no per-creature card
effect. Techniques are the mechanical layer: ~70, hand-authored, curated hard.
Volume goes where volume is wanted.

Also cut in review: the trait→card-effect compiler (a design trap — it either
emits generic effects or you hand-author anyway), and capture-method-dependent
effects (3× the design work for something players won't perceive).

## 14. Scope

1. **Pipeline spike — 1 week.** Style bible plus 12 species end-to-end through
   ingest into a rendered grid, all four treatments. **Kill criterion: if the 12
   don't look like one artist made them, fix the bible before writing game
   code.**
2. **Vertical slice — 3 weeks.** One region, 12 species, 3 hides, 15 Techniques,
   full night loop with two-player kits and the write-up.
3. **Systems — 4 weeks.** Rule evaluator, margin hypotheses, season structure,
   disturbance meter, knowledge entries, guide export.
4. **Content — 6 weeks.** Scale to 3 regions, ~120 species, ~70 Techniques.
   Throughput-bound, which is why step 1 comes first.
5. **Ship.** The export is the marketing engine.

## 15. Risks

- **Two-controller requirement** pins the platform and cuts the addressable
  audience. Solo must be genuinely good, not a courtesy — validate it in the
  slice, not at the end.
- **Real-time may be wrong.** Turn-based hides would suit the shared-attention
  dynamic of a parent and child better and would make the sketchbook's enforced
  stillness less awkward. This is the single biggest open question in the design
  and should be prototyped both ways in the vertical slice.
- **Reading load.** A 7-year-old reads, but not fluently under time pressure.
  Every rule must have an icon form; text is confirmation, never the only
  channel.
- **Tedium at volume.** 120 species built from 30 rules risks feeling
  combinatorial rather than authored. Mitigate with hand-written annotation
  voice per species and a variation axis in the JSON.
- **Store policy and sentiment.** Steam requires AI-content disclosure;
  `art/provenance.jsonl` exists to make that disclosure factual and complete,
  and the model's commercial terms belong in `THIRD_PARTY_LICENSES.md`. A
  segment of players will object regardless. The honest posture is disclosure
  plus visible craft.
- **The export screenshots badly.** A filled guide reads as a grid of small
  images — which is what a skeptical viewer thinks generated art looks like.
  Market with the *page-assembly animation* and the naming moment instead.
