#import "Compat.h"
#import "GameSession.h"

/* Owns every open game window and the menus.  Game > New Game opens one per game (Cmd-N starts the last one chosen). */
@interface AppController : NSObject
{
    NSMutableArray *sessions;          /* GameSession* */
    int             lastGame;          /* index into the game table of the last one started */
    NSMenu         *keypadMenu;
}
- (void)buildMenu;
- (void)newGame:(id)sender;
- (void)newLastGame:(id)sender;
- (void)setKeypad:(id)sender;
- (void)showOptions:(id)sender;
- (void)showScores:(id)sender;
- (void)showEnding:(id)sender;
- (void)showPreferences:(id)sender;
- (void)sessionDidEnd:(GameSession *)session;
@end
