# SPEEDRUN THIS

**"The game is cheating. The narrator says you're bad."**

A rage-comedy platformer where every level looks trivially simple — but the game is secretly sabotaging you. An invisible cheat engine escalates with each death: walls appear out of nowhere, gravity spikes mid-jump, controls reverse at the worst moment, and the goal *runs away from you*. Meanwhile, a smug narrator insists nothing is wrong.

## Controls

| Action | Keyboard | Controller |
|--------|----------|------------|
| Move | A/D or ←/→ | Left stick |
| Jump | Space or W or ↑ | A button |
| Restart | R | Y button |
| Pause | Escape | Start |

## Levels

1. **WALK RIGHT** — Just walk to the flag. What could go wrong?
2. **THE JUMP** — One gap. That's all this is.
3. **STAIRS** — Three platforms going up. Simple geometry.
4. **THE CORRIDOR** — A straight line. I literally made this a straight line.
5. **WALK RIGHT (AGAIN)** — Same as Level 1. Should be easy now. Right?

## The Cheat Engine

Each level has escalating sabotage tied to your attempt count:

- **Invisible walls** — collision shapes with no visual
- **Floor gaps** — the floor *looks* solid but isn't
- **Gravity spikes** — heavier gravity mid-jump, right when it hurts
- **Platform shrink** — collision is narrower than the visual
- **Speed drain** — you get slower and slower each second
- **Control reversal** — left becomes right for a brief, awful moment
- **Goal flee** — the finish flag runs away when you get close
- **Wind** — invisible headwind in the worst spots
- **Platform slide** — landing platforms drift sideways
- **Coyote time removal** — can't jump after walking off an edge
- **Ceiling crush** — the ceiling pushes you down near certain spots
- **Bouncy floor** — random sections of floor launch you upward

After beating each level, the game reveals exactly which cheats it used against you.

## The Narrator

The narrator has five personality phases based on your attempt count:

1. **Professional** (1–3): Polite but condescending
2. **Condescending** (4–7): Backhanded compliments
3. **Defensive** (8–14): Insists the game is fair
4. **Cracking** (15–24): Starting to feel something
5. **Breaking** (25+): Full confession

## Technical Notes

- **Zero art assets** — all visuals drawn procedurally via `_draw()`
- **Zero audio files** — all SFX synthesized from math at startup
- **Godot 4.7** — same engine and approach as ACCRETE
- Targets 1920×1080, stretch mode `canvas_items`

## Running

Open `speedrun_this/project.godot` in Godot 4.7+ and press Play.
