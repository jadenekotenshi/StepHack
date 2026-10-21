#import "GameConfig.h"
#import "UIHelpers.h"
#include <stdlib.h>
#include <string.h>
#include "rcfile.h"

#define KEY_NUMPAD @"DefaultToNumberPad"
#define KEY_LINES  @"DefaultToLineGraphics"

@implementation GameConfig

+ (NSString *)keyFor:(NSString *)key game:(const HkGameDef *)g
{
    return [NSString stringWithFormat:@"Game.%s.%@", g->id, key];
}

+ (NSString *)stored:(NSString *)key game:(const HkGameDef *)g
{
    NSString *v = [[NSUserDefaults standardUserDefaults] stringForKey:[self keyFor:key game:g]];
    return (v && [v length]) ? v : nil;
}

+ (NSString *)launcherForGame:(const HkGameDef *)g
{
    NSString *v = [self stored:@"launcher" game:g];
    return v ? v : [NSString stringWithCString:g->launcher];
}

+ (NSString *)hackdirForGame:(const HkGameDef *)g
{
    NSString *v = [self stored:@"hackdir" game:g];
    return v ? v : [NSString stringWithCString:g->hackdir];
}

+ (NSString *)rcPathForGame:(const HkGameDef *)g
{
    NSString *v = [self stored:@"rc" game:g];
    return v ? v : [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithCString:g->rcname]];
}

+ (void)setPath:(NSString *)path forKey:(NSString *)key game:(const HkGameDef *)g
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    NSString *k = [self keyFor:key game:g];
    if (path && [path length]) [d setObject:path forKey:k];
    else [d removeObjectForKey:k];
    [d synchronize];
}

+ (BOOL)defaultToNumberPad
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return ([d objectForKey:KEY_NUMPAD] == nil) ? YES : [d boolForKey:KEY_NUMPAD];
}

+ (void)setDefaultToNumberPad:(BOOL)flag
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:flag forKey:KEY_NUMPAD];
    [d synchronize];
}

+ (BOOL)defaultToLineGraphics
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return ([d objectForKey:KEY_LINES] == nil) ? YES : [d boolForKey:KEY_LINES];
}

+ (void)setDefaultToLineGraphics:(BOOL)flag
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:flag forKey:KEY_LINES];
    [d synchronize];
}

+ (int)numberPadForGame:(const HkGameDef *)g
{
    NSString *path = [self rcPathForGame:g];
    NSData *data = [NSData dataWithContentsOfFile:path];
    HkRc *rc;
    const char *v = NULL;
    int found, pad = 0, changed = 0;

    rc = hkrc_parse(data ? (const char *)[data bytes] : "", data ? [data length] : 0);
    if (!rc) return 0;

    found = hkrc_find(rc, "number_pad", &v);
    if (found == HKRC_VALUE && v) {
        pad = atoi(v);
    } else if (found == HKRC_BOOL && v) {
        pad = (strcmp(v, "1") == 0) ? 1 : 0;
    } else if ([self defaultToNumberPad]) {
        if (hkrc_set_value(rc, "number_pad", "1") == 0) { pad = 1; changed = 1; }
    }
    /* Line graphics for the walls, unless the file says anything about the symbols already. */
    if (g->line_option && [self defaultToLineGraphics] &&
        hkrc_find(rc, g->line_option, NULL) == HKRC_ABSENT && hkrc_find(rc, "symset", NULL) == HKRC_ABSENT &&
        hkrc_find(rc, "IBMgraphics", NULL) == HKRC_ABSENT && hkrc_find(rc, "curses_graphics", NULL) == HKRC_ABSENT) {
        if (hkrc_set_bool(rc, g->line_option, 1) == 0) changed = 1;
    }
    if (changed) {
        size_t len;
        char *text = hkrc_text(rc, &len);
        if (text) {
            NSData *out = [NSData dataWithBytes:text length:len];
            free(text);
            if (![out writeToFile:path atomically:YES]) {
                SSTrace("could not write %s", UI_CPATH(path));
                pad = (found == HKRC_VALUE || found == HKRC_BOOL) ? pad : 0;      /* the file stays as it was */
            }
        }
    }
    hkrc_free(rc);
    return pad;
}

@end
