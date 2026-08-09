> **Superseded — prior art, not the current plan.** The team has reset and is
> choosing a new game concept. Keep this document for its research (Steam market
> data, the judging method, the reuse map against the vendored code), but do not
> treat any of it as a requirement.
>
> Note also that the platform target is now stated authoritatively in
> `docs/PLATFORM_TARGETS.md`: **desktop PC via Steam, not web.**

# Master Game Design — ACCRETE

**The recommendation: build ACCRETE** — an action-incremental arena-defense
game where everything you destroy becomes permanently part of your star.
Chosen by a 5-concept, 3-judge design panel run over the full survey of our
vendored code (`docs/GODOT_CODE_SURVEY.md`), scored on Steam market fit,
buildability with our exact code and constraints, scope safety, and hook
strength.

## Why this game

- **It aims at a verified market gap.** Shipped idle/incremental games are
  static number-walls; survivors-likes reset every run. ACCRETE is the
  'visual incremental' the genre's own developers call undersupplied —
  progress is a permanent, visible, growing structure, and prestige is a
  screen-filling spectacle. The incremental niche converts through YouTube
  creators rather than wishlist mountains (Gnorp Apologue: $1.4M+ from 1.7k
  launch wishlists), which suits a no-name debut with no marketing budget.
- **It has the least engineering risk of all five concepts.** The engineer
  judge verified every reuse claim against the survey: zero uncovered
  systems. The only genuinely new subsystem is the economy math — pure
  GDScript, iterable from a spreadsheet, no engine risk.
- **Its look is what our code is best at.** Neon vector minimalism over
  WorldEnvironment glow — zero drawn sprites required, which neutralizes
  our no-artist constraint instead of fighting it.

## Panel scores

Three judges (jaded market analyst / senior Godot engineer verifying claims
against the survey / streamer-player advocate), each scoring market,
buildability, scope safety, and hook out of 10 (totals /40; judge 1
reported averages, shown here ×4):

| Concept | J1 market | J2 engineer | J3 streamer | Verdict |
| --- | --- | --- | --- | --- |
| **ACCRETE** | 31 | 32 | 30 | **Winner** (judges 1+2) |
| LARIAT | 27 | 30 | 33 | Runner-up (judge 3 winner) |
| DEAD WAX | 26 | 29 | 30 | 3rd |
| DEATHSTEP | 24 | 27 | 27 | 4th |
| FLOCKFALL | 23 | 24 | 25 | 5th (best raw hook, worst buildability) |

The streamer judge's dissent is the design's sharpest known weakness and is
addressed head-on in **Grafted requirements** below: ACCRETE's payoffs are
hour-scale, so minute one must be made clip-worthy deliberately.

---

# The design

**Working title:** ACCRETE (working title; alternates: Accretion, Starmass — verify Steam title collision before page creation)

**Genre tags:** Idler, Incremental, Bullet Heaven, Casual, Arcade, 2D, Sci-fi, Minimalist, Singleplayer

## Pitch

ACCRETE is an action-incremental arena defense game where everything you destroy becomes permanently part of your star: enemy wreckage spirals into your accretion ring as mass you spend to physically build turrets, armor shells, and generators onto the ring itself, so the arena visibly grows from a lone spark into a blazing fortress-sun over hours of play. When you finally collapse the whole structure into a singularity (prestige), the entire screen implodes into your core and you restart heavier, with new matter tiers and permanent talents. It is Nodebuster's moment-to-moment zap-satisfaction with Gnorp Apologue's visible-machine depth, aimed at the "visual incremental" gap the Gnorp dev himself called undersupplied.

## The hook

Your progress is physically visible on screen at all times: every kill accretes onto your star, so a screenshot at hour ten looks nothing like minute one — and prestige is a screen-filling gravitational collapse of everything you built. The time-lapse GIF (spark, then fortress-sun, then implosion) is the wishlist engine, and the same property makes it irresistible on YouTube incremental channels (Orbital Potato/Wanderbots/Retromation drove Gnorp Apologue from 1.7k launch wishlists to $1.4M+ with 140-180k-view videos). Verified gap: idle/incremental had 27 Steam hits in 2025 with a 22.99% success rate for marketed games (howtomarketagame.com), survivors-likes gen 1 are declared saturated, and the "incremental bullet heaven" intersection has only one small released entry (Astro Prospector, ~5hr) with the bigger attempts (Mirage, Dustdrifter) still unreleased.

## Core loop

30 seconds: mouse-aim your core's beam at incoming waves; enemies pop into glowing shard-debris that spirals magnetically into your ring with pitched-up pickup arpeggios (one sample, pitch_scale = 2^(n/12)); mass counter climbs; every ring level offers a 3-choice upgrade card. Turrets fire on their own — cursor aim adds focus-fire damage, so the game plays itself at roughly 60% efficiency if you only watch (idle contract), but skilled aim and target priority visibly outperform. 5 minutes: one wave cycle (buildup, elite, lull); during lulls you spend banked mass to crystallize new hardpoints onto the ring — placement is physical, so coverage arcs, chokepoints, and synergy adjacency (amp crystals boosting neighbors) are real spatial decisions; new enemy archetype introduced roughly every cycle. 1 hour: sector boss (a Harvester that eats your ring mass if ignored) then the prestige decision — collapse everything for permanent core talents and the next matter tier, or push deeper at escalating risk for multipliers. Away: offline calc banks mass from ambient debris at your passive DPS (timestamp delta on load); return to a "while you were gone" tally and a fatter ring.

## Art direction

Neon vector minimalism on a near-black nebula field — the exact look the vendored code is best at, and the look Nodebuster already proved sells in this genre. Everything is Godot primitives: enemies are 2-4 sided Polygon2D silhouettes per family (triangles dart, squares tank, pentagons harvest), the core is layered draw_circle + draw_arc rings, beams are AA-textured Line2D, and each matter tier is one saturated accent hue (iron cyan, gold amber, then violet, crimson) over the base palette so progression reads as the screen literally warming in color. WorldEnvironment glow does the heavy lifting (2d/glow recipe, Forward+), GPUParticles2D handles all death/pickup/trail effects from the particles demo recipes, FastNoiseLite (misc/noise_viewer) generates the parallax nebula backdrop tinted by the spectrum analyzer, and the HUD sits on a glow-exempt CanvasLayer using an MSDF-imported OFL font (Xolonium, license retained). Zero drawn sprites required; optional Kenney CC0 particle/UI sheets as garnish. Capsule art is the one commissioned-or-carefully-made exception: a single dramatic render of the fortress-sun (mock it in-engine with glow cranked, screenshot, and paint over).

## Meta progression

Three interlocking layers. (1) In-run: upgrade cards each ring level plus physical hardpoint building — spatial synergies (amp crystals, reflector shells) make each run's geometry a build. (2) Prestige (Collapse): converts total accreted mass into Cores spent on a permanent talent constellation (starting mass, passive-fire efficiency toward true idle, offline rate, new turret archetypes) and unlocks the next matter tier with new enemies and a new accent color; collapse math targets first prestige at 45-60 minutes, classic incremental compression thereafter. (3) Account-level: milestone achievements (Steam achievements feed the idle audience), a stats/records screen, cosmetic core styles, and an unlockable ambient windowed mode (small always-on-top window, validated by Rusty's Retirement's 330k copies and Desktop Defender's 20k Next Fest wishlists) as the post-launch retention feature. Saves via Maaack GlobalState Resource with versioning; offline progress on load.

## Steam positioning

Price: $4.99 with a 15-20% launch discount — above Nodebuster's $2.99 (which reviewers called content-thin at ~$1.1-1.8M gross anyway), in line with Lyca ($4.99, $150k solo) and Kabuto Park ($4.99, 35k sales month one), below Gnorp's $6.99; Zukowski's data says hit idlers average $3.89 and 'everyone should be charging more.' Comparables to cite on the page and in creator outreach: Nodebuster (14.2k Overwhelmingly Positive), the Gnorp Apologue ($1.4-2.1M, launched with only 1.7k wishlists — proof this genre converts via YouTube, not wishlist mountains), Astro Prospector (the only shipped incremental-bullet-hell, small and run-based), Brotato/Halls of Torment (Godot handles the entity counts). Why it stands out in the gap: released idlers are visually static number-walls, and survivors-likes (saturated per Zukowski's 2025 analysis) reset every run — ACCRETE is the only entry where progress is a permanent, visible, growing structure and prestige is a spectacle, i.e. the 'visual incremental' the Gnorp dev called undersupplied. Launch plan straight from the Lyca/Gnorp playbooks: demo out ASAP with endless-capped progression (median demo playtime is the Next Fest currency), key the incremental YouTube circuit (Orbital Potato, Wanderbots, Retromation, Idle cub), sprint to 10 reviews for Discovery Queue, localize UI strings via the CSV pipeline (Nodebuster ships 15+ languages; Chinese players are the largest cohort), and pursue bundles with other incrementals post-launch (bundles were 37% of Lyca's gross).

## System-by-system build map

Every system mapped to the vendored code that covers it (paths relative to
`third_party/`; full detail on each source in `docs/GODOT_CODE_SURVEY.md`):

- **Game shell: main menu, options (audio buses, fullscreen/vsync, rebinding), pause, threaded scene loads, credits**
  - third_party/Godot-Game-Template addons/maaacks_game_template (AppConfig/SceneLoader/MusicController/UISoundController autoloads, OverlaidWindow pause, input rebind menu); WinLoseManager from extras/ for run-end flow; NC-ND plugin logo already replaced per survey commit 4164455
- **Debris/bullet swarms (1000+ simultaneous shards and projectiles)**
  - third_party/godot-demo-projects/2d/bullet_shower — PhysicsServer2D RID bodies + single-node batched _draw(), including _exit_tree RID cleanup
- **Wave spawning and arcade game-loop skeleton**
  - third_party/godot-demo-projects/2d/dodge_the_creeps (Timer + Path2D/PathFollow2D edge spawning, signal-wired HUD, group cleanup) + 3d/squash_the_creeps retry/reload pattern
- **Enemy AI: elites, Harvester bosses with phases, swarm behaviors**
  - third_party/beehave behavior trees (SelectorReactive chase/attack, Cooldown decorators, Blackboard, tick_rate>1 for crowds) + 2d/navigation_astar steering-arrive for homing units
- **Game-flow and boss-phase state machines**
  - third_party/godot-demo-projects/2d/finite_state_machine (generic state.gd + state_machine.gd, drop-in)
- **Turret/upgrade definitions as data (cooldown, damage, spread, shot count, sounds)**
  - third_party/Starter-Kit-FPS scripts/weapon.gd Resource-per-weapon pattern + 2d/platformer gun cooldown Timer; upgrade-card economy values live in the same Resources
- **Neon glow rendering and HUD exemption**
  - third_party/godot-demo-projects/2d/glow (WorldEnvironment glow_* recipe, CanvasLayer-excludes-HUD trick, runtime glow_intensity punches on prestige)
- **Explosions, shard trails, implosion VFX**
  - third_party/godot-demo-projects/2d/particles (explosion/trail/subemitter/turbulence ParticleProcessMaterial recipes) + Starter-Kit-FPS objects/impact.gd self-freeing hit effect
- **Juice: hit-stop, screen shake, zoom punches, score pop-ups, collapse choreography**
  - third_party/godot-demo-projects/2d/tween cookbook; phantom-camera PhantomCameraNoiseEmitter2D shake + priority-tween zoom; 3d/ragdoll_physics slow-mo combo (Engine.time_scale + AudioServer.playback_speed_scale)
- **Persistent accretion visuals (ring strata that never despawn)**
  - third_party/godot-demo-projects/2d/drawable_textures blit_rect stamping for fossilized inner strata + 2d/custom_drawing batched _draw for the live layer + 2d/polygons_lines AA Line2D trick for beams/ring outlines
- **Shader polish: enemy dissolve deaths, hit-flash, vignette**
  - third_party/godot-demo-projects/2d/sprite_shaders (disintegrate/silhouette/outline .gdshader drop-ins) + 2d/screen_space_shaders vignette on a fullscreen ColorRect
- **HUD: cooldown arcs, animated big-number labels, floating mass numbers, off-screen elite arrows**
  - 2d/custom_drawing draw_arc; gui/rich_text_bbcode wave/shake for NEW TIER banners; godot-open-rpg UIDamageLabel tween rise-and-fade; 3d/waypoints edge-clamp indicator math (2D adaptation); gui/msdf_font for crisp scaling digits; gui/multiple_resolutions for aspect safety
- **Audio: pooled SFX, procedural synth blips/lasers, pitch-arpeggio pickups, beat-pulsed waves, reactive background**
  - Starter-Kit-City-Builder scripts/audio.gd (pooled players, random pitch, per-call volume); audio/generator push_frame synthesis; audio/midi_piano pitch_scale trick; audio/bpm_sync latency-compensated beat clock; audio/spectrum for the music-reactive nebula backdrop; CC0 Kenney SFX as fallback
- **Save, settings, and offline-progress persistence**
  - Maaack GlobalState + examples/game_state.gd versioned Resource save; 3d/voxel settings.gd JSON autoload; loading/serialization ConfigFile pattern; offline delta math itself is new code (~50 lines)
- **Screen transitions and music crossfade between menu/run/prestige**
  - third_party/godot-open-rpg src/common ScreenTransition (awaitable tween fade) and MusicPlayer crossfade autoload (or Maaack MusicController)
- **Incremental economy engine: exponential cost curves, big-number formatting (1.2e15 / suffix notation), prestige multiplier math, balance spreadsheet export**
  - new code — the one genuinely new subsystem; pure GDScript math, no engine risk, but it is the design-critical work (Lyca's only real review complaints were pacing)
- **Prestige collapse sequence (screen-filling implosion set-piece)**
  - new code choreographing existing pieces: tween cookbook + particles subemitters + glow intensity ramp + phantom-camera zoom + slow-mo trick

## Milestones

Milestone 1, weeks 1-3 — Vertical slice: bullet_shower batching + dodge_the_creeps skeleton + glow environment; core aiming, one enemy family, shard magnet economy, one turret, upgrade cards, mass HUD. Exit test: 10 minutes of 'one more upgrade' fun with placeholder balance. Milestone 2, weeks 4-6 — Systems complete: ring building with physical hardpoints, 4 turret archetypes (weapon.gd Resources), 6 enemy types (beehave), first Harvester boss, prestige v1 with collapse set-piece, Maaack shell integration, saves + offline progress, procedural audio pass. Milestone 3, weeks 7-9 — Content and feel: matter tiers 2-3, juice pass (tween/shake/slow-mo/dissolve), balance curves in a spreadsheet with an import script, playtest weekly (Doot's method), cut a 30-second time-lapse trailer, Steam page + demo live. Milestone 4, weeks 10-12 — Ship: achievements, settings polish, CSV localization scaffold, performance hardening (blit fossilization keeps draw calls flat), Next Fest entry, launch as v1.0 at ~4-6 hours to first full collapse plus endless mode — Early Access only if tier 4+ content slips. Total: roughly 11-13 part-time weeks, honest 2-3 months, because an estimated 70% of engineering is lift-and-adapt from the vendored survey.

## Risks and mitigations

1) Economy pacing is the product: incremental audiences punish flat curves (Lyca's main complaints were pacing) — mitigate with a balance spreadsheet from week 4, weekly playtests, and demo telemetry on time-to-first-prestige. 2) Performance of permanent accretion: unbounded persistent objects would melt draw calls — mitigate by fossilizing inner strata into a drawable texture via blit_rect (drawable_textures pattern) so live nodes stay bounded; batched _draw for everything mobile. 3) The conjunction is forming around this exact intersection (Mirage Q4 2026, Dustdrifter, Swarm Survivor all upcoming) — being late is the biggest commercial risk, so the 2-3 month scope is a feature; do not let it grow (Doot's explicit warning). 4) Idle-vs-action tension: too action-demanding alienates idlers, too idle bores arcade players — mitigate with the explicit 60%-efficiency-when-passive contract, tested separately with both cohorts. 5) Title/IP: 'Accrete/Accretion' needs a Steam search and trademark sanity check; mechanics are original (no clone exposure), all vendored code MIT, the one CC-BY-NC-ND blocker (Maaack plugin logo) already replaced per survey; ship OFL font licenses and strip demo assets flagged CC-BY. 6) Genre fatigue timing: Zukowski warns the idle boom 'could be over already' — hedge is that the game also reads as arena defense/bullet heaven (evergreen crafty-buildy adjacent), and total build cost is low enough that a modest Nodebuster-quartile outcome (~$50-100k gross) still pays for the next game.

## Grafted requirements (from the judges)

1. **Minute one must sparkle** (streamer judge): the first 60 seconds get
   the full juice budget — glow punches, shard magnetism, pitch-arpeggio
   pickups, first upgrade card inside 45s. A first-session viewer must see
   an action game, not a clicker warming up.
2. **Group-follow auto-zoom camera** (from FLOCKFALL): phantom-camera GROUP
   framing targets the core + outermost ring so the view pulls back as you
   accrete — growth is felt every session and improves every screenshot.
3. **Kill-criterion milestones** (from LARIAT): each milestone has an exit
   test ('10 minutes of one-more-upgrade fun with placeholder balance' at
   week 3) — if it fails, fix the loop before adding content.
4. **Sub-second restart / instant resume** (from LARIAT): idle players tab
   in and out constantly; zero-friction session re-entry is retention.
5. **Controller-first accessibility (owner requirement — hard).** The
   project owner plays controller-only. Full parity from day one: right
   stick aims, right trigger / A fires, Start pauses, Y restarts, every
   menu and upgrade card is d-pad navigable with visible focus. ACCRETE's
   stationary-core, low-APM, plays-itself-at-60% design is inherently
   suited to this — protect that property in every future mechanic (no
   forced twitch input, no mouse-only interactions, no hold-and-mash).
   Steam Deck verification is a launch target, and full input rebinding
   ships via the Maaack shell in Milestone 2.

---

# Runner-up (kept warm): LARIAT

**Genre tags:** Arcade, Score Attack, Bullet Hell, Action, Top-Down, Difficult, Leaderboards, Neon

## Pitch

LARIAT is a score-attack arcade game where you never fire a shot: you are a comet trailing a rope of light, and the only way to kill is to draw a glowing lasso around the swarm and close the loop — everything inside detonates in one slow-motion chain. It is a bullet hell where the bullets are the fence and greed is the mechanic: the wider you swing the loop, the bigger the multiplier, and the longer you are exposed. Five-minute runs, sub-second restarts, daily seeds, leaderboards — a neon space-rodeo built entirely from vector glow, particles, and procedural sound.

## The hook

You don't shoot the swarm — you LASSO it. Every kill in the game is a player-drawn glowing loop closing around dozens of enemies at once, followed by a slow-mo chain detonation and a giant "x37 LASSO" pop. The hook is self-marketing: every screenshot and every streamed death shows a hand-drawn loop of light around a constellation stampede, something no other arcade game on Steam looks like. Risk is spatial and legible to spectators: big loop = big number = big exposure.

If ACCRETE's economy pacing proves unfun at the week-3 exit test, LARIAT is
the pivot: it shares ~80% of the same vendored foundation (bullet_shower
batching, glow, Maaack shell, beehave, phantom-camera, procedural audio) —
the swap is the economy layer for the lasso mechanic (~150 lines of
geometry) and score-attack scaffolding. Its weakness is the market (pure
score-attack arcade undersells on Steam); its strength is the sharpest
moment-to-moment hook of the panel.

# Idea bank (non-winning concepts)

## DEAD WAX — a drum-machine survivors-like

You are a ghost DJ fighting hordes on the surface of a spinning vinyl record. Your weapons are instruments placed on a glowing 16-step loop that orbits your character — every slot is both WHEN and WHERE you fire — so leveling up literally composes the track you're surviving to, from a lone kick drum at minute one to a full wall-of-sound arrangement at the final chorus. Finish the record, export your run as a music track, and dig for new instruments, DJs, and records in your crate between runs.

*Panel take:* strongest audio identity; sequencer UI + DSP risk sank buildability.

## DEATHSTEP

DEATHSTEP is a neon bullet-heaven roguelite where your build IS a drum machine: every weapon you draft is a synth voice slotted onto a 16-step sequencer, so your arsenal literally composes the techno track you fight to. When two weapons trigger on the same step they fuse into a single super-projectile, turning build-crafting into beat-programming. No rhythm skill required — the game quantizes everything; you design the groove, then survive the drop.

*Panel take:* build-as-composition is compelling but scope-unsafe in 2-3 months.

## FLOCKFALL

You are the shepherd-spirit of a vast starling murmuration on its last migration across a dying sky. You fly one small, fast, glowing bird — but your health, your weapon, and your score are the tens of thousands of birds swirling behind you: hawks tear visible holes in the flock, panic ripples through it like a shockwave, and you win by shaping the swarm itself — compressing it into a battering ram, scattering it around lightning, funneling it through storm gaps. A roguelite where the crowd simulation IS the player character.

*Panel take:* best raw hook (9s across all judges) but boids-at-scale + flight feel is our highest-risk engineering.

# Next steps

1. Green-light from the owner on ACCRETE (or call the LARIAT pivot now).
2. `game/` project scaffold from the Maaack template + glow environment.
3. Milestone 1 vertical slice (weeks 1-3) per the build map above.
4. Steam page checklist: title collision search, capsule mock, demo plan.