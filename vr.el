;;
;; VR Mode - integration of GNU Emacs and Dragon NaturallySpeaking.
;;
;; Copyright 1999 Barry Jaspan, <bjaspan@mit.edu>.  All rights reserved.
;; See the file COPYING.txt for terms of use.
;;
;; $Id$
;; $Log$
;; Revision 1.6  2001/09/25 01:44:38  patrik
;; Worked around the exit-minibuffer lockup by checking if the command
;; about to be executed is one of the commands that never exits.  If so,
;; it uses the deferred-function mechanism instead.  The commands for
;; which this is done are kept in the variable vr-nonlocal-exit-commands.
;;
;; It seems to work well.  You cannot, of course, continue dictating
;; after the New-Line in the minibuffer, but then doing so seems a little
;; excessive as well...
;;
;; Revision 1.5  2001/09/10 23:35:10  patrik
;; Smoothed out a number of rough edges concerning the continuous
;; commands.  Most of the changes are in pbvElse, but there were a number
;; of problems with the deferred-function variables not being cleared
;; properly.  It still seems that sometimes expand-placeholder, which
;; should be executed in make-changes, does not get run.  Instead, it
;; will be run the next time you enter make-changes.  I have no idea why
;; this happens.
;;
;; Also fixed some problems with the execute-function function, stupid
;; Lisp stuff like whether the command sequence is a list or a vector,
;; and so on.
;;
;; Also added the running of pre-command-hook and post-command-hook for
;; our "simulated" keyboard input.  I hope that this would have cured the
;; fact that macro definitions don't recognize the VR mode keystrokes,
;; but it didn't.  I don't know how macros read keystrokes when they're
;; being defined.
;;
;; Revision 1.4  2001/09/01 10:56:47  patrik
;; Changed the command processing so that all commands except those
;; specified as vectors of keystrokes are executed directly.  The
;; advantage of doing this is that commands executed as keystrokes change
;; the active buffer to the minibuffer, so the changes to the buffer were
;; not communicated properly.  This was the case for yank, for example.
;;
;; Revision 1.3  2001/09/01 08:46:53  patrik
;; Fixed several problems with the abbreviation mode and ELSE.  The
;; routine handle-abbrev-expansion used to reinsert the placeholder text
;; that ELSE would remove when you type into the placeholder.  It would
;; then also run the commands and avoid the expansion by an on purpose
;; error.  This messed up VR mode since the error would stop processing
;; of the changes.  Made a very similar routine called
;; fix-else-abbrev-expansion, which would reinsert the placeholder text
;; but not call the command.  It's now called just before the command is
;; executed in vr-report-change.
;;
;; Also made a temporary fix for the fact that expand-placeholder is not
;; a command that returns quickly, but requires user input.  Since it is
;; called before make-changes sends tick and change counts, vr.exe would
;; timeout.  The fix checks if the command it is about to execute is
;; expand-placeholder, and if it is report-changes simply doesn't do
;; anything.  Instead, make-changes, after sending tick and change
;; counts, checks if deferred-deferred-function is set, and in that case
;; executes the command.  Of course this doesn't work if
;; expand-placeholder is not the last command in the utterance, but on
;; the other hand that doesn't make sense, because expand-placeholder
;; requires input, so it should be the last.
;;
;; It still isn't perfect, because ELSE uses before-change-functions to
;; delete the placeholder, which means that VR mode will get out of
;; sync.  I can't think of a simple way of taking care of this, when the
;; Emacs buffer changes before any characters have been entered, and
;; vr.exe thinks that all the characters have already been typed, it's
;; not straightforward to sort that out.
;;

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; User options
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-command "vr.exe" "*The \"vr.exe\" program to be
invoked as the VR mode sub-process.  This can be just the name, if the
program is in your PATH, or it can be a full path.")

(defvar vr-host nil "*The name of the computer running the VR Mode
process.  If nil, the process will be started on this computer.  See
also vr-port.")

(defvar vr-port 0 "*The port on which to connect to vr-host.  If
vr-host is nil, this can be zero to tell the VR Mode process to use
any available port.")

(defvar vr-win-class nil
  "*Class name of the Windows window for which VR Mode will accept
voice input.  Whenever a window matching vr-win-class and vr-win-title
(which see) is the foreground window, dictation and commands spoken
into the microphone will be executed by VR Mode.")
(defvar vr-win-title "emacs"
  "*Title of the Windows window for which VR Mode will accept voice
input.  Whenever a window matching vr-win-class (which see) and
vr-win-title is the foreground window, dictation and commands spoken
into the microphone will be executed by VR Mode.")

(defvar vr-activation-list nil
  "*A list of buffer name patterns which VR Mode will voice activate.
Each element of the list is a REGEXP.  Any buffer whose name matches
any element of the list is voice activated.  For example, with

(setq vr-activation-list '(\"^\\*scratch\\*$\" \"\\.txt$\"))

the buffer named \"*scratch*\" and any buffer whose name ends with
\".txt\" will be voice-activated.  Note that voice activation of the
minibuffer is controlled by vr-activate-minibuffer.")

(defvar vr-activate-minibuffer t
  "*Flag controlling whether the minibuffer is voice-activated.")

(defvar vr-voice-command-list '(vr-default-voice-commands)
  "*The list of Emacs interactive commands that can be invoked by
voice.  Each element can be a command, a CONS cell containing
spoken text and a command or key sequence, or the special symbol
'vr-default-voice-commands, which implicitly includes the voice
commands in vr-default-voice-command-list (which see).

For example:

(setq vr-voice-command-list
      '(vr-default-voice-commands
	my-command
	(\"other command\" . my-other-command)
	(\"prefix shell command\" . [\?\\C-u \?\\M-\\S-!])))

sets up the voice commands

	Spoken			Invokes
	===============		=============
	my command		M-x my-command
	other command		M-x my-other-command
	prefix shell command	C-u M-S-! (i.e. C-u M-x shell-command)

along with all the commands on vr-default-voice-command-list.")

(defconst vr-default-voice-command-list
  '(

    ;; Lists
    (list "0to20" "0 1 2 3 4 5 6 7 8 9 10 11 12 13 14 15 16 17 18 19 20")
    
    ;; VR Mode commands
    ("activate buffer" . vr-add-to-activation-list)

    ;; general emacs commands
    ("quit" . [?\C-g])
    ("undo" . undo)
    ("undo that" . undo)

    ;; keystrokes that often should not be self-inserted
    ("enter" . [?\C-j])
    ("tab" . [?\C-i])
    ("space" . [? ])

    ;; Repeat control commands.  These must be invoked with funcall, not M-x,
    ;; since M-x (or any non-RET event) terminates the repeat.
    ("faster" . "vr-repeat-mult-rate 0.5")
    ("slower" . "vr-repeat-mult-rate 2")
    ("stop" . "vr-repeat-stop nil")

    ;; Repeat that.
    ("repeat that <0to20> times" . vr-repeat-that)

    ;; files
    find-file
    save-buffer
    ("save file" . save-buffer)
    find-file-other-window
    find-file-other-frame
    
    ;; buffers
    switch-to-buffer
    kill-buffer
    switch-to-buffer-other-window
    switch-to-buffer-other-frame
    ("resynchronize" .  vr-resynchronize)
    
    ;; windows
    ("split window" . split-window-vertically)
    other-window
    delete-window
    delete-other-windows
    
    ;; frames
    
    ;; cursor movement
    ("forward char <0to20>" . forward-char) 
    ("backward char <0to20>" . backward-char )
    ("forward word <0to20>" . forward-word)
    ("backward word <0to20>" . backward-word)
    ("next line <0to20>" . next-line)
    ("previous line <0to20>" . previous-line)
    ("forward paragraph <0to20>" . forward-paragraph)
    ("backward paragraph <0to20>" . backward-paragraph)
    ("scroll up" . scroll-up)
    ("scroll down" . scroll-down)
    ("page down" . scroll-up)
    ("page up" . scroll-down)
    ("beginning of line" . beginning-of-line)
    ("end of line" . end-of-line)
    ("beginning of buffer" . beginning-of-buffer)
    ("end of buffer" . end-of-buffer)

    ("move up" . vr-repeat-move-up-s)
    ("move up slow" . vr-repeat-move-up-s)
    ("move up fast" . vr-repeat-move-up-f)
    ("move down" . vr-repeat-move-down-s)
    ("move down slow" . vr-repeat-move-down-s)
    ("move down fast" . vr-repeat-move-down-f)
    ("move left" . vr-repeat-move-left-s)
    ("move left slow" . vr-repeat-move-left-s)
    ("move left fast" . vr-repeat-move-left-f)
    ("move right" . vr-repeat-move-right-s)
    ("move right slow" . vr-repeat-move-right-s)
    ("move right fast" . vr-repeat-move-right-f)

    ("move up <0to20>" . previous-line)
    ("move down <0to20>" . next-line)
    ("move left <0to20>" . backward-char)
    ("move right <0to20>" . forward-char)
    ("move left <0to20> words" . backward-word)
    ("move right <0to20> words" . forward-word)
    ("move left <0to20> sentences" . backward-sentence)
    ("move right <0to20> sentences" . forward-sentence)
    ("move left <0to20> paragraphs" . backward-paragraph)
    ("move right <0to20> paragraphs" . forward-paragraph)
    ("back <0to20>" . backward-char)
    ("forward <0to20>" . forward-char)
    ("back <0to20> words" . backward-word)
    ("forward <0to20> words" . forward-word)
    ("back <0to20> sentences" . backward-sentence)
    ("forward <0to20> sentences" . forward-sentence)
    ("back <0to20> paragraphs" . backward-paragraph)
    ("forward <0to20> paragraphs" . forward-paragraph)

    ;; deleting text
    ("delete char <0to20>" . delete-char)
    ("kill word <0to20>" . kill-word)
    ("backward kill word <0to20>" . backward-kill-word)
    ("kill line <0to20>" . kill-line)
    ("repeat kill line" . "vr-repeat-kill-line 0.5")
    yank
    yank-pop
    ;; assumes yank-pop has key binding, else last-command==self-insert-command
    ("yank again" . yank-pop)
    ;; requires a key binding for yank, repeat yank to work!
    ("repeat yank" . vr-repeat-yank)

    ;; Searching
    ("I search forward" . isearch-forward)
    ("I search backward" . isearch-backward)
    ("repeat I search forward" . vr-repeat-search-forward-s)
    ("repeat I search backward" . vr-repeat-search-backward-s)

    ;; formatting
    fill-paragraph
    
    ;; modes
    auto-fill-mode
    exit-minibuffer
    )
  "*A list of standard Emacs voice commands.  This list is used as-is
whenever vr-voice-command-list (which see) includes the symbol
'vr-default-voice-commands, or it can be appended explicitly in a
custom vr-voice-command-list.")

(defvar vr-log-do nil "*If non-nil, VR mode prints debugging information
in the \" *vr*\" buffer.")

(defvar vr-log-send nil "*If non-nil, VR mode logs all data sent to the VR
subprocess in the \" *vr*\" buffer.")

(defvar vr-log-read nil "*If non-nil, VR mode logs all data received
from the VR subprocess in the \" *vr*\" buffer.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Configuration hooks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-mode-setup-hook nil
  "Hooks that are run after VR Mode is enabled but before VR.EXE is
successfully started (or connected to).  See also
vr-mode-startup-hook, called later.")

(defvar vr-mode-cleanup-hook nil
  "Hooks that are run after VR Mode is disabled and after VR.EXE has
exited or been told to exit.")

(defvar vr-mode-startup-hook nil
  "Hooks that are run after VR Mode is enabled, VR.EXE is
successfully started (or connected to), and after VR.EXE is initialized
with any per-connection state such as voice commands.  See also
vr-mode-setup-hook, called earlier.")

(defvar vr-mode-modified-hook nil
  "Hooks that are called whenever a voice activated buffer is modifed
for any reason, invoked by the 'modified-hooks property of vr-overlay.
Arguments provided are OVERLAY AFTER BEG END LEN.  If any hook returns
non-nil, VR Mode will *not* perform its normal modification processing
(ie: telling VR.EXE/DNS about the change).

If vr-ignore-changes is not nil, the hook has been invoked inside
vr-cmd-make-changes, which means the current change comes from DNS,
not from the keyboard or elsewhere.

Danger, Will Robinson!")

(defvar vr-cmd-listening-hook '(vr-cmd-listening)
  "Hooks that are called when the VR Mode command \"listening\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-connected-hook '(vr-cmd-connected)
  "Hooks that are called when the VR Mode command \"connected\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-initialize-hook '(vr-cmd-initialize)
  "Hooks that are called when the VR Mode command \"initialize\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-terminating-hook '(vr-cmd-terminating)
  "Hooks that are called when the VR Mode command \"terminating\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-frame-activated-hook '(vr-cmd-frame-activated)
  "Hooks that are called when the VR Mode command \"frame-activated\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-heard-command-hook '(vr-cmd-heard-command)
  "Hooks that are called when the VR Mode command \"heard-command\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-mic-state-hook '(vr-cmd-mic-state)
  "Hooks that are called when the VR Mode command \"mic-state\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-get-buffer-info-hook '(vr-cmd-get-buffer-info)
  "Hooks that are called when the VR Mode command \"get-buffer-info\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-make-changes-hook '(vr-cmd-make-changes)
  "Hooks that are called when the VR Mode command \"make-changes\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

(defvar vr-cmd-recognition-hook '(vr-cmd-recognition)
  "Hooks that are called when the VR Mode command \"recognition\" is
received.  Each hook function receives a single argument, REQ,
which is the list representing the command and its arguments.  If any
hook function returns non-nil, subsequent hooks on the list will not
be called.")

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Internal variables
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-mode nil
  "Non-nil turns on VR (Voice Recognition) mode.  DO NOT SET THIS
VARIABLE DIRECTLY.  Call M-x vr-mode instead.")

(defvar vr-internal-activation-list nil
  "The working copy of vr-activation-list.  Keeping it separate allows
re-starting VR Mode to undo vr-add-to-activation-list.")

(defvar vr-mode-line " VR"
  "String displayed in the minor mode list when VR mode is enabled.
In the dictation buffer, the format is VR:<micstate>.")
(make-variable-buffer-local 'vr-mode-line)
(if (not (assq 'vr-mode minor-mode-alist))
    (setq minor-mode-alist (cons '(vr-mode vr-mode-line)
				 minor-mode-alist)))

(defvar vr-mic-state "not connected"
  "String storing the microphone state for display in the mode line.")

(defvar vr-overlay nil
  "Overlay used to track changes to voice-activated buffers.")
(make-variable-buffer-local 'vr-overlay)

(defvar vr-select-overlay (make-overlay 1 1)
  "Overlay used to track and visually indicate the NaturallySpeaking
selection.")
(delete-overlay vr-select-overlay)
(overlay-put vr-select-overlay 'face 'region)
(if (eq window-system nil)
    (progn
      (overlay-put vr-select-overlay 'before-string "[")
      (overlay-put vr-select-overlay 'after-string "]")))

(defvar vr-process nil "The VR mode subprocess.")
(defvar vr-emacs-cmds nil)
(defvar vr-dns-cmds nil)

(defvar vr-reading-string nil "Storage for partially-read commands
from the VR subprocess.")

(defvar vr-buffer nil "The current voice-activated buffer, or nil.
See vr-activate-buffer and vr-switch-to-buffer.")

(defvar vr-ignore-changes nil "see comment in vr-overlay-modified")
(defvar vr-queued-changes nil "see comment in vr-overlay-modified")

(defvar vr-cmd-executing nil
  "If non-nil, the command symbol heard by NaturallySpeaking and
currently being executed by VR Mode, for which VR.EXE is expecting a
reply when done.")

(defvar vr-resynchronize-buffer nil)
(make-variable-buffer-local 'vr-resynchronize-buffer)

(defvar vr-deferred-deferred-function nil)
(defvar vr-deferred-deferred-deferred-function nil)
(defvar vr-nonlocal-exit-commands
  '(exit-minibuffer minibuffer-complete-and-exit)
  "These commands never exit and can't be executed in the make-changes
loop without screwing up the I/O.") 
  
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Key bindings
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-prefix-map nil "Prefix key used to access VR mode commands.")
(defvar vr-map nil)
(if vr-map
    nil
  (setq vr-map (make-sparse-keymap))
  (define-key vr-map "ws" 'vr-show-window)
  (define-key vr-map "wh" 'vr-hide-window)
  (define-key vr-map "B" 'vr-add-to-activation-list)
  (define-key vr-map "b" 'vr-switch-to-buffer)
  (define-key vr-map "m" 'vr-toggle-mic)
  (define-key vr-map "q" 'vr-quit)
  (define-key vr-map "\C-\M-y" 'vr-repeat-yank)
  )

(if vr-prefix-map
    nil
  (setq vr-prefix-map (make-sparse-keymap))
  (define-key vr-prefix-map "\C-cv" vr-map))

(if (not (assq 'vr-mode minor-mode-map-alist))
    (setq minor-mode-map-alist
	  (cons (cons 'vr-mode vr-prefix-map) minor-mode-map-alist)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Entry points for global hooks
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun vr-enter-minibuffer ()
  (if (and vr-emacs-cmds vr-activate-minibuffer)
      (vr-activate-buffer (current-buffer))))

(defun vr-post-command ()
  (add-hook 'post-command-hook 'vr-post-command)
  (if (overlayp vr-select-overlay)
      (delete-overlay vr-select-overlay))
  (vr-log "post-command: %s %s %s\n" this-command
	  vr-cmd-executing (buffer-name))
  (if vr-emacs-cmds
      (progn
	(vr-maybe-activate-buffer (current-buffer))
	(if (and vr-cmd-executing t) ;  (eq vr-cmd-executing this-command))
; apparently this-command is not always set to the name of the
; command, for example kill-line is executed with "kill-region" in
; this-command, so this check doesn't really work
	    (progn
	      (vr-send-cmd (format "command-done %s" vr-cmd-executing))
	      (setq vr-cmd-executing nil)))
	)))

(defun vr-kill-buffer ()
  (if vr-emacs-cmds
      (progn
	(vr-log "kill-buffer: %s\n" (current-buffer))
	(vr-send-cmd (concat "kill-buffer " (buffer-name (current-buffer)))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Buffer activation control
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun vr-filter (pred in)
  (let (out el)
    (while in
      (setq el (car in))
      (setq in (cdr in))
      (if (funcall pred el)
	  (setq out (cons el out)))
      )
out))
  
(defun vr-add-to-activation-list (buffer)
  "Adds BUFFER, which can be a buffer name or buffer, to the list of
buffers that are voice activated.  Called interactively, adds the
current buffer.

The only way to undo the effect of this function is to re-start VR
Mode."
  ;; If called interactively, vr-post-command will activate the
  ;; current buffer (so this function doesn't have to).
  (interactive (list (current-buffer)))
  (if (bufferp buffer)
      (setq buffer (buffer-name buffer)))
  (if (vr-activate-buffer-p buffer)
      nil
    (setq vr-internal-activation-list
	  (cons (concat "^" (regexp-quote buffer) "$")
		vr-internal-activation-list))))

(defun vr-resynchronize (buffer)
  "asks VR mode to resynchronize this buffer, if it has gotten out of
sync.  (That shouldn't happen, in an ideal world, but..."
  (interactive (list (current-buffer)))
  (set-buffer buffer)
  (setq vr-resynchronize-buffer t))

(defun vr-activate-buffer-p (buffer)
  "Predicate indicating whether BUFFER matches any REGEXP element and
does not match any '(not REGEXP) element of
vr-internal-activation-list.  BUFFER can be a buffer or a buffer name."
  (if (bufferp buffer)
      (setq buffer (buffer-name buffer)))
  (if (string-match "^ \\*Minibuf-[0-9]+\\*$" buffer)
      vr-activate-minibuffer
    (and (vr-filter (lambda (r) (and (stringp r) (string-match r buffer)))
		    vr-internal-activation-list)
	 (not (vr-filter (lambda (r)
			   (and (consp r) (eq (car r) 'not)
				(string-match (car (cdr r)) buffer)))
			 vr-internal-activation-list)))))

(defun vr-maybe-activate-buffer (buffer)
  ;; Deactivate whenever isearch mode is active.  This is a
  ;; "temporary" solution until isearch mode can be supported.
  (if (and (not isearch-mode) (vr-activate-buffer-p (buffer-name buffer)))
      (if (eq buffer vr-buffer)
	  nil
	(vr-activate-buffer buffer))
    (if vr-buffer 
	(vr-activate-buffer nil))))

(defun vr-switch-to-buffer ()
  "Select the current VR mode target buffer in the current window."
  (interactive)
  (if (buffer-live-p vr-buffer)
      (switch-to-buffer vr-buffer)
    (error "VR target buffer no longer exists; use vr-activate-buffer")))

(defun vr-activate-buffer (buffer)
  "Sets the target BUFFER that will receive voice-recognized text.  Called
interactively, sets the current buffer as the target buffer."
  (interactive (list (current-buffer)))
  (if (buffer-live-p vr-buffer)
      (save-excursion
	(set-buffer vr-buffer)
	;; somehow vr-buffer can be set to the minibuffer while
	;; vr-overlay is nil.
	(if (overlayp vr-overlay)
	    (delete-overlay vr-overlay))
	(setq vr-overlay nil)
	(kill-local-variable 'vr-mode-line)))
  (set-default 'vr-mode-line (concat " VR-" vr-mic-state))
  (setq vr-buffer buffer)
  (if buffer
      (save-excursion
	(set-buffer buffer)
	(setq vr-mode-line (concat " VR:" vr-mic-state))
	(vr-send-cmd (concat "activate-buffer " (buffer-name vr-buffer)))
	(if vr-overlay
	    nil
	  (setq vr-modification-stack ())
	  (setq vr-overlay-before-count 0)
	  (setq vr-overlay (make-overlay (point-min) (point-max) nil nil t))
	  (overlay-put vr-overlay 'modification-hooks '(vr-overlay-modified))
	  (overlay-put vr-overlay 'insert-in-front-hooks '(vr-grow-overlay))
	  (overlay-put vr-overlay 'insert-behind-hooks '(vr-grow-overlay)))
	)
    (vr-send-cmd "deactivate-buffer")
    )
  (force-mode-line-update)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Tracking changes to voice-activated buffers
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-overlay-before-count 0 "see comment in vr-grow-overlay")

(defun vr-grow-overlay (overlay after beg end &optional len)
  ;; Make OVERLAY grow to contain range START to END.  If called "before"
  ;; twice before called "after", only call vr-overlay-modified once.
  ;; This happens when we type the first char in the buffer, because I
  ;; guess it is inserted both before and after the empty overlay.

  (vr-log "Grow: %s %d %d %s %d\n" (if after "After: " "Before: ") beg end
  	  (if after (int-to-string len) "") vr-overlay-before-count)
  (if after
      (progn
	(move-overlay overlay
		      (min beg (overlay-start overlay))
		      (max end (overlay-end overlay)))
	(setq vr-overlay-before-count (1- vr-overlay-before-count))
	(if (> vr-overlay-before-count 0)
	    (progn;; (vr-log "   ignored duplicate grow\n")
	      nil)
	  (vr-report-change overlay after beg end len))
	;;(setq vr-modification-stack (cdr vr-modification-stack))
	)

    (setq vr-overlay-before-count (1+ vr-overlay-before-count))
    ;;(setq vr-modification-stack (cons (buffer-substring beg end)
    ;;vr-modification-stack))
    ))

(defvar vr-modification-stack () )

(defun vr-overlay-modified (overlay after beg end &optional len)
  (vr-log " overlay modified: a:%s vro:%s %d %d %d: \"%s\"\n"
	  after (eq vr-overlay overlay) beg end (if after len 0)
	  (buffer-substring beg end))
  (vr-log "  modification stack: %d\n" (length vr-modification-stack))
  (if after
      (progn
	(vr-log "   %s %s \n" (car vr-modification-stack)
		(buffer-substring beg end))
	(if (equal (car vr-modification-stack) (buffer-substring beg end))
	    ;; the before and after text are the same, so so it's one of these
	    ;; funky changes we can ignore.
	    (vr-log "ignoring bogus change\n" );;nil
	  ;; they're not equal, so we call the modification routine like before.
	  (vr-report-change overlay after beg end len))
	(setq vr-modification-stack (cdr vr-modification-stack))
	(if (< 0 vr-overlay-before-count)
	    (setq vr-overlay-before-count (1- vr-overlay-before-count))))

    ;; for the before call, we just save the prechange string in the stack
    (setq vr-modification-stack (cons (buffer-substring beg end)
				      vr-modification-stack))))

(defun vr-report-change (overlay after beg end &optional len)
  (if (and (not (run-hook-with-args-until-success 'vr-mode-modified-hook
						  overlay after beg end len))
	   after)
      ;; If vr-ignore-changes is not nil, we are inside the make-changes
      ;; loop.  Don't tell DNS about changes it told us to make.  And,
      ;; for changes we do need to tell DNS about (e.g. auto-fill),
      ;; queue them up instead of sending them immediately to avoid
      ;; synchronization problems.  make-changes will send them when
      ;; it is done. 
      ;;
      ;; This is not a foolproof heuristic.
      (progn
;;	(vr-log " overlay modified: a:%s vro:%s %d %d %d: \"%s\"\n"
;;		after (eq vr-overlay overlay) beg end len
;;		(buffer-substring beg end))
	(if (or (and (eq vr-ignore-changes 'self-insert)
		     (eq len 0)
		     (eq (- end beg) 1)
		     (eq (char-after beg) last-command-char))
		(and (eq vr-ignore-changes 'delete)
		     (> len 0)
		     (eq beg end)))
	    (progn (vr-log "ignore: %d %d %d: \"%s\" %s\n" beg end len
			   (buffer-substring beg end) vr-ignore-changes)
		   nil)
;	  (vr-log " After: %s %d %d %d: \"%s\"\n" overlay beg end len
;		  (buffer-substring beg end))
	  (let ((cmd (format "change-text \"%s\" %d %d %d %d %s"
			     (buffer-name (overlay-buffer overlay))
			     (1- beg) (1- end) len
			     (buffer-modified-tick)
			     (vr-string-replace (buffer-substring beg end)
						"\n" "\\n"))))
	    (if vr-ignore-changes
		(setq vr-queued-changes (cons cmd vr-queued-changes))
	      (vr-send-cmd cmd)))))
    (vr-log " overlay modified: a:%s vro:%s %d %d : \"%s\"\n"
	    after (eq vr-overlay overlay) beg end 
	    (buffer-substring beg end))
    )
  (if deferred-function
      (progn
	(setq vr-deferred-deferred-function deferred-function)
	(setq deferred-function nil)
	;(debug)
	(delete-backward-char 2)
	;(debug)
	(fix-else-abbrev-expansion)
	;(debug)
	(if (not (eq vr-deferred-deferred-function
		     'else-expand-placeholder))
	    (progn
	      ;;(call-interactively deferred-deferred-function)
	      (vr-log "report-change executing deferred function %s\n" vr-deferred-deferred-function)
	      (setq vr-deferred-deferred-deferred-function
		    vr-deferred-deferred-function )
	      (setq vr-deferred-deferred-function nil)
	      (vr-execute-command
	       vr-deferred-deferred-deferred-function))
	  (vr-log "report-change deferring command %s\n"
		  vr-deferred-deferred-function))
    ))
  t  )

(defun vr-string-replace (src regexp repl)
  (let ((i 0))
    (while (setq i (string-match regexp src))
      (setq src (concat (substring src 0 i)
			repl
			(substring src (match-end 0))))
      (setq i (match-end 0))))
  src)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Keyboard lockout during voice recognition
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-recognizing nil)

(defun vr-sleep-while-recognizing ()
  (interactive)
  (let* ((first t) (count 0))
    (while (and (< count 200) vr-recognizing (string= vr-mic-state "on"))
      (if first (message "Waiting for voice recognition..."))
      (setq first nil)
      (setq count (1+ count))
      (sleep-for 0 50))
    (if (eq count 200) 
	(message "Time out in vr-sleep-while-recognizing!")
      (message nil))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subprocess communication.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun vr-log (&rest s)
  (if vr-log-do
      (let* ((buf (get-buffer-create " *vr*"))
	     (win (get-buffer-window buf 't)))
	(save-excursion
					;( message "logging")
	  (set-buffer buf)
	  (goto-char (point-max))
	  (insert (apply 'format s))
	  (if win
	      (set-window-point win (point-max)))
	  ))))

(defun vr-sentinel (p s)
  (if (equal s "finished\n")
      (progn
	(if (processp vr-process)
	    (delete-process vr-process))
	(if (processp vr-emacs-cmds)
	    (delete-process vr-emacs-cmds))
	(if (processp vr-dns-cmds)
	    (delete-process vr-dns-cmds))
	(setq vr-process nil
	      vr-emacs-cmds nil
	      vr-dns-cmds nil))
    (error "VR process exited with status \"%s\"" s)))

(defun vr-cmd-listening (vr-request)
  (vr-connect "127.0.0.1" (nth 1 vr-request))
  t)

(defun vr-cmd-connected (vr-request)
  (vr-send-cmd (format "initialize %s|%s|%s"
		       (if (equal vr-win-class "")
			   nil
			 vr-win-class)
		       (if (equal vr-win-title "")
			   nil
			 vr-win-title)
		       (cdr (assoc 'window-id
				   (frame-parameters (car
						      (visible-frame-list)))))
		       )
	       )
  t)

(defun vr-cmd-initialize (vr-request)
  (cond ((eq (nth 1 vr-request) 'succeeded)
	 (vr-startup))
	((eq (nth 1 vr-request) 'no-window)
	 (vr-mode 0)
	 (message "VR process: no window matching %s %s"
		  vr-win-class vr-win-title))
	(t
	 (vr-mode 0)
	 (message "VR process initialization: %s"
		  (nth 1 vr-request))))
  t)

(defun vr-cmd-terminating (vr-request)
  (let (vr-emacs-cmds)
    (vr-mode 0))
  (if vr-host
      (vr-sentinel nil "finished\n"))
  (message "VR process terminated; VR Mode turned off")
  t)

(defun vr-cmd-frame-activated (vr-request)
  ;; This is ridiculous, but Emacs does not automatically change its
  ;; concept of "selected frame" until you type into it.  So, we have
  ;; the subprocess send us the HWND value and explcitly activate the
  ;; frame that owns it.  The HWND may not belong to any frame, for
  ;; example if vr-win-class/title match a Windows window not
  ;; belonging to Emacs.  In that case, just ignore it.
  ;;
  (let* ((wnd (int-to-string (car (cdr vr-request))))
	 (frame (car (vr-filter
		      (lambda (f) (equal (cdr (assoc 'window-id
						     (frame-parameters f)))
					 wnd))
		      (visible-frame-list)))))
    (if frame
	(select-frame frame)
      (message "VR Mode: %s is not an Emacs frame window handle; ignored."
	       wnd)))
  (vr-maybe-activate-buffer (current-buffer))
  t)

(defun vr-cmd-heard-command (vr-request)
  ;;
  ;; We want to execute the command after this filter function
  ;; terminates, so add the key sequence to invoke it to the end of
  ;; unread-command-events.  Add the key binding, if any, so we don't
  ;; get the "you can run the command <cmd> by typing ..." message.
  ;;
  ;; If the command has arguments, invoke it directly instead.  Also,
  ;; invoke pre-command-hook and post-command-hook so it looks as much
  ;; like a regular command as possible.
  ;;
  ;; Set vr-cmd-executing so vr-post-command (hook) will inform VR.EXE
  ;; when the command is finished.  If cmd is an undefined key
  ;; sequence, no command will be executed, so complete immediately.
  ;;
  (let* ((cmd (nth 1 vr-request))
	 (kseq (or (and (vectorp cmd) cmd)
		   (where-is-internal cmd nil 'non-ascii)
		   (concat "\M-x" (symbol-name cmd) "\n"))))
    (setq vr-cmd-executing (if (vectorp cmd) (key-binding cmd) cmd))
    (if (not vr-cmd-executing)
	(vr-send-cmd "command-done undefined"))
    
    (if (not (vectorp cmd))
	(vr-execute-command (cdr vr-request))
      (vr-log "running %s as key sequence:\n" cmd )
      (setq unread-command-events
	    (append unread-command-events
		    (listify-key-sequence kseq)))
      ) 
	)
  t)

;; executes a command, and runs the appropriate hooks.  It's used by
;; heard-command and by the deferred-function executions.  VR-command
;; can either be a symbol or a list.
(defun vr-execute-command (vr-command)
  (let ((cmd (or (and (listp vr-command ) (car vr-command))
		 vr-command)))
	  (run-hooks 'pre-command-hook)
	  (condition-case err
	      (if (and (listp vr-command) 
		       (> (length vr-command) 1))
		  (apply cmd (cdr vr-command))
		(call-interactively cmd))
	    ('wrong-number-of-arguments
	     (ding)
	     (message
	      "VR Mode: Wrong number of arguments calling %s"
	      vr-command))
	    ('wrong-type-argument 'error
				  (ding)
				  (message "VR Mode: %s calling %s"
					   (error-message-string err)
					   vr-command )))
	  (vr-log "running post-command-hook for %s\n" cmd)
 	  (let ((this-command cmd))
	    (run-hooks 'post-command-hook)))
  t)


(defun vr-cmd-mic-state (vr-request)
  (let ((state (car (cdr vr-request))))
    (cond ((eq state 'off)
	   (setq vr-mic-state "off"))
	  ((eq state 'on)
	   (setq vr-mic-state "on"))
	  ((eq state 'sleep)
	   (setq vr-mic-state "sleep")))
    (vr-activate-buffer vr-buffer))
  t)

(defun vr-cmd-get-buffer-info (vr-request)
  (let ((buffer (nth 1 vr-request))
	(tick (nth 2 vr-request))
	vr-text)
    (vr-log "get-buffer-info: current buffer: %s vr-buffer:%s\n"
	    (buffer-name) vr-buffer)
    (if (not (equal vr-buffer (get-buffer buffer)))
	(progn
	  (ding)
	  (message "VR Mode: get-buffer-info: %s is not %s"
		   buffer (buffer-name vr-buffer))    

	  ;; make sure that we always give information for the buffer that
	  ;; was asked for, even if we ding and the wrong buffer is
	  ;; selected.  This almost certainly means that the subprocess
	  ;; has not had time to update its idea of current buffer
	  (save-excursion
	    (set-buffer (get-buffer buffer))
	    (vr-log "buffer synchronization problem: using %s\n" 
		    (buffer-name (current-buffer)))
	    (vr-send-reply (1- (point)))
	    (vr-send-reply (1- (point)))
	    (vr-send-reply (1- (window-start)))
	    (vr-send-reply (1- (window-end)))
	    (if (eq (buffer-modified-tick) tick)
		(vr-send-reply "0 not modified")
	      (vr-send-reply "1 modified")
	      (vr-send-reply (format "%d" (buffer-modified-tick)))
	      (setq vr-text (buffer-string))
	      (vr-send-reply (length vr-text))
	      (vr-send-reply vr-text))
	    ))

      ;;
      ;; If mouse-drag-overlay exists in our buffer, it
      ;; overrides vr-select-overlay.
      ;;
      (let* ((mdo mouse-drag-overlay)
	     (sel-buffer (overlay-buffer mdo)))
	(vr-log " %s %s \n" vr-select-overlay sel-buffer)
	(if (eq sel-buffer vr-buffer)
	    (move-overlay vr-select-overlay
			  (overlay-start mdo)
			  (overlay-end mdo)
			  sel-buffer)))

      ;;
      ;; Send selection (or point) and viewable window.
      ;;
      (let ((sel-buffer (overlay-buffer vr-select-overlay)))
	(if (eq sel-buffer vr-buffer)
	    (progn
	      (vr-send-reply (1- (overlay-start vr-select-overlay)))
	      (vr-send-reply (1- (overlay-end vr-select-overlay)))
	      )
	  (vr-send-reply (1- (point)))
	  (vr-send-reply (1- (point)))
	  ))
      (vr-send-reply (1- (window-start)))
      (vr-send-reply (1- (window-end)))
      ;;
      ;; Then, send buffer contents, if modified.
      ;;

      (if (and (not vr-resynchronize-buffer) (eq (buffer-modified-tick) tick))
	  (vr-send-reply "0 not modified")
	(if vr-resynchronize-buffer
	    (vr-log "buffer resynchronization requested \n"))
	(vr-send-reply "1 modified")
	(vr-send-reply (format "%d" (buffer-modified-tick)))
	(setq vr-text (buffer-string))
	(vr-send-reply (length vr-text))
	(vr-send-reply vr-text)
	(setq vr-resynchronize-buffer nil))))
  t)

(defun vr-cmd-make-changes (vr-request)
  (if (eq (current-buffer) vr-buffer)
      (let ((start (1+ (nth 1 vr-request)))
	    (num-chars (nth 2 vr-request))
	    (text (nth 3 vr-request))
	    (sel-start (1+ (nth 4 vr-request)))
	    (sel-chars (nth 5 vr-request))
	    vr-queued-changes)
	(if (and buffer-read-only (or (< 0 num-chars) (< 0 (length text))))
	    ;; if the buffer is read-only we don't make any changes
	    ;; to the buffer, and instead we send the 
	    ;; the inverse command back
	    (progn
	      (vr-log "make changes:Buffer is read-only %d %d\n"
		      num-chars (length text))
	      (let ((cmd (format "change-text \"%s\" %d %d %d %d %s"
				 (buffer-name) (1- start)
				 (+ (1- start) num-chars) (length text)
				 (buffer-modified-tick)
				 (vr-string-replace (buffer-substring start
								      (+ start num-chars))
						    "\n" "\\n"))))
		(setq vr-queued-changes (cons cmd
					      vr-queued-changes))))
	    
	  ;; if it's not read-only we perform the changes as before
	  (let ((vr-ignore-changes 'delete))
	    (delete-region start (+ start num-chars)))
	  (goto-char start)
	  (let ((vr-ignore-changes 'self-insert))
	    ;;we make the changes by inserting the appropriate
	    ;;keystrokes and evaluating them
	    (setq unread-command-events
		  (append unread-command-events
			  (listify-key-sequence text)))
	    (while unread-command-events
	      (let* ((event(read-key-sequence-vector nil))
		     (command (key-binding event))
		     (this-command command)
		     (last-command-char (elt event 0))
		     (last-command-event (elt event 0))
		     (last-command-keys event)
		     )
		(vr-log "key-sequence %s %s %s\n" event
			command last-command-char)
		(run-hooks 'pre-command-hook)
		(if (eq command 'self-insert-command)
		    (command-execute command nil)
		  (vr-log "command is not a self insert: %s\n"
			  command )
		  ;; send back a "delete command", since when
		  ;; command is executed it will send the insertion.
		  (let ((cmd (format "change-text \"%s\" %d %d %d %d %s"
				     (buffer-name) (1- (point)) (point)
				     1 (buffer-modified-tick) ""))
			(vr-ignore-changes 'command-insert ))
		    (setq vr-queued-changes (cons cmd
						  vr-queued-changes))
		    ;; exit-minibuffer is a command that does not
		    ;; return properly , so to avoid timeouts waiting
		    ;; for the replies, we put it in the deferred
		    ;; function
		    (if (memq command vr-nonlocal-exit-commands )
			(setq vr-deferred-deferred-function command )
		      (command-execute command nil))
		    (vr-log "executed command: %s\n" command)
		    ))
		(run-hooks 'post-command-hook)
		)))
	  (if (equal (length text) 0)
	      (progn
		(vr-log "make changes: text length is %s" (length text))
		(goto-char sel-start)))
	  (delete-overlay mouse-drag-overlay)
	  (if (equal sel-chars 0)
	      (delete-overlay vr-select-overlay)
	    (move-overlay vr-select-overlay
			  sel-start (+ sel-start sel-chars)
			  (current-buffer))))

	;; in any case, we send the replies and the queued changes.
	(vr-log "sending tick\n")
	(vr-send-reply (buffer-modified-tick))
	(vr-send-reply (length vr-queued-changes))
	(mapcar 'vr-send-reply (nreverse vr-queued-changes))
	(if vr-deferred-deferred-function
	    (progn
	      (vr-log "executing deferred function in make-changes: %s\n"
		      vr-deferred-deferred-function)
	      (setq vr-deferred-deferred-deferred-function
		    vr-deferred-deferred-function )
	      (setq vr-deferred-deferred-function nil)
	      (fix-else-abbrev-expansion)
	      (vr-execute-command vr-deferred-deferred-deferred-function)))
	)
    ;; if the current buffer is not VR-buffer
    (vr-send-reply "-1"))
  t)

;; This function is called by Dragon when it begins/ends mulling over an
;; utterance; delay key and mouse events until it is done.  This
;; ensures that key and mouse events are not handled out of order
;; with respect to speech recognition events
(defun vr-cmd-recognition (vr-request)
  (let ((state (nth 1 vr-request)))
    (progn
      (vr-log "recognition %s: current buffer: %s vr-buffer:%s\n"
	      state (buffer-name) vr-buffer)
      (cond ((eq state 'begin)
					; if recognition starts and VR
					; buffer is not the current
					; buffer, we might have a
					; potential problem with
					; synchronization.  In that
					; case, let's try calling
					; maybe-activate-buffer and
					; see if it's not already too
					; late.
	     (vr-maybe-activate-buffer (current-buffer))
	     (run-at-time 0 nil 'vr-sleep-while-recognizing)
	     (setq vr-recognizing t))
	    ((eq state 'end)
	     (setq vr-recognizing nil))
	    (t
	     (error "Unknown recognition state: %s" state)))))
  t)
		
(defun vr-output-filter (p s)
  (setq vr-reading-string (concat vr-reading-string s))
  (while (> (length vr-reading-string) 0)
    (let* ((parsed (condition-case err
		       (read-from-string vr-reading-string)
		     ('end-of-file (error "Invalid VR command received: %s"
					  vr-reading-string))))
	   (vr-request (car parsed))
	   (idx (cdr parsed))
	   (vr-cmd (car vr-request)))
      (if vr-log-read
	  (vr-log "-> %s\n" (substring vr-reading-string 0 idx)))
      (setq vr-reading-string (substring vr-reading-string (1+ idx)))

      (cond ((eq vr-cmd 'listening)
	     (run-hook-with-args-until-success 'vr-cmd-listening-hook
					       vr-request))
	    ((eq vr-cmd 'connected)
	     (run-hook-with-args-until-success 'vr-cmd-connected-hook
					       vr-request))
	    ((eq vr-cmd 'initialize)
	     (run-hook-with-args-until-success 'vr-cmd-initialize-hook
					       vr-request))
	    ((eq vr-cmd 'terminating)
	     (run-hook-with-args-until-success 'vr-cmd-terminating-hook
					       vr-request))
	    ((eq vr-cmd 'frame-activated)
	     (run-hook-with-args-until-success 'vr-cmd-frame-activated-hook
					       vr-request))
	    ((eq vr-cmd 'heard-command)
	     (run-hook-with-args-until-success 'vr-cmd-heard-command-hook
					       vr-request))
	    ((eq vr-cmd 'mic-state)
	     (run-hook-with-args-until-success 'vr-cmd-mic-state-hook
					       vr-request))
	    ((eq vr-cmd 'get-buffer-info)
	     (run-hook-with-args-until-success 'vr-cmd-get-buffer-info-hook
					       vr-request))
	    ((eq vr-cmd 'make-changes)
	     (run-hook-with-args-until-success 'vr-cmd-make-changes-hook
					       vr-request))
	    ((eq vr-cmd 'recognition)
	     (run-hook-with-args-until-success 'vr-cmd-recognition-hook
					       vr-request))
	    (t
	     ;; The VR process should fail gracefully if an expected
	     ;; reply does not arrive...
	     (error "Unknown VR request: %s" vr-request))
	    ))))

(defun vr-send-reply (msg)
  (if (and vr-dns-cmds (eq (process-status vr-dns-cmds) 'open))
      (progn
	(if (integerp msg)
	    (setq msg (int-to-string msg)))
	(if vr-log-send
	    (vr-log "<- r %s\n" msg))
	(process-send-string vr-dns-cmds (vr-etonl (length msg)))
	(process-send-string vr-dns-cmds msg))
    (message "VR Mode DNS reply channel is not open!")))

(defun vr-send-cmd (msg)
  (if (and vr-emacs-cmds (eq (process-status vr-emacs-cmds) 'open))
      (progn
	(if vr-log-send
	    (vr-log "<- c %s\n" msg))
	(process-send-string vr-emacs-cmds (vr-etonl (length msg)))
	(process-send-string vr-emacs-cmds msg))
    (message "VR Mode command channel is not open: %s" msg)))

;; ewww
(defun vr-etonl (i)
  (format "%c%c%c%c"
	  (lsh (logand i 4278190080) -24)
	  (lsh (logand i 16711680) -16)
	  (lsh (logand i 65280) -8)
	  (logand i 255)))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subprocess commands
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun vr-quit ()
  "Turn off VR mode, and cause the VR mode subprocess to exit cleanly."
  (interactive)
  (vr-mode 0))

(defun vr-toggle-mic ()
  "Toggles the state of the Dragon NaturallySpeaking microphone:
off -> on, {on,sleeping} -> off."
  (interactive)
  (vr-send-cmd "toggle-mic"))

(defun vr-show-window ()
  (interactive)
  (vr-send-cmd "show-window"))

(defun vr-hide-window ()
  (interactive)
  (vr-send-cmd "hide-window"))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Subprocess initialization, including voice commands.
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun vr-connect (host port)
  (condition-case e
      (progn
	(setq vr-emacs-cmds (open-network-stream "vr-emacs" nil
						 host port))
	(vr-log "connecting to VR.exe %s" vr-emacs-cmds)
	(setq vr-dns-cmds (open-network-stream "vr-dns" nil host port))
	(process-kill-without-query vr-emacs-cmds)
	(process-kill-without-query vr-dns-cmds)
	(set-process-filter vr-dns-cmds 'vr-output-filter)
	(if vr-process
	    (set-process-filter vr-process nil))
	t)
    ('error (progn
	      (vr-mode 0)
	      (message "VR Mode: cannot connect to %s:%d" host port)
	      nil))))

;; functionp isn't defined in Win 95 Emacs 19.34.6 (!??!?)
(defun vr-functionp (object)
  "Non-nil if OBJECT is a type of object that can be called as a function."
  (or (subrp object) (byte-code-function-p object)
      (eq (car-safe object) 'lambda)
      (and (symbolp object) (fboundp object))))

(defun vr-strip-dash (symbol)
  (concat (mapcar (lambda (x) (if (eq x ?-) ?\ x)) (symbol-name symbol))))

(defun vr-startup ()
  "Initialize any per-execution state of the VR Mode subprocess."
  (let ((l (lambda (x)
	     (cond ((eq x 'vr-default-voice-commands)
		    (mapcar l vr-default-voice-command-list))
		   ((symbolp x)
		    (vr-send-cmd
		     (concat "define-command "
			     (vr-strip-dash x) "|" (symbol-name x))))
		   ((and (listp x) (eq (car x) 'list))
		    (vr-send-cmd
		     (format "define-list %s|%s" (nth 1 x) (nth 2 x))))
		   ((and (consp x) (vectorp (cdr x)))
		    (vr-send-cmd
		     (format "define-command %s|%s" (car x) (cdr x))))
		   ((and (consp x) (symbolp (cdr x)))
		    (vr-send-cmd
		     (format "define-command %s|%s" (car x) (cdr x))))
		   ((and (consp x) (stringp (cdr x)))
		    (vr-send-cmd
		     (format "define-command %s|%s" (car x) (cdr x))))
		   (t
		    (error "Unknown vr-voice-command-list element %s"
			   x))
		   )
	     )))
    (mapcar l (if (eq vr-voice-command-list t)
		  vr-default-voice-command-list
		vr-voice-command-list)))
  ;; don't set up these hooks until after initialization has succeeded
  (add-hook 'post-command-hook 'vr-post-command)
  (add-hook 'minibuffer-setup-hook 'vr-enter-minibuffer)
  (add-hook 'kill-buffer-hook 'vr-kill-buffer)
  (vr-maybe-activate-buffer (current-buffer))
  (run-hooks 'vr-mode-startup-hook)
  )

(defun vr-kill-emacs ()
  (vr-mode 0)
  t)

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; VR Mode entry/exit
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defun vr-mode (arg)
  "Toggle VR mode.  With argument ARG, turn VR mode on iff ARG is
positive.

VR mode supports Dragon NaturallySpeaking dictation, Select 'N
Say(tm), and voice commands in Emacs buffers.  See README.txt for
instructions.

\\{vr-map}"
  (interactive "P")
  (setq vr-mode
	(if (null arg) (not vr-mode)
	  (> (prefix-numeric-value arg) 0)))
  (if vr-mode
      ;; Entering VR mode
      (progn
	(vr-log "starting VR mode %s" vr-host)
	(setq vr-reading-string nil)
	(setq vr-mic-state "not connected")
	(set-default 'vr-mode-line (concat " VR-" vr-mic-state))
	(setq vr-internal-activation-list vr-activation-list)
	(setq vr-cmd-executing nil)
	(add-hook 'kill-emacs-hook 'vr-kill-emacs)
	(run-hooks 'vr-mode-setup-hook)

	(if vr-host
	    (vr-connect vr-host vr-port)
	  (setq vr-process (start-process "vr" " *vr*" vr-command
					  "-child"
					  "-port" (int-to-string vr-port)))
	  (process-kill-without-query vr-process)
	  (set-process-filter vr-process 'vr-output-filter)
	  (set-process-sentinel vr-process 'vr-sentinel))
	)
    
    ;; Leaving VR mode
    (remove-hook 'post-command-hook 'vr-post-command)
    (remove-hook 'minibuffer-setup-hook 'vr-enter-minibuffer)
    (remove-hook 'kill-buffer-hook 'vr-kill-buffer)
    (vr-activate-buffer nil)
    (if vr-host
	(vr-sentinel nil "finished\n")
      (vr-send-cmd "exit"))
    (run-hooks 'vr-mode-cleanup-hook)
    )
  (force-mode-line-update)
  )

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; "Repeat that N times"
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-last-heard-command-request nil
  "If non-nil, the complete, most-recently-received heard-command
message from VR.EXE")

(defun vr-repeat-that-hook (vr-request)
  (let ((cmd (nth 1 vr-request)))
    (if (not (eq cmd 'vr-repeat-that))
	(setq vr-last-heard-command-request vr-request)))
  nil)
(add-hook 'vr-cmd-heard-command-hook 'vr-repeat-that-hook)

(defun vr-repeat-that (num)
  (interactive '(1))
  (if vr-last-heard-command-request
      (progn
	(while (> num 0)
	  (run-hook-with-args-until-success 'vr-cmd-heard-command-hook
					    vr-last-heard-command-request)
	  (setq num (1- num))))))

;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;
;; Repeating commands (based on code by Steve Freund).
;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;;

(defvar vr-repeat-rate nil
  "The rate at which to repeat commands, in seconds.  If nil, any
currently repeating command will terminate.")

(defun vr-repeat-cmd (freq cmd &rest args)
  "Every FREQ seconds, execute (CMD ARG ...), until the user
generates an input event such as a key press or mouse click (or
executes a voice command that does so).

If the event is RET (the return key), it terminates the repeat but is
then discarded.  Any other event terminates the repeat and is then
acted on as it normally would be."
  (let (ev)
    (discard-input)
    (setq vr-repeat-rate freq)
    (while vr-repeat-rate
      (apply cmd args)
      (sit-for vr-repeat-rate)
      (if (input-pending-p)
	  (progn
	    (setq ev (read-event))
	    (setq vr-repeat-rate nil))))
    (if (and ev (not (eq ev 'return)))
	(setq unread-command-events
	      (cons ev unread-command-events)))
    ))

(defun vr-repeat-mult-rate (f)
  "Multiply the number of seconds between each execution of the current
repeating command by FACTOR."
  (setq vr-repeat-rate (* vr-repeat-rate f)))

(defun vr-repeat-stop (d)
  "Terminate the current repeating command."
  (setq vr-repeat-rate nil))

(defmacro vr-make-repeat-cmd (name freq cmd &rest args)
  "Define an interactive repeating command called NAME that takes no
arguments and, every FREQ seconds, invokes the function CMD.  Uses
vr-repeat-cmd."
  (let ((vrc 'vr-repeat-cmd))
    (list 'defun name '()
	  (format "Invoke %s every %s seconds,\nusing vr-repeat-cmd (which see)."
		  cmd freq)
	  '(interactive)
	  (list 'apply (list 'quote vrc) freq (list 'quote cmd)
		(list 'quote args)))))

(vr-make-repeat-cmd vr-repeat-move-up-s 0.25 previous-line 1)
(vr-make-repeat-cmd vr-repeat-move-up-f 0.05 previous-line 1)
(vr-make-repeat-cmd vr-repeat-move-down-s 0.25 next-line 1)
(vr-make-repeat-cmd vr-repeat-move-down-f 0.05 next-line 1)

(vr-make-repeat-cmd vr-repeat-move-left-s 0.25 backward-char 1)
(vr-make-repeat-cmd vr-repeat-move-left-f 0.05 backward-char 1)
(vr-make-repeat-cmd vr-repeat-move-right-s 0.25 forward-char 1)
(vr-make-repeat-cmd vr-repeat-move-right-f 0.05 forward-char 1)

(vr-make-repeat-cmd vr-repeat-move-word-left-s 0.25 backward-word 1)
(vr-make-repeat-cmd vr-repeat-move-word-left-f 0.05 backward-word 1)
(vr-make-repeat-cmd vr-repeat-move-word-right-s 0.5 forward-word 1)
(vr-make-repeat-cmd vr-repeat-move-word-right-f 0.05 forward-word 1)

(vr-make-repeat-cmd vr-repeat-search-forward-s 0.75 isearch-repeat-forward)
(vr-make-repeat-cmd vr-repeat-search-forward-f 0.25 isearch-repeat-forward)
(vr-make-repeat-cmd vr-repeat-search-backward-s 0.75 isearch-repeat-backward)
(vr-make-repeat-cmd vr-repeat-search-backward-f 0.25 isearch-repeat-backward)

(defun vr-repeat-kill-line (freq)
  "Invoke kill-line every FREQ seconds, using vr-repeat-cmd (which see).
The lines killed with this command form a single block in the yank buffer."
  (kill-new "") 
  (vr-repeat-cmd freq (function (lambda () (kill-line) (append-next-kill)))))

(defun vr-repeat-yank (freq arg)
  "Perform a yank from the kill ring every FREQ seconds, using
vr-repeat-cmd (which see).  This function cycles through the yank
buffer, doing the right thing regardless of whether the previous
command was a yank or not."
  (interactive (list 0.5 (prefix-numeric-value prefix-arg)))
  (vr-repeat-cmd
   freq (function (lambda ()
		    (if (or (eq last-command 'yank) (eq this-command 'yank))
			(yank-pop arg)
		      (yank arg)
		      (setq last-command 'yank))
		    (undo-boundary)
		    ))))

