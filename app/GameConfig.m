#import "GameConfig.h"
#import "UIHelpers.h"
#include <stdlib.h>
#include <string.h>
#include "rcfile.h"

#define KEY_NUMPAD @"DefaultToNumberPad"

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

+ (int)numberPadForGame:(const HkGameDef *)g
{
    NSString *path = [self rcPathForGame:g];
    NSData *data = [NSData dataWithContentsOfFile:path];
    HkRc *rc;
    const char *v = NULL;
    int found, pad = 0;

    rc = hkrc_parse(data ? (const char *)[data bytes] : "", data ? [data length] : 0);
    if (!rc) return 0;
    found = hkrc_find(rc, "number_pad", &v);
    if (found == HKRC_VALUE && v) {
        pad = atoi(v);
    } else if (found == HKRC_BOOL && v) {
        pad = (strcmp(v, "1") == 0) ? 1 : 0;
    } else if ([self defaultToNumberPad]) {
        if (hkrc_set_value(rc, "number_pad", "1") == 0) {
            size_t len;
            char *text = hkrc_text(rc, &len);
            if (text) {
                NSData *out = [NSData dataWithBytes:text length:len];
                free(text);
                if ([out writeToFile:path atomically:YES]) pad = 1;
                else SSTrace("could not write %s", UI_CPATH(path));
            }
        }
    }
    hkrc_free(rc);
    return pad;
}

@end
