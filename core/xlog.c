#include <stdlib.h>
#include <string.h>
#include <stdio.h>
#include "xlog.h"

typedef struct { char *key, *val; } Field;
typedef struct { Field *f; int n; } Rec;

struct HkXlog {
    char *buf;
    Rec *rec;
    int n, cap;
};

static int add_rec(HkXlog *x, const Rec *r)
{
    if (x->n == x->cap) {
        int nc = x->cap ? x->cap * 2 : 64;
        Rec *nr = (Rec *)realloc(x->rec, (size_t)nc * sizeof(Rec));
        if (!nr) return -1;
        x->rec = nr;
        x->cap = nc;
    }
    x->rec[x->n++] = *r;
    return 0;
}

/* Cuts one line (already NUL-terminated) into fields in place. */
static int parse_line(char *line, Rec *r)
{
    char sep;
    char *p = line;
    int cap = 0;

    r->f = NULL;
    r->n = 0;
    sep = strchr(line, '\t') ? '\t' : ':';
    while (*p) {
        char *start = p, *eq;
        while (*p && *p != sep) p++;
        if (*p) *p++ = '\0';
        eq = strchr(start, '=');
        if (!eq || eq == start) continue;
        *eq = '\0';
        if (r->n == cap) {
            Field *nf;
            cap = cap ? cap * 2 : 32;
            nf = (Field *)realloc(r->f, (size_t)cap * sizeof(Field));
            if (!nf) { free(r->f); r->f = NULL; r->n = 0; return -1; }
            r->f = nf;
        }
        r->f[r->n].key = start;
        r->f[r->n].val = eq + 1;
        r->n++;
    }
    return 0;
}

HkXlog *hkx_parse(const char *text, size_t len)
{
    HkXlog *x = (HkXlog *)calloc(1, sizeof(HkXlog));
    char *p, *end;

    if (!x) return NULL;
    x->buf = (char *)malloc(len + 1);
    if (!x->buf) { free(x); return NULL; }
    memcpy(x->buf, text, len);
    x->buf[len] = '\0';
    p = x->buf;
    end = x->buf + len;
    while (p < end) {
        char *line = p;
        Rec r;
        while (p < end && *p != '\n') p++;
        *p = '\0';
        if (p < end) p++;
        { size_t l = strlen(line); if (l && line[l - 1] == '\r') line[l - 1] = '\0'; }
        if (*line == '\0') continue;
        if (parse_line(line, &r) != 0) { hkx_free(x); return NULL; }
        if (r.n == 0) { free(r.f); continue; }                    /* not a record */
        if (add_rec(x, &r) != 0) { free(r.f); hkx_free(x); return NULL; }
    }
    return x;
}

void hkx_free(HkXlog *x)
{
    int i;
    if (!x) return;
    for (i = 0; i < x->n; i++) free(x->rec[i].f);
    free(x->rec);
    free(x->buf);
    free(x);
}

int hkx_count(const HkXlog *x) { return x->n; }

const char *hkx_get(const HkXlog *x, int rec, const char *key)
{
    int i;
    if (rec < 0 || rec >= x->n) return NULL;
    for (i = 0; i < x->rec[rec].n; i++)
        if (strcmp(x->rec[rec].f[i].key, key) == 0) return x->rec[rec].f[i].val;
    return NULL;
}

/* ---- the table ---- */

static const char *or_blank(const char *s) { return s ? s : ""; }

static long points_of(const HkXlog *x, int rec)
{
    const char *p = hkx_get(x, rec, "points");
    return p ? strtol(p, NULL, 10) : 0;
}

/* YYYYMMDD -> YYYY-MM-DD; anything else as it is (at most 10 characters). */
static void date_of(const HkXlog *x, int rec, char *out)
{
    const char *d = hkx_get(x, rec, "deathdate");
    if (!d) d = hkx_get(x, rec, "enddate");
    if (d && strlen(d) == 8) sprintf(out, "%.4s-%.2s-%.2s", d, d + 4, d + 6);
    else sprintf(out, "%.10s", or_blank(d));
}

/* One game as a line of at most about 330 characters (every field is cut to a fixed length). */
static void line_of(const HkXlog *x, int rec, char *out)
{
    char date[16];
    const char *role = hkx_get(x, rec, "role"), *race = hkx_get(x, rec, "race");
    const char *gender = hkx_get(x, rec, "gender"), *align = hkx_get(x, rec, "align");
    const char *dl = hkx_get(x, rec, "deathlev"), *ml = hkx_get(x, rec, "maxlvl");
    int n;

    date_of(x, rec, date);
    n = sprintf(out, "%-10s  %-12.12s  %.4s %.4s %.4s %.4s  %9ld  %6.8s  %.120s",
                date, or_blank(hkx_get(x, rec, "name")), or_blank(role), or_blank(race), or_blank(gender), or_blank(align),
                points_of(x, rec), or_blank(hkx_get(x, rec, "turns")), or_blank(hkx_get(x, rec, "death")));
    if (dl) {
        n += sprintf(out + n, "  (level %.6s", dl);
        if (ml) n += sprintf(out + n, ", deepest %.6s", ml);
        strcpy(out + n, ")");
    }
}

char *hkx_report(const HkXlog *x, int order, int max)
{
    int *idx = (int *)malloc((size_t)(x->n > 0 ? x->n : 1) * sizeof(int));
    int i, j;
    int shown = (max > 0 && max < x->n) ? max : x->n;
    size_t cap = 512 + (size_t)shown * 400, at = 0;
    char *out = (char *)malloc(cap);
    char line[400];

    if (!idx || !out) { free(idx); free(out); return NULL; }
    for (i = 0; i < x->n; i++) idx[i] = x->n - 1 - i;                 /* newest first */
    if (order == HKX_BEST) {                                          /* stable insertion sort, highest points first */
        for (i = 1; i < x->n; i++) {
            int v = idx[i];
            long pv = points_of(x, v);
            for (j = i - 1; j >= 0 && points_of(x, idx[j]) < pv; j--) idx[j + 1] = idx[j];
            idx[j + 1] = v;
        }
    }
    at += (size_t)sprintf(out + at, "%-10s  %-12s  %-19s  %9s  %6s  %s\n", "Date", "Name", "Character", "Points", "Turns", "Ended");
    for (i = 0; i < shown; i++) {
        line_of(x, idx[i], line);
        at += (size_t)sprintf(out + at, "%s\n", line);
    }
    if (x->n == 0) at += (size_t)sprintf(out + at, "(no games recorded)\n");
    free(idx);
    return out;
}
