#include <string.h>
#include "games.h"

static const HkGameDef GAMES[] = {
    { "nethack",   "NetHack 3.6.7",   "/usr/local/bin/nethack",   "/usr/local/lib/nethackdir",   ".nethackrc",   NULL,         NULL,                  "nethack367", "DECgraphics", 1, HK_FAMILY_36, HK_CURSES_SYMSET, 1, NULL, "sysconf", NULL },
    { "slashem",   "Slash'EM 0.0.7",  "/usr/local/bin/slashem",   "/usr/local/slashemdir",       ".slashemrc",   NULL,         NULL,                  "slashem",    "DECgraphics", 1, HK_FAMILY_34, HK_CURSES_NONE, 0, NULL, NULL, NULL },
    { "nethack5",  "NetHack 5.0",     "/usr/local/bin/nethack5",  "/usr/local/lib/nethack5dir",  ".nethackrc",   NULL,         NULL,                  "nethack5",   "DECgraphics", 1, HK_FAMILY_50, HK_CURSES_SYMSET, 1, NULL, "sysconf", NULL },
    { "sporkhack", "SporkHack 0.6.5", "/usr/local/bin/sporkhack", "/usr/local/lib/sporkhackdir", ".sporkrc",     ".nethackrc", NULL,                  "sporkhack",  "DECgraphics", 1, HK_FAMILY_34, HK_CURSES_GFX, 1, "xterm", NULL, NULL },
    { "nethack343","NetHack 3.4.3",   "/usr/local/bin/nethack343","/usr/local/lib/nethack343dir",".nethack343rc",NULL,       NULL,                  "nethack343", "DECgraphics", 1, HK_FAMILY_34, HK_CURSES_GFX, 1, "xterm", NULL, "NETHACKOPTIONS" },
    { "unnethack", "UnNetHack 6.0.17","/usr/local/bin/unnethack", "/usr/local/share/unnethack",  ".unnethackrc", ".nethackrc", "unnethackrc.default", "unnethack",  "DECgraphics", 1, HK_FAMILY_34 | HK_FAMILY_36, HK_CURSES_GFX, 1, "xterm", NULL, NULL },
    { "evilhack",  "EvilHack 0.9.3",  "/usr/local/bin/evilhack",  "/usr/local/lib/evilhackdir",  ".evilhackrc",  NULL,         NULL,                  "evilhack",   "DECgraphics", 1, HK_FAMILY_36, HK_CURSES_SYMSET, 1, "xterm", "sysconf", NULL },
    { "splicehack","SpliceHack 1.2.0","/usr/local/bin/splicehack","/usr/local/lib/splicehackdir",".splicehackrc",NULL,         NULL,                  "splicehack", "DECgraphics", 1, HK_FAMILY_36 | HK_FAMILY_50, HK_CURSES_SYMSET, 1, "xterm", "sysconf", NULL },
    { "hackem",    "Hack'EM 1.3.2",  "/usr/local/bin/hackem",    "/usr/local/lib/hackemdir",    ".hackemrc",    NULL,         NULL,                  "hackem",     "DECgraphics", 1, HK_FAMILY_36, HK_CURSES_SYMSET, 0, "xterm", "sysconf", NULL }
};

const char *hk_mode_arg(int mode)
{
    return mode == HK_MODE_WIZARD ? "-D" : mode == HK_MODE_EXPLORE ? "-X" : NULL;
}

const char *hk_mode_name(int mode)
{
    return mode == HK_MODE_WIZARD ? "wizard mode" : mode == HK_MODE_EXPLORE ? "explore mode" : "";
}

int hk_game_count(void) { return (int)(sizeof(GAMES) / sizeof(GAMES[0])); }

const HkGameDef *hk_game(int index)
{
    if (index < 0 || index >= hk_game_count()) return NULL;
    return &GAMES[index];
}

const HkGameDef *hk_game_by_id(const char *id)
{
    int i;
    for (i = 0; i < hk_game_count(); i++)
        if (strcmp(GAMES[i].id, id) == 0) return &GAMES[i];
    return NULL;
}

/* An xterm-style terminal as term/vt.c implements it.  Kept well under the 1023 characters classic termcap accepts in an
 * environment variable.  The line-drawing set is switched by escape sequences (as/ae), not SO/SI, so it does not depend on
 * which character set the terminal started with. */
static const char TERMCAP[] =
    HK_TERM_NAME "|StepHack terminal:"
    "co#80:li#24:Co#8:pa#64:"
    "am:bs:ms:xn:"
    "cl=\\E[H\\E[2J:cm=\\E[%i%d;%dH:ho=\\E[H:ce=\\E[K:cd=\\E[J:"
    "up=\\E[A:do=\\E[B:nd=\\E[C:le=^H:cr=^M:nl=^J:bl=^G:"
    "cs=\\E[%i%d;%dr:sf=^J:sr=\\EM:"
    "so=\\E[7m:se=\\E[27m:us=\\E[4m:ue=\\E[24m:md=\\E[1m:mr=\\E[7m:me=\\E[m:"
    "AF=\\E[3%dm:AB=\\E[4%dm:op=\\E[39;49m:"
    "as=\\E(0:ae=\\E(B:"
    "vi=\\E[?25l:ve=\\E[?25h:"
    "";

const char *hk_termcap_entry(void) { return TERMCAP; }
