/*
 * schema.h -- the list of options a game has, for the options window.
 *
 * A schema is a text file of tab-separated lines (see schemas/):
 *
 *     game  <id>   <title>
 *     group <title>
 *     bool  <name> <default 0|1>  <label>
 *     enum  <name> <default>      <label>  <choice>|<choice>...      a choice is "value=label" or just "value"
 *     int   <name> <default>      <label>  <min>..<max>
 *     text  <name> <default>      <label>
 *
 * hks_effective() and hks_apply() connect a schema to a run-commands file (core/rcfile.h): what the window should show for
 * an option, and what to write when it is changed.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_SCHEMA_H
#define HK_SCHEMA_H

#include <stddef.h>
#include "rcfile.h"

enum { HKS_GROUP = 0, HKS_BOOL, HKS_ENUM, HKS_INT, HKS_TEXT };

typedef struct {
    int         kind;
    const char *name;        /* GROUP: the group's title */
    const char *def;
    const char *label;
    const char *extra;       /* ENUM: the choices; INT: "min..max" */
} HkSchemaItem;

typedef struct HkSchema HkSchema;

HkSchema *hks_parse(const char *text);                 /* NULL if out of memory or there is no "game" line */
void      hks_free(HkSchema *s);
const char *hks_id(const HkSchema *s);
const char *hks_title(const HkSchema *s);
int       hks_count(const HkSchema *s);                /* items, groups included, in file order */
const HkSchemaItem *hks_item(const HkSchema *s, int i);

/* The text of a schema built into the program ("nethack367", "slashem"): malloc'd, free() it; NULL if there is none. */
char *hks_builtin(const char *id);

/* ENUM choices: fills value and label (NUL-terminated, cut to the sizes given) for choice i; returns 0 past the last. */
int       hks_choice(const HkSchemaItem *it, int i, char *value, int vsize, char *label, int lsize);
int       hks_choice_index(const HkSchemaItem *it, const char *value);       /* case-blind; -1 if not a choice */
int       hks_int_range(const HkSchemaItem *it, int *lo, int *hi);

/* What the window should show for an item: the file's setting if it has one, else the default.  Booleans give "1" or "0". */
void      hks_effective(const HkRc *rc, const HkSchemaItem *it, char *out, int size);
/* True if the file sets the option itself. */
int       hks_is_set(const HkRc *rc, const HkSchemaItem *it);
/* Makes the file say value (booleans "1"/"0"; an integer is clamped to its range).  A value equal to the default, or an empty
 * one, removes the option from the file instead -- unless always_write is set, for options whose default the front end
 * itself changes.  Returns 0, or -1 if out of memory. */
int       hks_apply(HkRc *rc, const HkSchemaItem *it, const char *value, int always_write);

#endif
