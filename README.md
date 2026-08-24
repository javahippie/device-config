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
  (Ausnahme: Waybar-Modul **`Wach`** aktiv, s. "Idle-Verhalten")
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

## Mikrofon-Rauschunterdrückung (RNNoise)

Immer an, für jedes Mikrofon, ohne dass eine App etwas davon wissen muss:
`dot_config/pipewire/pipewire.conf.d/99-rnnoise.conf` hängt eine
PipeWire-Filter-Chain mit dem RNNoise-LADSPA-Plugin in den Graphen. Ergebnis ist
eine virtuelle Quelle **"Mikrofon (RNNoise)"**, die WirePlumber als
Standard-Eingang wählt. Slack, Element, Firefox & Co. sehen nur noch die —
gefiltert wird also nicht pro App, sondern einmal zentral.

```sh
pw-metadata -n default | grep audio.source   # muss 'rnnoise_source' zeigen
pw-link -l | grep -B1 capture.rnnoise        # zeigt, an welchem echten Mikrofon der Filter hängt
```

- **Kein Fedora-Paket.** Das Repo-Paket `rnnoise` ist nur
  `/usr/lib64/librnnoise.so`, also die Bibliothek ohne Plugin-Wrapper; ein
  `noise-suppression-for-voice` gibt es in Fedora nicht (geprüft).
  bootstrap.sh holt deshalb das Release-Binary von werman/noise-suppression-for-voice
  nach `/usr/local/lib/ladspa` — gleiches Muster wie minikube und lazydocker,
  gepinnte Version plus SHA-256 (das Projekt liefert selbst keine
  `checksums.txt`, die Summe im Skript ist die des geprüften Assets und muss
  beim Versions-Bump mitwandern).
- **Kein EasyEffects.** Das kann RNNoise auch, ist aber eine GUI plus
  Hintergrunddienst und zieht auf diesem Minimal Install den kompletten
  Qt6/KF6-Stack nach. Die Filter-Chain ist eine Konfigurationsdatei und läuft
  im PipeWire-Prozess mit.
- **Drop-in statt kopierter `pipewire.conf`.** PipeWire merged
  `~/.config/pipewire/pipewire.conf.d/*.conf` in die System-Config. Eine
  vollständig kopierte `pipewire.conf` würde die Upstream-Defaults einfrieren.
- **`flags = [ nofail ]` ist Pflicht, kein Detail.** Scheitert ein Modul aus
  `context.modules`, beendet sich PipeWire komplett — ohne das Flag hätte eine
  Maschine, auf der `chezmoi apply` schon lief und bootstrap.sh noch nicht,
  **gar keinen Ton**. Mit nofail fehlt nur die virtuelle Quelle.
- **Keine Rückkopplung, obwohl die Aufnahmeseite dem Standard-Eingang folgt.**
  Die virtuelle Quelle ist ja selbst der Standard-Eingang. Filter-Chain setzt
  auf beide Knoten dieselbe `node.link-group`, und WirePlumber verlinkt einen
  Stream nie mit einem Ziel derselben link-group — der Filter greift sich also
  automatisch die bestbewertete *echte* Quelle.
- **`priority.session = 3000`** statt einmaligem `wpctl set-default`: die
  physischen Quellen liegen hier bei 1800-2100, damit gewinnt die virtuelle von
  allein — auch auf einer frisch installierten Maschine, ohne Handgriff.
- **`node.passive = true`** auf der Aufnahmeseite: sonst hält der Filter das
  Mikrofon dauerhaft offen (Aufnahme-LED an, "wird benutzt" in jeder App), auch
  wenn gerade niemand aufnimmt.
- **`wpctl status` listet die Quelle NICHT unter "Sources".** Knoten mit
  `node.link-group` landen dort in einem eigenen Block **"Filters"** — dort
  steht sie, mitsamt dem `*` für den Standard-Eingang. Unter "Sources" fehlt
  dann jede `*`-Markierung, was wie ein Fehler aussieht und keiner ist.
  Verlässlich ist `pw-metadata -n default`.
- **Welche echte Quelle der Filter greift, ist bei Gleichstand nicht
  deterministisch.** Scarlett 8i6 und das Kameramikrofon liegen beide bei
  `priority.session = 2100`; vor dieser Änderung war das Kameramikrofon
  Standard, der Filter hängt sich jetzt an die Scarlett. Wer ein bestimmtes
  Mikrofon will, muss es pinnen (s. letzter Punkt) — sonst kann ein Neustart
  die Wahl umdrehen.
- **Zu aggressiv oder zu lasch?** `"VAD Threshold (%)"` in der Config
  hochdrehen (Richtung 90) filtert mehr, schneidet aber leise Satzanfänge ab.
  Danach `systemctl --user restart pipewire.service` — ein bloßes
  `chezmoi apply` reicht nicht, die Config wird nur beim Start gelesen.
- **Welches echte Mikrofon gefiltert wird**, entscheidet weiterhin WirePlumber
  nach Priorität. Ein anderes erzwingen: `target.object` in `capture.props`
  auf den `node.name` des gewünschten Geräts setzen (`pw-dump` zeigt ihn).

## Idle-Verhalten und der `Wach`-Schalter

`hypridle.conf` fährt eine dreistufige Kette: **5 min** sperren
(`loginctl lock-session` → hyprlock), **5:30 min** Display aus,
**15 min** Suspend.

Das ist für den Alltag richtig und für lange Hintergrund-Jobs falsch — ein
Build, ein Export, ein `podman build`, ein großer Sync nach mailbox.org Drive.
Suspend nach 15 min unterbricht so etwas mitten drin.

Dafür sitzt links in der rechten Modulgruppe der Waybar ein Schalter:

| Anzeige | Farbe | Bedeutung |
| --- | --- | --- |
| `Idle` | gedämpft (`overlay1`) | Normalfall, volle Kette aus `hypridle.conf` |
| `Wach` | gelb | kein Lock, kein Display-Aus, kein Suspend |

Klick schaltet um, der Tooltip nennt den jeweils anderen Zustand.

**Wie es wirkt.** Das ist Waybars eingebautes `idle_inhibitor`-Modul, kein
eigenes Skript. Es hält einen `zwp_idle_inhibitor_v1` auf seiner eigenen
Layer-Surface; Hyprland stoppt daraufhin die `ext-idle-notify-v1`-Timer, und
aus genau denen speist hypridle seine drei Listener. hypridle wird also
**nicht gestoppt** — ihm wird die Uhr angehalten. `pidof hypridle` sieht
weiterhin alles normal, und `systemctl --user` bleibt außen vor. Beim
Zurückschalten laufen die Timer von vorn los, nicht an der Stelle weiter, an
der sie standen.

Zwei Konsequenzen, die man kennen sollte:

- **Der Zustand überlebt nichts.** `start-activated` ist absichtlich nicht
  gesetzt: Waybar-Neustart, Relogin oder Reboot schalten zurück auf `Idle`.
  Ein vergessener Inhibit, der einen Reboot übersteht, fällt sonst erst auf,
  wenn der Akku von "book" leer ist.
- **Manuelles Sperren geht weiter.** `SUPER+L` ruft hyprlock direkt auf und
  fragt keinen Inhibitor. Der Schalter unterdrückt nur das *automatische*
  Sperren.

Nicht genommen: `systemctl --user stop hypridle` per Custom-Modul. Das wäre
ein Zustand außerhalb der Bar (Unit gestoppt), der einen Absturz von Waybar
überlebt — und damit genau der vergessene Inhibit, den die Variante oben
vermeidet.

**Kein Keybind.** Der Schalter hat bewusst nur den Klick. Ein
Zwei-Zustands-Schalter ohne sichtbare Anzeige ist blind bedienbar, und
verlassen kann man sich darauf nur, wenn man die Anzeige sowieso ansieht.

## Suspend hängt sich auf (gelöst: kein s2idle-Fallback)

**Symptom.** Nach dem automatischen Suspend kommt der Rechner nicht zurück:
schwarzer Bildschirm, keine Reaktion auf Tastatur oder Maus, kein SSH-Login,
und der Power-Button am Gehäuse fährt ihn auch nicht herunter. Es bleibt der
harte Reset.

**Was tatsächlich passiert** (Journal vom 24.08.2026, Boot `-1`, ab 09:03:25 —
`journalctl -b -1` und dann nach `PM: suspend` suchen):

1. hypridle löst nach 15 min `systemctl suspend` aus. systemd probiert
   `SuspendState` der Reihe nach durch, per Default `mem standby freeze`.
   Erster Versuch `mem` = S3. Der Kernel bricht beim Einfrieren der CPUs ab:

   ```
   Disabling non-boot CPUs ...
   Wakeup pending. Abort CPU freeze
   Non-boot CPUs are not disabled
   ```

   Ein Wakeup-Event lag schon an. Für sich genommen harmlos — der Kernel rollt
   sauber zurück, der Rechner ist einfach wieder wach.

2. Weil `mem` einen Fehler zurückgibt, fällt systemd auf `freeze` = s2idle
   zurück. Die iGPU lehnt ab, das BIOS ist nicht dafür konfiguriert:

   ```
   amdgpu 0000:11:00.0: Power consumption will be higher as BIOS has not been
                        configured for suspend-to-idle.
   amdgpu 0000:11:00.0: [drm] *ERROR* Unsupported suspend state 1
   amdgpu 0000:11:00.0: PM: pci_pm_suspend(): amdgpu_pmops_suspend returns -22
   PM: Some devices failed to suspend, or early wake event detected
   ```

3. Beim Zurückrollen aus diesem halben s2idle antwortet die SMU der dGPU nicht
   mehr. Das ist der Punkt, an dem die Kiste stirbt:

   ```
   amdgpu 0000:03:00.0: SMU: No response msg_reg: 36 resp_reg: 0
   amdgpu 0000:03:00.0: RunDcBtc failed!
   amdgpu 0000:03:00.0: resume of IP block <smu> failed -62
   amdgpu 0000:03:00.0: amdgpu_device_ip_resume failed (-62).
   ```

4. Ab da läuft der `sdma0`-Ring der dGPU in einer Endlosschleife aus Timeout
   und Reset — alle zwei Sekunden, 70 Minuten lang, bis zum harten Reset:

   ```
   amdgpu 0000:03:00.0: ring sdma0 timeout, signaled seq=1594169, emitted seq=1594173
   amdgpu 0000:03:00.0: Starting sdma0 ring reset
   amdgpu 0000:03:00.0: Ring sdma0 reset succeeded
   amdgpu 0000:03:00.0: [drm] device wedged, but no recovery needed
   ```

**Warum auch SSH tot ist.** Ist es formal nicht. Kernel und Netzwerk laufen
weiter — im Journal kommt `enp13s0` mit 1 Gbps zurück, und der
`rclone-lambdaschmiede-refresh.timer` feuert um 10:13 noch sauber durch. Nur
hängt alles, was das Device anfasst, im Treiber fest; der Power-Button erzeugt
ein ACPI-Event, das logind auch erreicht, aber das Herunterfahren wartet auf
die Session, und die kommt nicht mehr. Von außen ist das nicht zu unterscheiden
von "Rechner ist weg".

**Der Fix.** Schritt 2 ist der einzige in der Kette, der nichts bringt: s2idle
kann dieses Board nicht, der Fallback kann also nur schaden. Deshalb ein
Drop-in, geschrieben von `bootstrap.sh`:

```ini
# /etc/systemd/sleep.conf.d/10-device-config.conf
[Sleep]
SuspendState=mem
```

Damit endet Schritt 1 damit, dass der Rechner wach bleibt und es fünf Minuten
später erneut versucht. Prüfen mit:

```console
$ systemd-analyze cat-config systemd/sleep.conf | grep SuspendState
SuspendState=mem
```

**Nicht genommen:** `mem_sleep_default=deep` in der Kernel-Cmdline. Das setzt
nur, was `/sys/power/mem_sleep` ohnehin schon auf `[deep]` stehen hat, und
ändert an systemds Fallback-Liste genau nichts.

**Offen: der Auslöser in Schritt 1.** Das anliegende Wakeup-Event kommt
vermutlich von einem der beiden Funk-Empfänger, die als Wakeup-Quelle
freigeschaltet sind:

```console
$ for f in /sys/bus/usb/devices/*/power/wakeup; do
      [ "$(cat $f)" = enabled ] && echo "${f%/power/wakeup}: $(cat ${f%/power/wakeup}/product)"
  done
/sys/bus/usb/devices/1-5.4: USB Receiver
/sys/bus/usb/devices/3-2: Hama EWM-500
```

Eine zuckende Funkmaus reicht, um den Suspend genau im falschen Moment zu
kippen. Abschalten ließe sich das per udev-Regel (`ATTR{power/wakeup}="disabled"`),
der Preis wäre: aufwecken geht dann nur noch über den Power-Button. Solange der
Fallback weg ist, ist der abgebrochene Suspend folgenlos — deshalb bleibt es
vorerst so.

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

## R und LaTeX (Emacs statt RStudio)

R-Arbeit und TeX laufen beide in dem Emacs, der ohnehin im Repo steht. Installiert
wird dafür:

| Zweck | Paket | Herkunft |
|---|---|---|
| R-Interpreter | `R-core` | Fedora |
| CRAN-Pakete bauen | `R-core-devel` | Fedora |
| R in Emacs (ESS) | `ess` | **GNU ELPA**, via bootstrap.sh |
| LaTeX in Emacs | `emacs-auctex` | Fedora |
| TeX Live | `texlive-scheme-small` | Fedora |
| Build-Treiber | `latexmk` | Fedora |
| PDF-Ansicht mit SyncTeX | `zathura` + `zathura-pdf-mupdf` | Fedora |
| R Markdown / Quarto | `pandoc-cli` | Fedora |

**Warum kein RStudio.** Nicht aus Prinzip, sondern nach Prüfung: kein Fedora-Paket,
kein Flathub-Eintrag. Posit liefert ausschließlich ein **rhel9**-Electron-RPM,
340 MB gepackt, 1,4 GB installiert, mit eigener Chromium-Kopie. Technisch liefe es
hier: die deklarierten Abhängigkeiten sind mager (`/bin/sh`, `libxkbcommon-x11`,
`sqlite`), und `ldd` auf dem entpackten Binary meldet auf Fedora 44 **keine**
fehlende Bibliothek. Es scheitert am Bezugsweg — das RPM ist **unsigniert**
(`rpm -qpi` zeigt ein leeres `Signature`-Feld), ginge also nur per `--nogpgcheck`
plus gepinnter SHA-256 wie bei NetBeans, und dazu käme ein zweiter, an dnf
vorbeilaufender Update-Pfad. Emacs ist ohnehin da; ESS liefert dasselbe
Arbeitsmuster (Skriptpuffer plus lebende R-Konsole) ohne diesen Anhang.

**Bedienung, für Umsteiger von RStudio.**

- `M-x R` startet die R-Konsole in einem Puffer — das Gegenstück zum Console-Pane.
- Im `.R`-Puffer: `C-c C-r` sendet die Region, `C-c C-c` den Absatz bzw. die
  Funktion, `C-c C-b` die ganze Datei, `C-c C-z` springt zur Konsole und zurück.
- `C-c C-v` zeigt die Hilfe zum Objekt unter dem Cursor.
- LaTeX: `C-c C-c` startet latexmk, `C-c C-v` öffnet das PDF an der passenden
  Stelle; ein Klick im PDF springt zurück in die Quelle.

**Was man wissen muss, sonst hält man es für kaputt:**

- **ESS gibt es in Fedora nicht mehr** (`dnf search emacs-ess`: keine
  Übereinstimmung). Es kommt aus **GNU ELPA** — dem Archiv, das Emacs 30 ab Werk
  kennt; MELPA bleibt bewusst aus. GNU ELPA signiert, die Installation legt neben
  `ess-26.5.0/` eine `ess-26.5.0.signed`; das ersetzt die gepinnte Prüfsumme, die
  bei minikube & Co. nötig ist.
- **Die 14 Byte-Compile-Fehler beim ESS-Einbau sind normal.** Sie betreffen
  ausnahmslos Dateien unter `ess-26.5.0/test/`, denen der Testhelfer `etest` fehlt
  — der liegt nicht im ELPA-Tarball. Nichts davon wird zur Laufzeit geladen.
- **Emacs' XDG-Falle im bootstrap.** bootstrap.sh läuft VOR dem ersten
  `chezmoi apply`, `~/.config/emacs` existiert da also noch nicht. Emacs 30 nimmt
  dieses Verzeichnis aber nur, wenn es schon da ist, und fällt sonst auf
  `~/.emacs.d` zurück (nachgemessen: `emacs --batch --eval '(princ
  user-emacs-directory)'` mit und ohne das Verzeichnis). Deshalb setzt der
  ESS-Schritt `package-user-dir` ausdrücklich — sonst landet ESS an einer Stelle,
  an der der spätere Emacs nie sucht.
- **`R-core` statt des Metapakets `R`.** `R` verlangt `R-devel`, das
  `R-java-devel`, und `R-java` verlangt `java-headless`. Damit stünde ein
  Fedora-JDK in `/usr/lib/jvm` neben den JDKs, die hier über SDKMAN verwaltet
  werden — genau die Doppelverwaltung, die `dot_sdkmanrc` vermeidet.
- **`texlive-scheme-small`, nicht `basic`.** `basic` fehlen `babel-german`,
  `hyphen-german`, `koma-script`, `biblatex` und `microtype` (einzeln geprüft) —
  ein deutschsprachiges Dokument trennt damit falsch. Gemessen als tatsächlicher
  Zuwachs (`dnf download --resolve`): basic 215 Pakete/451 MB, small 662/1193 MB,
  medium 1913/3503 MB, full 5104/9148 MB. Fehlt später ein Paket, ist das ein
  `dnf install texlive-<name>` und kein Schema-Wechsel.
- **Zwei Paketnamen, die man falsch rät:** der Build-Treiber heißt `latexmk`
  (nicht `texlive-latexmk`, das existiert in Fedora nicht und steckt in keinem
  Schema), und pandoc kommt aus `pandoc-cli` — `dnf install pandoc` findet nichts,
  obwohl das Kommando `pandoc` heißt.
- **`emacs --batch` ist zum Nachprüfen ungeeignet** und meldet für eine `.R`-Datei
  `fundamental-mode` — das sieht nach kaputtem ESS aus und ist keins. Im
  Batch-Modus aktiviert Emacs die Pakete nicht (`package-activated-list` ist leer,
  obwohl `package-enable-at-startup` auf `t` steht); die Autoloads existieren also
  gar nicht. Wer im Batch prüfen will, muss `(package-activate-all)` voranstellen —
  interaktiv passiert genau das beim Start von allein.
- **`zathura` allein zeigt nichts an.** Das Programm ist nur die Hülle, jedes
  Format kommt aus einem Plugin; ohne `zathura-pdf-mupdf` bleibt das Fenster leer.
- **AUCTeX lädt sich selbst** über
  `/usr/share/emacs/site-lisp/site-start.d/auctex.el`. In `init.el` steht deshalb
  nur Konfiguration und kein `require`.
- **`TeX-command-default` muss in den Mode-Hook.** `LaTeX-mode` setzt die Variable
  in seinem eigenen Rumpf auf `"LaTeX"` (`latex.el:8306`) und überschreibt damit
  jedes globale `setq` — der Umweg über den Hook ist kein Stilmittel.

**Grafikausgabe läuft über XWayland — und das ist kein Problem.** R bringt kein
Wayland-Device mit; `capabilities()` meldet `X11 TRUE, cairo TRUE`, das
Standardgerät ist X11. Auf dieser Hyprland-Sitzung getestet (`x11(); plot(1:3);
dev.off()` bei `DISPLAY=:0`): das Fenster geht auf, Xwayland läuft ohnehin
rootless mit. Wen das stört, schreibt mit `png()`/`pdf()` in eine Datei oder nimmt
`httpgd`, das im Browser rendert.

**Verifiziert nach der Installation** (Fedora 44, R 4.6.1, TeX Live 2026):
`M-x R` läuft, eine `.R`-Datei öffnet in `ess-r-mode`, AUCTeX ist geladen und
zeigt PDFs im Zathura. Ein deutschsprachiges KOMA-Dokument mit `babel` und
`microtype` übersetzt fehlerfrei; latexmk entschied dabei von allein, dass zwei
Läufe nötig sind (wegen `\ref`), und mit dem `--synctex=1`, das AUCTeX über `%S`
anhängt, entsteht die `.synctex.gz` für den Sprung ins PDF und zurück.

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

## Dateimanager (Double Commander)

Zwei-Fenster-Dateimanager in der Total-Commander-Tradition: zwei Panels
nebeneinander, das eine ist Quelle, das andere Ziel, und die Funktionstasten
machen die Arbeit — `F3` Betrachten, `F4` Bearbeiten, `F5` Kopieren, `F6`
Verschieben/Umbenennen, `F7` Ordner anlegen, `F8` Löschen. Dazu Tabs pro Panel,
Archive als begehbare Ordner, Mehrfach-Umbenennen, Verzeichnisvergleich und ein
eingebauter FTP/SFTP-Client. Start: **`SUPER+E`** (s. `binds.conf`).

### Warum ausgerechnet `doublecmd-qt6` — und warum das kein Detail ist

Fedora baut aus derselben Quelle **drei** Pakete, eins pro Widgetset. Sie
unterscheiden sich nicht kosmetisch, sondern darin, ob das Programm überhaupt
ein Wayland-Client ist:

| Paket | Toolkit | Binary | Wayland |
|---|---|---|---|
| `doublecmd-gtk` | GTK2 | **`/usr/bin/doublecmd`** | nein — nur `libX11` |
| `doublecmd-qt` | Qt5 | `/usr/bin/doublecmd-qt` | nein — kein `libwayland-client` |
| `doublecmd-qt6` | Qt6 | `/usr/bin/doublecmd-qt6` | **ja** |

Nachprüfbar ohne Installation:

```sh
dnf repoquery --requires doublecmd-qt6 | grep -e wayland -e X11
dnf repoquery --whatprovides /usr/bin/doublecmd     # → doublecmd-gtk
```

**Die Falle steckt in der zweiten Zeile.** Den naheliegenden Namen `doublecmd`
belegt ausgerechnet die GTK2-Variante — und GTK2 hat nie ein Wayland-Backend
bekommen, die läuft also zwangsweise über XWayland. Wer den Befehl tippt, den
er erwartet, bekommt genau die Version, die hier nicht taugt. Deshalb stehen
Paketname *und* Aufrufname sowohl in `packages.txt` als auch in `binds.conf`
und `mimeapps.list` ausgeschrieben mit `-qt6`.

Nur `doublecmd-qt6` linkt `libwayland-client.so.0` direkt; `qt6-qtwayland` steht
ohnehin schon in `packages.txt`. Kosten: 3 Pakete, 48 MB.

### Drag & Drop in Firefox-Upload-Felder

Das ist der eigentliche Grund für die Paketwahl. Firefox ist hier ein natives
dnf-Paket und läuft nativ auf Wayland (`hyprctl clients -j | grep xwayland` →
`false`). Ein Wayland-Client, der zieht, bietet die Auswahl per
`wl_data_device` als `text/uri-list` an — genau das nimmt ein
`<input type="file">` entgegen. Beide Seiten nativ, ein Protokoll, fertig.

Über XWayland müsste derselbe Drop durch Hyprlands XDND-Brücke im XWM
übersetzt werden. Die **existiert** — X11-nach-Wayland-DnD ist nicht
grundsätzlich unmöglich —, ist aber der bekannt fragile Weg. Die Qt6-Variante
umgeht sie vollständig, statt sich auf sie zu verlassen.

### Auf Hardware verifiziert (22.08.2026) — bis auf den Drop

Die Paketauswahl war aus den Abhängigkeiten hergeleitet; inzwischen ist sie
nachgemessen:

```sh
hyprctl clients -j | grep -iB4 -i doublecmd | grep -e class -e xwayland
```

- **`xwayland: false`** — bestätigt, `doublecmd-qt6` ist ein nativer
  Wayland-Client. Stünde dort `true`, hätte Qt6 trotz allem den xcb-Plugin
  genommen: dann ist `QT_QPA_PLATFORM` in der Umgebung gesetzt oder
  `qt6-qtwayland` fehlt. Erst das reparieren, nicht das Programm wechseln.
  NICHT verwechseln mit `QT_QPA_PLATFORMTHEME`, das wir sehr wohl setzen —
  das ist eine andere Variable (s. Dark Mode unten).
- **Fensterklasse** ist `doublecmd-qt6`, ebenfalls aus derselben Ausgabe. Sie
  gehört geprüft, bevor sie in `rules.conf` oder Waybars `window-rewrite`
  landet — dieselbe Regel wie bei allen anderen Klassen dort. Bisher ist
  bewusst keine Regel eingetragen: der Manager soll gekachelt laufen wie jedes
  andere Arbeitsfenster.
- **Der Drop selbst steht noch aus** — eine Datei aus einem Panel in ein
  Upload-Feld ziehen (z. B. auf einer beliebigen Seite mit Dateiauswahl). Das
  ist der Punkt, der eine Hand an der Maus braucht. Kommt die Datei nicht an,
  liegt es fast immer daran, dass das Fenster doch unter XWayland läuft — also
  zurück zu Punkt eins.
- **Notausgang**, falls die Qt6-Variante unter Wayland zickt (Popup-Menüs an
  falscher Stelle, Fenster ohne Position): `QT_QPA_PLATFORM=xcb doublecmd-qt6`
  erzwingt XWayland. Damit ist die App wieder benutzbar — aber der Drop geht
  dann über die Brücke oben, das ist ein Rückschritt, kein Fix.

### Dark Mode und Catppuccin

Double Commander hat unter Linux **keinen eigenen Dark Mode**. Die Optionsseite
dafür steckt zwar im Binary — `strings /usr/bin/doublecmd-qt6 | grep pgDarkMode`
findet sie neben `pgViewer`, `pgLog`, `pgDiffer` —, eingehängt wird sie aber nur
unter Windows. Im Kategorie-Dropdown unter *Konfigurieren → Optionen → Farben*
stehen hier fünf Einträge (Anzeige für freien Speicher, Schnellansicht,
Vergleichsansicht, Log, Verzeichnisse synchronisieren), und Dark Mode ist keiner
davon. Wer danach sucht, sucht vergeblich; das ist kein Fedora-Bug, das Formular
wird nur für alle Plattformen mitkompiliert.

Dunkel wird das Fenster deshalb über zwei getrennte Schichten.

**Schicht 1 — die Qt-Palette** (Menüleiste, Toolbar, Tab-Reiter, Dialoge).
Qt zieht sie aus einem Platform-Theme, und `libqgtk3.so` liegt unter
`/usr/lib64/qt6/plugins/platformthemes/` bereits da: sie gehört zu
`qt6-qtbase-gui`. **Kein zusätzliches Paket**, insbesondere kein `qt6ct` und
kein `adwaita-qt6`. Zwei Zeilen im Repo schalten das scharf:

- `env = QT_QPA_PLATFORMTHEME,gtk3` in `hypr/base.conf`
- `gtk-application-prefer-dark-theme = 1` in `dot_config/gtk-3.0/settings.ini`

Das färbt die Panels gleich mit: DCs Panel-Farben stehen ab Werk auf
**symbolischen** Werten (im Dialog „Fenster" und „Voreingestellt", intern
`clWindow`/`clDefault`) und folgen damit der Palette. Ein dunkles Fenster gibt
es also schon, bevor eine einzige Farbe von Hand gesetzt ist.

Bewusst NICHT `GTK_THEME=Adwaita:dark` als Env-Variable: das ist laut GTK-Doku
ein Debug-Override, der jede andere Theme-Wahl übersteuert. `prefer-dark` ist
der vorgesehene Weg und deckt echte GTK-Programme gleich mit ab — passend zum
ohnehin gesetzten `color-scheme=prefer-dark` in dconf.

`QT_QPA_PLATFORMTHEME` steht zusätzlich in der Liste von
`dbus-update-activation-environment` in `base.conf`. Grund: DC startet nicht nur
über SUPER+E als Kind von Hyprland, sondern auch als Handler für
`inode/directory` (s. `mimeapps.list`) — dann startet ihn das Portal aus der
systemd-Activation-Environment heraus. Ohne den Eintrag käme er über die Taste
dunkel und über den Doppelklick hell hoch.

**Schicht 2 — was DC selbst zeichnet** (Dateilisten, Pfadleisten, Log, Differ,
Fortschrittsbalken, Baumansicht-Menü). Das liegt in `colors.json`, und dabei
sind drei Dinge unangenehm überraschend:

- **Das Zahlenformat.** Delphi-`TColor`, dezimal, Bytereihenfolge `$00BBGGRR` —
  also umgedreht gegenüber HTML. Mocha `base #1e1e2e` ist `3022366`, nicht
  `1973806`. Negative Werte sind die symbolischen Systemfarben von oben.
- **Es gibt zwei Styles**, `Light` und `Dark`, und die Auswahl ist unter Linux
  nicht bedienbar (s. o.). Nachgemessen mit einer Sonde — `BackColor` im
  Light-Style testweise auf Magenta, Fenster blieb dunkel —, greift bei dunkler
  Palette der `Dark`-Style. Nach welcher Regel genau, ist nirgends dokumentiert;
  deshalb stehen **beide** Styles auf Mocha.
- **Die Spaltenansicht färbt pro Spalte nach.** Sie ist die Default-Ansicht, und
  unter `ColumnSets → Columns` hat jede Spalte ihr eigenes `Background`,
  `TextColor`, `CursorColor` … Wer nur den `FilePanel`-Block setzt, ändert
  nichts Sichtbares. Dieselben Werte müssen dort noch einmal stehen.

Die Zuordnung folgt `fuzzel.ini`, damit DC nicht als einziges Fenster aus der
Reihe tanzt: Auswahl `surface2 #585b70`, Akzent und Cursor-Rahmen
`mauve #cba6f7`, markierte Dateien `yellow #f9e2af`, Text `text #cdd6f4` auf
`base`/`mantle` im Wechsel.

Was hier NICHT Catppuccin ist: die Fensterrahmen und Menüs selbst, die kommen
über GTK3 aus Adwaita-dark. Ein echtes Catppuccin-GTK-Theme wäre der nächste
Schritt und eine eigene Baustelle (Paket bauen oder vendorn) — der Kontrast
stimmt auch so.

### Konfiguration: die Farben getrackt, der Rest maschinenlokal

Hier stand früher, DC schreibe beim Beenden alle Dateien komplett neu, eine
getrackte Config wäre also Dauerrauschen in `chezmoi diff`. Für 1.2 stimmt das
nicht mehr — der flüchtige Teil ist in eigene Dateien ausgezogen:

| Datei | Inhalt | getrackt |
|---|---|---|
| `colors.json` | Farben beider Styles, Highlighter-Styles | **ja** |
| `doublecmd.xml` | Einstellungen, Fonts, Verhalten | nein |
| `tabs.xml` | offene Tabs je Panel | nein |
| `history.xml` | Pfad-Historie | nein |
| `session.ini` | Fenstergeometrie, je Auflösung | nein |
| `shortcuts.scf`, `multiarc.ini`, `pixmaps.*` | Tasten, Archiv-Backends, Icon-Cache | nein |

Nachgemessen mit `md5sum *` vor und nach einem vollständigen Start-/Beenden-
Zyklus ohne jeden Eingriff: **keine einzige Datei ändert sich**. Das Argument
gegen das Tracken ist damit weg, jedenfalls für die Farben.

Getrackt ist deshalb genau eine Datei, `dot_config/doublecmd/colors.json`. Sie
hat 3.400 Zeilen, weil DC die kompletten Syntax-Highlighter-Definitionen mit
hineinschreibt; interessant sind nur die Farbblöcke am Anfang jedes Styles. Das
ist der Preis dafür, dass `chezmoi apply` die Farben ohne Handschritt herstellt
und `chezmoi status` eine Abweichung überhaupt anzeigt — `drift-check.sh` hilft
hier nicht, das Skript vergleicht ausschließlich Pakete gegen `packages.txt`.

Der Rest bleibt bewusst draußen: Spaltenbreiten, Tabs, Geometrie und Historie
sind genau der Teil, der pro Gerät anders sein soll und darf.

**Beim Ändern beachten:** DC schreibt `colors.json` beim Beenden aus dem
Speicher. Wer die Datei bearbeitet und `chezmoi apply` laufen lässt, während DC
noch offen ist, verliert die Änderung beim nächsten Beenden — erst das Programm
schließen, dann anwenden.

### Aussortiert

- **Krusader** — dieselbe Gattung, sauber auf Qt6/KF6, Wayland-nativ. Zieht
  aber **76 Pakete** statt 3 nach (`dnf --assumeno install krusader` zeigt es),
  weil der komplette KF6-Unterbau mitkommt. Derselbe Einwand wie bei
  skanlite/skanpage in `flatpaks.txt`, nur mit noch klareren Zahlen.
- **Flatpak** — gibt es für Double Commander nicht (`flatpak search doublecmd`
  → nichts auf Flathub). Wäre auch der falsche Zuschnitt: eine Sandbox um das
  eine Programm zu legen, dessen Zweck der Zugriff auf *alle* Dateien ist,
  ergibt ein Loch mit App drumherum. Damit ist es die zweite bewusste Ausnahme
  von "GUI nur Flatpak" neben Firefox und KeePassXC.
- **`vifm` / `nnn`** (beide in Fedora) — Terminal-Manager, für den
  Tastatur-Workflow durchaus stärker. Scheiden hier aber an der
  Anforderung aus: aus einem Terminal-Programm heraus lässt sich nichts in ein
  Browser-Fenster ziehen. Das übliche Gegenmittel wäre ein Drag-Proxy wie
  `ripdrag`, und den gibt es in Fedora nicht (geprüft).
- **Thunar / Nemo** — paketiert und Wayland-tauglich, aber Ein-Fenster-Manager
  mit Baum links. Das ist die Gegenthese zu Total Commander, nicht eine
  Variante davon.

## mailbox.org Drive (Firmenfreigabe) unter ~/Dokumente/lambdaschmiede

Die Freigabe `lambdaschmiede` aus mailbox.org Drive hängt als FUSE-Mount im
Home. Kein Sync, keine zweite Kopie: was im Ordner liegt, liegt auf dem Server.

**Warum rclone.** OXDrive, der offizielle Client, gibt es nur für Windows,
macOS und Mobil — für Linux existiert schlicht keiner. Bleibt WebDAV, und dafür
gibt es zwei Wege: davfs2 (der klassische) und `rclone mount`. Es ist rclone
geworden, aus zwei Gründen. Erstens Rechte: davfs2 will einen fstab-Eintrag und
ein setuid-Bit auf `/sbin/mount.davfs` — root für etwas, das einem einzelnen
Benutzer gehört. rclone mountet per FUSE aus einer `systemd --user`-Unit, ganz
ohne Privilegierung. Zweitens Schreibverhalten: Office-Programme speichern nicht
in die Zieldatei, sondern schreiben eine Temp-Datei und benennen sie um. Über
davfs2 ist das ein Glücksspiel, `--vfs-cache-mode full` macht daraus lokale
Dateioperationen, die rclone danach hochlädt.

**Die URL ist der Stolperstein.** Die Doku von mailbox.org nennt

    https://dav.mailbox.org/servlet/webdav.infostore/

und das ist zwar der richtige Endpunkt, aber NICHT der Dateibaum — dort liegen
nur drei Knoten: `Userstore`, `Public infostore` und `Trash`. Die eigenen
Dateien hängen unter `Userstore/<Anzeigename>`, und der Anzeigename ist der aus
dem OX-Adressbuch, mit Komma: `Userstore/Zöller, Tim`. Freigaben liegen
woanders, nämlich unter `Public infostore/<Freigabename>` — hier also
`Public infostore/lambdaschmiede`. Wer das rät, rät falsch; einmal

    rclone lsd mailbox:

und man sieht es. Genau deshalb steht in `dot_config/rclone/rclone.conf` nur die
Wurzel-URL, und der Unterpfad kommt aus der env-Datei.

**Zugangsdaten liegen NICHT im Repo.** `~/.config/rclone/mailbox.env`, Modus
0600, wird von der Unit als `EnvironmentFile` gelesen und enthält Login,
Passwort und Pfad:

    RCLONE_CONFIG_MAILBOX_USER=tim.zoeller@lambdaschmiede.com
    RCLONE_CONFIG_MAILBOX_PASS=<obscured>
    MAILBOX_PATH="Public infostore/lambdaschmiede"

Das Passwort ist ein **Applikationspasswort** (Einstellungen → Sicherheit →
Applikationspasswörter), nicht das Kontopasswort: bei aktiver
Zwei-Faktor-Authentifizierung lehnt WebDAV das Kontopasswort ab. Erzeugt wird
der Wert mit `rclone obscure '<app-passwort>'` — das ist Verschleierung, keine
Verschlüsselung, umkehrbar mit `rclone reveal`. Deshalb 0600 und deshalb nicht
ins Repo. Der Login ist die Adresse auf der eigenen Domain, nicht die
@mailbox.org-Adresse. Die Anführungszeichen um `MAILBOX_PATH` sind Pflicht: der
Pfad enthält ein Leerzeichen, und ohne Quotes zerlegt jedes Shell-Sourcing der
Datei die Zeile (systemd selbst entfernt die Quotes wieder).

**Einrichtung auf einer weiteren Maschine** (`book`). Aus dem Repo kommt alles
außer dem Passwort — die Handarbeit besteht aus genau einer Datei:

1. Pakete `rclone` **und `fuse3`** (beide in `packages.txt`, also erledigt
   bootstrap.sh das). `fuse3` liefert den setuid-Helfer `fusermount3`, ohne den
   ein unprivilegierter Mount nicht geht; das rclone-RPM verlangt ihn nicht,
   s. Kommentar in `packages.txt`.
2. **Eigenes** Applikationspasswort in mailbox.org anlegen (Einstellungen →
   Sicherheit → Applikationspasswörter), nicht das vom `cube` mitbenutzen.
   Genau dafür sind sie da: eines pro Gerät, einzeln zurückziehbar, ohne die
   anderen Maschinen anzufassen. Das Kontopasswort geht nicht, s. o.
3. Die env-Datei anlegen — **das ist die einzige Stelle, an der das Passwort
   steht**, auf jeder Maschine neu:

        umask 077          # sonst entsteht die Datei mit 0644
        install -d ~/.config/rclone
        cat > ~/.config/rclone/mailbox.env <<'EOF'
        RCLONE_CONFIG_MAILBOX_USER=tim.zoeller@lambdaschmiede.com
        RCLONE_CONFIG_MAILBOX_PASS=
        MAILBOX_PATH="Public infostore/lambdaschmiede"
        EOF
        read -rs -p 'App-Passwort: ' PW; printf '%s' "$PW" | rclone obscure -; unset PW

   Den ausgegebenen Wert hinter `PASS=` eintragen. `read -rs` plus stdin statt
   `rclone obscure '<passwort>'`: so steht das Klartextpasswort weder in der
   Shell-History noch in der Prozessliste (`ps` zeigt argv jedem Benutzer).
   Der obscured Wert ist **nicht** maschinengebunden — bei jedem Aufruf kommt
   eine andere Zeichenkette heraus, aber jede davon lässt sich überall wieder
   auflösen. Er ist deshalb auch kein Schutz, sondern nur Verschleierung: die
   Datei gehört auf 0600 und nicht ins Repo.
4. `chezmoi apply` — bringt `rclone.conf` und die drei Units.
5. Einschalten:

        systemctl --user daemon-reload
        systemctl --user enable --now rclone-lambdaschmiede.service

   Bewusst Handarbeit und nicht in bootstrap.sh: das Skript läuft, bevor es die
   env-Datei gibt, und eine enabled Unit ohne Zugangsdaten würde bei jedem
   Login in den Restart-Loop laufen. Den Auffrisch-Timer muss man **nicht**
   separat einschalten, den zieht die Mount-Unit mit hoch (s. u.).
6. Gegenprobe: `systemctl --user status rclone-lambdaschmiede.service`,
   `ls ~/Dokumente/lambdaschmiede` und
   `systemctl --user list-timers rclone-lambdaschmiede-refresh.timer`.

**Bedienung.**

    systemctl --user start rclone-lambdaschmiede.service    # mounten
    systemctl --user stop  rclone-lambdaschmiede.service    # aushängen
    systemctl --user status rclone-lambdaschmiede.service   # inkl. rclone-Log
    systemctl --user start rclone-lambdaschmiede-refresh.service   # sofort auffrischen
    systemctl --user list-timers rclone-lambdaschmiede-refresh.timer

Die Unit ist `enable`d, der Mount kommt also mit dem Login. `Type=notify`:
systemd meldet die Unit erst als aktiv, wenn der Mount wirklich steht — nicht
schon beim Prozessstart.

**Neue Dateien kommen von allein rein.** WebDAV kennt keine
Change-Notification. `--poll-interval 0` ist deshalb keine Einstellungssache,
sondern die Feststellung, dass es nichts zu pollen gibt: von einer fremden
Änderung erfährt der Mount von sich aus erst, wenn der Verzeichnis-Cache
abgelaufen ist **und** jemand in den Ordner schaut. Genau das ist der Grund für
das zweite Unit-Paar:

    rclone-lambdaschmiede-refresh.timer     # Takt: 30 s nach dem Mount, dann alle 2 min
    rclone-lambdaschmiede-refresh.service   # rclone rc … vfs/refresh recursive=true

`vfs/refresh` liest den Verzeichnisbaum neu in den VFS-Cache — **Listings, keine
Dateiinhalte**, es wird also nichts heruntergeladen. Gemessen: ~3 s für den
ganzen Baum (229 Ordner). Weil das so billig ist, steht dort `recursive=true`
und nicht nur die oberste Ebene; sonst wären Unterordner weiterhin auf
Zufallstreffer angewiesen.

Damit ändert `--dir-cache-time` seine Rolle und steht jetzt auf **1 h** statt
1 min: den Cache frisch hält der Timer, die Cache-Dauer ist nur noch das
Sicherheitsnetz für den Fall, dass er nicht läuft. Nebenbei wird Blättern
schneller — es wird nicht mehr jede Minute beim Server nachgefragt.

Kommandiert wird der laufende rclone über seine **Remote Control**, und die
hängt an einem Unix-Socket in `$XDG_RUNTIME_DIR`
(`--rc-addr unix://%t/rclone-lambdaschmiede.sock`), nicht am Vorgabe-Port
`localhost:5572`. Der Unterschied ist nicht kosmetisch: ein TCP-Port ohne
Passwort steht **jedem** lokalen Prozess offen, und die rc-API kann weit mehr
als auffrischen. Beim Socket ist die Grenze `/run/user/<uid>` — das Verzeichnis
gehört dem Benutzer und ist 0700. Ein liegengebliebener Socket nach einem harten
Abschuss würde den nächsten Start blockieren, deshalb das
`ExecStartPre=-… rm -f` in der Unit.

Verdrahtet ist das Paar **ohne `enable`**: der Timer hat bewusst kein
`[Install]`. Der Mount zieht ihn per `Wants=` hoch, per `PartOf=` geht er mit
ihm wieder aus. Ein enabled Timer würde beim Login auch dann starten, wenn der
Mount gar nicht läuft, und dann alle 2 Minuten gegen einen nicht vorhandenen
Socket laufen.

**Was man wissen muss, sonst hält man es für kaputt:**

- **Schreiben wirkt verzögert.** Mit `--vfs-cache-mode full` landet ein
  `write()` zuerst im lokalen Cache; hochgeladen wird nach dem Schließen der
  Datei (`--vfs-write-back`, Vorgabe 5 s). Direkt nach dem Speichern ist die
  Datei serverseitig also noch nicht da. Gemessen: nach 5 s sichtbar.
- **Änderungen von außen brauchen ein paar Minuten** — den Takt gibt der
  Auffrisch-Timer (s. o.) vor, nicht rclone. Gemessen mit einer Datei, die am
  Mount vorbei direkt auf dem Server angelegt wurde: **155 s** bis sie im
  Ordner auftauchte, ohne jedes Zutun. Der Timer allein erklärt davon nur 2
  Minuten, der Rest ist Laufzeit des Durchlaufs plus der Dentry-Cache des
  Kernels — als Erwartung also eher „bis zu drei Minuten" als „exakt zwei".
  Wer nicht warten will:
  `systemctl --user start rclone-lambdaschmiede-refresh.service`. Ein `stop` +
  `start` des Mounts, wie es früher hier stand, ist dafür nicht mehr nötig.
- **Ein schon offenes Fenster merkt davon nichts.** Der Timer aktualisiert den
  Cache, aber ein FUSE-Mount schickt für serverseitige Änderungen keine
  inotify-Ereignisse — nachgeprüft mit `gio monitor` auf dem Mountpoint: die
  Datei taucht auf, ein Ereignis kommt nicht. Dateimanager und Dateidialoge
  hängen genau daran. Im Double Commander also `STRG+R`, sonst zeigt das Panel
  weiter den Stand von vorhin. Ein frisch geöffnetes Fenster ist immer aktuell.
- **Zeitstempel kann OX nicht.** Der WebDAV-Dienst ist ein Open-Xchange, kein
  Nextcloud/ownCloud: kein `X-OC-Mtime`, keine Hashes, deshalb `vendor = other`.
  rclone kann die mtime hochgeladener Dateien nicht setzen — serverseitig steht
  der Upload-Zeitpunkt. Für einen Mount egal, für jede Art von Sync-Vergleich
  über Kreuz nicht: Zeitvergleiche zwischen beiden Seiten sind hier wertlos.
- **Flatpaks sehen den Mount** — geprüft mit OnlyOffice. Das funktioniert, weil
  die App `filesystems=host` hat und der Mount beim Start der App schon steht.
  Ein Flatpak, das VOR dem Mount gestartet wurde, sieht den Ordner leer: die
  Sandbox bindet den Home-Baum beim Start ein, spätere Mounts wandern nicht
  nach. Kein Fehler, keine Meldung, nur ein leerer Dateidialog. Dann die App
  neu starten, nicht die Rechte suchen.
- `.drive` ist OX-Metadatenkram und per `--exclude` ausgeblendet. Es ist
  serverseitig weiterhin da, nur nicht im Mount sichtbar.
- **`error listing: directory not found` im Log heißt: jemand anders räumt
  gerade um.** Beobachtet, während OXDrive auf dem MacBook dieselbe Freigabe
  synchronisierte: die Auflistung von `Belege/2026` enthielt ein
  `Nachlieferungen/`, ein PROPFIND auf genau diesen href antwortete aber mit
  **404** (mit blankem `curl` nachgestellt, ohne rclone). Der Ordner war da
  schon nach `Belege/` verschoben — die Auflistung zeigte den alten Platz, die
  Namensauflösung kannte nur den neuen. Zwei Stunden später war der Eintrag von
  allein weg und der Lauf meldete wieder `"": "OK"`.
  Wichtig ist deshalb, was rclone dabei tut: der rekursive Lauf **bricht nicht
  ab**. Er meldet das eine Verzeichnis, frischt alles andere auf, `rclone rc`
  liefert Exit-Code 0, die Unit bleibt `success` — kein Grund, an der Unit zu
  drehen. Wer solche Zeilen sieht, sucht den Fehler also nicht hier, sondern
  fragt, welcher zweite Client gerade schreibt. Nicht dauerhaft per `--exclude`
  stummschalten: der nächste Umbau trifft einen anderen Ordner, und das
  Repo hätte dann Wissen über Inhalte, das es nichts angeht.

**Sackgassen (alle durchgespielt):**

- **Über die NAS statt direkt.** Naheliegend, weil die ASUSTOR ohnehin läuft und
  per NFS eingebunden ist — scheitert aber an ADM: *DataSync Center* (das den
  OneDrive-Ordner auf der NAS füttert) kann Google Drive, Dropbox, OneDrive und
  Yandex, aber **kein WebDAV**. WebDAV kann nur das *Cloud Backup Center*, und
  das ist einweg und terminbasiert, also Backup, kein Arbeitsordner.
  *Remote Sync* wiederum spricht ausschließlich rsync.
- **rclone in einem Container auf der NAS.** Ginge technisch — Docker CE 28.1.1
  ist als arm64-Build installiert, auch wenn die App-Central-Seite für
  „Docker Engine" ein x86-64-Paket zeigt und AS33 nicht in der Modellliste führt.
  Verworfen, weil der Mount hier ohnehin gebraucht wird und ein Sync auf die NAS
  eine zweite Kopie mit eigener Konfliktbehandlung wäre, ohne Gegenwert.
- **rclone-Binary + cron auf der NAS.** Statisches arm64-Binary wäre leichter als
  ein Container, aber ADMs crontab liegt unter `/var/spool/cron/crontabs/` und
  damit außerhalb von `/volume1` — Firmware-Updates setzen das zurück.
- **Vorsicht beim Probieren mit SSH auf die NAS:** ADM Defender arbeitet als
  Positivliste und sperrt zusätzlich nach wenigen Fehlversuchen. Die Kennung
  dafür ist der SSH-Banner `Not allowed at this time` noch vor der
  Authentifizierung. Erst die eigene IP in die Trusted List, dann probieren.

## Drucken & Scannen (Netzwerkgerät, treiberlos)

**Der Drucker selbst steht NICHT im Repo** — gleiche Begründung wie beim Key
Light und beim NFS-Mount: Geräte- und Netzinfo ist hostspezifisch (`book` am
anderen Standort druckt woanders), und dieses Repo ist public. Im Repo steht nur
die Maschinerie, die Warteschlange legt man einmal von Hand an.

Im Repo:

- `packages.txt`, Abschnitt *Drucken & Scannen*: `cups`, `cups-filters`,
  `cups-filters-driverless`, `cups-ipptool`, `avahi`, `avahi-tools`, `nss-mdns`,
  `sane-airscan`, `sane-backends`.
- `bootstrap.sh`: aktiviert `avahi-daemon.service` + `cups.service` und verdrahtet
  nss-mdns per `authselect enable-feature with-mdns4`.
- `flatpaks.txt`: `org.gnome.SimpleScan` als Scan-Frontend.
- `dot_local/share/flatpak/overrides/org.onlyoffice.desktopeditors`: cups-Socket
  für die Office-Sandbox (s. unten, das ist kein Detail).

### Warteschlange anlegen (einmalig, von Hand)

`driverless` liefert nur den DNS-SD-**Dienstnamen**, und der ist als
Diagnose-Ausgangspunkt unbrauchbar (s. Sackgassen unten). Die brauchbaren Daten
— echter Hostname, Port, Ressourcenpfad, unterstützte Formate — kommen aus
`ippfind`:

```sh
ippfind _ipp._tcp -x echo "{service_hostname}:{service_port} rp={txt_rp} pdl={txt_pdl}" \;
```

Auf dem cube (Brother DCP-L2540DN, August 2026):

```
BRN30055C75A454.local:631 rp=ipp/print pdl=application/octet-stream,image/urf,image/pwg-raster
```

`image/urf` in `pdl` ist die Zusage, dass `-m everywhere` funktionieren wird —
das ist AirPrint-Raster, und genau das erzeugt die everywhere-PPD. Steht da nur
`application/octet-stream`, wird es ein Treiberthema.

Dann anlegen:

```sh
sudo lpadmin -p buero -E -v ipp://BRN30055C75A454.local:631/ipp/print -m everywhere
sudo lpadmin -d buero                 # als Standarddrucker setzen
lpstat -v && echo TEST | lp -d buero
```

`-m everywhere` ist der eingebaute IPP-Everywhere-Treiber von CUPS 2.4: er fragt
die Fähigkeiten beim Gerät ab und baut die PPD daraus. Genau deshalb steht in
`packages.txt` kein `hplip`, kein `gutenprint`, kein Hersteller-RPM.

**Der Hostname, nicht die IP.** Das ist die Umkehrung der Key-Light-Regel, und
zwar mit Grund: Brother leitet den mDNS-Hostnamen aus der MAC ab
(`BRN<MAC>.local`) — der ist stabiler als jede DHCP-Lease und überlebt einen
IP-Wechsel, ohne dass die Queue angefasst werden muss. Beim Key Light gab es
diese Option nicht, weil dort gar kein mDNS eingerichtet war; hier ist nss-mdns
verdrahtet und `getent hosts BRN....local` löst auf. Wer die IP will, braucht
zwingend eine DHCP-Reservierung — sonst zeigt die Queue irgendwann ins Leere.

### Sackgassen (alle live durchgelaufen)

- **`ping` auf die `driverless`-URI ist kein Test.**
  `ipp://Brother%20DCP-L2540DN%20series._ipp._tcp.local/` ist ein
  DNS-SD-*Dienstinstanzname*, kein Hostname — den kann glibc prinzipiell nicht
  auflösen, egal wie gut nss-mdns eingerichtet ist. `ping` sagt dazu
  "Temporärer Fehler bei der Namensauflösung", was nach Netzproblem aussieht und
  keins ist. CUPS kommt mit der Form klar (es löst DNS-SD-URIs selbst auf),
  alles andere nicht. Der echte Hostname steht in `ippfind`s
  `{service_hostname}`.
- **Eine geratene IP kostet die ganze Queue.** `lpadmin -m everywhere` gegen eine
  tote Adresse scheitert mit `Host is down` — und danach ist die vorher
  funktionierende Queue *weg*, nicht etwa unverändert (`lpstat -v` sagt dann
  "Keine Druckziele hinzugefügt"). Die everywhere-PPD wird beim Anlegen live vom
  Gerät geholt; klappt das nicht, bleibt kein Ziel übrig. Also erst `ippfind`,
  dann `lpadmin`.
- **`(0 Datei(en))` in der `lp`-Ausgabe ist normal**, kein Fehler: `lp` zählt
  Datei-Argumente, und bei `echo TEST | lp` gibt es keine. Ob der Job durch ist,
  sagt `lpstat -W completed -o`.
- **„Drucker ist beschäftigt", und es passiert nichts.** `lpstat` zeigt
  ausschließlich, was CUPS denkt — hier stand die Queue auf `job-printing`,
  während das Gerät längst nichts mehr annahm. Der Zustand kommt vom Drucker,
  nicht vom Rechner, und nur er kann ihn beantworten:

  ```sh
  ipptool -tv ipp://BRN30055C75A454.local:631/ipp/print get-printer-attributes.test \
    | grep -E 'printer-state|printer-is-accepting|queued-job'
  ```

  Live gesehen: `printer-state = idle`, aber
  **`printer-is-accepting-jobs = false`** bei `queued-job-count = 1` und
  `printer-state-reasons = spool-area-full-report`. Der Brother hatte einen Job
  im EIGENEN Spool hängen (Rest der Fehlversuche gegen den falschen
  Ressourcenpfad) und lehnte seitdem alles ab. `spool-area-full-report` ist also
  NICHT die harmlose Dauermeldung, für die man sie wegen der `-report`-Endung
  hält — sie war hier die Ursache.

  Aufräumen ohne Stromstecker, per IPP. Erst die Job-ID vom Gerät holen
  (`which-jobs all` lehnt dieser Brother ab — Attribut weglassen, dann geht es):

  ```
  { OPERATION Get-Jobs
    GROUP operation-attributes-tag
    ATTR charset attributes-charset utf-8
    ATTR naturalLanguage attributes-natural-language en
    ATTR uri printer-uri $uri }
  ```

  dann dieselbe Datei mit `OPERATION Cancel-Job` plus `ATTR integer job-id <ID>`
  und `ATTR name requesting-user-name "<user>"`. Beides mit
  `ipptool -tv <uri> <datei>`. Nach ein paar Sekunden steht
  `printer-state-reasons = none` und `printer-is-accepting-jobs = true`, und die
  wartende CUPS-Queue läuft von allein weiter — kein erneutes `lp` nötig.

- **Nie an den falschen Ressourcenpfad senden.** Genau das hat den Spool
  verstopft. `ippfind`s `{txt_rp}` sagt `ipp/print`; alles andere (`/`, `/print`)
  nimmt der Drucker an und verdaut es nicht.

Wer lieber klickt: `http://localhost:631` — CUPS bringt seine Weboberfläche
selbst mit, deshalb ist kein `system-config-printer` im Repo. Administration
dort verlangt ein Konto aus `SystemGroup` (steht in `/etc/cups/cups-files.conf`).

**Firewall ist nie die Ursache.** Ausgehendes IPP braucht keine Regel, und die
Zone `public` hat `mdns` ab Werk offen (`/usr/lib/firewalld/zones/public.xml`,
geprüft). Wenn nichts gefunden wird, liegt es an `avahi-daemon` — der Dienst ist
auf einem Minimal Install nicht von allein an, das macht erst `bootstrap.sh`.
Gegenprobe eine Ebene tiefer: `avahi-browse -rt _ipp._tcp` (aus `avahi-tools`).

### Aus Flatpaks drucken — hier hört es sonst auf

Ein Flatpak ohne `--socket=cups` sieht `/run/cups/cups.sock` nicht und zeigt im
Druckdialog **keinen einzigen Drucker** an. Keine Fehlermeldung, keine leere
Liste mit Hinweis — einfach nichts. Stand hier (`flatpak info --show-permissions`):

| App | cups-Socket ab Werk |
| --- | --- |
| Thunderbird | ja |
| OnlyOffice | **nein** → Override im Repo |
| Element, Slack, Signal, Cider | nein (drucken hier niemand) |

Zwei Sackgassen, bevor man den Override probiert:

- `filesystems=host` (hat OnlyOffice) hilft **nicht**. `/run` ist davon nicht
  erfasst — das ist der Sinn der Trennung, nicht ein Versehen.
- Der Print-Portal von `xdg-desktop-portal-gtk` greift **nicht**. Den benutzt GTK
  automatisch, wenn es in einer Sandbox läuft; OnlyOffice ist Qt und redet direkt
  mit CUPS.

Der Override ist deshalb chezmoi-verwaltet statt ein `flatpak override`-Aufruf in
`bootstrap.sh`: es ist eine Konfigurationsdatei, und Konfiguration gehört in die
chezmoi-Schicht. Für eine weitere App analog eine Datei daneben legen —
Dateiname ist die App-ID, Inhalt `[Context]` + `sockets=cups;` (additiv, die
Werksrechte bleiben).

Prüfen nach `chezmoi apply`:

```sh
flatpak info --show-permissions org.onlyoffice.desktopeditors | grep sockets
```

### Scannen

Frontend ist der SimpleScan-Flatpak. Wichtig zu wissen: **er benutzt die
Host-Backends aus `packages.txt` nicht.** Das Manifest setzt
`SANE_CONFIG_DIR=/app/etc/sane.d`, er bringt seinen eigenen SANE-Stack mit. Den
Scanner findet er selbst, weil er `shared=network` und `org.freedesktop.Avahi=talk`
hat — Discovery passiert also in der Sandbox, nicht auf dem Host.

`sane-backends`/`sane-airscan` auf dem Host sind trotzdem richtig: das ist die
Diagnose-Ebene, gleiche Rolle wie `alsa-utils` beim Audio. Findet das Frontend
nichts, zuerst

```sh
scanimage -L          # sieht der Host das Gerät?
```

Antwortet der Host und das Flatpak nicht, ist es die Sandbox; antwortet auch der
Host nicht, ist es Netz/avahi — dann ist die Suche im Frontend Zeitverschwendung.

## Betriebsmodus

- Ad-hoc `dnf install` ist erlaubt; was bleibt, wandert SOFORT in packages.txt.
- GUI-Apps nur als Flatpak (flatpaks.txt), außer Firefox (s. o.).
  Dev-Toolchain über SDKMAN/mise.
- Config-Änderungen enden immer im Repo: live editiert ⇒ `chezmoi re-add`.
- `./drift-check.sh` zeigt handinstallierte Pakete, die nicht im Repo stehen.
- Vor jedem Commit: `git status` + `git diff` (Repo ist public!). TODO: gitleaks-Hook.
