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
    NSTextField     *daysField;        /* "delete backups older than N days" */
    BOOL             editable;
}
+ (SysconfController *)controllerForGame:(const HkGameDef *)g;
+ (BOOL)hasSysconfForGame:(const HkGameDef *)g;          /* the game uses one and it is there */
- (void)showWindow;
- (void)save:(id)sender;
- (void)revert:(id)sender;
- (void)cleanUp:(id)sender;
/* Each save first copies the file, gzipped, to <backups>/<game>/sysconf.old.ddMMMyyyy.hhmm.gz, where <backups> is
 * ~/.StepHack/backups (the data directory is usually not the user's to write to).  A copy of the same minute is kept as it
 * is.  Compressed with /usr/bin/gzip, else /usr/local/bin/gzip; left uncompressed if neither is there.  NO if the copy could not be made. */
- (BOOL)backupFile;
- (NSString *)backupDirectory;
- (int)countBackupsOlderThan:(int)days;      /* backups whose date is more than days days ago */
- (int)removeBackupsOlderThan:(int)days;     /* ... and deletes them; how many went */
+ (void)setBackupRoot:(NSString *)root;      /* instead of ~/.StepHack/backups (for the tests) */
/* for the tests */
- (BOOL)isEditable;
- (void)setValue:(NSString *)value forKey:(NSString *)key;
- (NSString *)valueForKey:(NSString *)key;
@end
