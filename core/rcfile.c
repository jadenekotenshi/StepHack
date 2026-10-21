#include <stdlib.h>
#include <string.h>
#include "rcfile.h"

struct HkRc {
    char **line;            /* each line without its newline */
    size_t n, cap;
    int final_newline;      /* the text ended with a newline (or has been edited, which ends it with one) */
    char found[256];        /* what hkrc_find() last returned for a value */
};

/* ---- small helpers (no strdup/snprintf in C89 or on OPENSTEP's libc) ---- */

static char *dupn(const char *s, size_t n)
{
    char *p = (char *)malloc(n + 1);
    if (p) { memcpy(p, s, n); p[n] = '\0'; }
    return p;
}

static int is_space(int c) { return c == ' ' || c == '\t' || c == '\r'; }

static int lower(int c) { return (c >= 'A' && c <= 'Z') ? c + ('a' - 'A') : c; }

static int name_equal(const char *a, size_t alen, const char *b)
{
    size_t i;
    for (i = 0; i < alen; i++) {
        if (b[i] == '\0' || lower((unsigned char)a[i]) != lower((unsigned char)b[i])) return 0;
    }
    return b[alen] == '\0';
}

static int add_line(HkRc *rc, char *s)
{
    if (rc->n == rc->cap) {
        size_t nc = rc->cap ? rc->cap * 2 : 32;
        char **nl = (char **)realloc(rc->line, nc * sizeof(char *));
        if (!nl) { free(s); return -1; }
        rc->line = nl;
        rc->cap = nc;
    }
    rc->line[rc->n++] = s;
    return 0;
}

HkRc *hkrc_parse(const char *text, size_t len)
{
    HkRc *rc = (HkRc *)calloc(1, sizeof(HkRc));
    size_t i = 0;

    if (!rc) return NULL;
    rc->final_newline = 1;
    while (i < len) {
        size_t j = i;
        while (j < len && text[j] != '\n') j++;
        if (add_line(rc, dupn(text + i, j - i)) != 0 || !rc->line[rc->n - 1]) { hkrc_free(rc); return NULL; }
        if (j >= len) rc->final_newline = 0;                   /* the last line had no newline */
        i = j + 1;
    }
    return rc;
}

void hkrc_free(HkRc *rc)
{
    size_t i;
    if (!rc) return;
    for (i = 0; i < rc->n; i++) free(rc->line[i]);
    free(rc->line);
    free(rc);
}

char *hkrc_text(const HkRc *rc, size_t *len)
{
    size_t i, total = 0, at = 0;
    char *out;

    for (i = 0; i < rc->n; i++) total += strlen(rc->line[i]) + 1;
    out = (char *)malloc(total + 1);
    if (!out) return NULL;
    for (i = 0; i < rc->n; i++) {
        size_t l = strlen(rc->line[i]);
        memcpy(out + at, rc->line[i], l);
        at += l;
        if (i + 1 < rc->n || rc->final_newline) out[at++] = '\n';
    }
    out[at] = '\0';
    if (len) *len = at;
    return out;
}

/* ---- finding the options in a line ---- */

/* Where the options of this line start, or -1 if it isn't an options line.  "OPTIONS=" (any case, spaces allowed around
 * the =) starts them after the =; a line that starts with another KEYWORD=, a '#', or a '[' isn't one; anything else is
 * the bare form, which the game also accepts. */
static int payload_start(const char *line)
{
    size_t i = 0, k;

    while (is_space((unsigned char)line[i])) i++;
    if (line[i] == '\0' || line[i] == '#' || line[i] == '[') return -1;
    k = i;
    while ((line[k] >= 'A' && line[k] <= 'Z') || (line[k] >= 'a' && line[k] <= 'z') || line[k] == '_') k++;
    {
        size_t e = k;
        while (is_space((unsigned char)line[e])) e++;
        if (k > i && line[e] == '=') {
            if (k - i == 7 && name_equal(line + i, 7, "options")) return (int)(e + 1);
            return -1;                                          /* MSGTYPE=, MENUCOLOR=, SYMBOLS= ... */
        }
    }
    return (int)i;
}

typedef struct { size_t s, e; size_t nstart, nend; int neg; int has_value; size_t vstart; } Item;

/* Splits the payload of a line into items; returns how many (at most max). */
static int split_items(const char *line, int start, Item *it, int max)
{
    size_t i = (size_t)start;
    int n = 0;

    for (;;) {
        size_t s, e, j;
        while (is_space((unsigned char)line[i])) i++;
        s = i;
        while (line[i] != '\0' && line[i] != ',') i++;
        e = i;
        while (e > s && is_space((unsigned char)line[e - 1])) e--;
        if (e > s && n < max) {
            it[n].s = s;
            it[n].e = e;
            j = s;
            it[n].neg = 0;
            if (line[j] == '!' || line[j] == '~') { it[n].neg = 1; j++; }
            it[n].nstart = j;
            while (j < e && line[j] != ':' && line[j] != '=') j++;
            it[n].nend = j;
            it[n].has_value = (j < e);
            it[n].vstart = j < e ? j + 1 : e;
            n++;
        }
        if (line[i] == '\0') break;
        i++;                                                    /* past the comma */
    }
    return n;
}

#define MAX_ITEMS 64

/* The last occurrence of name, as (line, item); returns 1 if found. */
static int find_last(const HkRc *rc, const char *name, size_t *li, Item *found)
{
    size_t l;
    Item it[MAX_ITEMS];

    for (l = rc->n; l > 0; l--) {
        const char *line = rc->line[l - 1];
        int ps = payload_start(line), n, k;
        if (ps < 0) continue;
        n = split_items(line, ps, it, MAX_ITEMS);
        for (k = n - 1; k >= 0; k--) {
            if (name_equal(line + it[k].nstart, it[k].nend - it[k].nstart, name)) {
                *li = l - 1;
                *found = it[k];
                return 1;
            }
        }
    }
    return 0;
}

int hkrc_find(const HkRc *rc, const char *name, const char **value)
{
    size_t li;
    Item it;
    HkRc *w = (HkRc *)rc;                                       /* only the scratch buffer is written */

    if (!find_last(rc, name, &li, &it)) return HKRC_ABSENT;
    if (it.has_value) {
        size_t l = it.e - it.vstart;
        if (l >= sizeof(w->found)) l = sizeof(w->found) - 1;
        memcpy(w->found, rc->line[li] + it.vstart, l);
        w->found[l] = '\0';
        if (value) *value = w->found;
        return HKRC_VALUE;
    }
    if (value) *value = it.neg ? "0" : "1";
    return HKRC_BOOL;
}

/* ---- editing ---- */

static int replace_span(HkRc *rc, size_t li, size_t s, size_t e, const char *with)
{
    const char *old = rc->line[li];
    size_t ol = strlen(old), wl = strlen(with);
    char *n = (char *)malloc(ol - (e - s) + wl + 1);

    if (!n) return -1;
    memcpy(n, old, s);
    memcpy(n + s, with, wl);
    strcpy(n + s + wl, old + e);
    free(rc->line[li]);
    rc->line[li] = n;
    return 0;
}

static void delete_line(HkRc *rc, size_t li)
{
    free(rc->line[li]);
    memmove(&rc->line[li], &rc->line[li + 1], (rc->n - li - 1) * sizeof(char *));
    rc->n--;
}

/* Removes the item k of line li (and a comma beside it); drops the line if it was the only one. */
static int remove_item(HkRc *rc, size_t li, const Item *it, int k, int n)
{
    const char *line = rc->line[li];
    if (n == 1) { delete_line(rc, li); return 0; }
    if (k + 1 < n) return replace_span(rc, li, it[k].s, it[k + 1].s, "");     /* up to the next item */
    {
        size_t p = it[k - 1].e;                                 /* the last item: from the end of the one before */
        (void)line;
        return replace_span(rc, li, p, it[k].e, "");
    }
}

static int append_options_line(HkRc *rc, const char *item)
{
    size_t l = strlen(item);
    char *s = (char *)malloc(l + 9);

    if (!s) return -1;
    memcpy(s, "OPTIONS=", 8);
    memcpy(s + 8, item, l + 1);
    rc->final_newline = 1;
    return add_line(rc, s);
}

static int set_item(HkRc *rc, const char *name, const char *text)       /* text: the whole new item */
{
    size_t li;
    Item it;

    if (find_last(rc, name, &li, &it)) return replace_span(rc, li, it.s, it.e, text);
    return append_options_line(rc, text);
}

int hkrc_set_bool(HkRc *rc, const char *name, int on)
{
    size_t l = strlen(name);
    char *t = (char *)malloc(l + 2);
    int r;

    if (!t) return -1;
    t[0] = '\0';
    if (!on) strcpy(t, "!");
    strcat(t, name);
    r = set_item(rc, name, t);
    free(t);
    return r;
}

int hkrc_set_value(HkRc *rc, const char *name, const char *value)
{
    char *t = (char *)malloc(strlen(name) + strlen(value) + 2);
    int r;

    if (!t) return -1;
    strcpy(t, name);
    strcat(t, ":");
    strcat(t, value);
    r = set_item(rc, name, t);
    free(t);
    return r;
}

int hkrc_unset(HkRc *rc, const char *name)
{
    size_t li;
    Item it, items[MAX_ITEMS];

    while (find_last(rc, name, &li, &it)) {
        const char *line = rc->line[li];
        int ps = payload_start(line), n = split_items(line, ps, items, MAX_ITEMS), k;

        for (k = n - 1; k >= 0; k--)
            if (items[k].s == it.s) break;
        if (k < 0 || remove_item(rc, li, items, k, n) != 0) return -1;
    }
    return 0;
}
