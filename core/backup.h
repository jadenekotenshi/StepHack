/*
 * backup.h -- names and ages of dated backup copies of a file: base.old.ddMMMyyyy.hhmm[.gz] ("sysconf.old.22Oct2026.1435.gz").
 *
 * The date is in the name, so how old a backup is does not depend on file times (which a copy resets).  Dates are
 * proleptic Gregorian, times are 24-hour, and the month abbreviations are always the English ones, whatever the locale.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_BACKUP_H
#define HK_BACKUP_H

#include <stddef.h>

/* "base.old.ddMMMyyyy.hhmm" into out (size bytes at least strlen(base) + 24); the caller adds ".gz" if it compresses it. */
void hkb_name(char *out, size_t size, const char *base, int year, int month, int day, int hour, int minute);
/* The date and time of a name made by hkb_name for this base, with or without a trailing ".gz": 1 and the fields, or 0 if the
 * name is anything else.  Any of the output pointers may be NULL. */
int  hkb_parse(const char *name, const char *base, int *year, int *month, int *day, int *hour, int *minute);
/* Days since 1970-01-01 (negative before), and back. */
long hkb_days(int year, int month, int day);
void hkb_civil(long days, int *year, int *month, int *day);

#endif
