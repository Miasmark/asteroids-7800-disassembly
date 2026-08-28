# Asteroids -- findings so far

Day one. This document is a starting map, not a finished one: almost
everything below is a *measurement* or an explicitly-flagged hypothesis,
and almost nothing is yet a confirmed claim about what the game does.

## The cartridge

| | |
|---|---|
| ROM | `Asteroids (NTSC) (Atari) (1987) (DFB93F40).a78` |
| Size | 16,512 bytes (128-byte header + 16,384) |
| MD5 | `457e065c27b1bc07614d6b69545dfffd` |
| Mapper | linear 16K, no banking, mapped `$C000-$FFFF` |
| Vectors | NMI `$D2FC`, RESET `$D000`, IRQ `$D32B` |

Structurally this is the same shape as the Centipede, Dig Dug and
Ms. Pac-Man cartridges in this series: a flat 16K with no bank switching,
so every address is unambiguous and cross-bank reference resolution --
a recurring source of error in the 32K projects -- simply doesn't apply.

One detail worth noting early: all three vectors point into a tight
cluster around `$D000`-`$D3xx`, at the *bottom* of the code region, while
the whole of `$C000-$CFFF` below them is untouched by the initial trace.

## Day one coverage

Tracing from the three hardware vectors alone reaches **41.9%** of the ROM
(6,860 of 16,384 bytes, 3,367 instructions), leaving 9,524 bytes in 15
gaps. For comparison, the sibling projects' day-one figures from the same
three-vector start were higher (Ms. Pac-Man reached 52.4%), which is a
statement about how much of this cartridge is data, not about how well the
trace went.

Every gap is now declared as a data block, so `--gaps` reports none and the
round-trip is byte-identical. **Declaring a block is not identifying it** --
the notes on each say so explicitly, and none of the 15 has had its
contents characterised yet.

## No missed code -- checked, not assumed

A naive scan for `JSR`/`JMP` opcodes whose operand lands inside a gap
returned six apparent hits (`$E385`, `$C004`, `$CA85`, `$CACA`, `$FE98`,
`$FF20`). All six are false positives. Re-checking each against the set of
addresses the disassembler actually *reached as code* showed every one is a
byte pattern sitting inside data, not a real instruction -- `$CACA`, for
instance, is just a run of `$CA` bytes, and `$FFFF` came from the vector
table itself.

So: **no traced code branches into any gap.** That matches what the sibling
16K projects found, and is the expected case on this hardware, where MARIA
fetches graphics by DMA without the 6502 ever loading them by address.

## The block at `$C000-$CFFF`, and a hypothesis that did *not* survive

The largest structural clue on day one: a page-aligned 4,096-byte block at
the very base of the mapped window, ending exactly where RESET begins. That
is precisely the position Ms. Pac-Man's character set occupies, so "this is
the font/tile set" is the obvious first hypothesis.

It was tested immediately, and the evidence does not support it. Ms. Pac-Man
stores glyphs as fixed-size cells with a pad byte at a constant offset,
which shows up as a sharp statistical signature -- one phase of the cell
far more likely to be `$00` than the others (42% versus 9-24%, an
unambiguous ~25-point spread). Running the same scan here across every cell
size from 3 to 16 produces no clear winner: the best is a 14-point spread
at cell size 16, which is weak enough to be ordinary structure in sparse
data.

That does not rule out graphics. It rules out *this particular layout*, and
it is recorded here so the next pass doesn't re-run a test that has already
come back negative. The block's identity is open.

## Signature notes on the other gaps

Byte-frequency signatures only -- these are descriptions of the data, not
claims about its purpose:

* `$E000-$F15D` (4,446 bytes) -- the largest gap. Heavily dominated by
  `$00` (2,236 bytes, just over half) with `$FF` next. Sparse rather than
  dense, which is consistent with bitmap data containing a lot of empty
  space, but that is a guess from a histogram.
* `$FDCE-$FFFF` (562 bytes) -- runs to the top of the ROM and contains the
  hardware vectors at `$FFFA-$FFFF`. Shows as a gap in every project for
  that reason. Declared with an explicit length rather than an end address,
  because the tool's `end` field is exclusive and `$FFFF` would otherwise
  be left unclaimed -- a one-byte trap this series has hit before.
* The remaining twelve gaps are small (1-148 bytes) and sit interleaved
  between traced routines, which is the usual shape of jump tables and
  per-object parameter tables rather than bulk graphics.

## First live pass: the scoring table, and the shared team score

`run-01.inp` (13,969 frames, length-checked against a 600,000-frame cap
before use, per a costly lesson from a sibling project) contains three
segments in one recording: a one-player game, a two-player *team* game,
and a two-player *competitive* game.

**The point-value table.** Grepping for `SED` found two sites, both in one
routine at `rom:DE5C` -- the same short-candidate-list technique that
opened up both sibling projects. It takes an award-type index in X and adds
a packed-BCD value to the current player's score, striding by
`CurrentPlayer`*4, so player 0's score is `ram_0046`-`ram_0049` and player
1's is `ram_004A`-`ram_004D`. The paired tables at `dat_FEDC` (low digits)
and `dat_FEE4` (high digits) decode to: **100, 50, 20, 500, 1000, 200**,
with two unused zero entries -- matching all six values the manual
documents (large asteroid 20, medium 50, small 100, large saucer 200,
small saucer 1,000, other player's ship 500).

**A real divergence from the sibling projects, worth stating plainly:**
these values are stored at *face value*. Both Galaga and Ms. Pac-Man
independently used a x10 BCD scale, where stored `$0100` meant 1,000
points. Carrying that convention over here would have mis-scaled every
award by a factor of ten. The family pattern is not a family rule.

**Live-verified**, not just read off the table: watching both score byte
ranges across the whole recording, every positive delta was exactly a
manual value -- +20 (x23), +50 (x40), +100 (x66), +200 (x3) -- with no
unexplained amounts. The 500 and 1,000 entries are **not** live-confirmed:
no small saucer and no player-versus-player kill occurred in this
recording, so those two rest on the table alone.

**The shared team score.** The user noted that Team mode displays a shared
score at top-centre. The bonus-ship code at `rom:DE75` explains it: the BCD
carry out of the low four digits fires exactly on a 10,000-point boundary
(matching the manual's bonus-ship rule), and the award is gated on
`GameMode` == 1 *and* `CurrentPlayer` == 2. `CurrentPlayer` therefore takes
a third value beyond the two players, and since the score routine strides
by `CurrentPlayer`*4, slot 2 lands at `ram_004E`-`ram_0051`.

Confirmed live across the recording's three segments: `GameMode` reads
`$FF` in one-player, `1` in team, `2` in competitive. During team play the
slot-2 score is exactly the **sum** of the two individual scores -- checked
at two independent moments (70+20=90, then 440+370=810) -- and stays 0 in
the other two modes. Slot 2's `ReserveShips` count was also seen depleting
only during team play, matching the manual's "sharing reserve ships". So
team mode maintains both individual scores *and* a shared total, and routes
the bonus ship to the shared pool.

## Hyperspace: the mechanism found, the reported death not reproduced

The user reported spending most of the two-player modes spamming the
"emergency teleport", and that it *sometimes* kills the ship with no
collision. That is the classic arcade Asteroids hyperspace risk, and the
manual doesn't mention it -- so it would be a real manual-vs-ROM
divergence if confirmed. It isn't confirmed yet.

**What is solid.** The 7800 pad has two buttons, read by `rom:sub_D66A`
into `Button1`/`Button2` per player. Across the recording player 1 pressed
Button1 503 times and Button2 46 -- fire versus a situational action -- and
Button2 is what triggers `rom:sub_D540`, hyperspace. That routine is
deliberately **rate-limited**: it returns immediately if the ship is
already in a special state, so mashing the button cannot re-trigger it
mid-jump. Measured: **73 button presses produced only 12 actual jumps**,
which fits "spamming" exactly. A real trigger sets the phase timer to
`$2C`; the timer counts *down*, and the state machine tests it at `$29` --
three steps later -- which is the re-entry checkpoint where `ram_00A5`
decides whether the ship survives.

**Where it stalls, and an honest contradiction.** A negative `ram_00A5` at
that checkpoint branches toward the ship-loss code, so it reads like a
"you die" flag. At the 12 jumps in this recording it was negative **11
times**. But a second probe, watching the reserve-ship counts directly,
found that **none of those 12 jumps cost a ship** within 40 frames. Both
numbers come from the same recording, so one of my readings is wrong:
a negative `ram_00A5` plainly does not by itself mean death. The gates
below it are the likely explanation -- one state value skips the loss
outright, and in team mode another byte can skip it or redirect the loss
to the shared slot -- but which one fired here is not established.

So: the hyperspace *mechanism* is found and the rate-limiting explains the
press-to-jump ratio, but **the reported random death is not reproduced**,
and what `ram_00A5` actually represents is still open. What would settle
it is a recording that contains an actual hyperspace death.

### run-02: the death captured, and two of my readings corrected

The user then recorded exactly that -- asteroids mostly cleared, teleport
pressed repeatedly, deaths only from teleport. It settles most of this.

**The deaths come through the hyperspace path, not a collision.** Write-
tapping the reserve-ship counts shows both losses written from `PC=$D7BC`,
inside this state machine. That confirms the user's "no collision"
observation from the code side rather than from watching the screen.

**The sequence.** A jump runs three phases on `ShipSpecialState`, with
`ShipPhaseTimer` counting down one step per two frames: phase 2 (timer
`$2C`, leaving), phase 3 (timer `$DE`, in hyperspace), then phase 1 (timer
`$2C` again, re-entry). The survival check fires when the timer reaches
`$29` **during phase 1**.

**A trap that had fooled the previous probe.** The timer passes through
`$29` in *both* phase 2 and phase 1 -- six frames after the jump, and again
~170 frames later. Only the phase-1 occurrence is the re-entry check.
Reading the phase-2 one gave a clean, confident, meaningless number.

**And a retraction.** `ram_00A5` is not the "you die" flag. Across run-02
it reads `$FF` at every checkpoint, on surviving and fatal jumps alike, so
it cannot be what decides. The earlier reading was wrong.

**What actually separates them is timing.** Both fatal jumps died exactly
**172 frames** after the jump; every survived jump completed its whole
cycle in about **110 frames**.

### Resolved: hyperspace carries a flat ~19.5% death roll

Logging every state transition rather than reading further code showed the
divergence immediately, and inverted the model: the four safe jumps go
state 2 -> **0** and never enter phase 3 at all. Phase 3 is not "in
hyperspace" -- **it is the destruction sequence**.

The decision is made at the end of phase 2, in `rom:L_D83D`, and it is two
independent things:

1. **A landing spot is drawn at random and *validated*.** Two PRNG calls
   give an X and a Y; `rom:sub_F93C` then tests the spot. If the test
   fails, the routine nudges the phase timer back up so the next tick
   repeats the whole draw -- it **retries until the spot is clear**. So
   materialising inside a rock is explicitly prevented, and is *not* what
   kills you.
2. **Then a separate roll decides whether you live.** With a clear spot in
   hand, `rom:L_D85F` draws *one more* random byte and compares it against
   `#$32`. `>= $32` rematerialises normally; `< $32` destroys the ship.
   That is **50 in 256 -- about 19.5% -- on every re-entry, regardless of
   what is on screen.**

This is a genuine **manual-versus-ROM divergence**: the manual describes
hyperspace only as warping "to a random location on screen" and says
nothing about any risk.

It also matches the user's account. Their run-02 has 7 jumps of which 3
were fatal, and their own estimate was "clearly less than 92% but higher
than 0%". Three-of-seven sits above the 19.5% expectation but is
unremarkable at that sample size -- and notably, their instinct that the
deaths had nothing to do with collisions was exactly right, for a more
interesting reason than landing on a rock.

## Asteroids: sizes, splitting, and the object array

Decoded by watching the object array across scoring events rather than by
reading the collision code -- faster, and it produces evidence rather than
inference.

`ObjType` (`ram_008C`) is a per-object type array of roughly `$2C` slots,
with `$FF` for an empty slot. Dumping it either side of six scoring events
in `run-01` gives the whole asteroid system:

| Type | Size | Points | On destruction |
|---|---|---|---|
| `$32` | large | 20 | becomes **two** `$21` |
| `$21` | medium | 50 | becomes **two** `$10` |
| `$10` | small | 100 | nothing spawned |

The points are inverse to size, exactly as the manual states, and the
split cascade is the classic one. Observed directly and more than once:
large at frames 1414 and 1956, medium at 1424, small at 1476 and 1570.

**Bit 7 marks destruction rather than being a separate type.** A destroyed
object keeps its identity and gains `$80`: `$10`->`$90`, `$21`->`$A1`,
`$32`->`$B2`, and the player ship `$23`->`$A3`. The slot then clears to
`$FF` shortly after. That incidentally explains the `$A3` written by the
hyperspace death path -- it is just the ship type with the exploding bit
set, not a distinct "destroyed by hyperspace" marker.

### The saucer, and what the other types are

Applying the same technique to `run-01`'s three `+200` awards identifies
the rest of the object system.

**The saucer is `$25`, and it lives in a dedicated slot.** All three kills
show index `$19` going `$25` -> `$A5` -- always the same slot, not one
drawn from the general pool. That is a *fifth* independent confirmation of
the bit-7 destruction rule, which now holds for every type seen destroyed:
`$10`/`$90`, `$21`/`$A1`, `$32`/`$B2`, `$23`/`$A3`, `$25`/`$A5`. Across the
whole recording `$25` is present for only ~994 frames, so the saucer is on
screen briefly and rarely.

**The small saucer is `$14`** -- resolved by `run-03`, which the user
recorded specifically to capture it. It uses the *same* dedicated slot
`$19` as the large saucer, so that slot is simply "the saucer" and the type
byte distinguishes large (`$25`, 200 points) from small (`$14`, 1,000
points). Both match the manual. `$14` -> `$94` on destruction: a sixth
confirmation of the bit-7 rule.

**And that run isolated something the earlier ones could not.** It contains
two small saucers, and the user let them die differently on purpose:

| Frames | Fate | Award |
|---|---|---|
| 5330-5392 | flew into an asteroid, destroyed itself | **none** |
| 5922-6142 | shot by the player | **+1000** |

Both show the identical `$14` -> `$94` transition. So **destruction and
scoring are separate**: the slot explodes either way, and the award is
gated on the player having caused it. That is worth carrying forward --
an object-type transition alone is *not* evidence of a scoring event, and
any future probe built on this array shouldn't treat it as one.

Not measured: `run-03` shows four large saucers first (frames 2538-4808)
and only then the two small ones, consistent with small saucers arriving
later in a game -- but that is one run, and no threshold has been tested.

**`$06` is a player shot.** A `$06` slot flips to `$86` on the exact frame
of every hit -- for asteroid kills and all three saucer kills alike -- i.e.
the shot is consumed on impact.

**Retracted twice, and now settled: there were never any `$07` objects.**
The user pointed out that if those slots were shots they ought to be
consumed as shooting continues. Measuring the array's actual extent
settled it: across a 4,599-frame window, indices `$00`-`$23` hold a valid
object type on *every single frame*, and index `$24` onward holds one on
**zero** frames.

So `ObjType` is exactly **36 slots, `$008C`-`$00AF`**. The "eight
permanently-present `$07` objects" were reads **past the end of the array**
into unrelated zero-page variables at `$00B0`-`$00B7` that happen to
contain `$07`. They were never objects; the fact that a few of them changed
value was ordinary variable activity, not movement. Both the original
shot-pool guess *and* its first retraction were reasoning about data
outside the array entirely.

**A bonus: this identifies the hyperspace investigation's mystery byte.**
`ram_00A5` is `$008C + $19` -- the `ObjType` entry for the dedicated
*saucer* slot. The test at `rom:D79E` is asking whether a saucer is
currently on screen (`$FF` = none, and negative), not consulting a "death
flag". That is exactly why it read `$FF` throughout `run-02`: that
recording contains no saucers. The hyperspace conclusion is unaffected --
the ~19.5% re-entry roll was traced through a different path and never
depended on this byte.

## Difficulty, measured against an Expert run

`run-04` was recorded on Expert specifically to expose differences, with the
observations that things move faster, saucers arrive sooner, and a small
saucer showed up before wave 1 ended.

**The difficulty byte.** Diffing zero page across runs -- looking for bytes
constant *within* a run but different *between* runs -- left one strong
candidate, and the code confirms it: `Difficulty` (`ram_0083`) is
incremented with a clamp at 3 and decremented with a floor at 0, exactly the
manual's four levels. `run-01`/`02`/`03` all read **1**; `run-04` reads
**3**. Since the manual says Novice has no saucers and all three
difficulty-1 runs contain saucers, 1 cannot be Novice -- so the top of the
mapping is pinned by the user's Expert run and the bottom by that
cross-check.

**"Novice has no saucers" is confirmed in the ROM.** The saucer routine
loads `Difficulty` and returns immediately if it is zero. No saucer is ever
processed on Novice.

**Why saucers come faster.** `Difficulty` indexes a 4-byte table reading
`$40, $60, $80, $DF` for levels 0-3, giving `DifficultyCap`. A per-player
accumulator, `SaucerPressure`, is added to and then **clamped to that cap**
-- so a harder setting simply permits a larger value. That value feeds the
saucer spawn path, which checks the saucer slot is empty before proceeding.
Higher difficulty raises the ceiling, and saucers arrive sooner.

Measured, rather than inferred:

| | difficulty 1 | Expert (3) |
|---|---|---|
| first saucer appears | frame 2006 | **frame 1070** |
| small saucer (`$14`) is the | 5th saucer (frame 5330) | **3rd saucer (frame 2522)** |

Both match the user's account. Not established: the units of
`SaucerPressure`, and whether the large-versus-small saucer choice follows
from it or from a separate rule. The "things move faster" impression is
also untested -- no object-velocity comparison has been made.

## What difficulty actually controls

Tracing every read of `Difficulty` gives three distinct gameplay effects
plus a display use -- and confirms a second manual claim from the ROM.

**1. Whether saucers exist at all.** The saucer routine returns immediately
when difficulty is 0, so Novice never processes one. (Manual: "Novice
features no saucers.")

**2. How soon saucers arrive.** Difficulty indexes a 4-byte table
(`$40`/`$60`/`$80`/`$DF`) giving a cap on the `SaucerPressure` accumulator
that feeds the spawn path. Measured: first saucer at frame 1070 on Expert
versus 2006 at difficulty 1.

**3. How many fragments an asteroid splits into.** This is the manual's
"simplified asteroid splitting mechanics" for Novice, and it is a branch on
difficulty around the fragment spawner:

| Difficulty | Fragments |
|---|---|
| 0 Novice | **one** |
| 1-2 Intermediate / Advanced | **two** |
| 3 Expert | two, **plus a 1-in-4 chance of a third** |

The fragment *type* is computed arithmetically -- destroyed type minus
`$91` -- which reproduces every size seen live: `$B2`->`$21`, `$A1`->`$10`,
and `$90` goes negative so a small asteroid yields nothing.

**Live-confirmed** by counting the net change in live asteroid slots per
destruction: at difficulty 1, all 18 splits netted **+1** (one destroyed,
two created). On Expert: +1 eighteen times, and **+2 twice** -- three
fragments from a single rock. It also netted +0 twice, which fits the
spawner finding no free slot; that exhaustion, plus the small sample,
explains why the observed extra-fragment rate (2 of 22) sits under the
nominal 1-in-4.

**Novice is now confirmed too.** `run-05` starts by accident at difficulty
1 and is reset to Novice at frame 1082. Across the Novice portion, every
one of **39 splits netted +0** -- one rock destroyed, exactly one created.
The user's description of how that looks on screen is the useful half: the
rock *"seems to just get smaller with hits rather than becoming 2 smaller
pieces"*, which is exactly what a single fragment of the next size down
produces. And the saucer slot, once initialised to `$FF` at frame 160,
never changes again across the remaining ~6,400 frames -- no saucer is ever
spawned.

All three fragment counts are therefore **measured, not inferred**: one on
Novice, two at difficulty 1, and two-plus-an-occasional-third on Expert.
The only level never recorded is 2 (Advanced), whose behaviour is
interpolated from the code alone.

**4. Display.** Difficulty is added to a base index before a text call,
consistent with selecting one of four level-name strings.

## The `$E000` block, solved: MARIA reads it straight from ROM

The largest unknown block, 4,446 bytes and 27% of the ROM, is MARIA
character/graphics data -- and the route in was a single instruction.

Scanning for a page constant in the block's range followed by a zero-page
store turned up `rom:F506`: **`LDA #$E0 ; STA $34`**, and `$34` is
`CHARBASE`. Write-tapping the MARIA registers across a recording confirms
it is written exactly once, at init, and never changed. So MARIA's indirect
character mode fetches glyph data from `$E000+` **in place, straight from
the cartridge** -- unlike the sibling Ms. Pac-Man project, where `CHARBASE`
pointed into RAM and the tile set was copied there at boot.

Rendering the block as an 8-line character set produces plainly readable
text: the digits, `PLAYER`, `GAME OVER`, `NOVICE` / `INTERMEDIATE` /
`ADVANCED` / `EXPERT`, `ONE PLAYER`, `TWO PLAYERS`, `TEAM PLAY`,
`COMPETITION PLAY`, and `COPYRIGHT ATARI 1984`.

That independently corroborates two things previously established from code
alone: the **four difficulty names** behind `Difficulty`'s 0-3 range, and
the **three game modes** behind `GameMode`. Both were inferred from branch
structure and manual cross-checks; here they are, spelled out in the ROM's
own artwork.

**A correction.** One commit earlier I recorded that read-tapping showed
zero CPU reads of this block during play, and wrote that up as "copied into
RAM once and rendered from there". That was wrong -- the block is never
copied. The tap simply cannot see MARIA's DMA, which is precisely the trap
the toolkit's own pitfalls document after the sibling project hit it. I
had the lesson written down and still drew the inference it warns against.

Still open within the block: its internal layout, particularly what
occupies `$E800-$F15D` beyond the first character page, and whether the
asteroid and ship shapes live here or in `dat_C000`.

## `$C000`: the moving objects, found via the display list

The second large block resisted every static search, and for a good
reason: **there are zero real absolute references to it anywhere in the
ROM**, no `LDA #$Cx / STA zp` pointer setup, and no pointer table. (The one
apparent absolute hit was another mid-instruction false positive -- the
scanner reading an `ADC`/`CMP` pair's operand bytes as an opcode. That is
the third time this class of error has turned up here, and the second time
it briefly looked like a lead.)

The route in was the display list. MARIA's registers are write-only, so
they have to be caught on the write: tapping them gives `CHARBASE` = `$E0`
and the display-list pointer `DPPH`/`DPPL` = **`$1A98`**. Walking the DLL
from there shows per-zone entries whose graphics pointers land squarely
inside the block -- `$C0E7`, `$C1BB`, `$C200`, `$C6FE`, `$C7FE`, `$CCF7`
and more, at widths of 1-2 bytes.

So the two big blocks divide the graphics work cleanly:

| Block | Mode | Role |
|---|---|---|
| `$E000-$F15D` | character (via `CHARBASE`) | text and a per-zone constant element |
| `$C000-$CFFF` | **direct** (via display-list pointers) | the moving game objects |

The pointers are computed into a RAM display list every frame and the data
fetched by MARIA DMA -- which is precisely why no 6502 instruction ever
names these addresses, and why a CPU read tap sees nothing during play.

### Decoded: the sprite sheet

Sampling the display list live across a recording gives each entry's *own*
width and line count, which is what the earlier guessed extents lacked. With
those, the block resolves cleanly.

It is a **page-strided direct-mode sprite sheet**: a 16-page by 256-byte
grid where each sprite occupies `width` consecutive columns across all 16
pages -- one row per page -- read with MARIA's offset counting down.
Sprites are packed contiguously at a stride equal to their width, and the
sheet is organised into banks by width. Live sampling finds 490 distinct
width-3 addresses, 720 width-2 and 270 width-1, essentially all at
stride = width, which confirms the packing.

Rendered at those real parameters, the artwork comes out:

| Bank | Width | Contents |
|---|---|---|
| from `$C000` | 3 (12px) | ~36 rotation frames of the **large asteroid**, then its explosion sequence |
| from `$C07B` | 2 (8px) | ~24 rotation frames of the **medium asteroid**, explosion frames, then the **player ship** through its rotation angles |
| from `$C0ED` | 1 (4px) | **small asteroid** frames and debris |

That lines up exactly with the object system decoded earlier -- three
asteroid sizes (`$32`/`$21`/`$10`), each animated by rotation, plus ship and
explosions.

Not established: exact bank boundaries and frame counts, and which frame
index maps to which rotation angle.

The rendered sheets are deliberately **not committed** -- they are derived
from the cartridge's copyrighted artwork, which this repo does not
redistribute -- but they are reproducible from the ROM with the toolkit's
`gfx.py` using the widths and line counts recorded here.

## What's still open

Refreshed after several rounds of work -- a number of the day-one bullets
here had been resolved and were left standing, which is its own kind of
error.

**Both large blocks are now identified** -- see "The `$E000` block,
solved" and "`$C000`: the moving objects" above. What remains is their
*internal* layout: which bytes are which sprite, and what occupies
`$E800-$F15D` beyond the first character page.

**Collision detection proper.** The object system, splitting and scoring
are all mapped, but the actual collision test -- `rom:sub_F93C`, used both
for hyperspace landing-spot validation and, presumably, for rock-vs-ship
and shot-vs-rock -- has never been traced. Tractable, and it sits right
next to work already done.

**The 500-point award** (shooting the other player's ship) is the one score
entry still unconfirmed live; it needs a competitive two-player run where
one player actually shoots the other.

**Smaller, well-defined questions:**

* Which award index maps to which object is inferred from matching the
  manual's values, not observed directly; a probe tagging the X register at
  each score call would settle it.
* Whether the large-versus-small saucer choice follows from
  `SaucerPressure` or a separate rule.
* Whether the ~19.5% hyperspace death roll varies by difficulty -- the
  `#$32` constant is a literal at that site, but a difficulty-indexed
  variant elsewhere has not been ruled out.
* Difficulty 2 (Advanced) has never been recorded; its behaviour is
  interpolated from the code alone.
* The twelve small interleaved gaps. Two are now identified -- the
  per-difficulty cap table and the score-value tables -- so the rest are
  likely the same sort of thing: small parameter and jump tables.
* "Things move faster on Expert" remains untested; no object-velocity
  comparison across difficulties has been made.
