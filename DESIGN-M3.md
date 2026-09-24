# Speed Cube — M3a: the sprint, and your times on your mat

*Proposed 2026-09-24, revised the same day after a second-developer
design review, and **approved by the CEO the same day -- all six
decisions as recommended.** This is now the design being built.*

## Why this and not a leaderboard

The records board was pulled on 2026-09-22 because every one-number
version was gameable: solve time runs from first swipe to last, so a
depth-3 solve always "beats" a depth-15 one, and whoever dials down owns
the wall. The rule underneath: **a ranking is gameable whenever the thing
measured can be made easier by a setting the player controls.** Depth is
that setting.

Un-gameable competition has two shapes, and this milestone builds both:

1. **Everyone gets the same cube.** What a real competition does — every
   competitor in a round solves the same scramble — and what the design
   has called "the sprint" since M1. Nothing to dial.
2. **You compete against yourself.** Your own best, on your own station.

Neither is a wall of names. Showing off is a *place* — a lit station the
whole hall can see — and a *thing on your mat*.

Honest limit, stated once: this is **dial-proof, not script-proof**. Every
client legitimately holds its deal's solution (that is how the arrows are
drawn), so a script could swipe it. The sprint's plausibility floor
(below) makes such a script have to look human-slow; it cannot make one
impossible. That is true of every solve in the game today and is not
new.

## The sprint

### The loop a player sees

1. Normal play. A quiet HUD line: `SPRINT IN 1:40`.
2. At 15 seconds a countdown takes over the top of the screen and a toast
   goes to everyone: *"Sprint in 15 — same cube, first pop wins."* Players
   finish whatever they are on.
3. **GO.** Every station in the hall is dealt the *same* scramble at the
   *same* depth, at the same instant. All the cubes look identical; the
   race is visible across the ring as they diverge.
4. **The first pop wins — that instant.** The winner's station lights up,
   a toast goes to the hall: *"mcmadmx wins the sprint — 6.12s."* That is
   the whole result: the pop the room just watched is the announcement.
5. Everyone else just finishes their cube as a normal solve, paid as
   normal. Normal play resumes.

### Decisions built into the shape

**Winner only.** No second, no third, no results card, no finisher bonus,
no champion badge, no win counter. Finishing already pays a normal
depth-8 solve — that is the incentive to keep going after someone pops.
A card reading `1st … 2nd … 3rd …` is a small wall of names, and the
badge and counter would be visible only to the one person they cannot
impress. Cutting them removes about half the client work and most of the
edge cases, and moves the announcement from a card 45 seconds later to
the moment of drama.

**First pop wins, by arrival.** Placing is the order the server receives
the finishing swipe — not the solve's seconds. The race the room watches
is the race that counts. A hatch animation or a lag spike at GO costs you
exactly that long, the way an inspection clock would at a real
competition. (The alternative, fastest seconds from first swipe, is
fairer to lag and would sometimes crown the *second* pop the room saw.
The visible race wins.)

**Automatic, not opt-in.** Every `Sprint.Every` seconds (proposal: 150)
while at least two players are joined. The intermission → round → results
loop is the structure every Roblox player already knows, and a button is
friction for a 9-16-year-old on a phone. Below two players nothing
happens and nothing is announced.

**One fixed depth for everyone** (`Sprint.Depth`, proposal: 8), regardless
of the dial. Same cube for everybody is the entire point; a fixed number
is legible ("the sprint is always a depth-8 cube"); 8 is inside a new
player's reach within nine solves. Alternatives considered: the lowest
unlocked depth in the lobby (one new player pins the hall at 5); the
median (fair, invisible, and it moves). The sprint deal ignores the dial
ceiling: a brand-new player gets the depth-8 cube too — the arrows carry
them.

**The dial is locked during a sprint deal.** Today, turning the dial on a
cube with no swipes yet quietly redeals a normal cube; during a sprint
that would silently drop the player out of the race. The server ignores
`SetDepth` while a sprint deal is live.

**The sprint replaces your current deal at GO.** The countdown exists so
most players are between cubes when it fires. Anyone mid-cube loses that
cube with no penalty: the combo is *not* reset, and the sprint solve
counts as a normal solve — coins, combo, PERFECTs, depth unlocks — with
the win bonus on top for one player. A slow player deep in a 15-move cube
will lose it most sprints; that is a deliberate cost of a shared start.

**A win needs a race.** The pop only counts as a win if at least one
*other* player has made a correct swipe on the sprint deal. Otherwise the
solve pays as normal and nothing else happens. This closes the cheapest
way to game it: a second account, or a player who went to make a
sandwich, sitting in the server so sprints fire and one person "wins"
them all. Cost: an honest two-player race where the loser never swipes
pays the winner nothing extra. Accepted.

**The server decides everything.** It generates one scramble
(`Moves.generate(Sprint.Depth, rng)`) and deals it to every joined player
with a fresh deal id and a `sprint` flag. Each finish is timed by the
server's own clock in `finish()`, as every solve is today. A finish that
fails the sprint's plausibility floor (`Sprint.MinHumanPerMove`, proposal
0.15 s per move — the game's PERFECT bar is 0.35, "fast" is 0.6, so no
human is excluded) cannot win. The client sends nothing new. There is no
number a client can claim.

**A cap** (`Sprint.Seconds`, proposal: 45). If nobody has popped by then,
the sprint ends with no winner, a toast says so, and the previous
winner's light clears — so a lit station always means "won the *last*
sprint". Anyone still solving just continues that cube as a normal deal.

**The crown is the station, not an object above the cube.** The camera is
locked. From the far seats the frame's ceiling at the far station is
about 7–7.5 studs (the engine test measures 6.8 at the seating behind it;
`Config.Arena.SeenHeight` is 7) and the cube's top sits at about 6.2 —
so a crown floating over the cube would live in the last half-stud of
frame, marginal at best. The plinth ring and floor pool at ground level
are what the tier tint has already proved reads from any seat, so the
winner's station is lit through the same parts.

**The crown colour must not be a tier colour.** The Legendary tint is
already gold (`Config.Arena.Station.TierTint.Legendary`). At hall
distance only colour survives, so a gold crown would be indistinguishable
from "is holding a Legendary" — and a Legendary holder who won would lose
their tint for the same colour. Proposal: **white** — the winner's station
is the brightest thing on the floor, and no tier, the house, the arrows
(magenta) or the coins (gold) use it. Green is the fallback. Which one is
`aesthetic-eye`'s question, with a capture; that it must differ from every
tier is a design fact.

**The crown's lifecycle**, so it never lies:
- set at the winning pop; if the same player wins again it is set before
  the old one clears, so the station never blinks;
- an override *above* the tier tint: an Equip re-tints the station today,
  and the crown must survive that;
- cleared when the next sprint resolves (win or no-winner cap);
- cleared when the winner leaves, and forgotten by the sprint service, so
  the next player seated at that index is not lit for a win they did not
  earn (the station goes back to the house colour, as any leave does).

**Late joiners are told the phase.** A player who joins during the
countdown or the race gets the current phase and its clock in their
`Sync`, not just future events. During a race they receive a normal deal
and watch; they are in the next one.

**Rewards.** `Sprint.WinBonus`: 40 coins, **flat, after the multipliers**
— the combo and cube multipliers reward the streak and the collection;
the sprint rewards the race, and the same race should pay a new player
and a veteran the same. Forty is about two normal depth-8 solves: worth
racing for, not worth throwing the session at. Placeholder; tune on play.

### Edge cases, decided

| case | what happens |
|---|---|
| fewer than two players joined | no sprints; the HUD line is hidden |
| players drop below two during the countdown | countdown cancels with a toast; nothing dealt |
| a player joins 3 s before GO | they are dealt the sprint cube with everyone else, and their `Sync` carries the countdown so they know why |
| a player joins during the race | normal deal; they spectate; next sprint |
| a player leaves mid-race | nothing to do — they simply cannot pop |
| only one player ever swipes the sprint cube | their pop pays as a normal solve; no win, no light (a win needs a race) |
| a hatch is playing at GO | the deal lands under the hidden cube and the prompt appears when the box goes, as today; the hatch's ~2.5 s is time lost, like an inspection clock |
| a 2 s lag spike at GO | the same: lost time. Bunched swipes after a spike hit the existing spam guard, as they would on any cube |
| nobody pops inside the cap | no winner; toast; the previous light clears |
| the winner wins again | set before clear; no blink |
| the winner leaves while lit | station to house colour; the sprint service forgets the crown |
| the dial is pressed during the sprint deal | ignored |
| eight players at GO | eight shuffle animations at once on every client — **unverified on a phone; test on a real cheap Android before tuning** |

### What gets built

- `src/server/Services/SprintService.luau` — the timer, the countdown, the
  shared deal, the first-pop check with the second-runner rule, the
  bonus, the crown. ~120 lines. Hooks into `SolveService`: a
  `dealAll(depth)` that wraps the existing `deal` with a preset scramble
  (today `deal` generates internally; `Moves.generate` already returns
  both halves), a `finish` callback carrying the server time and the
  plausibility result, and the dial guard.
- One new remote, server → client: `Sprint(phase, payload)` with phases
  `countdown`, `go`, `won`, `nobody`, `cancel`; plus a `sprint` field in
  `SyncState` for late joiners. Nothing client → server.
- `Arena.setStationCrown(index, on)` — a per-station flag that
  `setStationTier` respects, so an Equip re-tint cannot erase the crown;
  ~20 lines beside the tint, and the engine test round-trips it (crown
  on, tint change ignored, crown off restores the tier).
- Client: the HUD countdown line and banner, the GO flash, the win toast.
  The lit station is free — a server part colour replicates. ~70 lines.
- `Config.Sprint` — every number above.
- `tools/test-sprint.luau` — the second-runner rule, the plausibility
  floor, the cap, the repeat-winner and leave cases, as a pure function
  over a list of (index, swipes, popped-at, plausible).

Not in M3a: the weekly global board (the same gameability question
applies unless it is keyed per depth — decide separately), daily quests,
rebirth, arrow fade. Those are M3b.

## Your times on your mat

Each station's mat already carries a painted number. This adds a second
painted line, on your mat only: `BEST 6.73s · depth 14` — your best at
your current dial depth, the same figure the HUD shows. Server-side text
on the mat's canvas, set on join and whenever `finish()` records a new
best, cleared on leave. About twenty lines; no new remote; no new render
pass (it is a label on the gui the mat already has).

**The honest caveat.** It is readable by *you* (your mat is about eight
studs from your camera) and not by anyone else: at thirty to fifty studs
the station number is already marginal. So this shows off to you, and to
the game's sense of place — a real competition station has your times on
it — not to the room. Showing off *to the room* is the lit station and
the tier tint, because at that distance only colour and shape survive.
Not gameable: the depth is printed next to the time, so dialling to 3
shows "depth 3" and fools nobody.

If distance matters more than the text, the honest alternative is
**depth bands**: one glowing band on the plinth column per three depths
unlocked (four at depth 15). Monotonic, so it cannot be gamed; reads from
any seat as "how far they have come". Not in this proposal — a different
feature — and worth deciding after the lit station has been seen in
play.

## The six decisions

1. **Automatic sprints** every ~2.5 min with a 15 s countdown, or opt-in?
   *Recommended: automatic.*
2. **Fixed depth 8 for everyone**, ignoring the dial? *Recommended: yes.*
3. **Winner only, first pop by arrival, the station lit in a non-tier
   colour** (white proposed; aesthetic-eye picks between white and green
   from a capture)? *Recommended: yes on all three — no placings, no
   card, no badge.*
4. **40 coins flat, after multipliers**, as a placeholder to tune?
   *Approve the shape, not the number.*
5. **A win needs a second runner** (one correct swipe by someone else),
   accepting that a race where the loser never swipes pays nothing extra?
   *Recommended: yes — it is the only thing standing between "won a
   sprint" and "sat next to an idle account".*
6. **The mat PB**, knowing only you can read it? *Recommended: yes — small,
   honest, and it is what a competition station looks like. Depth bands
   later, if the room needs more.*
