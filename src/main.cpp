/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

#include <windows.h>
#include <stdio.h>
#include <stdarg.h>
#include <assert.h>
#include <malloc.h> // alloca

/* Actually define the GUIDs */
#include <objbase.h>
#include <initguid.h>
#include <dnssdk.h>

#include "resource.h"
#include "IO.h"
#include "EngSink.h"
#include "DictSink.h"
#include "MicSink.h"
#include "VCmdSink.h"
#include "hook.h"
#include "vr.h"
#include "Client.h"

#define MAX_TRACE_LENGTH 32766
#define WM_ACTIVATE_NOTIFY (WM_USER+10)

HWND hWndEdit = NULL;
IDgnEngineControl *engine = NULL;
IDgnMicrophone *microphone = NULL;
MicSink *micSink = NULL;
EngSink *engSink = NULL;
IO *io = NULL;
Client *clients;

/*
  Determines whether to exit or hide if window is closed.
  */
int is_child = 0;

/*
  This controls initial visibility of the dialog, and also tracks its
  visibility status.
  */
int show_state = 1;

/*
  This controls whether the protocol trace is active, and is controlled
  by a checkbox.
  */
int show_trace = 1;

/*
  This sets a non-DNS debugging mode
  */
int skip_dns = 0;

/* Handy macros, lifted from the DNS SDK samples. */
#define ReturnIfFailed(msg) { \
  if(FAILED(hRes)) {		      \
    char buf[BUFSIZ];                 \
    sprintf(buf, msg, hRes);          \
    MessageBox(NULL, buf, "VR Failure", MB_OK|MB_TOPMOST|MB_ICONERROR); \
    return E_FAIL;                    \
  }                                   \
}

void set_registry(HWND hDlg), get_registry(HWND hDlg);

void debug_log(const char *msg)
{ debug_lprintf(strlen(msg), "%s", msg); }

/*
  XXX This function needs to be synchronized... also, it uses SendMessage
  so it blocks if the main thread is blocked.  Perhaps it should use
  PostMessage.
  */
void debug_lprintf(int maxlen, const char *fmt, ...)
{
  va_list args;
  char *buf;
  int len;
  
  if (!show_state || ! show_trace)
    return;

  buf = (char *) _alloca(maxlen); // maybe malloc would be safer
  va_start(args, fmt);
  vsprintf(buf, fmt, args);
  va_end(args);
  
  len = GetWindowTextLength(hWndEdit);
  if ((len+strlen(buf)) > MAX_TRACE_LENGTH) {
    SendMessage(hWndEdit, EM_SETSEL, 0, (len+strlen(buf))-MAX_TRACE_LENGTH);
    SendMessage(hWndEdit, WM_CLEAR, 0, 0);
  }
  
  len = GetWindowTextLength(hWndEdit);
  if (len > 0)
    SendMessage(hWndEdit, EM_SETSEL, len, len);
  SendMessage(hWndEdit, EM_REPLACESEL, FALSE, (long)buf);
  SendMessage(hWndEdit, EM_SCROLLCARET, 0, 0);
}

int mb_lprintf(HWND wnd, const char *title, int flags,
	       int maxlen, const char *fmt, ...)
{
  va_list args;
  char *buf = (char *) _alloca(maxlen); // maybe malloc would be safer
  va_start(args, fmt);
  vsprintf(buf, fmt, args);
  va_end(args);

  debug_lprintf(strlen(title)+strlen(buf)+5, "%s: %s\r\n", title, buf);
  return MessageBox(wnd, buf, title, flags);
}

HRESULT initializeNatSpeak(IO *io)
{
    HRESULT hRes;
    DWORD dwFlags = 0;

    dwFlags = dgnregGlobalCM; /* XXX why not dgnregNone? */

    /*
      Create a DgnEngineControl object, and register a sink.  This
      gives us UtteranceBegin/End callbacks, so we can disable keyboard
      activity in clients during recognition.
      */
    hRes = CoCreateInstance(CLSID_DgnEngineControl, NULL, CLSCTX_ALL,
			    IID_IDgnEngineControl, (void **)&engine);
    ReturnIfFailed("Couldn't create a DgnEngineControl object (0x%X)");

    engSink = new EngSink();
    hRes = engine->Register(dwFlags, IID_IDgnEngineControlNotifySink,
			    (IDgnEngineControlNotifySink*)engSink);
    ReturnIfFailed("IDgnEngineControl::Register() failed (0x%X)");

    /*
      Create a DgnMicrophone control, and register a sink with it.
      The sink uses the IO object to communicate changes to Emacs.
      This allows VR mode to track and control the mic state.
      */
    hRes = CoCreateInstance(CLSID_DgnMicrophone, NULL, CLSCTX_ALL,
			    IID_IDgnMicrophone, (void **)&microphone);
    ReturnIfFailed("Couldn't create a DgnMicrophone object (0x%X)");

    micSink = new MicSink(io);
    hRes = microphone->Register(dwFlags, IID_IDgnMicrophoneNotifySink,
				(IDgnMicrophoneNotifySink*)micSink);
    ReturnIfFailed("IDgnMicrophone::Register() failed (0x%X)");
    return S_OK;
}

void cleanupNatSpeak()
{
  Client *c;
  while (clients != NULL) {
    c = clients;
    clients = clients->next;
    delete c;
  }
  if (engine) {
    engine->UnRegister (FALSE);
    engine->Release();
    engine = NULL;
  }
  if (microphone) {
    microphone->UnRegister();
    microphone->Release();
    microphone = NULL;
  }
}

struct enum_data { const char *clss, *title; HWND wnd; };
BOOL CALLBACK find_window_proc(HWND wnd, LPARAM param)
{
  struct enum_data *data = (struct enum_data *) param;
  char clss[256], title[256];

  GetWindowText(wnd, title, sizeof(title));
  GetClassName(wnd, clss, sizeof(clss));
  if ((data->clss == NULL || strstr(clss, data->clss) != NULL) &&
      (data->title == NULL || strstr(title, data->title) != NULL)) {
    data->wnd = wnd;
    return FALSE;
  }
  return TRUE;
}
HWND find_window(const char *clss, const char *title)
{
  struct enum_data data = { clss, title, NULL };
  if (clss == NULL && title == NULL)
    return NULL;
  EnumWindows((WNDENUMPROC)find_window_proc, (LPARAM)&data);
  return data.wnd;
}

void do_connect(Client *c, HWND hDlg)
{
  c->next = clients;
  clients = c;
  
  SetWindowText(GetDlgItem(hDlg, IDC_STATE), io->get_state());
  SetWindowText(GetDlgItem(hDlg, IDC_HOST), c->get_host());
  
  c->send_cmd("(connected)\n");
  io->notify();
}

void do_disconnect(Client *client, HWND hDlg)
{
  Client *c, *p;

  c = clients;
  p = NULL;
  while (c != NULL) {
    if (c == client)
      break;
    p = c;
    c = c->next;
  }

  if (c == NULL) {
    /* not found */
    debug_log("XXX cannot find client in list!\r\n");
    return;
  }


  /* unlink */
  if (c == clients)
    clients = c->next;
  else
    p->next = c->next;

  delete c;
  
  SetWindowText(GetDlgItem(hDlg, IDC_STATE), io->get_state());
  SetWindowText(GetDlgItem(hDlg, IDC_HOST), "");
}

void do_cmd(Client *c, HWND hDlg)
{
  char *buf = c->get_cmd();
  if (! buf) {
    do_disconnect(c, hDlg);
    io->notify();
    return;
  }
  
  char *cmd = strtok(buf, " ");
  char *arg = cmd + strlen(cmd) + 1;

  if (strcmp(cmd, "initialize") == 0) {
    c->clss = strtok(arg, "|");
    c->title = strtok(NULL, "|");
    if (c->clss && strcmp(c->clss, "nil") == 0)
      c->clss = NULL;
    if (c->title && strcmp(c->title, "nil") == 0)
      c->title = NULL;
    c->clss = c->clss ? strdup(c->clss) : NULL;
    c->title = c->title ? strdup(c->title) : NULL;
    c->targetWin = find_window(c->clss, c->title);
    if (c->targetWin == NULL)
      c->send_cmd("(initialize no-window)\n");
    else if(!skip_dns && FAILED(c->initialize()))
      c->send_cmd("(initialize failed)\n");
    else {
      DgnMicStateConstants state;
      BOOL paused;
      c->send_cmd("(initialize succeeded)\n");
      microphone->MicStateGet(&state, &paused);
      micSink->MicStateChanged(state, paused);
      SetForegroundWindow(c->targetWin);
    }
  } else if (strcmp(cmd, "exit") == 0) {
    PostMessage(hDlg, WM_QUIT, 0, 0);
  } else if (strcmp(cmd, "show-window") == 0) {
    show_state = 1;
    ShowWindow(hDlg, show_state ? SW_SHOW : SW_HIDE);
  } else if (strcmp(cmd, "hide-window") == 0) {
    show_state = 0;
    ShowWindow(hDlg, show_state ? SW_SHOW : SW_HIDE);
  } else if (strcmp(cmd, "toggle-mic") == 0) {
    DgnMicStateConstants state;
    BOOL paused;
    HRESULT hRes;
    
    if (! (FAILED(hRes = microphone->MicStateGet(&state, &paused)))) {
      switch (state) {
      case dgnmicOff:
	microphone->MicStateSet(dgnmicOn);
	break;
      case dgnmicOn:
      case dgnmicSleeping:
	microphone->MicStateSet(dgnmicOff);
	break;
      case dgnmicDisabled:
	break;
      }
    } else {
      debug_lprintf(256, "MicStateSet failed: 0x%x\r\n", hRes);
    }
  } else if (strncmp(cmd, "define-command", 14) == 0) {
    c->vcmdSink->DefineCommand(arg);
  } else if (strncmp(cmd, "define-list", 11) == 0) {
    c->vcmdSink->DefineList(arg);
  } else if (strncmp(cmd, "activate-buffer", 15) == 0) {
    c->activate_buffer(arg);
  } else if (strncmp(cmd, "deactivate-buffer", 17) == 0) {
    c->activate_buffer(NULL);
  } else if (strncmp(cmd, "kill-buffer", 11) == 0) {
    c->kill_buffer(arg);
  } else if (strncmp(cmd, "change-text", 11) == 0) {
    c->change_text(arg);
  } else if (strncmp(cmd, "command-done", 12) == 0) {
    c->vcmdSink->command_done();
  } else {
    debug_log("   UNKNOWN COMMAND!\r\n");
  }

  free(buf);
  io->notify();
}
 
BOOL CALLBACK DialogProc(HWND hDlg, UINT uMsg, WPARAM wParam, LPARAM lParam)
{
  Client *c;
  HANDLE hIcon = NULL;
  char buf[BUFSIZ];
  
  switch (uMsg) {
  case WM_INITDIALOG:
    assert((hWndEdit = GetDlgItem(hDlg, IDC_TEXTSINK)) != NULL);
    SendMessage(hWndEdit, EM_SETLIMITTEXT, MAX_TRACE_LENGTH, 0);
    return TRUE;

  case WM_SIZE:
    if (wParam == SIZE_RESTORED) {
      HWND hSink;
      RECT rect;
      int width = LOWORD(lParam), height = HIWORD(lParam);

      hSink = GetDlgItem(hDlg, IDC_TEXTSINK);
      GetWindowRect(hSink, &rect);
      MapWindowPoints(HWND_DESKTOP, hDlg, (POINT *)&rect, 2);
      /* XXX "10" is empirically determined; I don't the right way */
      MoveWindow(hSink, rect.left, rect.top,
		 width-rect.left-10, height-rect.top-10, TRUE);
    }
    break;

#define DEBUG_WINDOWS
  case WM_ACTIVATE_NOTIFY:
    for (c = clients; c != NULL; c = c->next) {
      struct enum_data data = { c->clss, c->title, NULL };
#ifdef DEBUG_WINDOWS
      char clss[256], title[256];
      GetWindowText((HWND) wParam, title, sizeof(title));
      GetClassName((HWND) wParam, clss, sizeof(clss));
#endif
      
      if (find_window_proc((HWND) wParam, (LPARAM)&data) == FALSE) {
#ifdef DEBUG_WINDOWS
	debug_lprintf(1024,
		      "Wnd (%d) %s/%s matches %s/%s\r\n",
		      (HWND) wParam, clss, title,
		      c->clss?c->clss:"*", c->title?c->title:"*");
#endif
	c->activate_frame((HWND) wParam);
	sprintf(buf, "(frame-activated %d)\n", (long) wParam);
	c->send_cmd(buf);
      } else {
	// inform the client that it has been deactivated
	c->deactivate_frame ();
#ifdef DEBUG_WINDOWS
	debug_lprintf(1024,
		      "Wnd (%d) %s/%s doesn't match %s/%s\r\n",
		      (HWND) wParam, clss, title,
		      c->clss?c->clss:"*", c->title?c->title:"*");
#endif
      }
    }
    return TRUE;
    break;

  case WM_COMMAND:
    switch(LOWORD(wParam)) {
    case IDC_DO_CONNECT:
      do_connect((Client *)lParam, hDlg);
      break;
    case IDC_DO_COMMAND:
      do_cmd((Client *)lParam, hDlg);
      break;
    case IDC_DO_DISCONNECT: /* never sent from anywhere */
      do_disconnect((Client *)lParam, hDlg);
      break;
	
    case IDC_SHOW_WINDOW:
      show_state = IsDlgButtonChecked(hDlg, IDC_SHOW_WINDOW);
      set_registry(hDlg);
      break;
    case IDC_SHOW_TRACE:
      show_trace = IsDlgButtonChecked(hDlg, IDC_SHOW_TRACE);
      set_registry(hDlg);
      break;
    case IDC_SHOW_WIN:
      show_state = 1;
      ShowWindow(hDlg, show_state ? SW_SHOW : SW_HIDE);
      break;
    case IDC_HIDE_WIN:
      set_registry(hDlg);
      show_state = 0;
      ShowWindow(hDlg, show_state ? SW_SHOW : SW_HIDE);
      break;
      
    case IDC_EXIT:
      set_registry(hDlg);
      PostQuitMessage(0);
      break;

    default:
      return FALSE;
    }
    return TRUE;

  case WM_CLOSE:
    set_registry(hDlg);
    PostQuitMessage(0);
    return FALSE;
    break;

  case WM_SYSCOMMAND:
    if(wParam == SC_CLOSE) {
      if (is_child && !skip_dns) {
	/* don't quit, just close window */
	PostMessage(hDlg, WM_COMMAND, IDC_HIDE_WIN, 0);
	return TRUE;
      } else {
	PostQuitMessage(0);
      }
    }
    break;

  default:
    return FALSE;
  }

  return FALSE;
}

void get_registry(HWND hDlg)
{
  HKEY key;
  DWORD size;
  int x, y, cx, cy;

  show_state = show_trace = 1;
  
  if (RegOpenKeyEx(HKEY_CURRENT_USER,
		   "Software\\VR Mode\\Settings",
		   0, KEY_ALL_ACCESS, &key) == ERROR_SUCCESS) {
    size = sizeof(show_state);
    RegQueryValueEx(key, "Show Window", NULL, NULL,
		    (unsigned char *)&show_state, &size);
    size = sizeof(show_trace);
    RegQueryValueEx(key, "Show Trace", NULL, NULL,
		    (unsigned char *)&show_trace, &size);

    size = sizeof(int);
    x = y = cx = cy = 0;
    RegQueryValueEx(key, "x", NULL, NULL, (unsigned char *)&x, &size);
    RegQueryValueEx(key, "y", NULL, NULL, (unsigned char *)&y, &size);
    RegQueryValueEx(key, "cx", NULL, NULL, (unsigned char *)&cx, &size);
    RegQueryValueEx(key, "cy", NULL, NULL, (unsigned char *)&cy, &size);
    if (x > 0 && y > 0 && cx > 0 && cy > 0)
      SetWindowPos(hDlg, NULL, x, y, cx, cy, SWP_NOZORDER);
    
    RegCloseKey(key);
  }

  CheckDlgButton(hDlg, IDC_SHOW_WINDOW,
		 show_state ? BST_CHECKED : BST_UNCHECKED);
  CheckDlgButton(hDlg, IDC_SHOW_TRACE,
		 show_trace ? BST_CHECKED : BST_UNCHECKED);
}

void set_registry(HWND hDlg)
{
  HKEY key;
  DWORD disp, size;
  RECT rect;
  long cx, cy;

  if (RegCreateKeyEx(HKEY_CURRENT_USER,
		     "Software\\VR Mode\\Settings",
		     NULL, NULL, REG_OPTION_NON_VOLATILE,
		     KEY_ALL_ACCESS, NULL, &key, &disp) != ERROR_SUCCESS) {
    debug_lprintf(64, "Cannot open registry key!  Using defaults.\r\n");
    return;
  }
  size = sizeof(show_state);
  RegSetValueEx(key, "Show Window", NULL, REG_DWORD,
		(unsigned char *)&show_state, size);
  size = sizeof(show_trace);
  RegSetValueEx(key, "Show Trace", NULL, REG_DWORD,
		(unsigned char *)&show_trace, size);

  GetWindowRect(hDlg, &rect);
  cx = rect.right - rect.left;
  cy = rect.bottom - rect.top;
  size = sizeof(long);
  RegSetValueEx(key, "x", NULL, REG_DWORD, (unsigned char *)&rect.left, size);
  RegSetValueEx(key, "y", NULL, REG_DWORD, (unsigned char *)&rect.top, size);
  RegSetValueEx(key, "cx", NULL, REG_DWORD, (unsigned char *)&cx, size);
  RegSetValueEx(key, "cy", NULL, REG_DWORD, (unsigned char *)&cy, size);
  
  RegCloseKey(key);
}

/* do I really have to write this myself? */
int parse_argv(char *cmdline, char ***pargv)
{
  char **argv;
  char *c = strdup(cmdline), *p;
  int argc, size;

  size = 4;
  argv = (char **) malloc((size+1)*sizeof(char *));
  argc = 0;

  argv[argc++] = (char *) malloc(255);
  GetModuleFileName(NULL, argv[0], 255);

  while ((p = strtok(c, " ")) != NULL) {
    c = NULL;
    if (argc == size) {
      size *= 2;
      argv = (char **) realloc(argv, (size+1)*sizeof(char *));
    }
    argv[argc++] = p;
  }
  argv[argc] = NULL;
  argv = (char **) realloc(argv, argc*sizeof(char *));
  
  *pargv = argv;
  return argc;
}

void usage()
{
  MessageBox(NULL,
	     "Usage: VR.EXE [-port port] [-child]",
	     "VR.EXE Command Line Error",
	     MB_OK);
  exit(1);
}

int WINAPI WinMain(HINSTANCE hInstance, HINSTANCE hInstPrev,
                    LPSTR szCmdLine, int nCmdShow)
{
  char **argv;
  int argc = parse_argv(szCmdLine, &argv);
  int i, port;

  port = 0;
  for (i = 1; i < argc; i++) {
    if (strcmp(argv[i], "-port") == 0) {
      if (argv[++i] == NULL)
	usage();
      port = atoi(argv[i]);
    } else if (strcmp(argv[i], "-child") == 0) {
      is_child++;
    } else
      usage();
  }
  
  WSADATA wsaData;
  if (WSAStartup(MAKEWORD(2,1),&wsaData) != 0){
    fprintf(stderr,"WSAStartup failed: %d\n",GetLastError());
    MessageBox(NULL, "Winsock initialization failed.", NULL, MB_OK);
    return -1;
  }
  
  if(FAILED(CoInitialize(NULL))) {
    MessageBox(NULL, "OLE initialization failed.", NULL, MB_OK);
    return -1;
  }

  clients = NULL;

  HWND hDlg = CreateDialogParam(hInstance, MAKEINTRESOURCE(IDD_VR_DIALOG),
				NULL, (DLGPROC)DialogProc, 0);
  if (hDlg == NULL) {
    CoUninitialize();
    return -1;
  }

  get_registry(hDlg);
  
  ShowWindow(hDlg, show_state ? SW_SHOW : SW_HIDE);

  if (! SetHook(hDlg, WM_ACTIVATE_NOTIFY)) {
    MessageBox(NULL, "VR Mode cannot set its windows hook procedure.  "
	       "VR Mode will not track Emacs frame changes properly.",
	       "VR Mode Error", MB_OK|MB_ICONERROR);
  }

  io = new IO(port, hDlg);
  io->start();

  if (FAILED(initializeNatSpeak(io))) {
    MessageBox(NULL, "NatSpeak initialization failed.", NULL, MB_OK);
    return -1;
  }
  
  SetDlgItemInt(hDlg, IDC_PORT, io->get_port(), TRUE);
  SetWindowText(GetDlgItem(hDlg, IDC_STATE), io->get_state());
  SetWindowText(GetDlgItem(hDlg, IDC_HOST), "");
  debug_lprintf(64, "<- (listening %d)\r\n", io->get_port());
  printf("(listening %d)\n", io->get_port());
  fflush(stdout);

  MSG msg;
  while(GetMessage(&msg, NULL, 0, 0)) {
    if(! IsDialogMessage(hDlg, &msg)) {
      TranslateMessage(&msg);
      DispatchMessage(&msg);
    }
  }

  if (!skip_dns)
    cleanupNatSpeak();
  delete io;
 
  ClearHook();
  DestroyWindow(hDlg);
  CoUninitialize();
  WSACleanup();
  return 0;
}
