/* Host-only check of the ending screen: the terminal's transcript, and EndingStore saving, listing and pruning.
 * make ending-smoke */
#import "TerminalView.h"
#import "EndingStore.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>

void PSmoveto(float x, float y) { }
void PSshow(const char *s) { }
@implementation NSFont (OpenStepHostStub)
- (float)widthOfString:(NSString *)s { return [self maximumAdvancement].width; }
@end

static int failures = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

static void feed(TerminalView *tv, const char *s) { [tv writeBytes:(const unsigned char *)s length:(int)strlen(s)]; }

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TerminalView *tv = [[[TerminalView alloc] initWithFrame:NSMakeRect(0, 0, 640, 400)] autorelease];
    NSString *t;
    const HkGameDef *g = hk_game_by_id("nethack");
    NSString *dir, *path, *path2;
    NSArray *list;
    int i;

    /* a screen with a boxed tombstone-ish thing, colour, and scrolled-off lines before it */
    for (i = 0; i < 60; i++) { char line[64]; sprintf(line, "line %d\r\n", i); feed(tv, line); }
    feed(tv, "\033[2J\033[H\033[31mGoodbye Jade...\033[0m\r\n\033(0lqqqk\r\nx   x\r\nmqqqj\033(B\r\n   \r\nRest in peace\r\n\r\n\r\n");
    t = [tv transcript:600];
    CHECK([t rangeOfString:@"line 0\n"].length == 7);                          /* from the scrollback */
    CHECK([t rangeOfString:@"Goodbye Jade...\n+---+\n|   |\n+---+\n"].length > 0);   /* box drawing as + - | */
    CHECK([t rangeOfString:@"Rest in peace\n"].length > 0);
    CHECK(![t hasSuffix:@"\n\n"]);                                             /* trailing blank lines dropped */
    CHECK([t rangeOfString:@"\033"].length == 0);
    t = [tv transcript:5];
    CHECK([t length] < 120);                                                   /* only the last lines */
    {
        int lines = 0; unsigned k;
        for (k = 0; k < [t length]; k++) if ([t characterAtIndex:k] == '\n') lines++;
        CHECK(lines <= 5);
    }

    /* the store, in a throwaway home directory */
    dir = [NSString stringWithFormat:@"/tmp/stephack-ending-test-%d", (int)getpid()];
    [[NSFileManager defaultManager] createDirectoryAtPath:dir attributes:nil];
    [EndingStore setDirectory:dir];
    CHECK([[EndingStore pathsForGame:g] count] == 0);
    path = [EndingStore saveText:@"first ending\nsecond line\n" forGame:g];
    CHECK(path != nil && [[EndingStore textAtPath:path] isEqualToString:@"first ending\nsecond line\n"]);
    CHECK([[EndingStore titleForPath:path game:g] rangeOfString:@"NetHack 3.6.7"].length > 0);
    CHECK([[EndingStore titleForPath:path game:g] hasPrefix:@"20"]);
    for (i = 0; i < 35; i++) {                                                  /* files named by the second: make distinct names */
        NSString *p = [NSString stringWithFormat:@"%@/nethack-2020010%d-%06d.txt", dir, i % 9 + 1, i];
        [@"x" writeToFile:p atomically:YES];
    }
    path2 = [EndingStore saveText:@"later ending\n" forGame:g];
    list = [EndingStore pathsForGame:g];
    CHECK([list count] == 30);                                                 /* pruned to the newest 30 */
    CHECK([[list objectAtIndex:0] isEqualToString:path2] || [[list objectAtIndex:0] isEqualToString:path]);
    CHECK([[EndingStore pathsForGame:hk_game_by_id("slashem")] count] == 0);    /* kept apart per game */
    CHECK([EndingStore textAtPath:@"/nonexistent/file"] == nil);

    [[NSFileManager defaultManager] removeFileAtPath:dir handler:nil];
    printf("ending: %s\n", failures ? "FAILED" : "ok");
    [pool release];
    return failures ? 1 : 0;
}
