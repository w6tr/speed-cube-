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

Then in Studio: **new Baseplate** -> **Plugins -> Rojo -> Connect** -> **Play**.
(The game removes the template's baseplate and spawn and builds its own
lobby; nothing in the place file matters.)

You appear behind a pedestal with a cube on it. The cube shuffles, then an
arrow appears on it.

| Do this | What happens |
|---|---|
| swipe (or press W A S D / arrow keys) the way the arrow points | that row or column turns, the next arrow appears |
| swipe the wrong way | the cube wobbles, the combo resets, swipes are ignored for 0.3s |
| swipe the last arrow | the cube pops, coins are paid, a new cube shuffles in |
| swipe within 0.35s of the last swipe | PERFECT (+1 coin each) |
| tap **-** / **+** bottom-right | change the depth (moves per cube); the ceiling rises every 3 solves |

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
goes. It cannot see the 3D placement, the UI or the remotes; those still
need Studio.

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
src/shared/     Config        every number: depth, coins, combo, timing, cube, camera, lobby, input, sounds, save
                Moves         the eight turns, their axes and angles, the arrow each one prompts, scramble generation
                Remotes       the wire format, and the payload types
                CubeBuilder   the 26 cubies with SurfaceGui stickers (server builds still ones, client the live one)

src/server/     init          builds the lobby, starts services, the join/leave sequence, stands the avatar
                LobbyBuilder  floor, the ring of pedestals, a still cube on each
                Services/
                  SolveService  deal / swipe / solve, combo, PERFECT, coins, leaderstats -- read this first
                  SaveService   DataStore (coins, solves, best per depth, the dial)

src/client/     init          wires remotes to the cube and HUD; checks swipes instantly; asks for the truth on doubt
                CubeView      draws and turns the live cube, the arrow prompt, the pop, the wobble, sounds
                Input         touches, drags and keys -> Up / Down / Left / Right
                Hud           coins, timer, step, combo, hint, depth dial
                CameraRig     fixed three-quarter view of the pedestal
                Theme, Toasts

tools/          test-moves    the headless proof of the move maths
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
