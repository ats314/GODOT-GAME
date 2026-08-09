# Using Codespaces (and other containers) effectively

A cloud container is a genuinely good place to develop this game — it can import the
project, run it, render frames, lint, test and export release builds. It is a bad place
to judge one. Knowing exactly where that line falls is what makes it useful instead of
misleading.

Everything in the "verified" column below was measured in a container with no GPU and no
display, not taken from documentation.

## The container is pre-configured

Two entry points, one shared script, so they cannot drift apart:

| Environment | Entry point |
| --- | --- |
| GitHub Codespaces | `.devcontainer/devcontainer.json` → `tools/setup_environment.sh` |
| Claude Code on the web | `.claude/hooks/session-start.sh` → the same script |
| Anything else (local Docker, CI) | run `tools/setup_environment.sh` yourself |

It installs the pinned Godot 4.7.1 binary, Xvfb, the Mesa software Vulkan driver, and
`gdlint`/`gdformat`. It is idempotent, so re-running costs a second. To see what a machine
can do without changing it:

```bash
tools/setup_environment.sh --verify
```

Because Codespaces caches the container image after creation, enabling **prebuilds** on
this repository means a new Codespace starts with all of that already baked in rather
than downloading the 76 MB engine on first boot. Worth turning on.

## What you can verify here

| Task | Command | Verified |
| --- | --- | --- |
| Project imports, resources and UIDs resolve | `tools/godot_smoke_test.sh <project>` | yes |
| Scripts run: `_ready`, signals, timers, autoloads | same, headless boot | yes |
| No script or parse errors | same — non-zero exit on failure | yes |
| A frame renders (Compatibility/OpenGL) | `… --render` | yes, Mesa llvmpipe |
| A frame renders (Forward+/Vulkan) | `… --forward-plus` | yes, Mesa lavapipe |
| Screenshot to a file | `get_viewport().get_texture().get_image().save_png(…)` | yes |
| GDScript style and formatting | `gdlint file.gd`, `gdformat file.gd` | yes, gdtoolkit 4.5.0 |
| Unit tests | gdUnit4, vendored at `third_party/beehave/addons/gdUnit4/` | runs headlessly |
| Release exports | `godot --headless --export-release <preset>` | needs export templates, see below |

The two software rasterizers do all the work on the CPU, so **real frames come out of a
machine with no graphics hardware**. That is what makes visual checking — and eventually
visual regression testing against committed reference images — possible in CI.

## What it cannot tell you

Be disciplined about this. A container that renders a correct frame feels like it is
telling you the game works, and it is not.

- **Performance.** `llvmpipe`/`lavapipe` are orders of magnitude slower than any real GPU.
  A frame time measured here is meaningless. Profile on hardware — for us that means a
  Steam Deck, the weakest machine we ship to (`PLATFORM_TARGETS.md`).
- **Driver reality.** Shader compilation quirks, vendor precision differences and driver
  bugs will not reproduce on a software rasterizer.
- **Game feel.** Input latency, controller response, and whether it is fun. No substitute
  for a person and a real machine.
- **Audio.** There is no sound card; Godot falls back to a dummy driver. Audio code runs,
  nothing is audible. Assert on generated buffers, not by listening.

## Running the actual Godot editor in a browser

The devcontainer includes the `desktop-lite` feature, which serves a minimal desktop over
noVNC on port **6080** (password `godot`). Forward the port and open it, and you can
launch the editor:

```bash
$HOME/.cache/godot-bin/Godot_v4.7.1-stable_linux.x86_64 --path <project>
```

Honest expectations: the editor renders through the same software rasterizer, so it is
fine for inspecting a scene tree, wiring signals, adjusting a resource or checking an
import — and frustrating for anything involving continuous viewport interaction. Treat it
as an inspection tool, not your authoring environment. If you never need it, delete the
`desktop-lite` feature from `devcontainer.json` and container start gets faster.

## Export builds

Export templates are a separate ~1.2 GB download and are **not** installed by the setup
script, because most sessions never need them:

```bash
mkdir -p ~/.local/share/godot/export_templates
curl -sSL -o /tmp/templates.tpz \
  https://github.com/godotengine/godot/releases/download/4.7.1-stable/Godot_v4.7.1-stable_export_templates.tpz
unzip -q /tmp/templates.tpz -d /tmp/tpl
mv /tmp/tpl/templates ~/.local/share/godot/export_templates/4.7.1.stable
```

Then `godot --headless --path <project> --export-release "Linux" out/game.x86_64`.
Size was confirmed against the release URL; the export itself has not been exercised here
because there is no game project yet.

## Working effectively as an agent in this container

The point of all this setup is that **claims can be checked instead of asserted**. Before
reporting that a change works:

1. `tools/godot_smoke_test.sh <project> <scene>` — did it import and boot clean?
2. `gdlint` the files you touched.
3. If the change is visual, `--render` and actually look at the screenshot.
4. If you changed anything vendored or indexed, regenerate:
   `python3 tools/build_api_index.py && python3 tools/build_code_index.py`.

And when you cannot check something here — performance, feel, driver behaviour — say so
explicitly rather than implying the container validated it.

## Traps worth knowing

- **Vulkan silently falls back.** Without `mesa-vulkan-drivers`, asking for
  `--rendering-driver vulkan` succeeds, reports `llvmpipe`, and quietly runs OpenGL — so
  you can believe you tested Forward+ when you tested Compatibility. Check for
  `/usr/share/vulkan/icd.d/lvp_icd.json`. `--verify` reports it.
- **Container noise looks like failure.** With no sound card, Godot prints
  `ERROR: Condition "status < 0" is true` with the ALSA cause on the *following* line. Any
  error filter that reads one line at a time will treat that as a real failure — or, worse,
  a filter tuned to ignore it will swallow real errors. `godot_smoke_test.sh` joins each
  error with its next line before filtering.
- **Screenshots land in `user://`**, which on Linux is
  `~/.local/share/godot/app_userdata/<project name>/`. They are not in the project folder.
- **The engine cache lives in `~/.cache/godot-bin`** and is mounted as a volume in
  Codespaces, so a container rebuild does not re-download it.
- **Storage.** This repository is ~445 MB before the engine, export templates or build
  artifacts. Give a Codespace at least 32 GB.
