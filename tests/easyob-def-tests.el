;;; easyob-def-tests.el --- Tests for easyob-def  -*- lexical-binding: t; -*-

(require 'ert)
(require 'easyob-tests)

(ert-deftest easyob--parse-args-defaults ()
  (let ((plist (easyob--parse-args 'mylang '(:command "run %s" :var "%s=%s"))))
    (should (equal (plist-get plist :lang) "mylang"))
    (should (equal (plist-get plist :command) "run %s"))
    (should (equal (plist-get plist :var-format) "%s=%s"))
    (should (eq (plist-get plist :var-mode) 'format))))

(ert-deftest easyob--parse-args-error-no-command ()
  (should-error (easyob--parse-args 'test '(:var "x")))
  (let ((plist (easyob--parse-args 'test '(:execute-fn my-func))))
    (should (equal (plist-get plist :execute-fn) 'my-func))))

(ert-deftest easyob--make-execute-lambda-command-mode ()
  (let* ((options (easyob--parse-args 'test '(:command "echo %s" :var "%s=%s" :extension ".sh")))
         (lambda-sexp (easyob--make-execute-lambda "test" options)))
    (should (consp lambda-sexp))
    (should (eq (car lambda-sexp) 'lambda))
    (let ((fn (eval lambda-sexp)))
      (should (functionp fn)))))

(ert-deftest easyob--make-execute-lambda-execute-fn-mode ()
  (let* ((options (easyob--parse-args 'test '(:execute-fn (lambda (b p) "done"))))
         (lambda-sexp (easyob--make-execute-lambda "test" options)))
    (let ((fn (eval lambda-sexp)))
      (should (equal (funcall fn "body" '()) "done")))))

(ert-deftest easyob-def-basic ()
  (let* ((lang "easytest")
         (exec-func (intern (concat "org-babel-execute:" lang)))
         (header-var (intern (concat "org-babel-default-header-args:" lang))))
    (unwind-protect
        (progn
          (eval `(easyob-def ,(intern lang) :command "true" :extension ".sh"
                             :default-header-args '((:results . "output"))))
          (should (fboundp exec-func))
          (should (boundp header-var))
          (should (equal (symbol-value header-var)
                         '((:results . "output")))))
      (fmakunbound exec-func)
      (when (boundp header-var) (makunbound header-var)))))

(ert-deftest easyob-def-with-session ()
  (let* ((lang "easytest2")
         (exec-func (intern (concat "org-babel-execute:" lang)))
         (init-sess (intern (concat "org-babel-initiate-session:" lang)))
         (prep-sess (intern (concat "org-babel-prep-session:" lang))))
    (unwind-protect
        (progn
          (eval `(easyob-def ,(intern lang)
                   :command "echo hi"
                   :session-cmd "cat"
                   :prompt-regexp "$"))
          (should (fboundp init-sess))
          (should (fboundp prep-sess))
          (should (fboundp exec-func)))
      (mapc #'fmakunbound (list exec-func init-sess prep-sess)))))

(provide 'easyob-def-tests)
