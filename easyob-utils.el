;;; easyob-utils.el --- Internal helpers for easyob -*- lexical-binding: t; -*-

(require 'org-macs)
(require 'ob)

(defun easyob--blank-p (str)
  (string-match-p "\\`[ \t\n\r]*\\'" str))

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

(defun easyob--expand-template (template tmp-src-file body)
  (let ((result template))
    (setq result (replace-regexp-in-string (regexp-quote "$FILE_SIMPLE") "$FILE_DIR/$FILE_BASE" result t t))
    (setq result (replace-regexp-in-string (regexp-quote "$FILE_BASE") (file-name-base tmp-src-file) result t t))
    (setq result (replace-regexp-in-string (regexp-quote "$FILE_DIR") (file-name-directory tmp-src-file) result t t))
    (setq result (replace-regexp-in-string (regexp-quote "$FILE") tmp-src-file result t t))
    (setq result (replace-regexp-in-string (regexp-quote "$BODY") body result t t))
    result))

(defun easyob--process-body (body params var-mode var-format
                                  complete-check-regx complete-prefix complete-subfix
                                  head tail prologue-from-params epilogue-from-params)
  (let* ((vars (easyob--get-vars params))
         (prologue (when prologue-from-params (cdr (assq :prologue params))))
         (epilogue (when epilogue-from-params (cdr (assq :epilogue params))))
         (body (cond
                ;; 1) let 模式
                ((eq var-mode 'let)
                 (if (null vars) body
                   (format "(let (%s)\n%s)"
                           (mapconcat (lambda (x) (format "(%s %S)" (car x) (cdr x))) vars "\n      ")
                           body)))
                ;; 2) format 模式（关键字，非函数）
                ((eq var-mode 'format)
                 (if (and var-format vars)
                     (concat (easyob--custom-vars var-format vars) body)
                   body))
                ;; 3) 用户自定义函数（必须是真正的函数对象，不能是符号）
                ((and (functionp var-mode) (not (symbolp var-mode)))
                 (funcall var-mode vars body))
                ;; 4) 其他情况（包括 nil）不做变量替换
                (t body))))
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
