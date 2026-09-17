# Reviewer checklist — Speed Cube

Read every time. Short on purpose.

## Roblox golden rules (from the roblox-dev skill)

1. **The server owns the truth.** Coins, solves, best times, the combo,
   the deal and its step: computed and stored on the server. The client
   displays and asks. Any value that arrives from a client is untrusted:
   the client sends a DIRECTION, the server decides what it meant.
2. **Client and server talk only through RemoteEvents** in
   `ReplicatedStorage/Remotes`, created server-side at boot (`Remotes.luau`).
   The client `WaitForChild`s for them — with a timeout and a warning on nil.
3. **Shared code lives in ModuleScripts** under `ReplicatedStorage/Shared`;
   server-only logic under `ServerScriptService/Server`.
4. **`task` library only** — `task.wait`, `task.spawn`, `task.delay`. Never
   bare `wait()` / `spawn()`.
5. **Rojo owns the code.** Any script edited inside Studio gets overwritten.
6. **Saves must survive crashes**: save on `PlayerRemoving`, flush in
   `game:BindToClose`, never save defaults over a failed load, use
   `UpdateAsync` and honour a newer `lastSeen` from another server.

## Cube-game sanity (this project's rules)

- **The deal is the contract.** `solution[step + 1]` is the only move the
  server accepts next. Anything that advances `step` without comparing the
  direction to that move's `direction` is a bug.
- **Scramble = solution reversed and inverted.** `Moves.generate` is the
  only place a deal is made; `tools/test-moves.luau` proves it. A change to
  `Moves.luau` must keep that test green.
- **Every deal has an id.** The client starts a deal ONLY when the id
  changes or the step drifts; `dealToken` in `init.client` cancels a
  pending start when a newer deal arrives. A reset that ignores the token
  can wipe a cube mid-shuffle.
- **Busy means busy.** `CubeView.isBusy()` covers the queue, the animation
  worker, the shuffle and the pop. A new deal waits for it. Anything that
  moves cubies outside the worker while it runs is a bug.
- **Snap after every turn.** `snap()` rounds positions to the pitch grid
  and axes to unit vectors. A turn that skips the snap will drift after
  enough solves.
- **Wrong swipes lock, briefly.** `WrongLockSeconds` on BOTH sides. The
  server's lock is the one that matters (guessing four directions must be
  slower than playing); the client's is for feel.
- **The pop pause is longer than the animations.** `Timing.PopSeconds`
  (server) must exceed `Cube.TurnSeconds + Cube.PopSeconds` (client) or the
  next deal arrives mid-pop and waits on `isBusy` — fine — but shorter than
  a second or the loop feels dead.
- **Best is per depth.** `data.best[tostring(depth)]`. A "best" compared
  across depths is meaningless (a 3-move solve always beats a 15).
- **The dial changes now only at step 0.** Otherwise it applies to the
  next deal. A redeal mid-solve is a bug.
- **Leaderstats are display.** They are written from the save in
  `updateLeaderstats`; nothing reads them back.
- **First-frame state goes through the handshake.** Everything the first
  frame needs is in `Sync`, answered from `answerSync` in `init.server` on
  `RequestSync`.
- **Per-player state is released on leave**, in `init.server`'s
  `onPlayerRemoving`: `SolveService.leave` first (frees the pedestal) and
  `SaveService.release` LAST.
- **Config owns numbers.** A literal price, multiplier, timer or dimension in
  a service or view is a smell; it belongs in `Config.luau` with a comment.
- **Never "Rubik's".** Trademark. Search the diff for it.

## Research cross-check pointers (RESEARCH-CUBE.md)

- §1 — the swipe (mobile cube apps): direction-only, commit on distance.
- §2 — input buffering (csTimer): queued turns, step advances on swipe.
- §3 — combo, PERFECT and the pop (rhythm games, endless runners).
- §4 — depth as the difficulty dial (Drift & Flip's assist rule).
- §5 — the gacha plan (pet sims): M1 must not need changes for boxes.
- §6 — Roblox facts: SurfaceGui stickers, +Z front, right-hand rule, snap.

## The user's taste

- They are a beginner "vibe coder": they test by playing, not by reading
  code. Give them one number to change and a "Try it" step.
- They want to build on proven systems, not re-derive; cite the source.
- They asked for "super simple but fun": every addition must earn its
  place in a 30-second phone session. Prefer cutting to adding.
- Gacha is a MAJOR element (M2); the M1 design keeps every cube-specific
  thing (look, sound, multiplier) as data a cube id could carry.
