#import "SysconfController.h"
#import "GameConfig.h"
#import "UIHelpers.h"
#include <stdlib.h>
#include <string.h>
#include <unistd.h>
#include <sys/types.h>
#include <grp.h>
#include <sys/param.h>
#include "backup.h"

#define WIN_W   560.0
#define ROW_H   54.0

static NSMutableDictionary *controllers = nil;

@interface SysconfController (Private)
- (id)initForGame:(const HkGameDef *)g;
- (void)buildWindow;
- (void)loadFile;
- (void)refreshControls;
- (NSString *)explanation;
@end

/* True if the current user is root or in the named group. */
static BOOL user_in_group(const char *name)
{
    struct group *gr;
    int list[NGROUPS], n, i;

    if (geteuid() == 0) return YES;
    gr = getgrnam(name);
    if (!gr) return NO;
    if ((int)getegid() == (int)gr->gr_gid || (int)getgid() == (int)gr->gr_gid) return YES;
    n = getgroups(NGROUPS, list);
    for (i = 0; i < n; i++) if (list[i] == (int)gr->gr_gid) return YES;
    return NO;
}

@implementation SysconfController

+ (SysconfController *)controllerForGame:(const HkGameDef *)g
{
    NSString *key = [NSString stringWithCString:g->id];
    SysconfController *c;
    if (!controllers) controllers = [[NSMutableDictionary alloc] init];
    c = [controllers objectForKey:key];
    if (!c) {
        c = [[[SysconfController alloc] initForGame:g] autorelease];
        [controllers setObject:c forKey:key];
    }
    return c;
}

+ (BOOL)hasSysconfForGame:(const HkGameDef *)g
{
    NSString *p;
    if (!g->sysconf) return NO;
    p = [[GameConfig hackdirForGame:g] stringByAppendingPathComponent:[NSString stringWithCString:g->sysconf]];
    return [[NSFileManager defaultManager] fileExistsAtPath:p];
}

- (id)initForGame:(const HkGameDef *)g
{
    self = [super init];
    if (!self) return nil;
    game = g;
    controls = [[NSMutableArray alloc] init];
    return self;
}

- (void)dealloc
{
    hksc_free(sc);
    [path release]; [controls release]; [window release];
    [super dealloc];
}

- (void)loadFile
{
    NSData *data;
    hksc_free(sc);
    [path release];
    path = [[[GameConfig hackdirForGame:game] stringByAppendingPathComponent:[NSString stringWithCString:game->sysconf]] retain];
    data = [NSData dataWithContentsOfFile:path];
    sc = hksc_parse(data ? (const char *)[data bytes] : "", data ? [data length] : 0);
    editable = data != nil && [[NSFileManager defaultManager] isWritableFileAtPath:path];
}

/* Why the file can or cannot be changed. */
- (NSString *)explanation
{
    if (editable) return [NSString stringWithFormat:@"%@ -- you can change it.", path];
    return [NSString stringWithFormat:@"%@ -- read only. It should belong to root and group wheel with mode 664 so that members "
            @"of wheel can edit it (as root: chgrp wheel and chmod 664 on it). You are %s group wheel.",
            path, user_in_group("wheel") ? "in" : "not in"];
}

- (void)buildWindow
{
    NSView *v;
    int i, n = hksc_key_count();
    float total = 70.0 + n * ROW_H + 16.0 + 36.0, y;

    window = [[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, WIN_W, total + 40.0)
                                         styleMask:(NSTitledWindowMask | NSClosableWindowMask | NSMiniaturizableWindowMask)
                                           backing:NSBackingStoreBuffered
                                             defer:NO];
    [window setReleasedWhenClosed:NO];
    [window setTitle:[NSString stringWithFormat:@"%s System Settings", game->title]];
    v = [window contentView];
    total += 40.0;

    statusLabel = ui_wrapping_label(@"", NSMakeRect(16, total - 62, WIN_W - 32, 52), YES);
    [v addSubview:statusLabel];

    y = total - 70.0;
    for (i = 0; i < n; i++) {
        const HkSysconfKey *k = hksc_key(i);
        id ctl;
        y -= ROW_H;
        [v addSubview:ui_label([NSString stringWithCString:k->label], NSMakeRect(16, y + 28, 130, 18))];
        if (k->kind == HKSC_BOOL) {
            ctl = ui_switch(@"On", NSMakeRect(156, y + 26, 100, 22));
        } else {
            ctl = ui_field(NSMakeRect(156, y + 26, k->kind == HKSC_INT ? 70.0 : WIN_W - 172.0, 22));
        }
        [v addSubview:ctl];
        [controls addObject:ctl];
        [v addSubview:ui_wrapping_label([NSString stringWithCString:k->help], NSMakeRect(156, y + 2, WIN_W - 172.0, 22), NO)];
    }

    [v addSubview:ui_label(@"Delete backups older than", NSMakeRect(16, 54, 170, 18))];
    daysField = ui_field(NSMakeRect(190, 52, 44, 22));
    [v addSubview:daysField];
    [v addSubview:ui_label(@"days", NSMakeRect(240, 54, 40, 18))];
    [v addSubview:ui_button(@"Clean Up...", NSMakeRect(290, 50, 100, 26), self, @selector(cleanUp:))];

    saveButton = ui_button(@"Save", NSMakeRect(WIN_W - 104, 12, 88, 26), self, @selector(save:));
    [v addSubview:saveButton];
    [v addSubview:ui_button(@"Revert", NSMakeRect(WIN_W - 200, 12, 88, 26), self, @selector(revert:))];
    [window center];
}

- (void)refreshControls
{
    int i, n = hksc_key_count();
    for (i = 0; i < n; i++) {
        const HkSysconfKey *k = hksc_key(i);
        id ctl = [controls objectAtIndex:i];
        const char *val = hksc_get(sc, k->key);
        if (k->kind == HKSC_BOOL) {
            [ctl setState:(val ? val[0] != '0' : YES) ? NSOnState : NSOffState];       /* absent: the game's default, on */
        } else {
            [ctl setStringValue:[NSString stringWithCString:val ? val : ""]];
        }
        [ctl setEnabled:editable];
    }
    [saveButton setEnabled:editable];
    [daysField setStringValue:[NSString stringWithFormat:@"%d", [GameConfig backupDays]]];
    [statusLabel setStringValue:[self explanation]];
}

- (void)showWindow
{
    [self loadFile];
    if (!window) [self buildWindow];
    [self refreshControls];
    [window makeKeyAndOrderFront:nil];
}

- (BOOL)isEditable { return editable; }

- (NSString *)valueForKey:(NSString *)key
{
    const char *v = hksc_get(sc, UI_CPATH(key));
    return v ? [NSString stringWithCString:v] : nil;
}

- (void)setValue:(NSString *)value forKey:(NSString *)key
{
    int i, n = hksc_key_count();
    for (i = 0; i < n; i++) {
        if (strcmp(hksc_key(i)->key, UI_CPATH(key)) == 0) {
            id ctl = [controls objectAtIndex:i];
            if (hksc_key(i)->kind == HKSC_BOOL) [ctl setState:[value isEqualToString:@"1"] ? NSOnState : NSOffState];
            else [ctl setStringValue:value];
        }
    }
}

/* ---- backups: sysconf.old.ddMMMyyyy beside the file ---- */

- (NSString *)directory { return [path stringByDeletingLastPathComponent]; }

- (BOOL)backupFile
{
    NSCalendarDate *now = [NSCalendarDate calendarDate];
    char name[96];
    NSString *backup;
    NSData *orig;

    hkb_name(name, sizeof(name), game->sysconf, [now yearOfCommonEra], [now monthOfYear], [now dayOfMonth]);
    backup = [[self directory] stringByAppendingPathComponent:[NSString stringWithCString:name]];
    if ([[NSFileManager defaultManager] fileExistsAtPath:backup]) return YES;      /* the day's first copy stays */
    orig = [NSData dataWithContentsOfFile:path];
    if (!orig) return NO;
    return [orig writeToFile:backup atomically:NO];
}

/* The backups of this file in its directory that are more than days old, as full paths. */
- (NSArray *)backupsOlderThan:(int)days
{
    NSCalendarDate *now = [NSCalendarDate calendarDate];
    long today = hkb_days([now yearOfCommonEra], [now monthOfYear], [now dayOfMonth]);
    NSArray *names = [[NSFileManager defaultManager] directoryContentsAtPath:[self directory]];
    NSMutableArray *out = [NSMutableArray array];
    unsigned i;

    for (i = 0; i < [names count]; i++) {
        NSString *n = [names objectAtIndex:i];
        int y, m, d;
        if (hkb_parse(UI_CPATH(n), game->sysconf, &y, &m, &d) && today - hkb_days(y, m, d) > days)
            [out addObject:[[self directory] stringByAppendingPathComponent:n]];
    }
    return out;
}

- (int)countBackupsOlderThan:(int)days
{
    if (!path) [self loadFile];
    return (int)[[self backupsOlderThan:days] count];
}

- (int)removeBackupsOlderThan:(int)days
{
    NSArray *old;
    unsigned i;
    int gone = 0;

    if (!path) [self loadFile];
    old = [self backupsOlderThan:days];
    for (i = 0; i < [old count]; i++)
        if ([[NSFileManager defaultManager] removeFileAtPath:[old objectAtIndex:i] handler:nil]) gone++;
    return gone;
}

- (void)cleanUp:(id)sender
{
    const char *txt = UI_CPATH(ui_trim([daysField stringValue])), *p;
    int days = 0, count, gone;

    for (p = txt; *p; p++) {
        if (*p < '0' || *p > '9') { days = -1; break; }
        days = days * 10 + (*p - '0');
        if (days > 100000) break;
    }
    if (days < 0 || txt[0] == '\0') {
        NSRunAlertPanel(@"Clean Up", @"%@", @"OK", nil, nil, @"Enter the age in days as a whole number.");
        return;
    }
    [GameConfig setBackupDays:days];
    count = [self countBackupsOlderThan:days];
    if (count == 0) {
        NSRunAlertPanel(@"Clean Up", @"%@", @"OK", nil, nil,
                        [NSString stringWithFormat:@"There are no backups of %s more than %d days old.", game->sysconf, days]);
        return;
    }
    if (NSRunAlertPanel(@"Clean Up", @"%@", @"Delete", @"Cancel", nil,
                        [NSString stringWithFormat:@"Delete %d backup%s of %s more than %d days old?", count,
                         count == 1 ? "" : "s", game->sysconf, days]) != NSAlertDefaultReturn) return;
    gone = [self removeBackupsOlderThan:days];
    if (gone < count)
        NSRunAlertPanel(@"Clean Up", @"%@", @"OK", nil, nil,
                        [NSString stringWithFormat:@"Deleted %d of %d. The rest could not be removed (the directory %@ may not be writable).",
                         gone, count, [self directory]]);
}

/* Writes the file in place: its owner, group and mode stay as they are (a replacement file would belong to whoever saves). */
- (void)save:(id)sender
{
    int i, n = hksc_key_count();
    size_t len;
    char *text;
    NSData *data;

    if (!editable) return;
    [window makeFirstResponder:window];
    for (i = 0; i < n; i++) {
        const HkSysconfKey *k = hksc_key(i);
        id ctl = [controls objectAtIndex:i];
        NSString *val;
        const char *cv;

        if (k->kind == HKSC_BOOL) {
            hksc_set(sc, k->key, ([ctl state] == NSOnState) ? "1" : "0");
            continue;
        }
        val = ui_trim([ctl stringValue]);
        cv = UI_CPATH(val);
        if (k->kind == HKSC_INT) {
            const char *p;
            for (p = cv; *p; p++) {
                if (*p < '0' || *p > '9') {
                    NSRunAlertPanel(@"System Settings", @"%@", @"OK", nil, nil,
                                    [NSString stringWithFormat:@"%s needs a whole number.", k->label]);
                    return;
                }
            }
        }
        if (cv[0] == '\0' && hksc_get(sc, k->key) == NULL) continue;           /* nothing there, nothing to write */
        hksc_set(sc, k->key, cv);
    }
    text = hksc_text(sc, &len);
    if (!text) return;
    data = [NSData dataWithBytes:text length:len];
    free(text);
    if (![self backupFile] &&
        NSRunAlertPanel(@"System Settings", @"%@", @"Save Anyway", @"Cancel", nil,
                        [NSString stringWithFormat:@"A backup copy could not be made in %@ (the directory may not be writable "
                         @"to you). Save without one?", [self directory]]) != NSAlertDefaultReturn) return;
    if (![data writeToFile:path atomically:NO])
        NSRunAlertPanel(@"System Settings", @"%@", @"OK", nil, nil, [NSString stringWithFormat:@"Could not write %@.", path]);
}

- (void)revert:(id)sender
{
    [self loadFile];
    [self refreshControls];
}

@end
