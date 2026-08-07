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
