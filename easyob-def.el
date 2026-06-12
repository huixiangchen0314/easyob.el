;;; easyob-def.el --- Public macros for easyob language definition -*- lexical-binding: t; -*-

(require 'easyob-utils)
(require 'easyob-exec)
(require 'easyob-session)


(defun easyob--args-get-lang (name args)
  "Get language from ARGS by property of `:lang`.
if value is nil. get symbol-name of NAME."
  (or (plist-get args :lang)
      (symbol-name name)))

(defun easyob--args-get-var (args)
  "Get :var property of ARGS."
  (plist-get args :var))

(defun easyob--args-get-var-mode (args)
  "Return the :var-mode from ARGS, defaulting to 'format.
When :var-mode is not provided, line-by-line variable assignment (format) is used."
  (or (plist-get args :var-mode) 'format))

(defun easyob--args-get-command (args)
  "Get :command property of ARGS.
:command is required to execute code."
  (let ((cmd (plist-get args :command)))
    (unless cmd
    (lwarn 'easyob :warning "Missing :command in args"))
    cmd))

(defun easyob--args-get-execute-fn (args)
  "Return the :execute-fn from ARGS, or nil if absent.
:execute-fn is an optional function that completely overrides the
standard code execution pipeline (temp file + command).  When
supplied, it must be a lambda or function of two arguments:
BODY (the processed source block body) and PARAMS (the Org Babel
parameters).  It should return the result string to be inserted
in the Org buffer.  If not provided, the language must define
a :command instead."
  (plist-get args :execute-fn))

(defun easyob--args-get-head (args)
  "Return the :head string from ARGS, or \"\" if absent.
:head is prepended to the source block body before execution
in non-session mode.  It typically wraps the user code so that
the last expression's value is printed/returned."
  (or (plist-get args :head) ""))

(defun easyob--args-get-tail (args)
  "Return the :tail string from ARGS, or \"\" if absent.
:tail is appended to the source block body before execution
in non-session mode.  Together with :head, it forms the outer
wrapper (e.g. closing parentheses) needed to capture the result."
  (or (plist-get args :tail) ""))

(defun easyob--args-get-extension (args)
  "Return the :extension string from ARGS, or \"\" if absent.
It specifies the file extension (including the dot) for the
temporary source file, e.g. \".lua\".  Used to construct the
temp file name in `org-babel-temp-file'."
  (or (plist-get args :extension) ""))

(defun easyob--args-get-filename-prefix (args)
  "Return the :filename-prefix string from ARGS, or \"\" if absent.
It is passed to `org-babel-temp-file' as the PREFIX argument,
influencing the generated temp file name.  Useful to avoid
collisions when multiple languages are used."
  (or (plist-get args :filename-prefix) ""))


(defun easyob--args-get-complete-check-regx (args)
  "Return the :complete-check-regx from ARGS, or nil if absent.
This regexp is tested against the processed body before execution.
If the body does NOT match, the body is considered incomplete and
will be wrapped with :complete-prefix and :complete-subfix to form
a valid program.  Useful for languages that require a boilerplate
around user-provided expressions."
  (plist-get args :complete-check-regx))

(defun easyob--args-get-complete-prefix (args)
  "Return the :complete-prefix string from ARGS, or \"\" if absent.
When :complete-check-regx is supplied and the body does not match,
this string is prepended to the body.  Use it to add the necessary
opening part of a completion wrapper (e.g. a print statement)."
  (or (plist-get args :complete-prefix) ""))

(defun easyob--args-get-complete-subfix (args)
  "Return the :complete-subfix string from ARGS, or \"\" if absent.
Like :complete-prefix, but appended to the body when the body fails
the completeness check.  Use it to add the closing part of a wrapper."
  (or (plist-get args :complete-subfix) ""))

(defun easyob--args-get-prologue-from-params (args)
  "Return the :prologue-from-params property from ARGS, or nil if absent.
If non-nil, `easyob--process-body' will extract the prologue from
the source block's parameters (i.e., the :prologue header argument).
When nil, the prologue is taken from the `:head' setting, if any."
  (plist-get args :prologue-from-params))

(defun easyob--args-get-epilogue-from-params (args)
  "Return the :epilogue-from-params property from ARGS, or nil if absent.
If non-nil, `easyob--process-body' will extract the epilogue from
the source block's parameters (i.e., the :epilogue header argument).
When nil, the epilogue is taken from the `:tail' setting, if any."
  (plist-get args :epilogue-from-params))

(defun easyob--args-get-default-header-args (args)
  "Return the :default-header-args property from ARGS, or nil if absent.
This is a plist of Org Babel header arguments that should be used as
the default for the language.  When supplied, it is used to define a
variable `org-babel-default-header-args:<lang>'."
  (plist-get args :default-header-args))

(defun easyob--args-get-header-args-def (args)
  "Return the :header-args-def property from ARGS, or nil if absent.
This is a list of header argument names that are defined (and possibly
required) for the language.  When supplied, it is used to define a
variable `org-babel-header-args:<lang>'."
  (plist-get args :header-args-def))


(defun easyob--args-get-edit-prep (args)
  "Return the :edit-prep property from ARGS, or nil if absent.
If supplied, it should be a function of one argument (INFO) that
is called when the user edits the source block with `org-edit-src-code'.
It typically sets up the edit buffer with language-specific settings
\(e.g., enabling a certain major mode, setting variables, or loading
necessary libraries).  When nil, no special preparation is done."
  (plist-get args :edit-prep))

(defun easyob--args-get-alias (args)
  "Return the :alias property from ARGS, or nil if absent.
An alias allows the language to be invoked by an alternative name
in Org source blocks.  For example, if :alias is \"js\", then both
`#+BEGIN_SRC javascript' and `#+BEGIN_SRC js' will work.
The value should be a string (the alias name).  When nil, the
language has no alias."
  (plist-get args :alias))

(defun easyob--args-get-no-session (args)
  "Return the :no-session property from ARGS, or nil if absent.
If non-nil, it indicates that this language does NOT support
session evaluation at all.  In that case, `easyob-def' will
define a `org-babel-prep-session:<lang>' function that signals
an error if a session is requested.  When nil, session support
is either provided or not applicable."
  (plist-get args :no-session))

(defun easyob--args-get-session-cmd (args)
  "Return the :session-cmd property from ARGS, or nil if absent.
This is the command used to start an interactive REPL session
for the language.  It can be a string (no arguments) or a list
\(command and arguments).  For example, for Python it might be
'(\"python\" \"-i\").  If nil, session support is not available
\(unless :execute-fn is used to provide custom session handling)."
  (plist-get args :session-cmd))

(defun easyob--args-get-prompt-regexp (args)
  "Return the :prompt-regexp from ARGS, or nil if absent.
This is a regular expression used to detect the REPL prompt in
session evaluation.  It should match the prompt string that appears
after every command in the interactive session.  ANSI escape codes
are automatically stripped before matching, so the regex can match
the plain text prompt."
  (plist-get args :prompt-regexp))

(defun easyob--args-get-eval-cmd (args)
  "Return the :eval-cmd from ARGS, or nil if absent.
In session mode, this is a format string that wraps the source
block body before sending it to the REPL.  For example, \"%s\\n\"
sends the body followed by a newline.  If nil, the body is sent
as-is.  This is useful for languages that require a special prefix
or suffix to trigger evaluation in the REPL."
  (plist-get args :eval-cmd))

(defun easyob--args-get-session-async (args)
  "Return the :session-async property from ARGS, or nil if absent.
If non-nil, session blocks will default to asynchronous execution
\(the user can still override it with :async in the block).
If nil, session execution is synchronous unless the block
explicitly sets :async yes."
  (plist-get args :session-async))

(defun easyob--args-get-file (args)
  "Return the :file property from ARGS, or nil if absent.
:file is a string (possibly containing $FILE, $BODY placeholders)
that specifies an output file for the source block result."
  (plist-get args :file))

(defun easyob--parse-args (name args)
  (let* ((lang (easyob--args-get-lang name args))
         (var-format (easyob--args-get-var args))
         (var-mode (easyob--args-get-var-mode args))
         (command (easyob--args-get-command args ))
         (execute-fn (easyob--args-get-execute-fn args))
         (head (easyob--args-get-head args))
         (tail (easyob--args-get-tail args))
         (ext (easyob--args-get-extension args))
         (prefix (easyob--args-get-filename-prefix args))
         (ck-regx (easyob--args-get-complete-check-regx args))
         (ck-prefix (easyob--args-get-complete-prefix args))
         (ck-subfix (easyob--args-get-complete-subfix args))
         (prologue-from (easyob--args-get-prologue-from-params args))
         (epilogue-from (easyob--args-get-epilogue-from-params args))
         (def-headers (easyob--args-get-default-header-args args))
         (head-def (easyob--args-get-header-args-def args))
         (edit-prep (easyob--args-get-edit-prep args))
         (alias (easyob--args-get-alias args))
         (no-session (easyob--args-get-no-session args))
         (s-cmd (easyob--args-get-session-cmd args))
         (prompt (easyob--args-get-prompt-regexp args))
         (file (easyob--args-get-file args))
         (eval-cmd (easyob--args-get-eval-cmd args))
         (session-async (easyob--args-get-session-async args)))
    (unless (or command execute-fn)
      (error "easyob-def requires either :command or :execute-fn"))
    `(:lang ,lang :command ,command :execute-fn ,execute-fn
      :var-mode ,var-mode :var-format ,var-format :file ,file
      :head ,head :tail ,tail :extension ,ext :filename-prefix ,prefix
      :complete-check-regx ,ck-regx :complete-prefix ,ck-prefix :complete-subfix ,ck-subfix
      :prologue-from-params ,prologue-from :epilogue-from-params ,epilogue-from
      :default-header-args ,def-headers :header-args-def ,head-def
      :edit-prep ,edit-prep :alias ,alias :no-session ,no-session
      :session-cmd ,s-cmd :prompt-regexp ,prompt :eval-cmd ,eval-cmd
      :session-async ,session-async)))

(defun easyob--params-get-async (params)
  "Return the :async value from PARAMS (a processed Org Babel params alist).
Returns nil if :async is not present or is nil."
  (alist-get :async params nil))

(defun easyob--params-get-file (params)
  "Return the :file value from PARAMS (an Org Babel parameters alist).
If :file is not present or is nil, return nil."
  (cdr (assq :file params)))

(defun easyob--make-execute-lambda (lang options)
  (let ((execute-fn (plist-get options :execute-fn))
        (command (plist-get options :command))
        (prefix (plist-get options :filename-prefix))
        (ext (plist-get options :extension))
        (head (plist-get options :head))
        (tail (plist-get options :tail))
        (file (plist-get options :file))
        (ck-regx (plist-get options :complete-check-regx))
        (ck-prefix (plist-get options :complete-prefix))
        (ck-subfix (plist-get options :complete-subfix))
        (vmode (plist-get options :var-mode))
        (vfmt (plist-get options :var-format))
        (prologue-from (plist-get options :prologue-from-params))
        (epilogue-from (plist-get options :epilogue-from-params)))
    (if execute-fn
        `(lambda (body params)
           (let ((processed-body (easyob--process-body body params ',vmode ,vfmt
                                                       ,ck-regx ,ck-prefix ,ck-subfix
                                                       ,head ,tail ,prologue-from ,epilogue-from)))
             (funcall ,execute-fn processed-body params)))
      ;; else here.
      `(lambda (body params)
         (let* ((tmp-src-file (org-babel-temp-file ,prefix ,ext))
                (processed-params (org-babel-process-params params))
                (async (easyob--params-get-async processed-params))
                (file (or (cdr (assq :file params)) ,file))
                (body (easyob--process-body body params ',vmode ,vfmt
                                            ,ck-regx ,ck-prefix ,ck-subfix
                                            ,head ,tail ,prologue-from ,epilogue-from))
                (command (easyob--expand-placeholders ,command tmp-src-file body)))
           (with-temp-file tmp-src-file (insert body))
           (message "Processed command: %s" command)
           (if async
               (easyob--execute-async command ,lang)
             (easyob--execute-sync command file tmp-src-file body ,prefix processed-params params)))))))

(defun easyob--session-valid-p (session)
  "Return non-nil if SESSION is a valid session name.
A session is valid if it is a non-empty string and not equal to \"none\"."
  (and session
       (stringp session)
       (not (string-empty-p session))
       (not (equal session "none"))))

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
                       (if (easyob--session-valid-p session)
                           (let ((session-buffer-name (easyob--session-init ,lang ,session-cmd ,prompt-regexp))
                                 (full-body (if ,var-format
                                                (concat (easyob--custom-vars ,var-format (easyob--get-vars params)) body)
                                              body))
                                 (async (when (or ,session-async (alist-get :async params)) t)))
                             (if async
                                 (easyob--session-eval-async session-buffer-name ,prompt-regexp full-body params ,eval-cmd)
                               (easyob--session-eval-sync session-buffer-name ,prompt-regexp full-body ,eval-cmd)))
                         ;; else here.
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
