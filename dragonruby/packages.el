(defconst dragonruby-packages
  '(
    company
    (company-dragonruby :location local
                        :requires company)
    ))

(defun dragonruby/post-init-company ()
  (spacemacs|add-company-backends
    :backends company-dragonruby
    :modes ruby-mode))

(defun dragonruby/init-company-dragonruby ()
  (use-package company-dragonruby
    :defer t))
