;;; easyob-exec.el --- Temp-file execution engine for easyob -*- lexical-binding: t; -*-

(require 'easyob-utils)
(require 'ob)

(defun easyob--execute-sync (command output-file-template tmp-src-file body
                             filename-prefix processed-params params)
  "Execute COMMAND synchronously and return the result.
COMMAND is a shell command string (after template expansion).
OUTPUT-FILE-TEMPLATE is the value of the :file header argument
\(possibly containing $FILE, $BODY, etc.) that will be expanded
into a concrete file path.  If non-blank, the result of the
execution is replaced by this file path (so that Org inserts a
file link instead of the command's stdout).
TMP-SRC-FILE is the temporary source file created for the block.
BODY is the processed source block content.
FILENAME-PREFIX is passed to `org-babel-temp-file' when converting
table/vector results.
PROCESSED-PARAMS is the alist of Org Babel parameters for the block,
after processing (contains :result-params, etc.).
PARAMS is the raw parameter alist (contains :colnames, :rownames, etc.).
Returns the final result string (which may be a file link)."
  (let* ((result (org-babel-eval command ""))
         (expanded-output-file (easyob--expand-placeholders output-file-template
                                                        tmp-src-file body)))
    (unless (easyob--blank-p expanded-output-file) ;; 当代码块的输出是文件的时候，结果就是这个文件
      (setq result expanded-output-file))
    (when result
      (org-babel-reassemble-table
       (if (or (member "table" (cdr (assoc :result-params processed-params)))
               (member "vector" (cdr (assoc :result-params processed-params))))
           (let ((tmp-file (org-babel-temp-file filename-prefix)))
             (with-temp-file tmp-file (insert (org-babel-trim result)))
             (org-babel-import-elisp-from-file tmp-file))
         (org-babel-read (org-babel-trim result) t))
       (org-babel-pick-name (cdr (assoc :colname-names params))
                            (cdr (assoc :colnames params)))
       (org-babel-pick-name (cdr (assoc :rowname-names params))
                            (cdr (assoc :rownames params)))))))

(defun easyob--execute-async (command lang)
  (async-shell-command command
                       (concat "*org-babel-execute:" lang "*")
                       (concat "*org-babel-execute:" lang " Error !!!*")))

(provide 'easyob-exec)
;;; easyob-exec.el ends here
