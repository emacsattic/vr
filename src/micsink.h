/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

class MicSink : public IDgnMicrophoneNotifySink
{
public:
  // construction
  MicSink(IO *);

  // IUnknown
  STDMETHODIMP QueryInterface( REFIID, LPVOID FAR * );
  STDMETHODIMP_(ULONG) AddRef();
  STDMETHODIMP_(ULONG) Release();

  // IDgnMicrophoneNotifySink
  STDMETHODIMP MicStateChanged(DgnMicStateConstants micState,
			       BOOL bPaused);
  STDMETHODIMP VUMeter(WORD wLevel, DgnMicVUConstants VUState)
  { return S_OK; }
  
protected:
  int m_nRefCount;
  IO *io;
};
