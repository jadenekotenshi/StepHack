/* Host-only end-to-end check of GameSession: runs a fake "game" (cat) on a real pty, types at it through the command bar's
 * path, checks the key translation, the options-file defaults, and the saved ending.  make session-smoke */
#import "GameSession.h"
#import "GameConfig.h"
#import "EndingStore.h"
#import "TerminalView.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/stat.h>
#include "vt.h"
#include "keymap.h"
#include "commands.h"

void PSmoveto(float x, float y) { }
void PSshow(const char *s) { }
@implementation NSFont (OpenStepHostStub)
- (float)widthOfString:(NSString *)s { return [self maximumAdvancement].width; }
@end

@interface Owner : NSObject { int ended; } - (int)ended; @end
@implementation Owner
- (void)sessionDidEnd:(GameSession *)s { ended = 1; }
- (int)ended { return ended; }
@end

static int failures = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void spin(double seconds) { [[NSRunLoop currentRunLoop] runUntilDate:[NSDate dateWithTimeIntervalSinceNow:seconds]]; }

static TerminalView *find_terminal(NSWindow *w)
{
    NSEnumerator *e = [[[w contentView] subviews] objectEnumerator];
    id v;
    while ((v = [e nextObject])) if ([v isKindOfClass:[TerminalView class]]) return v;
    return nil;
}

static int wait_for(TerminalView *tv, NSString *needle, double timeout)
{
    double waited = 0;
    while (waited < timeout) {
        if ([[tv transcript:200] rangeOfString:needle].length > 0) return 1;
        spin(0.05);
        waited += 0.05;
    }
    return 0;
}

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *dir = [NSString stringWithFormat:@"/tmp/stephack-session-test-%d", (int)getpid()];
    NSString *launcher = [dir stringByAppendingPathComponent:@"fakegame"];
    NSString *rc = [dir stringByAppendingPathComponent:@"rc"];
    const HkGameDef *g = hk_game_by_id("nethack");
    Owner *owner = [[[Owner alloc] init] autorelease];
    GameSession *s;
    NSString *why = nil, *rctext, *ending;
    TerminalView *tv;
    unsigned char b[32];
    int n, i;

    [fm createDirectoryAtPath:dir attributes:nil];
    [@"#!/bin/sh\nexec cat\n" writeToFile:launcher atomically:YES];
    chmod([launcher fileSystemRepresentation], 0755);
    [@"# my rc\nOPTIONS=color\n" writeToFile:rc atomically:YES];
    [GameConfig setPath:launcher forKey:@"launcher" game:g];
    [GameConfig setPath:dir forKey:@"hackdir" game:g];
    [GameConfig setPath:rc forKey:@"rc" game:g];
    [EndingStore setDirectory:[dir stringByAppendingPathComponent:@"endings"]];
    [fm createDirectoryAtPath:[dir stringByAppendingPathComponent:@"endings"] attributes:nil];

    /* a game with a template options file starts from it, not from nothing */
    {
        const HkGameDef *u = hk_game_by_id("unnethack");
        NSString *tmpl = [dir stringByAppendingPathComponent:@"unnethackrc.default"];
        NSString *urc = [dir stringByAppendingPathComponent:@"urc"], *got;
        [@"# template\nOPTIONS=pickup_types:$?!\n" writeToFile:tmpl atomically:YES];
        [GameConfig setPath:dir forKey:@"hackdir" game:u];
        [GameConfig setPath:urc forKey:@"rc" game:u];
        CHECK([[GameConfig rcDataForGame:u] length] == [[NSData dataWithContentsOfFile:tmpl] length]);
        CHECK([GameConfig numberPadForGame:u] == 1);
        got = [NSString stringWithContentsOfFile:urc];
        CHECK([got hasPrefix:@"# template\nOPTIONS=pickup_types:$?!\n"] && [got rangeOfString:@"number_pad:1"].length > 0);
        CHECK([GameConfig termForGame:u] != nil && [[GameConfig termForGame:u] isEqualToString:@"xterm"]);
        [GameConfig setPath:@"stephack" forKey:@"term" game:u];
        CHECK([GameConfig termForGame:u] == nil);                              /* the override picks the termcap entry */
        [GameConfig setPath:@"" forKey:@"term" game:u];
        [GameConfig setPath:@"" forKey:@"hackdir" game:u];
        [GameConfig setPath:@"" forKey:@"rc" game:u];
    }

    s = [[GameSession alloc] initWithGame:g owner:owner];
    CHECK([s startReportingTo:&why]);
    tv = find_terminal([s window]);
    CHECK(tv != nil && [s isRunning]);

    /* the options file got its defaults, and everything else in it is as it was */
    rctext = [NSString stringWithContentsOfFile:rc];
    CHECK([rctext hasPrefix:@"# my rc\nOPTIONS=color\n"]);
    CHECK([rctext rangeOfString:@"number_pad:1"].length > 0 && [rctext rangeOfString:@"DECgraphics"].length > 0);
    CHECK([s padMode] == HK_PAD_DIGITS);

    /* keys: the delegate maps cursor keys, and leaves the rest */
    n = [s terminalView:tv translateKey:VT_KEY_UP mods:0 into:b];             CHECK(n == 1 && b[0] == '8');
    n = [s terminalView:tv translateKey:VT_KEY_PGDN mods:VT_MOD_SHIFT into:b]; CHECK(n == 2 && b[0] == 'G' && b[1] == '3');
    n = [s terminalView:tv translateKey:VT_KEY_F1 mods:0 into:b];             CHECK(n == 0);
    [s setPadMode:HK_PAD_LETTERS];
    n = [s terminalView:tv translateKey:VT_KEY_LEFT mods:0 into:b];           CHECK(n == 1 && b[0] == 'h');

    /* the command bar's route: keys typed at the game come back (cat, through the pty's echo) */
    [s sendKeys:"#pray\r"];
    CHECK(wait_for(tv, @"#pray", 3.0));
    for (i = 0; i < hk_command_count(); i++) {                               /* every button sends something */
        const HkCommand *c = hk_command(i);
        CHECK(c && strlen(c->keys) >= 1);
    }

    /* the game ends: its screen is kept, the bar is off */
    CHECK([s endingPath] == nil);
    [s sendKeys:"\004"];
    for (i = 0; i < 60 && [s isRunning]; i++) spin(0.05);
    CHECK(![s isRunning]);
    CHECK([s endingPath] != nil);
    ending = [EndingStore textAtPath:[s endingPath]];
    CHECK(ending != nil && [ending rangeOfString:@"#pray"].length > 0);
    CHECK([[EndingStore pathsForGame:g] count] == 1);

    [s shutdown];
    [[s window] close];
    [s release];

    [fm removeFileAtPath:dir handler:nil];
    [GameConfig setPath:@"" forKey:@"launcher" game:g];
    [GameConfig setPath:@"" forKey:@"hackdir" game:g];
    [GameConfig setPath:@"" forKey:@"rc" game:g];
    printf("session: %s\n", failures ? "FAILED" : "ok");
    [pool release];
    return failures ? 1 : 0;
}
