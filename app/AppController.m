#import "AppController.h"
#import "PrefsController.h"
#import "OptionsController.h"
#import "ScoresController.h"
#import "SysconfController.h"
#import "GameConfig.h"
#import "EndingsController.h"
#import "UIHelpers.h"
#include "keymap.h"

/* Menu item tags: a game's index in the game table, and the keypad modes. */
enum { TAG_PAD_LETTERS = 100, TAG_PAD_DIGITS, TAG_PAD_PHONE, TAG_PAD_QWERTZ, TAG_SYSCONF };

/* gcc 2.7.2 does not look ahead within an @implementation, so anything called before its definition must be declared. */
@interface AppController (Private)
- (void)startGameIndex:(int)index;
- (void)buildFullMenu;
- (int)menuParts;
- (void)startGameIndex:(int)index mode:(int)mode;
- (NSMenu *)keepMenu:(NSMenu *)menu;
- (void)rebuildGamesMenu;
- (NSString *)installedSignature;
- (void)addModeMenus;
- (void)fillGamesMenu:(NSMenu *)menu mode:(int)mode;
- (int)defaultGameIndex;
@end

@implementation AppController

- (id)init
{
    self = [super init];
    if (!self) return nil;
    sessions = [[NSMutableArray alloc] init];
    menuKeepers = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    [sessions release];
    [super dealloc];
}

/* ---------------------------------------------------------------- */
/* menus                                                            */

- (id)addItem:(NSString *)title action:(SEL)action key:(NSString *)key
       target:(id)target toMenu:(NSMenu *)menu
{
    id item = [menu addItemWithTitle:title action:action keyEquivalent:key];
    if (target) [item setTarget:target];
    return item;
}

/* This AppKit does not keep the menus it is given: not the main menu (NSApp setMainMenu:), nor a submenu of another (setSubmenu:
 * forItem:), nor the Windows and Services menus.  It keeps pointers to them and uses them whenever the application is
 * activated, so a menu that is only autoreleased is freed when the pool it was made in is drained, and the activation then
 * sends messages to freed objects (the system log says "message respondsToSelector: sent to freed object") and the
 * application dies.  Built before the event loop that pool lasted the whole run, by accident; every menu is therefore held
 * here for the life of the program. */
- (NSMenu *)keepMenu:(NSMenu *)menu
{
    [menuKeepers addObject:menu];
    return menu;
}

- (int)menuCount { return (int)[menuKeepers count]; }

- (NSMenu *)submenuNamed:(NSString *)title inMenu:(NSMenu *)parent
{
    NSMenu *sub = [[NSMenu alloc] initWithTitle:title];
    id item = [parent addItemWithTitle:title action:NULL keyEquivalent:@""];
    [parent setSubmenu:sub forItem:item];
    [self keepMenu:sub];
    return [sub autorelease];
}

/* The New Game menu lists the games found on this machine, and a way to look again. */
/* Menu item tags: a game's index in the table plus 256 times its play mode. */
#define TAG_MODE_SHIFT 256

- (void)fillGamesMenu:(NSMenu *)menu mode:(int)mode
{
    NSArray *old = [menu itemArray];
    int i, found = 0;
    unsigned k;

    for (k = [old count]; k > 0; k--) {
        id gone = [old objectAtIndex:k - 1];
        [menuKeepers addObject:gone];               /* held on: AppKit may still hold the item (the log said "hash sent to freed object") */
        [menu removeItem:gone];
    }
    for (i = 0; i < hk_game_count(); i++) {
        id item;
        if (![GameConfig isInstalled:hk_game(i)]) continue;
        item = [self addItem:[NSString stringWithFormat:@"%s%s", hk_game(i)->title, hk_game(i)->verified ? "" : " (untested)"]
                      action:@selector(newGame:) key:@"" target:self toMenu:menu];
        [item setTag:i + TAG_MODE_SHIFT * mode];
        found++;
    }
    if (found == 0) [self addItem:@"No games found" action:NULL key:@"" target:nil toMenu:menu];
    if (mode == HK_MODE_NORMAL) [self addItem:@"Look for Games Again" action:@selector(rescanGames:) key:@"" target:self toMenu:menu];
    if (launched && [menu respondsToSelector:@selector(sizeToFit)]) [menu sizeToFit];
}

/* The New Game menus list the games found on this machine, and (the first) a way to look again. */
- (void)rebuildGamesMenu
{
    [installedSig release];
    installedSig = [[self installedSignature] retain];
    if (gamesMenu) [self fillGamesMenu:gamesMenu mode:HK_MODE_NORMAL];
    if (wizardMenu) [self fillGamesMenu:wizardMenu mode:HK_MODE_WIZARD];
    if (exploreMenu) [self fillGamesMenu:exploreMenu mode:HK_MODE_EXPLORE];
}

- (void)coloursChanged:(id)sender
{
    unsigned i;
    for (i = 0; i < [sessions count]; i++) [[sessions objectAtIndex:i] applyColours];
}

- (void)rescanGames:(id)sender
{
    [self rebuildGamesMenu];
}

/* The game to start when none is named: the one played last if it is installed, else the first that is; -1 if none is. */
- (int)defaultGameIndex
{
    NSString *last = [GameConfig lastGameId];
    int i;

    if (last) {
        const HkGameDef *g = hk_game_by_id(UI_CPATH(last));
        if (g && [GameConfig isInstalled:g]) {
            for (i = 0; i < hk_game_count(); i++) if (hk_game(i) == g) return i;
        }
    }
    for (i = 0; i < hk_game_count(); i++) if ([GameConfig isInstalled:hk_game(i)]) return i;
    return -1;
}

/* What goes up before the application runs: a main menu with Quit and nothing else.  A launch from Workspace is waiting for
 * the application to start running, and on a slow machine the many menu items of the real menu, made first, were enough to
 * make it give up; the real menus are built in applicationDidFinishLaunching. */
- (void)buildMenu
{
    NSMenu *main;
    id item;

    if ([[NSUserDefaults standardUserDefaults] integerForKey:@"MenuPreRun"] == 1) {      /* a test: the way StepTTY does it */
        SSTrace("buildMenu: the real menu, before the event loop");
        [self buildFullMenu];
        menusBuilt = YES;
        return;
    }
    main = [self keepMenu:[[[NSMenu alloc] initWithTitle:@"StepHack"] autorelease]];
    item = [main addItemWithTitle:@"Quit" action:@selector(terminate:) keyEquivalent:@"q"];
    [item setTarget:NSApp];
    SSTrace("buildMenu: minimal menu");
    [NSApp setMainMenu:main];
}

/* Which parts of the menu are built, for finding what a window system objects to: the MenuParts default (defaults write
 * StepHack MenuParts n), every part if unset.  The bits: 1 the Game menu (without submenus), 2 the Edit menu, 4 the
 * Preferences item, 8 the Windows menu, 16 Hide, 32 the submenus (New Game, Keypad), 64 Services.  Quit is always there. */
enum { MP_GAME = 1, MP_EDIT = 2, MP_PREFS = 4, MP_WINDOWS = 8, MP_HIDE = 16, MP_SUBMENUS = 32, MP_SERVICES = 64, MP_ALL = 127 };

- (int)menuParts
{
    NSUserDefaults *d = [NSUserDefaults standardUserDefaults];
    int parts = ([d objectForKey:@"MenuParts"] == nil) ? MP_ALL : [d integerForKey:@"MenuParts"];
    return parts & MP_ALL;
}

- (void)buildFullMenu
{
    NSMenu *main = [self keepMenu:[[[NSMenu alloc] initWithTitle:@"StepHack"] autorelease]];
    NSMenu *m;
    int parts = [self menuParts];

    SSTrace("buildFullMenu: start (menu parts %d)", parts);
    menuLevel = (parts & MP_SUBMENUS) ? 3 : 1;
    if (parts & MP_GAME) {
        m = [self submenuNamed:@"Game" inMenu:main];
        gameMenu = m;
        SSTrace("buildFullMenu: the Game menu exists");
        if (parts & MP_SUBMENUS) gamesMenu = [self submenuNamed:@"New Game" inMenu:m];
        [self addItem:@"New Game Again" action:@selector(newLastGame:) key:@"n" target:self toMenu:m];
        [self addItem:@"Options..." action:@selector(showOptions:) key:@"o" target:self toMenu:m];
        [[self addItem:@"System Settings..." action:@selector(showSysconf:) key:@"" target:self toMenu:m] setTag:TAG_SYSCONF];
        [self addItem:@"Scores..." action:@selector(showScores:) key:@"s" target:self toMenu:m];
        [self addItem:@"View Ending..." action:@selector(showEnding:) key:@"e" target:self toMenu:m];
        [self addItem:@"Close Window" action:@selector(performClose:) key:@"w" target:nil toMenu:m];

        if (parts & MP_SUBMENUS) {
            keypadMenu = [self submenuNamed:@"Keypad" inMenu:m];
            [[self addItem:@"Number keys (number_pad)" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
                setTag:TAG_PAD_DIGITS];
            [[self addItem:@"Phone layout" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
                setTag:TAG_PAD_PHONE];
            [[self addItem:@"Letter keys (hjklyubn)" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
                setTag:TAG_PAD_LETTERS];
            [[self addItem:@"Letter keys, y and z swapped" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
                setTag:TAG_PAD_QWERTZ];
        }
    }
    SSTrace("buildFullMenu: Game menu done");
    if (parts & MP_EDIT) {
        m = [self submenuNamed:@"Edit" inMenu:main];
        [self addItem:@"Copy" action:@selector(copy:) key:@"c" target:nil toMenu:m];
        [self addItem:@"Paste" action:@selector(paste:) key:@"v" target:nil toMenu:m];
        [self addItem:@"Select All" action:@selector(selectAll:) key:@"a" target:nil toMenu:m];
        [self addItem:@"Clear Scrollback" action:@selector(clearScrollback:) key:@"k" target:nil toMenu:m];
    }
    if (parts & MP_PREFS) [self addItem:@"Preferences..." action:@selector(showPreferences:) key:@"," target:self toMenu:main];
    if (parts & MP_WINDOWS) {
        m = [self submenuNamed:@"Windows" inMenu:main];
        [self addItem:@"Arrange in Front" action:@selector(arrangeInFront:) key:@"" target:nil toMenu:m];
        [self addItem:@"Miniaturize Window" action:@selector(performMiniaturize:) key:@"m" target:nil toMenu:m];
        [NSApp setWindowsMenu:m];
    }
    if (parts & MP_SERVICES) {
        m = [self submenuNamed:@"Services" inMenu:main];
        [NSApp setServicesMenu:m];
    }
    if (parts & MP_HIDE) [self addItem:@"Hide" action:@selector(hide:) key:@"h" target:NSApp toMenu:main];
    [self addItem:@"Quit" action:@selector(terminate:) key:@"q" target:NSApp toMenu:main];

    SSTrace("buildFullMenu: setting the main menu");
    [NSApp setMainMenu:main];
    SSTrace("buildFullMenu: done");
}

/* The frontmost game window's session, or nil. */
- (GameSession *)frontSession
{
    NSWindow *w = [NSApp keyWindow];
    unsigned i;
    if (!w) return nil;
    for (i = 0; i < [sessions count]; i++)
        if ([[sessions objectAtIndex:i] window] == w) return [sessions objectAtIndex:i];
    return nil;
}

- (BOOL)validateMenuItem:(id)item
{
    int tag = [item tag];
    if (!launched) return tag < TAG_PAD_LETTERS || tag > TAG_SYSCONF ? YES : NO;      /* (nothing is looked up before the application runs) */
    if (tag == TAG_SYSCONF) {                                  /* only for a game that has a sysconf file */
        GameSession *fs = [self frontSession];
        const HkGameDef *fg = fs ? [fs game] : hk_game(lastGame);
        return fg != NULL && [SysconfController hasSysconfForGame:fg];
    }
    if (tag >= TAG_PAD_LETTERS && tag <= TAG_PAD_QWERTZ) {
        GameSession *s = [self frontSession];
        int mode = HK_PAD_LETTERS;
        switch (tag) {
        case TAG_PAD_DIGITS: mode = HK_PAD_DIGITS; break;
        case TAG_PAD_PHONE: mode = HK_PAD_PHONE; break;
        case TAG_PAD_QWERTZ: mode = HK_PAD_LETTERS_QWERTZ; break;
        }
        [item setState:(s && [s padMode] == mode) ? NSOnState : NSOffState];
        return s != nil;
    }
    return YES;
}

/* ---------------------------------------------------------------- */
/* startup                                                          */

/* The wizard and explore mode menus are made once the application is running: creating them while the menus were being
 * built stopped a launch from Workspace dead (a launch of the binary itself was fine). */
- (void)addModeMenus
{
    id item;

    if (wizardMenu || menuLevel < 3 || !gameMenu) return;
    SSTrace("adding the wizard mode menu");
    wizardMenu = [self keepMenu:[[[NSMenu alloc] initWithTitle:@"New Wizard Mode Game"] autorelease]];
    item = [gameMenu insertItemWithTitle:@"New Wizard Mode Game" action:NULL keyEquivalent:@"" atIndex:1];
    [gameMenu setSubmenu:wizardMenu forItem:item];
    SSTrace("adding the explore mode menu");
    exploreMenu = [self keepMenu:[[[NSMenu alloc] initWithTitle:@"New Explore Mode Game"] autorelease]];
    item = [gameMenu insertItemWithTitle:@"New Explore Mode Game" action:NULL keyEquivalent:@"" atIndex:2];
    [gameMenu setSubmenu:exploreMenu forItem:item];
}

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    int first;
    NSLog(@"StepHack: applicationDidFinishLaunching");
    launched = YES;
    if (!menusBuilt) {
        SSTrace("applicationDidFinishLaunching: building the menus");
        [self buildFullMenu];
    }
    first = [self defaultGameIndex];
    [self addModeMenus];
    SSTrace("applicationDidFinishLaunching: filling the game menus");
    [self rebuildGamesMenu];
    SSTrace("applicationDidFinishLaunching: first game index %d (last played: %s)", first,
            [GameConfig lastGameId] ? UI_CPATH([GameConfig lastGameId]) : "(none)");
    if (first < 0) {
        SSTrace("no installed game found: alert and Preferences");
        NSRunAlertPanel(@"StepHack", @"%@", @"OK", nil, nil,
                        @"No game was found. Install one (its package puts the program in /usr/local/bin), or tell "
                        @"Preferences where it is; the New Game menu lists the games that can be started.");
        [self showPreferences:nil];
        return;
    }
    lastGame = first;
    if ([[NSUserDefaults standardUserDefaults] objectForKey:@"AutoStart"] != nil &&
        [[NSUserDefaults standardUserDefaults] integerForKey:@"AutoStart"] == 0) {         /* a test: no game window at launch */
        SSTrace("AutoStart is 0: no game started");
        return;
    }
    [self startGameIndex:first];
    SSTrace("start-up finished with %u game window(s)", (unsigned)[sessions count]);
}

/* Coming back to the application is when a package may have been installed meanwhile. */
/* One string naming the installed games, to tell whether the menus need rebuilding. */
- (NSString *)installedSignature
{
    NSMutableString *sig = [NSMutableString string];
    int i;
    for (i = 0; i < hk_game_count(); i++) [sig appendString:[GameConfig isInstalled:hk_game(i)] ? @"1" : @"0"];
    return sig;
}

- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    NSString *sig;
    SSTrace("the application became active");
    if (!launched) return;
    sig = [self installedSignature];
    if (installedSig && [sig isEqualToString:installedSig]) return;        /* nothing changed: leave the menus alone */
    [installedSig release];
    installedSig = [sig retain];
    [self rebuildGamesMenu];
    SSTrace("the game menus were rebuilt (%s)", UI_CPATH(sig));
}

- (void)applicationDidResignActive:(NSNotification *)notification
{
    SSTrace("the application resigned active");
}

/* Quitting hangs up the games that are still running (which saves them), waits a few seconds for them to finish, and
 * kills what is left, so that no game is left running without a window. */
- (void)applicationWillTerminate:(NSNotification *)notification
{
    unsigned i;
    SSTrace("the application will terminate (%u game window(s) open)", (unsigned)[sessions count]);
    for (i = 0; i < [sessions count]; i++) [[sessions objectAtIndex:i] shutdown];
    for (i = 0; i < [sessions count]; i++) [[sessions objectAtIndex:i] finishClosing:5.0];
    SSTrace("the games have been dealt with");
}

/* ---------------------------------------------------------------- */
/* games                                                            */

- (void)startGameIndex:(int)index
{
    [self startGameIndex:index mode:HK_MODE_NORMAL];
}

- (void)startGameIndex:(int)index mode:(int)mode
{
    const HkGameDef *g = hk_game(index);
    GameSession *s;
    NSString *why = nil;

    if (!g) return;
    SSTrace("starting %s (mode %d)", g->id, mode);
    lastGame = index;
    [GameConfig setLastGameId:[NSString stringWithCString:g->id]];
    s = [[GameSession alloc] initWithGame:g owner:self];
    [s setPlayMode:mode];
    if (![s startReportingTo:&why]) {
        NSRunAlertPanel([NSString stringWithCString:g->title], @"%@", @"OK", nil, nil,
                        why ? why : @"The game could not be started.");
        [s release];
        return;
    }
    [sessions addObject:s];
    [s release];
}

- (void)newGame:(id)sender
{
    int tag = (sender && [sender respondsToSelector:@selector(tag)]) ? [sender tag] : lastGame;
    [self startGameIndex:tag % TAG_MODE_SHIFT mode:tag / TAG_MODE_SHIFT];
}

- (void)newLastGame:(id)sender
{
    [self startGameIndex:lastGame];
}

- (void)setKeypad:(id)sender
{
    GameSession *s = [self frontSession];
    if (!s) return;
    switch ([sender tag]) {
    case TAG_PAD_DIGITS: [s setPadMode:HK_PAD_DIGITS]; break;
    case TAG_PAD_PHONE: [s setPadMode:HK_PAD_PHONE]; break;
    case TAG_PAD_QWERTZ: [s setPadMode:HK_PAD_LETTERS_QWERTZ]; break;
    default: [s setPadMode:HK_PAD_LETTERS]; break;
    }
}

- (void)showOptions:(id)sender
{
    GameSession *s = [self frontSession];
    const HkGameDef *g = s ? [s game] : hk_game(lastGame);
    if (g) [[OptionsController controllerForGame:g] showWindow];
}

- (void)showSysconf:(id)sender
{
    GameSession *s = [self frontSession];
    const HkGameDef *g = s ? [s game] : hk_game(lastGame);
    if (g && [SysconfController hasSysconfForGame:g]) [[SysconfController controllerForGame:g] showWindow];
}

- (void)showScores:(id)sender
{
    GameSession *s = [self frontSession];
    const HkGameDef *g = s ? [s game] : hk_game(lastGame);
    if (g) [[ScoresController controllerForGame:g] showWindow];
}

- (void)showEnding:(id)sender
{
    GameSession *s = [self frontSession];
    const HkGameDef *g = s ? [s game] : hk_game(lastGame);
    if (g) [[EndingsController controllerForGame:g] showWindowSelecting:s ? [s endingPath] : nil];
}

- (void)showPreferences:(id)sender
{
    [[PrefsController sharedController] showWindow];
}

- (void)sessionDidEnd:(GameSession *)session
{
    [[session retain] autorelease];                     /* it is still on the stack in windowWillClose: */
    [sessions removeObject:session];
}

@end
