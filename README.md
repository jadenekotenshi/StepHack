# StepHack

A native OPENSTEP 4.2 front end for NetHack and its relatives. It is not a tiles interface: the game still runs
unmodified in its tty mode, inside a terminal window StepHack provides, and StepHack adds the conveniences around it.

**Status: early.** The key mapping and options-file code are tested on a development Mac; the application itself has not yet
been built or run on OPENSTEP. Expect rough edges and please report what you find.

## What it does

- **Runs the game for you.** Pick a game from *Game > New Game*; StepHack starts the program on a pty with a terminal
  description it knows the window really supports (colours, cursor addressing, line drawing for `DECgraphics`).
- **Number pad movement without a number pad.** The cursor keys move, Home / PgUp / End / PgDn are the four diagonals, and
  Shift runs. With the game's `number_pad` on these send the digits; with it off, the vi keys. The game needs no changes.
  A real keypad works as it always did. *Game > Keypad* switches the mapping if you change `number_pad` in play.
- **`number_pad` on by default.** If your options file doesn't set `number_pad`, StepHack adds `OPTIONS=number_pad:1` to
  it (switch this off in Preferences).
- **Line graphics by default.** If your options file sets no symbols (`DECgraphics`, `symset`, `IBMgraphics`), StepHack adds
  `OPTIONS=DECgraphics` so walls are drawn as lines (also switchable in Preferences). Anything you have set yourself, in
  either direction, is left alone.
- **Options file editing without disturbing it.** The reader and writer in `core/rcfile.c` keep your comments, other
  directives and layout, and change only the option concerned. (The options window itself is the next thing to be built.)
- **Line drawing.** Walls drawn with `DECgraphics` are painted as real lines, whatever font you use.

## Games

| Game | Program | Data directory | Options file |
|---|---|---|---|
| NetHack 3.6.7 | `/usr/local/bin/nethack` | `/usr/local/lib/nethackdir` | `~/.nethackrc` |
| Slash'EM 0.0.7E7F3 | `/usr/local/bin/slashem` | `/usr/local/slashemdir` | `~/.slashemrc` |
| NetHack 5.0 | `/usr/local/bin/nethack5` | `/usr/local/lib/nethack5dir` | `~/.nethackrc` |

These are where the [openstep-pkg](https://github.com/jadenekotenshi/openstep-pkg) packages install them. All three
locations can be changed in *Preferences*. NetHack 5.0 is listed but its port is still being finished. More variants
(NetHack 3.4.3, UnNetHack, SporkHack, EvilHack, SpliceHack) are planned.

## Building

On a development machine (macOS or Linux), the portable part builds and its tests run:

    make test        # key mapping, options-file editing, terminal emulation
    make lint        # rejects anything OPENSTEP 4.2's compiler can't take
    make check-objc  # syntax-checks the Objective-C against the host's SDK

On OPENSTEP 4.2 (gcc 2.7.2):

    make -f Makefile.openstep test
    make -f Makefile.openstep
    make -f Makefile.openstep install      # into /LocalApps
    make -f Makefile.openstep dist-fat     # an i386 + m68k + SPARC installer package

## Layout

- `core/` - portable C89 with no I/O and its own tests: the key mapping, the options-file editor and the game table.
- `term/` - the terminal emulator (shared with StepTTY, StepSSH and RatChat).
- `app/` - the Objective-C application.

## License

MIT; see `LICENSE`. The games themselves have their own licenses and are not part of this repository.
