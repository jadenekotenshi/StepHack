#include <stdlib.h>
#include <string.h>
#include "test.h"
#include "vt.h"
#include "keymap.h"
#include "rcfile.h"
#include "games.h"
#include "schema.h"
#include "xlog.h"
#include "commands.h"

static int bytes_are(const unsigned char *got, int n, const char *want)
{
    return (size_t)n == strlen(want) && memcmp(got, want, (size_t)n) == 0;
}

static void test_keymap(void)
{
    unsigned char o[8];
    int n;

    /* digits (number_pad:1) */
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_UP, 0, o);    CHECK(bytes_are(o, n, "8"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_DOWN, 0, o);  CHECK(bytes_are(o, n, "2"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_LEFT, 0, o);  CHECK(bytes_are(o, n, "4"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_RIGHT, 0, o); CHECK(bytes_are(o, n, "6"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_HOME, 0, o);  CHECK(bytes_are(o, n, "7"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_PGUP, 0, o);  CHECK(bytes_are(o, n, "9"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_END, 0, o);   CHECK(bytes_are(o, n, "1"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_PGDN, 0, o);  CHECK(bytes_are(o, n, "3"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_UP, VT_MOD_SHIFT, o);    CHECK(bytes_are(o, n, "G8"));
    n = hk_map_key(HK_PAD_DIGITS, VT_KEY_PGDN, VT_MOD_SHIFT, o);  CHECK(bytes_are(o, n, "G3"));
    /* vi keys */
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_UP, 0, o);    CHECK(bytes_are(o, n, "k"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_DOWN, 0, o);  CHECK(bytes_are(o, n, "j"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_LEFT, 0, o);  CHECK(bytes_are(o, n, "h"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_RIGHT, 0, o); CHECK(bytes_are(o, n, "l"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_HOME, 0, o);  CHECK(bytes_are(o, n, "y"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_PGUP, 0, o);  CHECK(bytes_are(o, n, "u"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_END, 0, o);   CHECK(bytes_are(o, n, "b"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_PGDN, 0, o);  CHECK(bytes_are(o, n, "n"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_LEFT, VT_MOD_SHIFT, o);  CHECK(bytes_are(o, n, "H"));
    n = hk_map_key(HK_PAD_LETTERS, VT_KEY_HOME, VT_MOD_SHIFT, o);  CHECK(bytes_are(o, n, "Y"));
    /* the other layouts */
    n = hk_map_key(HK_PAD_PHONE, VT_KEY_UP, 0, o);      CHECK(bytes_are(o, n, "2"));
    n = hk_map_key(HK_PAD_PHONE, VT_KEY_DOWN, 0, o);    CHECK(bytes_are(o, n, "8"));
    n = hk_map_key(HK_PAD_PHONE, VT_KEY_HOME, 0, o);    CHECK(bytes_are(o, n, "1"));
    n = hk_map_key(HK_PAD_PHONE, VT_KEY_END, 0, o);     CHECK(bytes_are(o, n, "7"));
    n = hk_map_key(HK_PAD_LETTERS_QWERTZ, VT_KEY_HOME, 0, o);                CHECK(bytes_are(o, n, "z"));
    n = hk_map_key(HK_PAD_LETTERS_QWERTZ, VT_KEY_HOME, VT_MOD_SHIFT, o);     CHECK(bytes_are(o, n, "Z"));
    /* anything else is left to the terminal */
    CHECK(hk_map_key(HK_PAD_DIGITS, VT_KEY_INSERT, 0, o) == 0);
    CHECK(hk_map_key(HK_PAD_DIGITS, VT_KEY_F1, 0, o) == 0);
    CHECK(hk_map_key(HK_PAD_DIGITS, VT_KEY_DELETE, VT_MOD_SHIFT, o) == 0);
    CHECK(hk_map_key(HK_PAD_DIGITS, 0, 0, o) == 0);
    CHECK(hk_move_bytes(HK_PAD_DIGITS, 8, 0, o) == 0 && hk_move_bytes(HK_PAD_DIGITS, -1, 0, o) == 0);
    /* number_pad values */
    CHECK(hk_pad_mode(0) == HK_PAD_LETTERS && hk_pad_mode(1) == HK_PAD_DIGITS && hk_pad_mode(2) == HK_PAD_DIGITS);
    CHECK(hk_pad_mode(3) == HK_PAD_PHONE && hk_pad_mode(4) == HK_PAD_DIGITS && hk_pad_mode(-1) == HK_PAD_LETTERS_QWERTZ);
    CHECK(hk_pad_mode(99) == HK_PAD_LETTERS);
}

static char *render(HkRc *rc)
{
    size_t len;
    char *s = hkrc_text(rc, &len);
    CHECK(s != NULL && strlen(s) == len);
    return s;
}

static void roundtrip(const char *text)
{
    HkRc *rc = hkrc_parse(text, strlen(text));
    char *s;
    CHECK(rc != NULL);
    s = render(rc);
    CHECK(s && strcmp(s, text) == 0);
    free(s);
    hkrc_free(rc);
}

static void test_rc_read(void)
{
    const char *text =
        "# my config\n"
        "OPTIONS=number_pad:1, !autopickup,color\n"
        "  options = Time , hilite_pet\n"
        "MSGTYPE=hide \"You swap places\"\n"
        "pettype:cat\n"
        "[section]\n"
        "OPTIONS=fruit:kumquat\n"
        "OPTIONS=number_pad:2\n";
    HkRc *rc = hkrc_parse(text, strlen(text));
    const char *v;

    CHECK(rc != NULL);
    CHECK(hkrc_find(rc, "number_pad", &v) == HKRC_VALUE && strcmp(v, "2") == 0);       /* the last one wins */
    CHECK(hkrc_find(rc, "NUMBER_PAD", NULL) == HKRC_VALUE);                              /* case-blind */
    CHECK(hkrc_find(rc, "autopickup", &v) == HKRC_BOOL && strcmp(v, "0") == 0);
    CHECK(hkrc_find(rc, "color", &v) == HKRC_BOOL && strcmp(v, "1") == 0);
    CHECK(hkrc_find(rc, "time", &v) == HKRC_BOOL && strcmp(v, "1") == 0);                /* lower-case "options =" */
    CHECK(hkrc_find(rc, "hilite_pet", NULL) == HKRC_BOOL);
    CHECK(hkrc_find(rc, "pettype", &v) == HKRC_VALUE && strcmp(v, "cat") == 0);          /* the bare form */
    CHECK(hkrc_find(rc, "fruit", &v) == HKRC_VALUE && strcmp(v, "kumquat") == 0);
    CHECK(hkrc_find(rc, "MSGTYPE", NULL) == HKRC_ABSENT);                                /* other directives aren't options */
    CHECK(hkrc_find(rc, "hide", NULL) == HKRC_ABSENT);
    CHECK(hkrc_find(rc, "section", NULL) == HKRC_ABSENT);
    CHECK(hkrc_find(rc, "nothing", NULL) == HKRC_ABSENT);
    hkrc_free(rc);

    roundtrip(text);
    roundtrip("");
    roundtrip("\n");
    roundtrip("no newline at the end");
    roundtrip("a\r\nb\r\n");
    roundtrip("\n\n# x\n\n");
}

static void check_edit(const char *before, int (*edit)(HkRc *), const char *after)
{
    HkRc *rc = hkrc_parse(before, strlen(before));
    char *s;
    CHECK(rc != NULL && edit(rc) == 0);
    s = render(rc);
    if (!(s && strcmp(s, after) == 0)) printf("  got:  [%s]\n  want: [%s]\n", s ? s : "(null)", after);
    CHECK(s && strcmp(s, after) == 0);
    free(s);
    hkrc_free(rc);
}

static int e_pad_on(HkRc *rc)        { return hkrc_set_value(rc, "number_pad", "1"); }
static int e_pad_off_bool(HkRc *rc)  { return hkrc_set_bool(rc, "autopickup", 0); }
static int e_pick_on(HkRc *rc)       { return hkrc_set_bool(rc, "autopickup", 1); }
static int e_unset_a(HkRc *rc)       { return hkrc_unset(rc, "a"); }
static int e_unset_b(HkRc *rc)       { return hkrc_unset(rc, "b"); }
static int e_unset_c(HkRc *rc)       { return hkrc_unset(rc, "c"); }
static int e_unset_x(HkRc *rc)       { return hkrc_unset(rc, "x"); }
static int e_set_pettype(HkRc *rc)   { return hkrc_set_value(rc, "pettype", "dog"); }

static void test_rc_edit(void)
{
    /* in place, the rest untouched */
    check_edit("# hi\nOPTIONS=color, number_pad:0 ,time\nMSGTYPE=hide \"x\"\n", e_pad_on,
               "# hi\nOPTIONS=color, number_pad:1 ,time\nMSGTYPE=hide \"x\"\n");
    /* only the last of several is changed */
    check_edit("OPTIONS=number_pad:0\nOPTIONS=number_pad:2\n", e_pad_on, "OPTIONS=number_pad:0\nOPTIONS=number_pad:1\n");
    /* booleans */
    check_edit("OPTIONS=autopickup,color\n", e_pad_off_bool, "OPTIONS=!autopickup,color\n");
    check_edit("OPTIONS=!autopickup,color\n", e_pick_on, "OPTIONS=autopickup,color\n");
    check_edit("OPTIONS=~autopickup\n", e_pick_on, "OPTIONS=autopickup\n");
    /* absent: appended as a new line, with a newline supplied if the file lacked one */
    check_edit("OPTIONS=color\n", e_pad_on, "OPTIONS=color\nOPTIONS=number_pad:1\n");
    check_edit("OPTIONS=color", e_pad_on, "OPTIONS=color\nOPTIONS=number_pad:1\n");
    check_edit("", e_pad_on, "OPTIONS=number_pad:1\n");
    /* a bare line */
    check_edit("pettype:cat\n", e_set_pettype, "pettype:dog\n");
    /* removal: first, middle, last, only item, all copies */
    check_edit("OPTIONS=a,b,c\n", e_unset_a, "OPTIONS=b,c\n");
    check_edit("OPTIONS=a, b, c\n", e_unset_b, "OPTIONS=a, c\n");
    check_edit("OPTIONS=a,b,c\n", e_unset_c, "OPTIONS=a,b\n");
    check_edit("# x\nOPTIONS=a\nOPTIONS=b\n", e_unset_a, "# x\nOPTIONS=b\n");
    check_edit("OPTIONS=a:1,b\nOPTIONS=c,a:2\n# end\n", e_unset_a, "OPTIONS=b\nOPTIONS=c\n# end\n");
    check_edit("OPTIONS=a\n", e_unset_x, "OPTIONS=a\n");                       /* nothing to remove */
    /* names that merely start the same are left alone */
    check_edit("OPTIONS=number_pad:0,number\n", e_pad_on, "OPTIONS=number_pad:1,number\n");
}

static void test_rc_robust(void)
{
    char big[4096];
    int i;
    HkRc *rc;
    const char *v;

    /* a line with more items than the scanner keeps does not crash, and the early ones still work */
    strcpy(big, "OPTIONS=first");
    for (i = 0; i < 200; i++) strcat(big, ",o");
    rc = hkrc_parse(big, strlen(big));
    CHECK(rc != NULL && hkrc_find(rc, "first", &v) == HKRC_BOOL);
    CHECK(hkrc_set_bool(rc, "first", 0) == 0 && hkrc_find(rc, "first", &v) == HKRC_BOOL && strcmp(v, "0") == 0);
    hkrc_free(rc);

    /* odd text is tolerated */
    {
        const char *odd[] = { "OPTIONS=", "OPTIONS", "=", ",,,", "OPTIONS=,", "!", ":", "OPTIONS=:x", "  ", "\t\n\t" };
        for (i = 0; i < (int)(sizeof(odd) / sizeof(odd[0])); i++) {
            rc = hkrc_parse(odd[i], strlen(odd[i]));
            CHECK(rc != NULL);
            (void)hkrc_find(rc, "x", NULL);
            CHECK(hkrc_set_value(rc, "x", "1") == 0 && hkrc_find(rc, "x", &v) == HKRC_VALUE && strcmp(v, "1") == 0);
            CHECK(hkrc_unset(rc, "x") == 0 && hkrc_find(rc, "x", NULL) == HKRC_ABSENT);
            hkrc_free(rc);
        }
    }
    /* a long value is cut to the scratch buffer rather than overflowing it */
    {
        char *t = (char *)malloc(1000);
        memset(t, 'v', 999); t[999] = '\0';
        strcpy(big, "OPTIONS=fruit:");
        strcat(big, t);
        free(t);
        rc = hkrc_parse(big, strlen(big));
        CHECK(hkrc_find(rc, "fruit", &v) == HKRC_VALUE && strlen(v) == 255);
        hkrc_free(rc);
    }
}

static void test_schema(void)
{
    const char *ids[] = { "nethack367", "slashem" };
    int g, i, j;

    for (g = 0; g < 2; g++) {
        char *text = hks_builtin(ids[g]);
        HkSchema *s;
        int groups = 0, opts = 0;
        CHECK(text != NULL);
        s = hks_parse(text);
        free(text);
        CHECK(s != NULL && strcmp(hks_id(s), ids[g]) == 0 && hks_title(s)[0] != '\0');
        if (!s) continue;
        for (i = 0; i < hks_count(s); i++) {
            const HkSchemaItem *it = hks_item(s, i);
            char v[64], l[128];
            int lo, hi;
            if (it->kind == HKS_GROUP) { groups++; CHECK(it->name[0] != '\0'); continue; }
            opts++;
            CHECK(it->name[0] != '\0' && it->label[0] != '\0');
            for (j = 0; j < i; j++)                                    /* no option listed twice */
                if (hks_item(s, j)->kind != HKS_GROUP) CHECK(strcmp(hks_item(s, j)->name, it->name) != 0);
            if (it->kind == HKS_BOOL) CHECK(strcmp(it->def, "0") == 0 || strcmp(it->def, "1") == 0);
            if (it->kind == HKS_ENUM) {
                CHECK(hks_choice(it, 0, v, sizeof(v), l, sizeof(l)));
                CHECK(hks_choice_index(it, it->def) >= 0);              /* the default is one of the choices */
            }
            if (it->kind == HKS_INT) {
                CHECK(hks_int_range(it, &lo, &hi) && lo <= hi && atoi(it->def) >= lo && atoi(it->def) <= hi);
            }
        }
        CHECK(groups >= 4 && opts >= 40);
        hks_free(s);
    }
    CHECK(hks_builtin("nosuch") == NULL);
    {
        /* parsing odd input */
        HkSchema *s = hks_parse("game\tx\tX\nbogus\tline\nbool\tfoo\t1\tFoo\nbool\t\t1\tno name\n# c\n\nenum\te\t\tE\t=A|b=B|c");
        char v[16], l[16];
        CHECK(s != NULL && hks_count(s) == 2);                         /* the unknown line and the nameless one are skipped */
        CHECK(hks_choice(hks_item(s, 1), 0, v, sizeof(v), l, sizeof(l)) && v[0] == '\0' && strcmp(l, "A") == 0);
        CHECK(hks_choice(hks_item(s, 1), 1, v, sizeof(v), l, sizeof(l)) && strcmp(v, "b") == 0 && strcmp(l, "B") == 0);
        CHECK(hks_choice(hks_item(s, 1), 2, v, sizeof(v), l, sizeof(l)) && strcmp(v, "c") == 0 && strcmp(l, "c") == 0);
        CHECK(!hks_choice(hks_item(s, 1), 3, v, sizeof(v), l, sizeof(l)));
        CHECK(hks_choice_index(hks_item(s, 1), "B") == 1 && hks_choice_index(hks_item(s, 1), "z") == -1);
        hks_free(s);
        CHECK(hks_parse("bool\tfoo\t1\tFoo\n") == NULL);              /* no game line */
        CHECK(hks_parse("") == NULL);
    }
}

static void test_schema_apply(void)
{
    HkSchema *s = hks_parse("game\tx\tX\n"
                            "bool\tcolor\t1\tColour\n"
                            "bool\ttime\t0\tTime\n"
                            "enum\tnumber_pad\t0\tKeys\t0=A|1=B|2=C\n"
                            "int\tmsghistory\t20\tMsgs\t0..100\n"
                            "text\tfruit\t\tFruit\n");
    const HkSchemaItem *color = hks_item(s, 0), *tm = hks_item(s, 1), *pad = hks_item(s, 2), *mh = hks_item(s, 3), *fr = hks_item(s, 4);
    HkRc *rc = hkrc_parse("OPTIONS=!color,fruit:kumquat\n", 29);
    char v[64], *t;
    const char *cv;
    size_t len;

    hks_effective(rc, color, v, sizeof(v));  CHECK(strcmp(v, "0") == 0);
    hks_effective(rc, tm, v, sizeof(v));     CHECK(strcmp(v, "0") == 0);
    hks_effective(rc, pad, v, sizeof(v));    CHECK(strcmp(v, "0") == 0);
    hks_effective(rc, fr, v, sizeof(v));     CHECK(strcmp(v, "kumquat") == 0);
    CHECK(hks_is_set(rc, color) && !hks_is_set(rc, tm));

    CHECK(hks_apply(rc, color, "1", 0) == 0);                          /* back to the default: removed */
    CHECK(!hks_is_set(rc, color));
    CHECK(hks_apply(rc, tm, "1", 0) == 0);  CHECK(hkrc_find(rc, "time", &cv) == HKRC_BOOL && strcmp(cv, "1") == 0);
    CHECK(hks_apply(rc, tm, "0", 0) == 0);  CHECK(!hks_is_set(rc, tm));
    CHECK(hks_apply(rc, tm, "0", 1) == 0);  CHECK(hks_is_set(rc, tm));  /* always_write keeps a default explicit */
    CHECK(hks_apply(rc, pad, "1", 0) == 0); hks_effective(rc, pad, v, sizeof(v)); CHECK(strcmp(v, "1") == 0);
    CHECK(hks_apply(rc, pad, "0", 1) == 0); CHECK(hks_is_set(rc, pad));
    hks_effective(rc, pad, v, sizeof(v));    CHECK(strcmp(v, "0") == 0);
    CHECK(hks_apply(rc, pad, "0", 0) == 0); CHECK(!hks_is_set(rc, pad));
    CHECK(hks_apply(rc, mh, "500", 0) == 0); hks_effective(rc, mh, v, sizeof(v)); CHECK(strcmp(v, "100") == 0);     /* clamped */
    CHECK(hks_apply(rc, mh, "-5", 0) == 0);  hks_effective(rc, mh, v, sizeof(v)); CHECK(strcmp(v, "0") == 0);
    CHECK(hks_apply(rc, mh, "20", 0) == 0);  CHECK(!hks_is_set(rc, mh));
    CHECK(hks_apply(rc, fr, "", 0) == 0);    CHECK(!hks_is_set(rc, fr));
    CHECK(hks_apply(rc, fr, "slime mold", 0) == 0); hks_effective(rc, fr, v, sizeof(v)); CHECK(strcmp(v, "slime mold") == 0);
    t = hkrc_text(rc, &len);
    CHECK(t && strstr(t, "fruit:slime mold") && strstr(t, "msghistory") == NULL);
    free(t);
    hkrc_free(rc);
    hks_free(s);
}

static void test_xlog(void)
{
    const char *text =
        "version=3.6.7\tpoints=1200\tdeathdnum=0\tdeathlev=3\tmaxlvl=4\tdeathdate=20261019\trole=Val\trace=Hum\tgender=Fem\talign=Law\tname=Jade\tdeath=killed by a jackal\tturns=412\n"
        "\n"
        "version=3.6.7\tpoints=98765\tdeathlev=12\tmaxlvl=12\tdeathdate=20261020\trole=Wiz\trace=Elf\tgender=Mal\talign=Cha\tname=Mage\tdeath=ascended\tturns=30211\n"
        "garbage line without fields\n"
        "version=3.6.7:points=50:name=Colon:death=starved:deathdate=20261021:role=Arc\r\n";
    HkXlog *x = hkx_parse(text, strlen(text));
    char *r;
    const char *p;

    CHECK(x != NULL && hkx_count(x) == 3);                                 /* the blank and the field-less lines are not games */
    CHECK((p = hkx_get(x, 0, "points")) != NULL && strcmp(p, "1200") == 0);
    CHECK((p = hkx_get(x, 1, "death")) != NULL && strcmp(p, "ascended") == 0);
    CHECK((p = hkx_get(x, 2, "name")) != NULL && strcmp(p, "Colon") == 0);        /* colon-separated lines too */
    CHECK((p = hkx_get(x, 2, "role")) != NULL && strcmp(p, "Arc") == 0);          /* with the CR dropped */
    CHECK(hkx_get(x, 0, "nosuch") == NULL && hkx_get(x, 3, "name") == NULL && hkx_get(x, -1, "name") == NULL);

    r = hkx_report(x, HKX_RECENT, 0);
    CHECK(r != NULL && strstr(r, "Date") == r);
    CHECK(strstr(r, "2026-10-21") && strstr(r, "2026-10-20") && strstr(r, "2026-10-19"));
    CHECK(strstr(r, "2026-10-21") < strstr(r, "2026-10-20") && strstr(r, "2026-10-20") < strstr(r, "2026-10-19"));     /* newest first */
    CHECK(strstr(r, "killed by a jackal  (level 3, deepest 4)") != NULL);
    CHECK(strstr(r, "Val Hum Fem Law") != NULL && strstr(r, "     98765") != NULL);
    free(r);

    r = hkx_report(x, HKX_BEST, 0);
    CHECK(r && strstr(r, "98765") < strstr(r, "1200") && strstr(r, "1200") < strstr(r, " 50 "));                          /* by points */
    free(r);
    r = hkx_report(x, HKX_RECENT, 1);
    CHECK(r && strstr(r, "Colon") != NULL && strstr(r, "Mage") == NULL);                                                  /* only the latest */
    free(r);
    hkx_free(x);

    x = hkx_parse("", 0);
    r = hkx_report(x, HKX_RECENT, 10);
    CHECK(x && hkx_count(x) == 0 && r && strstr(r, "no games recorded") != NULL);
    free(r);
    hkx_free(x);
    {   /* very long fields are cut, not overflowed */
        char big[3000];
        memset(big, 'x', sizeof(big));
        memcpy(big, "name=", 5);
        big[2998] = '\n'; big[2999] = '\0';
        x = hkx_parse(big, strlen(big));
        r = hkx_report(x, HKX_RECENT, 0);
        CHECK(x && r && strlen(r) < 500);
        free(r);
        hkx_free(x);
    }
}

static void test_commands(void)
{
    int i, j, mains[3] = { 0, 0, 0 };

    CHECK(hk_command_count() >= 20);
    for (i = 0; i < hk_command_count(); i++) {
        const HkCommand *c = hk_command(i);
        CHECK(c && c->label[0] && c->keys[0] && c->tip[0] && c->families != 0);
        /* extended commands are "#name" and Return; the rest are single keys */
        CHECK((c->keys[0] == '#' && c->keys[strlen(c->keys) - 1] == '\r') || strlen(c->keys) == 1);
        for (j = 0; j < i; j++) CHECK(strcmp(hk_command(j)->label, c->label) != 0);
        for (j = 0; j < hk_game_count(); j++)
            if (c->main && hk_command_in(c, hk_game(j))) mains[j]++;
    }
    CHECK(hk_command(-1) == NULL && hk_command(hk_command_count()) == NULL);
    for (j = 0; j < hk_game_count(); j++) CHECK(mains[j] >= 6 && mains[j] <= 9);              /* a bar that fits the window */
    /* the dungeon overview is not in the 3.4.3 line */
    for (i = 0; i < hk_command_count(); i++)
        if (strcmp(hk_command(i)->label, "Overview") == 0) {
            CHECK(!hk_command_in(hk_command(i), hk_game_by_id("slashem")));
            CHECK(hk_command_in(hk_command(i), hk_game_by_id("nethack")));
        }
}

static void test_games(void)
{
    const char *tc = hk_termcap_entry();
    int i;

    CHECK(hk_game_count() >= 3);
    for (i = 0; i < hk_game_count(); i++) {
        const HkGameDef *g = hk_game(i);
        CHECK(g && g->id[0] && g->title[0] && g->launcher[0] == '/' && g->hackdir[0] == '/' && g->rcname[0] == '.');
        CHECK(hk_game_by_id(g->id) == g);
    }
    CHECK(hk_game(-1) == NULL && hk_game(hk_game_count()) == NULL && hk_game_by_id("nosuch") == NULL);
    CHECK(strcmp(hk_game_by_id("nethack")->launcher, "/usr/local/bin/nethack") == 0);
    CHECK(strcmp(hk_game_by_id("slashem")->hackdir, "/usr/local/slashemdir") == 0);
    CHECK(strcmp(hk_game_by_id("slashem")->rcname, ".slashemrc") == 0);
    CHECK(strcmp(hk_game_by_id("nethack")->line_option, "DECgraphics") == 0 && strcmp(hk_game_by_id("slashem")->line_option, "DECgraphics") == 0);
    /* the termcap entry must fit a classic environment variable and be well formed */
    CHECK(strlen(tc) < 1000);
    CHECK(strncmp(tc, HK_TERM_NAME "|", strlen(HK_TERM_NAME) + 1) == 0);
    CHECK(tc[strlen(tc) - 1] == ':' && strstr(tc, "::") == NULL);
    CHECK(strstr(tc, ":cm=") && strstr(tc, ":AF=") && strstr(tc, ":as=\\E(0:") && strstr(tc, ":ae=\\E(B:"));
}

int main(void)
{
    test_keymap();
    test_rc_read();
    test_rc_edit();
    test_rc_robust();
    test_games();
    test_schema();
    test_xlog();
    test_commands();
    test_schema_apply();
    TEST_DONE("core");
}
