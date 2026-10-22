#import "Compat.h"
#import "GameSession.h"

/* Owns every open game window and the menus.  Game > New Game opens one per game (Cmd-N starts the last one chosen). */
@interface AppController : NSObject
{
    NSMutableArray *sessions;          /* GameSession* */
    int             lastGame;          /* index into the game table of the last one started */
    NSMenu         *keypadMenu;
    NSMenu         *gameMenu;          /* the Game menu itself */
    NSMenu         *wizardMenu, *exploreMenu;   /* the same games, started in wizard or explore mode */
    BOOL            launched;          /* the application is running: until then no menu item looks at the disk or the preferences */
    NSMenu         *gamesMenu;         /* the New Game submenu: only the games that are installed */
}
- (void)buildMenu;
- (void)newGame:(id)sender;
- (void)coloursChanged:(id)sender;     /* Preferences changed the terminal colours: open windows follow */
- (void)addModeMenus;                  /* the wizard and explore mode submenus, made once the application runs */
- (void)rescanGames:(id)sender;       /* look again at which games are installed and rebuild the New Game menu */
- (void)newLastGame:(id)sender;
- (void)setKeypad:(id)sender;
- (void)showOptions:(id)sender;
- (void)showSysconf:(id)sender;
- (void)showScores:(id)sender;
- (void)showEnding:(id)sender;
- (void)showPreferences:(id)sender;
- (void)sessionDidEnd:(GameSession *)session;
@end
