#import "GameConfig.h"
#import "UIHelpers.h"
#include <stdlib.h>
#include <string.h>
#include "rcfile.h"

#define KEY_NUMPAD @"DefaultToNumberPad"
#define KEY_LINES  @"DefaultToLineGraphics"
#define KEY_CLOSE  @"CloseWhenDone"

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

+ (BOOL)isInstalled:(const HkGameDef *)g
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *launcher = [self launcherForGame:g];
    BOOL isDir = NO;
    return [fm fileExistsAtPath:launcher isDirectory:&isDir] && !isDir && [fm isExecutableFileAtPath:launcher];
}

+ (NSString *)lastGameId
{
    return [[NSUserDefaults standardUserDefaults] stringForKey:@"LastGame"];
}

+ (void)setLastGameId:(NSString *)gid
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setObject:gid forKey:@"LastGame"];
    [d synchronize];
}

+ (NSString *)hackdirForGame:(const HkGameDef *)g
{
    NSString *v = [self stored:@"hackdir" game:g];
    return v ? v : [NSString stringWithCString:g->hackdir];
}

/* The file the game reads when nothing is set in Preferences: its usual name in the home directory, or, for a game that
 * falls back to an older name, that file while the usual one does not exist. */
+ (NSString *)defaultRcPathForGame:(const HkGameDef *)g
{
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *main_ = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithCString:g->rcname]];
    NSString *alt;

    if (g->rcname_alt && ![fm fileExistsAtPath:main_]) {
        alt = [NSHomeDirectory() stringByAppendingPathComponent:[NSString stringWithCString:g->rcname_alt]];
        if ([fm fileExistsAtPath:alt]) return alt;
    }
    return main_;
}

+ (NSString *)rcPathForGame:(const HkGameDef *)g
{
    NSString *v = [self stored:@"rc" game:g];
    return v ? v : [self defaultRcPathForGame:g];
}

+ (NSString *)termForGame:(const HkGameDef *)g curses:(BOOL)curses
{
    NSString *v = [self stored:@"term" game:g];
    if (v) return [v isEqualToString:[NSString stringWithCString:HK_TERM_NAME]] ? nil : v;
    if (g->term) return [NSString stringWithCString:g->term];
    return curses ? @"xterm" : nil;
}

+ (NSString *)termForGame:(const HkGameDef *)g
{
    return [self termForGame:g curses:NO];
}

+ (NSData *)rcDataForGame:(const HkGameDef *)g
{
    NSString *path = [self rcPathForGame:g];
    NSData *data = [NSData dataWithContentsOfFile:path];
    if (data || !g->rcdefault) return data;
    return [NSData dataWithContentsOfFile:[[self hackdirForGame:g] stringByAppendingPathComponent:
                                              [NSString stringWithCString:g->rcdefault]]];
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

+ (BOOL)closeWhenDone
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    return ([d objectForKey:KEY_CLOSE] == nil) ? YES : [d boolForKey:KEY_CLOSE];
}

+ (void)setCloseWhenDone:(BOOL)flag
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setBool:flag forKey:KEY_CLOSE];
    [d synchronize];
}

+ (int)colourScheme
{
    int v = [[NSUserDefaults standardUserDefaults] integerForKey:@"ColourScheme"];
    return (v == 1) ? 1 : 0;
}

+ (void)setColourScheme:(int)scheme
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:(scheme == 1 ? 1 : 0) forKey:@"ColourScheme"];
    [d synchronize];
}

+ (int)boldStyle
{
    int v = [[NSUserDefaults standardUserDefaults] integerForKey:@"BoldStyle"];
    return (v == 1 || v == 2) ? v : 0;
}

+ (void)setBoldStyle:(int)style
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:((style == 1 || style == 2) ? style : 0) forKey:@"BoldStyle"];
    [d synchronize];
}

+ (int)closeAction
{
    return ([[NSUserDefaults standardUserDefaults] integerForKey:@"CloseAction"] == 1) ? 1 : 0;
}

+ (void)setCloseAction:(int)action
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    [d setInteger:(action == 1 ? 1 : 0) forKey:@"CloseAction"];
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

+ (BOOL)useCursesForGame:(const HkGameDef *)g
{
    NSString *v;
    if (g->curses == HK_CURSES_NONE) return NO;
    v = [self stored:@"curses" game:g];
    if (v) return [v isEqualToString:@"1"];
    return g->curses_default != 0;
}

+ (void)setUseCurses:(int)choice forGame:(const HkGameDef *)g
{
    [self setPath:(choice < 0) ? @"" : (choice ? @"1" : @"0") forKey:@"curses" game:g];
}

+ (int)numberPadForGame:(const HkGameDef *)g
{
    int curses;
    return [self numberPadForGame:g curses:&curses];
}

/* Sets an option the file leaves unset, noting that the file changed. */
static int add_bool_default(HkRc *rc, const char *name)
{
    if (hkrc_find(rc, name, NULL) != HKRC_ABSENT) return 0;
    return hkrc_set_bool(rc, name, 1) == 0;
}

+ (int)numberPadForGame:(const HkGameDef *)g curses:(int *)curses
{
    NSString *path = [self rcPathForGame:g];
    NSData *data = [self rcDataForGame:g];
    HkRc *rc;
    const char *v = NULL;
    int found, pad = 0, changed = 0, isCurses = 0;

    *curses = 0;
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

    /* The interface: what the file says if it names one, else curses when that is wanted and the game has it. */
    if (hkrc_find(rc, "windowtype", &v) == HKRC_VALUE && v) {
        isCurses = (strcmp(v, "curses") == 0 || strcmp(v, "Curses") == 0);
    } else if ([self useCursesForGame:g]) {
        if (hkrc_set_value(rc, "windowtype", "curses") == 0) { isCurses = 1; changed = 1; }
    }

    if (isCurses && g->curses != HK_CURSES_NONE) {
        /* Line drawing, colour, mouse and the like, for whatever the file leaves unset. */
        static const char *const plain[] = { "color", "guicolor", "mouse_support", "perm_invent", "splash_screen", "popup_dialog", NULL };
        int i;

        if ([self defaultToLineGraphics]) {
            if (g->curses == HK_CURSES_SYMSET) {
                if (hkrc_find(rc, "symset", NULL) == HKRC_ABSENT && hkrc_find(rc, "DECgraphics", NULL) == HKRC_ABSENT &&
                    hkrc_find(rc, "IBMgraphics", NULL) == HKRC_ABSENT && hkrc_find(rc, "curses_graphics", NULL) == HKRC_ABSENT &&
                    hkrc_set_value(rc, "symset", "DECgraphics") == 0) changed = 1;
            } else if (add_bool_default(rc, "cursesgraphics")) {
                changed = 1;
            }
        }
        for (i = 0; plain[i]; i++)
            if (add_bool_default(rc, plain[i])) changed = 1;
    } else if (g->line_option && [self defaultToLineGraphics]) {
        /* The plain tty interface: line graphics for the walls, unless the file says anything about the symbols already. */
        if (hkrc_find(rc, g->line_option, NULL) == HKRC_ABSENT && hkrc_find(rc, "symset", NULL) == HKRC_ABSENT &&
            hkrc_find(rc, "IBMgraphics", NULL) == HKRC_ABSENT && hkrc_find(rc, "curses_graphics", NULL) == HKRC_ABSENT) {
            if (hkrc_set_bool(rc, g->line_option, 1) == 0) changed = 1;
        }
    }

    if (changed) {
        size_t len;
        char *text = hkrc_text(rc, &len);
        if (text) {
            NSData *out = [NSData dataWithBytes:text length:len];
            free(text);
            if (![out writeToFile:path atomically:YES]) {
                SSTrace("could not write %s", UI_CPATH(path));
                if (!(found == HKRC_VALUE || found == HKRC_BOOL)) pad = 0;       /* the file stays as it was */
                isCurses = 0;
            }
        }
    }
    *curses = isCurses && g->curses != HK_CURSES_NONE;
    hkrc_free(rc);
    return pad;
}

@end
