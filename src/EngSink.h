/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

class EngSink : public IDgnEngineControlNotifySink
{
public:
  // construction
  EngSink();

  // IUnknown
  STDMETHODIMP QueryInterface( REFIID, LPVOID FAR * );
  STDMETHODIMP_(ULONG) AddRef();
  STDMETHODIMP_(ULONG) Release();

  // IDgnEngineControlNotifySink
  STDMETHODIMP RecognitionStarting();
  STDMETHODIMP SpeakerChanged()
  { return S_OK; }
  STDMETHODIMP TopicChanged()
  { return S_OK; }
  STDMETHODIMP UtteranceBegin();
  STDMETHODIMP UtteranceEnd();
  STDMETHODIMP MimicDone(DWORD lParam, LPUNKNOWN pIUnknownError)
  { return S_OK; }
  
protected:
  void recognition(const char *);
  int m_nRefCount;
};
