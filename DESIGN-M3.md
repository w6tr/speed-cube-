# Speed Cube — M3a: the sprint, and your times on your mat

*PROPOSAL, 2026-09-24. Not yet approved. The five decisions the CEO has to
make are at the end; everything else is the lead developer's recommended
shape, built on the code that exists today.*

## Why this and not a leaderboard

The records board was pulled on 2026-09-22 because every one-number
version was gameable: solve time runs from first swipe to last, so a
depth-3 solve always "beats" a depth-15 one, and whoever dials down owns
the wall. The general rule underneath: **a ranking is gameable whenever
the thing measured can be made easier by a setting the player controls.**
Depth is that setting.

Un-gameable competition has two shapes, and this milestone builds both:

1. **Everyone gets the same cube.** That is what a real competition does
   — every competitor in a round solves the same scramble — and it is what
   the design has called "the sprint" since M1. Nothing to dial.
2. **You compete against yourself.** Your own best, on your own station.

Neither is a wall of names. Showing off is a *place* (a gold station the
whole hall can see) and a *thing on your mat*, not a number on a board.

## The sprint

### The loop a player sees

1. Normal play. A quiet HUD line: `SPRINT IN 1:40`.
2. At 15 seconds a countdown takes over the top of the screen and a toast
   goes to everyone: *"Sprint in 15 — same cube, first pop wins."* Players
   finish whatever they are on.
3. **GO.** Every station in the hall is dealt the *same* scramble at the
   *same* depth, at the same instant. All eight cubes look identical; the
   race is visible across the ring as they diverge.
4. First pop wins. Second and third place. Everyone who finishes inside
   the cap gets a small bonus on top of the normal solve payout.
5. A results card: `1st mcmadmx 6.12s · 2nd … · 3rd …`, your placing and
   bonus. A toast to the hall: *"mcmadmx wins the sprint — 6.12s."*
6. **The winner's station goes gold** — the plinth ring and the floor pool
   — and stays gold until the next sprint resolves. From any seat that is
   the one thing you can see across the hall. Normal play resumes.

### Decisions built into the shape

**Automatic, not opt-in.** Every `Sprint.Every` seconds (proposal: 150)
while at least two players are joined. The intermission → round → results
loop is the structure every Roblox player already knows, and a button is
friction for a 9-16-year-old on a phone. Below two players nothing
happens and nothing is announced.

**One fixed depth for everyone** (`Sprint.Depth`, proposal: 8), regardless
of the dial. Same cube for everybody is the entire point, a fixed number
is legible ("the sprint is always a depth-8 cube"), and 8 is inside a new
player's reach within nine solves. Alternatives considered: the lowest
unlocked depth in the lobby (fair, but one new player pins the whole hall
at 5); the median (fair, invisible, and it moves). Fixed wins on
legibility. The sprint deal ignores the dial ceiling: a brand-new player
gets the depth-8 cube too — the arrows carry them.

**The sprint replaces your current deal at GO.** The countdown exists so
most players are between cubes when it fires. Anyone mid-cube loses that
cube with no penalty: the combo is *not* reset by a sprint starting, and
the sprint solve counts as a normal solve — coins, combo, PERFECTs, depth
unlocks — with the placing bonus on top.

**The server decides everything.** It generates one scramble
(`Moves.generate(Sprint.Depth, rng)`) and deals it to every joined player
with a fresh deal id and a `sprint` flag. Each finish is timed by the
server's own clock in `finish()`, exactly as now; placement is the order
finishes arrive, and a finish that fails `plausible` (faster than a human
could swipe) cannot place. The client sends nothing new. There is no
number a client can claim.

**A cap** (`Sprint.Seconds`, proposal: 45). When it passes, placing closes
and the results card goes out; anyone still solving just continues that
cube as a normal deal — it is still a valid cube.

**The crown is the station, not an object.** The camera is locked and its
frame ceiling across the hall is about 6.5 studs (`Config.Arena.SeenHeight`,
measured by the engine test). The cube floats 2 studs above a 2.6-stud
plinth; a crown above it would sit at 7+ and no other seat would ever see
it. The plinth ring and floor pool at ground level are what the tier tint
already proved reads from any seat — so the winner's station is lit
**gold** through the same machinery (`Arena.setStationCrown(index, on)`,
an override that sits above the tier tint and is removed when the next
sprint resolves or the winner leaves). Static in M3a; a slow client-side
pulse is polish for later. The winner also gets a HUD badge —
`SPRINT CHAMPION` under the coin counter — for the same period.

**Rewards** (`Sprint.Bonus`): winner 40, second 20, third 10, every other
finisher inside the cap 5 — on top of the normal payout, before the combo
and cube multipliers. Forty is about three normal depth-8 solves: worth
racing for, not worth throwing the rest of the session at. Placeholder
numbers, to tune on play.

**Records.** `Leaderboard` keeps sprint wins per name for the server's
life (`snapshot()` exposes them). Not shown on a wall. A HUD line —
`Sprint wins: 3` — is honest, because the sprint is the same cube for
everyone.

### Edge cases, decided

| case | what happens |
|---|---|
| fewer than two players joined | no sprints; the HUD line is hidden |
| players drop below two during the countdown | countdown cancels with a toast; nothing dealt |
| a player joins during a sprint | normal deal; they spectate the race and are in the next one |
| a player leaves mid-sprint | dropped from placing; if they were the sole remaining racer the round closes at the cap as usual |
| a hatch is playing at GO | as today: the client queues the deal behind the hatch animation; the server clock starts at their first swipe, so they are not penalised for the animation |
| every other racer leaves and one finishes | they place first; the reward stands — the race was real when it started |
| the winner leaves while gold | the station reverts to its tier tint on leave, as the tint already does |
| two finishes in the same server frame | first received places first; at `os.clock` resolution a true tie does not occur |

### What gets built

- `src/server/Services/SprintService.luau` — the timer, the countdown, the
  shared deal, placing, rewards, the crown call. ~150 lines. Hooks:
  `SolveService.dealAll(depth)` (new; wraps the existing `deal` with a
  preset scramble) and a `finish` callback so SprintService sees every
  finish with its server time.
- `src/shared/Sprint.luau` — the **pure** placing function: given the
  finishes (index, seconds, plausible) and the cap, return placings and
  bonuses. Pure so a lune test can drive it with every edge case above.
- One new remote, server → client: `Sprint(phase, payload)` with phases
  `countdown`, `go`, `result`, `cancel`. Nothing client → server.
- `Arena.setStationCrown(index, on)` — ~20 lines beside `setStationTier`,
  and the engine test round-trips it (gold on, tier tint restored on off).
- Client: the HUD countdown line and banner, the results card (the solve
  card's twin), the champion badge, the gold-station handling is free
  (server part colour replicates). ~120 lines across `Hud` and
  `init.client`.
- `Config.Sprint` — every number above.
- `tools/test-sprint.luau` — placing, ties, cap, the sole-finisher case.

Not in M3a: the weekly global board (the same gameability question
applies unless it is keyed per depth — decide separately), daily quests,
rebirth, arrow fade. Those are M3b.

## Your times on your mat

Each station's mat already carries a painted number. This adds a second
painted line, on your mat only: `BEST 6.73s · depth 14` — your best at
your current dial depth, the same figure the HUD shows. Server-side text
on the mat's canvas, set on join and whenever `finish()` records a new
best, cleared on leave. About twenty lines; no new remote.

**The honest caveat.** It is readable by *you* (your mat is about eight
studs from your camera) and not by anyone else: at thirty to fifty studs
the station number is already marginal, and a time in the same type would
be a smudge. So this shows off to you, and to the game's sense of place —
a real competition station has your times on it — not to the room.
Showing off *to the room* is the gold station and the tier tint, because
at that distance only colour and shape survive.

If distance matters more than the text, the honest alternative is
**depth bands**: one glowing band on the plinth column per three depths
unlocked (four at depth 15). Monotonic, so it cannot be gamed; reads from
any seat as "how far they have come". Not in the base proposal — it is a
different feature — but it is the version of "showing off" that actually
crosses the hall.

## The five decisions

1. **Automatic sprints** every ~2.5 min with a 15 s countdown, or opt-in?
   *Recommended: automatic.*
2. **Fixed depth 8 for everyone**, ignoring the dial? *Recommended: yes.*
3. **The crown is the winner's station lit gold** (plus a HUD badge), not
   an object above the cube? *Recommended: yes — an object would be
   invisible from every other seat.*
4. **Rewards 40 / 20 / 10 / 5** as placeholders to tune? *Approve the
   shape, not the numbers.*
5. **The mat PB**: build it as owner-readable, and/or the depth bands for
   distance? *Recommended: build the mat PB now (it is small and honest),
   and decide bands after seeing the gold station in play.*
