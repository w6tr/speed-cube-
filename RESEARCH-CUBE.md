# Research — what Speed Cube is built from

The rule on every project in this studio: start from a proven system, then
say what was adopted, what was rejected, and why. This file is the
reference for anyone reviewing a change.

## 1. The input: swipe-on-face, from the mobile cube apps

**Source.** Magic Cube Puzzle 3D, CubeX, cube-solver.com: all converge on
one gesture, *swipe across the stickers and the layer under the finger
turns in the swipe direction*. Their App Store reviews list the failures:
swipes that orbit the whole cube instead of turning a layer, the wrong
layer turning, swipes not registering, "something you didn't want to move
moved".

**Adopted.** The direction-only swipe. Because the prompt has already
chosen the layer, the input only has to supply *which way*, so a swipe
anywhere on the screen works and none of the layer-picking failures exist.

**Adopted.** Commit on distance, not on lift (`Input.luau`): a drag of
`SwipeMinPixels` fires immediately, one swipe per touch. A fast flick
registers before it is over.

**Rejected.** Orbit-the-cube dragging. The camera is fixed at a
three-quarter view that shows the front, top and right faces, so every
prompted layer is always visible and nothing can be swiped by accident.

## 2. Input buffering, from csTimer's virtual cube

**Source.** csTimer (the speedcubing community's standard timer) has a
virtual cube driven by keys; fast cubers type moves faster than the
animation and the cube queues them. Its key layout mirrors finger tricks.

**Adopted.** Turns are queued (`CubeView.turn` → worker) and the logical
step advances on the swipe, not on the animation. A player who swipes
ahead of the animation sees the cube catch up.

**Rejected (for now).** The csTimer key layout. With the arrow prompts,
the four arrow keys / WASD are enough and match the touch input exactly.
Worth revisiting if a "no arrows" expert tier lands (M2).

## 3. The combo and the pop, from rhythm and endless runners

**Source.** Beat Bounce (Geometry Dash clone, on Roblox's trending puzzle
chart) and Subway Surfers: four directions, a combo that resets on a miss,
timing windows, and a feedback burst on every hit. Pure prompt-following
goes stale in minutes; what keeps it alive is stakes (the streak) and
escalation.

**Adopted.** Combo across solves with a capped multiplier; a PERFECT
window for quick consecutive swipes; a pop with particles and a sound on
every solve; a brief lockout on a wrong swipe as the "stake".

**Rejected.** Music-synced timing. The cube sets its own pace; PERFECT is
measured from the previous swipe, so it rewards flow, not rhythm.

## 4. Depth as the difficulty dial, from Drift & Flip's assist rule

**Source.** In Drift & Flip the throttle assist is the difficulty setting,
not a menu option. Here the scramble depth is the same kind of dial:
longer sequences pay more and risk more, and the dial's ceiling rises with
solves.

**Adopted.** `Config.Depth`: Start 5, Min 3, Max 15, +1 every 3 solves.
The player chooses any depth up to the ceiling.

**Planned (M2).** Arrow fade: at higher tiers the last moves show no arrow,
bridging prompted play to real cube reading.

## 5. The gacha loop, from the pet simulators (M2)

**Source.** Pet Simulator 99's egg loop: eggs, rarity tiers, golden and
rainbow variants, hatch animation, trading. Day-30 retention on those
loops is unusually flat for Roblox.

**Adopted for M2.** Cubes are the pets: looks, a turning sound, a small
coin multiplier. "Cube boxes" mirror both the eggs and real cubing
unboxings on YouTube. The turning sound is the differentiator: the
top-ranked search result for the genre today is an ASMR keyboard game
with 120K concurrent players.

**M1 constraint honoured.** Everything a box would hand out is a
*cube id*; the server owns coins, the client owns looks and sounds. No
code in M1 needs to change for boxes, only additions.

## 6. Roblox facts used

- **SurfaceGui stickers.** One Part per cubie, six coloured frames as
  SurfaceGuis with a UICorner. 26 parts per cube, no sticker parts to
  move. `LightInfluence` keeps them readable in the fixed light.
- **Client-side cube.** The live cube is built by the client in Workspace
  and never replicates. Other players' cubes are ALSO client-built
  copies, driven by server broadcasts of accepted moves (M2); the server
  builds no cubes at all. Sync seeds each copy with the current deal id,
  scramble and step; a deal id already drawn is never redrawn, so a copy
  is never reset under a running animation. Roblox's "Front" NormalId is −Z; the cube's
  front face toward the camera is +Z, so the arrow's SurfaceGui uses
  `Face = Back`.
- **Right-hand rule.** A clockwise face turn is a negative angle about
  that face's outward axis. `tools/test-moves.luau` proves every
  inverse, every scramble/solution pair and every arrow direction under
  Lune, with the real `Moves.luau`.
- **Snap after every turn.** Positions rounded to the grid and rotation
  axes rounded to unit vectors, so 10,000 turns never drift.
- **Built-in sounds.** `rbxasset://sounds/*.wav` ship in the client and
  need no asset ids. They are placeholders for per-cube sounds.
- **The handshake.** As in Squadrun: the client asks `RequestSync` until
  answered, so a RemoteEvent fired before the client connected is never
  lost.

## 7. Market notes (2026-09-17)

| Game | What it is | Visits |
|---|---|---|
| Grow Your Rubik's Cube | eat-cubes-to-grow sim, no solving | 45.2M |
| Rubik's Cube (DwewyNPC, 2018) | real solving | 708K |
| Solve a Rubik's Cube (2024) | real solving, leaderboard | 212K |
| Rubik's Cube Simulator (2017) | real solving | 128K |
| Rubik's Run (Spin Master, official) | obby runner | absent from search |

Trending puzzle chart the same day: word games, sorting games and "IQ
tests" at 1K–12K concurrent each. That is the realistic band for a
puzzle-shaped game; the clips are the upside.

## 8. Trademark

Spin Master's brand guide: third parties must say "puzzle cube" or "magic
cube", never "Rubik's". The game name, UI text and store page follow that.
