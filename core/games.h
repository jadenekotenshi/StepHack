/*
 * games.h -- what the front end knows about each game before the user has told it anything: where the OPENSTEP packages
 * install it, what its run-commands file is called, and the terminal description it is run under.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_GAMES_H
#define HK_GAMES_H

/* How a game is told to use the curses interface and its line drawing. */
enum {
    HK_CURSES_NONE = 0,       /* the game has no curses interface */
    HK_CURSES_SYMSET = 1,     /* 3.6 and later: OPTIONS=windowtype:curses and symset:DECgraphics */
    HK_CURSES_GFX = 2         /* the 3.4.3 line with a curses port: windowtype:curses and cursesgraphics */
};

/* Which commands a game has depends on the line it descends from. */
enum { HK_FAMILY_34 = 1, HK_FAMILY_36 = 2, HK_FAMILY_50 = 4 };    /* NetHack 3.4.3 and its variants (Slash'EM), 3.6.x, 5.0 */

typedef struct {
    const char *id;             /* short key for preferences: "nethack", "slashem" ... */
    const char *title;          /* shown in the menu */
    const char *launcher;       /* the script or program that starts it (it sets HACKDIR itself) */
    const char *hackdir;        /* the game's data directory */
    const char *rcname;         /* run-commands file in the user's home directory */
    const char *rcname_alt;     /* an older name the game falls back to if the first is absent, or NULL */
    const char *rcdefault;      /* a template options file in the data directory that the game copies for a new player, or NULL */
    const char *schema;         /* options schema name (the file schemas/<schema>.txt) */
    const char *line_option;    /* the boolean option that draws walls with line graphics ("DECgraphics"), NULL if unsure */
    int         verified;       /* 0 for a game whose OPENSTEP port is still being worked on */
    int         family;         /* HK_FAMILY_* */
    int         curses;         /* HK_CURSES_* */
    int         curses_default; /* 1: run it with curses unless told otherwise (its package is built with that interface) */
    const char *term;           /* TERM for a game built on ncurses/terminfo, which cannot use the stephack termcap entry; NULL: use it */
    const char *sysconf;        /* the system configuration file in the data directory ("sysconf"), or NULL if the game has none */
} HkGameDef;

/* How a game is started: normally, in wizard (debug) mode, or in explore (non-scoring) mode.  The mode is the game's -D or -X. */
enum { HK_MODE_NORMAL = 0, HK_MODE_WIZARD = 1, HK_MODE_EXPLORE = 2, HK_MODES };
const char       *hk_mode_arg(int mode);        /* "-D", "-X", or NULL for a normal game */
const char       *hk_mode_name(int mode);       /* "wizard mode", "explore mode", or "" */

int               hk_game_count(void);
const HkGameDef  *hk_game(int index);                 /* NULL if out of range */
const HkGameDef  *hk_game_by_id(const char *id);

/* The termcap entry the games are run under (set as TERM and TERMCAP in their environment), so they get colours, line
 * drawing and cursor addressing that the terminal emulator really supports whatever /etc/termcap says. */
#define HK_TERM_NAME "stephack"
const char       *hk_termcap_entry(void);

#endif
