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

#ifndef __VCMDSINK_H__
#define __VCMDSINK_H__

class Client;

class VCmdSink : public IDgnVCmdNotifySink
{
public:
  // construction
  VCmdSink(HWND, IDgnVoiceCmd *, Client *);
  ~VCmdSink();

  // IUnknown
  STDMETHODIMP QueryInterface( REFIID, LPVOID FAR * );
  STDMETHODIMP_(ULONG) AddRef();
  STDMETHODIMP_(ULONG) Release();

  // IDgnVCmdNotifySink
  STDMETHODIMP CommandRecognize(LPCSTR pszCommand, DWORD dwID,
				LPCSTR pszAction, LPCSTR pListResults,
				DWORD dwListSize);
  
  STDMETHODIMP CommandOther(LPCSTR pszCommand, LPCSTR pszApp, LPCSTR pszState)
  { return S_OK; }
  STDMETHODIMP ActionComplete(DWORD dwID, BOOL bAborted)
  { return S_OK; }

  // application
  void DefineCommand(char *);
  void DefineList(char *);
  void CreateMenu();
  void activate_frame(HWND);
  void command_done();
  
protected:
  int m_nRefCount;
  Client *client;
  IDgnVoiceCmd *voxCmd;
  HWND parent;
  IDgnVMenu *theMenu;
};

#endif /* __VCMDSINK_H__ */
