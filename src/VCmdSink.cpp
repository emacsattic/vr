/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

#include <windows.h>
#include <stdio.h>
#include <tchar.h>
#include <assert.h>
#include <malloc.h> // alloca
#include <dnssdk.h>

#include "IO.h"
#include "VCmdSink.h"
#include "Client.h"
#include "vr.h"

#define ReturnIfFailed(hRes, msg) { \
  if(FAILED(hRes)) {		      \
    char buf[BUFSIZ];                 \
    sprintf(buf, msg, hRes);          \
    mb_lprintf(parent, "VR Error", MB_OK|MB_TOPMOST|MB_ICONERROR, \
	       strlen(buf)+1, "%s", buf); \
    return;	                      \
  }                                   \
}

VCmdSink::VCmdSink(HWND parent, IDgnVoiceCmd *voxCmd, Client *client)
{
  this->parent = parent;
  this->voxCmd = voxCmd;
  this->client = client;
  m_nRefCount = 0;
  theMenu = NULL;
}

VCmdSink::~VCmdSink()
{
  if (theMenu) {
    theMenu->ActiveSet(FALSE);
    //theMenu->Release();
    delete (theMenu);
  }
}

STDMETHODIMP VCmdSink::QueryInterface(const struct _GUID &riid,void **ppVoid)
{
  if (riid == IID_IDgnVCmdNotifySink) {
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

STDMETHODIMP_(ULONG) VCmdSink::AddRef(void)
{
  return ++m_nRefCount;
}

STDMETHODIMP_(ULONG) VCmdSink::Release(void)
{
  m_nRefCount--;
  if (m_nRefCount == 0) {
    delete this;
  }
  return m_nRefCount;
}

void VCmdSink::CreateMenu()
{
  HRESULT hRes;
  char *state;

  state = (char *) malloc(18);
  sprintf(state, "Client 0x%08x", client);
  
  hRes = voxCmd->MenuCreate(_T("GNU Emacs VR Mode"),
			    state,
			    dgnlangUSEnglish, /* unused */
			    _T("Standard"), /* unused */
			    vcmdmc_CREATE_TEMP,
			    IID_IDgnVMenu,
			    (IUnknown **)&theMenu);
  ReturnIfFailed(hRes, "Cannot create voice menu: 0x%x");

  hRes = theMenu->HwndMenuSet(parent);
  ReturnIfFailed(hRes, "Cannot set voice menu window: 0x%x");
  
  hRes = theMenu->ActiveSet(TRUE);
  ReturnIfFailed(hRes, "Cannot activate voice menu: 0x%x");
}

void VCmdSink::DefineCommand(char *cmd)
{
  HRESULT hRes;
  char *words, *action, abuf[1024];

  if (! theMenu)
    return;

  words = strtok(cmd, "|");
  action = strtok(NULL, "|");

  /* makes internal copies of string args */
  hRes = theMenu->Add(1235, words, "category: unused", "description: unused",
		      action, dgnactionUserDefined);
  sprintf(abuf, "Cannot define words \"%s\" to be command \"%s\": 0x%%x\n",
	  words, action);
  ReturnIfFailed(hRes, abuf);
}

void VCmdSink::DefineList(char *cmd)
{
  HRESULT hRes;
  char *listName, *words, *p, abuf[1024];
  int num, size;

  if (! theMenu)
    return;

  listName = strtok(cmd, "|");
  words = strtok(NULL, "|");

  num = 1;
  size = strlen(words) + 1;
  p = words;
  while ((p = strchr(p, ' ')) != NULL) {
    *p++ = '\0';
    num++;
  }

  /* makes internal copies of string args */
  hRes = theMenu->ListSet(listName, num, words, size);
  sprintf(abuf, "Cannot define list \"%s\" to be \"%s\": 0x%%x\n",
	  listName, words);
  ReturnIfFailed(hRes, abuf);
}

/* return non-zero if p matches -?([0-9]*\.)?[0-9]+ */
int is_number(const char *p)
{
  int dot, digit;
  if (*p == '-') p++;
  for (dot = 0, digit = 0; *p; p++) {
    if ((!dot) && *p == '.') { dot++; digit = 0; /* don't allow [0-9]\. */ }
    else if (isdigit(*p)) digit++;
    else return 0;
  }
  return digit;
}

STDMETHODIMP VCmdSink::CommandRecognize(LPCSTR pszCommand, DWORD dwID,
					LPCSTR pszAction, LPCSTR pListResults,
					DWORD dwListSize)
{
  /* a single-letter list element may become [ "x"] */
  char *buf = (char *) _alloca(dwListSize*4 + strlen(pszAction) + 18);
  int isnum;

  sprintf(buf, "(heard-command %s", pszAction);
  while (dwListSize > 0) {
    isnum = is_number(pListResults);
    strcat(buf, " ");
    if (!isnum) strcat(buf, "\"");
    strcat(buf, pListResults);
    if (!isnum) strcat(buf, "\"");
    dwListSize -= strlen(pListResults)+1;
    pListResults += strlen(pListResults)+1;
  }
  strcat(buf, ")\n");

  /*
    A command may change the editor buffer.  However, it may not be
    finished executing when the user *begins* the next utterance, causing a
    get-buffer-info command; this can lead to inconsistencies.  Therefore,
    disable all dictation until the command is complete.
    */
  client->disable_dictation();
  client->send_cmd(buf);
      
  return S_OK;
}

void VCmdSink::command_done()
{
  client->enable_dictation();
}

void VCmdSink::activate_frame(HWND wnd)
{
  HRESULT hRes;

  if (! theMenu)
    return;
  
  parent = wnd;
  hRes = theMenu->HwndMenuSet(wnd);
  if (FAILED(hRes))
    mb_lprintf(wnd, "VR Mode Error", MB_OK|MB_ICONERROR, 256,
	       "VCmdSink::HwndMenuSet() failed (0x%X)", hRes);
}  
