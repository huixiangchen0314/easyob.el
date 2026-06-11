;;; easyob-def.el --- Public macros for easyob language definition -*- lexical-binding: t; -*-

(require 'easyob-utils)
(require 'easyob-exec)
(require 'easyob-session)

(defun easyob--parse-args (name args)
  (let* ((lang (or (plist-get args :lang) (symbol-name name)))
         (var-format (plist-get args :var))
         (var-mode (or (plist-get args :var-mode) (when var-format 'format)))
         (command (plist-get args :command))
         (execute-fn (plist-get args :execute-fn))
         (head (or (plist-get args :head) ""))
         (tail (or (plist-get args :tail) ""))
         (ext (or (plist-get args :extension) ""))
         (prefix (or (plist-get args :filename-prefix) ""))
         (ck-regx (plist-get args :complete-check-regx))
         (ck-prefix (or (plist-get args :complete-prefix) ""))
         (ck-subfix (or (plist-get args :complete-subfix) ""))
         (file (or (plist-get args :file) ""))
         (prologue-from (plist-get args :prologue-from-params))
         (epilogue-from (plist-get args :epilogue-from-params))
         (def-headers (plist-get args :default-header-args))
         (head-def (plist-get args :header-args-def))
         (edit-prep (plist-get args :edit-prep))
         (alias (plist-get args :alias))
         (no-session (plist-get args :no-session))
         (s-cmd (plist-get args :session-cmd))
         (prompt (plist-get args :prompt-regexp))
         (eval-cmd (plist-get args :eval-cmd))
         (session-async (plist-get args :session-async)))
    (unless (or command execute-fn)
      (error "easyob-def requires either :command or :execute-fn"))
    `(:lang ,lang :command ,command :execute-fn ,execute-fn
      :var-mode ,var-mode :var-format ,var-format
      :head ,head :tail ,tail :extension ,ext :filename-prefix ,prefix
      :complete-check-regx ,ck-regx :complete-prefix ,ck-prefix :complete-subfix ,ck-subfix
      :file ,file :prologue-from-params ,prologue-from :epilogue-from-params ,epilogue-from
      :default-header-args ,def-headers :header-args-def ,head-def
      :edit-prep ,edit-prep :alias ,alias :no-session ,no-session
      :session-cmd ,s-cmd :prompt-regexp ,prompt :eval-cmd ,eval-cmd
      :session-async ,session-async)))

(defun easyob--make-execute-lambda (lang options)
  (let ((execute-fn (plist-get options :execute-fn))
        (command (plist-get options :command))
        (file (plist-get options :file))
        (prefix (plist-get options :filename-prefix))
        (ext (plist-get options :extension))
        (head (plist-get options :head)) (tail (plist-get options :tail))
        (ck-regx (plist-get options :complete-check-regx))
        (ck-prefix (plist-get options :complete-prefix))
        (ck-subfix (plist-get options :complete-subfix))
        (vmode (plist-get options :var-mode)) (vfmt (plist-get options :var-format))
        (prologue-from (plist-get options :prologue-from-params))
        (epilogue-from (plist-get options :epilogue-from-params)))
    (if execute-fn
        `(lambda (body params)
           (let ((processed-body
                  (if ,vmode
                      (easyob--process-body body params ,vmode ,vfmt
                                            ,ck-regx ,ck-prefix ,ck-subfix
                                            ,head ,tail ,prologue-from ,epilogue-from)
                    body)))
             (funcall ,execute-fn processed-body params)))
      `(lambda (body params)
         (let* ((tmp-src-file (org-babel-temp-file ,prefix ,ext))
                (processed-params (org-babel-process-params params))
                (async (alist-get :async processed-params nil))
                (body (easyob--process-body body params ,vmode ,vfmt
                                            ,ck-regx ,ck-prefix ,ck-subfix
                                            ,head ,tail ,prologue-from ,epilogue-from))
                (command (easyob--expand-template ,command tmp-src-file body)))
           (with-temp-file tmp-src-file (insert body))
           (message "Processed command: %s" command)
           (if async
               (easyob--execute-async command ,lang)
             (easyob--execute-sync command ,file tmp-src-file body ,prefix processed-params params)))))))

(defmacro easyob-def (name &rest args)
  "Define Org-babel execute for NAME.  Accepts :command or :execute-fn."
  (when (stringp (car args))             ; backward compatibility
    (setq args (list* :command (car args) (cdr args))))
  (let* ((options (easyob--parse-args name args))
         (lang (plist-get options :lang))
         (exe-sym (intern (concat "org-babel-execute:" lang)))
         (lambda-form (easyob--make-execute-lambda lang options))
         (def-headers (plist-get options :default-header-args))
         (head-def (plist-get options :header-args-def))
         (edit-prep (plist-get options :edit-prep))
         (alias (plist-get options :alias))
         (no-session (plist-get options :no-session))
         (session-cmd (plist-get options :session-cmd))
         (prompt-regexp (plist-get options :prompt-regexp))
         (eval-cmd (plist-get options :eval-cmd))
         (var-format (plist-get options :var-format))
         (session-async (plist-get options :session-async)))
    `(progn
       (fset ',exe-sym ,lambda-form)
       ,(when def-headers
          `(defvar ,(intern (concat "org-babel-default-header-args:" lang))
             ,def-headers))
       ,(when head-def
          `(defvar ,(intern (concat "org-babel-header-args:" lang))
             ',head-def))
       ,(when edit-prep
          `(defun ,(intern (concat "org-babel-edit-prep:" lang)) (info)
             ,edit-prep))
       ,(when alias
          `(org-babel-make-language-alias ,alias ,lang))
       ,(cond
         (session-cmd
          `(progn
             (defun ,(intern (concat "org-babel-initiate-session:" lang)) (_s _p)
               (easyob--session-init ,lang ,session-cmd ,prompt-regexp))
             (defalias ',(intern (concat "org-babel-prep-session:" lang))
               ',(intern (concat "org-babel-initiate-session:" lang)))
             (fset ',exe-sym
                   (lambda (body params)
                     (let ((session (cdr (assq :session params))))
                       (if session
                           (let ((session-buffer-name (easyob--session-init ,lang ,session-cmd ,prompt-regexp))
                                 (full-body (if ,var-format
                                                (concat (easyob--custom-vars ,var-format (easyob--get-vars params)) body)
                                              body))
                                 (async (when (or ,session-async (alist-get :async params)) t)))
                             (if async
                                 (easyob--session-eval-async session-buffer-name ,prompt-regexp full-body params ,eval-cmd)
                               (easyob--session-eval-sync session-buffer-name ,prompt-regexp full-body ,eval-cmd)))
                         (funcall ,lambda-form body params)))))))
         (no-session
          `(defun ,(intern (concat "org-babel-prep-session:" lang)) (_s _p)
             (error ,(format "%s sessions are not supported" lang))))))))

(defmacro easyob-def-session (name command session-cmd prompt-regexp &rest options)
  "Shortcut to define a language with both temp-file and session execution."
  (declare (indent 2))
  `(easyob-def ,name
     :command ,command
     :session-cmd ,session-cmd
     :prompt-regexp ,prompt-regexp
     ,@options))

(provide 'easyob-def)
;;; easyob-def.el ends here
