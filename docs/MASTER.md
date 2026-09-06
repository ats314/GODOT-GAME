# GODOT-GAME's place in the master idea

Internal. This repository is one of five. The others are `lidargame-`
(lidarworld, a LiDAR compiler), `Kalasatama` (Helsinki photogrammetry),
`CityBuilder` (a walkable ASCII megacity) and `react-native-game-engine`. The
full note lives in `lidargame-/docs/MASTER.md`; this is the part that concerns
this repository.

## The idea, in one paragraph

Measured reality is compiled once into a small, theme-independent and
engine-independent description — a **World Seed**: terrain grid, footprint and
two heights per building, a centreline and width per road, a position and size
per tree, and nothing else. Renderers and engines are targets that expand it.
Nothing crosses a repository boundary except that seed file.

## Two separate things live here, and conflating them would be a mistake

### 1. ACCRETE is a game, and it is not this pipeline

ACCRETE — the action-incremental in `game/`, designed in `docs/GAME_DESIGN.md`,
already a running Milestone 1 slice — shares **no geometry, no data and no
pipeline stage** with a measured city. It is a 2D arena about accreting mass
onto a star.

That is stated plainly rather than smoothed over, because the alternative is
the retrofit this whole document exists to avoid: inventing a story in which a
neon vector incremental is secretly a city-generation product. It is not. It is
a separate product with its own market case (a verified gap in visual
incrementals, a genre that converts through YouTube rather than wishlists) and
it should be judged on that.

What ACCRETE *does* contribute to the master idea is proof: it demonstrates that
the shell in this repository can carry a designed game from a survey to a
running slice, which is exactly the capability the pipeline needs at its far
end and does not have anywhere else.

### 2. This repository is the estate's shipping engine

That part is directly load-bearing. Ten vendored MIT/CC0 codebases, surveyed
file by file in `docs/GODOT_CODE_SURVEY.md`, with a complete production shell:
threaded scene loading, persistent settings, input rebinding, pause, save/load,
music and UI sound (Maaack's template); enemy AI (beehave); camera work
(phantom-camera); terrain (Terrain3D); grid placement and Resource-based
persistence (Starter-Kit-City-Builder).

**A Godot backend is the shortest route from a measured place to a store page.**
Every other target in the estate ends in a browser. This one ends in a build.

## The unbuilt piece: a `godot` backend

Named in `lidargame-/docs/MASTER.md` as the highest-value unbuilt target. What
it looks like, grounded in what is already vendored here:

```
world.seed.json  ──►  WorldSeed.gd        parse + validate `seed: "lidarworld/0.1"`,
                                          refuse a major version it does not know
                 ──►  SeedTerrain.gd      terrain.z[ix][iy] at step_m -> Terrain3D
                                          heightmap, or a plain mesh for small tiles
                 ──►  SeedCity.gd         per building: footprint ring + ground_z +
                                          height + roof form -> generated geometry
                                          standing at measured coordinates
                 ──►  SeedStreets.gd      roads[].line + half_width -> carriageway
                 ──►  SeedTrees.gd        vegetation[] -> MultiMeshInstance3D
```

Four rules it has to keep, all of them inherited rather than invented:

1. **Generated geometry at measured coordinates.** Never reproduce a measured
   surface; the seed does not carry one, on purpose. `Kalasatama`'s first rule
   and `lidargame-`'s invariant are the same rule.
2. **Materialisation happens here and only here.** The seed names no material,
   no texture and no shader. Binding them is the backend's whole job.
3. **Measured and generated stay distinguishable.** The seed carries `residual`
   per building, `evidence` on derived terrain, `surface: "inferred"` on water.
   Keep that on the node so the scene can still say which is which.
4. **Local coordinates.** A raw projected easting can be tens of millions of
   metres, where float32 resolves about two metres. The seed carries `origin`
   and `crs` for exactly this reason — subtract the origin, keep the CRS.

Reuse that already exists here: `Starter-Kit-City-Builder/scripts/builder.gd`
for grid placement and MeshLibrary-built-at-runtime, its
`data_map.gd`/`data_structure.gd` for typed Resource persistence, Terrain3D for
the ground, `phantom-camera` for the walkthrough, and Maaack's shell for
everything around the world itself.

## The licence policy here is the estate's best one, and should be the model

`THIRD_PARTY_LICENSES.md` and the survey do the thing the other repositories
mostly do not: code and assets audited separately, every import recorded, a
stated policy (MIT / Apache-2.0 / CC0 only, no GPL source), and blockers tracked
to resolution — the Maaack plugin logo under CC BY-NC-ND was found and replaced
in commit `4164455` rather than shipped and discovered later.

That matters for the master idea because the estate straddles a licence line:

| repository | licence |
|---|---|
| `lidargame-`, `Kalasatama` | proprietary, all rights reserved |
| `CityBuilder`, `GODOT-GAME` | MIT (ours) |
| `react-native-game-engine` | MIT, upstream copyright (not ours) |

**So proprietary source must never be vendored into this repository**, and a
`godot` backend must live on the compiler side, emitting a scene or a `.tres`
that this repository loads. The seed file is the boundary. That is not a
preference — a monorepo or a vendored compiler would either relicense
proprietary work by accident or contaminate this MIT tree, and there is no
third option.

Two things still owed by this repository's own records, both from the survey:
the OFL fonts (Lilita One, Xolonium, Nunito, and the rest) need their licence
text bundled with any release that ships them, and the CC BY-SA items carry
ShareAlike terms that bind modified versions too.

## The ASCII city already published here

`ascii-city/` and `play/` host CityBuilder's NOCTIS-7 demo on the Pages branch.
That is the first cross-repository join in the estate and it predates this
document. It now has a formal shape: `lidargame-` grew a `noctis` backend that
bakes a World Seed straight into that renderer's city texture, so a place
measured once can be walked in ASCII and in Godot without either of them owning
a copy of the other's data.
