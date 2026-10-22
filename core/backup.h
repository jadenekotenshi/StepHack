/*
 * backup.h -- names and ages of dated backup copies of a file: base.old.ddMMMyyyy ("sysconf.old.22Oct2026").
 *
 * The date is in the name, so how old a backup is does not depend on file times (which a copy resets).  Dates are
 * proleptic Gregorian; the month abbreviations are always the English ones, whatever the locale.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_BACKUP_H
#define HK_BACKUP_H

#include <stddef.h>

/* "base.old.ddMMMyyyy" into out (size bytes at least strlen(base) + 16). */
void hkb_name(char *out, size_t size, const char *base, int year, int month, int day);
/* The date of a name made by hkb_name for this base: 1 and the date, or 0 if the name is anything else. */
int  hkb_parse(const char *name, const char *base, int *year, int *month, int *day);
/* Days since 1970-01-01 (negative before), and back. */
long hkb_days(int year, int month, int day);
void hkb_civil(long days, int *year, int *month, int *day);

#endif
