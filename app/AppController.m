#import "AppController.h"
#import "PrefsController.h"
#import "OptionsController.h"
#import "ScoresController.h"
#import "GameConfig.h"
#import "EndingsController.h"
#import "UIHelpers.h"
#include "keymap.h"

/* Menu item tags: a game's index in the game table, and the keypad modes. */
enum { TAG_PAD_LETTERS = 100, TAG_PAD_DIGITS, TAG_PAD_PHONE, TAG_PAD_QWERTZ };

/* gcc 2.7.2 does not look ahead within an @implementation, so anything called before its definition must be declared. */
@interface AppController (Private)
- (void)startGameIndex:(int)index;
- (void)rebuildGamesMenu;
- (int)defaultGameIndex;
@end

@implementation AppController

- (id)init
{
    self = [super init];
    if (!self) return nil;
    sessions = [[NSMutableArray alloc] init];
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

- (NSMenu *)submenuNamed:(NSString *)title inMenu:(NSMenu *)parent
{
    NSMenu *sub = [[NSMenu alloc] initWithTitle:title];
    id item = [parent addItemWithTitle:title action:NULL keyEquivalent:@""];
    [parent setSubmenu:sub forItem:item];
    return [sub autorelease];
}

/* The New Game menu lists the games found on this machine, and a way to look again. */
- (void)rebuildGamesMenu
{
    NSArray *old = [gamesMenu itemArray];
    int i, found = 0;
    unsigned k;

    for (k = [old count]; k > 0; k--) [gamesMenu removeItem:[old objectAtIndex:k - 1]];
    for (i = 0; i < hk_game_count(); i++) {
        id item;
        if (![GameConfig isInstalled:hk_game(i)]) continue;
        item = [self addItem:[NSString stringWithFormat:@"%s%s", hk_game(i)->title, hk_game(i)->verified ? "" : " (untested)"]
                      action:@selector(newGame:) key:@"" target:self toMenu:gamesMenu];
        [item setTag:i];
        found++;
    }
    if (found == 0) [self addItem:@"No games found" action:NULL key:@"" target:nil toMenu:gamesMenu];
    [self addItem:@"Look for Games Again" action:@selector(rescanGames:) key:@"" target:self toMenu:gamesMenu];
    if ([gamesMenu respondsToSelector:@selector(sizeToFit)]) [gamesMenu sizeToFit];
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

- (void)buildMenu
{
    NSMenu *main = [[[NSMenu alloc] initWithTitle:@"StepHack"] autorelease];
    NSMenu *m;

    m = [self submenuNamed:@"Game" inMenu:main];
    gamesMenu = [self submenuNamed:@"New Game" inMenu:m];
    [self rebuildGamesMenu];
    [self addItem:@"New Game Again" action:@selector(newLastGame:) key:@"n" target:self toMenu:m];
    [self addItem:@"Options..." action:@selector(showOptions:) key:@"o" target:self toMenu:m];
    [self addItem:@"Scores..." action:@selector(showScores:) key:@"s" target:self toMenu:m];
    [self addItem:@"View Ending..." action:@selector(showEnding:) key:@"e" target:self toMenu:m];
    [self addItem:@"Close Window" action:@selector(performClose:) key:@"w" target:nil toMenu:m];

    keypadMenu = [self submenuNamed:@"Keypad" inMenu:m];
    [[self addItem:@"Number keys (number_pad)" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
        setTag:TAG_PAD_DIGITS];
    [[self addItem:@"Phone layout" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
        setTag:TAG_PAD_PHONE];
    [[self addItem:@"Letter keys (hjklyubn)" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
        setTag:TAG_PAD_LETTERS];
    [[self addItem:@"Letter keys, y and z swapped" action:@selector(setKeypad:) key:@"" target:self toMenu:keypadMenu]
        setTag:TAG_PAD_QWERTZ];

    m = [self submenuNamed:@"Edit" inMenu:main];
    [self addItem:@"Copy" action:@selector(copy:) key:@"c" target:nil toMenu:m];
    [self addItem:@"Paste" action:@selector(paste:) key:@"v" target:nil toMenu:m];
    [self addItem:@"Select All" action:@selector(selectAll:) key:@"a" target:nil toMenu:m];
    [self addItem:@"Clear Scrollback" action:@selector(clearScrollback:) key:@"k" target:nil toMenu:m];

    [self addItem:@"Preferences..." action:@selector(showPreferences:) key:@"," target:self toMenu:main];

    m = [self submenuNamed:@"Windows" inMenu:main];
    [self addItem:@"Arrange in Front" action:@selector(arrangeInFront:) key:@"" target:nil toMenu:m];
    [self addItem:@"Miniaturize Window" action:@selector(performMiniaturize:) key:@"m" target:nil toMenu:m];
    [NSApp setWindowsMenu:m];

    m = [self submenuNamed:@"Services" inMenu:main];
    [NSApp setServicesMenu:m];

    [self addItem:@"Hide" action:@selector(hide:) key:@"h" target:NSApp toMenu:main];
    [self addItem:@"Quit" action:@selector(terminate:) key:@"q" target:NSApp toMenu:main];

    [NSApp setMainMenu:main];
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

- (void)applicationDidFinishLaunching:(NSNotification *)notification
{
    int first = [self defaultGameIndex];
    NSLog(@"StepHack: applicationDidFinishLaunching");
    SSTrace("applicationDidFinishLaunching");
    if (first < 0) {
        NSRunAlertPanel(@"StepHack", @"%@", @"OK", nil, nil,
                        @"No game was found. Install one (its package puts the program in /usr/local/bin), or tell "
                        @"Preferences where it is; the New Game menu lists the games that can be started.");
        [self showPreferences:nil];
        return;
    }
    lastGame = first;
    [self startGameIndex:first];
}

/* Coming back to the application is when a package may have been installed meanwhile. */
- (void)applicationDidBecomeActive:(NSNotification *)notification
{
    [self rebuildGamesMenu];
}

/* ---------------------------------------------------------------- */
/* games                                                            */

- (void)startGameIndex:(int)index
{
    const HkGameDef *g = hk_game(index);
    GameSession *s;
    NSString *why = nil;

    if (!g) return;
    lastGame = index;
    [GameConfig setLastGameId:[NSString stringWithCString:g->id]];
    s = [[GameSession alloc] initWithGame:g owner:self];
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
    int index = (sender && [sender respondsToSelector:@selector(tag)]) ? [sender tag] : lastGame;
    [self startGameIndex:index];
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
