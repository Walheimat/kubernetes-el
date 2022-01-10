;; kubernetes-core.el --- core functionality -*- lexical-binding: t; -*-
;;; Commentary:
;;; Code:

(require 's)

(require 'kubernetes-vars)

(defun kubernetes--message (format &rest args)
  "Call `message' with FORMAT and ARGS.

We `inhibit-message' the message when the cursor is in the
minibuffer and when Emacs version is before Emacs 27 due to the
fact that we often use `kubernetes--info', `kubernetes--warn' and
`kubernetes--error' in async context and the call to these
function is removing the minibuffer prompt.  The issue with async
messages is already fixed in Emacs 27."
  (when kubernetes-show-message
    (let ((inhibit-message (and (minibufferp)
                                (version< emacs-version "27.0"))))
      (apply #'message format args))))

(defun kubernetes--info (format &rest args)
  "Display kubernetes info message with FORMAT with ARGS."
  (kubernetes--message "%s :: %s" (propertize "k8s" 'face 'success) (apply #'format format args)))

(defun kubernetes--warn (format &rest args)
  "Display kubernetes warn message with FORMAT with ARGS."
  (kubernetes--message "%s :: %s" (propertize "k8s" 'face 'warning) (apply #'format format args)))

(defun kubernetes--error (format &rest args)
  "Display kubernetes error message with FORMAT with ARGS."
  (kubernetes--message "%s :: %s" (propertize "k8s" 'face 'error) (apply #'format format args)))

(defun kubernetes--val-from-arg-list (arg-list key)
  "Find value for flag KEY in CLI-flag-style ARG-LIST.
Flag-value pairs in ARG-LIST can be either separate or paired with =,
  e.g. '(\"--foo\" bar) or '(\"--foo=bar\").
This function expects long flags only.
If ARG-LIST is nil or KEY is not present in ARG-LIST, returns nil."
  (when arg-list
    (-when-let* ((key-index (--find-index
                             (s-prefix? (format "--%s" (symbol-name key)) it)
                             arg-list))
                 (key-val (nth key-index arg-list)))
      (if (s-contains? "=" key-val)
          (cadr (s-split "=" key-val))
        (nth (+ 1 key-index) arg-list)))))

(defvar kubernetes--poll-timer nil
"Background timer used to poll for updates.

This is used to regularly synchronise local state with Kubernetes.")

(defvar kubernetes--redraw-timer nil
  "Background timer used to trigger buffer redrawing.

This is used to display the current state.")

(defun kubernetes--initialize-timers ()
  "Initialize kubernetes.el global timers.

Global timers are responsible for overview redrawing and resource
polling according to `kubernetes-redraw-frequency' and
`kubernetes-poll-frequency', respectively."
  (unless kubernetes--redraw-timer
    (setq kubernetes--redraw-timer (run-with-timer 0 kubernetes-redraw-frequency #'kubernetes-state-trigger-redraw)))
  (unless kubernetes--poll-timer
    (setq kubernetes--poll-timer (run-with-timer 0 kubernetes-poll-frequency
                                       (lambda ()
                                         (run-hooks 'kubernetes-poll-hook))))))

(defun kubernetes--kill-timers ()
  "Kill kubernetes.el global timers."
  (when-let (timer kubernetes--redraw-timer)
    (cancel-timer timer))
  (when-let (timer kubernetes--poll-timer)
    (cancel-timer timer))
  (setq kubernetes--redraw-timer nil)
  (setq kubernetes--poll-timer nil))

(provide 'kubernetes-core)
;;; kubernetes-core.el ends here