/*
 * commands.h -- the commands the game window offers as buttons: what they are called and the keys they send.
 *
 * Most are extended commands ("#pray" then Return), which every version takes the same whatever the movement-key setting.
 * A few versions lack some commands, so each entry says which families of game have it.
 *
 * Pure C89, no I/O.
 */
#ifndef HK_COMMANDS_H
#define HK_COMMANDS_H

#include "games.h"

typedef struct {
    const char *label;       /* on the button */
    const char *keys;        /* sent to the game, with C escapes already resolved (\r is Return) */
    const char *tip;         /* a sentence for the tool tip / menu */
    int         families;    /* HK_FAMILY_* bits of the games that have it */
    int         main;        /* 1: a button of its own on the bar; 0: only in the More menu */
} HkCommand;

int              hk_command_count(void);
const HkCommand *hk_command(int index);
/* True if the game has the command. */
int              hk_command_in(const HkCommand *c, const HkGameDef *g);

#endif
