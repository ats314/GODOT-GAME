# Predicting a skyline, and failing usefully

An attempt to predict Manhattan's building heights from public data alone, and
what the failure tells you. All inputs are public and read directly from S3 with
no downloads: USGS 3DEP lidar for measured heights, Overture Maps for the street
network and point-of-interest density.

## The model

Standard monocentric bid-rent: land rent falls with distance from activity, and
developers substitute capital for land by building upward where rent is high.

```
log(height) = a·log(activity) + b·log(centrality) + c·log(major-road density) + d
```

`activity` is POI density smoothed at 640 m, `centrality` is inverse distance to
the activity-weighted centroid, `major-road density` is motorway/trunk/primary/
secondary rasterised and smoothed at 128 m.

## Scale inverts the answer

Fitted inside a single 1 km box in Midtown:

| predictor | r |
|---|---|
| POI density | **+0.13** |
| major-road proximity | **−0.11** |

The model concludes that **being near a big street makes buildings shorter**.

Widen the fit to 8.2 km and the same predictors, unchanged:

| predictor | r | r² |
|---|---|---|
| POI density (~640 m) | **+0.575** | 0.330 |
| inverse distance to activity centroid | +0.376 | 0.141 |
| major-road density | +0.283 | 0.080 |

Combined fit **R² = 0.333** over 43,830 building cells.

Manhattan's 1811 Commissioners' Plan deliberately flattened local access
variation — a uniform grid is the point of it. Below about a kilometre there is
no gradient left to measure, and you are sampling inside one bump of it. This is
why `bake_city_model.py` fits on a wide coarse tile and evaluates on a narrow
fine one, resampling the predictor fields rather than recomputing them (a 640 m
blur inside a 1 km box degenerates to a constant).

## The honest result

- Fitting at 8.2 km: **R² = 0.333**
- Transferring that fit to a 1 km tile at 4 m cells: **R² = −0.105**

Negative R² means worse than predicting the mean. Both numbers are the finding:

**Where the city puts its mass is economically predictable. Which building is
tall is not.** At kilometre scale, a third of the variance in height follows
activity and access. At block scale, none of it does — that is decided by the
zoning envelope, landmark status, air rights already sold, whether a developer
could assemble the lot, and when it was built.

## The residual

`residual = measured − predicted`, mean +6.1 m, sd 27.0 m, range −53 to +367 m.

Mapped over the island it is not noise. Midtown runs systematically positive
(taller than activity alone explains). A broad negative band runs up the West
Side through Chelsea, the West Village and Hell's Kitchen — areas that are
low-rise relative to their centrality, and which carry historic districts and
special zoning districts that cap height.

That correspondence is suggestive, **not verified**. Confirming it needs NYC's
PLUTO tax-lot and zoning data, which this environment cannot reach. Until then
the residual is a map of what the economic model does not know, and the
suspicion that most of it is law.

## Reproducing

```bash
# measured heights: wide coarse tile to fit on, narrow fine tile to walk
python3 tools/bake_lidar_city.py --lat 40.7480 --lon -73.9860 --cell 32 --depth 7 --out wide.png
python3 tools/bake_lidar_city.py --lat 40.7530 --lon -73.9860 --cell 4  --depth 10 --out fine.png

# fit wide, evaluate fine
python3 tools/bake_city_model.py \
    --fit-png wide.png --fit-lat 40.7480 --fit-lon -73.9860 --fit-cell 32 \
    --eval-png fine.png --eval-lat 40.7530 --eval-lon -73.9860 --eval-cell 4 \
    --out model.png --report model.json
```

62.5 million lidar points, 21,017 road segments and 138,034 places went into the
wide fit. Nothing was downloaded in full: Overture ships ~450 MB parquet shards,
and GeoParquet's per-row-group bbox statistics mean the footer alone identifies
which one or two row groups can intersect the area. 128 shard footers are read
concurrently over HTTP range requests in about 35 seconds.
