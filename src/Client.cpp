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

// $Id$

#include <stdio.h>
#include <assert.h>
#include <windows.h>

#include <dnssdk.h>         // Dragon NaturallySpeaking SDK header
#include "resource.h"

#include "IO.h"
#include "DictSink.h"
#include "VCmdSink.h"
#include "vr.h"		// for debug_*
#include "Client.h"

int Client::counter = 0;

/* Handy macros, lifted from the DNS SDK samples. */
#define ReturnIfFailed(msg) { \
  if(FAILED(hRes)) {		      \
    char buf[BUFSIZ];                 \
    sprintf(buf, msg, hRes);          \
    MessageBox(targetWin, buf, "VR Failure", MB_OK|MB_TOPMOST|MB_ICONERROR); \
    return E_FAIL;                    \
  }                                   \
}
Client::Client(IO *io, int emacs_sock, int dns_sock)
{
  this->io = io;
  this->emacs_sock = emacs_sock;
  this->dns_sock = dns_sock;
  targetWin = NULL;
  voxCmd = NULL;
  vcmdSink = NULL;
  map = activeBuffer = NULL;
  clss = title = NULL;
  dict_allowed = 1;
  num = counter++;
}

Client::~Client()
{
  BufMap *m;

  send_cmd("(terminating)\n");
  closesocket(dns_sock);
  closesocket(emacs_sock);
  
  while (map != NULL) {
    if (map->dict != NULL) {
      map->dict->ActiveSet(FALSE);
      map->dict->UnRegister();
      map->dict->Release();
      map->dict = NULL;
    }
    if (map->bufnam != NULL)
      free((void*)map->bufnam);
    m = map;
    map = map->next;
    free(m);
  }
  if (vcmdSink) {
    delete vcmdSink;
    vcmdSink = NULL;
  }
  if (voxCmd) {
    voxCmd->UnRegister();
    //voxCmd->Release();
    voxCmd = NULL;
  }
  free(clss);
  free(title);
}  

HRESULT Client::initialize()
{
  HRESULT hRes;
  DWORD dwFlags = 0;

  assert(IsWindow(targetWin));
    
  dwFlags = dgnregGlobalCM; /* XXX why not dgnregNone? */

  /*
    Create a DgnVoiceCmd control, and register a sink with it.
    The vcmdSink is invoked when a voice command is uttered, and
    implements the define-command VR Mode Protocol command.

    A DgnDictCust and DictSink are created for each buffer.
    */
  hRes = CoCreateInstance(CLSID_DgnVoiceCmd, NULL, CLSCTX_ALL,
			  IID_IDgnVoiceCmd, (void **)&voxCmd);
  ReturnIfFailed("Couldn't create a DgnVoiceCmd object (0x%X)");

  vcmdSink = new VCmdSink(targetWin, voxCmd, this);
  hRes = voxCmd->Register("", dwFlags, IID_IDgnVCmdNotifySink, vcmdSink);
  ReturnIfFailed("IDgnVCmdNotifySink::Register() failed (0x%X)");
  vcmdSink->CreateMenu();
  return S_OK;
}

void Client::send_cmd(const char *cmd)
{
  // before we send the command, flush any junk remaining on the
  // stream
  int n_flush;
  if ((n_flush=flush_reply_stream()) > 0)
    debug_lprintf (64 , "flushed %d junk characters from reply stream\r\n",
		   n_flush);

  io->send_line(dns_sock, num, cmd);
}

void Client::send_reply(const char *cmd)
{
  io->send_line(emacs_sock, num, cmd);
}

char *Client::get_host()
{
  return io->get_host(emacs_sock);
}

char *Client::get_cmd()
{
  return io->get_line(emacs_sock, num, NULL);
}

char *Client::get_reply(const char *desc)
{
  return io->get_line(dns_sock, num, desc);
}

int Client::flush_reply_stream ()
{
  return io->flush_stream(dns_sock);
}

void Client::activate_frame(HWND wnd)
{
  HRESULT hRes;
  
  targetWin = wnd;
  for (BufMap *m = map; m != NULL; m = m->next) {
    hRes = m->dict->HwndActivateSet(targetWin);
    if (FAILED(hRes))
      mb_lprintf(wnd, "VR Mode Error", MB_OK|MB_ICONERROR, 256,
		 "IDgnDictCustom::HwndActivateSet() failed (0x%X)", hRes);
  }
  // enable dictation again if it was disabled when the frame was deactivated
  enable_dictation ();

  vcmdSink->activate_frame(wnd);
}

// this is used to prevent unnecessary get-buffer-info calls when the
// frame is not in focus 
void Client::deactivate_frame ()
{
  disable_dictation ();
}

void Client::disable_dictation()
{
  dict_allowed = 0;
  if (activeBuffer != NULL)
    activeBuffer->dict->ActiveSet(FALSE);
}

void Client::enable_dictation()
{
  dict_allowed = 1;
  if (activeBuffer != NULL)
    activeBuffer->dict->ActiveSet(TRUE);
}  
  
