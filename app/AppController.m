#import "AppController.h"
#import "PrefsController.h"
#import "UIHelpers.h"
#include "keymap.h"

/* Menu item tags: a game's index in the game table, and the keypad modes. */
enum { TAG_PAD_LETTERS = 100, TAG_PAD_DIGITS, TAG_PAD_PHONE, TAG_PAD_QWERTZ };

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

- (void)buildMenu
{
    NSMenu *main = [[[NSMenu alloc] initWithTitle:@"StepHack"] autorelease];
    NSMenu *m, *games;
    int i;

    m = [self submenuNamed:@"Game" inMenu:main];
    games = [self submenuNamed:@"New Game" inMenu:m];
    for (i = 0; i < hk_game_count(); i++) {
        id item = [self addItem:[NSString stringWithCString:hk_game(i)->title] action:@selector(newGame:)
                            key:@"" target:self toMenu:games];
        [item setTag:i];
    }
    [self addItem:@"New Game Again" action:@selector(newLastGame:) key:@"n" target:self toMenu:m];
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
    NSLog(@"StepHack: applicationDidFinishLaunching");
    SSTrace("applicationDidFinishLaunching");
    [self newGame:nil];
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
