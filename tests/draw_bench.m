/* Host-only: how long does drawing a whole 130x32 screen of mixed colours and attributes take?  make draw-bench */
#import "TerminalView.h"
#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <sys/time.h>

void PSmoveto(float x, float y) { }
void PSshow(const char *s) { }
@implementation NSFont (OpenStepHostStub)
- (float)widthOfString:(NSString *)s { return [self maximumAdvancement].width; }
@end

static double now(void) { struct timeval tv; gettimeofday(&tv, NULL); return tv.tv_sec + tv.tv_usec / 1e6; }
static void feed(TerminalView *tv, const char *s) { [tv writeBytes:(const unsigned char *)s length:(int)strlen(s)]; }

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    TerminalView *tv = [[[TerminalView alloc] initWithFrame:NSMakeRect(0, 0, 1000, 520)] autorelease];
    NSWindow *w = [[[NSWindow alloc] initWithContentRect:NSMakeRect(0, 0, 1000, 520) styleMask:NSTitledWindowMask backing:NSBackingStoreBuffered defer:NO] autorelease];
    int r, c, i, kind;
    char line[256];
    double t0, t[2];

    [[w contentView] addSubview:tv];
    [tv setFrame:NSMakeRect(0, 0, 1000, 520)];
    [tv fitToFrame];
    for (kind = 0; kind < 2; kind++) {            /* 0: a curses-like screen (mostly plain, some colour); 1: every cell different */
        feed(tv, "\033[2J\033[H");
        for (r = 0; r < [tv rows]; r++) {
            for (c = 0; c < [tv cols]; c++) {
                if (kind == 1 || (c % 11 == 0 && r % 3 == 0)) {
                    sprintf(line, "\033[%d;%dm", (r + c) % 4 == 0 ? 1 : 0, 31 + (r + c) % 7);
                    feed(tv, line);
                } else if (c % 11 == 1) feed(tv, "\033[0m");
                line[0] = (char)('a' + (r * 7 + c) % 26); line[1] = 0;
                feed(tv, line);
            }
            feed(tv, "\033[0m\r\n");
        }
        {
            NSBitmapImageRep *rep = [tv bitmapImageRepForCachingDisplayInRect:[tv bounds]];
            [tv cacheDisplayInRect:[tv bounds] toBitmapImageRep:rep];       /* warm up */
            t0 = now();
            for (i = 0; i < 40; i++) [tv cacheDisplayInRect:[tv bounds] toBitmapImageRep:rep];
            t[kind] = (now() - t0) / 40.0 * 1000.0;
        }
    }
    printf("full redraw of %d x %d: %.2f ms (mostly plain), %.2f ms (every cell different)\n", [tv cols], [tv rows], t[0], t[1]);
    [pool release];
    return 0;
}
