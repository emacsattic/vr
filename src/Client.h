/*
  VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.

  Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
  See the file COPYING.txt for terms of use.
  */

#ifndef __CLIENT_H__
#define __CLIENT_H__

class VCmdSink;
class DictSink;
class IO;

typedef struct _bufmap {
  struct _bufmap *next;
  const char *bufnam;
  IDgnDictCustom *dict;
  DictSink *sink;
} BufMap;

class Client {
public:
  static int counter;
  
  class Client *next;

  Client(IO *io, int emacs_sock, int dns_sock);
  ~Client();
  HRESULT initialize();

  void send_cmd(const char *);
  void send_reply(const char *);
  char *get_host();
  char *get_cmd();
  char *get_reply(const char *);

  int create_buffer(BufMap *map, const char *name);
  int activate_buffer(const char *);
  void kill_buffer(const char *);
  void change_text(char *);
  void activate_frame(HWND);

  void enable_dictation();
  void disable_dictation();

  IO *io;
  HWND targetWin;
  IDgnVoiceCmd *voxCmd;
  VCmdSink *vcmdSink;
  int emacs_sock, dns_sock;
  BufMap *map;
  BufMap *activeBuffer;
  int num;
  char *clss, *title;
  int dict_allowed;
};

extern Client *clients;

#endif /* __CLIENT_H__ */
