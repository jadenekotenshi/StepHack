#include <stdlib.h>
#include <string.h>
#include "sysconf.h"

struct HkSysconf {
    char **line;
    size_t n, cap;
    int final_newline;
    char found[512];
};

static char *dupn(const char *s, size_t n)
{
    char *p = (char *)malloc(n + 1);
    if (p) { memcpy(p, s, n); p[n] = '\0'; }
    return p;
}

static int is_space(int c) { return c == ' ' || c == '\t' || c == '\r'; }

static int insert_line(HkSysconf *sc, size_t at, char *s)
{
    if (!s) return -1;
    if (sc->n == sc->cap) {
        size_t nc = sc->cap ? sc->cap * 2 : 64;
        char **nl = (char **)realloc(sc->line, nc * sizeof(char *));
        if (!nl) { free(s); return -1; }
        sc->line = nl;
        sc->cap = nc;
    }
    memmove(&sc->line[at + 1], &sc->line[at], (sc->n - at) * sizeof(char *));
    sc->line[at] = s;
    sc->n++;
    return 0;
}

HkSysconf *hksc_parse(const char *text, size_t len)
{
    HkSysconf *sc = (HkSysconf *)calloc(1, sizeof(HkSysconf));
    size_t i = 0;

    if (!sc) return NULL;
    sc->final_newline = 1;
    while (i < len) {
        size_t j = i;
        while (j < len && text[j] != '\n') j++;
        if (insert_line(sc, sc->n, dupn(text + i, j - i)) != 0) { hksc_free(sc); return NULL; }
        if (j >= len) sc->final_newline = 0;
        i = j + 1;
    }
    return sc;
}

void hksc_free(HkSysconf *sc)
{
    size_t i;
    if (!sc) return;
    for (i = 0; i < sc->n; i++) free(sc->line[i]);
    free(sc->line);
    free(sc);
}

char *hksc_text(const HkSysconf *sc, size_t *len)
{
    size_t i, total = 0, at = 0;
    char *out;

    for (i = 0; i < sc->n; i++) total += strlen(sc->line[i]) + 1;
    out = (char *)malloc(total + 1);
    if (!out) return NULL;
    for (i = 0; i < sc->n; i++) {
        size_t l = strlen(sc->line[i]);
        memcpy(out + at, sc->line[i], l);
        at += l;
        if (i + 1 < sc->n || sc->final_newline) out[at++] = '\n';
    }
    out[at] = '\0';
    if (len) *len = at;
    return out;
}

/* Does this line start with KEY= (after blanks), and, if commented is set, behind a '#' ("#KEY=")?  Returns the offset of the
 * value, or -1. */
static int key_value_at(const char *line, const char *key, int commented)
{
    size_t i = 0, k = strlen(key);

    while (is_space((unsigned char)line[i])) i++;
    if (commented) {
        if (line[i] != '#') return -1;
        i++;
        while (is_space((unsigned char)line[i])) i++;
    }
    if (strncmp(line + i, key, k) != 0) return -1;
    i += k;
    while (is_space((unsigned char)line[i])) i++;
    if (line[i] != '=') return -1;
    return (int)(i + 1);
}

const char *hksc_get(const HkSysconf *sc, const char *key)
{
    size_t l;
    HkSysconf *w = (HkSysconf *)sc;

    for (l = sc->n; l > 0; l--) {
        int v = key_value_at(sc->line[l - 1], key, 0);
        if (v >= 0) {
            const char *val = sc->line[l - 1] + v;
            size_t len;
            while (is_space((unsigned char)*val)) val++;
            len = strlen(val);
            while (len > 0 && is_space((unsigned char)val[len - 1])) len--;
            if (len >= sizeof(w->found)) len = sizeof(w->found) - 1;
            memcpy(w->found, val, len);
            w->found[len] = '\0';
            return w->found;
        }
    }
    return NULL;
}

int hksc_set(HkSysconf *sc, const char *key, const char *value)
{
    size_t l, kl = strlen(key), vl = strlen(value);
    char *nl;

    nl = (char *)malloc(kl + vl + 2);
    if (!nl) return -1;
    memcpy(nl, key, kl);
    nl[kl] = '=';
    memcpy(nl + kl + 1, value, vl + 1);

    for (l = sc->n; l > 0; l--) {                              /* the last active line is the one that counts */
        if (key_value_at(sc->line[l - 1], key, 0) >= 0) {
            free(sc->line[l - 1]);
            sc->line[l - 1] = nl;
            return 0;
        }
    }
    for (l = 0; l < sc->n; l++) {                              /* else just after a commented-out example */
        if (key_value_at(sc->line[l], key, 1) >= 0) {
            if (insert_line(sc, l + 1, nl) != 0) return -1;
            return 0;
        }
    }
    sc->final_newline = 1;
    return insert_line(sc, sc->n, nl);                         /* else at the end */
}

int hksc_unset(HkSysconf *sc, const char *key)
{
    size_t l;
    for (l = sc->n; l > 0; l--) {
        if (key_value_at(sc->line[l - 1], key, 0) >= 0) {
            free(sc->line[l - 1]);
            memmove(&sc->line[l - 1], &sc->line[l], (sc->n - l) * sizeof(char *));
            sc->n--;
        }
    }
    return 0;
}

static const HkSysconfKey KEYS[] = {
    { "WIZARDS",   "Wizard mode",   "Users allowed to start the game in wizard mode (-D), separated by spaces; * allows everyone, empty nobody", HKSC_TEXT },
    { "EXPLORERS", "Explore mode",  "Users allowed to start the game in explore mode (-X); * allows everyone", HKSC_TEXT },
    { "SHELLERS",  "Shell escape",  "Users allowed the ! and Ctrl-Z commands, which reach a shell; empty means nobody", HKSC_TEXT },
    { "MAXPLAYERS","Games at once", "Most games that may run at the same time (0: no limit)", HKSC_INT },
    { "SEDUCE",    "Seduction",     "Incubi and succubi try to seduce you (the dangerous kind of foe; off makes them ordinary monsters)", HKSC_BOOL },
    { "DUMPLOGFILE","Dump file",    "Where the game writes a text dump of the character when it ends (%n is the name, %d the time)", HKSC_TEXT }
};

int hksc_key_count(void) { return (int)(sizeof(KEYS) / sizeof(KEYS[0])); }

const HkSysconfKey *hksc_key(int index)
{
    return (index >= 0 && index < hksc_key_count()) ? &KEYS[index] : NULL;
}
