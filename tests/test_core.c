#include <stdlib.h>
#include <string.h>
#include "test.h"
#include "vt.h"
#include "keymap.h"
#include "rcfile.h"
#include "games.h"

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
    TEST_DONE("core");
}
