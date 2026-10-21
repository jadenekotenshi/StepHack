/*
 * games.h -- what the front end knows about each game before the user has told it anything: where the OPENSTEP packages
 * install it, what its run-commands file is called, and the terminal description it is run under.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_GAMES_H
#define HK_GAMES_H

/* Which commands a game has depends on the line it descends from. */
enum { HK_FAMILY_34 = 1, HK_FAMILY_36 = 2, HK_FAMILY_50 = 4 };    /* NetHack 3.4.3 and its variants (Slash'EM), 3.6.x, 5.0 */

typedef struct {
    const char *id;             /* short key for preferences: "nethack", "slashem" ... */
    const char *title;          /* shown in the menu */
    const char *launcher;       /* the script or program that starts it (it sets HACKDIR itself) */
    const char *hackdir;        /* the game's data directory */
    const char *rcname;         /* run-commands file in the user's home directory */
    const char *schema;         /* options schema name (the file schemas/<schema>.txt) */
    const char *line_option;    /* the boolean option that draws walls with line graphics ("DECgraphics"), NULL if unsure */
    int         verified;       /* 0 for a game whose OPENSTEP port is still being worked on */
    int         family;         /* HK_FAMILY_* */
} HkGameDef;

int               hk_game_count(void);
const HkGameDef  *hk_game(int index);                 /* NULL if out of range */
const HkGameDef  *hk_game_by_id(const char *id);

/* The termcap entry the games are run under (set as TERM and TERMCAP in their environment), so they get colours, line
 * drawing and cursor addressing that the terminal emulator really supports whatever /etc/termcap says. */
#define HK_TERM_NAME "stephack"
const char       *hk_termcap_entry(void);

#endif
