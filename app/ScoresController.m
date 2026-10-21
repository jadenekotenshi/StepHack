#import "ScoresController.h"
#import "GameConfig.h"
#import "ProcessRunner.h"
#import "UIHelpers.h"
#include <stdlib.h>
#include <string.h>
#include "xlog.h"

enum { SRC_RECENT = 0, SRC_BEST, SRC_MINE, SRC_ALL };

static NSMutableDictionary *controllers = nil;

@interface ScoresController (Private)
- (id)initForGame:(const HkGameDef *)g;
- (void)buildWindow;
- (NSString *)xlogPath;
- (NSString *)textForSource:(int)source;
@end

@implementation ScoresController

+ (ScoresController *)controllerForGame:(const HkGameDef *)g
{
    NSString *key = [NSString stringWithCString:g->id];
    ScoresController *c;
    if (!controllers) controllers = [[NSMutableDictionary alloc] init];
    c = [controllers objectForKey:key];
    if (!c) {
        c = [[[ScoresController alloc] initForGame:g] autorelease];
        [controllers setObject:c forKey:key];
    }
    return c;
}

- (id)initForGame:(const HkGameDef *)g
{
    self = [super init];
    if (!self) return nil;
    game = g;
    return self;
}

- (void)dealloc
{
    [window release];
    [super dealloc];
}

- (NSString *)xlogPath
{
    return [[GameConfig hackdirForGame:game] stringByAppendingPathComponent:@"xlogfile"];
}

- (void)buildWindow
{
    NSScrollView *scroll;
    NSView *v;
    NSRect f;
    int i;
    NSArray *names = [NSArray arrayWithObjects:@"Latest games", @"Best games", @"High scores (yours)",
                                               @"High scores (everyone)", nil];

    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 760, 360)
                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask |
                                                    NSMiniaturizableWindowMask | NSResizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setMinSize:NSMakeSize(420, 200)];
    [window setTitle:[NSString stringWithFormat:@"%s Scores", game->title]];
    v = [window contentView];
    f = [v frame];

    sourcePop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(12, f.size.height - 34, 230, 24) pullsDown:NO];
    for (i = 0; i < (int)[names count]; i++) [sourcePop addItemWithTitle:[names objectAtIndex:i]];
    [sourcePop setTarget:self];
    [sourcePop setAction:@selector(sourceChanged:)];
    [sourcePop setAutoresizingMask:NSViewMinYMargin];
    [v addSubview:sourcePop];
    {
        NSButton *b = ui_button(@"Refresh", NSMakeRect(254, f.size.height - 35, 88, 26), self, @selector(refresh:));
        [b setAutoresizingMask:NSViewMinYMargin];
        [v addSubview:b];
    }

    scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(12, 12, f.size.width - 24, f.size.height - 54)] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setHasHorizontalScroller:YES];
    [scroll setBorderType:NSBezelBorder];
    [scroll setAutoresizingMask:(NSViewWidthSizable | NSViewHeightSizable)];
    text = [[NSTextView alloc] initWithFrame:[[scroll contentView] frame]];
    [text setEditable:NO];
    [text setSelectable:YES];
    [text setRichText:NO];
    [text setFont:[NSFont userFixedPitchFontOfSize:11.0]];
    [text setVerticallyResizable:YES];
    [text setHorizontallyResizable:YES];                    /* lines are long: scroll sideways rather than wrap */
    [text setAutoresizingMask:NSViewNotSizable];
    [text setMinSize:NSMakeSize(0, 0)];
    [text setMaxSize:NSMakeSize(1.0e7, 1.0e7)];
    [[text textContainer] setWidthTracksTextView:NO];
    [[text textContainer] setContainerSize:NSMakeSize(1.0e7, 1.0e7)];
    [scroll setDocumentView:text];
    [text release];
    [v addSubview:scroll];
    [window center];
}

- (NSString *)textForSource:(int)source
{
    if (source == SRC_RECENT || source == SRC_BEST) {
        NSData *data = [NSData dataWithContentsOfFile:[self xlogPath]];
        HkXlog *x;
        char *report;
        NSString *s;
        if (!data) {
            return [NSString stringWithFormat:@"This game keeps no record of finished games here (%@ is missing).\n\n"
                    @"Choose High scores from the menu above to see its own list.\n", [self xlogPath]];
        }
        x = hkx_parse((const char *)[data bytes], [data length]);
        if (!x) return @"Out of memory.\n";
        report = hkx_report(x, source == SRC_BEST ? HKX_BEST : HKX_RECENT, 200);
        hkx_free(x);
        if (!report) return @"Out of memory.\n";
        s = ui_string_from_utf8(report);
        free(report);
        return s;
    } else {
        NSArray *args = (source == SRC_ALL) ? [NSArray arrayWithObjects:@"-s", @"all", nil] : [NSArray arrayWithObject:@"-s"];
        NSString *out = [ProcessRunner outputOfProgram:[GameConfig launcherForGame:game] arguments:args
                                               hackdir:[GameConfig hackdirForGame:game] seconds:8.0];
        if (!out) return @"The game could not be run to read its score list.\n";
        if ([ui_trim(out) length] == 0) return @"The game printed no score list.\n";
        return out;
    }
}

- (void)refresh:(id)sender
{
    [text setString:[self textForSource:[sourcePop indexOfSelectedItem]]];
    [text scrollRangeToVisible:NSMakeRange(0, 0)];
}

- (void)sourceChanged:(id)sender
{
    [self refresh:nil];
}

- (void)showWindow
{
    if (!window) {
        [self buildWindow];
        /* Start on the game log when there is one; else on the program's own list. */
        [sourcePop selectItemAtIndex:[[NSFileManager defaultManager] fileExistsAtPath:[self xlogPath]] ? SRC_RECENT : SRC_ALL];
    }
    [self refresh:nil];
    [window makeKeyAndOrderFront:nil];
}

@end
