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

Nach dem Reboot: TTY1-Login startet Hyprland automatisch über den
`start-hyprland`-Wrapper (0.53+ verlangt den — nackter `Hyprland`-Start
lässt Session-Setup aus). Kein Display-Manager, bewusst.
TTY2 (Strg+Alt+F2) startet KEIN Hyprland — das ist der Debug-Ausgang.

## 3. Verifikation

- `hyprctl configerrors` — sollte leer sein
- `systemctl --user status xdg-desktop-portal xdg-desktop-portal-hyprland xdg-desktop-portal-gtk`
  — alle drei `active`, keins `Dependency failed`
- Flatpak-Probe: eines installieren, Datei-Dialog öffnen
- `hyprctl monitors` — echte Namen in `monitors.conf.tmpl` eintragen, apply
- `pidof hypridle` — sollte laufen; nach 5 min Idle sperrt hyprlock automatisch

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
- Wallpaper ist bewusst keine Bilddatei: `background_color` im `misc`-Block
  (base.conf) füllt den Hintergrund mit der flachen Mocha-Base-Farbe. Kein
  hyprpaper/swaybg, kein Binary im Repo — passt zum Deko-Nullpunkt-Prinzip
  aus effects.conf. Wer ein echtes Bild will: hyprpaper zu packages.txt,
  ein `exec-once` in base.conf, fertig.
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
