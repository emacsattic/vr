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
