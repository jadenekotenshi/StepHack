#import "OptionsController.h"
#import "GameConfig.h"
#import "UIHelpers.h"
#include <stdlib.h>
#include <string.h>

#define WIN_W      560.0
#define WIN_H      600.0
#define DOC_W      500.0
#define ROW_PAD    4.0
#define LABEL_W    300.0
#define CONTROL_X  316.0
#define CONTROL_W  176.0

static NSMutableDictionary *controllers = nil;

@interface OptionsController (Private)
- (id)initForGame:(const HkGameDef *)g;
- (void)buildWindow;
- (void)buildRows;
- (void)loadFile;
- (void)refreshControls;
- (void)syncFields;
- (void)setDirty:(BOOL)flag;
- (BOOL)writeFile;
- (BOOL)alwaysWrite:(const HkSchemaItem *)it;
@end

@implementation OptionsController

+ (OptionsController *)controllerForGame:(const HkGameDef *)g
{
    NSString *key = [NSString stringWithCString:g->id];
    OptionsController *c;
    if (!controllers) controllers = [[NSMutableDictionary alloc] init];
    c = [controllers objectForKey:key];
    if (!c) {
        c = [[[OptionsController alloc] initForGame:g] autorelease];
        [controllers setObject:c forKey:key];
    }
    return c;
}

- (id)initForGame:(const HkGameDef *)g
{
    char *text;
    self = [super init];
    if (!self) return nil;
    game = g;
    text = hks_builtin(g->schema);
    if (text) { schema = hks_parse(text); free(text); }
    controls = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    hks_free(schema);
    hkrc_free(rc);
    [path release]; [controls release]; [window release];
    [super dealloc];
}

/* Options whose default the front end changes itself (see GameConfig): they are written even when equal to the game's own. */
- (BOOL)alwaysWrite:(const HkSchemaItem *)it
{
    if (strcmp(it->name, "number_pad") == 0) return YES;
    if (game->line_option && strcmp(it->name, game->line_option) == 0) return YES;
    return NO;
}

/* ---------------------------------------------------------------- */
/* the file                                                         */

- (void)loadFile
{
    NSData *data;
    hkrc_free(rc);
    [path release];
    path = [[GameConfig rcPathForGame:game] retain];
    data = [NSData dataWithContentsOfFile:path];
    rc = hkrc_parse(data ? (const char *)[data bytes] : "", data ? [data length] : 0);
}

- (BOOL)writeFile
{
    size_t len;
    char *text = hkrc_text(rc, &len);
    NSData *out;
    BOOL ok;
    if (!text) return NO;
    out = [NSData dataWithBytes:text length:len];
    free(text);
    ok = [out writeToFile:path atomically:YES];
    if (!ok) NSRunAlertPanel(@"Options", @"%@", @"OK", nil, nil, [NSString stringWithFormat:@"Could not write %@.", path]);
    return ok;
}

/* ---------------------------------------------------------------- */
/* window                                                           */

- (void)buildRows
{
    float y, total = 0.0;
    int i, n = hks_count(schema);
    NSView *doc;
    NSScrollView *scroll;
    float heights[400];
    char v[64], l[160];

    /* First the heights, so that the rows can be placed from the top of an unflipped view. */
    for (i = 0; i < n && i < 400; i++) {
        switch (hks_item(schema, i)->kind) {
        case HKS_GROUP: heights[i] = 34.0; break;
        case HKS_BOOL: heights[i] = 22.0 + ROW_PAD; break;
        default: heights[i] = 32.0 + ROW_PAD; break;
        }
        total += heights[i];
    }
    total += 8.0;
    doc = [[[NSView alloc] initWithFrame:NSMakeRect(0, 0, DOC_W, total)] autorelease];
    y = total - 4.0;
    for (i = 0; i < n && i < 400; i++) {
        const HkSchemaItem *it = hks_item(schema, i);
        id ctl = nil;
        float top = y;

        y -= heights[i];
        switch (it->kind) {
        case HKS_GROUP: {
            NSTextField *h = ui_label([NSString stringWithCString:it->name], NSMakeRect(4, top - 26, DOC_W - 8, 18));
            [h setFont:[NSFont boldSystemFontOfSize:12.0]];
            [doc addSubview:h];
            ctl = [NSObject class];
            break;
        }
        case HKS_BOOL: {
            NSButton *b = ui_switch([NSString stringWithCString:it->label], NSMakeRect(8, y + ROW_PAD / 2, DOC_W - 16, 22));
            [b setTarget:self];
            [b setAction:@selector(controlChanged:)];
            [b setTag:i];
            [doc addSubview:b];
            ctl = b;
            break;
        }
        case HKS_ENUM: {
            NSPopUpButton *p = [[[NSPopUpButton alloc] initWithFrame:NSMakeRect(CONTROL_X, y + ROW_PAD / 2 + 4, CONTROL_W, 24)
                                                           pullsDown:NO] autorelease];
            int k;
            for (k = 0; hks_choice(it, k, v, sizeof(v), l, sizeof(l)); k++)
                [p addItemWithTitle:[NSString stringWithCString:l]];
            [p setTarget:self];
            [p setAction:@selector(controlChanged:)];
            [p setTag:i];
            [doc addSubview:ui_wrapping_label([NSString stringWithCString:it->label],
                                              NSMakeRect(8, y + ROW_PAD / 2, LABEL_W, 30), NO)];
            [doc addSubview:p];
            ctl = p;
            break;
        }
        default: {                                         /* HKS_INT, HKS_TEXT */
            NSTextField *f = ui_field(NSMakeRect(CONTROL_X, y + ROW_PAD / 2 + 4, it->kind == HKS_INT ? 70.0 : CONTROL_W, 22));
            [f setTarget:self];
            [f setAction:@selector(controlChanged:)];
            [f setDelegate:self];
            [f setTag:i];
            [doc addSubview:ui_wrapping_label([NSString stringWithCString:it->label],
                                              NSMakeRect(8, y + ROW_PAD / 2, LABEL_W, 30), NO)];
            [doc addSubview:f];
            ctl = f;
            break;
        }
        }
        [controls addObject:ctl];
    }

    scroll = [[[NSScrollView alloc] initWithFrame:NSMakeRect(12, 54, WIN_W - 24, WIN_H - 54 - 44)] autorelease];
    [scroll setHasVerticalScroller:YES];
    [scroll setHasHorizontalScroller:NO];
    [scroll setBorderType:NSBezelBorder];
    [scroll setDocumentView:doc];
    [[window contentView] addSubview:scroll];
    [doc scrollPoint:NSMakePoint(0, total)];                /* start at the top */
}

- (void)buildWindow
{
    NSView *v;

    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, WIN_W, WIN_H)
                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask |
                                                    NSMiniaturizableWindowMask | NSResizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setDelegate:(id)self];
    [window setMinSize:NSMakeSize(WIN_W, 300)];
    v = [window contentView];

    pathLabel = ui_label(@"", NSMakeRect(12, WIN_H - 34, WIN_W - 24, 18));
    [pathLabel setAutoresizingMask:(NSViewWidthSizable | NSViewMinYMargin)];
    [v addSubview:pathLabel];

    [self buildRows];

    saveButton = ui_button(@"Save", NSMakeRect(WIN_W - 100, 14, 88, 26), self, @selector(save:));
    [saveButton setAutoresizingMask:NSViewMinXMargin];
    [v addSubview:saveButton];
    {
        NSButton *rv = ui_button(@"Revert", NSMakeRect(WIN_W - 196, 14, 88, 26), self, @selector(revert:));
        [rv setAutoresizingMask:NSViewMinXMargin];
        [v addSubview:rv];
    }
    {
        NSTextField *note = ui_label(@"Changes apply to games started afterwards.", NSMakeRect(12, 18, 280, 18));
        [note setAutoresizingMask:NSViewMaxXMargin];
        [v addSubview:note];
    }
    [window center];
}

/* ---------------------------------------------------------------- */
/* showing the file's values                                        */

- (void)refreshControls
{
    int i, n = hks_count(schema);
    char val[256], v[64], l[160];

    for (i = 0; i < n && i < (int)[controls count]; i++) {
        const HkSchemaItem *it = hks_item(schema, i);
        id ctl = [controls objectAtIndex:i];

        if (it->kind == HKS_GROUP) continue;
        hks_effective(rc, it, val, sizeof(val));
        switch (it->kind) {
        case HKS_BOOL:
            [ctl setState:(val[0] == '1') ? NSOnState : NSOffState];
            break;
        case HKS_ENUM: {
            int idx = hks_choice_index(it, val), k, count = 0;
            for (k = 0; hks_choice(it, k, v, sizeof(v), l, sizeof(l)); k++) count++;
            while ([ctl numberOfItems] > count) [ctl removeItemAtIndex:[ctl numberOfItems] - 1];       /* a value of its own, shown before */
            if (idx < 0) {                                  /* a value the schema doesn't list: show it as it is */
                [ctl addItemWithTitle:[NSString stringWithCString:val]];
                idx = count;
            }
            [ctl selectItemAtIndex:idx];
            break;
        }
        default:
            [ctl setStringValue:[NSString stringWithCString:val]];
            break;
        }
    }
    [pathLabel setStringValue:path];
}

/* Text and number fields are applied when Return is pressed or the field is left, and again here before saving. */
- (void)syncFields
{
    int i, n = hks_count(schema);
    char cur[256];

    [window makeFirstResponder:window];                     /* ends any editing in progress */
    for (i = 0; i < n && i < (int)[controls count]; i++) {
        const HkSchemaItem *it = hks_item(schema, i);
        id ctl = [controls objectAtIndex:i];
        const char *now;

        if (it->kind != HKS_INT && it->kind != HKS_TEXT) continue;
        now = UI_CPATH(ui_trim([ctl stringValue]));
        hks_effective(rc, it, cur, sizeof(cur));
        if (strcmp(now, cur) != 0 || (!hks_is_set(rc, it) && now[0] != '\0' && strcmp(now, it->def) != 0)) {
            hks_apply(rc, it, now, [self alwaysWrite:it]);
            [self setDirty:YES];
        }
    }
}

- (void)setDirty:(BOOL)flag
{
    dirty = flag;
    [window setDocumentEdited:flag];
    [saveButton setEnabled:flag];
}

- (void)controlChanged:(id)sender
{
    int i = [sender tag];
    const HkSchemaItem *it = hks_item(schema, i);
    char v[64], l[160];

    if (!it) return;
    switch (it->kind) {
    case HKS_BOOL:
        hks_apply(rc, it, ([sender state] == NSOnState) ? "1" : "0", [self alwaysWrite:it]);
        break;
    case HKS_ENUM:
        if (hks_choice(it, [sender indexOfSelectedItem], v, sizeof(v), l, sizeof(l)))
            hks_apply(rc, it, v, [self alwaysWrite:it]);
        break;
    default:
        hks_apply(rc, it, UI_CPATH(ui_trim([sender stringValue])), [self alwaysWrite:it]);
        break;
    }
    [self setDirty:YES];
    [self refreshControls];                                 /* shows what was really written, e.g. a clamped number */
}

- (void)controlTextDidChange:(NSNotification *)note
{
    [self setDirty:YES];
}

- (void)save:(id)sender
{
    [self syncFields];
    if ([self writeFile]) [self setDirty:NO];
}

- (void)revert:(id)sender
{
    [self loadFile];
    [self refreshControls];
    [self setDirty:NO];
}

- (void)showWindow
{
    if (!schema) {
        NSRunAlertPanel([NSString stringWithCString:game->title], @"%@", @"OK", nil, nil,
                        @"This game has no list of options yet.");
        return;
    }
    if (!window) {
        [self loadFile];
        [self buildWindow];
        [window setTitle:[NSString stringWithFormat:@"%s Options", game->title]];
        [self refreshControls];
        [self setDirty:NO];
    } else if (!dirty) {
        [self loadFile];                                    /* picks up changes made to the file elsewhere */
        [self refreshControls];
    }
    [window makeKeyAndOrderFront:nil];
}

/* Closing with unsaved changes asks first. */
- (BOOL)windowShouldClose:(id)sender
{
    int answer;
    [self syncFields];
    if (!dirty) return YES;
    answer = NSRunAlertPanel(@"Options", @"%@", @"Save", @"Don't Save", @"Cancel",
                             [NSString stringWithFormat:@"Save the changes to %@?", path]);
    if (answer == NSAlertDefaultReturn) { [self save:nil]; return !dirty; }
    if (answer == NSAlertAlternateReturn) { [self revert:nil]; return YES; }
    return NO;
}

@end
