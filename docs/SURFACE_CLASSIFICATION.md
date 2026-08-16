# Can the survey tell you what a surface is made of?

Yes, better than a first pass concluded — and the interesting part is how the
first pass got it wrong, because both of its answers were wrong in ways that
looked rigorous.

The question matters because the renderer picks a material per cell. Height,
water and vegetation already come from measurement. Road, pavement, plaza and
bare ground did not: everything below 2 m was flagged `ROAD`, so a plaza, a
courtyard and Fifth Avenue were the same material.

## The first answer, and why it was wrong

Ground truth was Overture road centrelines rasterised onto the grid, and the
comparison was per-feature medians with Cohen's d:

| feature | road | other ground | separation |
|---|---|---|---|
| intensity (raw) | 31.5 | 45.3 | 0.72σ |
| intensity (angle-corrected) | −16.6 | −3.5 | 0.71σ |
| roughness (z sd) | 0.08 | 0.10 | 0.11σ |
| single-echo fraction | 1.00 | 1.00 | 0.30σ |
| points/cell | 49 | 45 | 0.19σ |

The conclusion drawn was that lidar cannot separate road from other paved
ground at 4 m cells, and that a spectral sensor would be needed. That
conclusion was wrong, for three reasons.

**The labels were contaminated.** A centreline is one cell wide. A Manhattan
carriageway is 10–20 m, so two to four cells either side of every line are
genuinely road and were sitting in the negative class. Buffering each segment
by its own class width turns 24,345 centreline cells into 75,306 road cells,
and of 56,628 ground cells **43,536 are road**. The old negative class was
mostly road. Everything was being measured against noise.

**The metric was wrong.** Cohen's d on a skewed, unbalanced variable is a poor
proxy for whether a feature is usable. Intensity's "0.72σ" is **AUC 0.791**
once the labels are right — a genuinely useful single feature.

**Nothing was fitted.** 28,000 free labels were available and thresholds were
set by hand instead. Features worth 0.51 alone are worth a lot jointly.

## The second answer, also wrong

The obvious diagnosis was that a road is not a cell property — it is long,
thin, of constant width, flanked by buildings and joined into a network — so
morphology was added: distance transform of open space, corridor width, medial
ridge, structure-tensor anisotropy, flanking height, openness, building
fraction at two scales.

It does not help.

| model | AUC |
|---|---|
| per-cell lidar channels only | **0.897** |
| + six morphology features | 0.873–0.886 |

Shape features are strongly spatially structured, and the train/test split is
spatial (by column, with a gap) precisely because neighbouring cells are near
duplicates. So the morphology features largely encode *where you are*, and
carrying that across a spatial boundary costs accuracy rather than adding any.

## What actually worked

Channels the bake was already fetching and throwing away.

- **The intensity tail, not the mean.** Lane paint is retroreflective, so a
  painted cell has a bright *tail*; averaging is precisely the operation that
  destroys it. Counting returns above the 90th and 99th percentile keeps it.
- **Class 17.** 6.87 M of Midtown's 18.4 M points are classified as bridge and
  were being discarded. A bridge deck is a road surface.
- **Intensity spread within the cell**, which the tool had been accumulating
  (`s_int2`) and never using.

Individually these look worthless — 0.512, 0.531, 0.551 AUC. Jointly they take
the lidar-only model from 0.864 to **0.897**, because their value is in
interaction with mean intensity rather than on their own.

| stage | AUC |
|---|---|
| mean intensity alone | 0.791 |
| all original per-cell channels | 0.864 |
| + intensity tail, spread, class 17 | **0.897** |

Base rate is 76.9%, so quote AUC and average precision (0.939), not accuracy —
"always say road" already scores 0.769.

## What this changes

**No second sensor is needed for this.** ESA WorldCover and Sentinel-2 are
reachable and remain interesting for vegetation type and for cities whose
surveys are poorer, but road-vs-ground at 4 m is a lidar problem and the lidar
answers it.

## Not yet done

- Per-flight-line radiometric normalisation. One node carries **116 distinct
  `point_source_id`s**, and gain varies between flights; the only correction
  tried was a single global regression on scan angle, which is a real effect
  (−0.86 DN/degree) and bought nothing on its own.
- Cars. `height < 2.0` defines the ground plane, which deletes exactly the
  1.5–2 m objects that sit on roads and in car parks. Detecting them is likely
  a strong road and parking cue and the current framing throws it away by
  construction.
- Per-cell height histograms. The bake keeps max, min, mean and variance of z;
  the *distribution* is the standard discriminator between canopy and roof.
- Multi-class. Everything here is binary road-vs-ground. The renderer wants
  road / pavement / plaza / bare / grass, and those labels have to come from
  somewhere — ESA WorldCover is the obvious candidate for the non-road classes.
- Transfer to San Francisco, which is 16-bit intensity, has no class 17 to
  speak of, and is not a grid. A model fitted on Manhattan should be expected
  to do badly there, and that is worth measuring rather than assuming.

## Reproducing

```bash
python3 tools/bake_lidar_city.py --lat 40.7530 --lon -73.9770 --grid 512 \
    --depth 11 --out mh.png --dump mh_fields.npz
```

`--dump` writes the per-cell fields so a classifier can be retuned without
re-fetching 18 M points, which is what made it cheap to discover that the first
two answers were wrong.
