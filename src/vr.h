/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

#ifndef __VR_H__
#define __VR_H__

void debug_log(const char *msg);
void debug_lprintf(int maxlen, const char *fmt, ...);
int mb_lprintf(HWND wnd, const char *title, int flags, int maxlen,
		const char *fmt, ...);
#endif
