# Speed Cube — art critic log

Every round of the `art-critic` gate, newest at the bottom. The scale is
the rubric's: 8–10 ship, 5–7 go again, 0–4 change the approach. Captures
live in the session scratchpad; the frames that matter are described in
each entry.

## The CUBES screen — attempt 1 — 2026-09-24 — score 4

**Changed since last round:** first attempt
**Reason it is not higher:** tidy and working, but the thing being sold is never shown — two box cards with a blank where the box should be and ten "?" glyphs where the cubes should be; a 5 requires nothing that reads as placeholder.
**Keep:** the affordability state (live blue BUY vs dead grey BUY); the tier colour hierarchy; the odds printed on the box; the card type hierarchy; the flavour copy's voice; one gold for coins across the game.
**Defects:** no product art; Basic and Pro cards identical; no backdrop dim (the hall, the timer and the move prompt stay lit behind the shop); the BEST line bleeds through the panel; tier carried by a hairline border; ~9px text; third row chopped with no padding or fade and the equipped cube (Neon) hidden in it, no EQUIPPED state; stock scrollbar, plain CLOSE, cryptic "x2"; four accent colours with none in charge; the panel is a generic dark-mode settings panel, not from this hall; nothing glows.
**Ranked list:**
1. +2 put the products on the screen: a rendered box in each box card, a rendered cube on every cube card (owned in colour, locked as a dark silhouette with a padlock).
2. +1 make Pro visibly premium: bigger card, gold-and-purple glow, LEGENDARY 5% as a badge; Basic plain.
3. +1 take the stage: dark blurred backdrop, hide the timer and prompt while open, fully opaque panel.
4. +0.5 tier as a fill (tier-coloured tile behind the art, tier label as a coloured pill), flavour text off the card face.
5. +0.5 finish the edges: bottom padding/fade on the grid, styled or no scrollbar, EQUIPPED ribbon pinned into view, duplicate badge on the art, header bar with wordmark and coin pill, CLOSE as an X, panel edged in the hall's blue neon.
**Next:** apply 1–5 as block 3 (cards with live ViewportFrame previews) — attempt 2.

## The HUD and the toasts — attempt 1 — 2026-09-24 — score 5

**Changed since last round:** first attempt
**Reason it is not higher:** coherent and nothing broken, but no identity — the panels are the same dark translucent rounded rectangles as Roblox's own player list beside them, and the timer, the one object a speedcubing final is built around, is a grey box with white digits.
**Keep:** one accent colour (gold) used consistently; the result card's hierarchy (time, coins, tags) and its thin gold stroke; corner discipline (shared left and right edges, centre left to the cube); the readable prompt under the cube; the coin + equipped-cube pairing.
**Defects:** no esports/broadcast identity (no scorebug, no Stackmat-style digits, no shared panel shape — Rivals does this); the arrow lane is nearly invisible (~20px white current move, ~10px grey next moves, no backing) and gone on a phone; placeholder strings ("(max 15)", "A or Left arrow" meaningless on a phone, "no best yet" lowercase vs "BEST" caps); the pop frame contradicts itself (NEW BEST beside "no best yet at depth 3"); the result card sits on top of the cube it should show off; NEW BEST whispered in 14px grey; confetti is a uniform sparkle overlay with no origin at the cube; depth dial reads as a settings row ("DEPTH" means nothing to a kid, "-" reads disabled, "+" is the only blue in the HUD, nothing says higher pays more); no coin icon, equipped cube name not in its tier colour; CUBES is a flat rectangle with no icon, no pressable edge, no affordable-badge; the BEST line is 13px on a translucent bar crossing the avatar's hair; the combo readout is not visible in any still (behind Roblox's player list or hidden at 0).
**Ranked list:**
1. +1 an esports identity starting with the timer: a scorebug top-centre with big seven-segment digits and a state-coloured edge (grey idle, green running, gold on the pop), then the same panel language on coins, dial and card.
2. +1 make the arrow lane readable: a backing pill, current move large, next two stepping down, all in the cube's arrow magenta; fold the prompt text into it.
3. +0.5 fix the reward moment: card off the cube, NEW BEST as a loud coloured badge, confetti as a burst from the cube in sticker colours, kill the "no best yet" line during the pop.
4. +0.5 remove every debug string: "(max 15)" becomes a segmented bar / "14 / 15" under a word a kid gets, "-" styled like "+", "+" joins the palette, glyph-first prompt matching the input device, one casing for BEST.
5. +0.5 value in the corners: coin icon, cube name in its tier colour, CUBES with a cube icon, a darker bottom edge and a pulse when a box is affordable, the combo somewhere the player list cannot cover.
**Next:** apply 1–5 as block 4 (the HUD kit) — attempt 2.

## The pop — attempt 1 — 2026-09-24 — score 5

**Changed since last round:** first attempt
**Reason it is not higher:** it tells the player what happened but does not make them feel it — the card is a bordered rectangle that hides the cube it is celebrating, and the confetti is dim dust, so in a still (and at 150px) nothing visibly pops.
**Keep:** the information order (time, coins, badges) and its type hierarchy; gold as the one reward colour across card, counter and CUBES; the moment anchored on the cube; the stage already lit (magenta glow, neon rings); the panel is clean (rounded, no overflow).
**Defects:** the card covers the cube's top face and top rows at the moment it swells; "a rectangle with text in it" (1px border, flat fill, no glow); confetti is tiny, one size, olive-yellow, not glowing, spread evenly with no origin, gone at 150px; NEW BEST is a small grey caps word at the same weight as FAST and x1.62; the frame contradicts itself ("no best yet at depth 3" above a NEW BEST card); badges are one grey line, not pills; "+21 coins" has no coin, nothing flies to the counter; the hall does not react (ring stays blue, no flash, counter does not bump); two clocks (HUD timer and card both say 1.38); the multiplier's source (COMBO) is half-buried under the player list. Pet Simulator 99 is the reference: chunky outlined numerals that overshoot, big bright additive particles bursting from the thing, a tilted rarity stamp, coins that fly.
**Ranked list:**
1. +1 to +1.5 kill the box: a big chunky "+21" with a coin icon, thick dark outline and soft glow, ABOVE the cube; "1.38s" beneath at half size; badges under that.
2. +1 confetti as a burst with a flash: text-gold, glowing/additive, 2–3× bigger with size variety, fired outward from the cube's centre; a white-gold flash or expanding ring on the mat at the solve instant.
3. +0.5 NEW BEST gets its own event: a stamp larger than the time, tilted, in a colour nothing else uses, second burst; FAST and the multiplier as small coloured pills.
4. +0.5 remove the contradiction: hide or update the "no best yet" line for the length of the pop.
5. +0.5 make the station react: ring and floor flash to gold and fade back; the coin counter bumps as coins land.
**Next:** apply 1–5 as block 5 (pop VFX) — attempt 2.

## The cube and the arrow prompts — attempt 1 — 2026-09-24 — score 6

**Changed since last round:** first attempt
**Reason it is not higher:** the arrows, the one thing the player has to read, are the smallest, dimmest and least centred thing on a cube whose stickers outshout them.
**Keep:** the cube owns the frame (brightest thing in it, the hall two steps down); the Neon stickers read Epic (rounded, rim, soft bloom); five of six colours stay distinct under glow; the black outline on the arrows (the contrast guarantee when arrow colours vary per skin — non-negotiable); three arrows across the whole row; one accent used twice (arrows and pool light in the same magenta).
**Defects:** arrows about a third of a sticker wide, flat and unlit on glowing stickers, two-tone bevel reads as clip-art (Funky Friday does glyphs right: huge, thick-outlined, saturated, flaring); arrows registered off-centre in the bottom-left of every sticker; the avatar's hair in frame at the cube's top-right, even at 150px (a full point); a white sliver at the cube's foot bottom-right reads as clipping; no headroom under the BEST pill; yellow and orange nearly the same under glow, red and arrow-magenta the same family; the cube sits askew on the mat, on top of the timer pads; two arrow languages (tiny white prompt triangle vs fat magenta cube arrow; the queue above the cube barely there); no juice on the instruction in a still.
**Ranked list:**
1. +1 make the arrows the loudest thing on the cube: centred, ~two-thirds of the sticker's width, thick black outline, fill at least as bright as the sticker, soft dark halo.
2. +1 get the hair out of the frame: the avatar must never enter the locked camera's view.
3. +0.5 mark the row that moves: brighten the prompted row or dim the other stickers on that face.
4. +0.5 finish the edges: remove the white sliver, square the cube on its mat with the timer pad in front, clear air above it, warmer orange, and write the rule that arrow colour never shares a hue with a sticker and always keeps the outline.
5. +0.5 one arrow language: the prompt under the cube gets the same chunky magenta glyph on a small dark pill; the queue above grows legible or goes.
**Next:** items 1, 3, 4 belong to block 1 (cube skins + tier VFX); item 2 is block 7 (the avatar); item 5 is block 4 (HUD kit) — attempt 2 after those.

## The thirteen cube looks as a set — attempt 1 — 2026-09-24 — score 5

**Changed since last round:** first attempt
**Reason it is not higher:** the four Rares are not readable as a step above the Commons without their labels, which is the one job this set has — Classic, the free cube, out-ranks three of the four cubes a player pays for.
**Keep:** one product line (same proportions, stickers, gaps; no clipping or seams); the glow tier is real (Neon, Plasma read as a clear step up, and Neon in play is the best shot); Classic as the anchor; one material rule per tier as the shape of the system; Jelly as the one designed Rare; Legendary the brightest thing in the hall.
**Defects:** Rare reads as Common (Sunset is Ember without borders, Ocean a blue Mint, Pastel a beige block — stickerless is a speedcuber's distinction, not a player's); Frost's white body breaks the Common rule and collapses into Pastel; Void reads as Rare (a purple cube beside Jelly, stickers not visibly glowing); Prism is a lightbulb, not a prism (top face blown out to white, right face a cyan haze — reads as an exposure mistake); the names promise looks the cubes don't deliver (Sunset flat tan, Ocean flat blue, Jelly opaque, Void purple, Prism white); no material variety (all flat matte, no gloss/metal/glass/gradient/pattern/particle, no sheen on the black plastic); pale palette on six of thirteen (reads unpainted on Roblox); no rim light on any cube (lit flat like a product shot, not staged like a final); Plasma is the arrow magenta (check the arrows on it); at 150px stickered vs stickerless vanishes — the ladder a phone sees is coloured, coloured, glowing, white blob. Pet Sim 99 codes rarity by material and effect (gold, animated rainbow, sparkle, size), never by colour alone.
**Ranked list:**
1. +1.5 make the Rares deliver their names: Sunset an orange-to-pink gradient, Ocean deep slightly translucent blue lighter on top, Jelly glossy see-through candy, Pastel a multi-hue pastel set; all four glossy so they catch light the Commons don't.
2. +1 make Prism a prism: pull the bloom until all three faces keep their stickers, then a spectral hue per face or an iridescent finish; still the brightest thing, also the only thing never seen before.
3. +0.5 make Void an Epic: black stickers on a black body with violet light leaking from the seams and a faint halo.
4. +0.5 saturate or replace the pale Commons; Frost gets the black body; sheen on the black plastic.
5. +0.5 rim-light every cube (the plinth's magenta from below or a cool light from behind); check Plasma against the magenta arrows.
**Next:** this IS block 1 — apply 1–5 as attempt 2.

## The stations (plinth, mat, pool, tint, crown) — attempt 1 — 2026-09-24 — score 5

**Changed since last round:** first attempt
**Reason it is not higher:** the station is a drum, a board and two black ovals with a light under it — only the trim ring has been designed, and the empty station, which is what seven of the eight seats show, gives the eye nothing.
**Keep:** the trim ring as underglow (the esports-desk instinct, best in Epic); rarity as a tint of the furniture rather than a badge; the stack of ingredients (mat, pads, number, best line); the palette (navy, blue neon, one accent per station).
**Defects:** parts, not furniture — the board is wider than the drum with corners hanging in the air, the cube fills the mat edge to edge, "a thing balanced on a thing"; the house light does not carry (a sliver from the seat, a hint on the far stations — seven stations read as dark drums); the pool is a flat disc with no falloff (the white crown pool reads as a grey puddle); the timer pads are two black holes with no timer unit between them; the number is teal on teal and sideways to the camera; the mat is a muddy thick teal slab; Epic trim is hot magenta, the arrows' hue (the pool is a truer violet); the plinth shifts colour between shots; the best-time line reads as HUD, not mat. **Crown:** white reads as glare up close and as "that light is on" from across the hall — visible but not meaningful; green would be worse (the mat colour, and "go"). Keep white, give it a vertical shape. Risk: Legendary gold beside crown white untested. References: Pet Sim 99 (ground ring with falloff plus a beam), Sol's RNG (a column of light readable across the map), Dress to Impress (a spotlight cone on the winner while the rest dim).
**Ranked list:**
1. +1 light every station and make the pool a pool: house-blue rings bright enough to read across the hall; a soft-edged additive gradient pool, brightest at the drum's base; the crown pool bright white with the same falloff.
2. +1 one piece of furniture: a top wide enough for the mat with a margin, a mat wide enough for the cube with a margin, a rim and a foot on the drum, a thin bound-edge mat, a timer unit at the mat's front edge with a readout strip lit in the tint.
3. +0.5 shape the crown: a visible cone of light from above through the haze; consider the number or trim flipping to gold, checked against Legendary first.
4. +0.5 numbers that read: high contrast, and a second large number on the drum's side facing the centre.
5. +0.5 mat to black rubber with a coloured binding (or house blue); Epic trim to the pool's violet so magenta stays the arrows'.
**Next:** items 1, 2, 4, 5 are a new block ("the station as furniture") before block 6; item 3 joins block 5 (sprint GO VFX) — attempt 2 after.

## The hall and the lighting rig — attempt 1 — 2026-09-24 — score 5

**Changed since last round:** first attempt
**Reason it is not higher:** coherent, and the cube sits in it correctly, but the lighting rig only makes the room dark — no rim light, no pool of light under any station, no haze, so every surface is the same flat navy and it reads as a dark set rather than a lit final.
**Keep:** the palette (navy dominant, cyan accent, one magenta for "mine"); the LED rail with its bloom (the one strong line, survives the thumbnail); the hall staying behind the cube; the ring reading as a ring; the floor ring markings at their quiet value; the hoarding copy; no void at the top.
**Defects:** lighting that illuminates without selling — no rim light on any pedestal, sixteen lamps leave no visible pool or highlight, no haze so near and far read at one distance, floor/barrier/wall/pedestals within a hair of the same value; the frame is unbalanced (the floor's centre and the opposite station sit right of the cube; the left third is wall, the right third empty floor; the station straight across is under the timer); dead space (the empty disc and the front rows of empty stands are a third of the frame; the crowd is invisible); hoardings are white text on navy with no panel, colour or mark; visible parts tells — the LED rail bends at polygon corners, worst near-left; hard straight-segment edges on the floor discs; mats overhang their cylinders at all seven visible stations; off-palette grass-green mats; the red-orange thing over the cube's far corner; at 150px the hall is navy and one faint arc, no second shape; no motion visible in a still. References: Dress To Impress (spotlights that cast pools, visible audience, beams in haze, a big screen), Blade Ball (a lit ring where the floor separates from the walls at any size), Rivals (how hard Roblox lighting can be pushed and still read on a phone).
**Ranked list:**
1. +1.5 put the lamps to work: a coloured pool under every station (cyan for seven, magenta for mine), a rim of light on every pedestal edge, haze in the air.
2. +1 balance the frame: the floor's centre and the station straight across directly behind the cube, the ring sweeping out of both sides equally; kill the empty right third.
3. +1 a hero piece and a crowd on the far side: a big screen or lit arch above the far barrier behind the cube, and the front rows lit with a crowd you can see (silhouettes with phone lights).
4. +0.5 make the hoardings hoardings: lit coloured panels with a mark, alternating fills, the far one biggest.
5. +0.5 finish the geometry: smooth the LED rail's polygon corners, soften the floor discs' edges, remove the red-orange object over the cube.
**Next:** a new block ("the hall lit") — items 1, 4, 5 first; 2 and 3 need a CEO call (the seat orientation is layout, the screen and crowd are new builds) — attempt 2 after.

## The hatch — attempt 1 — 2026-09-24 — score 4

**Changed since last round:** first attempt
**Reason it is not higher:** for the first 1.25 seconds, the part that is supposed to build the wanting, the subject is an unlit near-black crate that the eye skips entirely, so the reveal carries the whole piece alone.
**Keep:** the reveal's hierarchy (the new cube the brightest thing at the pop); the tier colour thread (Epic purple on the "?" and in the burst); the star sprite (crisp six-point, pink-white core, stays off the cube's faces); the landing spot on the glowing pedestal; the beat structure (drop, rattle, pop, card).
**Defects:** the box is the darkest object in a dark hall (near-black wood, unlit, no glow — Pet Sim 99's egg is the brightest, most saturated thing on screen); the "gold lid" sits on the LEFT side as a flat mustard plank, not on top, not metallic; the "?" marks are flat decals tilted 45°, not glowing — the entire rarity read rests on them; the drop uncovers the seated default avatar (orange bun, denim jacket) and the mat's upside-down text; the avatar leaks mid-shake (hair above the box, sleeve at its edge) and in the burst (hair above the new cube); the hatch never owns the screen (timer, moves, BEST strip, hint arrows and "A or Left arrow" stay up; the move arrows are on the new cube while stars still fly); no lighting change; the shake still is inert (no seam light, cracks, dust); the burst is a scatter (one sprite, one colour, even to the corners, over the HUD, no flash, ring or falloff); wrong game (a wooden "?" crate is the Fortnite/Mario trope in an esports hall); at 150px the shake frame is a black rectangle with a yellow stripe; the name-card toast not captured.
**Ranked list:**
1. +2 make the box the brightest thing in the frame and a prize: body out of black (lacquer, white, or the tier colour), gold lid on TOP and metallic, glowing "?", a tier-coloured glow that grows through the rattle with light leaking from the seam.
2. +1 nothing of the seated avatar visible in any beat.
3. +1 the hatch takes the stage: hall dims, tier-coloured spotlight on the station, play HUD and move arrows gone until the toast clears.
4. +1 make the burst a burst: white flash at the pop, tier-coloured ring across the floor, particles born at the cube flying outward with size falloff, none over the HUD.
5. +0.5 fit the direction: a hard competition cube case in the tier colour with a sealed tag (also the store icon's signature shape).
**Next:** this IS block 2 — apply 1–5 as attempt 2 (item 2 shared with block 7, the avatar).

## The cube and the arrow prompts — attempt 2 — 2026-09-24 — score 7 (was 6)

**Changed since last round:** arrows centred, two-thirds of a sticker, brighter, black outline + dark halo; no characters at all (hair gone); the prompted row lit a notch up and the rest down; the mat widened with the pads in front and the best text behind (sliver gone); a rim light behind the cube. Not done: the orange, the BEST bar, the prompt/queue language.
**Reason it is not higher:** the three magenta arrows still lose the brightness fight to the white-and-yellow top face a centimetre away, so the instruction is the second thing read on the cube, not the first.
**Keep:** the cube (black plastic, rounded neon stickers, brightest object in the hall); arrows centred and outlined, magenta on cyan; the hair gone; the wider mat and the pads out front ("the most esports-final the station has looked"); the stage glow and rim light giving the cube depth.
**Defects:** arrows more saturated but not lighter than the white/yellow stickers; on screen ~40–45% of a sticker, the outline a hairline, the halo invisible; the row marking reads as a colour change (cyan) not a spotlight; magenta means two things (the station glow is the same hue and many times the area — at 150px only the glow is left); the caption is a label not an instruction (white text, tiny grey arrow, two arrow languages); the queue above is three tiny grey glyphs; no air above the cube (the BEST bar sits on its head); a letter of the mat text peeks out right of the cube; no juice in a still.
**Ranked list:**
1. +0.5–1 the arrow wins the cube: base spanning the sticker's inner face, the arrow carrying the glow (magenta bloom), a white-hot core with a magenta edge, a thicker outline.
2. +0.5 one arrow language: the caption becomes the same fat magenta glyph on a dark pill with the key hint small beside it; the queue legible or gone.
3. +0.5 air above, nothing peeking: move the BEST bar off the cube; the mat text fully hidden or fully visible.
4. +0.25–0.5 give magenta one meaning: shift the station glow to another hue.
5. +0.25–0.5 mark the layer with light (an edge glow), not a hue shift; catch a pulse.
**Next:** apply 1–5 — attempt 3.

## The thirteen cube looks as a set — attempt 2 — 2026-09-24 — score 6 (was 5)

**Changed since last round:** Frost black-bodied and saturated; Mint greener; Rares glass, shaded by height, Pastel a six-hue set, Ocean lighter on top, Sunset a gold–orange–pink gradient, Jelly 25% see-through; Void a glowing violet body with black stickers and a lamp; Plasma violet/cyan (no arrow magenta); Prism a pale glass body with spectral stickers at two-thirds Epic brightness, a lamp, and a hue walk; a rim light.
**Reason it is not higher:** the Legendary now ranks visually below all three Epics and is a look-alike of Pastel, a Rare.
**Keep:** Frost (the best Common now); Sunset delivering its name; Plasma fixed and distinct; Void's inversion (the only cube with a silhouette-level identity); Neon as the brightness reference; the Prism's stickers readable; the black-bodied Commons.
**Defects:** Prism reads as a Rare (pale lavender, pastel stickers, two-thirds of an Epic is a Rare; siblings with Pastel); Pastel is a blank white block with no seams; Jelly not glossy or see-through from the play camera, its palette muddier than last round; no specular visible on any Rare from the locked camera; the rim light not visible at sheet scale; look-alike pairs Frost/Ocean and Ember/Sunset; Void reads electric blue in a blue hall, seams too wide, not "void"; Neon is Classic with a lamp; the Legendary has less juice than the Epics and no particles. Pet Sim 99's ladder is additive — every tier adds an effect, nothing subtracts.
**Ranked list:**
1. +1 Prism the brightest object in the hall and not a pastel: a real rainbow across the faces, 1.2× Epic glow, a halo, sparkle particles, a dark chrome/holographic body.
2. +0.5 rebuild Pastel: six nameable candy hues with visible seams.
3. +0.5 visible gloss on the Rares (a hard highlight painted into the sticker) and a vivid, visibly translucent Jelly.
4. +0.25 Void from blue to violet, seams a third as wide, body near-black, soft halo.
5. +0.25 break the look-alike pairs: Frost paler white-ice, Ocean owns deep blue; Ember flat brick, Sunset owns the gradient.
**Next:** apply 1–5 — attempt 3.

## The cube and the arrow prompts — attempt 3 — 2026-09-24 — score 7.5 (was 7)

**Changed since last round:** white-hot cores with magenta edges and a dark outline, nearly the whole sticker; a glowing magenta frame round the moving row/column instead of a hue shift; the prompt as a dark pill with the glyph and a short key hint; the lane in magenta and larger; the BEST bar moved above the dial; the mat text shortened so it hides; the Epic tint shifted toward violet.
**Reason it is not higher:** one finishing pass short — the magenta frame hangs off the bottom of the cube onto the mat, and the same arrow appears at three different weights on one screen (fat on the cube, thin in the queue, a small flat triangle on the pill).
**Keep:** the three-ring glyph (white core, magenta edge, dark outline); the frame round the column (the change that moved the score); the stickers keeping their colours; the clean air above the cube; the Neon cube as an object; the dark pill under the cube.
**Defects:** the frame overshoots the cube's base by a sticker-gap; three arrow weights; the queue above is ~15px specks with no backing; the glyph loses a ring on white (core vanishes) and on red (edge sinks) — the dark outline is thin; the right face blooms to white and competes with the arrow cores; magenta still on the floor (the shift to violet is not visible); the glyph is ~60% of the sticker, not nearly full.
**Ranked list:**
1. +0.5 fit the frame to the column (corners on the column's corners, nothing below the base) and thicken it into a lit bezel.
2. +0.5 one glyph everywhere: the pill carries the cube's three-ring glyph at HUD scale, as tall as the timer; the queue adopts it on a small dark pill or goes.
3. +0.25 fatten the dark outline so all three rings hold on white and red; grow the glyph toward 80%.
4. +0.25 tame the sticker bloom to colour, not white; only the arrow cores are white-hot.
5. +0.25 take magenta off the floor (station piece): the ring goes violet or cyan.
**Next:** apply 1–5 — attempt 4, the last.

## The thirteen cube looks as a set — attempt 3 — 2026-09-24 — score 7 (was 6)

**Changed since last round:** Prism a dark chrome body with six saturated spectral faces at 1.2× Epic glow, a lamp, sparks, the hue walk; Pastel six candy hues on a grey body; a gloss band painted into every Rare sticker; Jelly vivid and 40% see-through; Void violet with thin seams; Frost paler white-ice.
**Reason it is not higher:** Prism is now the brightest object on the sheet but is built exactly like Neon and Plasma (black body, flat glowing stickers, three colours showing), so it reads as a third Epic that happens to be yellow, not as the one Legendary.
**Keep:** Prism's yellow (the only warm glow in a blue-and-magenta hall); Void (the most distinctive cube, the one most likely to be screenshotted); glow means Epic; the upgrade lines Ember→Sunset and Classic→Neon; Ocean's and Sunset's gradients; Pastel's visible seams; polish (no clipping, consistent corners, no white-out).
**Defects:** Prism has no signature — each face one flat colour, chrome reads black in a dark hall, one sparkle invisible at 150px, no halo distinct from bloom; Pastel reads below Common (80–90% white, the gloss band whitens it further); Jelly not jelly (opaque in the still, olive top, Ocean's sibling); Frost and Slate a new look-alike pair vanishing into the blue hall (the magenta ring beats both); the Rare gloss is a fade, not a highlight, and bleaches Pastel's and Ocean's top faces; the key light washes the top face of every matte cube near-white; Prism's cyan face pale.
**Ranked list:**
1. +1 the rainbow ON Prism's faces (a spectral gradient so one frozen frame shows five or more hues) and one signature effect that survives 150px: many sparks or a ring of motes, and a halo on the mat no other station gets.
2. +0.5 rebuild Pastel at candy saturation (bubblegum pink, sky, lemon nameable at 150px); drop or shrink the whitening gloss band.
3. +0.25–0.5 make Jelly read as jelly without transparency: one dominant candy hue, body a darker shade of it, a brighter core, a darker rim, a large soft highlight.
4. +0.25 separate Frost from Slate and keep both brighter than the ring under them.
5. +0.25 turn the Rare gloss into a hard highlight (a crisp white shape in a corner), and dial back the top-face washout.
**Next:** apply 1–5 — attempt 4, the last.

## The hatch — attempt 2 — 2026-09-24 — score 6 (was 4)

**Changed since last round:** the wooden crate replaced by a sealed competition cube case in the tier colour (coloured body, lit seam, dark metal lid on top, glowing "?" on every side, a "SPEED CUBE OPEN - SEALED" tag, a lamp inside growing through the rattle); no avatars; the hall dims and desaturates with a tier-coloured beam on the station, the HUD and player list hidden; a white flash, a floor ring, sparks from the cube, the lid flying off, the stage lights back under the flash.
**Reason it is not higher:** the drop and the rattle still carry unfinished parts on the subject — the lid, the biggest face from the locked camera, is an unlit black slab, and the "spotlight" is a hard-edged translucent block whose vertical edges show in every frame.
**Keep:** the Epic purple body; the "?" with its halo; the seam (the best graphic idea in the piece); the sealed tag; the stage taking over; the reveal's floor wash; the scale of the drop.
**Defects:** the lid is an unlit black slab (40% of the silhouette); the beam is a box with hard vertical edges, not light; the rattle still has no juice (no sparks, motes or rays); the star particles are Roblox's stock sprite in a uniform field with no centre; the flash is a flat sheet with no source; the move arrows and lane bezel sit on the prize at the burst (a demo artefact: the real flow clears them, the capture did not); at 150px the lid merges with the hall; the timer pads read as two holes under the cube; the dim has not landed when the box enters.
**Ranked list:**
1. +1 the lid as the crown: bright gold or tier chrome, a lit rim round the top edge, the biggest "?" on the top face.
2. +0.5–1 the beam as light: soft edges, brighter at the base, thinning with height, motes rising inside.
3. +0.5 anticipation in the rattle: tier sparks leaking from the seam and circling, the seam widening into rays, the lid lifting a hair.
4. +0.5 shape the burst: confetti chips in the six cube colours dense at the cube and thinning outward; a flash brightest at the seam.
5. +0.5 the prize clean: no arrows or lane on the cube until the toast clears; the dim landed before the box enters; the pads take the floor glow.
**Next:** apply 1–5 — attempt 3.
