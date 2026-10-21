/*
 * keymap.h -- turns the cursor keys into the movement keys a *hack game understands.
 *
 * tty NetHack and its relatives know nothing about escape sequences: with number_pad off they move on h j k l y u b n,
 * with it on on the digits 1-9.  This module sits between the keyboard and the pty so the game itself needs no
 * changes: arrows move, Home/PgUp/End/PgDn are the four diagonals, and Shift runs.
 *
 * Pure C89, no I/O.  The key numbers are the vt_encode_key() ones from term/vt.h, which the view passes through.
 */
#ifndef HK_KEYMAP_H
#define HK_KEYMAP_H

/* How the game reads movement keys (the number_pad option, boiled down). */
enum {
    HK_PAD_LETTERS = 0,           /* number_pad:0, the vi keys */
    HK_PAD_DIGITS  = 1,           /* number_pad:1, 2 and 4: 7 8 9 across the top, 1 2 3 along the bottom */
    HK_PAD_PHONE   = 3,           /* number_pad:3, a telephone's layout: 1 2 3 across the top */
    HK_PAD_LETTERS_QWERTZ = 4     /* number_pad:-1, the vi keys with y and z swapped */
};

enum { HK_DIR_N = 0, HK_DIR_NE, HK_DIR_E, HK_DIR_SE, HK_DIR_S, HK_DIR_SW, HK_DIR_W, HK_DIR_NW, HK_DIRS };

/* The keymap mode for a number_pad value as the game's option takes it (-1, 0, 1, 2, 3, 4); anything else counts as 0. */
int hk_pad_mode(int number_pad);

/* The bytes that move one step (run == 0) or run (run != 0) in direction dir, into out (at least 4 bytes).  Returns the count.
 * Running is the shifted letter with the vi keys and the G prefix with the digits. */
int hk_move_bytes(int pad_mode, int dir, int run, unsigned char *out);

/* Maps a key, as the VT_KEY_* numbers in term/vt.h name them, to its bytes: arrows move, Home/PgUp/End/PgDn go diagonally
 * (northwest, northeast, southwest, southeast), and VT_MOD_SHIFT (the mods bit 1) runs.  Returns 0 for any other key, which
 * is then sent the usual way. */
int hk_map_key(int pad_mode, int vt_key, int mods, unsigned char *out);

#endif
