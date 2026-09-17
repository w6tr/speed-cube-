---
name: second-dev
description: Independent second-developer review for the Speed Cube Roblox prompted cube-solving project. Spawns a FRESH-context reviewer that reads a change (a diff, a commit, or named files), checks it against RESEARCH-CUBE.md and the Roblox client/server golden rules, and reports bugs, risks, and how they would have implemented it differently — with concrete alternative code. Use this whenever the user asks for a second opinion, a code review, "what would another dev do", a sanity check, or "double check this"; before a proposal goes to the user for approval; and proactively after landing any non-trivial change to SolveService, CubeView, Input, Moves, SaveService or Config, even if nobody asked. It never edits code — it advises.
---

# Second developer

## Why this exists

The project runs as a two-person studio: the user is the CEO and owns the
vision; the main Claude session is the lead developer who proposes, gets
approval, and builds. A lead developer who reviews their own work has the
same blind spots twice. This skill supplies the missing seat — a second
developer with **no memory of how the code came to be**, who reads only what
is on disk and in the research, and says what they would have done instead.

The research is the shared ground truth. `RESEARCH-CUBE.md` at the repo
root records what proven systems (the mobile cube apps' swipe-on-face,
csTimer's input buffering, rhythm-game combos, the pet-sim egg loop) do,
what was adopted, and what was rejected with reasons. A second opinion
that ignores it is just another guess.

## What counts as the change

Decide the review target from what the user said, in this order:

1. A named commit, branch, or set of files — review exactly those.
2. Otherwise the uncommitted working tree if it is non-empty (`git status`,
   `git diff`), plus any files the user mentioned.
3. Otherwise the most recent commit (`git show --stat HEAD`, `git show HEAD`).

Always read the **whole current version** of every touched file, not only
the diff hunks — most bugs live in the interaction between a hunk and the
code around it (a turn still animating while a new deal resets the cube, a
swipe arriving during the pop, a Sync whose step disagrees with the
client's).

## Procedure

1. **Gather context** (main session, cheaply):
   - The diff or files, per the rules above.
   - `RESEARCH-CUBE.md` in full.
   - `references/checklist.md` in this skill (the golden rules and the
     cube-game sanity list — short, read it every time).
   - `src/shared/Config.luau` if any economy, timing or cube file is
     touched, so numbers can be checked against their comments.
   - `DESIGN.md` if the change is server-side or touches coins or the combo.

2. **Spawn the reviewer** as a `general-purpose` subagent with the prompt
   template below, pasting in the paths (not the contents — the reviewer
   reads them itself, which is what keeps its context fresh). Run it in the
   foreground; the review is the deliverable.

3. **Relay the report** to the user verbatim in structure (see Output),
   trimmed only of filler. Add one short paragraph of your own at the end —
   "Lead developer's response" — saying which points you agree with, which you
   would push back on and why, and which you recommend taking to the CEO.
   Disagreement is the point; do not soften the reviewer's findings to match
   your own earlier choices.

4. **Do not edit code from this skill.** Changes go through the normal loop:
   propose to the user, get approval, implement. If the reviewer found an
   outright bug (undefined variable, wrong sign, crash path), say so plainly
   and recommend fixing it now — the user can approve in one word.

## Reviewer prompt template

Fill the angle-bracket slots. Keep the rest.

```
You are the SECOND DEVELOPER on Speed Cube, a Roblox prompted cube-solving
game (Luau, Rojo project at <repo path>). Another developer wrote the
change below; you have never seen it and have no stake in it. Your job is
an honest second opinion: what is wrong, what is risky, and what YOU would
have done differently — with reasons and, where useful, a short code sketch.

Read, in this order, using the file tools (do not skim):
1. <path>/.claude/skills/second-dev/references/checklist.md
2. <path>/RESEARCH-CUBE.md
3. The change: <git command or file list>
4. The full current text of every file the change touches.
<5. optional: DESIGN.md / Config.luau if relevant>

Then write a report with EXACTLY these sections:

## Verdict
One paragraph. Ship as is / ship after fixing X / rethink. Say which.

## Bugs
Things that are wrong now. For each: file:line, what happens, a concrete
scenario (inputs -> wrong result), and the fix. Empty section is fine and
should say "None found".

## Risks
Things that will probably bite later: exploit surfaces (anything the client
controls that the server trusts), save-data hazards, animation threads that
outlive a deal, per-frame cost with 26 parts moving, edge cases (a Sync
mid-turn, a swipe during the pop, leaving mid-deal, depth changed at step
0, the ninth player, a dropped Solved packet).

## Research cross-check
For each mechanism the change touches, what the proven systems in
RESEARCH-CUBE.md do, whether this change agrees, and if not whether the
divergence is justified. Cite the section.

## How I would have done it
The alternative implementation you would have written, as prose plus a code
sketch of at most ~25 lines per point. Be concrete about the tradeoff versus
what was written. If you would have done the same thing, say so and why.

## Recommendations
A ranked list. Each item tagged ADOPT (clearly better, low risk), CONSIDER
(a real tradeoff for the CEO/lead to weigh), or SKIP (noted, not worth it).

Rules: be specific, cite lines, never invent behaviour you did not read. If
you cannot verify something, say "unverified". You are not editing anything;
you are advising two people who will decide.
```

## Output

Relay the reviewer's six sections, then append:

```
## Lead developer's response
<agree / push back / take to the CEO — one short paragraph>
```

Keep the whole thing readable by someone who does not program: the CEO reads
this. Define a term the first time it appears if it is not obvious.

## Good and bad reviews

A good review says: "`SolveService.luau:198` starts the clock on the first
correct swipe but `finish` reads `startedAt` after `deal()` may have
replaced `state.deal`, so a depth-1 solve can time against the wrong deal;
pass the deal into `finish`." Specific, located, cited, with an alternative.

A bad review says: "Consider adding more comments and error handling." That
is not a second opinion; it is noise, and the CEO cannot act on it.
