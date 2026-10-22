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

    /* the interface settings, for each style of game and each way the file can ask */
    {
        const HkGameDef *u = hk_game_by_id("unnethack"), *sl = hk_game_by_id("slashem");
        NSString *urc = [dir stringByAppendingPathComponent:@"crc"], *got;
        int curses = 0;
        [GameConfig setPath:urc forKey:@"rc" game:u];
        [@"# mine\nOPTIONS=!color\n" writeToFile:urc atomically:YES];
        [GameConfig numberPadForGame:u curses:&curses];
        got = [NSString stringWithContentsOfFile:urc];
        CHECK(curses == 1 && [got hasPrefix:@"# mine\nOPTIONS=!color\n"]);
        CHECK([got rangeOfString:@"windowtype:curses"].length > 0 && [got rangeOfString:@"cursesgraphics"].length > 0);
        CHECK([got rangeOfString:@"OPTIONS=color"].length == 0 && [got rangeOfString:@"OPTIONS=perm_invent"].length > 0);  /* !color is respected */
        CHECK([got rangeOfString:@"popup_dialog"].length > 0 && [got rangeOfString:@"splash_screen"].length > 0);
        CHECK([got rangeOfString:@"DECgraphics"].length == 0);                          /* the tty option is not used under curses */

        [@"OPTIONS=windowtype:tty\n" writeToFile:urc atomically:YES];                  /* the file asks for tty: honoured */
        [GameConfig numberPadForGame:u curses:&curses];
        got = [NSString stringWithContentsOfFile:urc];
        CHECK(curses == 0 && [got rangeOfString:@"windowtype:tty"].length > 0 && [got rangeOfString:@"OPTIONS=DECgraphics"].length > 0);
        CHECK([got rangeOfString:@"guicolor"].length == 0);

        [GameConfig setUseCurses:0 forGame:u];                                          /* turned off in Preferences */
        [@"" writeToFile:urc atomically:YES];
        [GameConfig numberPadForGame:u curses:&curses];
        got = [NSString stringWithContentsOfFile:urc];
        CHECK(curses == 0 && [got rangeOfString:@"windowtype"].length == 0 && [got rangeOfString:@"DECgraphics"].length > 0);
        [GameConfig setUseCurses:-1 forGame:u];

        [GameConfig setPath:urc forKey:@"rc" game:sl];                                  /* no curses interface: always tty */
        [@"" writeToFile:urc atomically:YES];
        [GameConfig numberPadForGame:sl curses:&curses];
        got = [NSString stringWithContentsOfFile:urc];
        CHECK(curses == 0 && [got rangeOfString:@"windowtype"].length == 0 && [got rangeOfString:@"OPTIONS=DECgraphics"].length > 0);
        CHECK(![GameConfig useCursesForGame:sl]);
        [GameConfig setPath:@"" forKey:@"rc" game:sl];
        [GameConfig setPath:@"" forKey:@"rc" game:u];
    }

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
        CHECK([GameConfig termForGame:hk_game_by_id("nethack")] == nil);                /* tty on termcap: stephack */
        CHECK([[GameConfig termForGame:hk_game_by_id("nethack") curses:YES] isEqualToString:@"xterm"]);   /* curses: terminfo */
        [GameConfig setPath:@"stephack" forKey:@"term" game:u];
        CHECK([GameConfig termForGame:u] == nil);                              /* the override picks the termcap entry */
        [GameConfig setPath:@"" forKey:@"term" game:u];
        [GameConfig setPath:@"" forKey:@"hackdir" game:u];
        [GameConfig setPath:@"" forKey:@"rc" game:u];
    }

    NSString *flag = [NSHomeDirectory() stringByAppendingPathComponent:@".StepHack.pty"];
    NSString *plog = [NSHomeDirectory() stringByAppendingPathComponent:@".StepHack.ptylog"];
    BOOL hadFlag = [fm fileExistsAtPath:flag];
    if (!hadFlag) [@"" writeToFile:flag atomically:YES];                          /* switch the raw log on for this test */

    s = [[GameSession alloc] initWithGame:g owner:owner];
    CHECK([s startReportingTo:&why]);
    tv = find_terminal([s window]);
    CHECK(tv != nil && [s isRunning]);

    /* the options file got its defaults, and everything else in it is as it was */
    rctext = [NSString stringWithContentsOfFile:rc];
    CHECK([rctext hasPrefix:@"# my rc\nOPTIONS=color\n"]);
    CHECK([rctext rangeOfString:@"number_pad:1"].length > 0);
    CHECK([rctext rangeOfString:@"windowtype:curses"].length > 0 && [rctext rangeOfString:@"symset:DECgraphics"].length > 0);
    CHECK([rctext rangeOfString:@"OPTIONS=guicolor"].length > 0 && [rctext rangeOfString:@"OPTIONS=mouse_support"].length > 0);
    CHECK([s usesCurses] && [tv cols] == 110 && [tv rows] == 32);                 /* the curses interface gets the bigger window */
    CHECK([s padMode] == HK_PAD_DIGITS);

    /* colours: black on white until Preferences says otherwise, then the open window follows */
    CHECK([[[tv defaultBackground] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] redComponent] > 0.9);
    [GameConfig setColourScheme:1];
    [s applyColours];
    CHECK([[[tv defaultBackground] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] redComponent] < 0.1);
    CHECK([GameConfig colourScheme] == 1);
    [GameConfig setColourScheme:0];
    [s applyColours];
    CHECK([[[tv defaultBackground] colorUsingColorSpaceName:NSCalibratedRGBColorSpace] redComponent] > 0.9);

    /* bold text: a bold face of the same width is found where there is one, and the style follows Preferences */
    printf("  (bold face found: %s)\n", [tv hasBoldFont] ? "yes" : "no");
    [GameConfig setBoldStyle:2];
    [s applyColours];
    CHECK([GameConfig boldStyle] == 2);
    [GameConfig setBoldStyle:7];
    CHECK([GameConfig boldStyle] == 0);                                       /* nonsense falls back to the default */
    [GameConfig setBoldStyle:0];
    [s applyColours];

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
    CHECK([owner ended]);                                                   /* a normal exit closed the window by itself */
    ending = [EndingStore textAtPath:[s endingPath]];
    CHECK(ending != nil && [ending rangeOfString:@"#pray"].length > 0);
    CHECK([[EndingStore pathsForGame:g] count] == 1);

    {
        NSString *raw = [NSString stringWithContentsOfFile:plog];
        CHECK(raw != nil && [raw hasPrefix:@"# nethack TERM=xterm curses=1 cols=110 rows=32\n"] && [raw rangeOfString:@"#pray"].length > 0);
        if (!hadFlag) [fm removeFileAtPath:flag handler:nil];
        [fm removeFileAtPath:plog handler:nil];
    }
    [s shutdown];
    [[s window] close];
    [s release];

    /* play modes: the launcher is given -D or -X, and the title says so */
    {
        int modes[3] = { HK_MODE_NORMAL, HK_MODE_WIZARD, HK_MODE_EXPLORE };
        const char *want[3] = { "[]", "[-D]", "[-X]" };
        int k;
        for (k = 0; k < 3; k++) {
            Owner *o3 = [[[Owner alloc] init] autorelease];
            GameSession *s3;
            NSString *l3 = [dir stringByAppendingPathComponent:@"modegame"], *argfile = [dir stringByAppendingPathComponent:@"args"], *got;
            [[NSString stringWithFormat:@"#!/bin/sh\necho \"[$@]\" > %@\nexec cat\n", argfile] writeToFile:l3 atomically:YES];
            chmod([l3 fileSystemRepresentation], 0755);
            [fm removeFileAtPath:argfile handler:nil];
            [GameConfig setPath:l3 forKey:@"launcher" game:g];
            s3 = [[GameSession alloc] initWithGame:g owner:o3];
            [s3 setPlayMode:modes[k]];
            CHECK([s3 startReportingTo:&why]);
            for (i = 0; i < 100 && ![fm fileExistsAtPath:argfile]; i++) spin(0.05);
            got = [NSString stringWithContentsOfFile:argfile];
            CHECK(got != nil && [got hasPrefix:[NSString stringWithCString:want[k]]]);
            if (k == 1) CHECK([[[s3 window] title] rangeOfString:@"wizard mode"].length > 0);
            if (k == 0) CHECK([[[s3 window] title] rangeOfString:@"mode"].length == 0);
            [s3 abandon];
            [[s3 window] close];
            [s3 release];
        }
    }

    /* closing the window of a game in progress hangs it up (the game saves) and waits for it; abandoning kills it */
    {
        NSString *hup = [dir stringByAppendingPathComponent:@"hupgame"], *saved = [dir stringByAppendingPathComponent:@"saved"];
        int round;
        [[NSString stringWithFormat:@"#!/bin/sh\ntrap 'sleep 0.3; echo saved > %@; exit 0' HUP\nwhile :; do sleep 0.1; done\n", saved]
            writeToFile:hup atomically:YES];
        chmod([hup fileSystemRepresentation], 0755);
        [GameConfig setPath:hup forKey:@"launcher" game:g];
        for (round = 0; round < 2; round++) {                              /* 0: close (saves), 1: abandon (does not) */
            Owner *o4 = [[[Owner alloc] init] autorelease];
            GameSession *s4;
            [fm removeFileAtPath:saved handler:nil];
            s4 = [[GameSession alloc] initWithGame:g owner:o4];
            CHECK([s4 startReportingTo:&why]);
            spin(0.4);                                                      /* the shell has set its trap */
            CHECK([s4 isRunning]);
            if (round == 0) { [[s4 window] close]; CHECK([o4 ended]); }
            else { [s4 abandon]; [[s4 window] close]; }
            CHECK(![s4 isRunning]);
            for (i = 0; i < 100 && ![fm fileExistsAtPath:saved]; i++) spin(0.05);
            if (round == 0) CHECK([fm fileExistsAtPath:saved]); else CHECK(![fm fileExistsAtPath:saved]);
            spin(0.5);                                                      /* the closing session finishes by itself */
            [s4 release];
        }
    }

    /* how a game's end is handled: normal -> closes; failed -> stays open; preference off -> stays open */
    {
        struct { const char *body; BOOL closeWhenDone; BOOL expectClosed; const char *what; } cases[3] = {
            { "#!/bin/sh\necho bye\nexit 0\n", YES, YES, "a game that exits normally closes its window" },
            { "#!/bin/sh\necho it broke\nexit 3\n", YES, NO, "a game that fails leaves its window open" },
            { "#!/bin/sh\necho bye\nexit 0\n", NO, NO, "with the preference off the window stays" }
        };
        int k;
        for (k = 0; k < 3; k++) {
            Owner *o2 = [[[Owner alloc] init] autorelease];
            GameSession *s2;
            NSString *l2 = [dir stringByAppendingPathComponent:@"endgame"];
            [[NSString stringWithCString:cases[k].body] writeToFile:l2 atomically:YES];
            chmod([l2 fileSystemRepresentation], 0755);
            [GameConfig setPath:l2 forKey:@"launcher" game:g];
            [GameConfig setCloseWhenDone:cases[k].closeWhenDone];
            s2 = [[GameSession alloc] initWithGame:g owner:o2];
            CHECK([s2 startReportingTo:&why]);
            for (i = 0; i < 100 && [s2 isRunning]; i++) spin(0.05);
            CHECK(![s2 isRunning]);
            if (cases[k].expectClosed) CHECK([o2 ended]); else CHECK(![o2 ended]);
            printf("  [status %d] ", [s2 exitStatus]);
            printf("%s: %s\n", cases[k].what, ([o2 ended] == cases[k].expectClosed) ? "ok" : "FAILED");
            if (k == 1) CHECK([s2 exitStatus] == 3);
            [s2 shutdown];
            [[s2 window] close];
            [s2 release];
        }
        [GameConfig setCloseWhenDone:YES];
    }
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"ColourScheme"];
    [[NSUserDefaults standardUserDefaults] removeObjectForKey:@"BoldStyle"];

    [fm removeFileAtPath:dir handler:nil];
    [GameConfig setPath:@"" forKey:@"launcher" game:g];
    [GameConfig setPath:@"" forKey:@"hackdir" game:g];
    [GameConfig setPath:@"" forKey:@"rc" game:g];
    printf("session: %s\n", failures ? "FAILED" : "ok");
    [pool release];
    return failures ? 1 : 0;
}
