;;; easyob-exec.el --- Temp-file execution engine for easyob -*- lexical-binding: t; -*-

(require 'easyob-utils)
(require 'ob)

(defun easyob--execute-sync (command file-template tmp-src-file body
                                     filename-prefix processed-params params)
  (let* ((result (org-babel-eval command ""))
         (processed-file (easyob--expand-template file-template tmp-src-file body)))
    (unless (easyob--blank-p processed-file)
      (setq result processed-file))
    (when result
      (org-babel-reassemble-table
       (if (or (member "table" (cdr (assoc :result-params processed-params)))
               (member "vector" (cdr (assoc :result-params processed-params))))
           (let ((tmp-file (org-babel-temp-file filename-prefix)))
             (with-temp-file tmp-file (insert (org-babel-trim result)))
             (org-babel-import-elisp-from-file tmp-file))
         (org-babel-read (org-babel-trim result) t))
       (org-babel-pick-name (cdr (assoc :colname-names params)) (cdr (assoc :colnames params)))
       (org-babel-pick-name (cdr (assoc :rowname-names params)) (cdr (assoc :rownames params)))))))

(defun easyob--execute-async (command lang)
  (async-shell-command command
                       (concat "*org-babel-execute:" lang "*")
                       (concat "*org-babel-execute:" lang " Error !!!*")))

(provide 'easyob-exec)
;;; easyob-exec.el ends here
