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
- **Other players** see a still solved cube on each pedestal (the server
  builds one) and the avatar behind it. Live turns for spectators are M2.

## Milestones

| | What | State |
|---|---|---|
| M1 | Pedestal ring, prompted solves, swipe + keys, combo, PERFECT, pop, coins, depth dial, leaderstats, saving | built, untested in Studio |
| M2 | **Cube boxes** (the gacha): cube skins, stickerless / mirror / glow looks, per-cube turning sounds, small coin multiplier, rarity tiers. Arrow fade: at higher tiers the last moves are unprompted. Live cubes for spectators. | design |
| M3 | Server sprints (same scramble for the lobby, first pop wins), global leaderboard (OrderedDataStore), daily streaks | design |
| M4 | Trading, golden / rainbow variants, seasonal boxes, gamepasses (2x coins, extra box slots) | design |

## Naming

"Rubik's" is Spin Master's trademark and their brand guide forbids third
parties using it; they also run their own Roblox experience. This game is
**Speed Cube** and its text says *cube* and *puzzle cube*, never Rubik's.
