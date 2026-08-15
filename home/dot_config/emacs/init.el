;; Catppuccin Mocha — catppuccin-theme.el + catppuccin-definitions.el 1:1 aus
;; github.com/catppuccin/emacs (MIT), vendored in themes/ statt über MELPA
;; nachgeladen: kein Netzwerk-Dependency beim ersten Emacs-Start, gleiches
;; Prinzip wie bei den anderen Catppuccin-Themes in diesem Repo.
(add-to-list 'custom-theme-load-path
             (expand-file-name "themes" user-emacs-directory))

(setq catppuccin-flavor 'mocha)
(load-theme 'catppuccin t)
