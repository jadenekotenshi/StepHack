#import "Compat.h"

/* Preferences: where each game is installed, and whether movement defaults to the number pad. */
@interface PrefsController : NSObject
{
    NSWindow      *window;
    NSPopUpButton *gamePop;
    NSTextField   *launcherField, *hackdirField, *rcField, *termField;
    NSButton      *padSwitch, *lineSwitch, *cursesSwitch, *closeSwitch;
    NSPopUpButton *colourPop, *boldPop, *closePop;
    int            shown;                 /* index in the game table of the game the fields show */
}
+ (PrefsController *)sharedController;
- (void)showWindow;
- (void)gameChanged:(id)sender;
- (void)restoreDefaults:(id)sender;
- (void)padChanged:(id)sender;
- (void)lineChanged:(id)sender;
- (void)cursesChanged:(id)sender;
- (void)closeChanged:(id)sender;
- (void)colourChanged:(id)sender;
- (void)boldChanged:(id)sender;
- (void)closeActionChanged:(id)sender;
@end
