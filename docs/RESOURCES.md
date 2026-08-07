# Useful Godot Information — Curated Index

The code we can *use* is vendored in `third_party/` (see
`THIRD_PARTY_LICENSES.md`). This file indexes the *information* sources worth
returning to — documentation is better consumed live (it's huge and updates
constantly), so we link rather than vendor it.

## Official

- **Godot documentation** — https://docs.godotengine.org — manual + full class
  reference for Godot 4.x. (Sources: https://github.com/godotengine/godot-docs,
  CC-BY-3.0. Not vendored: very large, always fresher online.)
- **Engine downloads / releases** — https://godotengine.org/download and
  https://github.com/godotengine/godot/releases (engine is MIT).
- **Official demo projects** — https://github.com/godotengine/godot-demo-projects
  (MIT — vendored here at `third_party/godot-demo-projects/`).
- **Godot Asset Library** — https://godotengine.org/asset-library/asset —
  addons/assets with per-item licenses (check each before importing).
- **GDScript style guide** —
  https://docs.godotengine.org/en/stable/tutorials/scripting/gdscript/gdscript_styleguide.html

## Ecosystem catalogs

- **Awesome Godot** — https://github.com/godotengine/awesome-godot — the
  community's master list of addons, tools, and open games (check licenses
  per project before importing anything from it).
- **Godot Shaders** — https://godotshaders.com — community shader library
  (per-shader licenses, many CC0).

## Learning (free)

- **GDQuest** — https://www.gdquest.com and https://github.com/gdquest-demos —
  high-quality tutorials; their open projects are MIT (one is vendored here:
  `third_party/godot-open-rpg/`).
- **KidsCanCode Godot Recipes** — https://kidscancode.org/godot_recipes/4.x/ —
  concise how-to patterns for Godot 4.
- **Godot official "Your first 2D game"** —
  https://docs.godotengine.org/en/stable/getting_started/first_2d_game/ —
  the Dodge the Creeps tutorial; finished code is vendored at
  `third_party/godot-demo-projects/2d/dodge_the_creeps/`.

## Community megathread picks (r/godot)

Distilled from the r/godot community resource megathread. The original post's
per-video links aren't reproducible here, but every item below is findable by
searching the title on YouTube (channels listed further down).

### Named tools and templates from the thread

- **Terrain3D** (MIT) — vendored at `third_party/Terrain3D/` — editable 3D
  terrain with LOD, used by shipped Godot games.
- **ShaderV** (MIT) — vendored at `third_party/ShaderV/` — visual-shader node
  collection.
- **COGITO** (MIT) — first-person immersive-sim template for Godot 4:
  interactables, inventory, save systems. Not vendored (upstream moved to
  https://codeberg.org/Phazorknight/Cogito, unreachable from this build
  environment; final Godot 4.4 release remains at
  https://github.com/Phazorknight/Cogito). Import it via Godot's Asset
  Library if needed.

### Topics worth searching (2D)

Brackeys' 2D tutorial; "every 2D node in 9 minutes"; 2D bodies explained;
Slay-the-Spire clone series; remaking Mario in Godot 4; idle-game series;
point-and-click grid movement; 2D light systems; dynamic side-scroller water.

### Topics worth searching (3D)

Brackeys' 3D game; first/third-person controller series; quaternions in
depth; Blender-to-Godot character workflow; GridMaps; procedural animation;
destructible environments; procedural dungeons; water/ocean shaders;
stylized grass and wind shaders; Terrain3D workflows; post-processing.

### Topics worth searching (general)

Signals (editor vs code, in depth); every node explained in 42 minutes;
every Variant in Godot 4; reading the documentation effectively; useful
coding patterns and downsides of inheritance; ECS explained; data models;
save/load systems; multiplayer in 3 minutes + networking series; spatial
audio; dissolve/sky/cloud shaders; 100k boids with shaders; dialog
localization; modular upgrade systems.

### Channels the thread recommends

Lukky, GDQuest, DevLogLogan, LegionGames, Crigz Vs Game Dev, Godotneers,
StayAtHomeDev, Timothy Cain (Fallout's creator), Blender Artifex, LucyLavend,
Bramwell, Nagi, Pixel Principles, Brackeys, Grant Abbitt, Ian Hubert,
CG Cookie, CG Boost, Le Lu, SimonDev.

### Blender (asset-creation side)

- Blender documentation — https://docs.blender.org
- Blender Guru's "donut series" (basics + texturing), low-poly animals,
  modular assets, rigged-character workflow, importing Blender models into
  Godot 4, pixel-art addon/3D pixel art.

### Paid (flagged as paid in the thread)

GameDev.tv Godot courses, Zenva packs (Humble Bundle), GameDev.tv Blender
courses. Optional; everything needed to build our game exists free above.

## Free assets (license-safe sources)

- **Kenney** — https://kenney.nl/assets — thousands of CC0 sprites, models,
  UI packs, audio. Safest possible asset source; three of Kenney's complete
  Godot starter kits are vendored here.
- **OpenGameArt** — https://opengameart.org — filter by license (prefer CC0).
- **Freesound** — https://freesound.org — filter by CC0 for sound effects.
- **Google Fonts** — https://fonts.google.com — OFL fonts (attribution: keep
  the OFL license file alongside the font).

## Licensing references

- **Choose a License** — https://choosealicense.com — plain-language license
  summaries (MIT, Apache-2.0, GPL, CC variants).
- **Godot engine license & attribution requirements** —
  https://godotengine.org/license — what a shipped game must credit.

## Rules of engagement (from our licensing policy)

1. Code and assets are licensed separately — verify both, always.
2. MIT / Apache-2.0 / BSD / ISC / zlib / CC0 → usable, keep notices.
3. CC-BY → usable with attribution; CC-BY-SA/NC or GPL → do not import.
4. No license = no permission. Public visibility grants nothing.
5. Every import gets a row in `THIRD_PARTY_LICENSES.md` with the exact commit.
