/* Building the environment a game is run in. */
#ifndef HK_GAMEENV_H
#define HK_GAMEENV_H

#include "games.h"

/* A malloc'd copy of a C string (OPENSTEP's libc has no strdup); NULL if out of memory. */
char *hk_copy_c(const char *s);

/* A new environment block (NULL-terminated, malloc'd, never freed: it is for a child that is about to exec): this
 * process's own, with HACKDIR set and the terminal described: TERM=stephack with a TERMCAP entry for the window (see
 * core/games.c), or, for a game that reads terminfo through ncurses and cannot use that, the game's own TERM name. */
char **hk_game_environ(const char *hackdir, const HkGameDef *game);

#endif
