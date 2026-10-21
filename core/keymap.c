#include "keymap.h"
#include "vt.h"

static const char LETTERS[HK_DIRS + 1]        = "kulnjbhy";
static const char LETTERS_QWERTZ[HK_DIRS + 1] = "kulnjbhz";     /* y is where z sits on a German keyboard */
static const char DIGITS[HK_DIRS + 1]         = "89632147";
static const char PHONE[HK_DIRS + 1]          = "23698741";

int hk_pad_mode(int number_pad)
{
    switch (number_pad) {
    case 1: case 2: case 4: return HK_PAD_DIGITS;
    case 3: return HK_PAD_PHONE;
    case -1: return HK_PAD_LETTERS_QWERTZ;
    default: return HK_PAD_LETTERS;
    }
}

int hk_move_bytes(int pad_mode, int dir, int run, unsigned char *out)
{
    const char *tab;
    int n = 0;

    if (dir < 0 || dir >= HK_DIRS) return 0;
    switch (pad_mode) {
    case HK_PAD_DIGITS: tab = DIGITS; break;
    case HK_PAD_PHONE: tab = PHONE; break;
    case HK_PAD_LETTERS_QWERTZ: tab = LETTERS_QWERTZ; break;
    default: tab = LETTERS; break;
    }
    if (pad_mode == HK_PAD_DIGITS || pad_mode == HK_PAD_PHONE) {
        if (run) out[n++] = 'G';
        out[n++] = (unsigned char)tab[dir];
    } else {
        unsigned char c = (unsigned char)tab[dir];
        if (run && c >= 'a' && c <= 'z') c = (unsigned char)(c - 'a' + 'A');
        out[n++] = c;
    }
    return n;
}

int hk_map_key(int pad_mode, int vt_key, int mods, unsigned char *out)
{
    int dir;

    switch (vt_key) {
    case VT_KEY_UP: dir = HK_DIR_N; break;
    case VT_KEY_DOWN: dir = HK_DIR_S; break;
    case VT_KEY_RIGHT: dir = HK_DIR_E; break;
    case VT_KEY_LEFT: dir = HK_DIR_W; break;
    case VT_KEY_HOME: dir = HK_DIR_NW; break;
    case VT_KEY_PGUP: dir = HK_DIR_NE; break;
    case VT_KEY_END: dir = HK_DIR_SW; break;
    case VT_KEY_PGDN: dir = HK_DIR_SE; break;
    default: return 0;
    }
    return hk_move_bytes(pad_mode, dir, (mods & VT_MOD_SHIFT) != 0, out);
}
