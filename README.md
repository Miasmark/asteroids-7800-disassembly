# Asteroids (Atari 7800) disassembly

A byte-identical disassembly and memory-map investigation of *Asteroids*
(NTSC, Atari, 1987), built with
[a7800-toolkit](https://github.com/Miasmark/a7800-toolkit) and MAME as a
live-verification instrument, not just a static reader.

**This repo does not contain the ROM.** Supply your own legally-owned dump
(`Asteroids (NTSC) (Atari) (1987) (DFB93F40).a78`, alongside a 7800 BIOS)
to reproduce anything here. The disassembly listing itself (`src/rom.asm`)
isn't committed either -- it's fully generated from
[`annotations.json`](annotations.json) plus the ROM, and regenerating it is
one command (below).

## Start here

[`docs/FINDINGS.md`](docs/FINDINGS.md) is the real deliverable: a narrative
of what's been confirmed live in MAME, what's still just a hint, and what
was actively distrusted, tested, and in several cases retracted rather than
assumed. [`annotations.json`](annotations.json) is the machine-readable form
of the same knowledge.

Every byte of the ROM is classified, and both large graphics blocks are
identified and decoded: the character/text set MARIA reads directly via
`CHARBASE`, and the direct-mode sprite sheet holding the asteroid rotation
frames, the ship and the explosions. Solved and live-verified on the
gameplay side: the complete scoring table, the asteroid size and split
cascade, both saucers and the rule that picks between them, the size-aware
collision test, hyperspace including its re-entry death roll, spawn
invulnerability, and everything the four difficulty levels control.

The wrong turns are deliberately left next to the corrections, because
several were the most instructive part of the work: a collision claim
correct about one routine but wrongly generalised to the whole game, a
"probability model" that blamed the random generator for a branch that had
simply been read past, an inference about graphics being copied to RAM that
the project's own documented pitfall warns against, and object "slots" that
turned out to be reads past the end of an array.

A privately-held, unlicensed historical source for this game exists (the
same archive the sibling projects' reference sources came from), and was
handled the way those projects settled on: held off until the independent
work was substantially complete, then used strictly as a check -- never as
the origin of a finding, never quoted or copied in. That cross-check has now
been done and is written up in `docs/FINDINGS.md`: broad corroboration
including a byte-for-byte match on the collision extent tables and an exact
match on the hyperspace death constant, plus one small unreconciled numeric
point left open rather than resolved in this project's favour.

Working discipline, same as the sibling projects: every claim about what a
byte range does should be checked live before it's trusted, not just
pattern-matched from a probe script carried over from a previous project.
Every `annotations.json` change is followed by JSON validation, `disasm.py`
regeneration, and a `verify.py` byte-identical round-trip check.

## Reproducing it

```
# from this directory, with the toolkit checked out as a sibling (adjust
# the path below to wherever you have it) and your own ROM copy dropped in:

python3 ../a7800-toolkit/tools/disasm.py "Asteroids (NTSC) (Atari) (1987) (DFB93F40).a78" -c annotations.json -o src
python3 ../a7800-toolkit/tools/verify.py "Asteroids (NTSC) (Atari) (1987) (DFB93F40).a78" -d src
# -> ROUND-TRIP PASSED
```

`src/rom.asm` is then a full listing, byte-identical when reassembled.

Add `--gaps` for a text report of every byte reached as neither code nor a
declared data block, or `--map` for the same picture as a heatmap (green
code, blue declared data, red gap -- needs Pillow):

```
python3 ../a7800-toolkit/tools/disasm.py "Asteroids (NTSC) (Atari) (1987) (DFB93F40).a78" -c annotations.json -o src --gaps --map
```

![Coverage map](docs/img/coverage-map.png)

## Recording a session

Live findings in this project come from replaying a MAME input
recording (a deterministic button-press log, not video, and not
copyrighted content) against a PC/frame-tagged Lua probe -- the same
technique the sibling projects used throughout. Six recordings
(`run-01.inp` through `run-06.inp`) are committed here and most live
findings cite specific frames in one of them -- several were recorded to
test a specific prediction, which is what makes the claims in
`docs/FINDINGS.md` reproducible rather than assertions.

```
./"Record Session.command"        # play, Esc to stop -> next free run-NN.inp
./"Play Recording.command" run-01 # watch a recording play back
```

Manual (mechanics reference, scoring table):
https://atariage.com/manual_html_page.php?SoftwareID=2117

## Layout

| | |
|---|---|
| `annotations.json` | The recipe. Feed it to `disasm.py` to get the listing. |
| `docs/FINDINGS.md` | The narrative -- read this first. |
| `docs/img/` | `coverage-map.png` (regenerate with `disasm.py --map`). |
| `tools/` | This project's own probe scripts. |
| `Play Recording.command`, `Record Session.command` | Double-click launchers for replaying/recording a session (macOS + MAME on `PATH`). |

Not committed (see `.gitignore`): the ROM, the generated `src/rom.asm` and
`build/`, and the probe scripts' regeneratable output manifests -- all
reproducible from the ROM and a recording.
