# Speed Cube — design

*Decided 2026-09-17. The fourth Roblox game, alongside Drift & Flip, Drop &
Roll and Squadrun.*

## The one-line pitch

A puzzle cube drops onto your pedestal a few moves from solved. Arrows on
the cube tell you which row or column to swipe and which way. You swipe
them, the cube pops, coins fly out, the next cube drops. Speed and a clean
streak are the whole game.

## Why this game

- **The clips are huge, the market is empty.** Speedcubing clips of kids
  from China (Ziyu Ye's 0.39s 2x2, Yiheng Wang's 3.51s average) went viral
  in 2025–26. On Roblox, every game that asked players to *actually solve*
  a cube stayed tiny (the biggest has 0.7M visits over eight years); the
  one cube-branded hit, a "grow your cube" eating sim with 45M visits, does
  not involve solving at all. The icon has pull. The skill has never been
  made accessible.
- **Zero skill floor by design.** Most Roblox players cannot solve a cube.
  The arrows carry them. It plays like a rhythm game or Subway Surfers'
  four swipes, which the platform already loves, wearing a cube costume.
- **The cube is honest.** The arrows are the real moves. The scramble is
  the answer played backwards, so the last swipe genuinely solves the cube
  with the player's own hands. That is why the pop feels earned.
- **One input on every device.** Four swipes or four keys. No layer
  picking, no drag-to-orbit, none of the failure modes the mobile cube apps
  are criticised for.

## The loop

1. **Deal.** The server picks `depth` moves (no two on the same face in a
   row), inverts and reverses them into a scramble, and sends both. The
   client resets its cube and plays the scramble as a quick shuffle.
2. **Prompt.** An arrow sits on the front face over the row or column that
   has to turn, pointing the way. The HUD repeats it as a hint.
3. **Swipe.** Right direction: the layer turns, the next arrow appears, the
   combo climbs. Wrong direction: the cube wobbles, the combo resets, and
   swipes are ignored for a moment (so mashing four directions is slower
   than playing).
4. **Pop.** On the last move the cube swells, bursts confetti in sticker
   colours, and the server pays coins:
   `(1 per move + 5 solve + 5 if fast + 1 per PERFECT) × combo multiplier`.
   PERFECT is a correct swipe within 0.35s of the previous one. The combo
   multiplier is `1 + 0.1 × combo`, capped at ×3, and carries across
   solves.
5. **Depth.** Every 3 solves unlocks one more move of depth (start 5, max
   15). The dial lets the player go shallower for a safe run or straight to
   their ceiling for more coins.

## Who owns what

- **Server** (`SolveService`): the deal, the step, the combo, the clocks,
  the coins, the best times, the leaderstats. Every swipe is checked here;
  the client's copy is for zero-lag feedback only.
- **Client** (`CubeView`, `Input`, `Hud`): draws the cube, checks each
  swipe against the same deal for an instant turn or wobble, sends the
  direction, redraws from the server whenever a Sync disagrees.
- **Other players** see your cube turning for real: the server broadcasts
  every accepted move, deal and pop with your pedestal index, and each
  client keeps a silent copy of your cube in your equipped look. Nothing
  a client sends can fake a turn on someone else's screen.

## Milestones

| | What | State |
|---|---|---|
| M1 | Pedestal ring, prompted solves, swipe + keys, combo, PERFECT, pop, coins, depth dial, leaderstats, saving. Feel pass: arrow lane, combo streak, solve card, first-play nudge, one-press chained swipes. | **playing in Studio** (2026-09-17) |
| M2 | **Cube boxes** (the gacha): cubes with a look, a turning sound and a small coin multiplier; rarity tiers; the hatch animation; a collection screen with one equipped cube. Live cubes for spectators. A lobby leaderboard board (server bests per depth). Robux plumbing (coin packs, box bundles) with blank product ids until tuned. | next |
| M3 | Server sprints (same scramble for the lobby, first pop wins, a crown), global weekly leaderboard (OrderedDataStore), daily streak + daily quests paying boxes, **rebirth** (reset coins and depth for a permanent multiplier), arrow fade at high depth | design |
| M4 | Gamepasses (2x coins, VIP cube), seasonal boxes with limited cubes, trading, golden / rainbow variants, **per-cube arrow skins** | design |

**Decisions taken 2026-09-17 (CEO):** cubes DO have power (a coin multiplier, capped around +50% for the best); rebirth lands in M3 after boxes exist; the economy runs on coins only until it is tuned on real play, but the Robux purchase plumbing ships in M2 with blank product ids so it can be switched on without code; public release tentatively after M2; the name "Speed Cube" is a placeholder to revisit.

## The look

**Decided 2026-09-17 (CEO): a speedcubing competition floor, staged like
an esports final.** Real competition furniture — mats, timer pads,
station numbers, hoardings round the floor, a raked bank of seating — lit
the way a final is lit: a dark hall at night, coloured rim light, bloom,
haze, every cube the brightest thing in its own frame. The authenticity
is what gives the game an identity no other Roblox cube game has taken;
the staging is what makes it worth clicking.

### The one fact the whole hall is built on

**The camera is locked and nobody can look around.** `CameraRig`
re-applies it every `RenderStepped`, so all eight seats see the same
picture forever. The eye sits at pedestal height + cube height + the
camera offset — 9.25 studs as those are set today, and it moves whenever
any of them do — pitched 30° down at the cube, 55° field of view. That
puts the TOP edge of the frame 2.5° *below* the horizon, so the frame's
ceiling falls about a stud for every 23 studs of distance. Measured in
the engine by `tools/smoke-arena.luau`: the middle of the top edge lands
on the fourth row of seating at **y = 6.77, 56 studs out**.

That is the *middle* of the top edge. The **corners** of a wide screen
look along rays that fall away more slowly and reach y = 8.46 in the
worst ultrawide case — which the same test now measures, because Roblox's
field of view is vertical, so it is width and not height that varies
between a phone and a monitor. (A narrow phone screen sees the same
height and less width, which makes phones the safe case, always.)

So `Config.Arena.SeenHeight` is the height below which detail is worth
**building** — not a promise that nothing above it is ever seen.
Everything the eye actually lands on lives between the floor and about 7
studs, which is exactly what a competition floor is anyway, and that is
where the budget goes. The back wall is deliberately 17 studs tall so it
still covers the ultrawide corner, and the first second of a session,
before the first Sync arrives and while the camera is still Roblox's own
and the player can look wherever they like. The truss and the lamp
housings are out of frame during play; they exist for that first second
and for the store icon.

### Where it lives

| | |
|---|---|
| `Config.Look` | the lighting rig's numbers |
| `Config.Arena` | the hall: radii, heights, colours, the hoarding texts |
| `src/server/Look.luau` | applies the rig at boot |
| `src/server/Arena.luau` | builds the hall around the ring (315 parts, 73 of them Neon, 16 lights) |
| `default.project.json` | the same lighting again, for Studio's edit view, plus `Technology` — which a script may neither read nor write |

`Arena` never touches a pedestal CFrame; it only positions things *from*
them, so the camera, the cube and every spectator copy stay exactly where
the rest of the game puts them. Both it and the lighting rig run inside a
`pcall`: they are decoration, and a bad property in either must not be
able to take a live server down with it.

The numbers above are printed by `tools/smoke-arena.luau`. Re-run it
rather than hand-copying them when the config changes.

### Still to do

**Per-cube arrow skins are M4** (CEO, 2026-09-17). The arrow is a
cosmetic you stare at every second of play, so it is the highest
perceived value per unit of work in the gacha, and it doubles as the
rarity signal the arena currently lacks. It waits for M4 with the other
cosmetics rather than shipping alongside M2's boxes. The rule when it
lands, already written into `Config.Cube.Arrow`: only the arrow's colour
and glow may vary per cube. Its size, outline and pulse are the readable
skeleton and never change, because a cube you unlock must never be
harder to play than the one you started with.

The centre board, the crowd, per-tier cube VFX (a light and a sparkle on
the Epics and the Legendary), and hall lighting that answers a combo and
a pop. Then the store icon and thumbnails, shot in-engine with a free
camera.

## Naming

"Rubik's" is Spin Master's trademark and their brand guide forbids third
parties using it; they also run their own Roblox experience. This game is
**Speed Cube** and its text says *cube* and *puzzle cube*, never Rubik's.
