/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

#ifndef __DICTSINK_H__
#define __DICTSINK_H__

class Client;

class DictSink : public IDgnDictCustomNotifySink
{
public:
  DictSink(HWND, const char *, IDgnDictCustom *, Client *);

  STDMETHODIMP QueryInterface(REFIID, LPVOID FAR *);
  STDMETHODIMP_(ULONG) AddRef();
  STDMETHODIMP_(ULONG) Release();

  STDMETHODIMP RecognitionStarting();
  STDMETHODIMP MakeChanges (DWORD, DWORD, LPCTSTR, DWORD, DWORD);
  STDMETHODIMP PlaybackNowPlaying(DWORD, DGNNOWPLAYINGINFO *)
  { return S_OK; }
  STDMETHODIMP PlaybackBeginning()
  { return S_OK; }
  STDMETHODIMP PlaybackStopped()
  { return S_OK; }
  STDMETHODIMP PlaybackNoSpeech(DWORD, DWORD)
  { return S_OK; }
  STDMETHODIMP TranscriptionStopped()
  { return S_OK; }

  void SetTick(int tick);
   
protected:
  const char *name;
  int m_nRefCount, tick;
  IDgnDictCustom *m_pIDgnDictCustom;
  HWND parent;
  Client *client;
};

#endif
