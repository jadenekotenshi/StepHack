#import "Compat.h"
#include "games.h"

/* Where each game lives on this machine, as the user has set it (Preferences) or the OPENSTEP packages put it. */
@interface GameConfig : NSObject
+ (NSString *)launcherForGame:(const HkGameDef *)g;
+ (NSString *)hackdirForGame:(const HkGameDef *)g;
+ (NSString *)rcPathForGame:(const HkGameDef *)g;
+ (NSString *)defaultRcPathForGame:(const HkGameDef *)g;     /* ignoring Preferences */
+ (void)setPath:(NSString *)path forKey:(NSString *)key game:(const HkGameDef *)g;     /* key: launcher, hackdir, rc; "" restores the default */
+ (BOOL)defaultToNumberPad;                                                           /* add number_pad:1 to a run-commands file that doesn't set it */
+ (void)setDefaultToNumberPad:(BOOL)flag;

+ (BOOL)defaultToLineGraphics;                                                        /* add DECgraphics to a file that sets no symbol set */
+ (void)setDefaultToLineGraphics:(BOOL)flag;

/* Reads the game's run-commands file and returns its number_pad value (0 when the file doesn't set it).  First, for each
 * default that is switched on (number_pad:1; the game's line-graphics option) and that the file leaves unset, writes it
 * into the file (creating it).  An option the user has set either way, or a symbol set they chose, is never touched. */
+ (int)numberPadForGame:(const HkGameDef *)g;
@end
