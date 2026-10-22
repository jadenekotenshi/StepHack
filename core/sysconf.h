/*
 * sysconf.h -- reads and edits a game's system configuration file ("sysconf" in its data directory: NetHack 3.6 and later,
 * and the variants built on them).
 *
 * The file is lines of KEY=value (upper-case keys), with # comments.  Like core/rcfile.h this keeps every line as it was
 * and changes only the key asked for, so the comments that explain each setting survive.  An edit of a key that is only
 * present as a commented-out example ("#WIZARDS=root") puts the real line just after the example.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_SYSCONF_H
#define HK_SYSCONF_H

#include <stddef.h>

typedef struct HkSysconf HkSysconf;

HkSysconf  *hksc_parse(const char *text, size_t len);        /* NULL only if out of memory */
void        hksc_free(HkSysconf *sc);
char       *hksc_text(const HkSysconf *sc, size_t *len);     /* the file again, malloc'd and NUL-terminated (free() it) */

/* The value of an active KEY=value line (the last, if there are several), or NULL.  Valid until the next change. */
const char *hksc_get(const HkSysconf *sc, const char *key);
int         hksc_set(HkSysconf *sc, const char *key, const char *value);      /* 0, or -1 if out of memory */
int         hksc_unset(HkSysconf *sc, const char *key);                        /* removes the active lines; comments stay */

/* The settings the dialog offers. */
enum { HKSC_TEXT = 0, HKSC_INT, HKSC_BOOL };
typedef struct {
    const char *key;
    const char *label;
    const char *help;
    int         kind;
} HkSysconfKey;

int                 hksc_key_count(void);
const HkSysconfKey *hksc_key(int index);

#endif
