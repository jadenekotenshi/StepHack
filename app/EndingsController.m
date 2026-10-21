#import "EndingsController.h"
#import "EndingStore.h"
#import "UIHelpers.h"

static NSMutableDictionary *controllers = nil;

@interface EndingsController (Private)
- (id)initForGame:(const HkGameDef *)g;
- (void)buildWindow;
- (void)reloadSelecting:(NSString *)path;
@end

@implementation EndingsController

+ (EndingsController *)controllerForGame:(const HkGameDef *)g
{
    NSString *key = [NSString stringWithCString:g->id];
    EndingsController *c;
    if (!controllers) controllers = [[NSMutableDictionary alloc] init];
    c = [controllers objectForKey:key];
    if (!c) {
        c = [[[EndingsController alloc] initForGame:g] autorelease];
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
    [window release]; [paths release];
    [super dealloc];
}

- (void)buildWindow
{
    NSScrollView *scroll;
    NSView *v;
    NSRect f;

    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 700, 480)
                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask |
                                                    NSMiniaturizableWindowMask | NSResizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setMinSize:NSMakeSize(420, 220)];
    [window setTitle:[NSString stringWithFormat:@"%s Endings", game->title]];
    v = [window contentView];
    f = [v frame];

    pop = [[NSPopUpButton alloc] initWithFrame:NSMakeRect(12, f.size.height - 34, 300, 24) pullsDown:NO];
    [pop setTarget:self];
    [pop setAction:@selector(choose:)];
    [pop setAutoresizingMask:NSViewMinYMargin];
    [v addSubview:pop];
    {
        NSButton *b = ui_button(@"Copy All", NSMakeRect(324, f.size.height - 35, 88, 26), self, @selector(copyAll:));
        [b setAutoresizingMask:NSViewMinYMargin];
        [v addSubview:b];
        b = ui_button(@"Save As...", NSMakeRect(418, f.size.height - 35, 96, 26), self, @selector(saveAs:));
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
    [text setHorizontallyResizable:YES];
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

- (void)reloadSelecting:(NSString *)path
{
    unsigned i;
    int select = 0;

    [paths release];
    paths = [[EndingStore pathsForGame:game] retain];
    [pop removeAllItems];
    for (i = 0; i < [paths count]; i++) {
        [pop addItemWithTitle:[EndingStore titleForPath:[paths objectAtIndex:i] game:game]];
        if (path && [[paths objectAtIndex:i] isEqualToString:path]) select = (int)i;
    }
    if ([paths count] == 0) {
        [text setString:[NSString stringWithFormat:@"No ending of %s has been saved yet.\\n\\n"
                         @"When a game in a StepHack window finishes, what it left on the screen (the tombstone, the "
                         @"final attributes and inventory, the high scores) is kept here.\\n", game->title]];
        return;
    }
    [pop selectItemAtIndex:select];
    [self choose:nil];
}

- (void)choose:(id)sender
{
    int i = [pop indexOfSelectedItem];
    NSString *s;
    if (i < 0 || i >= (int)[paths count]) return;
    s = [EndingStore textAtPath:[paths objectAtIndex:i]];
    [text setString:s ? s : @"The saved ending could not be read.\\n"];
    [text scrollRangeToVisible:NSMakeRange(0, 0)];
}

- (void)copyAll:(id)sender
{
    NSPasteboard *pb = [NSPasteboard generalPasteboard];
    [pb declareTypes:[NSArray arrayWithObject:NSStringPboardType] owner:nil];
    [pb setString:[text string] forType:NSStringPboardType];
}

- (void)saveAs:(id)sender
{
    NSSavePanel *sp = [NSSavePanel savePanel];
    int i = [pop indexOfSelectedItem];
    NSData *d;
    if (i < 0 || i >= (int)[paths count]) return;
    if ([sp runModalForDirectory:NSHomeDirectory() file:@"ending.txt"] != NSOKButton) return;
    d = [[text string] dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    if (![d writeToFile:[sp filename] atomically:YES])
        NSRunAlertPanel(@"Save", @"%@", @"OK", nil, nil, [NSString stringWithFormat:@"Could not write %@.", [sp filename]]);
}

- (void)showWindowSelecting:(NSString *)path
{
    if (!window) [self buildWindow];
    [self reloadSelecting:path];
    [window makeKeyAndOrderFront:nil];
}

@end
