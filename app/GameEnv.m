#import "GameEnv.h"
#include <stdlib.h>
#include <string.h>
#include "games.h"

extern char **environ;

char *hk_copy_c(const char *s)
{
    size_t n = strlen(s) + 1;
    char *p = (char *)malloc(n);
    if (p) memcpy(p, s, n);
    return p;
}

/* "NAME=value" for putting in an environment block. */
static char *env_entry(const char *name, const char *value)
{
    size_t nl = strlen(name), vl = strlen(value);
    char *p = (char *)malloc(nl + vl + 2);
    if (p) { memcpy(p, name, nl); p[nl] = '='; memcpy(p + nl + 1, value, vl + 1); }
    return p;
}

char **hk_game_environ(const char *hackdir, const HkGameDef *game)
{
    int count = 0, i, k = 0;
    char **env;

    while (environ[count]) count++;
    env = (char **)malloc((size_t)(count + 4) * sizeof(char *));
    if (!env) return NULL;
    for (i = 0; i < count; i++) {
        const char *e = environ[i];
        if (strncmp(e, "TERM=", 5) == 0 || strncmp(e, "TERMCAP=", 8) == 0 || strncmp(e, "HACKDIR=", 8) == 0) continue;
        env[k++] = environ[i];
    }
    if (game && game->term) {
        env[k++] = env_entry("TERM", game->term);
    } else {
        env[k++] = env_entry("TERM", HK_TERM_NAME);
        env[k++] = env_entry("TERMCAP", hk_termcap_entry());
    }
    env[k++] = env_entry("HACKDIR", hackdir);
    env[k] = (char *)0;
    return env;
}
