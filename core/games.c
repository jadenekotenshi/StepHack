#include <string.h>
#include "games.h"

static const HkGameDef GAMES[] = {
    { "nethack",  "NetHack 3.6.7",    "/usr/local/bin/nethack",  "/usr/local/lib/nethackdir",  ".nethackrc", "nethack367", 1 },
    { "slashem",  "Slash'EM 0.0.7",   "/usr/local/bin/slashem",  "/usr/local/slashemdir",      ".slashemrc", "slashem",    1 },
    { "nethack5", "NetHack 5.0",      "/usr/local/bin/nethack5", "/usr/local/lib/nethack5dir", ".nethackrc", "nethack5",   0 }
};

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
