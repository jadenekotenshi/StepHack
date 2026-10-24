#import "GameSession.h"
#import "GameConfig.h"
#import "UIHelpers.h"
#import "GameEnv.h"
#import "Reaper.h"
#import "EndingStore.h"
#include "keymap.h"
#include "commands.h"
#include <stdio.h>
#include <string.h>
#include <stdlib.h>              /* posix_openpt/grantpt/unlockpt/ptsname on the host build */
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/time.h>
#include "oscompat.h"    /* pid_t: must come before <sys/wait.h> below, whose own POSIX-mode
                          * prototypes (wait()/waitpid()) reference pid_t themselves */
/* OPENSTEP 4.2's <sys/wait.h> is dual-mode, gated by _POSIX_SOURCE (confirmed by reading the real
 * header, not guessed): without it, WIFEXITED/WIFSIGNALED are defined against a `union wait`, not
 * a plain int, and WEXITSTATUS/WTERMSIG aren't declared at all. With it, everything is the
 * familiar plain-int POSIX form the rest of this file assumes (applied to a union wait's own
 * .w_status member -- see hk_reap_pending() below -- since waitpid() itself turned out not to be a
 * real, linkable symbol on this system at all: only wait3() is, which needs `union wait` and the
 * NeXT-native declarations _NEXT_SOURCE gates, a separate part of the same header, unconditional
 * on _POSIX_SOURCE's own state so both can be active together). Both defined only around this one
 * include, matching stepscp.c's own established pattern for the exact same kind of gate on
 * <dirent.h>, since a feature-test macro can in principle change what other headers expose too. */
#define _POSIX_SOURCE 1
#define _NEXT_SOURCE 1
#include <sys/wait.h>
#undef _NEXT_SOURCE
#undef _POSIX_SOURCE
#include <sys/ioctl.h>
/* POSIX termios (tcgetattr/tcsetattr) postdates OPENSTEP 4.2: its <termios.h> declares them (no
 * compile error -- and ONLCR itself, once <termios.h> is coaxed into declaring it at all, needs
 * yet another _NEXT_SOURCE dance, both confirmed the hard way) but the real hardware linker
 * reports both as undefined symbols: genuinely unimplemented, not just undeclared -- the exact
 * same class of gap as setsid()/waitpid() in oscompat.h, and StepSSH's tools/clicommon.c hit this
 * identical wall already. What a 4.3BSD-derived system like this genuinely has instead is the much
 * older "sgtty" ioctl interface (TIOCGETP/TIOCSETP, struct sgttyb, both declared unconditionally
 * in <sys/ioctl.h> -- confirmed by reading the real header, no further gating needed) that termios
 * was later built to replace; CRMOD is that era's single combined flag for what POSIX later split
 * into ICRNL (input) and ONLCR (output). */
#ifdef OPENSTEP
#include <sgtty.h>
#else
#include <termios.h>
#endif

#ifndef O_NONBLOCK
#define O_NONBLOCK O_NDELAY
#endif
#ifndef EWOULDBLOCK
#define EWOULDBLOCK EAGAIN
#endif

#define COMMAND_BAR_H 30.0
#define CURSES_COLS 130                  /* the curses interface uses the whole window, so it gets a bigger one */
#define CURSES_ROWS 32
#define TICK_SECONDS 0.02
#define MAX_READS_PER_TICK 64            /* x 16 KB, within TICK_BUDGET seconds */
#define TICK_BUDGET 0.03
#define MORE_WAIT_USEC 4000              /* after a short read, how long to wait for the game's next piece of a refresh */

/* gcc 2.7.2 does not look ahead within an @implementation, so anything called
 * before its definition must be declared here. */
@interface GameSession (Private)
- (void)buildWindow;
- (void)tick:(NSTimer *)t;
- (void)childEnded;
- (void)flushPending;
- (void)buildCommandBarIn:(NSView *)container width:(float)width;
- (void)saveEnding;
- (NSString *)baseTitle;
- (void)closingTick;
- (void)terminalView:(id)tv sendBytes:(const unsigned char *)bytes length:(int)n;
@end

#ifdef OPENSTEP
/* Classic BSD pty device pairs: /dev/pty<letter><hexdigit> (master), /dev/tty<letter><hexdigit>
 * (matching slave) -- the manual scheme every 4.3BSD-heritage system has supported since long
 * before openpty()/posix_openpt() existed, so the one most likely to actually be present on
 * OPENSTEP 4.2 itself. UNVERIFIED on real OPENSTEP hardware: the device nodes are still visible
 * on a modern Mac (`ls /dev/pty*`), but opening any of them now fails there unconditionally with
 * EAGAIN -- confirmed directly, not guessed -- so that could only be checked here for "does the
 * file exist", not "does open() actually work", which is why the host build below uses a
 * different mechanism instead of standing in for this one. If OPENSTEP doesn't have these
 * devices, or open() fails there too, report back exactly what happened. */
static int open_master_pty(char *slave_out)
{
    static const char letters[] = "pqrstuvw";
    static const char digits[] = "0123456789abcdef";
    int li, di;

    for (li = 0; letters[li]; li++) {
        for (di = 0; digits[di]; di++) {
            char master[32];
            int fd;
            sprintf(master, "/dev/pty%c%c", letters[li], digits[di]);
            fd = open(master, O_RDWR);
            if (fd >= 0) {
                sprintf(slave_out, "/dev/tty%c%c", letters[li], digits[di]);
                return fd;
            }
        }
    }
    return -1;
}
#else
/* Host testing only -- NOT what Makefile.openstep builds; see the #ifdef OPENSTEP branch above
 * for that. Modern macOS/Linux want /dev/ptmx + posix_openpt()/grantpt()/unlockpt()/ptsname()
 * instead: confirmed directly that the classic /dev/ptyXX nodes above are only cosmetically
 * present here (open() on any of them fails with EAGAIN, unconditionally), so they cannot stand
 * in for the real thing in a host test -- this lets the rest of GameSession (fork/exec, the poll
 * loop, backpressure, EOF/exit-status handling) still be genuinely exercised against a real
 * forked shell on the dev machine, even though the actual pty-opening mechanism differs. */
static int open_master_pty(char *slave_out)
{
    int fd = posix_openpt(O_RDWR | O_NOCTTY);
    char *name;
    if (fd < 0) return -1;
    if (grantpt(fd) != 0 || unlockpt(fd) != 0) { close(fd); return -1; }
    name = ptsname(fd);
    if (!name) { close(fd); return -1; }
    strcpy(slave_out, name);
    return fd;
}
#endif

#ifdef OPENSTEP
/* wait3() is the only genuinely linkable exit-reaping call on this system (waitpid() is declared
 * by <sys/wait.h> but not actually implemented -- confirmed by a real hardware link failure, not
 * guessed) -- and unlike waitpid(), it can only reap "the next available child", not one specific
 * pid. Harmless with a single session, but a real problem with more than one open at once (each
 * with its own forked child): one session's reap could catch a different session's child. Reaped
 * (pid, status) pairs that don't belong to whoever's tick happened to reap them are stashed here,
 * keyed by pid, for whichever session actually wants that pid to find later. */
typedef struct reaped_child {
    int pid, status;
    struct reaped_child *next;
} reaped_child;
static reaped_child *reaped_list = NULL;

void hk_reap_pending(void)
{
    union wait wstatus;
    int pid;
    for (;;) {
        pid = wait3(&wstatus, WNOHANG, (struct rusage *)0);
        if (pid <= 0) break;
        {
            reaped_child *n = (reaped_child *)malloc(sizeof(*n));
            if (!n) break;
            n->pid = pid;
            n->status = wstatus.w_status;
            n->next = reaped_list;
            reaped_list = n;
        }
    }
}

int hk_reap_child(int pid, int *status_out)
{
    reaped_child **pp;
    hk_reap_pending();
    for (pp = &reaped_list; *pp; pp = &(*pp)->next) {
        if ((*pp)->pid == pid) {
            reaped_child *found = *pp;
            *status_out = found->status;
            *pp = found->next;
            free(found);
            return 1;
        }
    }
    return 0;
}
#else
/* Host testing only: plain waitpid() works fine here (it is the OPENSTEP side that lacks it), and
 * can target a specific pid directly, so there is no shared-cache race to work around at all. */
void hk_reap_pending(void) { }
int hk_reap_child(int pid, int *status_out)
{
    int w = waitpid(pid, status_out, WNOHANG);
    return w == pid;
}
#endif

@implementation GameSession

- (id)initWithGame:(const HkGameDef *)aGame owner:(id)anOwner
{
    self = [super init];
    if (!self) return nil;
    owner = anOwner;
    game = aGame;
    masterFD = -1;
    exitStatus = -1;
    return self;
}

- (void)dealloc
{
    [self shutdown];
    if (pending.p) free(pending.p);
    [window release]; [termView release]; [scroller release];
    [barControls release]; [moreCommands release]; [endingPath release];
    if (rawLog) fclose((FILE *)rawLog);
    [super dealloc];
}

- (NSWindow *)window { return window; }
- (BOOL)isRunning { return state == GS_RUNNING; }
- (int)exitStatus { return exitStatus; }
- (const HkGameDef *)game { return game; }
- (void)setPlayMode:(int)mode { playMode = (mode == HK_MODE_WIZARD || mode == HK_MODE_EXPLORE) ? mode : HK_MODE_NORMAL; }

/* The window title: the game, and the mode when it is not an ordinary game. */
- (NSString *)baseTitle
{
    if (playMode == HK_MODE_NORMAL) return [NSString stringWithCString:game->title];
    return [NSString stringWithFormat:@"%s (%s)", game->title, hk_mode_name(playMode)];
}
- (NSString *)endingPath { return endingPath; }
- (int)padMode { return padMode; }

- (void)applyColours
{
    [termView setBoldStyle:[GameConfig boldStyle]];
    if ([GameConfig colourScheme] == 1)
        [termView setForeground:[NSColor whiteColor] background:[NSColor blackColor]];
    else
        [termView setForeground:[NSColor blackColor] background:[NSColor whiteColor]];
}
- (BOOL)usesCurses { return usesCurses != 0; }
- (void)setPadMode:(int)mode { padMode = mode; }

/* ---------------------------------------------------------------- */
/* window (mirrors SSHSession's buildWindow closely)                */

- (void)buildWindow
{
    static float offset = 0.0;
    NSSize cs;
    float sw = [NSScroller scrollerWidth];
    NSRect content;
    NSView *container;
    NSRect scr = [[NSScreen mainScreen] frame];

    termView = [[TerminalView alloc] initWithFrame:NSMakeRect(0, 0, 100, 100)];
    {   /* (TerminalSettleMS in the defaults overrides the 40 ms; 0 turns the wait off) */
        NSUserDefaults *ud = [NSUserDefaults standardUserDefaults];
        float ms = ([ud objectForKey:@"TerminalSettleMS"] != nil) ? [ud floatForKey:@"TerminalSettleMS"] : 40.0;
        [termView setSettleDelay:ms / 1000.0 max:ms * 3.75 / 1000.0];                   /* show a game's multi-step refresh as one frame */
    }
    if (usesCurses) {
        /* 130 columns, or as many fewer (but never under 80) as the screen has room for */
        int wantCols = CURSES_COLS;
        cs = [termView contentSizeForCols:wantCols rows:CURSES_ROWS];
        while (wantCols > 80 && cs.width + sw > scr.size.width - 24.0) {
            wantCols--;
            cs = [termView contentSizeForCols:wantCols rows:CURSES_ROWS];
        }
    } else {
        cs = [termView contentSizeForCols:80 rows:24];
    }
    content = NSMakeRect(0, 0, cs.width + sw, cs.height + COMMAND_BAR_H);

    window = [[NSWindow alloc] initWithContentRect:content
                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask |
                                                    NSMiniaturizableWindowMask | NSResizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:(id)self];
    [window setMinSize:NSMakeSize(200, 100)];
    if ([window respondsToSelector:@selector(setResizeIncrements:)])      /* snap to whole cells */
        [window setResizeIncrements:NSMakeSize(1, 1)];

    /* Scrollbar on the left, not the right -- genuine OPENSTEP/NeXTSTEP AppKit's own native
     * default for NSScrollView's vertical scroller (NSMinXEdge; it only moves to the right under
     * the NSMacintoshInterfaceStyle/NSWindows95InterfaceStyle compatibility styles, neither of
     * which this app requests). This view's scroller is a plain NSScroller positioned by hand
     * rather than an NSScrollView, so it does not inherit that platform default automatically --
     * placed on the left explicitly here to match it. */
    container = [[NSView alloc] initWithFrame:content];
    [termView setFrame:NSMakeRect(sw, COMMAND_BAR_H, cs.width, cs.height)];
    [termView setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    scroller = [[NSScroller alloc] initWithFrame:NSMakeRect(0, COMMAND_BAR_H, sw, cs.height)];
    [scroller setAutoresizingMask:(NSViewHeightSizable | NSViewMaxXMargin)];
    [container addSubview:termView];
    [container addSubview:scroller];
    [self buildCommandBarIn:container width:cs.width + sw];
    [window setContentView:container];
    [container release];

    [termView setDelegate:self];
    [self applyColours];
    [termView setLocalScrollKeys:NO];                  /* Shift-PgUp/PgDn run northeast/southeast in a game */
    [termView setScroller:scroller];
    [window setTitle:[self baseTitle]];
    [window setFrameTopLeftPoint:NSMakePoint(scr.origin.x + 60 + offset, NSMaxY(scr) - 40 - offset)];
    offset += 24.0;
    if (offset > 240.0) offset = 0.0;
    [window makeKeyAndOrderFront:nil];
    [window makeFirstResponder:termView];
}

- (void)refreshTitle
{
    vt *t = [termView terminal];
    if (t->title_changed) {
        t->title_changed = 0;
        [window setTitle:[NSString stringWithCString:t->title]];
    }
}

/* ---------------------------------------------------------------- */
/* the command bar                                                   */

- (void)buildCommandBarIn:(NSView *)container width:(float)width
{
    NSView *bar = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, width, COMMAND_BAR_H)] autorelease];
    float x = 4.0;
    int i, longest = 4;
    NSPopUpButton *more;

    [bar setAutoresizingMask:(NSViewWidthSizable | NSViewMaxYMargin)];
    barControls = [[NSMutableArray alloc] init];
    moreCommands = [[NSMutableArray alloc] init];

    for (i = 0; i < hk_command_count(); i++) {
        const HkCommand *c = hk_command(i);
        NSButton *b;
        float w;
        if (!hk_command_in(c, game) || !c->main) continue;
        w = 14.0 + 6.5 * (float)strlen(c->label);
        b = ui_button([NSString stringWithCString:c->label], NSMakeRect(x, 4, w, 22), self, @selector(commandButton:));
        [b setFont:[NSFont systemFontOfSize:10.0]];
        [b setTag:i];
        [bar addSubview:b];
        [barControls addObject:b];
        x += w + 3.0;
    }
    /* The menu is as wide as the button, so the button is made wide enough for the longest entry. */
    for (i = 0; i < hk_command_count(); i++) {
        const HkCommand *c = hk_command(i);
        if (hk_command_in(c, game) && !c->main && (int)strlen(c->label) > longest) longest = (int)strlen(c->label);
    }
    more = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(x + 4, 4, 40.0 + 7.0 * (float)longest, 22) pullsDown:YES]
               autorelease];
    [more addItemWithTitle:@"More"];
    for (i = 0; i < hk_command_count(); i++) {
        const HkCommand *c = hk_command(i);
        if (!hk_command_in(c, game) || c->main) continue;
        [more addItemWithTitle:[NSString stringWithCString:c->label]];
        [moreCommands addObject:[NSNumber numberWithInt:i]];
    }
    [more setFont:[NSFont systemFontOfSize:10.0]];
    [more setTarget:self];
    [more setAction:@selector(commandMenu:)];
    [bar addSubview:more];
    [barControls addObject:more];
    [container addSubview:bar];
}

- (void)sendKeys:(const char *)keys
{
    if (state != GS_RUNNING || !keys) return;
    [self terminalView:termView sendBytes:(const unsigned char *)keys length:(int)strlen(keys)];
}

- (void)commandButton:(id)sender
{
    const HkCommand *c = hk_command([sender tag]);
    if (c) [self sendKeys:c->keys];
    [window makeFirstResponder:termView];                     /* typing carries on in the game */
}

- (void)commandMenu:(id)sender
{
    int i = [sender indexOfSelectedItem] - 1;                /* item 0 is the menu's own title */
    if (i >= 0 && i < (int)[moreCommands count]) {
        const HkCommand *c = hk_command([[moreCommands objectAtIndex:i] intValue]);
        if (c) [self sendKeys:c->keys];
    }
    [window makeFirstResponder:termView];
}

/* ---------------------------------------------------------------- */
/* starting the shell                                                */

- (BOOL)startReportingTo:(NSString **)why
{
    char slaveName[64];
    int flags;
    pid_t pid;
    int initCols, initRows;
    NSString *launcher = [GameConfig launcherForGame:game];
    NSString *hackdir = [GameConfig hackdirForGame:game];
    NSString *term;
    NSFileManager *fm = [NSFileManager defaultManager];
    char *launcherC, **env, *argv[3];

    if (![GameConfig isInstalled:game]) {
        if (why) *why = [NSString stringWithFormat:@"%s is not installed where Preferences says it is (%@). "
                         @"Install its package, or set the right path in Preferences.", game->title, launcher];
        return NO;
    }

    /* The options file decides the interface (and gets StepHack's defaults); that decides the terminal and the window. */
    padMode = hk_pad_mode([GameConfig numberPadForGame:game curses:&usesCurses]);
    term = [GameConfig termForGame:game curses:usesCurses != 0];
    SSTrace("%s: options file prepared (number pad %d, curses %d, TERM %s)", game->id, padMode, usesCurses, term ? UI_CPATH(term) : HK_TERM_NAME);

    /* Everything the child needs is prepared before fork(): no Objective-C after it. */
    launcherC = hk_copy_c(UI_CPATH(launcher));
    argv[0] = launcherC;
    argv[1] = hk_mode_arg(playMode) ? hk_copy_c(hk_mode_arg(playMode)) : (char *)0;     /* -D or -X; the launcher passes it on */
    argv[2] = (char *)0;
    /* A game that reads its options file's name from the environment (3.4.3's NETHACKOPTIONS=/path) is given its own file, so that
     * it does not share ~/.nethackrc with versions whose options it does not understand. */
    env = hk_game_environ_with(UI_CPATH(hackdir), term ? UI_CPATH(term) : NULL, game->rc_env,
                               game->rc_env ? UI_CPATH([GameConfig rcPathForGame:game]) : NULL);
    if (!launcherC || !env) { if (why) *why = @"Out of memory."; return NO; }

    [self buildWindow];
    SSTrace("%s: window built", game->id);

    masterFD = open_master_pty(slaveName);
    SSTrace("%s: pty master is descriptor %d", game->id, masterFD);
    if (masterFD < 0) {
        if (why) *why = @"Could not open a pty (no free device).";
        [window close];
        return NO;
    }

    /* Captured before fork() (plain ints, safe to read post-fork in the child) so the child can
     * push the pty's winsize on the slave, before exec, rather than the parent pushing it on the
     * master right after fork() -- which races the child's own open() of the slave: on this host,
     * TIOCSWINSZ/TIOCGWINSZ on the master fails with ENOTTY until the slave has been opened at
     * least once. Setting it from the child guarantees the ordering. */
    initCols = [termView cols];
    initRows = [termView rows];

    pid = fork();
    if (pid < 0) {
        close(masterFD); masterFD = -1;
        if (why) *why = @"Could not start the game (fork failed).";
        [window close];
        return NO;
    }

    if (pid == 0) {
        /* ---- child: becomes the game, on the slave side of the pty ---- */
        int slaveFD;

#ifdef OPENSTEP
        /* setsid() itself doesn't exist here (see oscompat.h's own note) -- the classic BSD
         * equivalent: detach from whatever's currently our controlling tty (inherited from
         * whoever launched this app), then become a new process group leader, so that opening
         * the new pty slave below (having no ctty and being a leader) auto-acquires it as the
         * new controlling terminal, the pre-SysV-TIOCSCTTY BSD convention. Old-style 2-arg
         * setpgrp(pid, pgrp) -- oscompat.h's own note explains why this BSD form, not setsid(). */
        {
            int ttyfd = open("/dev/tty", O_RDWR);
            if (ttyfd >= 0) {
#ifdef TIOCNOTTY
                ioctl(ttyfd, TIOCNOTTY, 0);
#endif
                close(ttyfd);
            }
        }
        setpgrp(0, getpid());
#else
        /* Host testing only: real setsid() works fine here (it is the OPENSTEP side that lacks
         * it, and whose modern BSD-descended setpgrp() takes no arguments at all, unlike the
         * classic 2-arg form above). */
        setsid();
#endif
        slaveFD = open(slaveName, O_RDWR);
        if (slaveFD < 0) _exit(127);
#ifdef TIOCSCTTY
        ioctl(slaveFD, TIOCSCTTY, 0);       /* [V] belt-and-suspenders in case this system ALSO
                                              * needs an explicit claim despite the open()-based
                                              * auto-acquire above; harmless either way if it does */
#endif
        {
            struct winsize ws;
            memset(&ws, 0, sizeof(ws));
            ws.ws_col = (unsigned short)initCols;
            ws.ws_row = (unsigned short)initRows;
            ioctl(slaveFD, TIOCSWINSZ, &ws);
        }
        /* A bare LF only moves the cursor down a row in vt.c (see its own newline_mode, off by
         * default -- correct VT100 behaviour: LF and CR are independent, and a real terminal
         * relies on the pty's own line discipline to translate an application's bare '\n' into
         * "\r\n" before it ever reaches the emulator). Never explicitly configured before, so this
         * only worked by accident of whatever the OS defaults a fresh pty slave to -- apparently
         * ON for posix_openpt() on the host (this exact bug never showed up there), but OFF for
         * OPENSTEP's own classic BSD pty (confirmed on real hardware: readable but "staggered",
         * each line starting one column further right than the last -- exactly what a working LF
         * with no CR looks like). Set explicitly rather than trusted implicitly, on both platforms,
         * so this can't silently depend on a default again. OPENSTEP uses the old sgtty CRMOD flag
         * instead of termios's OPOST|ONLCR -- see this file's own #include block above for why. */
#ifdef OPENSTEP
        {
            struct sgttyb t;
            if (ioctl(slaveFD, TIOCGETP, &t) == 0) {
                t.sg_flags |= CRMOD;
                ioctl(slaveFD, TIOCSETP, &t);
            }
        }
#else
        {
            struct termios t;
            if (tcgetattr(slaveFD, &t) == 0) {
                t.c_oflag |= OPOST | ONLCR;
                tcsetattr(slaveFD, TCSANOW, &t);
            }
        }
#endif
        close(masterFD);
        dup2(slaveFD, 0); dup2(slaveFD, 1); dup2(slaveFD, 2);
        if (slaveFD > 2) close(slaveFD);

        /* The game's own environment: TERM and TERMCAP describe the terminal this window really is (see
         * core/games.c), HACKDIR points at the data directory.  environ is replaced outright because OPENSTEP's
         * libc has no putenv(), and execl() passes on whatever environ holds. */
        {
            extern char **environ;
            environ = env;
        }
        execv(launcherC, argv);
        _exit(127);                                            /* exec failed */
    }

    /* ---- parent ---- */
    SSTrace("%s: forked pid %d", game->id, (int)pid);
    childPID = pid;
    /* A diagnostic: while ~/.StepHack.pty exists, every byte the game writes is also saved, untouched, in
     * ~/.StepHack.ptylog (the file is started afresh for each game), so what a terminal problem really is can be seen. */
    if ([fm fileExistsAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@".StepHack.pty"]]) {
        NSString *lp = [NSHomeDirectory() stringByAppendingPathComponent:@".StepHack.ptylog"];
        rawLog = fopen(UI_CPATH(lp), "wb");
        if (rawLog) {
            fprintf((FILE *)rawLog, "# %s TERM=%s curses=%d cols=%d rows=%d\n", game->id,
                    term ? UI_CPATH(term) : HK_TERM_NAME, usesCurses, initCols, initRows);
            fflush((FILE *)rawLog);
        }
    }
    /* Another: while ~/.StepHack.draw exists, what each redraw cost is written to ~/.StepHack.drawlog (shared by all games). */
    if ([fm fileExistsAtPath:[NSHomeDirectory() stringByAppendingPathComponent:@".StepHack.draw"]]) {
        static FILE *drawLogFile = NULL;
        if (!drawLogFile)
            drawLogFile = fopen(UI_CPATH([NSHomeDirectory() stringByAppendingPathComponent:@".StepHack.drawlog"]), "wb");
        [termView setDrawLog:drawLogFile];
    }
    flags = fcntl(masterFD, F_GETFL, 0);
    fcntl(masterFD, F_SETFL, flags | O_NONBLOCK);
    state = GS_RUNNING;
    timer = [[NSTimer scheduledTimerWithTimeInterval:TICK_SECONDS target:self
                                            selector:@selector(tick:) userInfo:nil repeats:YES] retain];
    return YES;
}

- (void)tick:(NSTimer *)t
{
    unsigned char buf[16384];
    int n;

    if (state == GS_CLOSING) { [self closingTick]; return; }
    if (state != GS_RUNNING) return;
    SSCrumb("GameSession tick: writing pending input");
    [self flushPending];
    hk_reap_pending();                 /* opportunistic: keeps the shared cache fresh for whoever
                                         * needs it (see hk_reap_pending()'s own comment above) */
    /* Take in what has arrived -- more than one read's worth if a flood is under way, while the tick's time budget lasts --
     * and redraw once afterwards (the view's frame cap decides when). A full buffer means there may be more waiting. */
    {
        NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
        int reads = 0;

        do {
            SSCrumb("GameSession tick: reading the pty");
            n = read(masterFD, buf, sizeof(buf));
            if (n > 0) {
                SSCrumb("GameSession tick: feeding the terminal");
                if (rawLog) { fwrite(buf, 1, (size_t)n, (FILE *)rawLog); fflush((FILE *)rawLog); }
                [termView writeBytes:buf length:n];
                reads++;
            }
            if (n > 0 && n < (int)sizeof(buf)) {       /* a short read: the game is probably still writing (the pty holds little,
                                                         * so it is held up until we read) -- give it a moment, don't wait a tick */
                fd_set rf;
                struct timeval tv;
                FD_ZERO(&rf);
                FD_SET(masterFD, &rf);
                tv.tv_sec = 0;
                tv.tv_usec = MORE_WAIT_USEC;
                if (select(masterFD + 1, &rf, NULL, NULL, &tv) <= 0) break;
            }
        } while (n > 0 && reads < MAX_READS_PER_TICK && [NSDate timeIntervalSinceReferenceDate] - t0 < TICK_BUDGET);
        if (reads > 0) [self refreshTitle];
    }
    if (n == 0 || (n < 0 && errno == EIO)) {                   /* EIO: the classic "far end hung up" for a pty */
        [termView flushDisplay];                               /* the last output must show */
        [self childEnded];
    } else if (n < 0 && errno != EWOULDBLOCK && errno != EAGAIN && errno != EINTR) {
        [termView flushDisplay];
        [self childEnded];
    } else {
        [termView flushDisplayIfDue];                          /* includes the trailing flush after a burst has ended */
    }
}

- (void)childEnded
{
    int status = -1;
    if (state != GS_RUNNING) return;
    state = GS_ENDED;
    [timer invalidate];
    [timer release];
    timer = nil;
    /* The pty can reach end-of-file a moment before the process is reapable: give it a little while. */
    {
        int tries, got = hk_reap_child(childPID, &status);
        for (tries = 0; !got && tries < 10; tries++) {
            usleep(20000);
            got = hk_reap_child(childPID, &status);
        }
        if (got) exitStatus = WIFEXITED(status) ? WEXITSTATUS(status)
                            : WIFSIGNALED(status) ? 128 + WTERMSIG(status) : -1;
    }
    if (masterFD >= 0) { close(masterFD); masterFD = -1; }
    SSTrace("%s ended with status %d", game->id, exitStatus);
    [self saveEnding];
    if (rawLog) { fclose((FILE *)rawLog); rawLog = NULL; }
    /* windowWillClose: is the only place that notifies owner, so it happens exactly once whether the game exited first or
     * the user closed a still-running one.  A game that ended normally (status 0) takes its window with it -- what it
     * left on the screen is kept (View Ending).  One that failed leaves the window open, showing its last words. */
    if (exitStatus == 0 && [GameConfig closeWhenDone]) {
        [termView flushDisplay];
        [window close];
        return;
    }
    [window setTitle:[NSString stringWithFormat:@"%@ (finished, status %d)", [self baseTitle], exitStatus]];
}

/* What the game left on the screen -- the tombstone, the final attributes, the high scores -- is kept as text, and the
 * command bar, which would only type into nothing, is switched off. */
- (void)saveEnding
{
    unsigned i;
    NSString *t = [termView transcript:600];

    for (i = 0; i < [barControls count]; i++) [[barControls objectAtIndex:i] setEnabled:NO];
    if ([ui_trim(t) length] == 0) return;
    [endingPath release];
    endingPath = [[EndingStore saveText:t forGame:game] retain];
}

- (void)stopPolling
{
    [timer invalidate];
    [timer release];
    timer = nil;
}

/* Closing the window of a game in progress: the game is told to hang up, which every *hack answers by saving the game
 * and exiting.  The pty stays open, and polled, until it has gone (so that nothing it writes while saving fails), and it is
 * killed only if it is still there after thirty seconds. */
- (void)shutdown
{
    if (state != GS_RUNNING) return;
    if (discardOnClose) { [self abandon]; return; }
    if (childPID > 0) kill(childPID, SIGHUP);
    state = GS_CLOSING;
    closeDeadline = [NSDate timeIntervalSinceReferenceDate] + 30.0;
    if (!timer)                                                   /* (a session that never got as far as polling) */
        timer = [[NSTimer scheduledTimerWithTimeInterval:TICK_SECONDS target:self
                                                selector:@selector(tick:) userInfo:nil repeats:YES] retain];
}

- (void)abandon
{
    if (state != GS_RUNNING && state != GS_CLOSING) return;
    state = GS_ENDED;
    [self stopPolling];
    if (childPID > 0) { int st; kill(childPID, SIGKILL); (void)hk_reap_child(childPID, &st); }
    if (masterFD >= 0) { close(masterFD); masterFD = -1; }
}

/* For quitting the application: waits (polling by hand, the run loop is going away) for a game that was told to hang up. */
- (void)finishClosing:(double)seconds
{
    NSTimeInterval stop = [NSDate timeIntervalSinceReferenceDate] + seconds;
    while (state == GS_CLOSING && [NSDate timeIntervalSinceReferenceDate] < stop) {
        [self closingTick];
        if (state == GS_CLOSING) usleep(50000);
    }
    if (state == GS_CLOSING) [self abandon];                      /* still there: no orphan is left behind */
}

/* While a closed game saves: its output is read and thrown away; when it is gone (or too slow), everything is released. */
- (void)closingTick
{
    unsigned char buf[4096];
    int n, done = 0, st;

    hk_reap_pending();
    do {
        n = read(masterFD, buf, sizeof(buf));
    } while (n == (int)sizeof(buf));
    if (n == 0 || (n < 0 && errno == EIO)) done = 1;
    if (!done && hk_reap_child(childPID, &st)) done = 1;
    if (!done && [NSDate timeIntervalSinceReferenceDate] > closeDeadline) {
        kill(childPID, SIGKILL);
        done = 1;
    }
    if (!done) return;
    {
        int k;                                                    /* collect it, if it has not been already */
        for (k = 0; k < 10 && !hk_reap_child(childPID, &st); k++) usleep(20000);
    }
    state = GS_ENDED;
    [self stopPolling];
    if (masterFD >= 0) { close(masterFD); masterFD = -1; }
}

/* Asked first, if Preferences says so: Save (the default), Close Without Saving (the game is lost), or Cancel. */
- (BOOL)windowShouldClose:(id)sender
{
    int answer;
    if (state != GS_RUNNING || [GameConfig closeAction] != 1) return YES;
    answer = NSRunAlertPanel(@"Close this game?", @"%@", @"Save and Close", @"Close Without Saving", @"Cancel",
                             [NSString stringWithFormat:@"%@ is in progress. Save and Close keeps it for next time; "
                              @"Close Without Saving abandons it.", [self baseTitle]]);
    if (answer == NSAlertDefaultReturn) return YES;
    if (answer == NSAlertAlternateReturn) { discardOnClose = 1; return YES; }
    return NO;
}

/* ---------------------------------------------------------------- */
/* pending writes: a non-blocking pty write can come back short (or EWOULDBLOCK) for a large
 * paste; queued here and retried each tick rather than silently dropped.                     */

- (void)flushPending
{
    int w;
    if (pending.len == 0 || masterFD < 0) return;
    w = write(masterFD, pending.p, pending.len);
    if (w > 0) {
        memmove(pending.p, pending.p + w, pending.len - (size_t)w);
        pending.len -= (size_t)w;
    }
}

- (void)queueBytes:(const unsigned char *)bytes length:(int)n
{
    size_t need = pending.len + (size_t)n;
    if (need > pending.cap) {
        size_t newcap = pending.cap ? pending.cap * 2 : 4096;
        unsigned char *np;
        while (newcap < need) newcap *= 2;
        np = (unsigned char *)realloc(pending.p, newcap);
        if (!np) return;                                       /* out of memory: drop rather than crash */
        pending.p = np;
        pending.cap = newcap;
    }
    memcpy(pending.p + pending.len, bytes, (size_t)n);
    pending.len += (size_t)n;
}

/* ---------------------------------------------------------------- */
/* TerminalView delegate                                            */

- (void)terminalView:(id)tv sendBytes:(const unsigned char *)bytes length:(int)n
{
    if (state != GS_RUNNING) return;
    if (pending.len) { [self queueBytes:bytes length:n]; return; }
    {
        int w = write(masterFD, bytes, (size_t)n);
        if (w < 0) w = 0;
        if (w < n) [self queueBytes:bytes + w length:n - w];
    }
}

- (int)terminalView:(id)tv translateKey:(int)key mods:(int)mods into:(unsigned char *)bytes
{
    return hk_map_key(padMode, key, mods, bytes);
}

- (void)terminalView:(id)tv resizedToCols:(int)cols rows:(int)rows
{
    struct winsize ws;
    if (state != GS_RUNNING) return;
    memset(&ws, 0, sizeof(ws));
    ws.ws_col = (unsigned short)cols;
    ws.ws_row = (unsigned short)rows;
    ioctl(masterFD, TIOCSWINSZ, &ws);                          /* [V] confirm this ioctl exists on OPENSTEP */
}

/* ---------------------------------------------------------------- */
/* window delegate                                                  */

- (void)windowWillClose:(NSNotification *)notification
{
    SSTrace("%s: its window is closing (state %d)", game->id, state);
    [self shutdown];
    [window setDelegate:nil];
    [owner sessionDidEnd:self];
}

- (void)windowDidResize:(NSNotification *)notification
{
    [termView fitToFrame];
}

@end
