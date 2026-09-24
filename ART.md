# Speed Cube — the art

*Started 2026-09-24. The goal: every visual building block of the game
ready and good enough that developers write gameplay into it and the
leads and the CEO direct the vision instead of arguing about lighting.*

**The gate:** every piece is scored 0–10 by the `art-critic` skill — a
fresh-context critic playing a front-page Roblox developer who judges
visual appeal and player pull, not code. Below 8 it comes back with a
ranked list and the piece goes around again, up to three more rounds.
Every round is logged in `art/critic-log.md`; the latest score lives in
the table below. **Nothing is finished at a 7.**

**How art exists in this game:** everything is built from parts and
SurfaceGuis at boot, by Luau, from numbers in `Config.luau`. There are no
imported meshes, textures or images yet. That is a strength (nothing to
lose, everything tunable, versioned in git) and a ceiling (no sculpted
shapes, no painted textures). Whether to add a mesh pipeline is an open
question below.

## What exists today

| piece | where | state | seen by eye | score (round, date) |
|---|---|---|---|---|
| The hall — floor markings, hoardings, stands, wall + LED band, truss + lamps | `Arena.luau`, `Config.Arena` | built | yes | **5** (r1, 2026-09-24) — a dark set, not a lit final |
| The lighting rig — night, atmosphere, bloom, grade, DOF | `Look.luau`, `Config.Look` | built, tuned twice | yes | scored with the hall: **5** — no rim light, no pools, no haze |
| Stations — plinth, mat with painted number / pads / best line, light pool | `Arena.luau`, `LobbyBuilder.luau` | built | yes | **5** (r1) — parts, not furniture; seven read as dark drums |
| Rarity tint on the station (per tier) | `Arena.setStationTier` | built | yes (Epic purple confirmed) | scored with the stations: the system is right, the Epic trim is the arrows' magenta |
| Sprint crown — the winner's station lit white | `Arena.setStationCrown` | built | yes (painted client-side for the capture) | scored with the stations: white reads as "that light is on", not "winner"; keep white, add a cone from above; green would be worse |
| The crowd in the stands | `Arena.luau`, `Stands.Crowd` | built | **invisible from any seat** | not scorable; the hall critic wants the front rows lit with a crowd you can see |
| The cube — 26 parts, SurfaceGui stickers, rounded | `CubeBuilder.luau` | built | yes | **7.75** (r4, out of rounds; 6 → 7 → 7.5 → 7.75) — the arrow layer is the instruction now; a filament and a red-safe ring are queued |
| 13 cube looks — a finish per tier: matte Commons, candy Rares, Epics that emit light, a rainbow Prism | `Defs/Cubes.luau`, `CubeBuilder.luau` | built | **yes, all 13** (cycled on the live pedestal) | **8** (r4, CLEARED; 5 → 6 → 7 → 8) — Jelly reads dark, queued first for any later pass |
| Arrow prompts — white-cored magenta three-ring glyphs, a lit bezel on the moving row, the same glyph in the lane and the pill | `CubeView.luau`, `Hud.luau`, `Config.Cube.Arrow` | built | yes | scored with the cube: **7.75** |
| The pop — swell + confetti burst + result card | `CubeView.luau`, `Toasts.luau` | built | yes (captured 0.5 s after a solve) | **5** (r1) — a receipt, not a reward; the card hides the cube |
| The hatch — a sealed competition case in the tier colour on a dimmed stage: gold lid, lit seam, a soft pillar of light, sparks, a flash from the seam, sticker-chip confetti | `Hatch.luau`, `Config.Hatch` | built | yes (34 frames per round, no purchase) | **7** (r3; 4 → 6 → 7) — round 4 is BUILT (sticker-part chips, a nine-layer pillar, a gold lid face, pouring sparks, the mat text hidden) but NOT yet captured or scored |
| HUD — coins, timer, combo, arrow lane, best line, sprint line, depth dial | `Hud.luau`, `Theme.luau` | built | yes | **5** (r1) — no identity; the arrow lane is nearly invisible |
| CUBES screen — every card a turning 3D preview of its cube (locked ones dark silhouettes) on a tier-coloured tile, the boxes drawn as the sealed cases, the Pro box visibly premium, the hall dark behind the panel | `CollectionPanel.luau`, `CubeBuilder.buildPreview`, `Config.Panel` | rebuilt | round 2 NOT yet captured | **4** (r1) — the rebuild is built and boots clean; its round 2 waits for a capture |
| Toasts — PERFECT, combo, info, big | `Toasts.luau` | built | the result card only | scored inside the HUD and the pop |
| Store icon + thumbnails | — | **none** | — | — |
| The avatar | none: characters no longer spawn (`Players.CharacterAutoLoads = false`) | done | gone from every frame | block 0 done 2026-09-24 |
| Sound | Roblox built-ins | placeholder | — | — |

The baseline pass ran on 2026-09-24: every piece that could be captured
went through the gate once. Every round is in `art/critic-log.md`, with
the critic's ranked list per piece. Nothing scored above 6. The pattern
across all eight reports: the *systems* are right (palette, tier
colours, the underglow, one accent) and the *finish* is missing — light
that only darkens, panels that are rectangles, products never shown,
arrows quieter than the stickers.

## The building blocks to make

Revised after the baseline pass (2026-09-24), ordered by score moved per
hour of work, most first. Each is a piece the critic scores on its own;
the full ranked lists are in `art/critic-log.md`.

0. **The avatar out of the frame.** Every one of the eight critics
   flagged the hair behind the cube; it is a full point on the cube, the
   hatch and the hall, and the cheapest point on the board. Hide it, or
   seat it below the mat line. First, because it lifts four pieces at
   once.
1. **The cube skins as a system, with tier VFX** (looks 5, cube 6).
   Arrows centred, two-thirds of a sticker wide, lit, with a dark halo;
   the moving row marked; the Rares as glossy gradients and translucent
   candy that deliver their names; the Prism a prism (bloom pulled back,
   a hue per face or an iridescent finish); Void leaking violet from its
   seams; the pale Commons saturated and Frost's body black; rim light
   on every cube; the rule that an arrow colour never shares a hue with
   a sticker. Deliverable: every look captured again and scored; a
   `Look` + VFX recipe a developer can add a fourteenth cube to.
2. **The hatch** (4). The box the brightest thing in the frame, in its
   tier colour, lid on top and metallic, a glowing "?", a glow that grows
   through the rattle; the hall dims and the play HUD goes; a real burst
   with a flash and a ring across the floor. The critic wants the wooden
   crate replaced by a competition cube case — a CEO call.
3. **CUBES screen cards with live 3D previews** (4). A rendered cube on
   every card, locked ones as dark silhouettes; the Pro box visibly
   premium; a backdrop dim; tier as a fill, not a hairline; the edges
   finished (EQUIPPED ribbon, padding, a real header).
4. **The pop** (5). A chunky outlined "+21" with a coin, above the cube
   instead of a card over it; a real burst with a flash; NEW BEST as a
   stamp; the station flashes gold; nothing on screen that contradicts
   the card.
5. **A HUD kit** (5). The timer as an esports scorebug with a
   state-coloured edge; the arrow lane on a pill in the arrows' magenta;
   no debug strings ("(max 15)", "A or Left arrow"); a coin icon, the
   cube name in its tier colour, a pressable CUBES with a badge; the
   combo out from under Roblox's player list. One language every later
   screen inherits.
6. **The station as furniture** (5). Every station lit with a house ring
   that carries across the hall; the pool a soft additive gradient; one
   piece of furniture (margins, a rim and a foot, a thin bound mat, a
   timer unit with a readout); numbers that read from every seat; the
   mat black rubber; Epic trim violet so magenta stays the arrows'. The
   crown keeps white and gains a cone of light from above.
7. **The hall lit** (5). Lamps that cast pools, rim light on every
   pedestal, haze; hoardings as lit coloured panels; the LED rail's
   polygon corners smoothed. The critic also wants the frame rebalanced
   (the opposite station directly behind the cube) and a hero piece on
   the far side (a big screen, a crowd you can see) — CEO calls, and
   the answer to "the crowd, or its removal".
8. **Store icon + thumbnails.** A beauty-shot camera rig in-engine: the
   cube filling 60% of frame, three-quarter view, one giant arrow, a
   bright saturated background — nothing like the gameplay camera. The
   CEO screenshots it; there is no image generator in the toolchain.
9. **Sound.** Not art, but half of juice. Creator Store ids for the turn,
   the pop, the hatch, the sprint.

## Open question: a mesh pipeline?

Parts can do a competition hall; they cannot do a trophy, a mascot, a
sculpted stand, or a stylised timer. **Blender is not installed on this
machine** (checked 2026-09-24), so there is no mesh pipeline today. If
it were installed, the `mesh-forge` skill could build a `.obj`/`.fbx`
that, imported through Studio's Asset Manager, becomes a MeshPart with
an id the code can reference -- a real path to building-block *assets*
rather than builders. Decide after the first pass through the gate: if
the parts-built pieces clear 8, we may not need it; if they cannot, the
CEO installs Blender and we open that door.

## Working rules for this phase

- Every piece goes through `art-critic` before it is called done, and
  the log records every round.
- `aesthetic-eye` when the question is *why* a player would feel a way;
  the critic when the question is *is it good enough*.
- Look before tuning: `studio-loop` preflight and capture, never a number
  changed on a guess. That rule cost an evening once.
- The direction stands: a speedcubing competition floor, staged like an
  esports final — "competition floor vibes with a pop". A piece can be
  beautiful and wrong.
