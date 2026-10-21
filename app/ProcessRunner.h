#import "Compat.h"

/* Runs a game's program for a moment to collect what it prints (its score list, its version) -- no terminal involved. */
@interface ProcessRunner : NSObject
/* Runs program with the arguments in the game's environment (see GameEnv.h) and returns everything it wrote, or nil if it
 * could not be started.  A program still running after limit seconds is killed and what it had written is returned. */
+ (NSString *)outputOfProgram:(NSString *)program arguments:(NSArray *)args hackdir:(NSString *)hackdir
                      seconds:(double)limit;
@end
