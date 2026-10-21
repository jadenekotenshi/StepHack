#import "PrefsController.h"
#import "GameConfig.h"
#import "UIHelpers.h"
#include "games.h"

static PrefsController *shared = nil;

@interface PrefsController (Private)
- (void)buildWindow;
- (void)load;
- (void)store;
@end

@implementation PrefsController

+ (PrefsController *)sharedController
{
    if (!shared) shared = [[PrefsController alloc] init];
    return shared;
}

- (void)buildWindow
{
    NSRect content = NSMakeRect(0, 0, 480, 236);
    NSView *v;
    int i;

    window = [[NSWindow alloc] initWithContentRect:content
                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setTitle:@"StepHack Preferences"];
    [window setDelegate:(id)self];
    v = [window contentView];

    [v addSubview:ui_label(@"Game:", NSMakeRect(16, 196, 110, 18))];
    gamePop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(130, 192, 330, 24) pullsDown:NO];
    for (i = 0; i < hk_game_count(); i++) [gamePop addItemWithTitle:[NSString stringWithCString:hk_game(i)->title]];
    [gamePop setTarget:self];
    [gamePop setAction:@selector(gameChanged:)];
    [v addSubview:gamePop];

    [v addSubview:ui_label(@"Program:", NSMakeRect(16, 160, 110, 18))];
    launcherField = ui_field(NSMakeRect(130, 158, 334, 22));
    [v addSubview:launcherField];
    [v addSubview:ui_label(@"Data directory:", NSMakeRect(16, 128, 110, 18))];
    hackdirField = ui_field(NSMakeRect(130, 126, 334, 22));
    [v addSubview:hackdirField];
    [v addSubview:ui_label(@"Options file:", NSMakeRect(16, 96, 110, 18))];
    rcField = ui_field(NSMakeRect(130, 94, 334, 22));
    [v addSubview:rcField];

    padSwitch = ui_switch(@"Move with the number pad: add number_pad:1 to an options file that doesn't set it",
                          NSMakeRect(16, 54, 448, 30));
    [padSwitch setTarget:self];
    [padSwitch setAction:@selector(padChanged:)];
    [v addSubview:padSwitch];

    [v addSubview:ui_button(@"Restore Defaults", NSMakeRect(16, 14, 130, 26), self, @selector(restoreDefaults:))];
    [window center];
}

- (void)load
{
    const HkGameDef *g = hk_game(shown);
    if (!g) return;
    [launcherField setStringValue:[GameConfig launcherForGame:g]];
    [hackdirField setStringValue:[GameConfig hackdirForGame:g]];
    [rcField setStringValue:[GameConfig rcPathForGame:g]];
    [padSwitch setState:[GameConfig defaultToNumberPad] ? NSOnState : NSOffState];
}

/* A value equal to the built-in default is stored as "unset", so a later change of the default reaches it. */
- (void)store
{
    const HkGameDef *g = hk_game(shown);
    NSString *s;
    if (!g || !window) return;
    s = ui_trim([launcherField stringValue]);
    [GameConfig setPath:[s isEqualToString:[NSString stringWithCString:g->launcher]] ? @"" : s forKey:@"launcher" game:g];
    s = ui_trim([hackdirField stringValue]);
    [GameConfig setPath:[s isEqualToString:[NSString stringWithCString:g->hackdir]] ? @"" : s forKey:@"hackdir" game:g];
    s = ui_trim([rcField stringValue]);
    [GameConfig setPath:[s isEqualToString:[[NSHomeDirectory() stringByAppendingPathComponent:
                                                [NSString stringWithCString:g->rcname]] description]] ? @"" : s
                 forKey:@"rc" game:g];
}

- (void)showWindow
{
    if (!window) [self buildWindow];
    shown = [gamePop indexOfSelectedItem];
    if (shown < 0) shown = 0;
    [self load];
    [window makeKeyAndOrderFront:nil];
}

- (void)gameChanged:(id)sender
{
    [self store];                                   /* keep what was typed for the game just left */
    shown = [gamePop indexOfSelectedItem];
    [self load];
}

- (void)restoreDefaults:(id)sender
{
    const HkGameDef *g = hk_game(shown);
    if (!g) return;
    [GameConfig setPath:@"" forKey:@"launcher" game:g];
    [GameConfig setPath:@"" forKey:@"hackdir" game:g];
    [GameConfig setPath:@"" forKey:@"rc" game:g];
    [self load];
}

- (void)padChanged:(id)sender
{
    [GameConfig setDefaultToNumberPad:([padSwitch state] == NSOnState)];
}

- (void)windowWillClose:(NSNotification *)notification
{
    [self store];
}

@end
