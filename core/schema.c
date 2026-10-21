#include <stdlib.h>
#include <string.h>
#include "schema.h"

struct HkSchema {
    char *buf;               /* the text, cut into fields in place */
    HkSchemaItem *item;
    int n, cap;
    const char *id, *title;
    int explicit_defaults;
};

static const char EMPTY[] = "";

static int lower(int c) { return (c >= 'A' && c <= 'Z') ? c + ('a' - 'A') : c; }

static int equal_nocase(const char *a, const char *b)
{
    while (*a && *b) {
        if (lower((unsigned char)*a) != lower((unsigned char)*b)) return 0;
        a++; b++;
    }
    return *a == *b;
}

static int add_item(HkSchema *s, const HkSchemaItem *it)
{
    if (s->n == s->cap) {
        int nc = s->cap ? s->cap * 2 : 64;
        HkSchemaItem *ni = (HkSchemaItem *)realloc(s->item, (size_t)nc * sizeof(HkSchemaItem));
        if (!ni) return -1;
        s->item = ni;
        s->cap = nc;
    }
    s->item[s->n++] = *it;
    return 0;
}

HkSchema *hks_parse(const char *text)
{
    HkSchema *s = (HkSchema *)calloc(1, sizeof(HkSchema));
    char *p;

    if (!s) return NULL;
    s->buf = (char *)malloc(strlen(text) + 1);
    if (!s->buf) { free(s); return NULL; }
    strcpy(s->buf, text);
    p = s->buf;
    while (*p) {
        char *line = p, *f[5];
        int nf = 0, k;
        HkSchemaItem it;

        while (*p && *p != '\n') p++;
        if (*p) *p++ = '\0';
        if (*line == '#' || *line == '\0') continue;
        for (k = 0; k < 5; k++) f[k] = (char *)EMPTY;
        f[nf++] = line;
        for (; *line && nf < 5; line++)
            if (*line == '\t') { *line = '\0'; f[nf++] = line + 1; }
        for (; *line; line++)                                      /* a stray extra tab stays in the last field */
            if (*line == '\t') *line = ' ';
        if (strcmp(f[0], "game") == 0) { s->id = f[1]; s->title = f[2]; s->explicit_defaults = (strcmp(f[3], "explicit") == 0); continue; }
        it.def = f[2];
        it.label = f[3];
        it.extra = f[4];
        it.name = f[1];
        if (strcmp(f[0], "group") == 0) it.kind = HKS_GROUP;
        else if (strcmp(f[0], "bool") == 0) it.kind = HKS_BOOL;
        else if (strcmp(f[0], "enum") == 0) it.kind = HKS_ENUM;
        else if (strcmp(f[0], "int") == 0) it.kind = HKS_INT;
        else if (strcmp(f[0], "text") == 0) it.kind = HKS_TEXT;
        else continue;                                             /* an unknown line type is skipped */
        if (it.kind != HKS_GROUP && it.name[0] == '\0') continue;
        if (add_item(s, &it) != 0) { hks_free(s); return NULL; }
    }
    if (!s->id) { hks_free(s); return NULL; }
    return s;
}

void hks_free(HkSchema *s)
{
    if (!s) return;
    free(s->buf);
    free(s->item);
    free(s);
}

const char *hks_id(const HkSchema *s) { return s->id; }
const char *hks_title(const HkSchema *s) { return s->title; }
int hks_explicit(const HkSchema *s) { return s->explicit_defaults; }
int hks_count(const HkSchema *s) { return s->n; }

const HkSchemaItem *hks_item(const HkSchema *s, int i)
{
    return (i >= 0 && i < s->n) ? &s->item[i] : NULL;
}

/* ---- choices and ranges ---- */

int hks_choice(const HkSchemaItem *it, int i, char *value, int vsize, char *label, int lsize)
{
    const char *p = it->extra, *end, *eq;
    int k;

    if (it->kind != HKS_ENUM || i < 0 || it->extra[0] == '\0') return 0;
    for (k = 0; k < i; k++) {
        p = strchr(p, '|');
        if (!p) return 0;
        p++;
    }
    if (*p == '\0' && i > 0) return 0;
    end = strchr(p, '|');
    if (!end) end = p + strlen(p);
    eq = p;
    while (eq < end && *eq != '=') eq++;
    {
        size_t vl = (size_t)(eq - p), ll = (eq < end) ? (size_t)(end - eq - 1) : 0;
        const char *ls = (eq < end) ? eq + 1 : p;
        if (eq >= end) ll = vl;
        if ((int)vl >= vsize) vl = (size_t)(vsize - 1);
        if ((int)ll >= lsize) ll = (size_t)(lsize - 1);
        memcpy(value, p, vl);
        value[vl] = '\0';
        memcpy(label, ls, ll);
        label[ll] = '\0';
    }
    return 1;
}

int hks_choice_index(const HkSchemaItem *it, const char *value)
{
    char v[64], l[128];
    int i;
    for (i = 0; hks_choice(it, i, v, sizeof(v), l, sizeof(l)); i++)
        if (equal_nocase(v, value)) return i;
    return -1;
}

int hks_int_range(const HkSchemaItem *it, int *lo, int *hi)
{
    const char *p = it->extra;
    char *e;
    long a, b;

    if (it->kind != HKS_INT) return 0;
    a = strtol(p, &e, 10);
    if (e == p || e[0] != '.' || e[1] != '.') return 0;
    b = strtol(e + 2, &e, 10);
    *lo = (int)a;
    *hi = (int)b;
    return 1;
}

/* ---- the file side ---- */

void hks_effective(const HkRc *rc, const HkSchemaItem *it, char *out, int size)
{
    const char *v = NULL;
    int found = hkrc_find(rc, it->name, &v);
    const char *src = it->def;

    if (it->kind == HKS_BOOL) {
        if (found == HKRC_BOOL && v) src = v;
        else if (found == HKRC_VALUE && v) src = (v[0] == '0' || v[0] == 'f' || v[0] == 'F' || v[0] == 'n' || v[0] == 'N') ? "0" : "1";
    } else if (found == HKRC_VALUE && v) {
        src = v;
    }
    if (size <= 0) return;
    strncpy(out, src, (size_t)size - 1);
    out[size - 1] = '\0';
}

int hks_is_set(const HkRc *rc, const HkSchemaItem *it)
{
    return hkrc_find(rc, it->name, NULL) != HKRC_ABSENT;
}

int hks_apply(HkRc *rc, const HkSchemaItem *it, const char *value, int always_write)
{
    char tmp[32];

    if (it->kind == HKS_BOOL) {
        int on = (value[0] == '1');
        if (!always_write && on == (it->def[0] == '1')) return hkrc_unset(rc, it->name);
        return hkrc_set_bool(rc, it->name, on);
    }
    if (it->kind == HKS_INT) {
        int lo, hi;
        long v = strtol(value, NULL, 10);
        if (value[0] == '\0') return hkrc_unset(rc, it->name);
        if (hks_int_range(it, &lo, &hi)) { if (v < lo) v = lo; if (v > hi) v = hi; }
        {   /* itoa by hand */
            int i = 0, j;
            char r[24];
            unsigned long u = (v < 0) ? (unsigned long)(-v) : (unsigned long)v;
            do { r[i++] = (char)('0' + u % 10); u /= 10; } while (u);
            j = 0;
            if (v < 0) tmp[j++] = '-';
            while (i) tmp[j++] = r[--i];
            tmp[j] = '\0';
        }
        value = tmp;
    }
    if (value[0] == '\0' || (!always_write && equal_nocase(value, it->def))) return hkrc_unset(rc, it->name);
    return hkrc_set_value(rc, it->name, value);
}
