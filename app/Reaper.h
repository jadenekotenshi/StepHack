/* Collecting the exit status of a child process.  OPENSTEP has only wait3(), which reaps whichever child finished next, so
 * finished children nobody has asked about yet are remembered here (see GameSession.m). */
#ifndef HK_REAPER_H
#define HK_REAPER_H

void hk_reap_pending(void);                              /* collects every child that has finished */
int  hk_reap_child(int pid, int *status_out);            /* 1 and the wait status if that child has finished */

#endif
