#import "Compat.h"
#include "games.h"

/* The scores window for one game: its record of finished games (the xlogfile, shown as a table of the latest or the best)
 * and its own high-score list (the program's -s output), as text that can be selected and copied. */
@interface ScoresController : NSObject
{
    const HkGameDef *game;
    NSWindow        *window;
    NSPopUpButton   *sourcePop;
    NSTextView      *text;
}
+ (ScoresController *)controllerForGame:(const HkGameDef *)g;
- (void)showWindow;
- (void)sourceChanged:(id)sender;
- (void)refresh:(id)sender;
@end
