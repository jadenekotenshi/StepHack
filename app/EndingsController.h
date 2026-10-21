#import "Compat.h"
#include "games.h"

/* The ending screens kept for one game (see EndingStore): a pop-up of finished games and the text of the chosen one. */
@interface EndingsController : NSObject
{
    const HkGameDef *game;
    NSWindow        *window;
    NSPopUpButton   *pop;
    NSTextView      *text;
    NSArray         *paths;
}
+ (EndingsController *)controllerForGame:(const HkGameDef *)g;
- (void)showWindowSelecting:(NSString *)path;       /* path: an ending to select, or nil for the newest */
- (void)choose:(id)sender;
- (void)copyAll:(id)sender;
- (void)saveAs:(id)sender;
@end
