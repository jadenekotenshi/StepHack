#import "EndingStore.h"
#import "UIHelpers.h"
#include <string.h>

#define KEEP 30

/* (NSString's hasPrefix:/hasSuffix: are not relied on: see tools/lint_openstep.sh.) */
static BOOL starts_with(NSString *s, NSString *prefix)
{
    unsigned n = [prefix length];
    return [s length] >= n && [[s substringToIndex:n] isEqualToString:prefix];
}

static BOOL ends_with(NSString *s, NSString *suffix)
{
    unsigned n = [suffix length], len = [s length];
    return len >= n && [[s substringFromIndex:len - n] isEqualToString:suffix];
}

@implementation EndingStore

static NSString *overrideDir = nil;

+ (void)setDirectory:(NSString *)dir
{
    [overrideDir release];
    overrideDir = [dir retain];
}

+ (NSString *)directory
{
    if (overrideDir) return overrideDir;
    NSFileManager *fm = [NSFileManager defaultManager];
    NSString *base = [NSHomeDirectory() stringByAppendingPathComponent:@".StepHack"];
    NSString *dir = [base stringByAppendingPathComponent:@"endings"];
    BOOL isDir = NO;
    if (![fm fileExistsAtPath:dir isDirectory:&isDir]) {
        [fm createDirectoryAtPath:base attributes:nil];
        [fm createDirectoryAtPath:dir attributes:nil];
    }
    return dir;
}

+ (NSArray *)pathsForGame:(const HkGameDef *)g
{
    NSString *dir = [self directory];
    NSString *prefix = [NSString stringWithFormat:@"%s-", g->id];
    NSArray *names = [[NSFileManager defaultManager] directoryContentsAtPath:dir];
    NSMutableArray *mine = [NSMutableArray array];
    NSArray *sorted;
    NSMutableArray *out = [NSMutableArray array];
    unsigned i;

    for (i = 0; i < [names count]; i++) {
        NSString *n = [names objectAtIndex:i];
        if (starts_with(n, prefix) && ends_with(n, @".txt")) [mine addObject:n];
    }
    sorted = [mine sortedArrayUsingSelector:@selector(compare:)];          /* the stamp sorts oldest first */
    for (i = [sorted count]; i > 0; i--) [out addObject:[dir stringByAppendingPathComponent:[sorted objectAtIndex:i - 1]]];
    return out;
}

+ (NSString *)saveText:(NSString *)text forGame:(const HkGameDef *)g
{
    NSString *dir = [self directory];
    NSString *stamp = [[NSCalendarDate calendarDate] descriptionWithCalendarFormat:@"%Y%m%d-%H%M%S"];
    NSString *path = [dir stringByAppendingPathComponent:[NSString stringWithFormat:@"%s-%@.txt", g->id, stamp]];
    NSData *data = [text dataUsingEncoding:NSUTF8StringEncoding allowLossyConversion:YES];
    NSArray *all;
    unsigned i;

    if (!data || ![data writeToFile:path atomically:YES]) return nil;
    all = [self pathsForGame:g];
    for (i = KEEP; i < [all count]; i++) [[NSFileManager defaultManager] removeFileAtPath:[all objectAtIndex:i] handler:nil];
    return path;
}

+ (NSString *)titleForPath:(NSString *)path game:(const HkGameDef *)g
{
    NSString *name = [[path lastPathComponent] stringByDeletingPathExtension];    /* id-YYYYMMDD-HHMMSS */
    unsigned idlen = (unsigned)strlen(g->id) + 1;
    NSString *stamp = ([name length] > idlen) ? [name substringFromIndex:idlen] : @"";
    if ([stamp length] == 15)
        return [NSString stringWithFormat:@"%@-%@-%@  %@:%@  %s", [stamp substringWithRange:NSMakeRange(0, 4)],
                [stamp substringWithRange:NSMakeRange(4, 2)], [stamp substringWithRange:NSMakeRange(6, 2)],
                [stamp substringWithRange:NSMakeRange(9, 2)], [stamp substringWithRange:NSMakeRange(11, 2)], g->title];
    return name;
}

+ (NSString *)textAtPath:(NSString *)path
{
    NSMutableData *d = [NSMutableData dataWithContentsOfFile:path];
    unsigned char zero = 0;
    if (!d) return nil;
    [d appendBytes:&zero length:1];
    return ui_string_from_utf8((const char *)[d bytes]);
}

@end
