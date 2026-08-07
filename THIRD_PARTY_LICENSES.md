# Third-Party Licenses

Every external project vendored into this repository, the exact upstream
snapshot it was taken from, and its license. All code here was chosen to be
commercially friendly (MIT), per our licensing policy: prefer MIT / Apache-2.0 /
CC0; avoid GPL/LGPL source; keep code and asset licensing separately verified.

Vendored copies live under `third_party/<name>/` with their original LICENSE
files intact and their `.git` history stripped (plain snapshots).

| Project | Upstream | Snapshot commit | License | Notes |
| --- | --- | --- | --- | --- |
| godot-demo-projects | https://github.com/godotengine/godot-demo-projects | `4652e17c04fe5f249dc53949fb195a3d8b24ee5f` | MIT | Official Godot demos (~120 projects, Godot 4.7). Some individual demos credit fonts/art with their own permissive licenses in per-demo READMEs — see the license audit in `docs/GODOT_CODE_SURVEY.md`. |
| Godot-Game-Template | https://github.com/Maaack/Godot-Game-Template | `dc2c43cbc4e2115c7bf2f13eeea2cda584e12fb1` | MIT | Complete game shell: main menu, options, credits, pause, loading, persistence (Godot 4.7). Copyright (c) 2022-present Marek Belski. |
| Starter-Kit-3D-Platformer | https://github.com/KenneyNL/Starter-Kit-3D-Platformer | `3fa8a04b1c01ab23db43123d4ce814a34c3fc7f0` | MIT | Kenney starter kit (Godot 4.6); art assets by Kenney (CC0, kenney.nl). |
| Starter-Kit-FPS | https://github.com/KenneyNL/Starter-Kit-FPS | `185fd2326d74a5cf858cffc616f87cf9696f9cc0` | MIT | Kenney starter kit (Godot 4.6); art assets by Kenney (CC0, kenney.nl). |
| Starter-Kit-City-Builder | https://github.com/KenneyNL/Starter-Kit-City-Builder | `4535092b740b378b700efd9df9e27a631815b84a` | MIT | Kenney starter kit (Godot 4.6); art assets by Kenney (CC0, kenney.nl). |
| beehave | https://github.com/bitbrain/beehave | `dd1df2d59e7daa49d8aa1fd9a55f2081cd0f4c6e` | MIT | Behavior-tree AI addon for Godot 4 (enemy AI). Copyright (c) 2023 bitbrain. |
| phantom-camera | https://github.com/ramokz/phantom-camera | `1c1b1295cf08c5c0af939e05c8235e99b2cf7425` | MIT | 2D/3D camera addon (follow, tween, shake-friendly). Copyright (c) 2022 Marcus Skov. |
| godot-open-rpg | https://github.com/gdquest-demos/godot-open-rpg | `19bd328fae9e4b534d3bb6db380a3d871d6ea58f` | MIT | GDQuest open RPG (Godot 4.6): combat, inventory, dialogs, grid movement. |

## Policy for new imports

1. Only import code whose license is MIT, Apache-2.0, BSD, ISC, zlib, or CC0.
2. Assets (art/audio/fonts) are licensed separately from code — verify each
   file's license, prefer CC0 or original work.
3. Record every import in this file: project, upstream URL, exact commit,
   license, and any attribution obligations.
4. No GPL/LGPL source in the shipped game unless we deliberately decide the
   game should be open source under a compatible license.
5. A public repository with no license grants no rights — never import from
   unlicensed repositories.
