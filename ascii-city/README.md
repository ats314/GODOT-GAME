# NOCTIS-7 — a walkable ASCII megacity

One HTML file. No images, no fonts, no libraries, no build step. Open it and
walk around a procedurally generated cyberpunk city that is drawn entirely with
text characters.

**Play:** `ascii-city/index.html` — open locally, or via GitHub Pages at
`/ascii-city/`.

```
WASD / arrows  walk          SHIFT  run            F  drone mode
mouse          look          V      switch alphabet [ ]  glyph size
C  copy the current frame to the clipboard as literal text
G  save PNG   R  new city   M  sound   B  bloom   L  reflections   N  rain
P  hide HUD   H  help
O  open source files   U  walk this page's own source
   …or drop a file or folder anywhere on the page
```

Touch devices get a virtual stick, a look-drag zone, and RUN / FLY / SET
buttons. Gamepads work too. `#s=<hex>` in the URL pins the city seed, so a
city you like has a shareable address.

---

## How it works

Four GPU passes. The important idea is that **the raycast runs once per
character cell, not once per pixel** — a 1280x720 window is only ~10,000 rays,
which is why this is cheap enough to run on a phone.

```
1  SCENE      → at cell resolution (x sub-sampling, see below)
                3-D DDA raycast through a height field, one ray per cell.
                MRT out: (lit colour, emissive mask) and (ink, kind, depth).

2  BLOOM      → separable blur of the emissive-masked colour, half res.

3  GLYPH      → per cell, choose which character to print.
                Ramp alphabets: Sobel over ink+depth picks a line glyph on
                silhouettes, otherwise a per-material luminance ramp.
                Sub-cell alphabets: threshold the SXxSY sub-samples against a
                Bayer matrix and print the glyph whose dots match.
                Out: (foreground colour, glyph index).

4  COMPOSITE  → at full device resolution. One glyph-atlas lookup per pixel,
                plus bloom, scanlines, chromatic aberration, vignette.
```

The glyph atlas is rasterised at runtime from the system monospace font into a
canvas at exactly the current cell size, so glyphs stay crisp at any DPI and
the file stays asset-free.

### The world

A 256x256 torus of grid cells baked into one RGBA8 texture — 256 KB for an
endless city:

| channel | meaning |
|---|---|
| `R` | height in 1.6-unit steps (0 = ground) |
| `G` | low nibble palette index, high nibble facade style |
| `B` | lit-window density |
| `A` | flag bits: road / road-axis / park / water / sign strip / roof beacon / plaza |

Generation, all deterministic from the seed: a torus-wrapped Voronoi diagram
assigns districts (each with its own height profile, palette family, window
density and signage rate); an irregular street grid of alleys, streets and
boulevards is cut through it; a canal is carved with bridges where roads cross;
the remaining blocks are BSP-subdivided into lots; each lot gets one building,
a park, or a plaza. A megaspire is planted at the centre. The spawn point is
chosen by scoring every road cell near the centre for carriageway width and
clear run length, then standing you mid-carriageway facing down the longest
view.

Nothing is stored per building — 1,900-odd buildings are a side effect of the
rules. The window pattern, signage, traffic and rooftop beacons are evaluated
analytically in the shader from world position, so they cost no memory at all.

### Ink is a separate channel from colour

The first version derived the character from pixel brightness, which is the
obvious approach and it looks wrong: dark blue concrete is dim, so towers came
out as black holes with windows floating in them.

So the scene pass emits **ink** — how densely a material should be typed —
independently of how bright it is. Concrete is dark navy but typed at ~0.35
density, so a tower reads as a solid mass of characters that happens to be
dark. Lit windows are typed at ~0.9. Distance multiplies ink, so the far city
thins out into blank paper rather than fading to grey. Art-directing coverage
and colour separately is what makes it look like the medium instead of like a
photo run through a filter.

---

## The alphabet switch (press `V`)

The same scene, printed four ways. This is the interesting part of the demo,
because it makes a normally invisible trade-off visible:

| alphabet | cell sampling | what it's good at |
|---|---|---|
| **ASCII** | 1x1 | *Legibility as material.* `X` reads as girder, `0` as window, `\|` as edge. Lowest fidelity, most character. |
| **TELETEXT** | 1x1 | Block-and-shade ramp (`░▒▓█`). Chunky, poster-like, very readable at a glance. |
| **QUADRANT** | 2x2 | 4x the spatial resolution for the same one-character cost, using `▘▝▀▖▌▞▛…`. |
| **BRAILLE** | 2x4 | 8x the resolution — `⠁⠂⠄⡀…` gives 256 dot patterns per cell. Highest fidelity, and it stops looking like text. |

Sub-cell alphabets render the scene at `cols*SX x rows*SY` and dither the
sub-samples through a 4x4 Bayer matrix, so the dots carry shape while the cell
colour carries tone. Unsupported glyphs are detected at startup by rasterising
a probe character and counting ink, so an alphabet the platform can't draw is
skipped instead of printing tofu.

Fidelity and legibility pull against each other. Braille is objectively the
better image and ASCII is the better *picture* — you lose the semantic reading
of a glyph the moment the glyph is only a dot pattern.

## Press `C`

Copies the current frame to the clipboard as literal text — the glyph index is
read straight back out of the GPU cell buffer, so what you paste is exactly
what is on screen. It is genuinely characters all the way down.

---

## SOURCE CITY — drop a file on it and walk that

The renderer doesn't care where the height field came from, so text can be the
input too. Drop a source file or a folder anywhere on the page (or press `O`,
or `U` to read this page's own source, or load `#repo=owner/name` for a public
GitHub repository) and the city becomes a rendering of that code.

| in the text | in the city |
|---|---|
| top-level block (function, class, CSS rule, markdown section) | one building |
| lines in it | **height** — your longest block is the megaspire |
| max indent depth | footprint |
| comment ratio | lit windows — and above 30%, the facade becomes a vertical garden |
| hash of its name | palette, so the same block is the same colour every time |
| exported / public | a neon strip up the facade |
| over 80 lines | a red aircraft beacon on the roof |
| file | district |
| **blank lines between blocks** | **the width of the street between them** |
| the block's name | the sign running up its wall |

Blocks are placed in source order, left to right and top to bottom, so walking
east along a row is reading down the file. Parsing is deliberately
language-agnostic — a new block starts on an unindented line that follows blank
space, which is what a function, a class, a CSS rule and a markdown heading all
look like from the outside. It works on JS, Python, GDScript, C, CSS, Markdown
and most things shaped like them.

The HUD names whatever you are looking at: point at a tower and it reads back
`shadeCore · 74 lines · depth 6 · 12% comment · ascii-city/index.html`.

Signage is rasterised into a label atlas — one row per block name — and the
scene shader runs it up the wall at a fixed 4.6 world units per letter. Letters
are therefore only a few character cells tall, which means **you often have to
switch to braille (`V`) to actually read a sign**. That is the fidelity
trade-off from the alphabet table, made load-bearing.

### The self-portrait

Press `U` on the hosted page and NOCTIS-7 reads its own source. You get 84
blocks and ~1,900 lines: a street made of its own blank lines, `frame` at 100
lines, `cityFromSources` at 115, `makeCity` at 152 — and the megaspire visible
from anywhere in the city turns out to be the 210-line block of shading code
that draws it.

---

MIT licensed, like everything outside `third_party/`.
