/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
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
