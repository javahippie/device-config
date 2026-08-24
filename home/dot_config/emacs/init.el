;; Catppuccin Mocha — catppuccin-theme.el + catppuccin-definitions.el 1:1 aus
;; github.com/catppuccin/emacs (MIT), vendored in themes/ statt über MELPA
;; nachgeladen: kein Netzwerk-Dependency beim ersten Emacs-Start, gleiches
;; Prinzip wie bei den anderen Catppuccin-Themes in diesem Repo.
(add-to-list 'custom-theme-load-path
             (expand-file-name "themes" user-emacs-directory))

(setq catppuccin-flavor 'mocha)
(load-theme 'catppuccin t)

;; --- R (ESS) ---
;; ESS ist kein Fedora-Paket mehr (`dnf search emacs-ess` findet nichts) und kommt
;; aus GNU ELPA — dem Archiv, das Emacs 30 ohnehin kennt; MELPA bleibt aus.
;; Installiert wird es von bootstrap.sh nach ~/.config/emacs/elpa, damit der erste
;; Emacs-Start ohne Netz auskommt — derselbe Gedanke wie beim vendored Theme oben.
;; Geladen wird hier NICHTS: ESS bringt Autoloads mit, eine .R-Datei landet von
;; allein in ess-r-mode (nachgeprüft).
(setq ess-ask-for-ess-directory nil)   ; sonst fragt jedes M-x R erst nach dem Verzeichnis
(setq inferior-R-args "--no-save --no-restore")
;; ^ Kein stilles .RData. Ohne das fragt R beim Beenden nach dem Workspace und liest
;;   ihn beim nächsten Start wieder ein — eine unsichtbare Zustandsquelle, die
;;   Skripte laufen lässt, die frisch gestartet nicht laufen würden.

;; --- LaTeX (AUCTeX) ---
;; Kommt aus dem Fedora-Paket emacs-auctex und aktiviert sich SELBST über
;; /usr/share/emacs/site-lisp/site-start.d/auctex.el. Hier steht deshalb nur
;; Verhalten, kein Laden.
(setq TeX-auto-save t                  ; Parse-Ergebnisse in ./auto/ ablegen
      TeX-parse-self t)                ; beim Öffnen parsen: kennt danach \label, \cite, \ref
(setq-default TeX-master nil)          ; mehrteilige Dokumente: einmal nachfragen statt raten
;; latexmk statt eines einzelnen LaTeX-Laufs — es entscheidet selbst, wie oft LaTeX
;; und BibTeX laufen müssen, bis Referenzen und Literaturverzeichnis stehen.
;; Das MUSS in den Mode-Hook: LaTeX-mode setzt TeX-command-default in seinem eigenen
;; Rumpf auf "LaTeX" (latex.el:8306) und würde ein globales setq überschreiben.
(add-hook 'LaTeX-mode-hook (lambda () (setq TeX-command-default "LaTeXMk")))
;; RefTeX ist in Emacs eingebaut: \ref und \cite per Auswahl statt aus dem Kopf.
(add-hook 'LaTeX-mode-hook #'turn-on-reftex)
(setq reftex-plug-into-AUCTeX t)

;; PDF im Zathura statt in dem, was xdg-open gerade fuer application/pdf haelt
;; (hier: OnlyOffice). Zathura laedt bei jedem LaTeX-Lauf von allein neu und kann
;; SyncTeX in beide Richtungen — AUCTeX bringt den Eintrag samt Aufrufzeile mit.
(setq TeX-view-program-selection '((output-pdf "Zathura")
                                   (output-dvi "xdg-open")
                                   (output-html "xdg-open")))
;; SyncTeX: C-c C-v springt vom Cursor an die Stelle im PDF, und ein Klick im PDF
;; zurueck in die Quelle. Der Rueckweg laeuft ueber emacsclient, dafuer muss der
;; Emacs-Server laufen — Vorgabe von AUCTeX waere 'ask (fragt bei jedem Start).
(setq TeX-source-correlate-mode t
      TeX-source-correlate-start-server t)
