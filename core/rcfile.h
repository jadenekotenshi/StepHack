/*
 * rcfile.h -- reads and edits a NetHack-style run-commands file (.nethackrc, .slashemrc ...) without disturbing the
 * parts of it the program doesn't understand.
 *
 * A file is kept as its lines, character for character.  Only the options lines (OPTIONS=a,!b,c:d, or the bare form old
 * versions accept) are looked into, and an edit changes the one item concerned: comments, other directives (MSGTYPE=,
 * MENUCOLOR=, SYMBOLS= ...), blank lines and the layout of every other line survive untouched.  Where an option appears more
 * than once the last one wins, as in the game, so that is the one that is read and changed.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_RCFILE_H
#define HK_RCFILE_H

#include <stddef.h>

typedef struct HkRc HkRc;

enum { HKRC_ABSENT = 0, HKRC_BOOL = 1, HKRC_VALUE = 2 };

HkRc *hkrc_parse(const char *text, size_t len);          /* NULL only if out of memory */
void  hkrc_free(HkRc *rc);
char *hkrc_text(const HkRc *rc, size_t *len);            /* the whole file again, malloc'd and NUL-terminated (free() it) */

/* Looks an option up (names compare without regard to case).  HKRC_BOOL: *value is "1" for "name" and "0" for "!name" (or
 * "~name"); HKRC_VALUE: *value is the text after "name:" (valid until the next call that changes rc).  value may be NULL. */
int  hkrc_find(const HkRc *rc, const char *name, const char **value);

/* Changes the last occurrence of the option in place, or adds an "OPTIONS=" line at the end of the file if there is none.
 * Return 0, or -1 if out of memory. */
int  hkrc_set_bool(HkRc *rc, const char *name, int on);
int  hkrc_set_value(HkRc *rc, const char *name, const char *value);
/* Removes every occurrence, so the game's own default applies again. */
int  hkrc_unset(HkRc *rc, const char *name);

#endif
