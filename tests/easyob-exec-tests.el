;;; easyob-exec-tests.el --- Tests for easyob-exec  -*- lexical-binding: t; -*-

(require 'ert)
(require 'easyob-tests)

(ert-deftest easyob--execute-sync-string-result ()
  (cl-letf (((symbol-function 'org-babel-eval)
             (easyob--mock-org-babel-eval "42")))
    (let ((result (easyob--execute-sync "echo 42" "" "/tmp/test.sh" ""
                                        "prefix" nil nil)))
      ;; org-babel-read turns "42" into 42
      (should (equal result 42)))))

(ert-deftest easyob--execute-sync-file-template ()
  (cl-letf (((symbol-function 'org-babel-eval) (lambda (_c _b) "ignored")))
    (let ((result (easyob--execute-sync "cmd" "$FILE" "/tmp/test.py" ""
                                        "prefix" nil nil)))
      (should (string-match-p "/tmp/test.py" result)))))

(ert-deftest easyob--execute-sync-table-result ()
  (cl-letf (((symbol-function 'org-babel-eval)
             (easyob--mock-org-babel-eval "1,2\n3,4"))
            ((symbol-function 'org-babel-temp-file) (lambda (&rest _) "/tmp/test.csv"))
            ((symbol-function 'org-babel-import-elisp-from-file)
             (lambda (_file) '((1 2) (3 4)))))
    (let ((processed-params '((:result-params . ("table"))))
          (params nil))
      (let ((result (easyob--execute-sync "cmd" "" "/tmp/test.sh" ""
                                          "prefix" processed-params params)))
        (should (equal result '((1 2) (3 4))))))))

(ert-deftest easyob--execute-async-buffers ()
  (let ((buf-name (concat "*org-babel-execute:test-lang*")))
    (unwind-protect
        (progn
          (easyob--execute-async "echo done" "test-lang")
          (sleep-for 0.5)
          (should (get-buffer buf-name)))
      (when (get-buffer buf-name) (kill-buffer buf-name)))))

(provide 'easyob-exec-tests)
