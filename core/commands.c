#include "commands.h"

#define ALL (HK_FAMILY_34 | HK_FAMILY_36 | HK_FAMILY_50)
#define NEW (HK_FAMILY_36 | HK_FAMILY_50)

static const HkCommand COMMANDS[] = {
    /* the bar */
    { "Pray",     "#pray\r",     "Pray to your god",                              ALL, 1 },
    { "Name",     "#name\r",     "Name a monster, an object, a level or a kind of object", ALL, 1 },
    { "Call",     "C",           "Call (name) a monster or give a type of object a name",  ALL, 1 },
    { "Loot",     "#loot\r",     "Loot a box or chest on the floor",              ALL, 1 },
    { "Chat",     "#chat\r",     "Talk to something nearby",                      ALL, 1 },
    { "Enhance",  "#enhance\r",  "Improve a weapon or other skill",               ALL, 1 },
    { "Overview", "#overview\r", "List the dungeon features you have seen",       NEW, 1 },
    { "Attrib",   "\030",        "Show your attributes (Ctrl-X)",                 ALL, 1 },
    /* the More menu */
    { "Force",    "#force\r",    "Force a lock with your weapon",                 ALL, 0 },
    { "Untrap",   "#untrap\r",   "Disarm a trap, or free a trapped pet",          ALL, 0 },
    { "Turn Undead", "#turn\r",  "Turn undead (priests and knights)",             ALL, 0 },
    { "Offer",    "#offer\r",    "Offer a sacrifice at an altar",                 ALL, 0 },
    { "Sit",      "#sit\r",      "Sit down",                                      ALL, 0 },
    { "Ride",     "#ride\r",     "Ride or get off a steed",                       ALL, 0 },
    { "Wipe",     "#wipe\r",     "Wipe your face",                                ALL, 0 },
    { "Rub",      "#rub\r",      "Rub a lamp or a stone",                         ALL, 0 },
    { "Dip",      "#dip\r",      "Dip an object into a fountain or a potion",     ALL, 0 },
    { "Invoke",   "#invoke\r",   "Invoke the power of an artifact",               ALL, 0 },
    { "Jump",     "#jump\r",     "Jump to a nearby square",                       ALL, 0 },
    { "Monster",  "#monster\r",  "Use a monster's special ability when polymorphed", ALL, 0 },
    { "Adjust",   "#adjust\r",   "Move an inventory item to another letter",      ALL, 0 },
    { "Conduct",  "#conduct\r",  "List the voluntary challenges you have kept",   ALL, 0 },
    { "Discoveries", "\\",       "List what you have identified",                 ALL, 0 },
    { "Look Here", ":",          "Look at what is on your square",                ALL, 0 },
    { "Redraw",   "\022",        "Redraw the screen (Ctrl-R)",                    ALL, 0 }
};

int hk_command_count(void) { return (int)(sizeof(COMMANDS) / sizeof(COMMANDS[0])); }

const HkCommand *hk_command(int index)
{
    if (index < 0 || index >= hk_command_count()) return 0;
    return &COMMANDS[index];
}

int hk_command_in(const HkCommand *c, const HkGameDef *g)
{
    return (c->families & g->family) != 0;
}
