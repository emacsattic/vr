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
#include <malloc.h>

#include "vr.h"
#include "Client.h"
#include "EngSink.h"

EngSink::EngSink()
{
}

STDMETHODIMP EngSink::QueryInterface(const struct _GUID &riid,void **ppVoid)
{
  if (riid == IID_IDgnEngineControlNotifySink) {
    *ppVoid = this;
    m_nRefCount++;
    return S_OK;
  } else if (riid == IID_IUnknown) {
    *ppVoid = this;
    m_nRefCount++;
    return S_OK;
  } else
    return E_NOINTERFACE;
}

STDMETHODIMP_(ULONG) EngSink::AddRef(void)
{
  return ++m_nRefCount;
}

STDMETHODIMP_(ULONG) EngSink::Release(void)
{
  m_nRefCount--;
  if (m_nRefCount == 0) {
    delete this;
  }
  return m_nRefCount;
}

STDMETHODIMP EngSink::RecognitionStarting()
{ return S_OK; }

STDMETHODIMP EngSink::UtteranceBegin()
{
  recognition("begin");
  return S_OK;
}

STDMETHODIMP EngSink::UtteranceEnd()
{
  recognition("end");
  return S_OK;
}

/*
  XXX It would be better (?) only to notify the active client of recognition
  events; no need to lock the keyboard on the others.
  */
void EngSink::recognition(const char *state)
{
  char *buf = (char *) _alloca(strlen(state) + 32);
  Client *c;

  sprintf(buf, "(recognition %s)\n", state);
  
  for (c = clients; c != NULL; c = c->next)
    c->send_cmd(buf);
}
