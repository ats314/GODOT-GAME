# Balance Notes — Milestone 1 economy simulation

Economy pacing is the design's #1 risk, so the slice's real constants were
simulated before the first playtest (focus-fire model: beam 26 DPS + one
turret ~15.6 DPS on the same target, each upgrade card ≈ +30% output,
spawn cadence/HP scaling exactly as coded in `spawner.gd`/`enemy.gd`,
costs `25 × 1.35^level`).

## Result: card cadence over a 12-minute run

| Ring level | Reached at | Gap | Wave |
| --- | --- | --- | --- |
| 1 | 9.8s | — | 1 |
| 2 | 21.1s | 11.3s | 2 |
| 3 | 40.4s | 19.3s | 3 |
| 4 | 61.0s | 20.6s | 5 |
| 5 | 74.8s | 13.8s | 6 |
| 8 | 146.4s | ~15–29s | 11 |
| 12 | 275.7s | 41.0s | 25 |
| 16 | 529.0s | 89.1s | 53 |

12 minutes ≈ ring level 17, wave 74, ~15k total mass.

## Verdict against design targets

- **First card inside 45s: PASS** (9.8s — comfortably inside the
  minute-one-must-sparkle requirement; the player is choosing an upgrade
  before the first wave ends).
- **Early cadence (levels 1–10): healthy** — a card every 10–30s keeps the
  "one more upgrade" pump primed.
- **Late cadence (level 13+): stretches to 45–90s.** Acceptable for the
  slice; the full game fills this with prestige pressure (first collapse is
  designed for minute 45–60) and richer mass sources. Flagged for M2:
  either soften the 1.35 growth after level 12, scale shard value with
  wave, or make tanks drop proportionally more.
- **Backlog sanity:** enemy backlog stays bounded (≤ ~40) through wave 50 in
  the model — kill rate keeps up if the player takes damage upgrades at a
  normal rate. Real playtest will validate.

## Known model limits

Single-target focus-fire only (no overkill waste, no travel time), upgrade
value approximated as uniform +30% output. Good enough to set pacing
expectations; the week-3 fun test is the real gate.

## Title collision (Steam research, 2026-08-07)

**"Accretion" is taken on Steam**: app 3614100 (ValarFerys, May 2025,
$9.99, ~62% mixed, open-universe celestial-body sim). Mechanically
unrelated, but one letter from "ACCRETE" — it would dominate our search
results and invite confusion. Decision needed before the Steam page:
keep ACCRETE as the working title, ship under an alternate. Candidates to
verify when chosen: STARMASS, FORTRESS SUN, SOLGROWTH, MASSBOUND.
