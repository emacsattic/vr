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

#include <stdio.h>
#include <assert.h>
#include <windows.h>

#include <dnssdk.h>         // Dragon NaturallySpeaking SDK header
#include "resource.h"

#include "IO.h"
#include "DictSink.h"
#include "MicSink.h"
#include "VCmdSink.h"
#include "vr.h"		// for debug_*
#include "Client.h"

static DWORD WINAPI start_io(LPVOID *data)
{
  return ((IO *) data)->run();
}

IO::IO(int port, HWND wnd)
{
  this->port = port;
  this->wnd = wnd;
  listener = -1;
  lock = CreateEvent(NULL, FALSE, FALSE, NULL);
  done = 0;
}

void IO::start()
{
  assert(CreateThread(NULL, 0, (LPTHREAD_START_ROUTINE)start_io,
		      this, 0, &tid) != NULL);
  assert (client_mutex = CreateMutex (NULL, FALSE, NULL));
  wait();
}

IO::~IO()
{
  done = 1;
  closesocket(listener);
}

const char *IO::get_state()
{
  switch (state) {
  case LISTEN: return "State: Listening";
  case FAILED:
  default:
    return "State: failed";
  }
}

char *IO::get_host(int sock)
{
  struct sockaddr_in saddr;
  int len = sizeof(saddr);

  if (getsockname(sock, (struct sockaddr *)&saddr, &len) < 0)
    return NULL;
  return inet_ntoa(saddr.sin_addr);
}

int IO::get_port()
{
  struct sockaddr_in saddr;
  int len = sizeof(saddr);

  if (getsockname(listener, (struct sockaddr *)&saddr, &len) < 0)
    return -1;
  return ntohs(saddr.sin_port);
}

void IO::send_line(int sock, int clnt, const char *cmd)
{
  int n, len = strlen(cmd);
  if ((n = send(sock, cmd, len, 0)) != len)
    debug_lprintf(len+256, "FAILED: %X <- %s: %d, %d\r\n",
		  clnt, cmd, n, WSAGetLastError());
  else
    debug_lprintf(len+32, "%X <- %s\r\n", clnt, cmd);
}

int IO::read_fully(int sock, char *buf, int len)
{
  struct timeval tv;
  fd_set rfs;
  int n, t;

  t = 0;
  while (len > 0) {
    FD_ZERO(&rfs);
    FD_SET(sock, &rfs);
    tv.tv_sec = 5; tv.tv_usec = 0;
    n = select(0 /* ignored */, &rfs, NULL, NULL, &tv);
    if (n <= 0)
      return -1;
    else {
      n = recv(sock, buf, len, 0);
      if (n < 0)
	return -1;
      else if (n == 0)
	return t == 0 ? 0 : -1;
      buf += n;
      len -= n;
      t += n;
    }
  }
  return t;
}

char *IO::get_line(int sock, int clnt, const char *desc)
{
  int n;
  long len;
  char *l;

  if (desc)
    debug_lprintf(strlen(desc)+20, "%X -> %s ", clnt, desc);
  else
    debug_lprintf(20, "%X -> ", clnt);

  n = read_fully(sock, (char *)&len, 4);
  if (n == 0) {
    debug_lprintf(64, "EOF from %s\r\n", get_host(sock));
    return NULL;
  } else if (n < 0) {
    debug_lprintf(64, "FAILED: %d, %d reading len\r\n", n, WSAGetLastError());
    return NULL;
  }
  len = ntohl(len);

  l = (char *)malloc(len+1);
  if (l == NULL) {
    debug_lprintf(64, "FAILED: out of memory allocating %d bytes\r\n", len);
    return NULL;
  }
  l[len] = 0;

  if ((n = read_fully(sock, l, len)) != len) {
    debug_lprintf(64, "FAILED: %d, %d reading data\r\n", n, WSAGetLastError());
    free(l);
    return NULL;
  }

  debug_lprintf(strlen(l)+7, "%.75s%s\r\n", l, strlen(l)>75 ? "..." : "");
  return l;
}  

void IO::notify()
{
  SetEvent(lock);
}

/**********************************************************************
  Everything above here only runs in the caller's thread.
  Everything below here only runs in the IO object's thread.
  ********************************************************************/

void IO::wait(int dur)
{
  if (WaitForSingleObject(lock, dur) == WAIT_TIMEOUT)
    debug_lprintf(64, "timeout in wait(%d)\r\n", dur);
}

/*
  This function must call notify() when listening or when it fails to
  set up the listener.  Note that debug_lprintf() will block until notify()
  is called...
  */
int IO::run()
{
  int n;
  sockaddr_in saddr;

  state = FAILED;

  listener = socket(AF_INET, SOCK_STREAM, IPPROTO_TCP);
  if (listener == INVALID_SOCKET) {
    n = WSAGetLastError();
    notify();
    debug_lprintf(64, "cannot create listener: %d\r\n", n);
    return 0;
  }

  memset(&saddr, 0, sizeof(saddr));
  saddr.sin_family = AF_INET;
  saddr.sin_addr.s_addr = INADDR_ANY;
  saddr.sin_port = htons(port);
  if (bind(listener, (struct sockaddr *)&saddr, sizeof(saddr)) < 0) {
    n = WSAGetLastError();
    closesocket(listener);
    notify();
    debug_lprintf(256, "cannot bind port %d for listener: %d\r\n", port, n);
    return 0;
  }
    
  if (listen(listener, SOMAXCONN) < 0) {
    n = WSAGetLastError();
    closesocket(listener);
    notify();
    debug_lprintf(256, "cannot listen: %d\r\n", n);
    return 0;
  }

  state = LISTEN;
  notify();

  while (1) {
    Client *c;
    fd_set rfs;
    
    FD_ZERO(&rfs);
    FD_SET(listener, &rfs);

    /*Ensure exclusive access to clients. */
    WaitForSingleObject (client_mutex, INFINITE);
    for (c = clients; c != NULL; c = c->next) {
      ReleaseMutex (client_mutex);
      if (c->emacs_sock != -1)
	FD_SET(c->emacs_sock, &rfs);
      WaitForSingleObject (client_mutex, INFINITE);
    }
    ReleaseMutex (client_mutex);
    
    n = select(0 /* ignored */, &rfs, NULL, NULL, NULL);
    if (done) {
      debug_lprintf(64, "IO: done\r\n");
      return 1;
    }
	
    if (FD_ISSET(listener, &rfs)) {
      int emacs_sock, dns_sock;
      n = sizeof(saddr);
      if ((emacs_sock = accept(listener,(struct sockaddr *)&saddr,&n))<0) {
	debug_lprintf(256, "cannot accept emacs_sock: %d\r\n",
		      WSAGetLastError());
      }
      n = sizeof(saddr);
      if ((dns_sock = accept(listener,(struct sockaddr *)&saddr,&n))<0) {
	debug_lprintf(256, "cannot accept dns_sock: %d\r\n",
		      WSAGetLastError());
      }
      PostMessage(wnd, WM_COMMAND, IDC_DO_CONNECT,
		  (LPARAM) new Client(this, emacs_sock, dns_sock));
      wait();
    }

    // We have to ensure exclusive access to clients here, because the
    // other thread occasionally adds or removes objects from the list.
    WaitForSingleObject (client_mutex, INFINITE);
    c = clients;
    while(c!=NULL) {
      ReleaseMutex (client_mutex);
      if (c->emacs_sock != -1 && FD_ISSET(c->emacs_sock, &rfs)) {
	PostMessage(wnd, WM_COMMAND, IDC_DO_COMMAND, (LPARAM) c);
	wait();
	break; // avoid using the possibly dangling pointer c
      }
      WaitForSingleObject (client_mutex, INFINITE);
      c = c->next;
    }
    ReleaseMutex (client_mutex);
    
  }
  return 1;
}


// Reads any characters waiting on the stream
int IO::flush_stream (int sock )
{
  struct timeval tv;
  fd_set rfs;

  FD_ZERO(&rfs);
  FD_SET(sock, &rfs);
  tv.tv_sec = 0 ; tv.tv_usec = 0;
  int n,ntot=0;
  while((n = select(0 /* ignored */, &rfs, NULL, NULL, &tv))!=0) {
    char buf[100];
    n = recv(sock, buf, 100, 0);
    if(n<1)
      // end-of-file
      break;
    ntot+=n;
  }
  return ntot;
}
