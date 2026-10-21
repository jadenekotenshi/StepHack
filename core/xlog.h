/*
 * xlog.h -- reads a game's log of finished games (the "xlogfile" NetHack 3.6 and several variants keep in the data
 * directory) and lays it out as a table.
 *
 * Each line is one game, a list of key=value fields separated by tabs (or, in some versions, colons):
 *     version=3.6.7  points=1234  deathdate=20261021  role=Val  race=Hum  name=Jade  death=killed by a jackal  turns=412 ...
 * Which keys exist varies between versions and variants, so a record is kept as its raw fields and the table asks for
 * what it needs; a missing field shows as blank.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_XLOG_H
#define HK_XLOG_H

#include <stddef.h>

typedef struct HkXlog HkXlog;

HkXlog *hkx_parse(const char *text, size_t len);        /* NULL only if out of memory */
void    hkx_free(HkXlog *x);
int     hkx_count(const HkXlog *x);                     /* games, oldest first (the order of the file) */
const char *hkx_get(const HkXlog *x, int rec, const char *key);     /* NULL if the game has no such field */

enum { HKX_RECENT = 0, HKX_BEST = 1 };
/* A table of at most max games as text, one per line under a heading: the latest first (HKX_RECENT) or the highest
 * score first (HKX_BEST).  malloc'd, NUL-terminated; free() it. */
char   *hkx_report(const HkXlog *x, int order, int max);

#endif
