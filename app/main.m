#import "Compat.h"
#import "AppController.h"
#import "UIHelpers.h"
#include <signal.h>
#include <stdlib.h>

/*
 * Startup is narrated with NSLog so a launch that "does nothing" can be diagnosed:
 * run  ./StepHack.app/StepHack  from a Terminal and see how far it gets.
 * Workspace throws a launched application's stderr away, so the same narration is also written
 * to ~/.StepHack.trace when that file exists:   touch ~/.StepHack.trace
 * then launch from Workspace and read the file.
 */
int main(int argc, char *argv[])
{
    NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
    AppController *controller;
    int i;

    NSLog(@"StepHack: starting");
    SSTrace("---- starting, argc=%d", argc);
    for (i = 0; i < argc; i++) SSTrace("  argv[%d] = %s", i, argv[i]);
    SSTrace("  cwd  = %s", SSCS([[NSFileManager defaultManager] currentDirectoryPath]));
    SSTrace("  NSHomeDirectory() = %s", SSCS(NSHomeDirectory()));
    SSTrace("  getenv(\"HOME\")   = %s", getenv("HOME") ? getenv("HOME") : "(not set)");
    SSTrace("  getenv(\"SHELL\")  = %s", getenv("SHELL") ? getenv("SHELL") : "(not set)");
    SSTrace("  NSUserName()      = %s", SSCS(NSUserName()));
    signal(SIGPIPE, SIG_IGN);                 /* writing to a pty whose slave just closed must not kill the app */

    NS_DURING
        [NSApplication sharedApplication];
        NSLog(@"StepHack: NSApplication created");
        SSTrace("NSApplication created");
        controller = [[AppController alloc] init];
        NSLog(@"StepHack: controller created");
        SSTrace("controller created");
        [NSApp setDelegate:controller];
        [controller buildMenu];
        NSLog(@"StepHack: menu built, entering the event loop");
        SSTrace("menu built, entering the event loop");
        [NSApp run];
        NSLog(@"StepHack: event loop ended");
        SSTrace("event loop ended");
    NS_HANDLER
        NSLog(@"StepHack: uncaught exception: %@ -- %@", [localException name], [localException reason]);
        SSTrace("uncaught exception: %s -- %s", SSCS([localException name]), SSCS([localException reason]));
    NS_ENDHANDLER

    [pool release];
    return 0;
}
