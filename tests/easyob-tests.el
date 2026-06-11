;;; easyob-tests.el --- Common test helpers for easyob  -*- lexical-binding: t; -*-

(require 'ert)
(require 'easyob)

(defmacro easyob-with-temp-org-buffer (&rest body)
  "Execute BODY in a temporary Org-mode buffer."
  `(with-temp-buffer
     (org-mode)
     ,@body))

(defun easyob--mock-org-babel-eval (output)
  "Return a mock function for `org-babel-eval' that returns OUTPUT."
  (lambda (_cmd _body) output))

(provide 'easyob-tests)
;;; easyob-tests.el ends here
