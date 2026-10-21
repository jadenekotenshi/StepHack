/* Host-only check of ProcessRunner: runs real programs and looks at what comes back.  make runner-smoke */
#import "ProcessRunner.h"
#import "UIHelpers.h"
#include <stdio.h>
#include <string.h>
#include <sys/wait.h>
#include <sys/types.h>

int hk_reap_child(int pid, int *status_out) { return waitpid(pid, status_out, WNOHANG) == pid; }
void hk_reap_pending(void) { }

static int failures = 0;
#define CHECK(c) do { if (!(c)) { printf("FAIL line %d: %s\n", __LINE__, #c); failures++; } } while (0)

int main(void)
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    NSString *o;
    NSTimeInterval t0;

    o = [ProcessRunner outputOfProgram:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", @"echo hello; echo err 1>&2; echo \"$HACKDIR|$TERM\"", nil]
                               hackdir:@"/tmp/hd" seconds:5.0];
    CHECK(o != nil && [o rangeOfString:@"hello\n"].length == 6);
    CHECK([o rangeOfString:@"err\n"].length == 4);                         /* stderr is captured too */
    CHECK([o rangeOfString:@"/tmp/hd|stephack"].length > 0);                /* the game environment */

    t0 = [NSDate timeIntervalSinceReferenceDate];
    o = [ProcessRunner outputOfProgram:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", @"echo first; sleep 30", nil]
                               hackdir:@"/tmp" seconds:1.0];
    CHECK(o != nil && [o rangeOfString:@"first"].length == 5);
    CHECK([NSDate timeIntervalSinceReferenceDate] - t0 < 5.0);               /* killed at the limit */

    o = [ProcessRunner outputOfProgram:@"/nonexistent/program" arguments:nil hackdir:@"/tmp" seconds:2.0];
    CHECK(o != nil && [o length] == 0);                                      /* exec failed: nothing printed */

    o = [ProcessRunner outputOfProgram:@"/bin/sh" arguments:[NSArray arrayWithObjects:@"-c", @"head -c 600000 /dev/zero | tr '\\0' x", nil]
                               hackdir:@"/tmp" seconds:5.0];
    CHECK(o != nil && [o length] <= 270000);                                 /* capped */

    printf("runner: %s\n", failures ? "FAILED" : "ok");
    [pool release];
    return failures ? 1 : 0;
}
