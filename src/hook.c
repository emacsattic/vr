/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

#include <windows.h>
#include <stdio.h>

#include "hook.h"

#pragma comment(linker, "-section:SHARED,rws")
#pragma data_seg("SHARED")
static HHOOK hook = NULL;
static HWND targetWin = NULL;
static UINT notifyMsg = 0;
#pragma data_seg()

static HINSTANCE g_hinstDLL = NULL;

LRESULT CALLBACK HookProc(int nCode, WPARAM wParam, LPARAM lParam)
{
  CWPSTRUCT *msg = (CWPSTRUCT *) lParam;

  if (nCode >= 0 &&
      msg->message == WM_ACTIVATE && LOWORD(msg->wParam) != WA_INACTIVE)
    PostMessage(targetWin, notifyMsg, (WPARAM) msg->hwnd, 0);
  return (CallNextHookEx(hook,nCode,wParam,lParam));
}

void DECLSPEC ClearHook()
{
  if (hook)
    UnhookWindowsHookEx(hook);
  hook = NULL;
}

int SetHook(HWND hwnd, UINT msg)
{
  ClearHook();
  targetWin = hwnd;
  notifyMsg = msg;
  /* XXX use Emacs' thread id */
  hook = SetWindowsHookEx(WH_CALLWNDPROC, HookProc, g_hinstDLL, 0);
  return (hook != NULL);
}

BOOL WINAPI DllMain(HANDLE hModule, ULONG ulReason, LPVOID lpReserved)
{
  g_hinstDLL = hModule;
  return TRUE;
}
