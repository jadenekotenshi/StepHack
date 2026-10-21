#import "Compat.h"
#include "games.h"
#include "schema.h"
#include "rcfile.h"

/* The options window for one game: a scrolling list of its options (from the game's schema) as switches, pop-up menus and
 * fields, editing the game's options file in place.  Changes are held until Save. */
@interface OptionsController : NSObject
{
    const HkGameDef *game;
    HkSchema        *schema;
    HkRc            *rc;
    NSString        *path;
    NSWindow        *window;
    NSTextField     *pathLabel;
    NSButton        *saveButton;
    NSMutableArray  *controls;         /* one control per schema item, NSNull-free: NSObject placeholders for groups */
    BOOL             dirty;
}
+ (OptionsController *)controllerForGame:(const HkGameDef *)g;     /* one per game, kept for the life of the program */
- (void)showWindow;
- (void)controlChanged:(id)sender;
- (void)save:(id)sender;
- (void)revert:(id)sender;
@end
