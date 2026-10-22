#include <stdio.h>
#include <string.h>
#include "backup.h"

static const char *const MONTHS[12] = { "Jan", "Feb", "Mar", "Apr", "May", "Jun", "Jul", "Aug", "Sep", "Oct", "Nov", "Dec" };

void hkb_name(char *out, size_t size, const char *base, int year, int month, int day, int hour, int minute)
{
    char tmp[256];
    if (month < 1 || month > 12) month = 1;
    sprintf(tmp, "%.150s.old.%02d%s%04d.%02d%02d", base, day % 100, MONTHS[month - 1], year % 10000, hour % 100, minute % 100);
    strncpy(out, tmp, size - 1);
    out[size - 1] = '\0';
}

static int digit(char c) { return c >= '0' && c <= '9'; }

int hkb_parse(const char *name, const char *base, int *year, int *month, int *day, int *hour, int *minute)
{
    size_t bl = strlen(base), len;
    const char *p;
    int d, y, m, hh, mm, i;

    if (strncmp(name, base, bl) != 0 || strncmp(name + bl, ".old.", 5) != 0) return 0;
    p = name + bl + 5;
    len = strlen(p);
    if (len == 17 && strcmp(p + 14, ".gz") != 0) return 0;          /* ddMMMyyyy.hhmm is 14 characters, then maybe ".gz" */
    if (len != 14 && len != 17) return 0;
    if (!digit(p[0]) || !digit(p[1])) return 0;
    d = (p[0] - '0') * 10 + (p[1] - '0');
    for (m = 0; m < 12; m++) if (strncmp(p + 2, MONTHS[m], 3) == 0) break;
    if (m == 12) return 0;
    y = 0;
    for (i = 5; i < 9; i++) {
        if (!digit(p[i])) return 0;
        y = y * 10 + (p[i] - '0');
    }
    if (p[9] != '.' || !digit(p[10]) || !digit(p[11]) || !digit(p[12]) || !digit(p[13])) return 0;
    hh = (p[10] - '0') * 10 + (p[11] - '0');
    mm = (p[12] - '0') * 10 + (p[13] - '0');
    if (d < 1 || d > 31 || hh > 23 || mm > 59) return 0;
    if (year) *year = y;
    if (month) *month = m + 1;
    if (day) *day = d;
    if (hour) *hour = hh;
    if (minute) *minute = mm;
    return 1;
}

/* Howard Hinnant's civil-date algorithms. */
long hkb_days(int year, int month, int day)
{
    long y = year - (month <= 2);
    long era = (y >= 0 ? y : y - 399) / 400;
    long yoe = y - era * 400;
    long doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1;
    long doe = yoe * 365 + yoe / 4 - yoe / 100 + doy;
    return era * 146097 + doe - 719468;
}

void hkb_civil(long days, int *year, int *month, int *day)
{
    long z = days + 719468;
    long era = (z >= 0 ? z : z - 146096) / 146097;
    long doe = z - era * 146097;
    long yoe = (doe - doe / 1460 + doe / 36524 - doe / 146096) / 365;
    long y = yoe + era * 400;
    long doy = doe - (365 * yoe + yoe / 4 - yoe / 100);
    long mp = (5 * doy + 2) / 153;
    long d = doy - (153 * mp + 2) / 5 + 1;
    long m = mp + (mp < 10 ? 3 : -9);
    *year = (int)(y + (m <= 2));
    *month = (int)m;
    *day = (int)d;
}
