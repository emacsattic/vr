/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.

  This file is part of Emacs VR Mode.

  Emacs VR Mode is free software; you can redistribute it and/or modify
  it under the terms of the GNU General Public License as published by
  the Free Software Foundation; either version 2 of the License, or (at
  your option) any later version.

  Emacs VR Mode is distributed in the hope that it will be useful, but
  WITHOUT ANY WARRANTY; without even the implied warranty of
  MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the GNU
  General Public License for more details.

  You should have received a copy of the GNU General Public License
  along with Emacs VR Mode; if not, write to the Free Software
  Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA 02111-1307
  USA
*/

#include <windows.h>
#include <stdio.h>
#include <assert.h>

#include <dnssdk.h>

#include "IO.h"
#include "DictSink.h"
#include "MicSink.h"
#include "VCmdSink.h"
#include "vr.h"
#include "Client.h"

/* Handy macros, lifted from the DNS SDK samples. */
#define ReturnIfFailed(msg) { \
  if(FAILED(hRes)) {		      \
    char buf[BUFSIZ];                 \
    sprintf(buf, msg, hRes);          \
    MessageBox(targetWin, buf, "VR Failure", MB_OK|MB_TOPMOST|MB_ICONERROR); \
    return E_FAIL;                    \
  }                                   \
}

#if 0
void dump_state(BufMap *m) 
{
  DWORD sel_start, sel_length;
  char buf[BUFSIZ], *p = NULL;

  m->dict->Lock(0);
  m->dict->TextSelGet(&sel_start, &sel_length);
  m->dict->TextGet(&p, 0, sizeof(buf)-strlen(buf)-4);
  m->dict->UnLock();
  sprintf(buf, "(dict-state %s %d %d \"", m->bufnam, sel_start, sel_length);
  strcat(buf, p);
  strcat(buf, "\")\n");
  io->send_cmd(buf);
}
#endif

int Client::create_buffer(BufMap *map, const char *name)
{
  HRESULT hRes;
  DWORD dwFlags = 0;

  dwFlags = dgnregGlobalCM; /* XXX why not dgnregNone? */

  map->bufnam = strdup(name);
  assert(map->bufnam);
  
  /*
    Create a DgnDictCustom control, and register a sink with it.
    The sink uses the Client object to communicate changes to Emacs.
    */
  hRes = CoCreateInstance(CLSID_DgnDictCustom, NULL, CLSCTX_ALL,
			  IID_IDgnDictCustom, (void **)&map->dict);
  ReturnIfFailed("Couldn't create a DgnDictCustom object (0x%X)");

  map->sink = new DictSink(targetWin, map->bufnam, map->dict, this);
  hRes = map->dict->Register(dwFlags, IID_IDgnDictCustomNotifySink,
			     map->sink);
  ReturnIfFailed("IDgnDictCustom::Register() failed (0x%X)");

  /*
    Set the DgnDictCust to use \n as the line terminator, as God
    intended.  This must be done before ActiveSet(TRUE), below.
    */
  hRes = map->dict->LineTerminatorSet("\n");
  ReturnIfFailed("IDgnDictCustom::LineTerminatorSet() failed (0x%X)");

  /*
    Only process dictation when Emacs is the foreground window.  It
    might be a useful feature to allow dictation in Emacs even when
    it is not in the foreground... but how would this interact with
    NaturalText and other windows that have their own dictation
    objects?

    XXX If we get an activate-buffer command before intialization is
    complete, targetWin will be NULL.  vr.el shouldn't do this, but
    we should probably deal more gracefully.
    */
  assert(targetWin);
  if (IsWindow(targetWin)) {
    hRes = map->dict->HwndActivateSet(targetWin);
    ReturnIfFailed("IDgnDictCustom::HwndActivateSet() failed (0x%X)");
  } else {
    HWND f = GetForegroundWindow();
    char c[256], t[256];

    GetWindowText(f, t, sizeof(t));
    GetClassName(f, c, sizeof(c));
    
    mb_lprintf(f, "VR Mode", MB_OK|MB_ICONERROR, 256,
	       "Warning!  VR Mode activity with wrong foreground "
	       "window.\r\n\r\n"
	       "Foreground window (%d) %s/%s does not match %s/%s\r\n\r\n",
	       f, c, t, clss ? clss : "*", title ? title : "*");
  }
  
  return 0;
}

void Client::kill_buffer(const char *name)
{
  BufMap *m, *p;

  m = map;
  p = NULL;
  while (m != NULL) {
    if (strcmp(m->bufnam, name) == 0)
      break;
    p = m;
    m = m->next;
  }

  if (m == NULL) {
    /* not found */
    //debug_log("kill-buffer: "); debug_log(name); debug_log(" not found\r\n");
    return;
  }

  // if it's the active buffer that's about to get killed, deactivate
  // it first
  if(m==activeBuffer)
    activate_buffer(0);

  /* clean up */
  /* XXX we never destroy the sink */
  if (m->dict != NULL) {
    m->dict->ActiveSet(FALSE);
    m->dict->UnRegister();
    m->dict->Release();
    m->dict = NULL;
  }
  if (m->bufnam != NULL) {
    free((void*)m->bufnam);
    m->bufnam = NULL;
  }

  /* unlink */
  if (m == map)
    map = m->next;
  else
    p->next = m->next;
  free(m);
  //debug_log("kill-buffer: "); debug_log(name); debug_log(" killed\r\n");
}

int Client::activate_buffer(const char *name)
{
  HRESULT hRes;
  BufMap *m;

  if (activeBuffer != NULL) {
    debug_lprintf(strlen(activeBuffer->bufnam)+ 36, "   deactivating buffer: %s\r\n", activeBuffer->bufnam);
    if (activeBuffer->dict != NULL)
      activeBuffer->dict->ActiveSet(FALSE);
    //BOOL test;
    //activeBuffer->dict->ActiveGet(&test);
    //if(test==FALSE)
    //  debug_lprintf(50, "   dictation is deactivated.\r\n");
    activeBuffer = NULL;
  }

  if (name == NULL) {
    //debug_log("deactivated buffer\r\n");
    return 0;
  }

  m = map;
  while (m != NULL) {
    debug_lprintf(strlen(m->bufnam)+16, "   buffer: %s\r\n", m->bufnam);
    if (strcmp(m->bufnam, name) == 0)
      break;
    m = m->next;
  }

  if (m == NULL) {
    m = (BufMap *) malloc(sizeof(BufMap));
    assert(m);
    m->next = map;
    map = m;
    create_buffer(m, name);
    debug_lprintf(32+strlen(name), "   created new buffer %s\r\n", name);
  }

  /* dictation may be disabled by an executing command */ 
  if (dict_allowed) {
    hRes = m->dict->ActiveSet(TRUE);
    ReturnIfFailed("IDgnDictCustom::ActiveSet failed (0x%X)");
  } else {
    debug_log("   dictation suspend by command\r\n");
  }
  
  activeBuffer = m;

  //debug_log("activated "); debug_log(name); debug_log("\r\n");
  return 0;
}

static BufMap *find_buffer(BufMap *m, char *name)
{
  while (m != NULL) {
    if (strcmp(m->bufnam, name) == 0)
      break;
    m = m->next;
  }
  return m;
}

void Client::change_text(char *msg)
{
  BufMap *m;
  char *name, *p, *q;
  int start, end, oldlen, tick;

  /* convert \\n --> \n */
  p = q = msg;
  while (*p) {
    if (*p == '\\' && p[1] == 'n') {
      *q++ = '\n';
      p += 2;
    } else
      *q++ = *p++;
  }
  *q = '\0';

  /* buffer name is enclosed in "'s */
  name = msg+1;
  p = strchr(msg+1, '"'); assert(p);
  *p++ = '\0';
  p++;

  if (activeBuffer != NULL && strcmp(activeBuffer->bufnam, name) == 0)
    m = activeBuffer;
  else
    m = find_buffer(map, name);
  if (m == NULL) {
    mb_lprintf(targetWin, "VR Error", MB_OK,
	       256, "ERROR!  No buffer named \"%s\" for\r\n\t%s\r\n",
	       name, msg);
    return;
  }

  start = atoi(p);
  p = strchr(p, ' '); assert(p); p++;
  end = atoi(p);
  p = strchr(p, ' '); assert(p); p++;
  oldlen = atoi(p);
  p = strchr(p, ' '); assert(p); p++;
  tick = atoi(p);
  p = strchr(p, ' '); assert(p); p++;

  if (m->dict->TextSet(p, start, oldlen) != 0)
    mb_lprintf(targetWin, "VR Error", MB_OK,
	       256 + strlen(p), "Cannot set text [%s],%d,%d in active buffer",
	       p, start, oldlen);
  m->sink->SetTick(tick);

#if 0
  dump_state((*activeBuffer));
#endif
}
