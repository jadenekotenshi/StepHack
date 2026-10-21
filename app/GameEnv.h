/* Building the environment a game is run in. */
#ifndef HK_GAMEENV_H
#define HK_GAMEENV_H

/* A malloc'd copy of a C string (OPENSTEP's libc has no strdup); NULL if out of memory. */
char *hk_copy_c(const char *s);

/* A new environment block (NULL-terminated, malloc'd, never freed: it is for a child that is about to exec): this
 * process's own, with TERM and TERMCAP describing the terminal window (see core/games.c) and HACKDIR set. */
char **hk_game_environ(const char *hackdir);

#endif
