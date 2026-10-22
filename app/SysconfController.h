#import "Compat.h"
#include "games.h"
#include "sysconf.h"

/* The system settings window for one game: the handful of settings in the game's "sysconf" file that matter on a machine
 * with several users (who may use wizard and explore mode, how many games may run, ...).  The file belongs to root and is
 * meant to be group-writable by wheel; the window edits it in place if the user can write it, and otherwise only shows it. */
@interface SysconfController : NSObject
{
    const HkGameDef *game;
    HkSysconf       *sc;
    NSString        *path;
    NSWindow        *window;
    NSMutableArray  *controls;         /* one control per key of hksc_key() */
    NSTextField     *statusLabel;
    NSButton        *saveButton;
    BOOL             editable;
}
+ (SysconfController *)controllerForGame:(const HkGameDef *)g;
+ (BOOL)hasSysconfForGame:(const HkGameDef *)g;          /* the game uses one and it is there */
- (void)showWindow;
- (void)save:(id)sender;
- (void)revert:(id)sender;
/* for the tests */
- (BOOL)isEditable;
- (void)setValue:(NSString *)value forKey:(NSString *)key;
- (NSString *)valueForKey:(NSString *)key;
@end
