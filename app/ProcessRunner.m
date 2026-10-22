#import "ProcessRunner.h"
#import "UIHelpers.h"
#import "GameEnv.h"
#import "Reaper.h"
#include <stdlib.h>
#include <string.h>
#include <errno.h>
#include <unistd.h>
#include <fcntl.h>
#include <signal.h>
#include <sys/types.h>
#include <sys/time.h>
#include "oscompat.h"

#ifdef OPENSTEP
/* OPENSTEP's headers lack prototypes for these (see StepSSH's SSHSession.m, which does the same). */
extern int select(int nfds, fd_set *readfds, fd_set *writefds, fd_set *exceptfds, struct timeval *timeout);
#endif

#ifndef O_NONBLOCK
#define O_NONBLOCK O_NDELAY
#endif

#define MAX_OUTPUT (256 * 1024)

@implementation ProcessRunner

+ (NSString *)outputOfProgram:(NSString *)program arguments:(NSArray *)args hackdir:(NSString *)hackdir
                         game:(const HkGameDef *)game seconds:(double)limit
{
    int fds[2], i, n = (int)[args count], status;
    char **argv, **env, *prog;
    pid_t pid;
    NSMutableData *out = [NSMutableData data];
    NSTimeInterval t0 = [NSDate timeIntervalSinceReferenceDate];
    BOOL finished = NO;
    unsigned char zero = 0;

    /* Everything the child needs is prepared before fork(): no Objective-C after it. */
    prog = hk_copy_c(UI_CPATH(program));
    argv = (char **)malloc((size_t)(n + 2) * sizeof(char *));
    env = hk_game_environ(UI_CPATH(hackdir), game);
    if (!prog || !argv || !env) return nil;
    argv[0] = prog;
    for (i = 0; i < n; i++) argv[i + 1] = hk_copy_c(UI_CPATH([args objectAtIndex:i]));
    argv[n + 1] = (char *)0;

    if (pipe(fds) != 0) return nil;
    pid = fork();
    if (pid < 0) { close(fds[0]); close(fds[1]); return nil; }
    if (pid == 0) {
        int nullfd = open("/dev/null", O_RDONLY);
        extern char **environ;
        if (nullfd >= 0) { dup2(nullfd, 0); close(nullfd); }
        dup2(fds[1], 1);
        dup2(fds[1], 2);
        close(fds[0]);
        close(fds[1]);
        environ = env;
        execv(prog, argv);
        _exit(127);
    }
    close(fds[1]);
    fcntl(fds[0], F_SETFL, fcntl(fds[0], F_GETFL, 0) | O_NONBLOCK);

    for (;;) {
        unsigned char buf[4096];
        fd_set rf;
        struct timeval tv;
        int r;

        FD_ZERO(&rf);
        FD_SET(fds[0], &rf);
        tv.tv_sec = 0;
        tv.tv_usec = 100000;
        r = select(fds[0] + 1, &rf, NULL, NULL, &tv);
        if (r > 0) {
            int got = read(fds[0], buf, sizeof(buf));
            if (got > 0) {
                if ([out length] < MAX_OUTPUT) [out appendBytes:buf length:got];
                continue;
            }
            if (got == 0 || (errno != EAGAIN && errno != EINTR && errno != EWOULDBLOCK)) { finished = YES; break; }
        }
        if ([NSDate timeIntervalSinceReferenceDate] - t0 > limit) break;
    }
    close(fds[0]);
    if (!finished) kill(pid, SIGKILL);
    /* Collect the child so that it doesn't linger: give it a moment to be reaped. */
    for (i = 0; i < 20; i++) {
        if (hk_reap_child(pid, &status)) break;
        usleep(50000);
    }
    [out appendBytes:&zero length:1];
    return ui_string_from_utf8((const char *)[out bytes]);
}

@end
