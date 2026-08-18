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
  `hyprctl clients` gegenprüfen und ggf. anpassen. Ausnahme: `ONLYOFFICE` ist
  auf dem cube live abgelesen und stimmt. Auf "book" (2 Monitore,
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

## Bluetooth

`dot_local/bin/bt` — Klick auf das **`BT`-Modul** der Waybar oder `SUPER+B`.
Auswahl verbindet ein getrenntes Gerät und trennt ein verbundenes.

```sh
bt              # = pick
bt list         # gekoppelte Geräte, verbundene mit *
bt status
bt on / bt off  # Adapter
```

- **Kein Zusatzpaket für BT-Audio.** Bluetooth ist in PipeWire einkompiliert
  (`bluez` ist BuildRequires im Fedora-Spec), und `pipewire-pulseaudio` ersetzt
  `pulseaudio-module-bluetooth` per `Obsoletes`. LDAC ist ebenfalls drin; ein
  `pipewire-codec-*` existiert in Fedora gar nicht. Es braucht nur `bluez`.
- `bluez` installiert die Unit, **aktiviert sie aber nicht** — bootstrap.sh macht
  `systemctl enable --now bluetooth.service`. Das `--now` ist hier gefahrlos
  (anders als bei sddm), der Dienst hängt an keiner Session.
- **Kein `blueman`.** Verbinden ist ein Zweizeiler im Picker, und ein
  GTK-Tray-Applet wäre eine zweite Ausnahme von "GUI nur als Flatpak" für einen
  Vorgang, den das Skript ohne neues Paket erledigt.
- **Koppeln geht mit `bt pair`** (Rechtsklick aufs BT-Modul, `SUPER+SHIFT+B`).
  Das war zuerst NICHT drin, mit der Begründung "koppelt man pro Gerät einmal,
  dafür lohnt keine Oberfläche". Falsch gedacht: von Hand heißt es, in einer
  Flut namenloser BLE-Privacy-Adressen die richtige MAC zu erraten — im Büro
  oder im Hotel praktisch unbrauchbar. Was `bt pair` deshalb erledigt:
  - **Scan auf BR/EDR statt LE.** Kopfhörer koppeln über klassisches
    Bluetooth; ein LE-Scan liefert vor allem namenlose, rotierende
    Privacy-Adressen von Handys und Uhren in der Umgebung. Der Filter wird
    explizit gesetzt, weil ein Rest-Filter aus einer früheren `bluetoothctl`-
    Sitzung sonst überlebt und man weiter auf dem falschen Transport sucht.
    Für reine BLE-Peripherie: `BT_TRANSPORT=auto bt pair`.
  - **Nur ungekoppelte Geräte**, nach Signalstärke sortiert — das eigene Gerät
    liegt beim Koppeln neben dem Rechner und steht damit oben. Angezeigt werden
    Name (aus `info` nachgeschlagen, nicht die MAC-Schreibweise aus `devices`),
    RSSI, Geräteklasse (`audio-card`, `phone`, …) und MAC.
  - **Agent registrieren.** Ohne `agent on` + `default-agent` scheitert jedes
    Pairing, das eine Bestätigung braucht. Der Agent lebt nur solange die
    `bluetoothctl`-Sitzung läuft, deshalb passiert alles — Agent, `pair`,
    `trust`, `connect` — in EINER Sitzung, deren stdin per `sleep` offen
    gehalten wird, bis das asynchrone Pairing durch ist.
  - **`trust` automatisch**, sonst muss jede spätere Verbindung neu bestätigt
    werden — und `bt pick` scheiterte scheinbar grundlos.
  - Bei Audiogeräten wird der neue bluez-Sink hinterher direkt als
    Standard-Ausgabe gesetzt (best effort, s. "Audio-Ausgabegerät wechseln").
- Schlägt das Koppeln fehl, fischt das Skript die `Failed`/`Error`-Zeile aus
  bluetoothctls Ausgabe und zeigt sie an, statt nur "hat nicht geklappt".
  Häufigster Grund neben dem fehlenden Agenten: das Geräteobjekt liegt aus einem
  früheren LE-Scan im Cache und bluez versucht über den falschen Transport zu
  koppeln. Dann hilft `bluetoothctl remove <MAC>` und ein neuer Versuch.
- Der Picker schaltet einen ausgeschalteten Adapter selbst ein — sonst gäbe es
  nur ein wortloses "connect failed".
- Den Verbindungszustand fragt das Skript nach der Auswahl **neu** ab, statt den
  Marker aus der angezeigten Zeile zu deuten: zwischen Anzeige und Klick kann
  sich ein Gerät verabschieden.
- `bluetuith` (TUI) ist **nicht** in Fedora paketiert, wäre also Go-Build oder
  COPR — bewusst nicht genommen.

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
  Keybind: `$mod SHIFT, K` (`$mod, K` ist schon movefocus) toggelt.
  - **Der Host steht NICHT im Repo.** Die IP des Lights ist interne Netzinfo,
    und dieses Repo ist public. Das Skript liest sie aus
    `~/.config/keylight.conf` — eine Zeile, von Hand angelegt, nicht von chezmoi
    verwaltet:
    ```sh
    echo 'KEYLIGHT_HOST=192.168.x.y' > ~/.config/keylight.conf
    ```
    Reihenfolge: `--host` > `$KEYLIGHT_HOST` > diese Datei. `~/.bashrc` wäre
    kein Weg: Hyprland führt `exec` über ein nicht-interaktives `/bin/sh` aus,
    und unter SDDM gibt es ohnehin keine Login-Shell.
  - **Keine mDNS-Discovery, und kein `keylight.local`-Default mehr.** Auf diesem
    System ist mDNS gar nicht aktiv (`resolvectl mdns` sagt für alle Links `no`,
    `nss-mdns` ist nicht installiert) — der Name hätte also nie aufgelöst. Wer
    `.local` will, braucht `avahi` + **`nss-mdns`** (letzteres ist der Teil, der
    glibcs Namensauflösung erweitert; avahi allein genügt nicht). Für ein Gerät
    an fester Wandposition ist eine DHCP-Reservierung die schlichtere Lösung.
  - Ohne konfigurierten Host **sagt das Skript das sofort**, statt in einen
    Timeout zu laufen — wichtig auf `book`, wo es kein Key Light gibt. Alle
    `curl`-Aufrufe sind auf `--connect-timeout 2 --max-time 5` gedeckelt, damit
    hinter dem Keybind nichts hängen bleibt.

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
- **`podman.service.d/override.conf` (aus dem Repo) setzt `--time=0`.**
  `podman system service` beendet sich sonst nach 5 Sekunden Inaktivität
  (Doku-Default) und wird bei Bedarf neu socket-aktiviert. Für Handbetrieb ist
  das gewollt, für **Testcontainers** nicht: das hält lange Verbindungen offen
  (Event-Stream, Wait-Strategien), und wenn der Dienst darunter verschwindet,
  reisst die Verbindung mitten in der Anfrage ab. Der Test scheitert dann mit
  `Container startup failed` und darunter `Datenübergabe unterbrochen (broken
  pipe)` — was nach einem Container-Problem aussieht, aber der Socket ist.
  Nach `chezmoi apply` nötig: `systemctl --user daemon-reload` und
  `systemctl --user restart podman.socket`.
- Weitere Testcontainers-Stolpersteine auf rootless Podman, falls der Timeout
  nicht die Ursache war: `TESTCONTAINERS_RYUK_DISABLED=true` (Ryuk bekommt den
  Socket rootless nicht eingehängt) und `TESTCONTAINERS_HOST_OVERRIDE=localhost`
  (Testcontainers leitet sonst die falsche Adresse zum Container her).
  Bewusst NICHT im Repo, solange sie nicht nachweislich gebraucht werden.
- `podman.socket` wird von bootstrap.sh aktiviert (`systemctl --user enable
  --now`) — Docker-API-kompatibler Socket unter
  `$XDG_RUNTIME_DIR/podman/podman.sock` für Tools, die einen echten
  `docker.sock` erwarten. Für die brauchst du zusätzlich
  `export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"` — absichtlich
  NICHT in `.bash_profile` gepackt (das ist laut eigenem Datei-Header nur für
  den Hyprland-Autostart da), sondern manuell in eine eigene `~/.bashrc`
  eintragen, falls gebraucht.

**lazydocker** ist ebenfalls kein Fedora-Paket (geprüft: 404 auf
packages.fedoraproject.org, lazygit übrigens auch nicht). bootstrap.sh holt
deshalb das Release-Binary nach `/usr/local/bin`, Version **gepinnt**, mit
`command -v` als Idempotenz-Guard — dasselbe Muster wie minikube. Ein
Unterschied: das Projekt liefert `checksums.txt`, und die wird auch geprüft.
Schlägt die Prüfsumme fehl, bricht der Bootstrap ab, statt eine kaputte Binary
zu installieren.

- **Ohne `DOCKER_HOST` findet lazydocker nichts.** Es spricht die Docker-API,
  die hier von `podman.socket` kommt; ohne die Variable sucht es
  `/var/run/docker.sock` ins Leere. Die Zeile gehört nach `~/.bashrc` und steht
  bewusst nicht im Repo (gleiche Begründung wie bei der mise-Aktivierung):
  ```sh
  export DOCKER_HOST="unix://$XDG_RUNTIME_DIR/podman/podman.sock"
  ```
  In Hyprlands `env =` wäre sie schlecht aufgehoben: dort wird `$XDG_RUNTIME_DIR`
  nicht expandiert, man müsste die UID hartkodieren.
- `dot_config/lazydocker/config.yml` (aus dem Repo) setzt
  `commandTemplates.dockerCompose` auf **`podman-compose`** — sonst ruft
  lazydocker `docker-compose` auf, das es hier nicht gibt. Ausserdem ein
  Zeitfenster für Logs (`since: 60m`), weil lazydocker sonst bei langlebigen
  Containern die komplette Historie einliest und beim Öffnen hängt.
  Schlüsselnamen gegenprüfen mit `lazydocker --config` (gibt die Default-Config
  aus).

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

## Office (OnlyOffice statt LibreOffice)

Die Suite ist `org.onlyoffice.desktopeditors` (Flatpak, s. flatpaks.txt) — die
Wahl fiel gegen LibreOffice, und zwar am Fenstermodell, nicht am Funktionsumfang:

- **LibreOffice ist ein Multi-Toplevel-Programm.** Start Center, jedes offene
  Dokument und jeder Dialog ("Speichern unter", "Optionen", "Suchen &
  Ersetzen") sind eigene Wayland-Toplevels. Ein Tiling-WM kachelt die alle
  gleichberechtigt ein — der Dialog schiebt das Dokument auf die halbe Breite.
- **Die naheliegende Gegenregel greift hier nicht.** Hyprland kann
  `windowrule = float, match:modal 1`, aber `modal` kommt aus dem Protokoll
  `xdg-dialog-v1`, und LibreOffices GTK3-Backend spricht das nicht. Über
  `match:class` sind Dialoge auch nicht zu fassen: sie erben die Klasse des
  Hauptfensters. Bliebe Matching auf Fenstertitel — lokalisiert, versionsabhängig,
  also genau die Sorte Regel, die still kaputtgeht.
- **OnlyOffice ist ein Ein-Fenster-Programm** mit Dokument-Tabs und in-App
  gerenderten Dialogen. Da ist nichts zu kacheln, also braucht es auch keine
  Regel in `rules.conf`. Zweiter Grund: die bessere Treue bei
  `.docx`/`.xlsx`/`.pptx`.
- **Preis:** ODF kann es, ist aber nicht seine Muttersprache; Base/Draw/Math
  haben kein Gegenstück. Wer die braucht, holt sich LibreOffice ad hoc dazu
  (`flatpak install --user flathub org.libreoffice.LibreOffice`) — und trägt es
  dann, wenn es bleibt, samt MIME-Defaults nach (s. Betriebsmodus).

**Fonts sind Teil der Formattreue**, deshalb stehen drei Font-Pakete in
packages.txt (`liberation-fonts-all`, `google-carlito-fonts`,
`google-crosextra-caladea-fonts`). Fehlt Calibri, ersetzt fontconfig es durch
irgendetwas mit anderen Buchstabenbreiten und die Seitenumbrüche eines fremden
Dokuments wandern. Metrik-kompatibel heißt: gleiche Breiten, gleicher Umbruch.
Die Pakete gehören auf den Host — Flatpak blendet Host-Fonts in die Sandbox ein,
nicht umgekehrt.

**MIME-Defaults**: OnlyOffice meldet in seiner `.desktop`-Datei ~70 Typen an,
darunter `application/pdf`, `text/plain` und `text/markdown`. Es wäre für die
hier der einzige registrierte Handler und würde damit automatisch gewinnen —
ein PDF-Anhang aus Thunderbird landete im Office statt in Firefox. `mimeapps.list`
setzt deshalb die Office-Formate explizit auf OnlyOffice und holt PDF (Firefox)
sowie plain/markdown (Emacs) explizit zurück.

Der Rückholer braucht dabei ZWEI Gruppen, und das ist der unintuitive Teil:
Fedoras `firefox.desktop` deklariert in `MimeType=` kein `application/pdf`
(nur html/xml/xhtml/mml + die http(s)-Scheme-Handler), `emacs.desktop` kein
`text/markdown` — beide können die Formate, sagen es nur nicht. Für glib reicht
`[Default Applications]` trotzdem, dessen Lookup
(`g_app_info_get_default_for_type_impl`) prüft nur die Existenz der
`.desktop`-Datei. Strengere Implementierungen filtern nach deklariertem Support
und fallen dann auf OnlyOffice zurück; `[Added Associations]` trägt die fehlende
Zuordnung genau dafür nach.

Diagnose, wenn ein Default nicht greift — die beiden Fragen unterscheiden sich:

```sh
gio mime application/pdf          # was Portal/Thunderbird tatsächlich benutzen (glib)
xdg-mime query default application/pdf   # xdg-utils, eigener Parser, kann abweichen
grep -n pdf ~/.config/mimeapps.list      # ist die Datei überhaupt appliziert?
```

Noch **nicht auf Hardware verifiziert** (Stand: Ersteintrag), beim ersten Start
mitprüfen:

```sh
flatpak run org.onlyoffice.desktopeditors     # startet es überhaupt
hyprctl clients | grep -iA2 -e class -e onlyoffice   # Klasse + xwayland: 0/1
xdg-mime query default application/vnd.openxmlformats-officedocument.wordprocessingml.document
xdg-mime query default application/pdf        # muss firefox.desktop bleiben
fc-list | grep -ci -e carlito -e caladea -e liberation
```

- **OnlyOffice läuft über XWayland** (`hyprctl clients` → `xwayland: 1`), und das
  ist der Normalzustand, kein Fehler: die App hat keinen Wayland-Support. Bei
  Upstream sind "Switch to native Wayland on Linux", "crashes on Wayland
  sessions due to XCB/X11 dependency" und "flatpak: Can't run on Wayland" offen.
  Dass die Flatpak `--socket=wayland` mitbringt, heißt nur, dass der Socket da
  wäre. **NICHT** `QT_QPA_PLATFORM=wayland` per `flatpak override` erzwingen —
  das bringt sie zum Absturz, statt sie nativ zu machen.
  Optisch kostet es hier nichts: beide Hosts stehen in `monitors.conf.tmpl` auf
  Scale `1`, und bei Scale 1 rendert XWayland pixelgenau. Erst wenn ein Monitor
  fraktional skaliert wird, wird die App unscharf — dann wäre
  `xwayland { force_zero_scaling = true }` plus `GDK_SCALE`/`QT_SCALE_FACTOR`
  der Weg, nicht der Platform-Switch.
- Die **Fensterklasse** kommt damit aus dem X11-`WM_CLASS` (die `.desktop`-Datei
  deklariert `StartupWMClass=ONLYOFFICE`). Vor einem Eintrag in Waybars
  `window-rewrite` (s. Theming) den echten Wert aus `hyprctl clients` nehmen —
  dieselbe Regel wie bei allen anderen Klassen dort.

## Claude Code: Sandbox (bubblewrap)

Claude Code kapselt seine Bash-Kommandos auf Linux mit **bubblewrap** und zwingt
den Netzverkehr durch einen lokalen Proxy — dafür stehen `bubblewrap` und
`socat` in packages.txt. Die Policy liegt als `claude/managed-settings.json` im
Repo, bootstrap.sh installiert sie nach `/etc/claude-code/managed-settings.json`.

**Warum managed statt `~/.claude/settings.json`:** in die Datei schreibt Claude
Code selbst (Theme, zuletzt genutzter Modus) — unter chezmoi wäre das ein
Drift-Generator, und `chezmoi re-add` würde Laufzeitzustand ins (public!) Repo
ziehen. Zweitens schlagen managed settings die Projekt-Settings: eine
`.claude/settings.json` in einem fremden Checkout kann die Sandbox nicht
aufweichen.

Die Policy schaltet die Sandbox **nur ein** und lässt sonst die Defaults stehen:

- `enabled: true` — Sandbox an.
- `autoAllowBashIfSandboxed: true` — keine Rückfrage für Kommandos, die
  innerhalb der Sandbox bleiben. Die Grenze zieht die Sandbox, nicht der Dialog.
  (Ist laut Claude Code ohnehin der Default; steht explizit da, damit ein
  geänderter Default hier nichts umkippt.)
- `allowUnsandboxedCommands: true` — Kommandos, die *nicht* in die Sandbox
  passen, sind nicht verboten, sondern fragen nach. Nötig, weil `git push` hier
  über SSH läuft (`git@github.com:...`) und die Sandbox nur proxy-fähiges
  HTTP(S) rauslässt; mit `false` könnte Claude in diesem Repo nie pushen.

Bewusst **nicht** gesetzt: Lese-/Schreib-Regeln auf Dateiebene
(`sandbox.filesystem.*`) und Domain-Allowlisten. Erst mal offen fahren, dann
sehen, was in der Praxis stört — nachziehen, wenn klar ist, was es kosten soll.

**Was die Defaults schon tun** (auf einer Linux-Kiste mit bubblewrap 0.11.1 mit
genau dieser Policy nachgemessen, auf der Zielhardware trotzdem gegenprüfen):

- Schreiben außerhalb des Workspace (`/etc`, `/tmp`) → `Read-only file system`.
  Schreibbar sind Arbeitsverzeichnis, `$TMPDIR` und `/tmp/claude`.
- Netz aus der Sandbox heraus ist zu, solange keine Domain freigegeben ist:
  `curl https://example.com` → Exit 7. Interaktiv fragt Claude nach einer
  Freigabe; im `-p`-Modus scheitert es kommentarlos.
- Lesen ist dagegen offen: `cat ~/.ssh/<datei>` liefert im Test Exit 0 samt
  Inhalt — die einzige Read-Deny per Default ist `~/.claude/ide`. Genau da würde
  eine `filesystem.denyRead`-Liste ansetzen (`~/.ssh`,
  `~/.claude/.credentials.json`, `~/.aws`), sobald der Bedarf feststeht.

**Grenzen — bewusst so:**

- Die Sandbox umfasst **nur Bash**. File-Tools, Hooks und MCP-Server laufen
  ungekapselt. Wer das schließen will, startet Claude unter `srt`
  (`@anthropic-ai/sandbox-runtime`) — hier absichtlich nicht verdrahtet.
- bubblewrap teilt den Host-Kernel. Gegen "Agent liest Dateien und schickt sie
  weg" hilft es; gegen einen Kernel-Exploit ist eine microVM nötig
  (`podman --runtime krun`), das wäre eine eigene Stufe.
- `podman.socket` läuft auf dieser Maschine. Wer ihn erreicht, startet einen
  Container mit `-v /:/host` und ist an bubblewrap vorbei — er steht deshalb
  nicht in `network.allowUnixSockets`, und das sollte auch so bleiben.
- **Claude Code selbst installiert dieses Repo nicht.** Offizieller Weg ist
  `curl -fsSL https://claude.ai/install.sh | bash` (Binary nach
  `~/.local/bin/claude`, aktualisiert sich selbst). Deshalb steht es nicht in
  bootstrap.sh: eine Version ließe sich nicht sinnvoll pinnen, das Muster von
  minikube/lazydocker passt nicht.

Nach `./bootstrap.sh`: in einer Claude-Session `/sandbox` aufrufen — der zeigt
den aktiven Zustand. Gegenprobe von Hand:

```sh
cat /etc/claude-code/managed-settings.json    # liegt die Policy?
rpm -q bubblewrap socat                       # sind die Pakete da?
```

## Betriebsmodus

- Ad-hoc `dnf install` ist erlaubt; was bleibt, wandert SOFORT in packages.txt.
- GUI-Apps nur als Flatpak (flatpaks.txt), außer Firefox (s. o.).
  Dev-Toolchain über SDKMAN/mise.
- Config-Änderungen enden immer im Repo: live editiert ⇒ `chezmoi re-add`.
- `./drift-check.sh` zeigt handinstallierte Pakete, die nicht im Repo stehen.
- Vor jedem Commit: `git status` + `git diff` (Repo ist public!). TODO: gitleaks-Hook.
