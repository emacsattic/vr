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

class IO {
public:
  IO(int, HWND);
  ~IO();

  void start();
  const char *get_state();
  char *get_host(int sock);
  int get_port();
  
  char *get_cmd();
  char *get_reply(const char *desc);
  void send_line(int sock, int clnt, const char *cmd);
  char *get_line(int sock, int clnt, const char *desc);
  void notify();

  int run(); /* forced public by start_io */

protected:
  int done;
  HANDLE lock;
  HWND wnd;
  DWORD tid;

  int port, listener;

  enum { FAILED, LISTEN, CONNECTED } state;

  int read_fully(int sock, char *buf, int len);
  void wait(int dur = INFINITE);
};
