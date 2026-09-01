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

;; --- Paket-Archive ---
;; GNU ELPA und NonGNU ELPA kennt Emacs 30 ab Werk und beide signieren; MELPA
;; kommt hier dazu und ist die EINZIGE Ausnahme von dieser Regel — treemacs
;; (weiter unten) liegt nirgends sonst.
;;
;; Die Prioritaeten sind kein Feinschliff, sondern der Grund, warum die Ausnahme
;; eine Ausnahme BLEIBT: MELPA versioniert nach Datum (20260812.1430) und schlaegt
;; damit jede GNU-ELPA-Version. Ohne diese Zeile waeren ess und markdown-mode beim
;; naechsten `package-install` still auf die unsignierten MELPA-Kopien gewechselt.
;; Mit ihr zieht MELPA nur fuer Pakete, die es sonst nirgends gibt — von treemacs'
;; acht Abhaengigkeiten kommen dadurch fuenf signiert aus GNU ELPA.
;; Dieselbe Liste steht in bootstrap.sh, und zwar notgedrungen: das Skript laeuft
;; VOR dem ersten `chezmoi apply`, diese Datei existiert dort noch nicht.
(add-to-list 'package-archives '("melpa" . "https://melpa.org/packages/") t)
(setq package-archive-priorities '(("gnu" . 10) ("nongnu" . 5) ("melpa" . 0)))

;; --- Treemacs ---
;; Dateibaum im Seitenfenster, aus MELPA (s. o.), installiert von bootstrap.sh.
;; Geladen wird hier nichts von Hand: treemacs bringt Autoloads mit, der Aufruf
;; im Hook unten zieht das Paket nach.
(setq treemacs-width 30
      ;; Beim Klick auf eine Datei den Baum NICHT verlassen-und-schliessen.
      treemacs-is-never-other-window t)

(defun tz/treemacs-open-at-startup ()
  "Treemacs oeffnen, ohne dabei etwas zu fragen, und den Fokus behalten."
  (let ((win (selected-window)))
    (require 'treemacs)
    (require 'project)
    ;; Der Workspace kommt normalerweise aus ~/.config/emacs/treemacs-persist.
    ;; Beim allerersten Start auf einer frischen Maschine gibt es die Datei nicht.
    (unless (treemacs-current-workspace)
      (treemacs--find-workspace))
    ;; Und ohne Projekt darin bleibt `treemacs' im Minibuffer mit "Project root:"
    ;; stehen — der Cursor sitzt dann beim ersten Start in einer Rueckfrage statt
    ;; in der Datei. Deshalb hier vorher eins eintragen, nicht-interaktiv:
    ;; das Projekt des aktuellen Buffers, sonst schlicht das Arbeitsverzeichnis.
    ;; (project-current) ohne Prompt-Argument fragt selbst auch nichts.
    (unless (treemacs-workspace->projects (treemacs-current-workspace))
      (let* ((pr (project-current))
             (root (directory-file-name
                    (expand-file-name (if pr (project-root pr) default-directory)))))
        (treemacs-do-add-project-to-workspace root (file-name-nondirectory root))))
    (treemacs)
    ;; Ohne das sitzt der Cursor nach dem Start im Baum statt in der Datei,
    ;; die man oeffnen wollte.
    (when (window-live-p win) (select-window win))))

;; emacs-startup-hook und nicht direkt hier: zum Zeitpunkt von init.el steht
;; weder das Fensterlayout noch die per Kommandozeile uebergebene Datei.
(add-hook 'emacs-startup-hook #'tz/treemacs-open-at-startup)

;; --- Markdown ---
;; markdown-mode ist kein Fedora-Paket (`dnf search emacs-markdown`: keine
;; Uebereinstimmung) und kommt aus NonGNU ELPA — neben GNU ELPA das zweite
;; Archiv, das Emacs 30 ab Werk kennt und das seine Pakete signiert (neben
;; markdown-mode-<ver>/ liegt eine .signed). MELPA bleibt also auch hier aus.
;; Installiert von bootstrap.sh nach ~/.config/emacs/elpa, damit der erste
;; Emacs-Start ohne Netz auskommt — derselbe Gedanke wie bei ESS oben.
;; Geladen wird hier NICHTS: markdown-mode bringt Autoloads mit, .md und
;; .markdown haengen sich selbst in auto-mode-alist (nachgeprueft).

;; Code in ```-Bloecken im jeweiligen Sprachmodus einfaerben statt alles
;; einheitlich als markdown-code-face. Default ist nil.
(setq markdown-fontify-code-blocks-natively t)

;; markdown-mode ruft zur Vorschau (C-c C-c p) per Default ein Programm namens
;; `markdown` auf — das gibt es hier nicht, der Aufruf scheitert wortlos.
;; pandoc ist ohnehin da (packages.txt, fuer R Markdown/Quarto).
(setq markdown-command "pandoc --from=markdown --to=html5 --standalone")

;; Weicher Umbruch am Fensterrand. Aendert die Datei NICHT, es wird nur anders
;; dargestellt — im Terminal sonst unangenehm, weil Prosa-Zeilen abgeschnitten
;; statt umgebrochen werden.
(add-hook 'markdown-mode-hook #'visual-line-mode)

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
