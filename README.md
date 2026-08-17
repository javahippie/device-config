# device-config

Reproduzierbares Setup: Fedora Minimal + Hyprland.
Erprobt auf dem Cube (Fedora 44, Hyprland 0.56 aus COPR), Book folgt später.
`bootstrap.sh` + `packages.txt` = Systemschicht, `home/` = chezmoi-Source.

## 0. Vorbereitung (ohne Zielhardware)

1. Fedora **Everything**-Netinstall-ISO: https://fedoraproject.org/everything/download
2. Auf USB-Stick: `sudo dd if=Fedora-Everything-netinst-x86_64-*.iso of=/dev/sdX bs=8M status=progress oflag=direct`

## 1. Installation (Anaconda)

- Softwareauswahl: Basisumgebung **"Fedora Custom Operating System"**
  (= Minimal auf dem Everything-Installer), rechte Spalte: NICHTS anhaken.
- Installationsziel: ganze NVMe, automatisch, Btrfs-Default, Bestand löschen.
- Netzwerk & Hostname: Hostname setzen (`cube` / `book`) — daran hängt
  die Monitor-Template-Weiche. Nachholen geht mit
  `sudo hostnamectl set-hostname cube`.
- Benutzer als Administrator anlegen, Root deaktiviert lassen.

## 2. Erster Boot (TTY)

```sh
sudo dnf install -y git chezmoi        # die zwei Handschritte vor dem Clone
git clone https://github.com/javahippie/device-config ~/sources/device-config
cd ~/sources/device-config
./bootstrap.sh        # COPR, Pakete, Flathub, SDKMAN, chezmoi-sourceDir
chezmoi apply
reboot
```

Nach dem Reboot kommt SDDM (s. "Login-Screen"). Dort einmalig die Session
**"Hyprland"** wählen — SDDM merkt sie sich danach, zusammen mit dem Benutzer.
TTY2 (Strg+Alt+F2) startet KEIN Hyprland — das ist der Debug-Ausgang.
Fällt SDDM aus, greift der Notfallpfad in `.bash_profile`: TTY1-Login startet
Hyprland dann wie früher direkt über den `start-hyprland`-Wrapper (0.53+
verlangt den — nackter `Hyprland`-Start lässt Session-Setup aus).

## 3. Verifikation

- `hyprctl configerrors` — sollte leer sein
- `systemctl --user status xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk`
  — alle drei `active`, keins `Dependency failed`
- Flatpak-Probe: eines installieren, Datei-Dialog öffnen
- `hyprctl monitors` — echte Namen in `monitors.conf.tmpl` eintragen, apply
- `pidof hypridle` — sollte laufen; nach 5 min Idle sperrt hyprlock automatisch
- `systemctl status sddm` — `active`, und der Greeter zeigt Catppuccin statt
  des grauen Werks-Themes
- `echo $PATH | tr : '\n' | grep local/bin` — muss `~/.local/bin` enthalten,
  sonst finden die Bindings `keylight`/`wallpaper` nicht (s. "Login-Screen")

## Gelernt auf echter Hardware (Fedora 44, August 2026)

- **Hyprland ist seit Fedora 43 aus den offiziellen Repos retired.**
  Quelle ist die COPR `ashbuk/Hyprland-Fedora` (Name strikt kleingeschrieben,
  falsche Schreibweise schlägt STILL fehl). bootstrap.sh richtet sie ein.
- **uwsm und hyprpolkitagent gibt es in F44 nicht.** Ersatz: Start über
  start-hyprland (bringt Session-/D-Bus-Setup mit) + mate-polkit als Agent.
  ABER: start-hyprland aktiviert NICHT `graphical-session.target`, wovon
  xdg-desktop-portal hart abhängt — siehe "Portale & Standardbrowser".
- **dnf5 bricht bei EINEM unbekannten Paketnamen die GANZE Transaktion ab** —
  ein toter Eintrag in packages.txt verhindert alle anderen Installationen.
- **Minimal Install hat weder flatpak noch tar** (SDKMAN braucht tar).
  Beides steht deshalb in packages.txt.
- **windowrule-Grammatik ist seit 0.53 komplett neu:** `match:class <regex>`
  plus Effekte mit Werten (`no_blur on`). windowrulev2 existiert nicht mehr.
- **.conf-Config wird mit Hyprland 0.57 entfernt** (Lua-Migration).
  Offenes TODO — Konverter: Hyprland-Repo Discussion #13115.
- Die ashbuk-COPR lässt Qt-GUI-Helfer (hyprland-qtutils/guiutils) bewusst
  weg — die Startup-Notiz dazu ist ignorierbar.

## Theming (Catppuccin Mocha)

- `hypr/mocha.conf` ist die einzige Quelle der Palette (Farbwerte aus dem
  offiziellen `catppuccin/hyprlock`-Theme) — gesourct von `hyprland.conf`
  UND direkt von `hyprlock.conf`, damit beide nie auseinanderlaufen.
  Sourcing-Reihenfolge in `hyprland.conf` ist wichtig: `mocha.conf` muss vor
  `base.conf`/`effects.conf` stehen, die seine Variablen referenzieren.
- Wallpaper: siehe eigenen Abschnitt weiter unten. `background_color` im
  `misc`-Block (base.conf) ist seitdem nicht mehr *das* Wallpaper, sondern der
  Fallback, wenn kein Bild gesetzt ist.
- Border-Farben (`col.active_border`/`col.inactive_border` in effects.conf)
  sind die einzige bewusste Ausnahme von "Deko ausschließlich in effects.conf
  via explizite Zeilen" — der Border ist so oder so da, nur die Farbe ändert sich.
- Waybar/mako/foot/fuzzel/btop: Farben aus den jeweiligen offiziellen
  `catppuccin/*`-Themes (Mauve-Akzent), Font ist überall `JetBrains Mono`
  (aus packages.txt) — **kein Nerd Font installiert**, deshalb bei
  Waybar-Icons/Glyphen aufpassen (aktuell text-only, siehe config.jsonc).
  `fontawesome-fonts-all` ist zwar installiert, wird aber aktuell nirgends
  referenziert.
- foot: Farbsektion heißt `[colors-dark]`, nicht `[colors]` — Letzteres ist
  deprecated und foot meckert das im laufenden Terminal an. `[colors-dark]`
  gilt automatisch als Default, solange `initial-color-theme` nicht auf
  `light` steht (steht es nicht, kein `[colors-light]` im Repo).
- btop: Theme-Datei liegt in `btop/themes/`, `btop.conf` referenziert sie
  nur per Namen (`color_theme`) — der Rest der btop-Config bleibt bewusst
  auf Werksdefaults, btop merged fehlende Keys selbst.
- Waybar-Workspaces: immer 1-6 sichtbar (auch leer), mit Mini-App-Icons pro
  laufendem Fenster. Icons sind Noto-Emoji statt der in geteilten Configs
  üblichen Nerd-Font-Glyphen (kein Nerd Font installiert, siehe oben).
  Die `class<...>`-Regeln in `window-rewrite` sind Vermutungen basierend auf
  den üblichen WM_CLASS-Werten — vor dem ersten Vertrauen mit
  `hyprctl clients` gegenprüfen und ggf. anpassen. Auf "book" (2 Monitore,
  `all-outputs:true`) zeigen aktuell BEIDE Bars dieselben 6 Buttons — falls
  unerwünscht, `persistent-workspaces` in `waybar/config.jsonc` auf
  Output-Namen aufteilen (siehe Waybar-Doku für `hyprland/workspaces`).
  Damit Waybars `persistent-workspaces` überhaupt greift, deklariert
  `rules.conf` die Workspaces 1-6 zusätzlich als `persistent:true` in
  Hyprland selbst.

## Wallpaper

**Die Bilder liegen bewusst NICHT im Repo**, sondern in `~/Pictures/wallpapers`.
Grund: das Repo ist public, und Wallpaper sind fast immer fremde Bilder mit
Lizenz dran. Preis dieser Entscheidung: auf einer frisch aufgesetzten Maschine
ist der Ordner leer, das ist der einzige Teil des Setups, der nicht
reproduzierbar ist. Bilder also selbst rüberkopieren (`rsync`, s. packages.txt).

**swaybg statt hyprpaper**, obwohl hyprpaper der "native" Weg wäre: hyprpaper
ist aus den Fedora-Repos raus (letzte Version F41), hyprland selbst F42 —
dieselbe Retire-Welle. swaybg ist regulär paketiert und damit
`dnf upgrade`-fähig, statt an der COPR zu hängen. swaybg hat kein IPC,
gewechselt wird per Prozess-Neustart; der Switcher startet den neuen Prozess vor
dem Abräumen des alten, sonst blitzt kurz die Hintergrundfarbe durch.

Switcher ist `dot_local/bin/wallpaper` (gleiche Bauart wie `keylight`):

```sh
wallpaper pick        # fuzzel-Auswahl — SUPER+SHIFT+W
wallpaper next        # nächstes Bild     — SUPER+ALT+W
wallpaper random
wallpaper clear       # zurück auf die flache Mocha-Base-Farbe
wallpaper status
```

Die Auswahl wird in `~/.local/state/wallpaper` gemerkt und beim Session-Start
per `exec-once = wallpaper restore` (base.conf) wieder gesetzt. Ist kein Bild
gemerkt, nimmt `restore` das erste im Ordner; ist der Ordner leer oder fehlt,
endet der Aufruf **still mit 0** — dann bleibt `background_color` stehen. Das
ist Absicht: eine frische Maschine soll deswegen keine Fehlerzeile im Log haben.

Für den Lockscreen gilt das NICHT — `hyprlock.conf` bleibt bei der flachen
Farbe. Wer dort auch ein Bild will, setzt in `background {}` einen
`path = ...` statt `color`; hyprlock kann sich das Bild aber nicht vom Switcher
holen, das wäre ein zweiter, manuell gepflegter Pfad.

## Audio-Ausgabegerät wechseln

`dot_local/bin/audio-out` — **Rechtsklick auf das `Vol`-Modul** der Waybar oder
`SUPER+A`. Linksklick auf das Modul schaltet weiterhin stumm.

```sh
audio-out          # = pick, fuzzel-Auswahl
audio-out list     # Geräte mit Node-IDs, aktives mit *
audio-out status
audio-out set 52
```

- **`pw-dump` + jq statt `wpctl status`**: `wpctl status` ist eine Baumansicht
  für Menschen, deren Format zwischen WirePlumber-Versionen wandern darf.
  `pw-dump` liefert JSON. Kostet `pipewire-utils` in packages.txt — eigenes
  Subpaket, das **nicht** mit `pipewire` mitkommt.
- Gesetzt wird trotzdem mit `wpctl set-default` (aus `wireplumber`): der
  unterstützte Weg, und die Wahl überlebt einen Reboot.
- `pactl` ist auf diesem System **nicht** zwangsläufig da — es kommt aus
  `pulseaudio-utils`, nicht aus `pipewire-pulseaudio`. Deshalb baut hier nichts
  darauf auf.
- Laufende Streams ohne fest gesetztes Ziel zieht WirePlumber beim Wechsel von
  selbst mit um (anders als klassisches PulseAudio, wo der Default nur für neue
  Streams galt). Bleibt eine App zurück, hat sie ein gepinntes Ziel — dann hilft
  nur, sie neu zu starten oder das Ziel per Mixer zu lösen.
- In der Auswahlliste steht die Node-ID hinten in Klammern. Das ist nicht
  Deko: zwei baugleiche Geräte hätten dieselbe Beschreibung und wären sonst
  nicht auseinanderzuhalten.

## Keybind-Übersicht

`SUPER+F1` oder der Klick auf **"Keys"** in der Waybar zeigt die Tastenbelegung
als durchsuchbares fuzzel-Popup (tippen filtert).

Der Witz daran: **Quelle ist `binds.conf` selbst.** `dot_local/bin/keybinds`
parst die Datei — Bindings *und* die `# --- Abschnitt ---`-Kommentare, aus denen
die Gliederung im Popup wird. Eine neue Bindung taucht damit automatisch auf.
Eine von Hand gepflegte Zweitliste wäre nach dem dritten neuen Binding falsch,
und das Repo hat mit `drift-check.sh` schon genug Meinung zu Abweichungen.

- Bewusst **nicht** `hyprctl binds -j`: das kennt zwar den Live-Zustand, liefert
  aber Modmasken statt Tastennamen und hat keine Abschnitte. Der Unterschied
  fällt nur auf, wenn man Bindings zur Laufzeit per `hyprctl keyword` ändert —
  die fehlen dann in der Übersicht.
- `$mod` wird beim Anzeigen zu `SUPER`, und `~/.local/bin/` fällt bei den
  eigenen Skripten weg, damit die Zeilen lesbar bleiben.
- **F1 statt des sonst üblichen `SUPER+/`**: der Slash liegt auf de-Layout
  hinter `SHIFT+7`, das Binding wäre also faktisch ein Dreifingergriff.
- Waybar-Modul ist `custom/keybinds`, Beschriftung **Text** ("Keys") wie der
  Rest der Bar — es ist weiterhin kein Nerd Font installiert.

## Screenshots

`dot_local/bin/screenshot`, vier Modi, alle über `Print`:

| Taste | Modus | Was |
|---|---|---|
| `Print` | `region` | Rechteck mit der Maus (slurp) |
| `SUPER`+`Print` | `window` | Fenster anklicken — slurp rastet auf die Kanten ein |
| `SHIFT`+`Print` | `screen` | Der Monitor der aktiven Workspace |
| `SUPER`+`SHIFT`+`Print` | `all` | Alle Monitore in ein Bild |

Jeder Modus **speichert und kopiert** — Datei nach `<XDG-Bilder>/Screenshots/`,
zusätzlich in die Zwischenablage. Getrennte Bindings für "nur kopieren" wären
nur mehr Tasten für dieselbe Entscheidung.

- Kein neues Paket für die Funktion selbst: `grim`, `slurp`, `jq` und
  `wl-clipboard` standen schon in packages.txt. Dazu kam nur `libnotify` für die
  Rückmeldung — mako ist der Anzeige-Daemon, der *Client* (`notify-send`) fehlt
  auf einem Minimal Install komplett. Ohne ihn kann kein Skript im Repo eine
  Notification schicken. Fehlt er trotzdem, bleibt das Skript still und macht
  den Screenshot ohne Meldung.
- **Kein grimblast** (hyprland-contrib): das hinge an derselben COPR wie
  hyprland selbst, deren Inhalt hier niemand kontrolliert — dieselbe Überlegung
  wie bei hyprpaper/swaybg beim Wallpaper.
- Der Fenster-Modus listet über `hyprctl clients -j` nur die **sichtbaren
  Fenster der aktiven Workspace** (`mapped`, nicht `hidden`) und gibt deren
  Rechtecke an `slurp -r`. Damit rastet die Auswahl auf Fensterkanten ein,
  statt pixelgenaues Zielen zu verlangen.
- `screen` nutzt `grim -o <monitor>` statt Koordinaten aus `hyprctl monitors`:
  auf skalierten Monitoren fallen Pixel- und Logikmaße auseinander, `-o` lässt
  grim selbst rechnen.
- Der Dateiname hat Sekundenauflösung. Zwei Screenshots in derselben Sekunde
  überschreiben sich — praktisch nur mit gedrückt gehaltener Taste erreichbar.
- Vorher lag das als zwei Einzeiler direkt in `binds.conf`
  (`grim -g "$(slurp)" - | wl-copy`). Die Semantik von `SHIFT+Print` hat sich
  dabei geändert: früher alle Monitore, jetzt der aktive.

## Login-Screen (SDDM)

Ersetzt den früheren TTY1-Autostart. Der ist nicht weg, sondern zum Notfallpfad
geworden: `.bash_profile` startet Hyprland nur noch dann direkt, wenn
`sddm.service` **nicht** läuft — also wenn der Display-Manager kaputt ist. Damit
bleibt die alte "eine Komponente weniger"-Resilienz erhalten, ohne dass sich
beide Startwege ins Gehege kommen.

- `sddm` + `sddm-wayland-generic` (packages.txt). Das Subpaket steht explizit
  drin, damit die Wahl feststeht: `sddm` verlangt ein virtuelles
  `sddm-greeter-displayserver`, das auch `sddm-x11` erfüllen würde — dnf könnte
  sonst Xorg auf ein System ziehen, das keins hat.
- **Der Greeter läuft in weston, nicht in Hyprland.** `sddm-wayland-generic`
  enthält laut Fedora-Spec keine einzige Datei; es zieht nur weston rein und
  markiert die Displayserver-Wahl. Das ist die wichtigste Eigenschaft dieses
  Setups, weil daran der erste Anlauf gescheitert ist: in
  `/etc/sddm.conf.d/10-device-config.conf` stand
  `GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell` — richtig für
  einen wlroots-Compositor, tödlich für weston, das `wlr-layer-shell` nicht
  kann. Qt kam hoch (Locale-Warnung im Log), bekam keine Surface und war nach
  einer Sekunde weg: schwarzer Bildschirm, kein Input, im journal ausschließlich
  die PAM-Zeilen von `sddm-helper` und **keine** `sddm[…]`-Zeile.
  Die Datei setzt deshalb nur noch `[Theme] Current=`, alles andere macht
  Fedoras Default besser. Merksatz: Greeter-Umgebung ≠ Session-Umgebung.
- Theme: `catppuccin/sddm` in Mocha/Mauve, passend zum Rest. Kein Fedora-Paket,
  deshalb Release-Zip in bootstrap.sh — dasselbe Muster wie bei minikube, mit
  `[ -d ... ]` als Idempotenz-Guard. Version ist **gepinnt** (`v1.1.2`) statt
  `latest`, sonst ändert sich der Login-Screen bei jedem bootstrap-Lauf.
- Font-Anpassung (JetBrains Mono) landet in `theme.conf.user` neben der
  `theme.conf` des Themes — SDDM liest das als Override, ein Theme-Update
  überschreibt es nicht.
- **Keine eigene Session-Datei** — es gilt die aus dem COPR-Paket
  ("Hyprland" im Session-Menü des Greeters). Hier stand mal eine eigene mit
  `Exec=/bin/bash -lc "exec start-hyprland"`, die einen **Login-Loop** erzeugt
  hat: Session startet, stirbt sofort, Greeter kommt wieder. Zwei Denkfehler:
  `start-hyprland` ist der Wrapper für den **TTY**-Start (er macht das Session-
  und D-Bus-Setup, das es ohne Display-Manager sonst nicht gäbe) — unter SDDM
  erledigt das der Display-Manager bereits. Und Anführungszeichen im `Exec=`
  folgen der Desktop-Entry-Spec, nicht Shell-Quoting.
  Der Session-Log dazu steht **nicht** im journal, sondern in
  `~/.local/share/sddm/wayland-session.log` — die Datei ist bei Loops die
  einzige brauchbare Quelle.
- **`~/.local/bin` ist unter SDDM nicht im PATH**, weil die Session ohne
  Login-Shell startet. `keylight` und `wallpaper` werden deshalb in
  `binds.conf`/`base.conf` mit vollem Pfad aufgerufen (`~/.local/bin/...`,
  Hyprland führt `exec` über `/bin/sh -c` aus, die Tilde wird expandiert).
  Das ist der unangenehmste Unterschied zum TTY-Login und der Grund für den
  PATH-Check in §3.
- bootstrap.sh macht `systemctl enable sddm` bewusst **ohne** `--now`: das würde
  die gerade laufende TTY-Session abschießen. Greift also erst nach dem Reboot.

## Elgato-Hardware (Stream Deck, Key Light)

- **Stream Deck** → [OpenDeck](https://github.com/nekename/OpenDeck) (GPL-3.0,
  Flatpak `me.amankhanna.opendeck` in flatpaks.txt), spielt die meisten
  echten Elgato-Plugins ab, statt nur eine Mini-Reimplementierung zu sein.
  Braucht zusätzlich `udev/40-streamdeck.rules` (1:1 aus
  `OpenActionAPI/rust-elgato-streamdeck`, MIT) — bootstrap.sh installiert die
  nach `/etc/udev/rules.d/` und triggert einen Reload. Ohne die Regel sieht
  auch die Flatpak-Version kein Gerät (Flatpak kann USB/hidraw-Rechte nicht
  selbst herstellen). Nach dem ersten `bootstrap.sh`-Lauf Stream Deck einmal
  aus- und wieder einstecken.
- **Key Light** → kein GUI-Tool, sondern `~/.local/bin/keylight`
  (`home/dot_local/bin/executable_keylight`): spricht die undokumentierte,
  authfreie HTTP-API auf Port 9123 direkt an, nur mit curl+jq (schon in
  packages.txt) — kein neues Paket, kein Electron-Client.
  `keylight on|off|toggle|status|brightness N|temp KELVIN`.
  **Keine mDNS-Discovery** (bewusst simpel) — Host per `KEYLIGHT_HOST` oder
  `--host` setzen, sonst Default `keylight.local` im Script anpassen.
  Keybind: `$mod SHIFT, K` (`$mod, K` ist schon movefocus) toggelt.

## Portale & Standardbrowser

Drei Schichten, die alle stimmen müssen, damit z. B. Element/Cider bei
OAuth/SSO-Login einen Browser öffnen können. Von unten nach oben, in der
Reihenfolge, in der wir sie live debuggt haben:

- **1. `graphical-session.target` muss aktiv sein.** `xdg-desktop-portal.service`
  hat eine harte Dependency darauf — ohne die bleibt der komplette Portal-Dienst
  im Zustand `Dependency failed`, dauerhaft, egal was sonst stimmt. Ein
  Wayland-Compositor muss systemd explizit sagen "wir sind jetzt eine grafische
  Session"; das macht normalerweise uwsm, das es in F44 nicht gibt (siehe
  unten), und `start-hyprland` tut es NICHT. Fix: `systemd/user/hyprland-session.target`
  (1:1 aus dem [Hyprland-Wiki](https://wiki.hypr.land/Useful-Utilities/Systemd-start/)),
  gestartet per `exec-once` ganz am Anfang von `base.conf`. Kein Shutdown-Hook
  (bräuchte die Lua-Config, offenes TODO) — beim echten Logout räumt
  systemd --user sowieso alles ab.
  Diagnose: `systemctl --user status xdg-desktop-portal.service` — `Dependency
  failed` heißt exakt das hier. `systemctl --user cat hyprland-session.target`
  bestätigt, ob die Unit überhaupt ankam (nach `chezmoi apply` einmalig
  `systemctl --user daemon-reload` nötig, damit neue Units gefunden werden).
- **2. Activation-Environment muss `XDG_DATA_DIRS` enthalten.** Portal-Backends
  erben ihre Umgebung von der D-Bus-/systemd-Activation-Environment, NICHT von
  der Login-Shell. Betrifft `--user`-Flatpaks (Thunderbird, Cider, Element,
  Slack, Signal) — deren `.desktop`-Dateien liegen in
  `~/.local/share/flatpak/exports/share/applications/`; fehlt dieser Pfad in
  dem `XDG_DATA_DIRS`, das das Portal sieht, findet es die Datei nicht.
  `xdg-mime query default` fragt aber die *Login-Shell*, antwortet also trotzdem
  korrekt — das Auseinanderfallen macht den Fehler verwirrend. Fix: `base.conf`
  reicht `XDG_DATA_DIRS`/`PATH`/`XDG_SESSION_TYPE` explizit per
  `dbus-update-activation-environment` durch. Firefox selbst ist davon nicht
  mehr betroffen, seit es ein natives Paket ist (s. "Firefox: nativ statt
  Flatpak" unten) — für alle anderen Flatpaks bleibt es relevant.
  Diagnose: `echo "$XDG_DATA_DIRS"` vs. `systemctl --user show-environment |
  grep XDG_DATA_DIRS` — müssen die Flatpak-Exports enthalten und zueinander passen.
- **3. Ein Default-Handler muss registriert sein.** `~/.config/mimeapps.list`
  setzt Firefox für `http(s)`/`text/html`. Ohne DE-Ersteinrichtung setzt das
  sonst nie jemand.
  Diagnose: `xdg-mime query default x-scheme-handler/https` → `firefox.desktop`.

Portal-Call direkt testen, eine Zeile, ohne App dazwischen:

```sh
gdbus call --session --dest org.freedesktop.portal.Desktop --object-path /org/freedesktop/portal/desktop --method org.freedesktop.portal.OpenURI.OpenURI '' 'https://example.com' '{}'
```

Nach Änderungen an Punkt 1 oder 2 greifen bereits laufende Portale das NICHT
automatisch — neu starten oder neu einloggen:
`systemctl --user restart xdg-desktop-portal xdg-desktop-portal-gtk`.

## Container & Kubernetes (Podman, minikube)

Podman statt Docker: rootless per Default, in Fedoras eigenen Repos (Docker
braucht ein Drittanbieter-Repo), systemd-Integration nativ statt nachgerüstet.

- `podman` + `podman-compose` + `podman-docker` (packages.txt). Letzteres ist
  der `docker`-CLI-Kompat-Shim für Tools, die den Namen hardcoden.
- `passt` extra gelistet: liefert `pasta`, Podmans rootless-Netzwerk-Backend
  seit 5.0 — bei Minimal Install nur eine "Recommends"-Abhängigkeit, kommt
  also nicht sicher mit (gleiche Kategorie Fehler wie flatpak/tar, s.o.).
- `kubernetes-client` (packages.txt) liefert `kubectl`.
- `helm` (packages.txt) liefert Helm 3. Anders als minikube ist Helm ein
  normales Fedora-Repo-Paket — also dnf statt Binary-Download aus dem
  Install-Skript (`get-helm-3`), damit es `dnf upgrade` mitnimmt. Repos fügt
  man erst bei Bedarf hinzu, das ist Benutzerzustand unter
  `~/.config/helm/repositories.yaml` und bewusst nicht im Repo:
  ```sh
  helm repo add bitnami https://charts.bitnami.com/bitnami
  helm repo update
  ```
  Helm redet über dieselbe Kubeconfig wie `kubectl`, braucht für minikube also
  keine Extra-Konfiguration.
- `podman.socket` wird von bootstrap.sh aktiviert (`systemctl --user enable
  --now`) — Docker-API-kompatibler Socket unter
  `$XDG_RUNTIME_DIR/podman/podman.sock` für Tools, die einen echten
  `docker.sock` erwarten. Für die brauchst du zusätzlich
  `export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"` — absichtlich
  NICHT in `.bash_profile` gepackt (das ist laut eigenem Datei-Header nur für
  den Hyprland-Autostart da), sondern manuell in eine eigene `~/.bashrc`
  eintragen, falls gebraucht.

**minikube** ist kein dnf-Paket — offizielle Empfehlung ist Binary-Download,
macht bootstrap.sh idempotent (`command -v minikube` als Guard). Podman-Treiber
gilt laut minikube-Doku noch als **experimental**.

```sh
minikube config set rootless true
minikube start --driver=podman --container-runtime=containerd
minikube status
kubectl get nodes
```

`--container-runtime=containerd` betrifft nur den Runtime *innerhalb* des
minikube-Node-Containers (von minikube selbst mitgebracht) — dafür ist auf dem
Host kein `containerd`-Paket nötig, nur Podman als Treiber.

Falls `minikube start` mit einem sudo-Fehler abbricht: der Podman-Treiber will
laut minikube-Doku standardmäßig passwortlos `sudo podman` können. Mit
`rootless true` (s. o.) umgeht man das — checken, ob es wirklich gegriffen hat:
`podman info | grep rootless`.

## Dev-Toolchain (SDKMAN + mise)

Zwei Versionsmanager, klar getrennt: **SDKMAN** für die JVM-Welt (Java/Maven/
mvnd, `dot_sdkmanrc`), **mise** für den Rest (Ruby/Node/...). Beide sind
bewusst KEINE dnf-Pakete für ihre verwalteten Sprachversionen selbst — nur die
Manager-Tools sind installiert, die Sprachversionen zieht man erst bei Bedarf.

- mise kommt über die COPR `jdxcode/mise` — laut mise-eigener Doku der
  empfohlene Weg für Fedora 41+ (Alternative wäre `curl https://mise.run/bash
  | sh`, aber das hätte NOCH ein curl-Bootstrap-Muster neben SDKMAN/minikube
  eingeführt; die COPR macht mise stattdessen zu einem stinknormalen,
  `dnf upgrade`-fähigen Paket).
- `~/.config/mise/config.toml` (aus dem Repo) setzt global `ruby=latest`,
  `node=lts` als HOME-Default — analog zu `dot_sdkmanrc`, ein `.mise.toml` im
  jeweiligen Projekt-Checkout gewinnt darüber.
- **Shell-Aktivierung ist NICHT Teil des Repos**, aus demselben Grund wie
  `DOCKER_HOST` oben: `~/.bashrc` wird hier nicht verwaltet. Einmalig von Hand:
  ```sh
  echo 'eval "$(mise activate bash)"' >> ~/.bashrc
  ```
  Danach neu einloggen (oder `~/.bashrc` neu sourcen), dann zieht
  `mise install` die in `config.toml` deklarierten Versionen.

## Firefox: nativ statt Flatpak

Einzige bewusste Ausnahme von "GUI nur Flatpak". Grund: KeePassXC-Browser
(die Extension) braucht Native Messaging, um mit dem laufenden KeePassXC zu
sprechen — startet also einen Host-Prozess von außerhalb der Sandbox. Flatpak
blockt das grundsätzlich; der kommende Standard-Fix dafür
(`xdg-native-messaging-proxy`, D-Bus-basiert) ist laut den offenen
KeePassXC-Issues dazu weder in Fedora paketiert noch in Firefox stabil
verfügbar — für heute keine Option. Der dokumentierte manuelle Workaround
(Wrapper-Skript + `flatpak override` in Firefox' Sandbox-Datenverzeichnis
gefrickelt) ist fragil und versionsabhängig genug, dass "einfach das native
Paket nehmen" die robustere Wahl war.

- `packages.txt`: `firefox` (dnf, kein COPR nötig — normales Fedora-Repo-Paket).
- `flatpaks.txt`: **kein** `org.mozilla.firefox` mehr.
- `mimeapps.list`: `firefox.desktop` statt `org.mozilla.firefox.desktop` —
  anderer Desktop-File-Name, weil natives Paket statt Flatpak-Export.
- Betrifft NUR Firefox. Thunderbird/Cider/Element/Slack/Signal bleiben
  Flatpak — für die gilt Punkt 2 aus "Portale & Standardbrowser" weiterhin.

## Betriebsmodus

- Ad-hoc `dnf install` ist erlaubt; was bleibt, wandert SOFORT in packages.txt.
- GUI-Apps nur als Flatpak (flatpaks.txt), außer Firefox (s. o.).
  Dev-Toolchain über SDKMAN/mise.
- Config-Änderungen enden immer im Repo: live editiert ⇒ `chezmoi re-add`.
- `./drift-check.sh` zeigt handinstallierte Pakete, die nicht im Repo stehen.
- Vor jedem Commit: `git status` + `git diff` (Repo ist public!). TODO: gitleaks-Hook.
