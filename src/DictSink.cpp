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
#include "resource.h"

#include "IO.h"
#include "DictSink.h"
#include "MicSink.h"
#include "VCmdSink.h"
#include "vr.h"
#include "Client.h"

/*
  XXX I fixed the bug for which I put in the assert.  So, remove it
  eventually.
  */
#define GET_REPLY_INT(v, d) {char *r=client->get_reply(d); assert(d && r!=name);\
  if (!r) { debug_lprintf(64, "timeout waiting for %s\r\n", d); return E_FAIL; } \
  v=atoi(r);free(r);}

#define ReturnIfFailed(hRes, unlock, msg) { \
  if(FAILED(hRes)) {		      \
    char buf[BUFSIZ];                 \
    sprintf(buf, msg, hRes);          \
    mb_lprintf(parent, "VR Error", MB_OK|MB_TOPMOST|MB_ICONERROR, \
	       strlen(buf)+1, "%s", buf); \
    if (unlock) m_pIDgnDictCustom->UnLock(); \
    PostQuitMessage(0);               \
    return S_OK;                      \
  }                                   \
}

DictSink::DictSink(HWND parent, const char *name,
		   IDgnDictCustom *pIDgnDictCustom, Client *c)
  : name(name)
{
  this->m_nRefCount = 0;
  this->parent = parent;
  this->m_pIDgnDictCustom = pIDgnDictCustom;
  this->client = c;
  this->tick = -1;
}

STDMETHODIMP DictSink::QueryInterface(const struct _GUID &riid,void **ppVoid)
{
  if (riid == IID_IDgnDictCustomNotifySink) {
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

STDMETHODIMP_(ULONG) DictSink::AddRef(void)
{
    return ++m_nRefCount;
}

STDMETHODIMP_(ULONG) DictSink::Release(void)
{
    m_nRefCount--;
    if (m_nRefCount == 0) {
      delete this;
    }
    return m_nRefCount;
}

STDMETHODIMP DictSink::RecognitionStarting()
{
    BOOL test;
    m_pIDgnDictCustom->ActiveGet(&test);
    if(test==FALSE)
      debug_lprintf(50, "    Dictation is deactivated in %s\r\n", name);
    else {

    int modified, window_start, window_end, sel_start, sel_end, length;
    char *text, buf[BUFSIZ];
    HRESULT hRes;

    //debug_lprintf(64, "**  recognition starting\r\n");

    sprintf(buf, "(get-buffer-info \"%s\" %d)\n", name, tick);
    client->send_cmd(buf);
    
    GET_REPLY_INT(modified, "is-modified");

    hRes = m_pIDgnDictCustom->Lock(0);
    ReturnIfFailed(hRes, 0, "IDgnDictCustom->Lock() failed, hRes = 0x%X");

    if (modified) {
      // "modified" means that an unsynchronized change has occurred,
      // so we reload the entire buffer contents 
      
      GET_REPLY_INT(length, "text length");
      text = client->get_reply("text");
      if (! text) {
	debug_lprintf(64, "timeout waiting for text\r\n");
	return E_FAIL;
       }
      hRes = m_pIDgnDictCustom->TextSet(text, 0, length);
      ReturnIfFailed(hRes, 1, "IDgnDictCustom->TextSet() failed, hRes = 0x%X");
      
      /*
	the sample code does NOT free the allocated text block, but
	Dragon says it is safe to do so.
	*/
      free(text);
    }

    // now ask for the changes that may have occured as a result of the
    // get-buffer info call. 
    int cnt;
    char *c;
    GET_REPLY_INT(cnt, "change count");
    for (int i = 0; i < cnt; i++) {
      c = client->get_reply("change");
      if (! c) {
	debug_lprintf(64, "timeout waiting for change\r\n");
	m_pIDgnDictCustom->UnLock();
	return E_FAIL;
      }
      client->change_text(c+12); // discard leading "change-text " */
    }

    GET_REPLY_INT(sel_start, "selection start");
    GET_REPLY_INT(sel_end, "selection end");
    GET_REPLY_INT(window_start, "window start");
    GET_REPLY_INT(window_end, "window end");
    //Most recent buffer tick
    GET_REPLY_INT(this->tick, "tick");
		      
    hRes = m_pIDgnDictCustom->TextSelSet(sel_start, sel_end - sel_start);
    ReturnIfFailed(hRes,1, "IDgnDictCustom->TextSelSet() failed, hRes = 0x%X");

    hRes = m_pIDgnDictCustom->VisibleTextSet(window_start,
					     window_end - window_start);
    ReturnIfFailed(hRes,1,"IDgnDictCustom->VisibleTextSet() failed,hRes=0x%X");

    hRes = m_pIDgnDictCustom->UnLock(); // unlock internal buffer
    ReturnIfFailed(hRes,0, "IDgnDictCustom->UnLock() failed, hRes = 0x%X");
    }

    return S_OK; 
}

//the NaturallySpeaking callback used when dictation has changed the buffer
STDMETHODIMP DictSink::MakeChanges(DWORD dwStart, DWORD dwNumChars,
				   LPCTSTR pszText, DWORD dwSelStart,
				   DWORD dwSelNumChars)
{
  int cnt = 0, tick, i;
  char *c, *t;
  char buf[BUFSIZ];

  /*
    Convert: " to \\", \n to \\n, and \ to \\.
    */
  if (pszText != NULL) {
    for (cnt = 0, c = (char *) pszText; *c; c++)
      if (*c == '"' || *c == '\\' || *c == '\n')
	cnt++;
    if (cnt > 0) {
      t = (char *) malloc(strlen(pszText) + cnt + 1);
      for (c = t; *pszText; pszText++) {
	switch (*pszText) {
	case '\n':
	  *c++ = '\\';
	  *c++ = 'n';
	  break;
	case '"':
	case '\\':
	  *c++ = '\\';
	  /* fall through */
	default:
	  *c++ = *pszText;
	  break;
	}
      }
      *c++ = *pszText;
    }
  }

  assert(sizeof(buf) >
	 (strlen(pszText != NULL ? (cnt > 0 ? t : pszText) : "") + 100));

  sprintf(buf, "(make-changes %d %d \"%s\" %d %d)\n",
	  dwStart, dwNumChars,
	  pszText != NULL ? (cnt > 0 ? t : pszText) : "",
	  dwSelStart, dwSelNumChars);
  client->send_cmd(buf);

  if (cnt > 0)
    free(t);

  GET_REPLY_INT(tick, "tick");

  m_pIDgnDictCustom->Lock(0);
  GET_REPLY_INT(cnt, "change count");
  for (i = 0; i < cnt; i++) {
    c = client->get_reply("change");
    if (! c) {
      debug_lprintf(64, "timeout waiting for change\r\n");
      m_pIDgnDictCustom->UnLock();
      return E_FAIL;
    }
    client->change_text(c+12); // discard leading "change-text " */
  }
  m_pIDgnDictCustom->UnLock();

  /*
    Change replies to make-changes have the wrong tick, and
    change_text() sets it, so make sure we use the make-changes value.
    */
  if (tick != -1)
    this->tick = tick;
  
  return S_OK; 
}

void DictSink::SetTick(int tick)
{ this->tick = tick; }
