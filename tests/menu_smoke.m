/* Host-only check of the New Game menu: it lists the games that are installed, and follows changes.  make menu-smoke */
#import "AppController.h"
#import "GameConfig.h"
#include <stdio.h>
#include <stdlib.h>
#include <sys/stat.h>
#include <unistd.h>

void PSmoveto(float x, float y) { }
void PSshow(const char *s) { }
@implementation NSFont (OpenStepHostStub)
- (float)widthOfString:(NSString *)s { return [self maximumAdvancement].width; }
@end

static int failures = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static NSMenu *submenu(NSMenu *m, NSString *title)
{
    NSArray *items = [m itemArray];
    unsigned i;
    for (i = 0; i < [items count]; i++)
        if ([[[items objectAtIndex:i] title] isEqualToString:title]) return [[items objectAtIndex:i] submenu];
    return nil;
}

static NSArray *titles(NSMenu *m)
{
    NSMutableArray *out = [NSMutableArray array];
    NSArray *items = [m itemArray];
    unsigned i;
    for (i = 0; i < [items count]; i++) [out addObject:[[items objectAtIndex:i] title]];
    return out;
}

static BOOL has(NSArray *a, NSString *prefix)
{
    unsigned i;
    for (i = 0; i < [a count]; i++) if ([[a objectAtIndex:i] hasPrefix:prefix]) return YES;
    return NO;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [NSString stringWithFormat:@"/tmp/stephack-menu-test-%d", (int)getpid()];
    NSString *fake = [dir stringByAppendingPathComponent:@"fakegame"];
    AppController *app;
    NSMenu *games;
    NSArray *t;
    int i;

    [NSApplication sharedApplication];
    [fm createDirectoryAtPath:dir attributes:nil];
    [@"#!/bin/sh\nexit 0\n" writeToFile:fake atomically:YES];
    chmod([fake fileSystemRepresentation], 0755);
    for (i = 0; i < hk_game_count(); i++) [GameConfig setPath:[dir stringByAppendingPathComponent:@"nothing-here"] forKey:@"launcher" game:hk_game(i)];

    app = [[[AppController alloc] init] autorelease];
    [app buildMenu];
    games = submenu(submenu([NSApp mainMenu], @"Game"), @"New Game");
    CHECK(games != nil);
    t = titles(games);
    CHECK([t count] == 2 && [[t objectAtIndex:0] isEqualToString:@"No games found"]);       /* nothing installed */
    CHECK([[t objectAtIndex:1] isEqualToString:@"Look for Games Again"]);

    [GameConfig setPath:fake forKey:@"launcher" game:hk_game_by_id("slashem")];             /* one appears */
    [app rescanGames:nil];
    t = titles(games);
    CHECK([t count] == 2 && has(t, @"Slash'EM") && !has(t, @"No games") && !has(t, @"NetHack"));

    [GameConfig setPath:fake forKey:@"launcher" game:hk_game_by_id("unnethack")];
    [GameConfig setPath:fake forKey:@"launcher" game:hk_game_by_id("nethack")];
    [app rescanGames:nil];
    t = titles(games);
    CHECK([t count] == 4 && has(t, @"NetHack 3.6.7") && has(t, @"Slash'EM") && has(t, @"UnNetHack"));
    CHECK([[t objectAtIndex:0] hasPrefix:@"NetHack 3.6.7"] && [[t objectAtIndex:1] hasPrefix:@"Slash'EM"]);        /* table order */
    CHECK(has(t, @"UnNetHack 6.0.17 (untested)"));                                            /* untested ones say so */
    {
        id item = [[games itemArray] objectAtIndex:1];
        CHECK([item tag] == 1 && hk_game([item tag]) == hk_game_by_id("slashem"));            /* the tag is the game's index */
    }

    [GameConfig setPath:[dir stringByAppendingPathComponent:@"nothing-here"] forKey:@"launcher" game:hk_game_by_id("slashem")];
    [app rescanGames:nil];                                                                    /* one disappears again */
    t = titles(games);
    CHECK([t count] == 3 && !has(t, @"Slash'EM"));

    /* the same games, started in wizard or explore mode: tags carry the mode */
    {
        NSMenu *wiz = submenu(submenu([NSApp mainMenu], @"Game"), @"New Wizard Mode Game");
        NSMenu *exp = submenu(submenu([NSApp mainMenu], @"Game"), @"New Explore Mode Game");
        NSArray *wt, *et;
        CHECK(wiz != nil && exp != nil);
        wt = titles(wiz); et = titles(exp);
        CHECK([wt count] == 2 && [et count] == 2 && has(wt, @"NetHack 3.6.7") && has(et, @"UnNetHack"));   /* the two installed; no "look again" item here */
        CHECK([[[wiz itemArray] objectAtIndex:0] tag] == 0 + 256 * HK_MODE_WIZARD);
        {
            int un = 0, j;
            for (j = 0; j < hk_game_count(); j++) if (hk_game(j) == hk_game_by_id("unnethack")) un = j;
            CHECK([[[exp itemArray] objectAtIndex:1] tag] == un + 256 * HK_MODE_EXPLORE);
        }
    }

    /* installed means a runnable file, not a directory or a plain file */
    [@"text" writeToFile:[dir stringByAppendingPathComponent:@"plain"] atomically:YES];
    [GameConfig setPath:[dir stringByAppendingPathComponent:@"plain"] forKey:@"launcher" game:hk_game_by_id("slashem")];
    CHECK(![GameConfig isInstalled:hk_game_by_id("slashem")]);
    [GameConfig setPath:dir forKey:@"launcher" game:hk_game_by_id("slashem")];
    CHECK(![GameConfig isInstalled:hk_game_by_id("slashem")]);
    CHECK([GameConfig isInstalled:hk_game_by_id("nethack")]);

    /* the last game played is remembered */
    [GameConfig setLastGameId:@"unnethack"];
    CHECK([[GameConfig lastGameId] isEqualToString:@"unnethack"]);

    for (i = 0; i < hk_game_count(); i++) [GameConfig setPath:@"" forKey:@"launcher" game:hk_game(i)];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"LastGame"];
    [fm removeFileAtPath:dir handler:nil];
    printf("menu: %s\n", failures ? "FAILED" : "ok");
    [pool release];
    return failures ? 1 : 0;
}
