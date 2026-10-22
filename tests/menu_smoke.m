/* Host-only check of the New Game menu: it lists the games that are installed, and follows changes.  make menu-smoke */
#import "AppController.h"
#import "GameConfig.h"
#import "SysconfController.h"
#import "ProcessRunner.h"
#import "UIHelpers.h"
#include "backup.h"
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
    CHECK([[[NSApp mainMenu] itemArray] count] == 1);                      /* before the application runs: just Quit */
    [app buildFullMenu];
    games = submenu(submenu([NSApp mainMenu], @"Game"), @"New Game");
    CHECK(games != nil);
    CHECK([[games itemArray] count] == 0);                                  /* nothing is looked up while the menus are built */
    [app addModeMenus];                                                    /* (what start-up does, without starting a game) */
    [app rescanGames:nil];
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

    /* system settings: the item is offered for a game that has a sysconf file, and the window edits it in place */
    {
        const HkGameDef *nh = hk_game_by_id("nethack");
        NSString *sysfile = [dir stringByAppendingPathComponent:@"sysconf"], *got;
        NSMenu *gm = submenu([NSApp mainMenu], @"Game");
        id item = nil;
        NSArray *its = [gm itemArray];
        unsigned q;
        SysconfController *sysc;

        for (q = 0; q < [its count]; q++) if ([[[its objectAtIndex:q] title] isEqualToString:@"System Settings..."]) item = [its objectAtIndex:q];
        CHECK(item != nil);
        [GameConfig setPath:dir forKey:@"hackdir" game:nh];
        [GameConfig setLastGameId:@"nethack"];
        CHECK(![SysconfController hasSysconfForGame:nh]);                         /* no file yet */
        [@"# header\nWIZARDS=root games\n#SHELLERS=\nMAXPLAYERS=10\nSEDUCE=1\n" writeToFile:sysfile atomically:YES];
        CHECK([SysconfController hasSysconfForGame:nh]);
        CHECK(![SysconfController hasSysconfForGame:hk_game_by_id("slashem")]);   /* a game without one */
        [SysconfController setBackupRoot:[dir stringByAppendingPathComponent:@"backups-first"]];       /* never the real ~/.StepHack */
        sysc = [SysconfController controllerForGame:nh];
        [sysc showWindow];
        CHECK([sysc isEditable]);
        CHECK([[sysc valueForKey:@"WIZARDS"] isEqualToString:@"root games"] && [[sysc valueForKey:@"MAXPLAYERS"] isEqualToString:@"10"]);
        [sysc setValue:@"root games jade" forKey:@"WIZARDS"];
        [sysc setValue:@"" forKey:@"SHELLERS"];                                   /* absent and empty: nothing written */
        [sysc setValue:@"4" forKey:@"MAXPLAYERS"];
        [sysc setValue:@"0" forKey:@"SEDUCE"];
        [sysc save:nil];
        got = [NSString stringWithContentsOfFile:sysfile];
        CHECK([got hasPrefix:@"# header\nWIZARDS=root games jade\n#SHELLERS=\nMAXPLAYERS=4\nSEDUCE=0\n"]);
        CHECK([got rangeOfString:@"SHELLERS=\nSHELLERS"].length == 0);
        /* the save made a dated, gzipped backup of the file as it was, in the backups directory (not beside the file) */
        {
            NSCalendarDate *nowd = [NSCalendarDate calendarDate];
            NSString *broot = [dir stringByAppendingPathComponent:@"backups"], *bdir = [broot stringByAppendingPathComponent:@"nethack"];
            NSArray *files;
            NSString *first, *content;
            char bn[96];
            long today = hkb_days([nowd yearOfCommonEra], [nowd monthOfYear], [nowd dayOfMonth]);
            int y, mo, da, k, ages[4] = { 40, 31, 30, 5 };
            NSString *orig = @"# header\nWIZARDS=root games\n#SHELLERS=\nMAXPLAYERS=10\nSEDUCE=1\n";
            NSString *gz = @"/usr/bin/gzip";

            CHECK(sysc != nil);
            /* (the first save above ran before the backups directory was redirected: do it again with the redirect) */
            [SysconfController setBackupRoot:broot];
            [orig writeToFile:sysfile atomically:YES];
            [sysc revert:nil];
            [sysc setValue:@"4" forKey:@"MAXPLAYERS"];
            [sysc save:nil];
            files = [fm directoryContentsAtPath:bdir];
            CHECK([files count] == 1);
            first = [files count] ? [files objectAtIndex:0] : @"";
            CHECK([first hasPrefix:@"sysconf.old."] && [first hasSuffix:@".gz"] && hkb_parse(UI_CPATH(first), "sysconf", NULL, NULL, NULL, NULL, NULL));
            CHECK(![fm fileExistsAtPath:[dir stringByAppendingPathComponent:first]]);              /* not next to the file */
            CHECK([[fm directoryContentsAtPath:dir] indexOfObject:@"sysconf.old"] == NSNotFound);
            content = [ProcessRunner outputOfProgram:gz arguments:[NSArray arrayWithObjects:@"-dc", [bdir stringByAppendingPathComponent:first], nil]
                                             hackdir:dir game:nh seconds:10.0];
            CHECK([content isEqualToString:orig]);                                                 /* a real gzip file with the old contents */
            CHECK([[NSString stringWithContentsOfFile:sysfile] rangeOfString:@"MAXPLAYERS=4"].length > 0);

            /* a second save in the same minute leaves that copy alone (a new minute just makes another) */
            [sysc setValue:@"5" forKey:@"MAXPLAYERS"];
            [sysc save:nil];
            content = [ProcessRunner outputOfProgram:gz arguments:[NSArray arrayWithObjects:@"-dc", [bdir stringByAppendingPathComponent:first], nil]
                                             hackdir:dir game:nh seconds:10.0];
            CHECK([content isEqualToString:orig]);
            CHECK([[NSString stringWithContentsOfFile:sysfile] rangeOfString:@"MAXPLAYERS=5"].length > 0);

            /* clean up: older than 30 days goes (the date in the name decides), the rest and other files stay */
            for (k = 0; k < 4; k++) {
                hkb_civil(today - ages[k], &y, &mo, &da);
                hkb_name(bn, sizeof(bn), "sysconf", y, mo, da, 9, 5);
                [@"old" writeToFile:[bdir stringByAppendingPathComponent:[NSString stringWithFormat:@"%s%s", bn, (k & 1) ? "" : ".gz"]]
                         atomically:YES];                                                          /* gzipped and plain names both count */
            }
            [@"x" writeToFile:[bdir stringByAppendingPathComponent:@"sysconf.old.junk"] atomically:YES];
            [@"x" writeToFile:[bdir stringByAppendingPathComponent:@"other.old.01Jan2000.0000.gz"] atomically:YES];
            CHECK([sysc countBackupsOlderThan:30] == 2);                                       /* 40 and 31 days, not 30 */
            CHECK([sysc countBackupsOlderThan:60] == 0 && [sysc countBackupsOlderThan:0] == 4);
            CHECK([sysc removeBackupsOlderThan:30] == 2);
            CHECK([sysc countBackupsOlderThan:30] == 0);
            hkb_civil(today - 31, &y, &mo, &da);
            hkb_name(bn, sizeof(bn), "sysconf", y, mo, da, 9, 5);
            CHECK(![fm fileExistsAtPath:[bdir stringByAppendingPathComponent:[NSString stringWithCString:bn]]]);
            hkb_civil(today - 30, &y, &mo, &da);
            hkb_name(bn, sizeof(bn), "sysconf", y, mo, da, 9, 5);
            {
                NSString *gzname = [NSString stringWithFormat:@"%s.gz", bn];
                CHECK([fm fileExistsAtPath:[bdir stringByAppendingPathComponent:gzname]]);
            }
            CHECK([fm fileExistsAtPath:[bdir stringByAppendingPathComponent:@"sysconf.old.junk"]]);
            CHECK([fm fileExistsAtPath:[bdir stringByAppendingPathComponent:@"other.old.01Jan2000.0000.gz"]]);
            CHECK([GameConfig backupDays] == 30);                                              /* the default */
            [SysconfController setBackupRoot:nil];
        }
        [sysc setValue:@"x" forKey:@"MAXPLAYERS"];                                 /* not a number: refused (no alert in a test: nothing written) */
        chmod([sysfile fileSystemRepresentation], 0444);                           /* read only: shown, not changed */
        [sysc revert:nil];
        CHECK(![sysc isEditable]);
        [sysc setValue:@"nobody" forKey:@"WIZARDS"];
        [sysc save:nil];
        CHECK([[NSString stringWithContentsOfFile:sysfile] rangeOfString:@"nobody"].length == 0);
        chmod([sysfile fileSystemRepresentation], 0644);
        [GameConfig setPath:@"" forKey:@"hackdir" game:nh];
        [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"SysconfBackupDays"];
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
