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

| piece | where | state | seen by eye | score |
|---|---|---|---|---|
| The hall — floor markings, hoardings, stands, wall + LED band, truss + lamps | `Arena.luau`, `Config.Arena` | built | yes | — |
| The lighting rig — night, atmosphere, bloom, grade, DOF | `Look.luau`, `Config.Look` | built, tuned twice | yes | — |
| Stations — plinth, mat with painted number / pads / best line, light pool | `Arena.luau`, `LobbyBuilder.luau` | built | yes | — |
| Rarity tint on the station (per tier) | `Arena.setStationTier` | built | yes (Epic purple confirmed) | — |
| Sprint crown — the winner's station lit white | `Arena.setStationCrown` | built | **no** (needs two players) | — |
| The crowd in the stands | `Arena.luau`, `Stands.Crowd` | built | **invisible from any seat** | — |
| The cube — 26 parts, SurfaceGui stickers, rounded | `CubeBuilder.luau` | built | yes | — |
| 12 cube looks — Common recolours, Rare stickerless, Epic glow, Legendary Prism | `Defs/Cubes.luau` | built | only Classic, Mint, Neon | — |
| Arrow prompts — magenta glyphs, outlined, pulsing | `CubeView.luau`, `Config.Cube.Arrow` | built | yes | — |
| The pop — swell + confetti burst | `CubeView.luau` | built | **no** (motion; never captured) | — |
| The hatch — box drop, shake, reveal, burst | `Hatch.luau` | built | **no** | — |
| HUD — coins, timer, combo, arrow lane, best line, sprint line, depth dial | `Hud.luau`, `Theme.luau` | built | yes | — |
| CUBES screen — boxes + collection cards | `CollectionPanel.luau` | built | yes: **cards show "?" or a swatch, never the cube** | — |
| Toasts — PERFECT, combo, info, big | `Toasts.luau` | built | partly | — |
| Store icon + thumbnails | — | **none** | — | — |
| The avatar | default Roblox avatar behind the cube | untouched | yes: **an accessory pokes into frame** | — |
| Sound | Roblox built-ins | placeholder | — | — |

"—" in the score column means the critic has not seen it yet. The first
job of the art phase is to put every existing piece through the gate
once, so the table shows where we actually stand.

## The building blocks to make

In the order the reviews say they matter, most valuable first. Each is a
piece the critic scores on its own.

1. **The cube skins as a system, with tier VFX.** Twelve looks exist and
   nine have never been seen. The gacha's engine is *wanting the next
   cube*, and that needs Epic and Legendary to look obviously more
   expensive than Common — on the cube itself, not only on the plinth: a
   light in the tier colour, a sparkle on Legendary, the Prism actually
   prismatic. Deliverable: every look captured and scored; a `Look` +
   VFX recipe a developer can add a thirteenth cube to in five lines.
2. **The hatch.** The money moment, never seen. Pet Sim 99's egg opening
   is the bar: the box fills the frame, the rarity colour is a *beam*,
   the reveal has a beat. Deliverable: the animation, captured at its
   three key frames, scored.
3. **CUBES screen cards with live 3D previews.** A `ViewportFrame` per
   card showing the actual spinning cube in its real colours with a
   tier-coloured frame; locked ones shown darkened, so you can see what
   you are missing. This is the single change most likely to sell boxes.
4. **A HUD kit.** `Theme.luau` is the seed: panels, buttons, the coin
   icon, tier frames, toast styles, a font pairing — one visual language,
   applied everywhere, so a developer adding a screen gets the look for
   free. The panels are "clean but generic" today.
5. **The pop and the sprint's GO** as VFX. The pop has never been
   captured; the sprint has no visual beyond the HUD line and a toast.
   GO should hit the whole hall — the lamps, the LED band, a flash.
6. **The crowd, or its removal.** Sixty-six parts nobody can see. Light
   it, brighten it, or cut it.
7. **The avatar.** Hide it, seat it, or replace it with something that
   belongs — an accessory poking in behind the cube reads as a bug.
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
