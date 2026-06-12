;; easyob-utils.el --- Internal helpers for easyob -*- lexical-binding: t; -*-

(require 'org-macs)
(require 'ob)

(defun easyob--blank-p (str)
  "Return t if STR is nil, empty, or consists only of whitespace characters."
  (or (null str)
      (string-match-p "\\`[ \t\n\r]*\\'" str)))

(defun easyob--get-vars (params)
  "Extract variable bindings from PARAMS.
Handles both `(var . value)' conses and string references."
  (let (vars)
    (dolist (p params)
      (when (eq (car p) :var)
        (let ((val (cdr p)))
          (cond
           ;; Direct (var . value) cons – used by easyob tests
           ((consp val) (push val vars))
           ;; String reference – delegate to Org if available
           ((stringp val)
            (if (fboundp 'org-babel--get-vars)
                (setq vars (append (org-babel--get-vars (list p)) vars))
              ;; Minimal fallback: parse "var=value"
              (let ((split (split-string val "=")))
                (when (cdr split)
                  (push (cons (intern (car split))
                              (mapconcat #'identity (cdr split) "="))
                        vars)))))))))
    (nreverse vars)))


(defun easyob--format-var (var-format pair)
  (let ((var (car pair)) (val (cdr pair)))
    (when (symbolp val) (setq val (symbol-name val)))
    (if var (concat (format var-format var val) "\n") "")))

(defun easyob--custom-vars (var-format vars)
  (if (null vars) ""
    (concat "\n"
            (mapconcat (lambda (p) (easyob--format-var var-format p)) vars "\n")
            "\n")))

(defun easyob--expand-placeholders (template-string source-file code-body)
  "Replace placeholders in TEMPLATE-STRING with actual values.
SOURCE-FILE is the full path to the temporary source file.
CODE-BODY is the processed source block body string.

Supported placeholders:

  $FILE         → full path of SOURCE-FILE
  $FILE_DIR     → directory part of SOURCE-FILE
  $FILE_BASE    → base name of SOURCE-FILE (without directory and extension)
  $FILE_SIMPLE  → alias for $FILE_DIR/$FILE_BASE
  $BODY         → CODE-BODY (the block's source code)

Return the expanded string."
  (unless (easyob--blank-p template-string)
    (let ((result template-string))
    ;; $FILE_SIMPLE is just a shorthand, expand to dir/base first
    (setq result (replace-regexp-in-string
                  (regexp-quote "$FILE_SIMPLE")
                  "$FILE_DIR/$FILE_BASE"
                  result t t))
    (setq result (replace-regexp-in-string
                  (regexp-quote "$FILE_BASE")
                  (file-name-base source-file)
                  result t t))
    (setq result (replace-regexp-in-string
                  (regexp-quote "$FILE_DIR")
                  (file-name-directory source-file)
                  result t t))
    (setq result (replace-regexp-in-string
                  (regexp-quote "$FILE")
                  source-file
                  result t t))
    (setq result (replace-regexp-in-string
                  (regexp-quote "$BODY")
                  code-body
                  result t t))
    result)))

(defun easyob--inject-vars (body vars var-mode var-format)
  "Inject variable declarations into BODY according to VAR-MODE and VAR-FORMAT.
VARS is an alist of (VAR . VALUE) bindings.
VAR-MODE can be:
  'format  → insert each var as a line using VAR-FORMAT (e.g. \"%s = %s\")
  'let     → wrap body in a (let ...) form
  a function → called as (funcall VAR-MODE VARS BODY)
If VAR-FORMAT is nil, no injection is performed.
When configuration is inconsistent, a warning is issued and the original BODY is returned."
  (cond
   ((easyob--blank-p var-format)
    body)
   ((eq var-mode 'format)
    (if (and var-format vars)
        (concat (easyob--custom-vars var-format vars) body)
      body))
   ((and (functionp var-mode) (not (symbolp var-mode)))
    (funcall var-mode vars body))
   (t
    (lwarn 'easyob :warning
           "Invalid var-mode (%s) or missing var-format; variables not injected"
           var-mode)
    body)))

(defun easyob--process-body (body params var-mode var-format
                                  complete-check-regx complete-prefix complete-subfix
                                  head tail prologue-from-params epilogue-from-params)
  (let* ((vars (easyob--get-vars params))
         (prologue (when prologue-from-params (cdr (assq :prologue params))))
         (epilogue (when epilogue-from-params (cdr (assq :epilogue params))))
         (body (easyob--inject-vars body vars var-mode var-format)))
    (unless (and complete-check-regx (string-match complete-check-regx body))
      (setq body (concat complete-prefix body complete-subfix)))
    (unless prologue (setq body (concat head body)))
    (unless epilogue (setq body (concat body tail)))
    (when prologue (setq body (concat prologue "\n" body)))
    (when epilogue (setq body (concat body "\n" epilogue)))
    body))


(defun easyob--strip-ansi (str)
  "Remove ANSI escape sequences from STR."
  (replace-regexp-in-string "\033\\[[0-9;]*m" "" str))

(defun easyob--looking-at-prompt-p (regexp tail-string)
  "Return non-nil if REGEXP matches TAIL-STRING after stripping ANSI codes."
  (string-match regexp (easyob--strip-ansi tail-string)))




(provide 'easyob-utils)
;;; easyob-utils.el ends here
