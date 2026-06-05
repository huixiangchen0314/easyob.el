;;; easyob.el --- DSL for Org-babel execution definition -*- lexical-binding: t; -*-

;; Copyright (C) 2024 lyt0628

;; Author: lyt0628
;; Maintainer: lyt0628
;; Created: 13 April 2024
;; Keywords: org-mode, org-babel
;; Homepage: https://github.com/lyt0628/easyob
;; Version: 0.0.2

;;; License:

;; This program is free software; you can redistribute it and/or modify
;; it under the terms of the GNU General Public License as published by
;; the Free Software Foundation; either version 3, or (at your option)
;; any later version.
;;
;; This program is distributed in the hope that it will be useful,
;; but WITHOUT ANY WARRANTY; without even the implied warranty of
;; MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
;; GNU General Public License for more details.
;;
;; You should have received a copy of the GNU General Public License
;; along with GNU Emacs; see the file COPYING.  If not, write to the
;; Free Software Foundation, Inc., 51 Franklin Street, Fifth Floor,
;; Boston, MA 02110-1301, USA.

;;; Commentary:

;; Easyob provides a minimal DSL to quickly define Org-babel execution
;; functions for arbitrary languages.  The main entry point is the
;; `easyob-def' macro.  See its docstring for usage examples.
;;
;; Requirements: Emacs 24.4+, `s' library.

;;; Code:
(require 's)                           ; for s-replace, s-blank?, s-concat

(defmacro easyob-defsh-async (name command)
  "Define an interactive command NAME that runs COMMAND asynchronously.
COMMAND is a string passed to `async-shell-command'.  Output goes to
buffers named *NAME* and *NAME*Error !*."
  `(defalias ',name
     (lambda ()
       (interactive)
       (async-shell-command
        ,command
        ,(concat "*" (symbol-name name) "*")
        ,(concat "*" (symbol-name name) "Error !*")))))

(defmacro easyob-defexe (lang command
                              filename-prefix extension
                              complete-check-regx complete-prefix complete-subfix
                              head tail
                              file
                              var-format)
  "Internal helper: define the actual `org-babel-execute:LANG' function.
This macro is invoked by `easyob-def' and should not be called directly."
  (let* ((exe-name (concat "org-babel-execute:" lang))
         (exe-sym  (intern exe-name)))
    `(fset ',exe-sym
           (lambda (body params)
             (let* ((tmp-src-file (org-babel-temp-file ,filename-prefix ,extension))
                    (processed-params (org-babel-process-params params))
                    (vars (easyob-get-vars processed-params))
                    (async (alist-get :async processed-params nil)))

               ;; Insert variable definitions if a format is provided
               (when ,var-format
                 (setq body (concat (easyob-custom-vars ,var-format vars)
                                    body)))

               ;; Optionally complete the source block if it doesn't match
               ;; the required pattern (e.g. wrap with a main function)
               (unless (and ,complete-check-regx
                            (string-match ,complete-check-regx body))
                 (setq body (concat ,complete-prefix body ,complete-subfix)))

               ;; Prepend head and append tail
               (setq body (concat ,head body ,tail))

               ;; Write body to temporary file
               (with-temp-file tmp-src-file
                 (insert body))

               ;; Resolve template variables in command and file
               (let* ((processed-command ,command)
                      (processed-command (s-replace "$FILE_SIMPLE" "$FILE_DIR/$FILE_BASE"
                                                    processed-command))
                      (processed-command (s-replace "$FILE_BASE" (file-name-base tmp-src-file)
                                                    processed-command))
                      (processed-command (s-replace "$FILE_DIR" (file-name-directory tmp-src-file)
                                                    processed-command))
                      (processed-command (s-replace "$FILE" tmp-src-file
                                                    processed-command))
                      (processed-command (s-replace "$BODY" body
                                                    processed-command))
                      (processed-file ,file)
                      (processed-file (s-replace "$FILE_SIMPLE" "$FILE_DIR/$FILE_BASE"
                                                 processed-file))
                      (processed-file (s-replace "$FILE_BASE" (file-name-base tmp-src-file)
                                                 processed-file))
                      (processed-file (s-replace "$FILE_DIR" (file-name-directory tmp-src-file)
                                                 processed-file))
                      (processed-file (s-replace "$FILE" tmp-src-file
                                                 processed-file))
                      (processed-file (s-replace "$BODY" body
                                                 processed-file)))
                 (message "Processed command: %s" processed-command) ; debug

                 ;; Async execution
                 (when async
                   (async-shell-command
                    processed-command
                    ,(concat "*" exe-name "*")
                    ,(concat "*" exe-name " Error !!!*")))

                 ;; Sync execution
                 (unless async
                   (let ((result (org-babel-eval processed-command "")))
                     ;; Use :file result if specified
                     (unless (s-blank? processed-file)
                       (setq result processed-file))

                     (when result
                       (org-babel-reassemble-table
                        (if (or (member "table" (cdr (assoc :result-params processed-params)))
                                (member "vector" (cdr (assoc :result-params processed-params))))
                            ;; Table/vector result: import from temp file
                            (let ((tmp-file (org-babel-temp-file ,filename-prefix)))
                              (with-temp-file tmp-file
                                (insert (org-babel-trim result)))
                              (org-babel-import-elisp-from-file tmp-file))
                          ;; Scalar result
                          (org-babel-read (org-babel-trim result) t))
                        (org-babel-pick-name
                         (cdr (assoc :colname-names params)) (cdr (assoc :colnames params)))
                        (org-babel-pick-name
                         (cdr (assoc :rowname-names params)) (cdr (assoc :rownames params)))))))))))))

(defmacro easyob-def (name command &rest options)
  "Define an Org-babel execution function for language NAME using COMMAND.

NAME is a symbol, COMMAND is a shell command string that may contain
the following placeholders:
  $FILE       – path to the temporary file containing the code
  $FILE_BASE  – file name without directory and extension
  $FILE_DIR   – directory of the temporary file
  $FILE_SIMPLE- alias for $FILE_DIR/$FILE_BASE
  $BODY       – the final source code (after head/tail/complete)
All other $... strings are left untouched.

OPTIONS is a plist accepting the following keywords:
  :lang          string  – language name for #+BEGIN_SRC (default: NAME)
  :extension     string  – temporary file extension (e.g. \".py\")
  :filename-prefix string – prefix for temp file (default: \"\")
  :head          string  – prepended to body before writing file
  :tail          string  – appended to body
  :complete-check-regx regexp – if body does not match, wrap with :complete-prefix/:complete-subfix
  :complete-prefix  string  – added before body when completion needed
  :complete-subfix  string  – added after body
  :file          string  – output file template (e.g. \"$FILE.png\")
  :var           string  – format string for variable definitions (e.g. \"(def %s %s)\")

Example:
  (easyob-def python \"python3 $FILE\"
    :lang \"python\"
    :extension \".py\"
    :var \"%s = %s\")

  Then in Org:
    #+BEGIN_SRC python :var x=10
    print(x)
    #+END_SRC

CAUTION: The $BODY placeholder inserts raw code into the shell command.
Ensure proper quoting if the code contains spaces or special characters."
  (let ((head (or (plist-get options :head) ""))
        (tail (or (plist-get options :tail) ""))
        (lang (or (plist-get options :lang) (symbol-name name)))
        (extension (or (plist-get options :extension) ""))
        (filename-prefix (or (plist-get options :filename-prefix) ""))
        (complete-check-regx (plist-get options :complete-check-regx))
        (complete-prefix (or (plist-get options :complete-prefix) ""))
        (complete-subfix (or (plist-get options :complete-subfix) ""))
        (file (or (plist-get options :file) ""))
        (var-format (plist-get options :var)))
    `(easyob-defexe ,lang ,command
                    ,filename-prefix ,extension
                    ,complete-check-regx ,complete-prefix ,complete-subfix
                    ,head ,tail
                    ,file
                    ,var-format)))

(defun easyob-get-vars (params)
  "Extract variable alist from Org-babel PARAMS, compatible with Org 8.3+."
  (if (< (string-to-number (org-version)) 8.3)
      (mapcar #'cdr (org-babel-get-header params :var))
    (org-babel--get-vars params)))

(defun easyob-format-var (var-format pair)
  "Format a single variable PAIR using VAR-FORMAT.
PAIR is (VAR . VAL).  Returns a string like:
  (format VAR-FORMAT VAR (symbol-name VAL)) if VAL is a symbol,
  else (format VAR-FORMAT VAR VAL)."
  (let ((var (car pair))
        (val (cdr pair)))
    (when (symbolp val)
      (setq val (symbol-name val)))
    (if var
        (concat (format var-format var val) "\n")
      "")))

(defun easyob-custom-vars (var-format vars)
  "Format all VARS using VAR-FORMAT and return them as a string."
  (if (null vars)
      ""
    (let ((format-var (apply-partially #'easyob-format-var var-format)))
      (concat "\n" (mapconcat format-var vars "\n") "\n"))))

(provide 'easyob)
;;; easyob.el ends here
