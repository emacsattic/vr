/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
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
