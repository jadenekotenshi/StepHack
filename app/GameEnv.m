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

char **hk_game_environ(const char *hackdir, const char *term)
{
    return hk_game_environ_with(hackdir, term, NULL, NULL);
}

char **hk_game_environ_with(const char *hackdir, const char *term, const char *name, const char *value)
{
    int count = 0, i, k = 0;
    char **env;

    while (environ[count]) count++;
    env = (char **)malloc((size_t)(count + 5) * sizeof(char *));
    if (!env) return NULL;
    for (i = 0; i < count; i++) {
        const char *e = environ[i];
        if (strncmp(e, "TERM=", 5) == 0 || strncmp(e, "TERMCAP=", 8) == 0 || strncmp(e, "HACKDIR=", 8) == 0) continue;
        if (name && strncmp(e, name, strlen(name)) == 0 && e[strlen(name)] == '=') continue;
        env[k++] = environ[i];
    }
    if (term) {
        env[k++] = env_entry("TERM", term);
    } else {
        env[k++] = env_entry("TERM", HK_TERM_NAME);
        env[k++] = env_entry("TERMCAP", hk_termcap_entry());
    }
    env[k++] = env_entry("HACKDIR", hackdir);
    if (name && value) env[k++] = env_entry(name, value);
    env[k] = (char *)0;
    return env;
}
