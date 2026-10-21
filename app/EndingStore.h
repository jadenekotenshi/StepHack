#import "Compat.h"
#include "games.h"

/* The ending screens of finished games, kept as text files under ~/.StepHack/endings (the last 30 of each game). */
@interface EndingStore : NSObject
/* Keeps the endings in dir instead of ~/.StepHack/endings (for the tests). */
+ (void)setDirectory:(NSString *)dir;
+ (NSString *)saveText:(NSString *)text forGame:(const HkGameDef *)g;       /* the file's path, or nil */
+ (NSArray *)pathsForGame:(const HkGameDef *)g;                              /* newest first */
+ (NSString *)titleForPath:(NSString *)path game:(const HkGameDef *)g;        /* "2026-10-21 14:03  NetHack 3.6.7" */
+ (NSString *)textAtPath:(NSString *)path;
@end
