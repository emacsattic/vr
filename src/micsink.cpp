/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

#include <windows.h>
#include <stdio.h>
#include <assert.h>
#include <dnssdk.h>

#include "IO.h"
#include "MicSink.h"
#include "Client.h"

MicSink::MicSink(IO *io)
{
  this->io = io;
  m_nRefCount = 0;
}

STDMETHODIMP MicSink::QueryInterface(const struct _GUID &riid,void **ppVoid)
{
  if (riid == IID_IDgnMicrophoneNotifySink) {
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

STDMETHODIMP_(ULONG) MicSink::AddRef(void)
{
  return ++m_nRefCount;
}

STDMETHODIMP_(ULONG) MicSink::Release(void)
{
  m_nRefCount--;
  if (m_nRefCount == 0) {
    delete this;
  }
  return m_nRefCount;
}

/* Tell VR mode about the change in microphone state */
STDMETHODIMP MicSink::MicStateChanged(DgnMicStateConstants micState,
				      BOOL bPaused)
{
  Client *c;
  for (c = clients; c != NULL; c = c->next) {
    switch (micState) {
    case dgnmicDisabled:
    case dgnmicOff:
      c->send_cmd("(mic-state off)\n");
      break;
    case dgnmicOn:
      c->send_cmd("(mic-state on)\n");
      break;
    case dgnmicSleeping:
      c->send_cmd("(mic-state sleep)\n");
      break;
    }
  }
  return S_OK;
}
    
  
