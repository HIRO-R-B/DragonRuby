(require 'company)
(require 'cl-lib)
(require 'json)
(require 'request)

(defvar company-dragonruby--callback nil)
(defvar company-dragonruby--activated nil)

(defun company-dragonruby-get-code ()
  (format "
begin
  $result = $gtk.suggest_autocompletion index: %d, text: <<-S
%s
S
  $result = $result.join(\"\\n\")
rescue
  $result = ''
end
"
          (- (point) 1)
          (company-dragonruby-get-buffer (current-buffer))))

(defun company-dragonruby-get-buffer (buffer)
  (with-current-buffer buffer
    (save-restriction (widen)
                      (buffer-substring-no-properties (point-min) (point-max)))))

(defun company-dragonruby-async-post ()
  (request "http://localhost:9001/dragon/eval/"
    :type "POST"
    :data (json-encode `(("code" . ,(company-dragonruby-get-code))))
    :headers '(("Content-Type" . "application/json"))
    :parser 'buffer-string
    :success (cl-function
              (lambda (&key data &allow-other-keys)
                (let ((candidates (split-string (format "%s" data) "\n")))
                  (funcall company-dragonruby--callback candidates))))
    :error (cl-function
            (lambda (&rest args &key error-thrown &allow-other-keys)
              (message "Is DragonRuby open?")))))

(defun company-dragonruby-find-candidates ()
  "Get completion candidates"
  (company-dragonruby-async-post))

;;;###autoload
(defun company-dragonruby-on ()
  "Turns on company-dragonruby completions"
  (interactive)
  (setq company-dragonruby--activated t))

;;;###autoload
(defun company-dragonruby-off ()
  "Turns off company-dragonruby completions"
  (interactive)
  (setq company-dragonruby--activated nil))

;;;###autoload
(defun company-dragonruby (command &optional arg &rest _args)
  "Dragonruby backend for company-mode. By default it's off"
  (interactive (list 'interactive))
  (cl-case command
    (interactive (company-begin-backend 'company-dragonruby))
    (prefix (when company-dragonruby--activated
             (company-grab-symbol-cons "\\." 1)))
    (candidates (cons :async
                      (lambda (callback)
                        (setq company-dragonruby--callback callback)
                        (company-dragonruby-find-candidates))))))

(provide 'company-dragonruby)
