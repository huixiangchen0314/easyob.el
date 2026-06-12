;;; easyob-utils-tests.el --- Tests for easyob-utils  -*- lexical-binding: t; -*-

(require 'ert)
(require 'easyob-tests)

(ert-deftest easyob--blank-p-test ()
  (should (easyob--blank-p ""))
  (should (easyob--blank-p "   \t\n  "))
  (should-not (easyob--blank-p " x "))
  (should-not (easyob--blank-p "a")))

(ert-deftest easyob--get-vars-test ()
  (let ((params '((:var . (x . 1)) (:var . (y . "two")) (:results . "output"))))
    (should (equal (easyob--get-vars params) '((x . 1) (y . "two"))))))

(ert-deftest easyob--format-var-test ()
  (should (equal (easyob--format-var "%s = %s" '(x . 1)) "x = 1\n"))
  (should (equal (easyob--format-var "%s = %s" '(y . "hello")) "y = hello\n"))
  (should (equal (easyob--format-var "%s = %s" '(nil . 5)) "")))

(ert-deftest easyob--custom-vars-test ()
  (should (equal (easyob--custom-vars "%s = %s" nil) ""))
  (should (equal (easyob--custom-vars "%s = %s" '((x . 1))) "\nx = 1\n\n"))
  (should (equal (easyob--custom-vars "%s = %s" '((x . 1) (y . 2)))
                 "\nx = 1\n\ny = 2\n\n")))

(ert-deftest easyob--expand-placeholders-test ()
  (let ((body "print(1+1)")
        (tmpfile "/tmp/test.py"))
    (should (string-match-p (regexp-quote body)
                            (easyob--expand-placeholders "$BODY" tmpfile body)))
    (should (string-match-p (regexp-quote tmpfile)
                            (easyob--expand-placeholders "$FILE" tmpfile body)))
    (should (string-match-p (regexp-quote (file-name-directory tmpfile))
                            (easyob--expand-placeholders "$FILE_DIR" tmpfile body)))
    (should (string-match-p (regexp-quote (file-name-base tmpfile))
                            (easyob--expand-placeholders "$FILE_BASE" tmpfile body)))))

(ert-deftest easyob--process-body-var-mode-format ()
  (let ((params '((:var . (x . 1)))))
    (should (string-match-p "x = 1"
                            (easyob--process-body "echo $x" params 'format "%s = %s"
                                                  nil "" "" "" "" nil nil)))))

(ert-deftest easyob--process-body-prologue-epilogue ()
  (let ((params '((:prologue . "P") (:epilogue . "E"))))
    (let ((body (easyob--process-body "body" params nil nil
                                      nil "" "" "" ""
                                      t t)))
      (should (string-match-p "P\nbody" body))
      (should (string-match-p "E$" body)))))

(ert-deftest easyob--process-body-complete-check ()
  (let ((params '()))
    (let ((body (easyob--process-body "if True:" params nil nil
                                      "def" "def " ": pass" "" "" nil nil)))
      (should (string-match-p "\\`def " body))
      (should (string-match-p ": pass\\'" body)))))

(ert-deftest easyob--looking-at-prompt-p-test ()
  (should (easyob--looking-at-prompt-p ">>>" "some output\n>>> "))
  (should (easyob--looking-at-prompt-p "# " "# "))
  (should-not (easyob--looking-at-prompt-p ">>>" "no prompt here")))

(provide 'easyob-utils-tests)
