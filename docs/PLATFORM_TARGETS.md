# Platform targets

**We build a desktop PC game and sell it on Steam.** That is the whole target list.

| Platform | Status |
| --- | --- |
| Windows (x86_64) | **Primary.** The overwhelming majority of Steam revenue |
| Linux (x86_64) | **Supported.** Cheap from Godot, and it is what Steam Deck runs |
| Steam Deck | **Supported.** Verified status is a launch goal |
| macOS | Supported if it stays cheap; drop it rather than let signing/notarisation eat a week |
| Web / HTML5 | **Not a target.** Not the product, not a demo, not a marketing page |
| iOS / Android | **Not a target.** No touch input, no phone UI, no store presence |
| Console | **Not a target.** Requires a third-party porting house; revisit only after a successful PC launch |

## Why this is written down

The repository previously contained a Web-only `export_presets.cfg`, a published
HTML5 build under `play/`, and a root `index.html` redirecting to it — while stating
its actual platform target in no document at all. Anyone (human or agent) reading the
repository would reasonably conclude it was a browser game. This file is the
authoritative answer so that never happens again. If a decision here changes, change
it *here* first.

## What this means for engineering decisions

These follow directly from "desktop native, not browser". Each one is a place where
the web assumption would have pushed us the wrong way.

- **Renderer: Forward+ or Mobile, chosen on visual need — not Compatibility.**
  A browser build is forced onto the Compatibility renderer (`rendering_method.web`
  defaults to `gl_compatibility`), which is why HDR 2D and the full glow pipeline
  degrade there. Targeting desktop means Forward+ is available and the art direction
  can depend on it. Pick the renderer for the look, then verify on a Deck-class GPU.
- **Threads are available.** No `SharedArrayBuffer`, no cross-origin-isolation
  headers, no single-threaded export penalty. Threaded resource loading, background
  navmesh baking and `run_on_separate_thread` physics are all on the table.
- **Build size is nearly free.** No download-time budget, so uncompressed audio,
  large textures and generous asset counts are fine. Do not contort the design to
  save megabytes.
- **Real filesystem access.** `user://` is a genuine directory, not IndexedDB. Saves,
  logs, crash dumps, mod folders and screenshots all behave normally.
- **Input is keyboard/mouse and gamepad.** No touch, no virtual keyboard, no phone
  form factors. Controller parity matters because of Steam Deck — see the
  accessibility requirements in the design docs.
- **Performance target is a desktop/Deck GPU**, not a phone and not WebAssembly.
  Benchmark on the Deck's power envelope, since it is the weakest machine we promise
  to run on.
- **Steam integration is in scope** from the start: achievements, cloud saves, rich
  presence, and the Steam overlay. This is a native-only surface; it does not exist
  in a browser build.

## Consequences still outstanding

- `game/export_presets.cfg` contains a single `Web` preset and no desktop preset.
  Whichever project we take forward needs Windows and Linux presets created in the
  editor (export templates must be installed to do this properly).
- `play/` (39 MB) and the root `index.html` redirect are artefacts of the abandoned
  web build. They should be removed once we confirm nothing is linking to the
  published page.
