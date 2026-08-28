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
cycle in about **110 frames**. So the fatal ones are the jumps where phase
3 *ran long*. What ends phase 3 early versus letting it run on is the
remaining open question -- and it is now a sharp one, with a known
signature to look for.

## What's still open

Essentially everything. Named explicitly so the next session has targets
rather than a blank page:

* What the `$C000-$CFFF` block actually is, given the glyph-grid layout is
  ruled out.
* What the large `$E000-$F15D` block is.
* Every one of the twelve small interleaved gaps.
* All gameplay mechanics: scoring, the rock split/size progression, saucer
  behaviour and timing, hyperspace, thrust and inertia, extra-life
  threshold, wave progression and difficulty.
* The 500-point (other player's ship) and 1,000-point (small saucer)
  awards are read from the table but never occurred in `run-01.inp`, so
  neither is live-confirmed.
* Which award index maps to which object is inferred from the manual's
  values, not observed directly -- a probe tagging the X register at each
  call would settle it.
* The four difficulty levels (Novice/Intermediate/Advanced/Expert), and
  the manual's claim that Novice has no saucers and simplified splitting.
* Everything else about gameplay: rock split behaviour, saucer timing,
  hyperspace, thrust and inertia, wave progression.
