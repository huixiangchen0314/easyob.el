;;; easyob-session.el --- Session support for easyob -*- lexical-binding: t; -*-

(require 'easyob-utils)
(require 'ob)
(require 'comint)

;; ── Session Initialization ────────────────────────────────────────────

(defun easyob--session-init (lang session-cmd prompt-regexp)
  "Start comint session for LANG, wait up to 5s for prompt."
  (let ((session-buffer-name (concat "*" lang "-easyob-session*")))
    (let* ((cmd (if (listp session-cmd) session-cmd (list session-cmd)))
           (max-wait 5)
           (start (float-time)))
      (unless (comint-check-proc session-buffer-name)
        (apply #'make-comint-in-buffer (car cmd) session-buffer-name
               (car cmd) nil (cdr cmd))
        (sleep-for 0.3))
      (with-current-buffer session-buffer-name
        (while (and (not (easyob--looking-at-prompt-p
                          prompt-regexp
                          (buffer-substring-no-properties
                           (max (point-min) (- (point-max) 500))
                           (point-max))))
                    (< (- (float-time) start) max-wait))
          (accept-process-output (get-buffer-process session-buffer-name) 0.1))
        (unless (easyob--looking-at-prompt-p
                 prompt-regexp
                 (buffer-substring-no-properties
                  (max (point-min) (- (point-max) 500))
                  (point-max)))
          (message "Easyob prompt wait debug – regexp: %S\ntail:\n%s"
                   prompt-regexp
                   (buffer-substring-no-properties (max (point-min) (- (point-max) 300)) (point-max)))
          (error "Easyob: session for %s did not show prompt within %s seconds" lang max-wait))))
    session-buffer-name))

;; ── Prompt Waiting (extracted) ────────────────────────────────────────

(defun easyob--wait-for-prompt (buffer input-end prompt-regexp max-wait)
  "Wait in BUFFER for new output after INPUT-END and a matching prompt.
Returns non-nil if prompt was found, nil if timeout."
  (let* ((start (float-time))
         (proc (get-buffer-process buffer)))
    (with-current-buffer buffer
      (while (and (not (and (> (point-max) (marker-position input-end))
                            (easyob--looking-at-prompt-p
                             prompt-regexp
                             (buffer-substring-no-properties
                              (max (point-min) (- (point-max) 500))
                              (point-max)))))
                  (< (- (float-time) start) max-wait))
        (accept-process-output proc 0.1)))
    (with-current-buffer buffer
      (and (> (point-max) (marker-position input-end))
           (easyob--looking-at-prompt-p
            prompt-regexp
            (buffer-substring-no-properties
             (max (point-min) (- (point-max) 500))
             (point-max)))))))

;; ── Output Extraction ─────────────────────────────────────────────────

(defun easyob--extract-raw-output (buffer input-end)
  "Extract raw output from BUFFER between marker INPUT-END and (point-max)."
  (with-current-buffer buffer
    (buffer-substring-no-properties input-end (point-max))))

;; ── Echo Filtering ────────────────────────────────────────────────────

(defun easyob--filter-echoed-input (raw-output prompt-regexp sent-body)
  "Remove echoed input lines from RAW-OUTPUT."
  (let* ((plain (easyob--strip-ansi raw-output))
         (input-lines (split-string sent-body "\n" t))
         (lines (split-string plain "\n"))
         (prompt-re (concat "\\`[ \t]*" prompt-regexp "[ \t]*")))
    (let ((clean-lines
           (seq-remove
            (lambda (line)
              (or (string-blank-p line)
                  (let ((stripped (if (string-match prompt-re line)
                                      (substring line (match-end 0))
                                    line)))
                    (seq-some (lambda (in) (equal (string-trim stripped) (string-trim in)))
                              input-lines))))
            lines)))
      (setq clean-lines
            (mapcar (lambda (line)
                      (if (string-match prompt-re line)
                          (string-trim (substring line (match-end 0)))
                        line))
                    clean-lines))
      (string-trim-right (string-join clean-lines "\n")))))

;; ── Result Cleaning ───────────────────────────────────────────────────

(defun easyob--clean-result (str)
  "Trim whitespace and return cleaned result string."
  (org-babel-trim str))

;; ── Synchronous Session Evaluation ────────────────────────────────────

(defun easyob--session-eval-sync (session-buffer prompt-regexp body &optional eval-cmd)
  "Send BODY to session and return the result string (synchronous)."
  (let* ((full-body (if eval-cmd (format eval-cmd body) body))
         (max-wait 10)
         (start (float-time))
         (proc (get-buffer-process session-buffer)))
    (unless proc
      (error "No process in session buffer %s" session-buffer))
    (with-current-buffer session-buffer
      (goto-char (point-max))
      (let ((input-start (point-marker)))
        (insert full-body)
        (comint-send-input nil t)
        ;; 给进程一点时间开始输出（修复 Windows 批处理下的时序问题）
        (sleep-for 0.2)
        ;; 等待提示符出现在缓冲区末尾
        (while (and (not (easyob--looking-at-prompt-p
                          prompt-regexp
                          (buffer-substring-no-properties
                           (max (point-min) (- (point-max) 500))
                           (point-max))))
                    (< (- (float-time) start) max-wait))
          (accept-process-output proc 0.1))
        (if (easyob--looking-at-prompt-p
             prompt-regexp
             (buffer-substring-no-properties
              (max (point-min) (- (point-max) 500))
              (point-max)))
            (let* ((raw-output (buffer-substring-no-properties input-start (point-max)))
                   (filtered (easyob--filter-echoed-input raw-output prompt-regexp full-body)))
              (easyob--clean-result filtered))
          (progn
            (message "Easyob: timeout waiting for prompt after sending: %s" full-body)
            ""))))))

;; ── Asynchronous Session Evaluation (unchanged) ───────────────────────

(defun easyob--session-eval-async (session-buffer prompt-regexp body params &optional eval-cmd)
  "Send BODY to session asynchronously; insert result when prompt appears.
Uses a process filter – true async callback, no timer."
  (let* ((full-body (if eval-cmd (format eval-cmd body) body))
         (proc (get-buffer-process session-buffer))
         (org-buffer (current-buffer))
         (result-marker (org-babel-where-is-src-block-result))
         (result-params (cdr (assq :result-params params)))
         (indent (save-excursion
                   (when result-marker
                     (goto-char result-marker)
                     (current-column))))
         (old-filter (process-filter proc)))
    (unless proc
      (error "No process in session buffer %s" session-buffer))
    (with-current-buffer session-buffer
      (goto-char (point-max))
      ;; 记录插入代码前的准确位置（用于后续提取输出）
      (let ((input-start (point-marker)))
        (insert full-body)
        (comint-send-input nil t)
        (set-process-filter
         proc
         (lambda (proc string)
           ;; 将进程输出追加到 session buffer
           (when (buffer-live-p session-buffer)
             (with-current-buffer session-buffer
               (save-excursion
                 (goto-char (point-max))
                 (insert string))))
           ;; 检查提示符是否已出现
           (when (and (buffer-live-p session-buffer)
                      (with-current-buffer session-buffer
                        (easyob--looking-at-prompt-p
                         prompt-regexp
                         (buffer-substring-no-properties
                          (max (point-min) (- (point-max) 500))
                          (point-max)))))
             ;; 恢复旧的 filter，防止重复触发
             (set-process-filter proc old-filter)
             ;; 提取并清洗结果
             (let* ((raw-output
                     (with-current-buffer session-buffer
                       (buffer-substring-no-properties input-start (point-max))))
                    (filtered (easyob--filter-echoed-input raw-output prompt-regexp full-body))
                    (final-result (easyob--clean-result filtered)))
               ;; 插入到原始 Org 缓冲区的结果位置
               (when (buffer-live-p org-buffer)
                 (with-current-buffer org-buffer
                   (save-excursion
                     (when result-marker (goto-char result-marker))
                     (org-babel-remove-result)
                     (org-babel-insert-result final-result result-params)
                     (when indent (indent-to indent))))))))))))
    (message "Easyob session async: code sent, result will be inserted automatically."))


(provide 'easyob-session)
;;; easyob-session.el ends here
