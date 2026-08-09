# Testing a Godot game in a headless container

Short answer: **yes, and further than most people assume.** A container with no GPU and
no display can import a project, run its scripts, execute a test suite, render real
frames through a software rasterizer, and produce release builds. What it cannot do is
tell you whether the game is fast or fun.

Everything below was measured in this repository's own sandbox — a Linux container, 4
cores, no `/dev/dri`, no display — not inferred from documentation.

## What was verified to work

| Capability | Result |
| --- | --- |
| Download and run the engine | Godot `4.7.1.stable.official.a13da4feb` |
| `--headless --import` | Builds `.godot/`, surfaces broken resources and UIDs |
| `--headless` scene boot | `_ready()`, signals, timers and autoloads all run |
| Detecting script errors | `SCRIPT ERROR`/`Parse Error` captured and failed on |
| Rendering, Compatibility | Mesa `llvmpipe`, OpenGL 4.5 Core, under `Xvfb` |
| Rendering, Forward+ | Vulkan 1.4 via Mesa `lavapipe`, under `Xvfb` |
| Screenshot to disk | `get_viewport().get_texture().get_image().save_png()`, verified visually |

Both rasterizers run on the CPU, so a real frame comes out with correct pixels on a
machine with no graphics hardware at all. That makes visual regression testing possible
in CI, not just error checking.

## What it cannot tell you

- **Performance.** `llvmpipe`/`lavapipe` are orders of magnitude slower than any real
  GPU, and this container has 4 cores. A frame time measured here means nothing. Profile
  on real hardware — and for us that means a Steam Deck, which is the weakest machine we
  ship to (see `PLATFORM_TARGETS.md`).
- **Real driver behaviour.** Shader compilation quirks, driver bugs and vendor-specific
  precision differences will not reproduce on a software rasterizer.
- **Game feel.** Input latency, controller response and whether any of it is enjoyable
  need a person and a real machine.
- **Audio output.** There is no sound card; Godot falls back to a dummy audio driver.
  Audio *code* runs, but nothing can be heard, so correctness has to be asserted on
  generated buffers rather than by listening.

## Using it

```bash
tools/godot_smoke_test.sh <project-dir> [main-scene] [--render] [--forward-plus]
```

- no flags — import and headless boot, the fast correctness check
- `--render` — also renders a frame with OpenGL (Compatibility) under Xvfb
- `--forward-plus` — renders with Vulkan (Forward+) instead

Exit code 0 means clean, 1 means the engine reported script errors, 2 means a setup
problem. The engine binary is cached in `~/.cache/godot-bin` after the first run.

Container audio and GPU-probing noise is filtered out, but a genuine error is not:
verified by injecting a call to a nonexistent method and confirming a non-zero exit.

## Setting up a fresh container

```bash
apt-get update
apt-get install -y xvfb                  # needed for any rendering
apt-get install -y mesa-vulkan-drivers   # only for Forward+/Mobile (installs lavapipe)
```

Without `mesa-vulkan-drivers`, requesting `--rendering-driver vulkan` **silently falls
back to OpenGL** — the run still succeeds and still reports `llvmpipe`, so it is easy to
believe you tested Forward+ when you tested Compatibility. Check for
`/usr/share/vulkan/icd.d/lvp_icd.json` before trusting a Forward+ result.

## Where this goes next

Once a game project exists, add a job to `.github/workflows/godot-ci.yml` that runs this
script, and consider a rendered-frame comparison against committed reference images for
visual regression. Unit tests (gdUnit4 is already vendored inside
`third_party/beehave/addons/gdUnit4/`) also run headlessly and belong in the same job.
