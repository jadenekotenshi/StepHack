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
- **An options window.** *Game > Options...* (Cmd-O) lists the game's options as switches, pop-up menus and fields,
  grouped by topic, and saves them to its options file. It keeps your comments, other directives (`MSGTYPE=`,
  `MENUCOLOR=` ...) and layout, and changes only the option you touched; an option set back to the game's own default is
  removed from the file. The lists are in `schemas/` (NetHack 3.6.7 and Slash'EM so far) and are compiled in.
- **Scores.** *Game > Scores...* (Cmd-S) shows the latest or the best finished games from the game's `xlogfile`, as a
  table, and the game's own high-score list (`-s` and `-s all`); it is text you can select and copy. Games that keep no
  `xlogfile` show only the high-score list.
- **Command bar.** A row of buttons under the game (Pray, Name, Call, Loot, Chat, Enhance, Overview, Attrib) and a *More*
  menu (Force, Untrap, Turn Undead, Offer, Sit, Ride, Wipe, Rub, Dip, Invoke, Jump, Monster, Adjust, Conduct, Discoveries,
  Look Here, Redraw) type the command for you. They send extended commands, which every version takes whatever the
  movement-key setting is, and only the ones the game has (no Overview for Slash'EM).
- **Endings.** When a game finishes, what it left on the screen (tombstone, final attributes and inventory, high scores) is
  saved as text under `~/.StepHack/endings` (the last 30 of each game). *Game > View Ending...* (Cmd-E) shows them; you can
  copy or save one.
- **Curses interface by default.** Where a game has it (every game here but Slash'EM), StepHack adds
  `OPTIONS=windowtype:curses` to an options file that doesn't name an interface, with line graphics (`symset:DECgraphics`,
  or `cursesgraphics` for SporkHack and UnNetHack) and, if unset, `color`, `guicolor`, `mouse_support`, `perm_invent`,
  `splash_screen` and `popup_dialog`. The window opens at 110 x 32 instead of 80 x 24 and the game runs under the `xterm`
  terminal description. A file that says `windowtype:tty` gets the plain interface; Preferences can turn curses off per game.
  The games must have been built with the curses interface.
- **Line drawing.** Walls drawn with `DECgraphics` are painted as real lines, whatever font you use.

## Games

| Game | Program | Data directory | Options file |
|---|---|---|---|
| NetHack 3.6.7 | `/usr/local/bin/nethack` | `/usr/local/lib/nethackdir` | `~/.nethackrc` |
| Slash'EM 0.0.7E7F3 | `/usr/local/bin/slashem` | `/usr/local/slashemdir` | `~/.slashemrc` |
| NetHack 5.0 | `/usr/local/bin/nethack5` | `/usr/local/lib/nethack5dir` | `~/.nethackrc` |
| EvilHack 0.9.3 (untested) | `/usr/local/bin/evilhack` | `/usr/local/lib/evilhackdir` | `~/.evilhackrc` |
| SpliceHack 1.2.0 (untested) | `/usr/local/bin/splicehack` | `/usr/local/lib/splicehackdir` | `~/.splicehackrc` |
| UnNetHack 6.0.17 (untested) | `/usr/local/bin/unnethack` | `/usr/local/share/unnethack` | `~/.unnethackrc` (`~/.nethackrc` while that is absent; a new one starts from the game's `unnethackrc.default`) |
| SporkHack 0.6.5 | `/usr/local/bin/sporkhack` | `/usr/local/lib/sporkhackdir` | `~/.sporkrc` (`~/.nethackrc` while that is absent) |

These are where the [openstep-pkg](https://github.com/jadenekotenshi/openstep-pkg) packages install them. All three
locations can be changed in *Preferences*. More variants
(NetHack 3.4.3) is planned. SporkHack, UnNetHack, EvilHack and SpliceHack are built on ncurses, so they are run under the
stock `xterm` terminal description instead of StepHack's own termcap entry; *Preferences* has a *Terminal* field to change
that for any game (`stephack` selects StepHack's own entry).

## Building

On a development machine (macOS or Linux), the portable part builds and its tests run:

    make test          # key mapping, options-file editing, option lists, score tables, terminal emulation
    make session-smoke # a game session end to end on a real pty with a fake game (also runner-smoke, ending-smoke)
    make lint        # rejects anything OPENSTEP 4.2's compiler can't take
    make check-objc  # syntax-checks the Objective-C against the host's SDK

On OPENSTEP 4.2 (gcc 2.7.2):

    make -f Makefile.openstep test
    make -f Makefile.openstep
    make -f Makefile.openstep install      # into /LocalApps
    make -f Makefile.openstep dist-fat     # an i386 + m68k + SPARC installer package

## Layout

- `core/` - portable C89 with no I/O and its own tests: the key mapping, the options-file editor, the option lists and the game table.
- `schemas/` - the option lists, one text file per game; `tools/gen_schemas.py` compiles them into `core/schema_data.c`.
- `term/` - the terminal emulator (shared with StepTTY, StepSSH and RatChat).
- `app/` - the Objective-C application.

## License

MIT; see `LICENSE`. The games themselves have their own licenses and are not part of this repository.
