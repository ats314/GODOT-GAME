# New Game Idea — CAUSTIC

A fresh concept for the idea bank, designed against the same constraints that
produced ACCRETE (`docs/GAME_DESIGN.md`): Godot 4, controller-only owner,
2-3 month part-time scope, ~70% lift-and-adapt from the vendored survey
(`docs/GODOT_CODE_SURVEY.md`).

**Status:** unresearched concept. The mechanical and engineering claims below
are checked against the vendored code; the *market* claims are design-side
judgement only and have **not** been through the research/panel pass ACCRETE
got. Treat the Steam positioning section as a hypothesis to verify, not a
finding.

**Working title:** CAUSTIC (alternates: LATTICE, ANGLE OF INCIDENCE, SPLIT —
Steam title-collision search required before any page work)

**Genre tags:** Roguelite, Tower Defense, Puzzle, Automation, Physics,
Minimalist, Sci-fi, Neon, Singleplayer

---

## Pitch

CAUSTIC is a real-time defense roguelite in which you never fire a shot and
never place a turret. You have exactly one beam of light — always on, always
pouring out of your reactor — and you defend by building the *geometry it
travels through*: mirrors, splitters, prisms, lenses, amplifiers. The beam is
fully simulated, so rotating a single mirror three degrees re-routes the entire
kill-line across the arena in real time, and the lattice you have assembled by
wave twenty is a signature snowflake of light that nobody else built the same
way.

## The hook

**One beam. Everything else is geometry.**

The verb is not "shoot" or "place" — it is *aim a mirror and watch a scythe of
light sweep the swarm*. The beam solution updates live while you rotate, at
sixty frames a second, through forty bounces, so the moment-to-moment feel is
continuous, physical, and legible from across a room. Two properties make it
self-marketing:

- **The solution is the screenshot.** Optical lattices are beautiful and
  unique per player. This is the Opus Magnum / Infinifactory sharing dynamic —
  players post their builds because their builds are *theirs* — applied to a
  real-time defense game instead of a puzzle box. Ship a one-button "capture
  lattice" export from day one.
- **The failure is spectacular.** Your own beam damages your own reactor. A
  mirror-shelled enemy wandering into a twelve-bounce chain folds the whole
  thing back onto you. Every run has a clip in it.

## Core loop

**Seconds.** The beam is continuous and does damage-per-second where it dwells,
so a stationary lattice kills steadily on its own while a hand-swept beam kills
far faster. That is the idle-vs-action contract in one mechanic, with no
separate systems: the lattice plays the game at roughly 60% efficiency, and
sweeping, re-aiming, and prioritising multiplies it. Enemies have no health
bars — their outlines *fill with light* as they heat, and pop when saturated.

**Minutes.** Enemies advance from the rim toward the reactor. Four archetypes
exist to attack the lattice rather than the player:

- **Absorbers** — matte, beam-eating, and they cast a real shadow cone behind
  them. Ignore one and the back half of your lattice goes dark.
- **Reflectors** — mirror-shelled; they bounce your beam somewhere random,
  possibly into your reactor. Hazard and comedy.
- **Refractors** — bend the beam as they cross it, so the whole downstream path
  wobbles while they are alive. They make your careful geometry breathe.
- **Shatterers** — they target your *components*. The real fail state is not
  losing HP, it is watching your build unravel and the beam fall limp.

**A wave.** Clear it, then draft one of three optical components. The lattice
persists for the whole run, so a run is a single growing structure and the
draft is a build decision, not a stat bump.

**The economy.** The beam carries finite power. Every bounce costs a percentage
of what remains and every enemy hit drains it, so a baroque forty-bounce
cathedral is dim at its far end while a brutal three-bounce line is blinding
but covers nothing. Amplifier nodes restore power at the cost of a lattice slot
and a placement constraint. Depth versus reach is the entire tuning knob, and
it is geometric rather than exponential — a genuinely different balancing
problem from ACCRETE's, and an easier one, because it is bounded.

**A run.** Twenty-five to thirty-five minutes to a boss: a Prism Colossus that
splits your beam into three divergent children you have to re-converge onto it
while it walks. Between runs you unlock component families and *reactor
variants* — dual emitters, a pulsed emitter that trades uptime for burst, an
inverted reactor whose beam gains power per bounce instead of losing it. Each
variant is a different geometry puzzle rather than a bigger number, which is
where the replay value lives.

## Art direction

The beam is the art. Pure additive light on near-black, every object a
Polygon2D outline of six to twelve vertices, every beam a Line2D using the
antialiasing-gradient texture trick, WorldEnvironment glow doing all the
atmosphere. No drawn sprites needed, same as ACCRETE — chosen because it is
fast and because the beam should look like light, not because art is off the
table (`docs/CONSTRAINTS.md`). Purchased or commissioned art can be layered in
wherever it beats primitives.

The one idea worth protecting: **colour is a mechanic that renders itself.**
Splitters emit real red/green/blue child beams, and additive blending means
crossing beams literally compute their own combination — white where all three
overlap, and white is triple damage. The renderer does the game logic for free,
and the resulting caustic patterns are the title.

Audio follows the same principle: the beam is a continuous drone whose pitch
tracks total path length, each bounce adds a harmonic, each component family
adds a voice. Building the lattice composes the soundtrack, using the
procedural-audio recipes already surveyed rather than licensed music.

## Controller parity (owner hard requirement)

CAUSTIC is *better* on a controller than on a mouse, which is a first for this
project's shortlist. Left stick moves a placement cursor, **right stick rotates
the held component with analog precision** — that fine rotation is the game's
core verb and its best feel, and an analog stick does it better than a mouse
ever could. Triggers cycle component type, A places, B cancels, X salvages for
partial power. Nothing is twitch, nothing is held, nothing is mashed, and the
game is pausable at every moment without losing state. Menus and draft cards
are d-pad navigable with visible focus via the Maaack shell, as in ACCRETE.

## Build map (vendored code → system)

Paths relative to `third_party/`. Roughly three quarters of this is the same
foundation ACCRETE would use, so prototyping CAUSTIC does not throw away the
shell work.

- **Game shell, options, pause, rebinding, saves** — `Godot-Game-Template`
  (Maaack autoloads, OverlaidWindow pause, input rebind menu, GlobalState
  versioned saves).
- **Beam rendering** — `godot-demo-projects/2d/polygons_lines` (AA Line2D
  gradient-edge trick, runtime `msaa_2d` toggle) + `2d/glow` (WorldEnvironment
  recipe, HUD-exempt CanvasLayer).
- **Optical solver** — **new code.** Iterative
  `PhysicsDirectSpaceState2D.intersect_ray` reflection loop with a hard bounce
  cap (~64 segments per branch, ~4 branches), per-segment power decay, dirty-flag
  re-solve on geometry change rather than every frame. 250-400 lines of pure
  GDScript, no engine risk. This is the one genuinely new subsystem — the same
  risk profile as ACCRETE's economy engine, and easier to unit-test.
- **Shadow cones behind Absorbers** — `2d/lights_and_shadows` (LightOccluder2D
  + PointLight2D) or, cheaper, a polygon fan generated by the solver itself.
- **Enemy swarms at count** — `2d/bullet_shower` (PhysicsServer2D RID bodies,
  single batched `_draw`, `_exit_tree` RID cleanup). Beam cost is bounded by the
  bounce cap, not by enemy count, so the two scale independently.
- **Enemy AI and boss phases** — `beehave` behaviour trees (Shatterers target
  components, Absorbers seek beam segments) + `2d/finite_state_machine` for the
  Colossus.
- **Wave spawning and run skeleton** — `2d/dodge_the_creeps` (Path2D rim
  spawning, signal-wired HUD, group cleanup).
- **Components as data** — `Starter-Kit-FPS` `scripts/weapon.gd` Resource-per-item
  pattern; a component is `{reflect_curve, split_count, power_cost, gain}`.
- **Placement cursor, snap, ghost preview** — `Starter-Kit-City-Builder`
  (selector with lerped snap, place/demolish/rotate, per-call audio pool),
  adapted from GridMap to 2D free placement.
- **Juice** — `2d/tween` cookbook; `phantom-camera` noise shake and priority
  zoom; `3d/ragdoll_physics` slow-mo trick (`Engine.time_scale` +
  `AudioServer.playback_speed_scale`) for the reactor-hit moment.
- **VFX** — `2d/particles` (subemitters for component shatter, turbulence for
  heat shimmer); `2d/sprite_shaders` disintegrate for enemy pops;
  `2d/screen_space_shaders` vignette.
- **HUD** — `2d/custom_drawing` arcs for the power budget, `gui/msdf_font` for
  crisp digits, `godot-open-rpg` UIDamageLabel tween for floating numbers,
  `gui/rich_text_bbcode` for wave banners.
- **Audio** — `audio/generator` push_frame synthesis for the beam drone,
  `Starter-Kit-City-Builder` `scripts/audio.gd` pooled players,
  `audio/spectrum` for a beam-reactive backdrop.
- **Transitions and music** — `godot-open-rpg` ScreenTransition + MusicPlayer
  crossfade, or the Maaack MusicController.

## Milestones

1. **Weeks 1-2 — Optics prototype.** Reactor, one mirror type, live solver,
   glow, a swarm from `bullet_shower`. *Exit test:* rotating one mirror through
   a crowd is fun with placeholder everything. If that single interaction is
   not satisfying in two weeks, the concept is dead and nothing else can save
   it — this is a cheap, decisive kill criterion.
2. **Weeks 3-5 — Game.** Four enemy archetypes, power economy, splitters and
   prisms with additive colour damage, component draft, wave structure, run
   loss, Maaack shell.
3. **Weeks 6-8 — Depth.** Reactor variants, Prism Colossus, meta unlocks,
   lattice capture/export, daily seed, juice and audio pass.
4. **Weeks 9-11 — Ship.** Balance spreadsheet, achievements, localisation
   scaffold, performance hardening, Steam page and demo.

Roughly 10-12 part-time weeks — comparable to ACCRETE, with the difference that
the risky subsystem is testable in isolation in week one.

## Steam positioning (hypothesis — not researched)

Price $6.99, above ACCRETE's proposed $4.99 because the audience skews
puzzle/automation rather than idle, and that audience pays more per hour.
Comparables to check: Rogue Tower, Mindustry, Opus Magnum, and the
neon-vector aesthetic lane Nodebuster established.

**Honest risk:** puzzle-defense converts worse on Steam than idle/incremental,
which is exactly the axis ACCRETE was chosen on. CAUSTIC trades measured market
fit for a sharper, more legible hook and a genuinely novel core verb. The
mitigations are the shareable-solution property, the daily-seed leaderboard,
and a demo that is one wave long and takes ninety seconds to understand — but
they are mitigations for a real weakness, not a refutation of it.

## How this relates to ACCRETE

It is a sibling, not a replacement. It shares roughly three quarters of the
vendored foundation, the neon-vector art solution, the
controller-first requirement, and the 60%-efficiency idle contract — so the
shell, glow, audio, and swarm work transfer either way. It differs in the only
places that matter for a green-light decision: the core verb (aim geometry, not
aim a gun), the progression (a persistent structure *within* a run, not across
hours), and the new-code risk (a bounded optics solver, testable in week one,
versus an open-ended economy that only reveals itself over hours of play).

If ACCRETE proceeds, CAUSTIC sits in the idea bank as the second pivot after
LARIAT. If the ACCRETE week-3 economy exit test fails, CAUSTIC is arguably a
better pivot than LARIAT: its kill criterion lands sooner, its risky subsystem
is unit-testable, and its hook survives a screenshot.

## Next steps if pursued

1. Run the same three-judge panel over this concept that produced the ACCRETE
   scores, so it is compared on equal evidence rather than on enthusiasm.
2. Research the market claims above — the puzzle-defense/automation conversion
   question is the whole decision.
3. Two-week optics prototype in a throwaway branch. The exit test is one
   sentence long and cheap to run.
