#import "Compat.h"
#include "games.h"

/* Where each game lives on this machine, as the user has set it (Preferences) or the OPENSTEP packages put it. */
@interface GameConfig : NSObject
+ (NSString *)launcherForGame:(const HkGameDef *)g;
/* True if the game's program exists where it is expected (Preferences, else the package's place) and can be run. */
+ (BOOL)isInstalled:(const HkGameDef *)g;
/* The id of the game started last, remembered between runs (nil: none yet). */
+ (NSString *)lastGameId;
+ (void)setLastGameId:(NSString *)gid;
+ (NSString *)hackdirForGame:(const HkGameDef *)g;
+ (NSString *)rcPathForGame:(const HkGameDef *)g;
+ (NSString *)defaultRcPathForGame:(const HkGameDef *)g;     /* ignoring Preferences */
/* The TERM the game is run under: the one set in Preferences, else the game's own (nil: the stephack termcap entry). */
+ (NSString *)termForGame:(const HkGameDef *)g;
/* The same for a run with or without the curses interface: curses reads terminfo (through ncurses), which has no
 * "stephack" entry, so it gets "xterm" unless Preferences or the game say otherwise. */
+ (NSString *)termForGame:(const HkGameDef *)g curses:(BOOL)curses;
/* The options file's contents, or, while the file doesn't exist, the template the game would copy for a new player (if it
 * has one), or nil. */
+ (NSData *)rcDataForGame:(const HkGameDef *)g;
+ (void)setPath:(NSString *)path forKey:(NSString *)key game:(const HkGameDef *)g;     /* key: launcher, hackdir, rc, term; "" restores the default */
+ (BOOL)defaultToNumberPad;                                                           /* add number_pad:1 to a run-commands file that doesn't set it */
+ (void)setDefaultToNumberPad:(BOOL)flag;

/* Whether the curses interface is used: the choice in Preferences if there is one, else the game's own default (only for a
 * game that has a curses interface at all). */
+ (BOOL)useCursesForGame:(const HkGameDef *)g;
+ (void)setUseCurses:(int)choice forGame:(const HkGameDef *)g;       /* 1 yes, 0 no, -1 back to the game's default */
/* Whether a game window closes by itself when its game ends normally (status 0); a failed one stays open to be read. */
+ (BOOL)closeWhenDone;
+ (void)setCloseWhenDone:(BOOL)flag;
/* The terminal's colours: 0 black on white (the default, as OPENSTEP's own applications), 1 white on black (what the games
 * are written for: much of what they show is yellow). */
+ (int)colourScheme;
+ (void)setColourScheme:(int)scheme;
/* How bold text is drawn: 0 the font's bold face if it has one (else overstrike), 1 overstrike, 2 only brighter colour. */
+ (int)boldStyle;
+ (void)setBoldStyle:(int)style;
/* What closing the window of a game in progress does: 0 saves the game (the default), 1 asks first. */
+ (int)closeAction;
+ (void)setCloseAction:(int)action;
/* How old (in days) a backup of the system configuration file has to be before "Clean Up" offers to delete it (default 30). */
+ (int)backupDays;
+ (void)setBackupDays:(int)days;
+ (BOOL)defaultToLineGraphics;                                                        /* add DECgraphics to a file that sets no symbol set */
+ (void)setDefaultToLineGraphics:(BOOL)flag;

/* Reads the game's run-commands file and returns its number_pad value (0 when the file doesn't set it).  First, for each
 * default that is switched on (number_pad:1; the game's line-graphics option) and that the file leaves unset, writes it
 * into the file (creating it).  An option the user has set either way, or a symbol set they chose, is never touched. */
+ (int)numberPadForGame:(const HkGameDef *)g;
/* The same, and *curses is set to 1 if the game will run with its curses interface (the file asks for it, or it is made to). */
+ (int)numberPadForGame:(const HkGameDef *)g curses:(int *)curses;
@end
