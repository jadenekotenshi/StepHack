#import "Compat.h"
#include "games.h"

/* Where each game lives on this machine, as the user has set it (Preferences) or the OPENSTEP packages put it. */
@interface GameConfig : NSObject
+ (NSString *)launcherForGame:(const HkGameDef *)g;
+ (NSString *)hackdirForGame:(const HkGameDef *)g;
+ (NSString *)rcPathForGame:(const HkGameDef *)g;
+ (void)setPath:(NSString *)path forKey:(NSString *)key game:(const HkGameDef *)g;     /* key: launcher, hackdir, rc; "" restores the default */
+ (BOOL)defaultToNumberPad;                                                           /* add number_pad:1 to a run-commands file that doesn't set it */
+ (void)setDefaultToNumberPad:(BOOL)flag;

/* Reads the game's run-commands file and returns its number_pad value (0 when the file doesn't set it).  When
 * defaultToNumberPad is on and the file leaves it unset, writes number_pad:1 into the file first (creating it). */
+ (int)numberPadForGame:(const HkGameDef *)g;
@end
