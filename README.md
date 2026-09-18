# Speed Cube

A prompted cube-solving game for Roblox. A puzzle cube lands on your
pedestal a few moves from solved; arrows on it show which row or column to
swipe and which way. Swipe them, the cube pops, coins fly out, the next
one drops. Speed and a clean streak are the game.

- **Why this game:** [DESIGN.md](DESIGN.md)
- **What it is built from and why:** [RESEARCH-CUBE.md](RESEARCH-CUBE.md)
- **Every number in the game:** [`src/shared/Config.luau`](src/shared/Config.luau)

---

## Running it

Same toolchain as the other three games: Rokit, Rojo 7.4.4, the Rojo
Studio plugin.

```bash
~/.rokit/bin/rojo serve
```

Then in Studio: open the **published** Speed Cube place -> **Plugins -> Rojo
-> Connect** -> **Play**. (The game removes the template's baseplate and
spawn and builds its own lobby; nothing in the place file matters.)

**The place must be published** (File -> Publish to Roblox As -> a private
experience of your own). On the current Studio, an unpublished place or a
local `.rbxl` makes Studio try to join a Team Create session for universe 0,
fail, and kick the play-test client 0.3 s in: the game freezes on its first
frame with dead inputs and the Output shows `Disconnect from 127.0.0.1|...`.
This cost an afternoon on 2026-09-17; it is not a bug in the game.

You appear behind a pedestal with a cube on it. The cube shuffles, then an
arrow appears on it.

| Do this | What happens |
|---|---|
| swipe (or press W A S D / arrow keys) the way the arrow points | that row or column turns, the next arrow appears |
| keep the finger (or mouse button) down and change direction | the next swipe commits without lifting; a long swipe is still one swipe; the same direction twice needs a lift |
| swipe the wrong way | the cube wobbles, the combo resets, swipes are ignored for 0.3s |
| swipe the last arrow | the cube pops, coins are paid, a new cube shuffles in |
| swipe within 0.35s of the last swipe | PERFECT (+1 coin each) |
| tap **-** / **+** bottom-right | change the depth (moves per cube); the ceiling rises every 3 solves |
| tap **CUBES** bottom-left | the collection: buy a Basic Box (150) or Pro Box (600), equip an owned cube |
| a box hatches | the cube on your pedestal turns into a box, rattles, bursts in the tier colour; a better cube equips itself |
| look across the ring | other players' cubes turn for real; the pillar in the middle lists the server's fastest times per depth |

The first things to eyeball in Studio:

1. **Do the arrows render?** They are the glyphs ▲ ▼ ◀ ▶ in a SurfaceGui.
   If you see empty boxes, change `ARROWS` in `CubeView.luau` and
   `Hud.luau` to `^ v < >`.
2. **Does the arrow sit on the right row?** U is the top row, D the
   bottom, L the left column, R the right. The maths is proven headless
   (below); the 3D placement is not until you see it.
3. **Does the avatar stand behind the cube facing you?** If it is inside
   the pedestal or facing away, `Lobby.StandBack` and the stand offset in
   `init.server.luau` are the knobs.
4. **Do the sounds play?** A click per turn, a fanfare on the pop, and a
   groan on a wrong swipe. They are Roblox's built-in `rbxasset://` sounds;
   if one is silent, swap its line in `Config.Sounds` for any Creator
   Store id.
5. **On a phone (Test -> Device), is the whole screen swipeable?** The
   default thumbstick and jump button are turned off in `init.client`; if
   a thumbstick still appears bottom-left, say so.
6. **Output** should show `[Speed Cube] server ready` and no red text.

### Saving in Studio

Saves only work in a **published** place with **Game Settings -> Security ->
Enable Studio Access to API Services** turned on. Until then the game runs
but warns `Studio: no DataStore access, playing without saving` in Output.

### Checking it on a phone

Open **Test -> Device** in Studio, pick an iPhone SE, and check the timer,
coins and depth dial all fit. The HUD scales to 55% on small screens. The
hint at the bottom says SWIPE on touch devices and names the keys on PC.

### The four numbers to tune first

All in `src/shared/Config.luau`:

| Number | What it changes |
|---|---|
| `Cube.TurnSeconds` (0.11) | how snappy a turn feels; lower is faster |
| `Timing.PerfectGap` (0.35) | how quick a swipe must follow the last one to be PERFECT |
| `Timing.WrongLockSeconds` (0.3) | the sting of a wrong swipe |
| `Depth.SolvesPerUnlock` (3) | how fast deeper cubes unlock |

---

## Proving the maths without Studio

```bash
~/.rokit/bin/lune run tools/test-moves.luau
```

Loads the real `Moves.luau`, builds a 26-cubie cube the way the client
does, and checks every inverse, every scramble/solution pair at depths
1–15, and that each arrow points where the front row or column actually
goes.

```bash
~/.rokit/bin/lune run tools/test-swipe.luau
```

Drives the real `Swipe.luau` with scripted finger paths: flicks, long
drags, reversals, corners, wobbles.

```bash
~/.rokit/bin/lune run tools/test-cubes.luau
```

Checks every cube definition (tier, six colours, multiplier inside its
tier's range and under the cap), that each box's odds add to 100, and
that 20,000 rolls per box land on the printed odds.

Neither can see the 3D placement, the UI or the remotes. For those there
is a real-engine loop: `rojo build` a place, then
`~/.rokit/bin/run-in-roblox --place <it> --script <a smoke script>` runs
the script inside a throwaway Studio window and prints its output here.

## Checks before every push

```bash
~/.rokit/bin/stylua src tools
~/.rokit/bin/selene src
~/.rokit/bin/rojo sourcemap default.project.json -o sourcemap.json
~/.rokit/bin/luau-lsp analyze --defs=globalTypes.d.luau --sourcemap=sourcemap.json src
~/.rokit/bin/lune run tools/test-moves.luau
```

`globalTypes.d.luau` is the Roblox API definition file (git-ignored);
download it once from
https://raw.githubusercontent.com/JohnnyMorganz/luau-lsp/main/scripts/globalTypes.d.luau
into the repo root.

---

## Layout

```
src/shared/     Config        every number: depth, coins, combo, timing, cube, camera, hud, lobby, input, sounds, boxes, hatch, products, board, save
                Moves         the eight turns, their axes and angles, the arrow each one prompts, scramble generation
                Swipe         finger paths -> directions (pure; tested)
                Remotes       the wire format, and the payload types
                CubeBuilder   the 26 cubies with SurfaceGui stickers; applyLook restyles a cube in place
                Defs/Cubes    the twelve cubes: look, sound, multiplier, tier

src/server/     init          builds the lobby, starts services, the join/leave sequence, stands the avatar
                LobbyBuilder  floor, the ring of pedestals
                Leaderboard   the pillar: fastest per depth and most solves on this server
                Services/
                  SolveService  deal / swipe / solve, combo, PERFECT, coins, spectate broadcasts -- read this first
                  CubeService   boxes, hatching, equipping, Robux receipts
                  SaveService   DataStore (coins, solves, bests, the dial, cubes, equipped, receipts)

src/client/     init          wires remotes to the cube, HUD, collection and spectators; checks swipes instantly
                CubeView      a live cube: turns, the arrow prompt, the pop, the wobble, looks, sounds
                Spectators    one silent CubeView per other player, driven by Spectate events
                Hatch         the box-opening animation
                CollectionPanel  the CUBES screen: boxes to buy, cubes to equip, Robux buttons when ids are set
                Input         touches, drags and keys -> Up / Down / Left / Right
                Hud           coins + cube, timer, arrow lane, combo, solve card, nudge, depth dial, CUBES
                CameraRig     fixed three-quarter view of the pedestal, the pop punch
                Theme, Toasts

tools/          test-moves    the headless proof of the move maths
                test-swipe    scripted finger paths through the swipe rules
                test-cubes    cube definitions, box odds and roll distribution
```

Read `Config.luau`, then `Moves.luau`, then `SolveService.luau`, then
`CubeView.luau`.

---

## Before publishing

1. Set the place's **max players to 8** (Game Settings -> Basic Info). There
   are eight pedestals; a ninth player is kicked with a polite message.
2. Turn on **Enable Studio Access to API Services** and test a save: solve a
   few, stop, play again -- the coins should still be there.
3. Never call it Rubik's anywhere: the name, the description, the icon.
   "Puzzle cube" and "speed cube" are fine.
4. To sell coin packs or box bundles for Robux: Creator Dashboard ->
   Monetization -> Developer Products, make one per entry in
   `Config.Products`, paste each id over the `0`. The buttons appear on
   their own. Leave the ids at 0 until the coin economy has been watched
   on real players.
