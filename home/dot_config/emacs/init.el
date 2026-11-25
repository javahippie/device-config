;; Catppuccin Mocha — catppuccin-theme.el + catppuccin-definitions.el 1:1 aus
;; github.com/catppuccin/emacs (MIT), vendored in themes/ statt über MELPA
;; nachgeladen: kein Netzwerk-Dependency beim ersten Emacs-Start, gleiches
;; Prinzip wie bei den anderen Catppuccin-Themes in diesem Repo.
(add-to-list 'custom-theme-load-path
             (expand-file-name "themes" user-emacs-directory))

(setq catppuccin-flavor 'mocha)
(load-theme 'catppuccin t)

;; --- Maus im Terminal ---
;; emacs laeuft per Alias als `emacs -nw` in foot (s. dot_bashrc). Dort kommen
;; Klicks und Mausrad nur an, wenn Emacs sie beim Terminal anfordert — ohne das
;; ist z. B. Treemacs nicht klickbar. Kehrseite: foots eigene Textauswahl braucht
;; jetzt Shift beim Ziehen (Shift+Drag markiert und kopiert wie vorher).
(xterm-mouse-mode 1)

;; --- Zwischenablage im Terminal ---
;; Im TUI-Emacs bleibt der Kill Ring sonst in Emacs: C-w/M-w landen nicht in der
;; Wayland-Zwischenablage, und C-y holt nichts aus dem Browser. Die GUI-Variante
;; macht das selbst; hier uebernimmt es wl-clipboard (packages.txt).
;; wl-copy OHNE -n: das wuerde einen abschliessenden Zeilenumbruch abschneiden,
;; und eine kopierte ganze Zeile kaeme ohne ihn an.
(defun tz/wl-copy (text)
  (let ((proc (make-process :name "wl-copy" :command '("wl-copy")
                            :connection-type 'pipe :noquery t)))
    (process-send-string proc text)
    (process-send-eof proc)))

(defun tz/wl-paste ()
  ;; nil heisst fuer Emacs "nichts Neues von aussen" — so bei leerer Ablage, bei
  ;; einem Bild in der Ablage (-t text findet dann nichts) und wenn der Inhalt
  ;; ohnehin der eigene letzte Kill ist (sonst stuende er doppelt im Kill Ring).
  (with-temp-buffer
    (when (eq 0 (call-process "wl-paste" nil '(t nil) nil "-n" "-t" "text"))
      (let ((text (buffer-string)))
        (unless (or (string-empty-p text) (equal text (car kill-ring)))
          text)))))

(when (and (not (display-graphic-p))
           (getenv "WAYLAND_DISPLAY")
           (executable-find "wl-copy"))
  (setq interprogram-cut-function #'tz/wl-copy
        interprogram-paste-function #'tz/wl-paste))

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

;; --- Git (Magit) ---
;; Aus NonGNU ELPA (signiert), installiert von bootstrap.sh — Fedoras emacs-magit
;; waere 4.2.0 von Ende 2024 und darf NICHT parallel installiert sein, s. dort.
;; Geladen wird hier nichts: Magit bringt Autoloads mit und bindet ueber
;; magit-define-global-key-bindings von allein
;;   C-x g    magit-status     (Status-Puffer: s stage, c c commit, P p push)
;;   C-x M-g  magit-dispatch   (alle Befehle als Menue, auch ohne Status-Puffer)
;;   C-c M-g  magit-file-dispatch (Befehle zur Datei im aktuellen Puffer)
;; Commit-Nachrichten entstehen in einem Emacs-Puffer (with-editor), nicht in
;; einem externen $EDITOR — C-c C-c schliesst ab, C-c C-k bricht ab.

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
      treemacs-is-never-other-window t
      ;; Ein gespeichertes Projekt, dessen Verzeichnis es nicht mehr gibt, still
      ;; aus der Liste nehmen. Default 'ask haelt den Start mit einer Rueckfrage
      ;; im Minibuffer an ("Project ... cannot be read."), bevor der Baum
      ;; erscheint — so geschehen mit einem laengst geloeschten /tmp-Verzeichnis.
      treemacs-missing-project-action 'remove)

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

;; --- Clojure (clojure-mode + Paredit) ---
;; Beide aus NonGNU ELPA (signiert), installiert von bootstrap.sh — MELPA
;; haette sie auch, zieht dank package-archive-priorities aber nicht.
;; Geladen wird hier nichts: clojure-mode haengt .clj/.cljs/.cljc/.edn per
;; Autoload selbst in auto-mode-alist, paredit-mode ist ebenfalls ein Autoload.
;; Paredit haelt Klammern immer balanciert: ( fuegt () ein, C-) / C-} ziehen
;; den naechsten Ausdruck herein bzw. schieben ihn hinaus, M-s hebt eine
;; Klammerebene auf. Loeschen ueber eine Klammer hinweg geht nur mit C-u DEL.
(add-hook 'clojure-mode-hook #'enable-paredit-mode)
(add-hook 'emacs-lisp-mode-hook #'enable-paredit-mode)

;; --- Java (java-ts-mode + Eglot + jdtls + Maven) ---
;; Alles hier ist in Emacs 30 eingebaut (java-ts-mode, eglot, flymake, xref,
;; completion-preview, transient kommt mit Magit) — kein zusaetzliches Paket,
;; insbesondere NICHT lsp-mode/lsp-java/eglot-java, die alle nur auf MELPA
;; liegen. Von aussen kommen genau zwei Dinge:
;;   - die Tree-sitter-Grammatik: Fedora-Paket libtree-sitter-java (packages.txt),
;;     Emacs findet /usr/lib64/libtree-sitter-java.so.14 von allein,
;;   - der Language Server: Eclipse jdtls, von bootstrap.sh nach
;;     ~/.local/opt/jdtls/<version> gelegt (kein Fedora-Paket, nachgesehen).

;; java-mode (cc-mode, Regex-Faerbung) gegen die Tree-sitter-Variante tauschen.
;; Emacs 30 macht das nicht von allein, auch wenn die Grammatik da ist.
(add-to-list 'major-mode-remap-alist '(java-mode . java-ts-mode))

(defconst tz/jdtls-home (expand-file-name "~/.local/opt/jdtls/current"))
(defconst tz/jdt-source-dir (expand-file-name "~/.cache/jdtls/sources/")
  "Hierhin schreibt `tz/jdt-file-name-handler' Quellen aus JDK und Jars.")

(defun tz/java-runtimes ()
  "Alle JDKs aus SDKMAN und mise als jdtls-Runtimes, eins pro Hauptversion.
Liste von (MAJOR . PFAD), hoechste Version zuerst."
  (let (seen)
    (dolist (dir (append (file-expand-wildcards (expand-file-name "~/.sdkman/candidates/java/*"))
                         (file-expand-wildcards (expand-file-name "~/.local/share/mise/installs/java/*"))))
      ;; Beide Manager legen Symlinks (current, temurin-latest, temurin-25.0 ...)
      ;; neben die echten Verzeichnisse — truename + Hauptversion entdoppelt das.
      (let ((release (expand-file-name "release" dir)))
        (when (file-readable-p release)
          (with-temp-buffer
            (insert-file-contents release)
            (when (re-search-forward "^JAVA_VERSION=\"\\([0-9]+\\)" nil t)
              (let ((major (string-to-number (match-string 1))))
                (unless (assq major seen)
                  (push (cons major (file-truename dir)) seen))))))))
    (sort seen (lambda (a b) (> (car a) (car b))))))

(defun tz/jdtls-contact (_interactive project)
  "Startbefehl fuer jdtls, von Eglot pro Projekt aufgerufen."
  (let* ((root (directory-file-name (expand-file-name (project-root project))))
         ;; Der Wrapper bildet sein -data-Verzeichnis sonst aus dem BASENAME des
         ;; Arbeitsverzeichnisses (jdtls.py: sha1(basename(cwd))) — zwei Checkouts
         ;; namens "api" teilten sich dann einen Index. Hier: voller Pfad.
         (data (expand-file-name (format "~/.cache/jdtls/workspace/%s-%s"
                                         (file-name-nondirectory root)
                                         (substring (sha1 root) 0 8))))
         (runtimes (tz/java-runtimes))
         ;; jdtls selbst braucht Java >= 21. Nicht dem PATH/JAVA_HOME ueberlassen:
         ;; eine .sdkmanrc im Projekt kann dort ein Java 17 hinsetzen, und jdtls
         ;; bricht dann mit "requires at least Java 21" ab.
         (java (and runtimes (expand-file-name "bin/java" (cdar runtimes))))
         ;; Lombok: ohne den Agent meldet jdtls jeden Getter als "undefined".
         ;; Genommen wird das neueste Jar aus ~/.m2 — es liegt ohnehin dort,
         ;; sobald ein Projekt es benutzt.
         ;; expand-file-name ist noetig: file-expand-wildcards laesst die Tilde
         ;; stehen, und die JVM bricht an "-javaagent:~/..." ab (nachgemessen).
         ;; Sortiert wird nach dem Versionsverzeichnis: `version<' auf den
         ;; vollen Pfaden wirft "Invalid version syntax", sobald zwei Jars
         ;; da sind (so passiert am 26.10.).
         (lombok (car (last (sort (file-expand-wildcards
                                   (expand-file-name
                                    "~/.m2/repository/org/projectlombok/lombok/*/lombok-*[0-9].jar"))
                                  (lambda (a b)
                                    (version< (file-name-nondirectory (directory-file-name (file-name-directory a)))
                                              (file-name-nondirectory (directory-file-name (file-name-directory b))))))))))
    `(,(expand-file-name "bin/jdtls" tz/jdtls-home)
      ,@(when java (list (concat "--java-executable=" java)))
      ,@(when lombok (list (concat "--jvm-arg=-javaagent:" lombok)))
      "-data" ,data
      ;; classFileContentsSupport: Spruenge in JDK- und Bibliotheksklassen kommen
      ;; dann als jdt://-URI zurueck, die tz/jdt-file-name-handler aufloest.
      ;; Ohne das liefert M-. auf `String' schlicht nichts.
      :initializationOptions
      (:extendedClientCapabilities (:classFileContentsSupport t)
       :settings
       (:java (;; KEIN Autobuild: jdtls (intern Eclipse m2e) kompiliert sonst mit
               ;; ECJ in DASSELBE target/classes wie Maven — auch fehlerhafte
               ;; Klassen, als Stub mit "Unresolved compilation problem". Danach
               ;; haelt `mvn compile' alles fuer aktuell und meldet BUILD SUCCESS
               ;; trotz Fehler im Code (so passiert beim Testen am 19.10.).
               ;; Fehler in offenen Dateien meldet jdtls auch ohne Build; target/
               ;; gehoert damit allein Maven.
               :autobuild (:enabled :json-false)
               :configuration
               ;; Jede installierte Hauptversion als Runtime, damit ein Projekt
               ;; mit <release>25</release> gegen das JDK 25 statt gegen das
               ;; laufende 21 aufgeloest wird. Name muss "JavaSE-<n>" heissen.
               (:runtimes ,(vconcat
                            (mapcar (lambda (r) `(:name ,(format "JavaSE-%d" (car r))
                                                        :path ,(cdr r)))
                                    runtimes)))))))))

(with-eval-after-load 'eglot
  (add-to-list 'eglot-server-programs '((java-mode java-ts-mode) . tz/jdtls-contact))
  ;; jdtls importiert beim ersten Start das ganze Maven-Projekt; das dauert
  ;; laenger als die 30 s, nach denen Eglot sonst aufgibt.
  (setq eglot-connect-timeout 120)
  ;; jdtls ist sehr gespraechig; das Event-Log kostet sonst spuerbar Zeit.
  (setq eglot-events-buffer-config '(:size 0 :format full))
  ;; Letzten Puffer eines Projekts geschlossen -> jdtls beenden (je ~1 GB RAM).
  (setq eglot-autoshutdown t)
  (define-key eglot-mode-map (kbd "C-c l r") #'eglot-rename)
  (define-key eglot-mode-map (kbd "C-c l a") #'eglot-code-actions)
  (define-key eglot-mode-map (kbd "C-c l o") #'eglot-code-action-organize-imports)
  (define-key eglot-mode-map (kbd "C-c l f") #'eglot-format-buffer)
  (define-key eglot-mode-map (kbd "C-c l i") #'eglot-find-implementation)
  (define-key eglot-mode-map (kbd "C-c l d") #'eldoc-doc-buffer))

(with-eval-after-load 'flymake
  (define-key flymake-mode-map (kbd "M-n") #'flymake-goto-next-error)
  (define-key flymake-mode-map (kbd "M-p") #'flymake-goto-prev-error)
  (define-key flymake-mode-map (kbd "C-c l e") #'flymake-show-project-diagnostics))

;; jdt://-URIs: Ein Sprung nach `String' oder in eine Maven-Abhaengigkeit liefert
;; keinen Dateinamen, sondern jdt://contents/java.base/java.lang/String.class?...
;; Eglot reicht solche URIs bewusst unveraendert an file-name-handler-alist weiter
;; (eglot.el, eglot-uri-to-path, bug#58790). Der Handler hier holt den Quelltext
;; per java/classFileContents beim Server (bei Jars ohne Sources-Jar dekompiliert
;; jdtls selbst), legt ihn einmal unter tz/jdt-source-dir ab und laesst die
;; eigentliche Dateioperation auf DIESER Datei laufen.
(defvar tz/jdt--server nil
  "Zuletzt aktiver jdtls — fuer Spruenge aus Puffern, die keinen eigenen haben.")

(defun tz/jdt--materialize (uri)
  ;; Klassenname = letzter Pfadteil vor dem "?". Mit Sources-Jar (bzw. src.zip
  ;; beim JDK) endet er auf .java, sonst auf .class — beides kommt vor.
  (let* ((class (file-name-base (car (split-string (string-remove-prefix "jdt://" uri) "?"))))
         ;; Hash-Verzeichnis statt Paketpfad: dieselbe Klasse aus zwei JDKs oder
         ;; zwei Jar-Versionen sind zwei URIs, also zwei Dateien. Der Puffer
         ;; heisst trotzdem schlicht String.java.
         (file (expand-file-name (format "%s/%s.java" (substring (sha1 uri) 0 12) class)
                                 tz/jdt-source-dir)))
    (unless (file-exists-p file)
      (let ((server (or (eglot-current-server) tz/jdt--server)))
        (unless (and server (jsonrpc-running-p server))
          (error "Kein laufender jdtls fuer %s" uri))
        (let ((content (jsonrpc-request server :java/classFileContents (list :uri uri))))
          (make-directory (file-name-directory file) t)
          (let ((coding-system-for-write 'utf-8-unix))
            (with-temp-file file (insert (if (stringp content) content "")))))))
    file))

(defun tz/jdt-file-name-handler (operation &rest args)
  (let ((inhibit-file-name-handlers (cons #'tz/jdt-file-name-handler
                                          (and (eq inhibit-file-name-operation operation)
                                               inhibit-file-name-handlers)))
        (inhibit-file-name-operation operation))
    ;; Nur wenn das erste Argument die URI ist; bei (expand-file-name "x" "jdt://...")
    ;; o. ae. laeuft die Operation unveraendert.
    (if (and (stringp (car args)) (string-prefix-p "jdt://" (car args)))
        (apply operation (tz/jdt--materialize (car args)) (cdr args))
      (apply operation args))))

(add-to-list 'file-name-handler-alist '("\\`jdt://" . tz/jdt-file-name-handler))

(defun tz/java-setup ()
  (if (and buffer-file-name
           (string-prefix-p tz/jdt-source-dir (expand-file-name buffer-file-name)))
      ;; Abgelegte JDK-/Jar-Quelle: nur lesen, und KEIN eglot-ensure — Eglot
      ;; hielte ~/.cache/jdtls/sources fuer ein eigenes Projekt und startete
      ;; dafuer einen zweiten jdtls. Weiterspringen aus String.java geht damit
      ;; nicht; zurueck kommt man mit M-, wie gewohnt.
      (read-only-mode 1)
    (eglot-ensure))
  ;; Vorschlag des ersten Treffers grau hinter dem Cursor, TAB uebernimmt ihn.
  ;; Eingebaut seit Emacs 30 und, anders als corfu/company-Popups, auch in der
  ;; TUI ohne Zusatzpaket brauchbar. Die volle Liste gibt es mit C-M-i.
  (completion-preview-mode 1))
(add-hook 'java-ts-mode-hook #'tz/java-setup)

(add-hook 'eglot-managed-mode-hook
          (lambda ()
            (when (and (derived-mode-p 'java-ts-mode) (eglot-current-server))
              (setq tz/jdt--server (eglot-current-server)))))

;; --- Maven ---
;; C-c m oeffnet ein Transient-Menue (wie Magit) mit den ueblichen Zielen. Es
;; laeuft im naechsten Verzeichnis mit pom.xml ueber dem aktuellen Puffer — in
;; einem Multi-Modul-Projekt also im Modul, nicht im Reactor. Ausgabe kommt in
;; *maven* (compilation-mode): Compilerfehler "[ERROR] /pfad/X.java:[12,5]" sind
;; anklickbar (Emacs' eingebauter `maven'-Eintrag in compilation-error-regexp-alist),
;; M-g n / M-g p springen von Fehler zu Fehler, g im Puffer wiederholt den Lauf.
;; compile startet ueber ein pty, Maven sieht also ein Terminal und faerbt —
;; ohne den Filter stuende "Tests run: ^[[0;1;32m1^[[m" im Puffer. Gilt fuer
;; jeden compilation-Puffer, schadet bei farblosen Programmen nicht.
(add-hook 'compilation-filter-hook #'ansi-color-compilation-filter)
;; Der Puffer folgt der Ausgabe bis ans Ende — sonst steht man nach dem Lauf
;; oben und muss erst mit M-> hin. Nicht 'first-error: das haelt schon bei der
;; ersten Maven-[WARNING] mit Dateipfad an, also meist in den ersten Zeilen.
(setq compilation-scroll-output t)

(defvar tz/maven-program "mvn"
  "Maven-Kommando, wenn das Projekt kein ./mvnw mitbringt. Alternative: \"mvnd\".")

(defun tz/maven--dir ()
  (or (locate-dominating-file default-directory "pom.xml")
      (user-error "Kein pom.xml ueber %s" default-directory)))

(defun tz/maven--program (dir)
  ;; Ein Maven-Wrapper im Projekt (oder darueber, bei Modulen) gewinnt: er
  ;; pinnt die Maven-Version, mit der das Projekt gebaut werden will.
  (let ((wrapper-dir (locate-dominating-file dir "mvnw")))
    (if wrapper-dir
        (expand-file-name "mvnw" wrapper-dir)
      tz/maven-program)))

(defun tz/maven-run (goals)
  "GOALS (String) mit den Menue-Schaltern im naechsten Maven-Modul ausfuehren."
  (let* ((default-directory (tz/maven--dir))
         ;; bound-and-true-p: per M-x direkt aufgerufen ist transient evtl. noch
         ;; gar nicht geladen; dann gibt es eben keine Schalter.
         (args (and (eq (bound-and-true-p transient-current-command) 'tz/maven)
                    (transient-args 'tz/maven)))
         ;; -ntp: kein seitenlanger Download-Fortschritt im *maven*-Puffer.
         (cmd (string-join (append (list (shell-quote-argument
                                          (tz/maven--program default-directory))
                                         "-ntp")
                                   args (list goals))
                           " ")))
    (save-some-buffers (not compilation-ask-about-save))
    (let ((process-environment (tz/maven--environment)))
      (compilation-start cmd nil (lambda (_) "*maven*")))))

(defun tz/maven--environment ()
  ;; Aus Sway (foot -e emacs) gestartet fehlt JAVA_HOME, weil .bashrc nie lief —
  ;; mvnw nimmt dann /usr/bin/java, Fedoras java-25-openjdk ohne -devel. Dem
  ;; fehlt lib/ct.sym, und javac bricht bei <release>17</release> mit
  ;; "Releaseversion 17 nicht unterstuetzt" ab (so passiert mit Operaton am
  ;; 19.10.). Dann wie im Terminal das SDKMAN-current, sonst das neueste JDK.
  (if (getenv "JAVA_HOME")
      process-environment
    (let ((jdk (if (file-directory-p "~/.sdkman/candidates/java/current")
                   (file-truename "~/.sdkman/candidates/java/current")
                 (cdar (tz/java-runtimes)))))
      (if jdk
          (cons (concat "JAVA_HOME=" jdk) process-environment)
        process-environment))))

(defun tz/maven--test-target (with-method)
  ;; Klasse = Dateiname (Konvention, und so erwartet es -Dtest auch fuer
  ;; @Nested-Klassen); Methode = die method_declaration um den Cursor, per
  ;; Tree-sitter statt per Regex.
  (unless (derived-mode-p 'java-ts-mode)
    (user-error "Kein Java-Puffer"))
  (let ((class (file-name-base buffer-file-name)))
    (if (not with-method)
        class
      (let ((node (treesit-parent-until
                   (treesit-node-at (point))
                   (lambda (n) (equal (treesit-node-type n) "method_declaration"))
                   t)))
        (unless node (user-error "Cursor steht in keiner Methode"))
        (concat class "#" (treesit-node-text
                           (treesit-node-child-by-field-name node "name") t))))))

(defun tz/maven--run-test (target)
  ;; Build-Cache aus: Operaton schaltet maven-build-cache-extension in
  ;; .mvn/maven.config ein, und deren Pruefsumme kennt -Dtest nicht — bei
  ;; unveraendertem Code hiess es "Skipping plugin execution (cached):
  ;; surefire:test", es lief also gar kein Test (nachgestellt am 19.10.).
  ;; Ohne die Extension ist die Property bedeutungslos.
  (tz/maven-run (format "test -Dmaven.build.cache.enabled=false -Dtest=%s -Dsurefire.failIfNoSpecifiedTests=false"
                        (shell-quote-argument target))))

(defun tz/maven-test-class ()
  (interactive)
  (tz/maven--run-test (tz/maven--test-target nil)))

(defun tz/maven-test-method ()
  (interactive)
  (tz/maven--run-test (tz/maven--test-target t)))

(defmacro tz/maven--goal (name goals)
  `(defun ,name () ,(format "mvn %s" goals) (interactive) (tz/maven-run ,goals)))
(tz/maven--goal tz/maven-compile "compile")
(tz/maven--goal tz/maven-test "test")
(tz/maven--goal tz/maven-package "package")
(tz/maven--goal tz/maven-verify "verify")
(tz/maven--goal tz/maven-install "install")
(tz/maven--goal tz/maven-clean "clean")
(tz/maven--goal tz/maven-clean-install "clean install")
(tz/maven--goal tz/maven-dependency-tree "dependency:tree")
(tz/maven--goal tz/maven-updates "versions:display-dependency-updates")

(defun tz/maven-rerun ()
  ;; Nicht das nackte `recompile': aus einem Java-Puffer heraus nimmt es
  ;; compile-command ("make -k") statt des letzten Laufs in *maven*.
  (interactive)
  (if (get-buffer "*maven*")
      (with-current-buffer "*maven*" (recompile))
    (user-error "Noch kein Maven-Lauf")))

(defun tz/maven-goals (goals)
  (interactive "sMaven-Ziele: ")
  (tz/maven-run goals))

;; Erst beim ersten C-c m laden — transient kommt aus ELPA (mit Magit) und
;; soll den Emacs-Start nicht verlaengern.
(autoload 'tz/maven "transient" nil t)
(with-eval-after-load 'transient
  (transient-define-prefix tz/maven ()
    "Maven im naechsten Modul mit pom.xml."
    ["Schalter"
     ("-o" "offline" "-o")
     ("-q" "nur Fehler ausgeben" "-q")
     ("-s" "Tests ueberspringen" "-DskipTests")
     ("-u" "Snapshots neu holen" "-U")]
    [["Build"
      ("c" "compile" tz/maven-compile)
      ("t" "test" tz/maven-test)
      ("p" "package" tz/maven-package)
      ("v" "verify" tz/maven-verify)
      ("i" "install" tz/maven-install)
      ("C" "clean" tz/maven-clean)
      ("I" "clean install" tz/maven-clean-install)]
     ["Tests"
      ("k" "diese Klasse" tz/maven-test-class)
      ("m" "diese Methode" tz/maven-test-method)
      ("g" "letzten Lauf wiederholen" tz/maven-rerun)]
     ["Sonstiges"
      ("d" "dependency:tree" tz/maven-dependency-tree)
      ("U" "Updates der Abhaengigkeiten" tz/maven-updates)
      ("e" "Ziele eingeben ..." tz/maven-goals)]]))
(global-set-key (kbd "C-c m") #'tz/maven)

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
