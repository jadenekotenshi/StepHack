#import "Compat.h"
#import "TerminalView.h"
#include "games.h"
#include <stddef.h>

/* A growable byte queue, just big enough for GameSession's own pending-write buffer -- not the
 * general sbuf StepSSH's protocol code needs (SSH wire-format framing), so not copied over. */
typedef struct { unsigned char *p; size_t len, cap; } pty_pending;

enum { GS_RUNNING = 1, GS_ENDED, GS_CLOSING };    /* CLOSING: the window is gone, the game was told to hang up (and save) and is being waited for */

/* One game window: the window and its TerminalView, a pty pair, a forked child running the game on the slave
 * side, and a 20ms poll loop reading the master side into the view.  Derived from StepTTY's PTYSession (one class
 * owns its window, its terminal view and the session logic, and is the window's own close delegate), including the
 * poll-loop model, proven reliable on real OPENSTEP hardware where async NSFileHandle notifications are not. */
@interface GameSession : NSObject
{
    int            masterFD;
    int            childPID;
    int            state;
    int            exitStatus;
    NSTimer       *timer;
    id             owner;
    const HkGameDef *game;
    int            usesCurses;         /* the game runs with its curses interface: a larger window */
    int            playMode;           /* HK_MODE_* */
    int            discardOnClose;     /* closing the window abandons the game instead of saving it */
    NSTimeInterval closeDeadline;      /* a closing game that is still there at this time is killed */
    int            padMode;            /* HK_PAD_*: how the cursor keys are turned into movement */
    pty_pending    pending;            /* bytes not yet accepted by a non-blocking write() */

    NSWindow      *window;
    TerminalView  *termView;
    NSScroller    *scroller;
    NSMutableArray *barControls;       /* the command bar's buttons and menu, disabled when the game is over */
    NSMutableArray *moreCommands;      /* command indices behind the More menu's items */
    void          *rawLog;             /* FILE * of everything the game wrote, while ~/.StepHack.pty exists (a diagnostic) */
    NSString      *endingPath;         /* where this game's ending was saved, once it is over */
}
- (id)initWithGame:(const HkGameDef *)aGame owner:(id)anOwner;
/* Opens a pty, forks the game's launcher on its slave side and starts polling.  NO on failure (the launcher is
 * missing, no free pty, or fork itself failed) -- no window is left open in that case, and *why receives a sentence
 * for the caller to show.  why may be NULL. */
- (BOOL)startReportingTo:(NSString **)why;
- (const HkGameDef *)game;
- (void)setPlayMode:(int)mode;              /* before -start...: HK_MODE_WIZARD runs the game with -D, HK_MODE_EXPLORE with -X */
- (void)finishClosing:(double)seconds;     /* after -shutdown: waits for the game to save and exit, and kills it if it takes longer than this */
- (void)abandon;                           /* kills the game at once, unsaved (for "Close Without Saving") */
- (int)padMode;
- (BOOL)usesCurses;
- (NSString *)endingPath;            /* the saved ending screen once the game is over, else nil */
- (void)applyColours;                      /* the terminal colours chosen in Preferences */
- (void)sendKeys:(const char *)keys;     /* as if typed */
- (void)commandButton:(id)sender;
- (void)commandMenu:(id)sender;
- (void)setPadMode:(int)mode;      /* HK_PAD_*: Game > Keypad, when the game's own setting was changed in play */
- (BOOL)isRunning;
- (int)exitStatus;                 /* -1 while still running or if it couldn't be determined */
- (NSWindow *)window;
/* SIGHUPs the child if still running and stops polling; safe to call more than once. */
- (void)shutdown;
@end

/* Informal protocol implemented by whoever creates a GameSession (AppController). */
@interface NSObject (GameSessionOwner)
- (void)sessionDidEnd:(GameSession *)session;
@end
