;;; easyob-session-tests.el --- Tests for easyob-session  -*- lexical-binding: t; -*-

(require 'ert)
(require 'easyob-tests)
(require 'comint)
(require 'org-element)

(defun easyob-test--command-exists-p (cmd)
  (executable-find cmd))

(ert-deftest easyob--session-init-basic ()
  (skip-unless (easyob-test--command-exists-p "cat"))
  (let ((bufname "*test-easyob-session*"))
    (unwind-protect
        (progn
          (let ((buf (easyob--session-init "test" "cat" "$")))
            (should (equal buf bufname))
            (should (buffer-live-p (get-buffer bufname)))
            (should (comint-check-proc bufname))))
      (when (get-buffer bufname)
        (let (kill-buffer-query-functions)
          (kill-buffer bufname))))))

(ert-deftest easyob--session-init-no-prompt-error ()
  (skip-unless (easyob-test--command-exists-p "sleep"))
  (should-error
   (easyob--session-init "fail" "sleep 10" "# NOTAPROMPT")))

(ert-deftest easyob--session-eval-sync-simple ()
  (skip-unless (easyob-test--command-exists-p "python"))
  (let ((bufname (easyob--session-init "python" '("python" "-i") ">>> "))
        (body "1 + 2\n")
        (eval-cmd "%s\n"))
    (unwind-protect
        (let ((result (easyob--session-eval-sync bufname ">>> " body eval-cmd)))
          ;; 不检查具体内容，只验证返回的是字符串且非空
          (should (stringp result))
          (should (not (equal result "")))
          (message "Python session result: %s" result))
      (when (get-buffer bufname)
        (let (kill-buffer-query-functions)
          (kill-buffer bufname))))))

(ert-deftest easyob--session-eval-async-simulate ()
  (skip-unless (easyob-test--command-exists-p "python"))
  (let ((org-buffer (generate-new-buffer "*test-org-async*"))
        (session-bufname nil)
        (result nil))
    (unwind-protect
        (progn
          ;; 1. 准备一个假的 Org 缓冲区，让异步函数有地方插入结果
          (with-current-buffer org-buffer
            (org-mode)
            (insert "#+RESULTS:\n")          ; 模拟结果位置
            (goto-char (point-min)))
          ;; 2. 启动 Python 会话
          (setq session-bufname (easyob--session-init "python" '("python" "-i") ">>> "))
          ;; 3. 发送异步代码，结果将自动插入 org-buffer
          (with-current-buffer org-buffer
            (easyob--session-eval-async session-bufname ">>> " "1 + 2\n" nil "%s\n"))
          ;; 4. 等待结果被插入（最多 5 秒）
          (let ((max-wait 5)
                (start (float-time)))
            (while (and (< (- (float-time) start) max-wait)
                        (not (with-current-buffer org-buffer
                               (save-excursion
                                 (goto-char (point-min))
                                 (re-search-forward "#\\+RESULTS:" nil t)))))
              ;; 处理进程输出，触发 filter
              (when (get-buffer-process session-bufname)
                (accept-process-output (get-buffer-process session-bufname) 0.1))
              (sleep-for 0.1)))
          ;; 5. 验证结果已非空插入
          (with-current-buffer org-buffer
            (goto-char (point-min))
            (should (re-search-forward "#\\+RESULTS:" nil t))
            (let ((end (point)))
              (forward-line 1)
              (setq result (buffer-substring (point) end)))
            (should (stringp result))
            (should (not (equal result "")))
            (message "Async test result: %s" result)))
      ;; 清理
      (when session-bufname
        (when (get-buffer session-bufname)
          (let (kill-buffer-query-functions)
            (kill-buffer session-bufname))))
      (when (get-buffer org-buffer)
        (let (kill-buffer-query-functions)
          (kill-buffer org-buffer))))))

;; 补充测试：结果过滤和 ANSI 剥离

(ert-deftest easyob--filter-echoed-input-no-echo ()
  "无回显时，保留所有输出行。"
  (let ((raw "1\n2\n")
        (body "1 + 1")
        (prompt ">>>"))
    (should (equal (easyob--filter-echoed-input raw prompt body)
                   "1\n2"))))

(ert-deftest easyob--filter-echoed-input-simple-echo ()
  "单行命令回显（带提示符）应被过滤。"
  (let ((raw ">>> 1 + 1\n2\n")
        (body "1 + 1")
        (prompt ">>>"))
    (should (equal (easyob--filter-echoed-input raw prompt body)
                   "2"))))

(ert-deftest easyob--filter-echoed-input-multiline-echo-no-prompt ()
  "多行输入回显，续行不带提示符。"
  (let* ((body "(def counter (atom 0))\n(swap! counter inc)")
         (raw "(def counter (atom 0))\n(swap! counter inc)\n#'user/counter\n1\n")
         (prompt "user=>[ \t]*"))
    (should (equal (easyob--filter-echoed-input raw prompt body)
                   "#'user/counter\n1"))))

(ert-deftest easyob--filter-echoed-input-multiline-echo-with-prompt ()
  "多行输入回显，首行带提示符。"
  (let* ((body "(def counter (atom 0))\n(swap! counter inc)")
         (raw "user=> (def counter (atom 0))\n(swap! counter inc)\n#'user/counter\n1\n")
         (prompt "user=>[ \t]*"))
    (should (equal (easyob--filter-echoed-input raw prompt body)
                   "#'user/counter\n1"))))

(ert-deftest easyob--filter-echoed-input-clojure-real ()
  "模拟 Clojure REPL 真实输出：首行带提示符，中间有结果，末行带提示符。"
  (let* ((body "(def counter (atom 0))\n(swap! counter inc)")
         (raw "user=> (def counter (atom 0))\n(swap! counter inc)\n#'user/counter\nuser=> 1\n")
         (prompt "user=>[ \t]*"))
    (should (equal (easyob--filter-echoed-input raw prompt body)
                   "#'user/counter\n1"))))

(ert-deftest easyob--filter-echoed-input-removes-trailing-prompt ()
  "末尾提示符不应出现在结果中。"
  (let* ((body "1 + 2")
         (raw ">>> 1 + 2\n3\n>>> ")
         (prompt ">>>"))
    (should (equal (easyob--filter-echoed-input raw prompt body)
                   "3"))))

(ert-deftest easyob--strip-ansi-test ()
  "ANSI 转义序列应被移除。"
  (should (equal (easyob--strip-ansi "\033[33muser=>\033[0m") "user=>"))
  (should (equal (easyob--strip-ansi "normal text") "normal text")))

(ert-deftest easyob--looking-at-prompt-p-ansi-test ()
  "带 ANSI 码的提示符应能被匹配。"
  (should (easyob--looking-at-prompt-p "user=>" "\033[33muser=>\033[0m"))
  (should-not (easyob--looking-at-prompt-p "user=>" "nope")))

(provide 'easyob-session-tests)
