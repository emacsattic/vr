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

#ifndef __VR_HOOK_H__
#define __VR_HOOK_H__

#ifdef _EXPORTING
#define DECLSPEC    __declspec(dllexport)
#else
#define DECLSPEC    __declspec(dllimport)
#endif

#ifdef __cplusplus
extern "C" {
#endif
  
void DECLSPEC ClearHook();
int DECLSPEC SetHook(HWND hwnd, UINT msg);

#ifdef __cplusplus
}
#endif

#endif /* __VR_HOOK_H__ */

