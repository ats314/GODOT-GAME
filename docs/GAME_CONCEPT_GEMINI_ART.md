# Game Concept — CRYPTID FIELD GUIDE

**An art-first concept designed around a generative image model (Gemini) as the
art department, and Claude as the engineer.** This is a deliberate counterweight
to `docs/GAME_DESIGN.md` (ACCRETE), which was chosen *because* it needs zero
drawn sprites. This concept assumes the opposite constraint: unlimited unique
still images, near-zero hand animation.

---

## 1. The design rule that comes first

An image model is extraordinary at **one-off, unique, high-detail stills** and
bad at **coherent motion across frames**. A 12-frame run cycle of the same
character, consistent to the pixel, is the hardest thing to ask for and the
least valuable per token. A gallery of 300 creatures that no human team could
afford to paint is the cheapest thing to ask for and the most valuable per
token.

So the genre must satisfy: **content volume scales with unique images, not with
animation frames.** That points at card games, creature collectors, illustrated
adventures, and shop/management games — not platformers or beat-em-ups.

## 2. Pitch

**CRYPTID FIELD GUIDE** is a monster-collecting deckbuilder that takes place
entirely inside a naturalist's hand-painted field journal. You are a cryptozoologist
surveying biomes for creatures that officially do not exist. Combat is a card
battle fought on the open journal spread; every creature you catalogue becomes a
new illustrated page, and that page *is* its card. Fill the guide, and the guide
itself is your save file, your deck, and your score.

The hook is bibliographic, not mechanical: **your run produces a physical
artifact.** At the end you can export your completed field guide as a real
multi-page document — every creature you found, illustrated, annotated with the
handwritten notes the game generated from how you actually beat it. That export
is the shareable object, the same way ACCRETE's time-lapse GIF was.

## 3. Why this fits an image model exactly

| Asset class | Volume | What it costs to generate | Animation needed |
| --- | --- | --- | --- |
| Creature portraits | 200–400 | 1 image each | None — parallax + skew only |
| Biome backdrops | 12–20 | 1 image each, layered | Parallax scroll |
| Item / relic icons | 150+ | 1 small image each | None |
| Journal page textures, ink borders, wax seals, map fragments | 60+ | 1 each | None |
| UI frames, card backs, buttons | 30 | 1 each, 9-slice | None |

Every single one is a still. The *entire* content budget is images the model is
best at, and the thing it is worst at (frame-consistent motion) appears nowhere
in the requirements.

## 4. Making stills move (the tech that earns the look)

Cards must feel alive or the game reads as a slideshow. Four techniques, all
already covered by vendored code, none requiring a second drawn frame:

1. **2.5D card parallax.** Generate each creature on a transparent background,
   composite over a separately-generated habitat plate. Two layers offset against
   card tilt gives real depth. Cursor-driven tilt with a specular sweep shader
   is the "holo card" feel players screenshot.
2. **Skeletal warp on a single image.** A 4–6 bone Skeleton2D over a Polygon2D
   textured with the portrait — breathe, lunge, recoil, death-slump. One image,
   full attack animation. This is the single highest-leverage trick in the whole
   pipeline; `third_party/godot-demo-projects` covers the rig.
3. **Particles and lighting do the acting.** Impacts, ink splatter, spore drift,
   glow on ability activation (GPUParticles2D + WorldEnvironment glow).
4. **Ink-bleed transitions.** Page turns as shader-driven dissolve through a
   generated paper-fiber noise mask.

## 5. Core loop

- **Survey (2 min).** Pick a biome page. Move a token across a generated map
  fragment, choosing between encounter / cache / rumor nodes.
- **Encounter (3–5 min).** Card battle on the journal spread. Your deck is the
  creatures already catalogued; the enemy is the one you're trying to document.
  You win not by killing it but by *filling its page* — each card played that
  reveals a trait (diet, gait, call, spoor) inks in part of the illustration.
  The page completes, the creature is yours.
- **Catalogue (30 s).** The new page is bound into the guide. It generates a
  handwritten annotation from the actual fight ("subdued at dusk; responds to
  bell-tones; three specimens observed"). Its traits become card effects, so
  *how* you caught it shapes what it does for you.
- **Expedition (45–60 min).** A run is one expedition, ~15 encounters, a
  regional endemic as the boss. Death is "the expedition was recalled" — you keep
  the guide, lose the deck. Meta-progression is the permanent guide filling up
  across runs, plus unlocked equipment and biomes.

## 6. Art direction

Naturalist watercolour and ink on aged rag paper — Audubon and Haeckel by way of
a slightly haunted 1890s expedition journal. Muted paper base, iron-gall ink
line, restrained washes, one saturated accent per biome. This style is chosen
for three engineering reasons, not just taste:

- **It hides model inconsistency.** Watercolour bleed, visible paper tooth, and
  hand-lettered annotation absorb the small incoherences that make AI art read as
  AI art. A crisp vector or photoreal style would expose every one.
- **It composites cleanly.** Ink-on-paper subjects cut out reliably and sit
  believably over any other paper element.
- **It is a moat.** Nobody ships this look, because it is prohibitively expensive
  to paint 300 plates by hand. That is precisely the gap generative art opens.

## 7. Production pipeline (the actual engineering work)

The game is downstream of the pipeline. Build the pipeline first.

**a. Style bible.** One locked prompt preamble (medium, palette, lighting, paper,
framing, negative constraints) plus 3–5 hand-picked reference plates used as
conditioning on every generation. Consistency comes from reference images and a
fixed preamble, not from asking nicely.

**b. Content as data.** `content/creatures/*.json` — name, biome, traits, stats,
and an `art_prompt` field. One row per creature. The prompt is content, versioned
in git alongside the stats it describes.

**c. Generation harness.** `tools/genart.py` — reads the JSON, composes
preamble + row prompt + reference plates, calls the image API, writes to
`art/raw/<id>/v<N>.png`, and records model, prompt, seed, and timestamp in
`art/provenance.jsonl`. Never overwrites; generation is append-only so any plate
can be rolled back.

**d. Ingest.** `tools/ingest.py` — background removal, alpha trim, canonical
resize, palette clamp toward the style bible's ramp (this step alone does most of
the visual unification), drop shadow bake, atlas packing, and emission of the
Godot `.import` settings and a `.tres` resource per creature. A new creature is
then: one JSON row, one generated plate, one command.

**e. Human gate.** A contact-sheet review step. Generation is cheap, so
over-generate 4–6 variants and pick. The picking is where quality actually comes
from; automate everything except the picking.

**f. In-engine validator.** A scene that loads every creature resource, renders
its card, and screenshots a grid — catches missing art, bad alpha, wrong
dimensions, and off-palette plates in one glance before they reach a build.

## 8. Reuse from vendored code

- `Godot-Game-Template/` — menus, options, pause, save/load, loading screens.
- `godot-open-rpg/` — turn-based combat scaffolding, inventory, dialogue.
- `godot-demo-projects/` — Skeleton2D rig, GPUParticles2D recipes, 2D glow,
  shader-based transitions, FastNoiseLite for paper and map fragments.
- `phantom-camera/` — journal focus pushes and encounter framing.
- Genuinely new: the art pipeline (Python, outside the engine) and the
  trait→card-effect compiler. Neither carries engine risk.

## 9. Scope and milestones

1. **Pipeline spike (week 1).** Style bible + 12 creatures end-to-end, generated
   through ingest into a rendered card grid. Kill criterion: if 12 plates don't
   look like one artist made them, fix the bible before writing any game code.
2. **Vertical slice (weeks 2–4).** One biome, 20 creatures, full encounter loop,
   catalogue, card parallax and skeletal warp.
3. **Systems (weeks 5–8).** Trait compiler, deck construction, expedition map,
   meta-progression, guide export.
4. **Content (weeks 9–14).** Scale to 200+ creatures — pipeline throughput, which
   is why step 1 comes first.
5. **Ship.** Guide export as the marketing engine; a filled 200-page field guide
   is the screenshot that sells it.

## 10. Risks

- **Sameness at volume.** 300 plates from one prompt template converge on one
  pose and one composition. Mitigate with an explicit variation axis in the JSON
  (pose, framing, angle, activity) and by reviewing contact sheets in batches of
  40, not 4.
- **Provenance and store policy.** Steam requires disclosure of AI-generated
  content. Plan for it: `art/provenance.jsonl` exists to make the disclosure
  factual and complete, and the model's commercial-use terms should be recorded in
  `THIRD_PARTY_LICENSES.md` alongside everything else. Audit this before the store
  page, not after.
- **Player sentiment.** A visible segment reacts badly to AI art. The honest
  posture is disclosure plus craft: the pipeline's human-gate and hand-authored
  design work are the answer, and the watercolour direction is chosen partly
  because it reads as authored rather than as a diffusion artifact.
- **Cost.** ~2,000 generations at 4–6 variants each. Estimate it before
  committing to the content target.

## 11. Relationship to ACCRETE

These are alternatives, not a merge. ACCRETE is the lower-risk ship and is
already partly built. CRYPTID FIELD GUIDE is the bet worth making *if* the
generative pipeline is the thing we actually want to prove out — its whole
premise is a content volume that is not otherwise reachable, and it fails
gracefully into a smaller creature count rather than into a broken game.
