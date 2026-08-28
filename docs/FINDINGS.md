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
* No recordings exist yet, so nothing here has been verified live in MAME.
  That is the single biggest gap in this document: **every statement above
  comes from static analysis of the bytes, and none of it has been watched
  running.**
