/* Host-only: draws a whole 130x32 screen of everything the games produce (bold, dim, underline, reverse, every colour,
 * line drawing, shades, a selection, the cursor) in both key states and both colour schemes, to see that drawing neither
 * crashes nor overruns anything (build it with the address checker: make draw-smoke).  */
#import "TerminalView.h"
#import "GameConfig.h"
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
    TerminalView *tv = [[[TerminalView alloc] initWithFrame:NSMakeRect(0, 0, 900, 520)] autorelease];
    NSWindow *w = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 900, 520) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
    int r, c, pass, style;
    char line[512];

    [[w contentView] addSubview:tv];
    [tv setFrame:NSMakeRect(0, 0, 900, 520)];
    [tv fitToFrame];
    CHECK([tv cols] >= 80 && [tv rows] >= 24);

    /* every colour and attribute, over the whole screen */
    feed(tv, "\033[2J\033[H");
    for (r = 0; r < [tv rows]; r++) {
        for (c = 0; c < [tv cols]; c++) {
            sprintf(line, "\033[%d;%d;%d;%dm%c", (r + c) % 3 == 0 ? 1 : 0, (r % 2) ? 4 : 24, ((r + c) % 5) == 0 ? 7 : 27,
                    30 + (r + c) % 8, 'a' + (r * 7 + c) % 26);
            feed(tv, line);
            if (c % 9 == 0) { sprintf(line, "\033[38;5;%dm\033[48;5;%dm", (r * 16 + c) % 256, (r * 5 + c * 3) % 256); feed(tv, line); }
        }
        feed(tv, "\033[0m\r\n");
    }
    /* line drawing and shades */
    feed(tv, "\033[H\033(0lqqqqqqqqqqqqqk\r\nx             x\r\ntqqqqqqwqqqqqqu\r\nx      x      x\r\nmqqqqqqvqqqqqqj\033(B\033[0m\r\n");
    feed(tv, "\033(0aaaaaaaa~~~~~``fgh\033(B\r\n");
    feed(tv, "\033[2m dim \033[1;2m bold dim \033[0m\033[1m BOLD \033[22m");

    for (style = 0; style < 3; style++) {                                   /* bold: auto, overstrike, colour only */
        [tv setBoldStyle:style];
        for (pass = 0; pass < 2; pass++) {                                  /* white on black / black on white */
            [tv setForeground:pass ? [NSColor whiteColor] : [NSColor blackColor] background:pass ? [NSColor blackColor] : [NSColor whiteColor]];
            [tv selectAll:nil];                                              /* a selection over everything */
            {
                NSBitmapImageRep *rep = [tv bitmapImageRepForCachingDisplayInRect:[tv bounds]];
                [tv cacheDisplayInRect:[tv bounds] toBitmapImageRep:rep];    /* the whole window at once */
                CHECK(rep != nil);
                [tv cacheDisplayInRect:NSMakeRect(40, 40, 200, 120) toBitmapImageRep:[tv bitmapImageRepForCachingDisplayInRect:NSMakeRect(40, 40, 200, 120)]];
            }
            [tv setNeedsDisplay:YES];
        }
    }
    printf("draw: %s\n", failures ? "FAILED" : "ok");
    [pool release];
    return failures ? 1 : 0;
}
