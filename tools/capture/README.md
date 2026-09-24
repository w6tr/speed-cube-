# Capture triggers

One-line Lua scripts for Studio's command bar during a play test (client
context), pasted and run by the `studio-loop` skill's `typeburst.ps1` so
that the trigger and the screen capture happen in one process. None of
them touch the save: they hide the live cube, play an animation or build
a preview, and put the cube back.

| file | what it shows | capture |
|---|---|---|
| `hatch.lua` | the hatch animation on the player's own station, Epic purple, no purchase | `-LeadMs 700 -Count 26 -IntervalMs 0` |
| `cycle-looks.lua` | every cube look in `Defs/Cubes.luau`, 1.6 s each, on the live pedestal | `-LeadMs 2100 -Count <looks> -IntervalMs 1470` -- one frame per look |
| `crown-station-2.lua` | station 2 painted in the sprint crown colour (the client's copy only) | `-LeadMs 1500 -Count 1` |

The pop needs no script: dial the depth to 3, read the arrow lane, and
send the last key with `burst.ps1 -Keys '{UP}'`.

These files are pasted as ONE line (newlines become spaces), so they may
not contain `--` comments: a comment would swallow the rest of the script.
`typeburst.ps1` drops full-line comments; do not rely on it for trailing ones.
