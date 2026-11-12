# device-config

Reproduzierbares Setup: Fedora Minimal + Sway.
Erprobt auf dem Cube (Fedora 44, Sway 1.11), Book folgt später.
Bis 10.09.2026 lief hier Hyprland — s. „Compositor: Sway".
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
**"Sway"** wählen — SDDM merkt sie sich danach, zusammen mit dem Benutzer.
TTY2 (Strg+Alt+F2) startet KEINEN Compositor — das ist der Debug-Ausgang.
Fällt SDDM aus, greift der Notfallpfad in `.bash_profile`: TTY1-Login startet
dann direkt `sway`. Kein Wrapper nötig — Sway macht sein Session- und
D-Bus-Setup selbst.

## 3. Verifikation

- `sway -C` — prüft die Konfiguration, ohne die Session anzufassen; sollte
  nichts melden
- `systemctl --user status xdg-desktop-portal xdg-desktop-portal-wlr xdg-desktop-portal-gtk`
  — alle drei `active`, keins `Dependency failed`
- Flatpak-Probe: eines installieren, Datei-Dialog öffnen
- `swaymsg -t get_outputs` — echte Namen in `sway/monitors.tmpl` eintragen, apply
- `pidof swayidle` — sollte laufen; nach 5 min Idle sperrt swaylock automatisch
  (Ausnahme: Waybar-Modul **`Wach`** aktiv, s. "Idle-Verhalten")
- `systemctl status sddm` — `active`, und der Greeter zeigt Catppuccin statt
  des grauen Werks-Themes
- `echo $PATH | tr : '\n' | grep local/bin` — muss `~/.local/bin` enthalten,
  sonst finden die Bindings `keylight`/`wallpaper` nicht (s. "Login-Screen")

## Gelernt auf echter Hardware (Fedora 44, August 2026)

- **dnf5 bricht bei EINEM unbekannten Paketnamen die GANZE Transaktion ab** —
  ein toter Eintrag in packages.txt verhindert alle anderen Installationen.
- **Minimal Install hat weder flatpak noch tar** (SDKMAN braucht tar).
  Beides steht deshalb in packages.txt.
- **Nichts aktiviert `graphical-session.target` von selbst**, und
  xdg-desktop-portal hängt hart davon ab. Deshalb gibt es
  `systemd/user/sway-session.target` — siehe "Portale & Standardbrowser".
- **Es gibt keinen schlanken Polkit-Agenten für wlroots-Sessions in F44.**
  Genommen: mate-polkit.
- Eine Handvoll Lektionen aus dieser Zeit betraf Hyprland selbst (die
  retirete COPR, die 0.53er windowrule-Grammatik, die anstehende
  Lua-Migration). Sie sind am 10.09.2026 mit Hyprland aus dem Repo
  gefallen — s. "Compositor: Sway".

## Theming (Catppuccin Mocha)

- Die Palette liegt in `sway/mocha` (als `set $name #rrggbb`) und noch einmal
  ausgeschrieben in `swaylock/config` (als `option=rrggbb`, ohne Raute — swaylock
  kennt keine Variablen und kein Include). Bis 13.09.2026 gab es dazu
  `hypr/mocha.conf` für hyprlock; die ist mit hyprlock gegangen, `kbdlight` liest
  seitdem `sway/mocha`. Farbwerte alle aus dem offiziellen `catppuccin/*`-Theme.
  Sourcing-Reihenfolge in `sway/config` ist wichtig: `mocha` muss vor `base`
  und `effects` stehen, die seine Variablen referenzieren.
- Wallpaper: siehe eigenen Abschnitt weiter unten. Die flache Farbe aus
  `output * bg` (`sway/monitors.tmpl`) ist nicht *das* Wallpaper, sondern der
  Fallback, wenn kein Bild gesetzt ist.
- Border-Farben (`client.focused`/`client.unfocused` in `sway/effects`)
  sind die einzige bewusste Ausnahme von "Deko ausschließlich in effects
  via explizite Zeilen" — der Border ist so oder so da, nur die Farbe ändert sich.
- Waybar/swaync/foot/fuzzel/btop: Farben aus den jeweiligen offiziellen
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
  `swaymsg -t get_tree` gegenprüfen und ggf. anpassen. Ausnahme: `ONLYOFFICE`
  ist auf dem cube live abgelesen und stimmt. Auf "book" (2 Monitore,
  `all-outputs:true`) zeigen aktuell BEIDE Bars dieselben 6 Buttons — falls
  unerwünscht, `persistent-workspaces` in `waybar/config.jsonc.tmpl` auf
  Output-Namen aufteilen (siehe Waybar-Doku für `sway/workspaces`).
  Ein Gegenstück in der Compositor-Konfiguration braucht es dafür nicht: das
  `sway/workspaces`-Modul erzeugt die leeren Buttons selbst.

## Wallpaper

**Die Bilder liegen bewusst NICHT im Repo**, sondern in `~/Pictures/wallpapers`.
Grund: das Repo ist public, und Wallpaper sind fast immer fremde Bilder mit
Lizenz dran. Preis dieser Entscheidung: auf einer frisch aufgesetzten Maschine
ist der Ordner leer, das ist der einzige Teil des Setups, der nicht
reproduzierbar ist. Bilder also selbst rüberkopieren (`rsync`, s. packages.txt).

**swaybg**, und das war schon zu Hyprland-Zeiten die Wahl: hyprpaper wäre dort
der "native" Weg gewesen, ist aber aus den Fedora-Repos raus (letzte Version
F41, hyprland selbst F42 — dieselbe Retire-Welle). swaybg ist regulär paketiert
und damit `dnf upgrade`-fähig, statt an einer COPR zu hängen. swaybg hat kein IPC,
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
per `exec ~/.local/bin/wallpaper restore` (`sway/base`) wieder gesetzt. Ist kein Bild
gemerkt, nimmt `restore` das erste im Ordner; ist der Ordner leer oder fehlt,
endet der Aufruf **still mit 0** — dann bleibt `background_color` stehen. Das
ist Absicht: eine frische Maschine soll deswegen keine Fehlerzeile im Log haben.

Für den Lockscreen gilt das NICHT — `swaylock/config` bleibt bei der flachen
Farbe (`color=1e1e2e`). Wer dort auch ein Bild will, setzt `image=...` dazu;
swaylock kann sich das Bild aber nicht vom Switcher holen, das wäre ein
zweiter, manuell gepflegter Pfad.

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

### Citrix greift am Filter vorbei (`mic-guard`)

Aufgenommen am 03.09.2026 auf dem Book. Symptom: im Citrix-Call kommt das
Trommeln auf dem Tisch durch, obwohl RNNoise laeuft. Der ganze Abschnitt haengt
nicht am Compositor — er galt unter Hyprland und gilt unter Sway unveraendert.

**Der Filter war nie das Problem.** Nachgemessen mit 4 s Raumgeraeusch,
gleichzeitig vor und hinter dem Filter aufgenommen:

| | RMS |
|---|---|
| roh (C920) | −48,8 dBFS |
| nach RNNoise | −86,3 dBFS |

Rund 37 dB Daempfung — die Kette arbeitet.

**Der Fehler steckt in der Verdrahtung.** `priority.session = 3000` sorgt
dafuer, dass WirePlumber "Mikrofon (RNNoise)" als *Standardquelle* waehlt. Das
wirkt nur bei Anwendungen, die die Standardquelle auch nehmen. Citrix' HDX-
Engine tut das nicht — sie fordert ihr Geraet mit Namen an:

```
application.process.binary = "HdxRtcEngine"
client.api                 = "pipewire-pulse"
target.object              = "alsa_input.usb-046d_HD_Pro_Webcam_C920_...-02.analog-stereo"
```

Der Kommentar in `99-rnnoise.conf` behauptet, es gebe "schlicht kein
ungefiltertes Standardmikrofon mehr". Das stimmt nur fuer Apps, die dem
Standard folgen — und das ist die eigentliche Lehre hier.

**Es faellt nicht auf, weil von aussen alles richtig aussieht:** der Filter
laedt, der Knoten existiert, `pactl get-default-source` antwortet brav
`rnnoise_source`. Sichtbar wird es einzig an der Quelle des *Streams*:

```sh
pactl list short source-outputs     # Spalte 2 ist die Quell-ID
```

Steht dort die ID der rohen Karte statt der von `rnnoise_source`, laeuft das
Mikrofon ungefiltert — egal was die Standardquelle sagt.

#### Drei Sackgassen, alle am Geraet durchprobiert

- **`pulse.rules` mit `update-props target.object`.** Die Regel *matcht*
  (mit einer Marker-Property nachgewiesen), aber die explizite
  Geraeteanforderung des Clients gewinnt: ohne `--device` landet der Stream auf
  `rnnoise_source`, mit `--device` nicht. Dazu nicht sicher eingrenzbar —
  `media.class` steht beim Matchen noch nicht zur Verfuegung, und ohne die
  Eingrenzung bekaeme auch der WIEDERGABE-Stream eine Quelle als Ziel; dann ist
  der Ton im Call weg statt sauber.
- **`node.virtual = false`**, damit Citrix die Quelle listet: ohne Wirkung.
- **Identitaetstausch** (die Filterkette uebernimmt Namen und Beschreibung der
  Webcam): nutzlos, solange Citrix den Knoten gar nicht erst listet.

**Warum Citrix sie aussiebt** — belegt, aber nicht behebbar. Genau die zwei
Quellen in Citrix' Geraeteliste tragen Hardware-Regler-Flags, die Filterquelle
nicht:

| Quelle | Pulse-Flags | gelistet |
|---|---|---|
| C920 | HARDWARE **HW_MUTE_CTRL HW_VOLUME_CTRL** DECIBEL_VOLUME LATENCY | ja |
| Ryzen Analog In | HARDWARE **HW_MUTE_CTRL HW_VOLUME_CTRL** DECIBEL_VOLUME LATENCY | ja |
| rnnoise_source | HARDWARE DECIBEL_VOLUME LATENCY | **nein** |
| die zwei Monitore | HARDWARE DECIBEL_VOLUME LATENCY | nein |

`HdxRtcEngine` ist nicht gegen libpulse gelinkt (keine `pa_*`-Symbole), und
PipeWires Pulse-Schicht bietet keinen Stellhebel fuer diese Flags. Auf dem Cube
ist die Quelle auswaehlbar, auf dem Book nicht — der Unterschied ist nicht
geklaert.

#### Die Loesung: `dot_local/bin/mic-guard`

Ein kleiner User-Dienst horcht mit `pactl subscribe` auf neue Aufnahme-Streams
und haengt jeden um, der am Filter vorbei auf **dessen eigene Eingangsquelle**
greift. Bewusst nicht "schiebe alles auf rnnoise": wer absichtlich von einem
anderen Mikrofon aufnimmt, darf das. Umgeleitet wird nur das eine Geraet, das
der Filter selbst benutzt — dafuer gibt es dann keinen ungefilterten Weg mehr.
Welches das ist, wird bei jedem Ereignis neu ermittelt, steht also nirgends
fest verdrahtet (ohne Webcam ist es das interne Mikrofon).

Das ist ein Daemon, und `99-rnnoise.conf` wirbt daneben mit "ohne GUI und ohne
Daemon" — der Satz zielte gegen NoiseTorch und bleibt fuer die Filterkette
richtig. Die Umleitung liesse sich ohne laufenden Prozess nicht loesen, siehe
die drei Sackgassen oben.

Verifiziert (03.09.2026, alles gemessen, nicht angenommen):

| Test | Ergebnis |
|---|---|
| Client fordert explizit die rohe C920 an | wird auf `rnnoise_source` umgehaengt, Logzeile im Journal |
| Client nimmt vom Ryzen-Analogeingang auf | bleibt unangetastet — kein Kapern fremder Geraete |
| Aufnahmeseite des Filters selbst (Spalte "Client" = `-`) | bleibt auf der rohen Quelle — keine Schleife |
| Wiedergabe-Streams | unberuehrt, der Dienst fasst nur source-outputs an |

**Nicht aktiviert auf dem cube.** `bootstrap.sh` aktiviert nur `podman.socket`,
sonst keine User-Units (gegengeprueft nach dem Sway-Umstieg, 08.10.2026) —
chezmoi legt die Unit also nur ab, gestartet wird sie erst mit
`systemctl --user enable --now mic-guard.service`. Auf dem cube ist sie damit
inaktiv, solange das niemand ausfuehrt. Schaden wuerde sie dort nicht (sie
waere ein No-Op, solange die Streams ohnehin auf rnnoise liegen), aber sie ist
bislang nur auf dem book geprueft.

Die Unit haengt an `default.target`, nicht an `sway-session.target`: sie hat mit
der grafischen Sitzung nichts zu tun, nur mit `pipewire-pulse`.

**Nachtest bei Zweifeln:** einmal trommeln oder klatschen, ohne dabei zu reden.
RNNoise ist VAD-gesteuert — waehrend erkannter Sprache steht das Gate offen
(plus 200 ms `VAD Grace Period`), Transienten kommen dann teilweise durch. Das
ist Absicht und kein Defekt.


## Aufnahmemodus (nur `cube`)

Waybar-Schalter zwischen "Interface für Meetings" und "Interface für die DAW".
Modul `custom/recording`, Script `dot_local/bin/recording-mode`, sitzt in der
Bar links neben `Vol`.

| Anzeige | Bedeutung |
| --- | --- |
| `Rec off` (gedämpft) | Alltag: Scarlett im Surround-Profil, ein Stereo-Sink, RNNoise am Mikro, CPU im Sparmodus |
| `Rec` (Mauve) | Aufnahme: Scarlett auf `pro-audio`, CPU auf `performance` + EPP `performance`, C-States > 100 µs aus |
| `Rec ?!` (rot) | Halb geschaltet — praktisch immer eine fehlende oder nicht greifende sudoers-Regel |
| `Rec —` (gedämpft) | Interface nicht angeschlossen |

**Warum ein Schalter und keine Dauereinstellung.** `pro-audio` liefert bewusst
keinen fertigen Stereo-Sink, sondern nackte Ports — Slack, Firefox & Co. finden
darin kein Ausgabegerät, das sie ohne Handarbeit bespielen könnten. WirePlumber
stuft das Profil deshalb mit Priorität 1 ein (das Surround-Profil hat 1301) und
wählt es nie von selbst. Für Meetings ist es unbrauchbar, für die DAW ist alles
andere Ballast: `hw:0` roh, alle 10 Ein- und 6 Ausgänge einzeln, keine
ALSA-Plugin- und keine Channel-Remap-Schicht.

**Wozu das Ganze.** Roundtrip-Latenz bei Gitarre über Amp-Sim. Vorher rund
26 ms (480 Samples Quantum + 240 Samples Headroom, Interface im
Surround-Profil), damit spielt es sich spürbar hinterher. Mit `pro-audio` und
kleinem Puffer sind ~7 ms bei 48 kHz und ~4 ms bei 96 kHz erreichbar — zum
Vergleich: ein Amp in einem Meter Entfernung "hat" schon 3 ms. Hardware-Direct-
Monitoring im Scarlett hilft hier NICHT, weil man das bearbeitete Signal hören
will, nicht das cleane.

**Reihenfolge:** erst den Button auf `Rec`, dann die DAW starten. Umgekehrt
zieht der Profilwechsel dem laufenden Programm das Gerät unter den Füßen weg.

**Die Hostweiche steht an drei Stellen** und muss zusammen gepflegt werden:

| Datei | gatet |
| --- | --- |
| `home/.chezmoiignore` | das Script selbst |
| `home/dot_config/waybar/config.jsonc.tmpl` | den Button in der Bar |
| `bootstrap.sh` | Root-Helfer + sudoers-Regel |

`home/dot_config/waybar/style.css` ist bewusst NICHT gegatet: CSS-Regeln für ein
nicht vorhandenes Modul sind wirkungslos, eine vierte Weiche wäre nur zusätzliches
Risiko.

**Der Root-Teil.** Governor, EPP und C-States liegen in `/sys` und brauchen
root. Statt dem Benutzer `sudo` auf `tee` zu geben (das wäre effektiv
passwortloses root) macht es ein eigener Helfer, `system/recording-mode-cpu`,
freigegeben über `system/recording-mode.sudoers` für genau zwei Aufrufe —
`… on` und `… off`, sonst nichts. Zwei Details, an denen es sonst still
scheitert:

- Die Helfer-Datei MUSS `root:root 0755` sein. Gehört sie dem Benutzer, kann
  der ihren Inhalt austauschen und per NOPASSWD-Regel als root ausführen
  lassen — die Regel wäre dann passwortloses root mit einem Zwischenschritt.
  `bootstrap.sh` benutzt deshalb `install -o root -g root -m 0755`, nicht `cp`.
- Der Zielname in `/etc/sudoers.d/` trägt KEINE Endung. sudo überspringt dort
  alles, was einen Punkt im Namen hat: aus `recording-mode.sudoers` würde eine
  Datei, die korrekt installiert ist, sauber parst und trotzdem nie gelesen
  wird.

`bootstrap.sh` prüft nach dem Installieren beides: `visudo -c` (parst die
Datei?) und einen echten `sudo -n`-Testaufruf (greift die Regel?). Das zweite
ist nicht redundant — genau diese Lücke hat beim ersten Einrichten Zeit
gekostet.

**C-States.** Im Aufnahmemodus fliegen alle Idle-States mit mehr als 100 µs
Aufweckzeit raus, auf dem Ryzen 9 7900 ist das C3 mit 350 µs. Bei 128 Samples
@ 48 kHz sind das rund 13 % des gesamten Zyklusbudgets, fällig genau dann, wenn
der Kern aus dem Leerlauf geholt wird. C1 (1 µs) und C2 (18 µs) bleiben an, die
kosten nichts und sparen echte Wärme. Gefiltert wird über die gemessene Latenz,
nicht über den Namen — "C3" heißt nicht auf jeder CPU dasselbe, die Zahl in
`latency` schon.

**Zustand wird nirgends gespeichert.** Jeder Aufruf liest frisch aus PipeWire
und `/sys`. Ein von Hand mit `wpctl` umgestelltes Profil oder ein abgezogenes
Interface fällt der Anzeige damit sofort auf, statt gegen eine gemerkte
Wahrheit zu laufen. Ein Klick auf `Rec ?!` führt zurück in den Alltagsmodus,
nicht noch einmal in denselben Fehler — ein halb geschalteter Zustand ist immer
ein kaputter Helfer, und den repariert kein Mausklick.

**Realtime** — nicht Teil dieses Schalters, aber Voraussetzung dafür, dass er
etwas bringt. Ohne Realtime knackt es bei kleinen Puffern, egal was Profil und
Governor tun. Zwei Fallen, beide am 2026-09-01 geschlossen:

- Fedora liefert `/etc/security/limits.d/` mit `@pipewire - rtprio 70` aus, die
  Regel greift aber nur für Mitglieder der Gruppe `pipewire` — und in die trägt
  Fedora niemanden ein. Ohne sie fällt PipeWire auf rtkit zurück und bekommt
  Priorität 20 statt der konfigurierten 60. **`bootstrap.sh` erledigt das**
  (hostunabhängig, direkt nach dem dnf-Lauf — vorher gibt es die Gruppe nicht).
- Ein Flatpak kommt ohne `[System Bus Policy]` gar nicht an rtkit heran und
  läuft komplett ohne Realtime — rtkit sitzt auf dem System-Bus, nicht auf dem
  Session-Bus. Behoben mit
  `flatpak override --user --system-talk-name=org.freedesktop.RealtimeKit1 <app-id>`
  für die DAW (von Hand installiert, bewusst nicht Teil dieses Repos).

Die Gruppe wirkt erst nach Ab- und Anmelden: PAM vergibt das Rlimit beim
Session-Start, ein neues Terminal reicht nicht. Gegenprobe: `ulimit -r` muss
`70` sagen und `ps -Lo cls,rtprio -p $(pgrep -x pipewire)` den Data-Loop auf
`RR 60` statt `RR 20`.

Der Flatpak-Override dagegen steht nirgends im Repo und geht bei einer
Neuinstallation verloren — die DAW ist bewusst nicht Teil dieses Repos.

**Danach noch offen:** `api.alsa.headroom` steht für das Scarlett auf 240
Samples = 5 ms, die konstant auf jeden Puffer obendrauf kommen. Eine
WirePlumber-Drop-in-Regel neben `99-rnnoise.conf` kann das auf 0–32 ziehen.
Und 96 kHz halbiert die Millisekunden bei gleicher Blockgröße.


## Musik (lokale MP3/FLAC)

Streaming bleibt Cider (Flatpak, Apple Music). Lokale Dateien laufen daneben in
**mpv** — CLI, im foot-Fenster, kein Daemon und keine Bibliothek:

```sh
music ~/Musik/album/track.flac    # eine Datei
music ~/Musik/album               # Ordner als Playlist
music ~/Musik/album/*.flac        # Auswahl
```

`dot_local/bin/music` ist ein dünner Wrapper um mpv, dessen einziger Zweck die
**Einzel-Instanz** ist (s. u.). `mpv datei.flac` von Hand geht weiterhin, macht
dann aber einen eigenen Player auf.

Steuerung ist mpvs eingebaute: Leertaste Pause, `<`/`>` Titel, `9`/`0`
Lautstärke, `q` Ende. Doppelklick im Double Commander bzw. `xdg-open track.mp3`
landen über `mimeapps.list` am selben Ort — dort aber als **schwebendes
Mini-Fenster** statt als halber Bildschirm (s. u.).

**Warum kein TUI-Player.** `cmus` und `musikcube` — die naheliegenden
Kandidaten — gibt es in Fedora 44 nicht mehr (`dnf search cmus`: keine
Übereinstimmung). Bliebe `mpd` + `ncmpcpp`: ein Daemon, ein Client, eine
`mpd.conf` und ein `~/.ncmpcpp/config` für die Frage "spiel diesen Ordner ab".
Für eine gepflegte Sammlung mit Playlists wäre das die richtige Antwort; hier
ist die Sammlung ein Ordner, und mpv ist ein Kommando ohne Zustand.

**Decoder kommen aus ffmpeg.** mpv linkt gegen `libavcodec`/`libavformat`
(`dnf repoquery --requires mpv`) — MP3 und FLAC sind damit erledigt, es gibt
kein `libmad`, kein `flac`-Paket und keine Codec-Nachinstallation.

### Cover-Art ist eine Videospur

Das ist der Fallstrick: Cover-Art in MP3/FLAC ist für mpv **Video** (Default
`--audio-display=embedded-first`). Unbehandelt macht mpv dafür ein Fenster auf,
und der Tiler kachelt es in die aktive Workspace ein — dasselbe
Fenstermodell-Problem wie bei LibreOffice (s. Office-Kapitel).

Zwei Stellen, mit Absicht getrennt:

- `dot_config/mpv/mpv.conf` setzt **`audio-display=no`**, global für jeden
  mpv-Aufruf. Das ist *nicht* dasselbe wie `--no-video`: echte Videodateien
  laufen weiter normal, es wird nur das Standbild aus Audio-Tags nicht mehr als
  Video behandelt. Deshalb darf es global stehen — und deshalb ist
  `mpv track.flac` von Hand genauso fensterfrei wie der Doppelklick.
- Der Handler setzt zusätzlich hart `--no-video`. Redundant, aber gewollt: ein
  Audio-Handler soll nicht davon abhängen, dass eine Config-Datei danebenliegt.

### Zwei .desktop-Dateien, mit Absicht

| Datei | Woher | Wofür |
|---|---|---|
| `mpv.desktop` | Paket (`/usr/share/applications`) | Video. Steht in fuzzel. |
| `mpv-audio.desktop` | `dot_local/share/applications` (Template) | Audio-Handler aus `mimeapps.list`, ruft `dot_local/bin/music`. `NoDisplay=true`, taucht in fuzzel **nicht** auf. |

Eigene Desktop-ID statt Schatten (anders als bei `emacs.desktop` daneben):
überschreibt man `mpv.desktop`, verliert man mit demselben Griff das Abspielen
von Videos. `Exec=foot -e mpv …` statt `Terminal=true`, gleiche Begründung wie
beim Emacs — ohne DE gibt es keinen "Standard-Terminal-Emulator", den ein
Aufrufer finden könnte.

MP3 und FLAC hatten vorher **gar keinen** Handler (`xdg-mime query default
audio/mpeg` antwortete leer) — derselbe Zustand wie seinerzeit
`inode/directory`: Doppelklick tat nichts, ohne Dialog und ohne Fehler.

### Eine Instanz statt fünf

Ohne Zutun startet jede geöffnete Datei ihren eigenen mpv — zwei Doppelklicks,
zwei Stücke gleichzeitig. `dot_local/bin/music` schickt die Datei deshalb an
den **schon laufenden** Player, statt einen zweiten aufzumachen: erste Datei als
`loadfile … replace`, alle weiteren als `append`, die Playlist bleibt also ganz.

**Über mpvs IPC-Socket, nicht über MPRIS.** Naheliegend wäre
`playerctl -p mpv open …` gewesen — mpv-mpris implementiert
`org.mpris.MediaPlayer2.Player` und damit `OpenUri`. Aber `TrackList` ist laut
seiner README ausdrücklich **nicht** implementiert, und MPRIS kennt keinen
Mehrfach-Open: ein im Double Commander markiertes Album wäre auf die erste
Datei zusammengeschrumpft. Der Socket kann beides.

Zwei Details, die den Unterschied zwischen "geht" und "geht meistens" machen:

- **Die Socket-Datei ist kein Beweis, dass ein Player läuft.** Gemessen: nach
  `quit` bleibt sie liegen, mpv räumt sie nicht weg. Das Skript nimmt deshalb
  den *Verbindungsversuch* als Test — klappt er nicht, ist es eine Leiche, sie
  wird gelöscht und ein frischer Player gestartet (durchgespielt: Fenster
  vorher 1, nachher 2).
- **Pfade werden absolut gemacht.** mpv löst ein relatives `loadfile` gegen das
  Arbeitsverzeichnis *des laufenden* mpv auf — also gegen das Verzeichnis, in
  dem der Player irgendwann gestartet wurde, nicht gegen das aktuelle. Aus dem
  `.desktop` kommen über `%F` ohnehin absolute Pfade, von Hand aber nicht.

Das JSON baut `jq` (steht schon in packages.txt), gesendet wird mit **`socat`**
— beides in *einer* Verbindung, sonst kostet jede Datei eines Albums die
Wartezeit erneut. Fokus holt das Skript bewusst nicht: ein Doppelklick im
Dateimanager soll nicht die Workspace wechseln. Wer es anders will, hängt
`swaymsg '[app_id="mpv-audio"] focus'` an — die Zeile steht auskommentiert
im Skript.

Der Handler ist deshalb jetzt ein **chezmoi-Template**
(`mpv-audio.desktop.tmpl`): `Exec=` sieht keine Shell, ein `~` wird nicht
expandiert, und ob `~/.local/bin` im PATH des Aufrufers steht, ist nicht
garantiert — bei Double Commander gemessen ja, aber genau diese Annahme war bei
den Compositor-Bindings schon einmal falsch. `{{ .chezmoi.homeDir }}` schreibt den
echten Pfad hinein.

### Das Player-Fenster

Erster Anlauf war ein `foot -e mpv …` ohne weitere Zutaten. Ergebnis: ein
**gekacheltes** Terminal über den halben Bildschirm (damals abgelesen mit
`hyprctl clients`: `class=foot … size=[1702,1388]`), gefüllt mit
`AO: [pipewire] 48000Hz stereo`.
Für eine Laufzeitanzeige zu viel Bildschirm und zu viel Text. Drei Griffe:

- **`foot --app-id=mpv-audio`.** Ohne eigene app-id heißt die Klasse schlicht
  `foot`, und jede Fensterregel dafür träfe auch jedes Arbeitsterminal. Die
  Regel in `sway/rules` lässt das Fenster schweben, 700×260, zentriert —
  gleiche Überlegung wie beim Rechner, `$mod+V` holt es in die Kachelung.
- **`--msg-level=all=warn,statusline=status`.** Die Startzeilen kommen aus
  mpvs Modul `cplayer`, die Laufzeit aus `statusline` (`mpv --msg-module` zeigt
  die Namen). Nur `cplayer` runterdrehen geht nicht, ohne die Statuszeile
  mitzunehmen — daher `all=` plus Ausnahme. Fehler bleiben sichtbar, `warn`
  schließt `error` und `fatal` ein. **Kein `--quiet`**: das nimmt die
  Statuszeile komplett mit, nachgemessen.
- **`--term-osd-bar`** für den Fortschrittsbalken. Im kleinen Fenster ist das
  die halbe Information.

**Warum das Fenster zentriert steht und nicht unten rechts.** Ursprünglich
sollte es in die Ecke. Der Versuch scheiterte damals unter Hyprland 0.56 an
dessen `move`-Grammatik, die nur absolute Pixel akzeptierte; live geprüft mit
`hyprctl keyword windowrule` auf einem 3440×1440-Monitor, fielen alle relativen
Schreibweisen **still** auf die Standardplatzierung zurück:

| Regel | Ergebnis |
|---|---|
| `move 2700 1140` | `at=[2700,1140]` — wie gewollt |
| `move 100%-740 100%-300` | `at=[1370,605]` — zentriert, also ignoriert |
| `move 78% 80%` | `at=[1370,605]` |
| `move onscreen 100%-740 100%-300` | `at=[1370,605]` |
| `move cursor -50% -50%` | `at=[1370,605]` |

Absolute Pixel wären auf dem cube richtig und auf dem book (andere Auflösung)
daneben gewesen — also zentriert.

Unter Sway steht in `sway/rules.tmpl` heute `resize set 700 260, move position
center`. Sway *könnte* die Ecke (`move position 78 ppt 80 ppt`); es bleibt
trotzdem bei zentriert, weil das auf beiden Hosts dasselbe vorhersagbare
Ergebnis liefert.

Den Titel liefert mpv selbst: es setzt den *Terminaltitel* auf das laufende
Stück, das steht damit in der Fensterleiste und im `sway/window`-Modul.
Ein `--term-playing-msg` wäre der falsche Weg — das hängt an `cplayer` und
fällt mit weg.

Waybar bekommt für die app-id ein eigenes Workspace-Icon (💿, Cider hat 🎵) —
so sieht man im Switcher, *was* gerade spielt.

**Kehrseite der Stille:** schlägt eine Datei fehl, steht die Fehlermeldung nur
so lange, wie mpv läuft — also einen Wimpernschlag, dann schließt foot. Zum
Nachsehen die Datei einmal von Hand im Terminal aufrufen.

### Medientasten (`playerctl`, für mpv UND Cider)

`playerctl` spricht MPRIS, nicht ein bestimmtes Programm. Cider bringt MPRIS
mit, mpv erst durch **`mpv-mpris`** — das Paket legt genau
`/etc/mpv/scripts/mpris.so` ab, mpvs systemweites Skriptverzeichnis, und wird
von jeder mpv-Instanz von allein geladen. Es gibt daran nichts zu
konfigurieren, auch keine `mpv.conf`.

Die Bindings in `sway/binds` benutzen `playerctl -p mpv,%any`:

- Ohne `-p` nimmt playerctl laut man-Page "den ersten verfügbaren Player" —
  bei laufendem Cider *und* laufendem mpv ist das nichts, worauf man sich
  verlassen will.
- `mpv,%any` heißt: lokaler Player zuerst, sonst irgendeiner. Wer gerade etwas
  lokal abspielt, meint mit der Taste das. Laufende Namen: `playerctl -l`.
- Das Komma in `mpv,%any` ist unter Sway unkritisch: hinter `exec` steht der
  Rest der Zeile ohnehin komplett in der Shell. (Unter Hyprland war das eine
  echte Frage — dessen Parser splittet an Kommas; nachgemessen hatte es
  damals ebenfalls gehalten.) Keine Anführungszeichen, kein Wrapper nötig.
- `bindsym --locked`, wie bei der Tastaturbeleuchtung: geht auch bei
  gesperrtem Bildschirm.

**Noch nicht auf dieser Hardware nachgemessen**, ob die Tasten wirklich
`XF86AudioPlay` & Co. schicken — anders als bei Kamera- und Rechner-Taste der
MX Keys. `wev` zeigt es. Tut sich nichts, ist es die Taste und nicht playerctl;
das trennt man mit `playerctl -p mpv,%any play-pause` direkt im Terminal.

Nebenbefund beim Einbauen: `dot_local/bin/keybinds` matchte nur `bind` und
`bindm`. `bindl`/`bindel` fielen durch — die Tastaturbeleuchtung stand also
schon länger in `binds.conf` und fehlte trotzdem im `SUPER+F1`-Popup, lautlos.
Muster war danach `bind[a-z]*`; seit Sway matcht das Skript `bindsym` (Flags
wie `--locked` stehen dort hinter dem Schlüsselwort, nicht darin).

### Prüfen nach `chezmoi apply`

```sh
xdg-mime query default audio/flac     # -> mpv-audio.desktop
xdg-open ~/Musik/irgendwas.flac       # -> foot mit mpv, KEIN zweites Fenster
playerctl -l                          # bei laufendem mpv: mpv (evtl. mpv.instanceN)
swaymsg -t get_tree | grep -A2 mpv-audio   # app_id=mpv-audio, floating
music a.flac; music b.flac            # zweiter Aufruf ersetzt, kein zweites Fenster
```

Meldet der zweite Schritt nichts, einmal
`update-desktop-database ~/.local/share/applications` — glib begnügt sich für
`[Default Applications]` zwar damit, dass die Datei existiert, strengere
Implementierungen lesen den Cache.

## Idle-Verhalten und der `Wach`-Schalter

`swayidle` (Aufruf in `sway/base`) fährt eine **zweistufige** Kette: **5 min**
sperren (`loginctl lock-session` → swaylock), **15 min** Suspend. Eine Display-Aus-Stufe
bei 5:30 min gab es früher, sie ist raus — siehe "Display-Aus killt Thunderbird"
weiter unten.

Das ist für den Alltag richtig und für lange Hintergrund-Jobs falsch — ein
Build, ein Export, ein `podman build`, ein großer Sync nach mailbox.org Drive.
Suspend nach 15 min unterbricht so etwas mitten drin.

Dafür sitzt links in der rechten Modulgruppe der Waybar ein Schalter:

| Anzeige | Farbe | Bedeutung |
| --- | --- | --- |
| `Idle` | gedämpft (`overlay1`) | Normalfall, volle swayidle-Kette |
| `Wach` | gelb | kein Lock, kein Display-Aus, kein Suspend |

Klick schaltet um, der Tooltip nennt den jeweils anderen Zustand.

**Wie es wirkt.** Das ist Waybars eingebautes `idle_inhibitor`-Modul, kein
eigenes Skript. Es hält einen `zwp_idle_inhibitor_v1` auf seiner eigenen
Layer-Surface; Sway stoppt daraufhin die `ext-idle-notify-v1`-Timer, und
aus genau denen speist swayidle seine Listener. swayidle wird also
**nicht gestoppt** — ihm wird die Uhr angehalten. `pidof swayidle` sieht
weiterhin alles normal, und `systemctl --user` bleibt außen vor. Beim
Zurückschalten laufen die Timer von vorn los, nicht an der Stelle weiter, an
der sie standen.

Zwei Konsequenzen, die man kennen sollte:

- **Der Zustand überlebt nichts.** `start-activated` ist absichtlich nicht
  gesetzt: Waybar-Neustart, Relogin oder Reboot schalten zurück auf `Idle`.
  Ein vergessener Inhibit, der einen Reboot übersteht, fällt sonst erst auf,
  wenn der Akku von "book" leer ist.
- **Manuelles Sperren geht weiter.** `SUPER+L` ruft `loginctl lock-session`
  (seit 13.09.2026; davor `hyprlock` direkt, also ein zweiter, ungeprüfter
  Weg) und fragt keinen Inhibitor — der hält nur die Idle-Timer an. Der
  Schalter unterdrückt also nur das *automatische* Sperren.

Nicht genommen: den Idle-Daemon per Custom-Modul anhalten. Das wäre
ein Zustand außerhalb der Bar (Unit gestoppt), der einen Absturz von Waybar
überlebt — und damit genau der vergessene Inhibit, den die Variante oben
vermeidet.

**Kein Keybind.** Der Schalter hat bewusst nur den Klick. Ein
Zwei-Zustands-Schalter ohne sichtbare Anzeige ist blind bedienbar, und
verlassen kann man sich darauf nur, wenn man die Anzeige sowieso ansieht.

### Standby eine Sekunde nach dem Entsperren (gelöst, 13.09.2026)

> Seit dem Abend des 13.09.2026 ist der Sperrbildschirm **swaylock**, nicht
> mehr hyprlock (Grund: „Nachlese 13.09.2026"). Die Analyse unten gilt
> unverändert — `-w` blockiert weiterhin pro Kommando —, nur der Fix sieht
> anders aus: statt `hyprlock &` steht `swaylock -f`, und das ist mehr als
> eine Schreibweise. `-f` forkt laut swaylock(1) erst *nach* dem Sperren, der
> lock-Aufruf kehrt also genau dann zurück, wenn die Session gesperrt ist.

**Symptom.** Der Rechner ist gesperrt, aber wach — hyprlock steht, kein
Standby. Passwort eingeben, Enter, Desktop ist kurz da, und eine Sekunde
später geht die Kiste in den Suspend. Zweimal passiert, beide Male seit dem
Wechsel auf Sway, und beide Male steht es so im Journal
(`journalctl --since 2026-09-08 | grep -E 'unix_chkpwd.*success|will suspend now'`):

```
2026-09-11T09:01:04 audit: op=PAM:unix_chkpwd acct="zoellert" ... res=success
2026-09-11T09:01:05 systemd-logind: The system will suspend now!
2026-09-13T11:02:51 audit: op=PAM:unix_chkpwd acct="zoellert" ... res=success
2026-09-13T11:02:52 systemd-logind: The system will suspend now!
```

**Ursache: `-w` gilt für jedes Kommando, und das lock-Kommando lief bis zum
Entsperren.** `swayidle -w` ist wegen `before-sleep` gesetzt (s. Kommentar in
`sway/base`). Die Manpage sagt aber ohne Einschränkung: *"using this option
causes swayidle to block until the command finishes"* — das gilt für `timeout`,
`lock`, `unlock`, alles. Das lock-Kommando war `pidof hyprlock || hyprlock`,
und hyprlock läuft genau so lange, wie der Bildschirm gesperrt ist. swayidle
saß also die ganze Sperrzeit in `waitpid` und hat **keine Wayland-Events
verarbeitet**. Live nachgesehen am 13.09. bei gesperrtem Bildschirm:

```console
$ cat /proc/$(pidof swayidle)/wchan
do_wait
$ ps --ppid $(pidof swayidle) -o pid,etime,cmd
 245081    07:37 hyprlock
```

Die Events stauen sich derweil im Socket, in der Reihenfolge, in der Sway sie
schickt: nach 15 min das `idled` für den 900er-Timer, beim Tippen des
Passworts das `resumed` für beide Timer. Sobald hyprlock weg ist, kehrt
`waitpid` zurück, swayidle arbeitet die Warteschlange ab — und das erste
Ereignis darin ist das `idled` → `systemctl suspend`. Das `resumed` dahinter
kommt zu spät. Daher die eine Sekunde.

Die Kehrseite desselben Fehlers fällt weniger auf: solange swayidle blockiert
war, konnte die 15-min-Stufe bei gesperrtem Bildschirm **nie** feuern. Seit
dem 10.09. gab es genau zwei Suspends, und das waren die beiden nach dem
Entsperren. Ein Rechner, der über Nacht gesperrt stehen bleibt, bleibt also
wach — der Suspend kommt erst morgens, eine Sekunde nach dem Passwort.

**Fix.** In `sway/base`:

```
lock 'pidof hyprlock >/dev/null || hyprlock &'
```

Das `&` hängt in POSIX sh an der ganzen `||`-Liste; die Shell kehrt sofort
zurück, hyprlock läuft weiter, swayidle ist wieder im Event-Loop. swaylock hat
für genau diesen Fall `-f` (die Manpage von swayidle benutzt es in ihrem
Beispiel), hyprlock 0.9.6 hat keinen Daemonize-Schalter (`hyprlock --help`) —
deshalb das Shell-`&`. `>/dev/null`, weil pidof sonst bei jedem Lock eine PID
in den Session-Log schreibt.

Greift nach `chezmoi apply` erst mit der nächsten Sway-Session (`exec` läuft
nur beim Start, s. `binds`). Wer nicht neu anmelden will, startet swayidle
von Hand neu (seit dem `&` ist hyprlock kein Kind von swayidle mehr, der
Neustart nimmt es also nicht mit; bei entsperrtem Bildschirm ist es trotzdem
übersichtlicher):

```sh
pkill -x swayidle && swaymsg exec "$(grep '^exec swayidle' ~/.config/sway/base | sed 's/^exec //')"
```

Prüfen: bei gesperrtem Bildschirm muss `cat /proc/$(pidof swayidle)/wchan`
jetzt `do_sys_poll` oder `ep_poll` zeigen, nicht mehr `do_wait`.

**Nicht genommen:**

- `-w` weglassen. Dann wartet `before-sleep` nicht mehr auf
  `loginctl lock-session`, und die Begründung in `sway/base` gilt weiter. Ehrlich
  gesagt ist der Schutz kleiner, als der Kommentar klingt: `-w` wartet nur
  darauf, dass der D-Bus-Aufruf durch ist. hyprlock selbst startet in beiden
  Varianten erst danach, asynchron über das Lock-Signal von logind, und gewinnt
  das Rennen gegen den Freezer von systemd-sleep bisher immer (11.09. und
  13.09.: nach dem Resume stand der Sperrbildschirm, unix_chkpwd um 09:01:28
  und 11:03:14).
- In `before-sleep` auf `pidof hyprlock` warten, um das Rennen sicher zu
  gewinnen. **Deadlock-Falle:** swayidle ist single-threaded und verarbeitet
  das Lock-Signal erst, wenn das before-sleep-Kommando zurück ist. Eine solche
  Schleife läuft immer in ihren Timeout, hyprlock startet danach trotzdem.
  Wenn der Schutz je gebraucht wird, muss `before-sleep` hyprlock **selbst**
  starten statt über `loginctl lock-session` zu gehen.

**Konsequenz, die man kennen sollte:** ab jetzt suspendiert der Rechner bei
gesperrtem Bildschirm nach 15 min tatsächlich, so wie es die Kette seit
August vorsieht. Für lange Jobs bleibt der `Wach`-Schalter oben. Der Suspend
selbst ist seit dem 26.08. unauffällig: 20 S3-Zyklen, null Fehler im Journal
(s. "Suspend hängt sich auf").

### Display-Aus killt Thunderbird (deshalb keine DPMS-Stufe)

> Diese Untersuchung ist im August/September 2026 **unter Hyprland** gemacht
> worden; die Log-Auszüge und Pfade unten stammen von dort. Das Ergebnis gilt
> unverändert weiter: die Ursache liegt beim Monitor und beim Kernel-Connector,
> nicht beim Compositor. Deshalb hat auch die swayidle-Kette in `sway/base`
> **keine** dpms-off-Stufe.

**Symptom.** Nach jedem Idle-Zyklus ließ ein laufender Thunderbird keine
Kontextmenüs mehr aufgehen. Kein Fehler, kein Absturz — das Menü kam einfach
nicht. Nur ein Neustart der App half. Firefox auf derselben Maschine war
unauffällig.

**Nicht die Ursache**, obwohl beides naheliegt: hyprlock ist es nicht (das
Symptom hängt nicht am Lock), und ein echter Suspend ist es auch nicht —
`journalctl -u systemd-suspend.service` zeigte über den ganzen Tag keinen
einzigen. Die 15-min-Stufe feuert im Alltag praktisch nie, es war immer nur
das Display-Aus bei 5:30 min.

**Was tatsächlich passiert.** `dpms off` schaltet den Monitor nicht bloß
dunkel. Das Gerät lässt im Standby die HPD-Leitung fallen, der Kernel meldet
den Connector daraufhin als *abgezogen*. Im damaligen Hyprland-Log
(`$XDG_RUNTIME_DIR/hypr/$HYPRLAND_INSTANCE_SIGNATURE/hyprland.log`) stand die
Kette dreimal Wort für Wort gleich:

```
drm: Disabling output HDMI-A-2
drm: Connector HDMI-A-2 enabledState changed true -> false
drm: Got a hotplug event for /dev/dri/card1
drm: Connector 383 connection state: 2
drm: Connector HDMI-A-2 disconnected
drm: HDMI-A-2 is not connected, clearing stale crtc 369
Swapchain: Reconfigured a swapchain to [Vector2D: x: 1920, y: 1080]
```

Die letzte Zeile ist der Beleg, dass es kein reines Dunkelschalten war: die
Swapchain fällt von 3440x1440 auf den 1920x1080-Fallback zurück. Hyprland
zerstört den `wl_output` und legt ihn beim Aufwachen neu an.

**Warum nur Thunderbird.** Gecko cached die GTK-Workarea über so ein
Output-Destroy/Recreate hinweg falsch und legt Popups danach mit kaputter
Geometrie an — sie existieren, sind aber nicht sichtbar. Das ist
[Mozilla-Bug 1564076](https://bugzilla.mozilla.org/show_bug.cgi?id=1564076),
später zusammengeführt über
[2036975](https://bugzilla.mozilla.org/show_bug.cgi?id=2036975) nach
[2026258](https://bugzilla.mozilla.org/show_bug.cgi?id=2026258). Der Fix
("Fall back to wl_output monitor size if we're missing Gtk workarea to calc
fractional scale") ist in **Gecko 151/152** gelandet. Firefox läuft hier als
natives Paket auf **153** und hat ihn; Thunderbird ist das Flatpak
`org.mozilla.thunderbird_esr` auf **140 ESR**, also Gecko 140, und hat ihn
nicht. Daher genau eine betroffene App bei identischem Compositor,
identischem Monitor, identischem Idle-Zyklus.

**Entscheidung: die DPMS-Stufe fällt weg.** Sie greift die Ursache an und
hilft jeder Gecko-ESR-App, nicht nur Thunderbird.

Preis: der Bildschirm bleibt zwischen Lock und Suspend an, also bis zu 10 min,
und zeigt dabei den fast schwarzen hyprlock-Screen.

Bewusst *nicht* auf "kurz vor den Suspend schieben": der Disconnect folgt dem
`dpms off` binnen Sekunden, die Dauer des Aus-Zustands ist also irrelevant —
es zählt nur, ob es überhaupt passiert.

**Verworfene Alternativen**, beide funktionsfähig, beide mit einem Preis, den
diese Kiste nicht zahlen muss:

- **Thunderbird auf XWayland**
  (`flatpak override --user --nosocket=wayland org.mozilla.thunderbird_esr`).
  X11-Popups sind override-redirect und von dem Bug nicht betroffen. Preis:
  Drag & Drop *aus* Thunderbird heraus liefe dann über die XDND-Brücke des
  XWayland-Managers — genau der Weg, der in packages.txt bei Double Commander
  schon als fragil ausgeschieden ist.
- **Wechsel auf den Release-Kanal** (`org.mozilla.thunderbird`, Flathub, aktuell
  154.0 — die *kleingeschriebene* App-ID, nicht das EOL `org.mozilla.Thunderbird`
  aus dem Kommentar in flatpaks.txt). Hat den Fix. Preis: monatliche
  Major-Versionen statt ESR-Ruhe, plus Profilumzug von
  `~/.var/app/org.mozilla.thunderbird_esr/` — und das ist eine Einbahnstraße,
  ein von 154 geöffnetes Profil geht nicht zurück auf 140.

**Wenn das Display-Aus zurück soll**, ist der Hebel nicht der Idle-Listener,
sondern der Connector: `video=HDMI-A-2:e` auf der Kernel-Cmdline zwingt ihn
dauerhaft auf "verbunden", der HPD-Verlust im Standby wird dann ignoriert und
der `wl_output` bleibt stehen. Hier nicht eingebaut, weil ungetestet und weil
10 min heller Lockscreen der billigere Preis ist.

**Diagnose, wenn es wiederkommt:**

```sh
journalctl --user -t sway | grep -c "disconnect"   # meldet Sway den Connector als weg?
journalctl -u systemd-suspend.service --since today   # feuert der Suspend ueberhaupt?
flatpak list --app --columns=application,version | grep -i thunderbird   # Gecko >= 152?
```

## Monitor gehört an die iGPU, nicht an die dedizierte Karte

**Stand 13.09.2026: Regel aufgehoben.** Das Kabel steckt seit dem Nachmittag
wieder an der RX 6400 (HDMI-A-1), der S3-Test mit aktivem Display ist sauber
durchgelaufen — s. „Ergebnis" am Ende dieses Abschnitts. Der Rest hier ist die
Vorgeschichte und bleibt stehen, weil die Journal-Befunde die Rückfallebene
begründen.

**Regel (bis 13.09.2026).** Das HDMI-Kabel steckt an der Onboard-Grafik des Mainboards
(`11:00.0`, Raphael), nicht an der Radeon RX 6400 (`03:00.0`). Das ist keine
Geschmacksfrage, sondern die Voraussetzung dafür, dass der Rechner aus dem Idle
zurückkommt.

**Symptom mit Kabel an der dGPU.** Läuft die Kiste in den Idle, kommt der
Bildschirm nicht wieder: schwarz, keine Reaktion auf Tastatur oder Maus. Der
Rechner selbst lebt dabei — SSH von außen funktioniert einwandfrei, Dienste
laufen weiter. Es stirbt ausschließlich der Display-Stack der dGPU, und ohne
zweiten Rechner im Netz sieht das aus wie ein toter Kasten.

**Was im Journal steht** (22.08.2026 20:08, 24.08.2026 09:03:35 und 14:09:24 —
drei Vorfälle, alle mit Kabel an der dGPU):

```
amdgpu 0000:03:00.0: SMU: No response msg_reg: 36 resp_reg: 0
amdgpu 0000:03:00.0: RunDcBtc failed!
amdgpu 0000:03:00.0: resume of IP block <smu> failed -62
amdgpu 0000:03:00.0: amdgpu_device_ip_resume failed (-62).
```

Die SMU der Navi 24 antwortet beim Aufwachen nicht mehr. Danach läuft der
`sdma0`-Ring in die Timeout-Schleife, die im nächsten Abschnitt beschrieben ist
— im Boot vom 24.08. sind das 16588 amdgpu-Zeilen für `03:00.0`.

**Mit Kabel an der iGPU** ist das weg. Verifiziert am 25.08.2026 mit einem
echten S3-Zyklus: nach dem Resume steht die dGPU wieder auf `suspended`/D3hot,
der Monitor an `card1-HDMI-A-2` ist da, das Netz verbunden, das Journal sauber.
Die dGPU macht dabei weiterhin `MODE1 reset` — das ist der normale Weg zurück
aus D3 und kein Fehler.

**Preis.** Die RX 6400 treibt dann kein Display mehr. Für Rendering, VAAPI oder
Compute steht sie weiter zur Verfügung, sie hängt nur nicht mehr im
Modesetting-Pfad.

**Rückweg zur dGPU (Plan vom 13.09.2026, am selben Tag gegangen).** Die Beweislage hat sich seit
August verschoben, und die Regel oben ist damit weicher, als sie klingt. Im
Journal (reicht zurück bis 15.08.) steht **jeder** SMU-Ausfall der RX 6400
(16., 17., 18.08. und die oben genannten 22./24.08.) **nach** einem
`PM: suspend entry (s2idle)` — also im Fallback, den der Drop-in
`SuspendState=mem` aus dem nächsten Abschnitt seit 25.08. unterbindet. Die
`deep`-Versuche unmittelbar davor (abgebrochen bei "Abort CPU freeze", Geräte
suspendiert und wieder aufgeweckt) hat die Karte **mit aktivem Display** jedes
Mal unbeschadet überstanden; am 16.08. um 00:34 z. B. ein kompletter
Geräte-Suspend/-Resume im deep-Pfad ohne eine einzige amdgpu-Fehlerzeile, die
SMU starb erst im anschließenden s2idle-Bein. Seit dem Kabelwechsel: 20 echte
S3-Zyklen, 0 × `SMU: No response`, 0 × s2idle, dazu rund 340 Runtime-Resumes
der dGPU aus BACO ohne Fehler.

Was **nicht** getestet ist: ein vollständiger S3 mit der dGPU in D0 und
aktivem CRTC — nicht aus dem Runtime-Suspend heraus, sondern als Karte, die
gerade ein Bild ausgibt. Genau das ist der Unterschied zu heute, und genau das
muss vor dem Umstecken einmal gezielt laufen. In dieser Reihenfolge:

1. **Trockenlauf ohne Umstecken.** dGPU wach halten, selbstweckenden S3
   fahren. Die Karte steht dann beim Suspend in D0 statt in D3hot und
   durchläuft ihren vollen Suspend/Resume-Pfad, das Display hängt weiter an
   der iGPU — stirbt die SMU doch, kostet das einen Reboot, keinen toten
   Bildschirm. Nicht während einer Besprechung; `rtcwake` weckt sich selbst,
   der Power-Button ist nicht nötig (so am 25.08. verifiziert).

   ```sh
   echo on | sudo tee /sys/bus/pci/devices/0000:03:00.0/power/control
   sudo rtcwake -m mem -s 20
   journalctl -k -b --since -3min | grep -E '0000:03:00.0.*(SMU|fail|error|timeout)'   # muss leer bleiben
   echo auto | sudo tee /sys/bus/pci/devices/0000:03:00.0/power/control
   ```

2. **Render-GPU festlegen, bevor das Kabel wandert.** `boot_vga` steht auf
   der iGPU (`/sys/bus/pci/devices/0000:11:00.0/boot_vga` = 1), und wlroots
   nimmt das Boot-VGA-Gerät als primäre GPU. Wandert nur das Kabel, rendert
   Sway weiter auf der Raphael und kopiert jeden Frame per PCIe auf die
   RX 6400 — das Schlechteste aus beiden Welten. Zwei Wege: im BIOS
   "Primary Display" / "Initial Display Output" auf PCIe stellen (dann kippt
   `boot_vga`, ohne eine Zeile Config und auch für den TTY-Notfallpfad), oder
   `WLR_DRM_DEVICES=/dev/dri/by-path/pci-0000:03:00.0-card` vor dem Start
   von Sway. Unter SDDM geht Letzteres nur über eine eigene Session-Datei mit
   `Exec=env WLR_DRM_DEVICES=... sway`; der Login-Loop aus dem SDDM-Abschnitt
   war ein `bash -lc`-Wrapper-Problem, kein `env`-Problem. Die iGPU im BIOS
   **nicht** abschalten: sie ist der einzige Encoder der Kiste (Navi 24 hat
   keinen, s. Bildschirmaufnahme), `renderD129` muss bleiben.

3. **Umstecken** auf DP-1 oder HDMI-A-1 der RX 6400. Der Output heißt dann
   nicht mehr `HDMI-A-2` — `monitors.tmpl` anpassen und den Modus mit
   `swaymsg -t get_outputs` gegenprüfen (3440x1440@99.982Hz, s. dort).

4. **Derselbe rtcwake-Test mit Display an der dGPU**, mit `book` per SSH
   daneben. Rückfallebene: Kabel zurück an die iGPU, Reboot.

Preis, wenn es klappt: kein Runtime-Suspend mehr für die Karte (ein aktiver
CRTC hält sie in D0), also ein paar Watt mehr im Leerlauf. Gewinn: Sway
rendert 3440x1440@100 Hz auf der stärkeren Karte. Eine Zwischenlösung ohne
jedes Risiko gibt es heute schon: Display an der iGPU lassen und einzelne
Anwendungen mit `DRI_PRIME=1` (oder `DRI_PRIME=pci-0000_03_00_0`) auf der
RX 6400 rendern lassen — die Karte wacht dafür aus BACO auf, das tut sie laut
Journal seit Wochen fehlerfrei.

**Ergebnis (13.09.2026, 15:27–15:33).** Der Plan ist in anderer Reihenfolge
gelaufen als aufgeschrieben, mit demselben Resultat:

- Schritt 1 (Trockenlauf) ist ausgefallen — das Kabel war schon umgesteckt,
  als die Session wieder aufgenommen wurde.
- Schritt 2 hat das BIOS erledigt: nach dem Reboot um 15:27 meldet der Kernel
  `pci 0000:03:00.0: vgaarb: setting as boot VGA device`, `boot_vga` steht
  auf der RX 6400 und auf 0 für die Raphael. wlroots nimmt damit die dGPU als
  primäre Karte, `WLR_DRM_DEVICES` und eine eigene SDDM-Session-Datei sind
  nicht nötig. Direkt belegen lässt sich das ohne root nicht — sway hält
  `CAP_SYS_NICE` und ist deshalb nicht dumpable, `/proc/<pid>/fd` bleibt zu —
  aber Firefox hat ausschließlich `renderD128` offen, und das ist jetzt die
  RX 6400 (`/dev/dri/by-path/pci-0000:03:00.0-render`). Wer es genau wissen
  will: `sudo cat /sys/kernel/debug/dri/1/clients`.
- Schritt 3: `swaymsg -t get_outputs` zeigt `HDMI-A-1` mit
  3440x1440@99.982 Hz. Die Output-Zeile über die Monitor-Kennung in
  `monitors.tmpl` hat gegriffen, ohne dass etwas anzupassen war.
- Schritt 4: `sudo rtcwake -m no -s 30 && systemctl suspend` um 15:32:25,
  also über logind und damit über den Weg, den swayidle nachts nimmt.
  `PM: suspend entry (deep)` → `PM: suspend exit` um 15:33:06. Die dGPU
  macht wie erwartet `MODE1 reset` (kein Fehler, s. oben), dann
  `SMU is resumed successfully!`, `DMUB hardware initialized`. Kein
  `SMU: No response`, kein `sdma0 timeout`, kein s2idle. Der Monitor stand
  danach mit denselben 99.982 Hz, `power/runtime_status` der Karte auf
  `active` mit `control=auto` — der aktive CRTC hält sie in D0, das ist der
  im Plan erwartete Preis (Leistungsaufnahme laut hwmon ~8 W im Leerlauf).

Damit ist der einzige nicht getestete Fall (S3 mit dGPU in D0 und aktivem
CRTC) genau einmal positiv gelaufen. Eine Stichprobe, kein Dauerbeweis — die
Rückfallebene bleibt: Kabel zurück an `HDMI-A-2` der iGPU, Reboot, `boot_vga`
kippt von selbst zurück. Die Render-Node-Nummern haben den Wechsel überlebt:
`renderD129` ist weiterhin die Raphael (der einzige Encoder, s.
Bildschirmaufnahme), `renderD128` die RX 6400.

Was der Test nebenbei aufgedeckt hat: der Bildschirm war über den Suspend
hinweg **nicht gesperrt**. Im Session-Log (`~/.cache/wayland-errors`) steht
`sh: Zeile 1: hyprlock: Kommando nicht gefunden` — das Paket-Aufräumen vom
Mittag hat hyprlock mitgenommen, s. „Nachlese 13.09.2026".

## Workspaces auf zwei Monitoren (book)

**Gewollt.** Workspace 1 auf dem internen Panel, 2-9 auf dem externen Monitor.

**Was stattdessen passierte** (unter Hyprland, `hyprctl workspaces`,
03.09.2026): 1-6 alle auf `eDP-1`, und ausgerechnet die 7 als einzige auf dem
externen Schirm. Zwei unabhaengige Ursachen, die zusammen genau dieses Bild
ergeben. Beide sind **nicht compositor-spezifisch**, und beide waren nach dem
Sway-Umstieg wieder da — `sway/monitors.tmpl` hatte die Lehren aus diesem
Abschnitt nicht abbekommen (korrigiert am 08.10.2026).

**Ursache 1: der Monitor hiess nie so.** Im book-Zweig stand `DP-1`. Der
externe Monitor heisst aber `HDMI-A-1` (er haengt an der NVIDIA, s. naechster
Abschnitt). Damit lief die `output`-Zeile ins Leere und die Workspace-Bindung
band an nichts.

Das Tueckische daran: **es gibt keine Fehlermeldung.** Die AMD-Karte *hat*
einen `DP-1`-Connector, er ist nur `disconnected` — die Zeile ist also
syntaktisch gueltig und wartet einfach auf einen Monitor, der nie kommt.
`hyprctl configerrors` blieb leer, und `sway -C` meldet aus demselben Grund
auch nichts. Der echte Schirm kam derweil ueber den Fallback hoch. Deshalb
steht "echte Namen eintragen" schon oben in der Verifikation: der Punkt faellt
sonst durch jede Fehlerpruefung durch.

**Ursache 2: eine Workspace ohne Monitor-Angabe landet dort, wo sie entsteht.**
Gebunden waren nur 1 und 2; 3-9 hatten gar keine Angabe. Und "wo sie entsteht"
heisst je nach Typ etwas anderes:

| Workspace | woher | wo sie landete |
|---|---|---|
| 1-6 | `persistent:true`, entstehen beim Start | auf dem beim Start voreingestellten Monitor = Panel |
| 7-9 | nicht persistent, entstehen beim ersten `$mod+7` | auf dem gerade **fokussierten** Monitor = der externe |

Genau daher die verdrehte Aufteilung: die persistenten klebten am Panel, und
die 7 war die einzige, die je auf dem externen Monitor angelegt wurde.

**Fix.** Richtiger Name, und eine Monitor-Bindung an **jeder** Workspace, nicht
nur an 1 und 2. In `sway/monitors.tmpl` sind das neun `workspace <n> output
<name>`-Zeilen. Unter Sway faellt dabei zweierlei weg:

- **`persistent:true` hat kein Gegenstueck und braucht keins** — die leeren
  Buttons 1-6 erzeugt das `sway/workspaces`-Modul in Waybar selbst. Damit ist
  die Haelfte von Ursache 2 strukturell weg: es gibt keine Workspaces mehr, die
  schon beim Start irgendwo entstehen.
- **`default:true` hat kein Gegenstueck und braucht keins** —
  `workspace <n> output <name>` sagt bereits, wo der Workspace aufgeht.

Was bleibt, ist der zweite Teil: ohne Bindung geht eine Workspace auf dem
fokussierten Monitor auf. Deshalb stehen alle neun da.

Haengt der externe Monitor nicht dran (Laptop unterwegs), legt Sway die
verwaisten Workspaces von selbst aufs Panel — die Bindung ist kein Problem.

**Dazu zwei Zahlen, die am Geraet nachgesehen sind** (08.10.2026, aus den
DRM-/EDID-Daten, also unabhaengig vom Compositor):

- Das Panel kann `2560x1440`, nicht 1920 Pixel breit. Die `position`-Angabe des
  externen Monitors muss deshalb `2560 0` lauten; mit den vorher dort stehenden
  `1920 0` haetten sich die beiden Monitore um 640 px ueberlappt.
- Der externe Monitor ist DERSELBE physische C34H89x wie am cube (gleiche
  Seriennummer `H1AK500000`). Trotzdem steht im book-Zweig der Connector-Name
  und nicht die Monitor-Kennung: die Begruendung drueben ist das Umstecken
  zwischen iGPU und dGPU, und das gibt es hier nicht (s. naechster Abschnitt).

**Noch nicht unter Sway gegengeprueft.** Die Befunde stammen vom Hyprland-
Stand, die Konfiguration ist portiert. Nachsehen mit
`swaymsg -t get_outputs` (Namen, `current_mode`, `rect`) und
`swaymsg -t get_workspaces` (Feld `output`).

## Book: der externe Monitor haengt an der NVIDIA (teil-gelöst)

Das Gegenstueck zum cube-Abschnitt "Monitor gehoert an die iGPU" — mit dem
Unterschied, dass beim Book niemand das Kabel umstecken kann. Aufgenommen am
03.09.2026 unter Hyprland 0.56.2; die Hardware-Befunde gelten unabhaengig
davon, die Logzitate sind Hyprlands.

**Die Hardware.** Das Book hat zwei GPUs, und die Displays sind fest verteilt:

| Karte | Treiber | Connector | Display |
|---|---|---|---|
| `06:00.0` Radeon 680M (iGPU) | `amdgpu` (`card2`) | `eDP-1` | internes Panel |
| `01:00.0` RTX 3060 Mobile | `nouveau` (`card1`) | `HDMI-A-1` | externer C34H89x |

Die HDMI-Buchse ist also fest an der dedizierten Karte verdrahtet. `card1-eDP-2`
und `card1-DP-5` sind `disconnected`, ein MUX zum Umschalten gibt es nicht.
Genau deshalb steht im book-Zweig von `sway/monitors.tmpl` der Connector-Name:
die Zeile kann nicht durch Umstecken veralten.

**Was der Compositor daraus macht** (aus `hyprland.log`, `drm:`-Zeilen):

```
drm: Found 2 GPUs
drm: gpu /dev/dri/card2 becomes primary drm
drm: Starting backend for /dev/dri/card1, with driver nouveau with primary /dev/dri/card2
Renderer: AMD Radeon 680M (radeonsi, rembrandt, ACO, ...)      <- gerendert wird hier
Renderer: zink Vulkan 1.4(... RTX 3060 Laptop GPU (NVK GA106)) <- hierhin wird kopiert
GBM: Buffer is marked as multigpu, forcing linear
drm: No renderer attached to backend when required for blitting, initializing
```

Jedes Bild fuer den externen Monitor wird auf der AMD gerendert und dann
**ueber die PCIe-Bruecke auf die NVIDIA geblittet** — mit `forcing linear`,
also ohne jede Tiling- oder Kompressions-Optimierung. Dazu kommt, dass nouveau
eine Ampere-Karte **nicht hochtaktet**: die GA106 haengt auf Boot-Clocks fest.

Das ist kein Hyprland-Effekt. Sway/wlroots macht in derselben Lage dasselbe —
eine Karte rendert, die andere stellt dar, das Bild muss dazwischen kopiert
werden. Wie es dort im Log aussieht, ist noch nicht nachgelesen; die Stelle ist
die Sway-Logausgabe der Session (`sway -d` bzw. das Journal der Sitzung).

**Und der zweite Fund, direkt daneben:**

```
drm: Atomic supported, using atomic for modesetting          <- card2 (AMD)
WARN drm: failed to set DRM_CLIENT_CAP_ATOMIC, falling back to legacy   <- card1 (nouveau)
ERR  No support for gamma on the legacy iface
```

nouveau nimmt hier `DRM_CLIENT_CAP_ATOMIC` nicht an, der externe Monitor laeuft
also ueber die **Legacy-DRM-Schnittstelle**. Das ist eine Treiber-Eigenschaft
und damit auch unter Sway zu erwarten. Konkret spuerbar war es an der Maus: der
Cursor ging nicht ueber eine Atomic-Plane, sondern per
`drmModeSetCursor`-Ioctl, und zwar einmal pro Mausbewegung.

**Was daran repariert ist.** Der Modus. Im Modeset-Log stand

```
legacy drm: Modesetting CRTC, mode: clock 265250 ... vrefresh 50
```

— 50 Hz, weil fuer das Book `preferred` eingetragen war. Es ist derselbe
C34H89x wie am Cube, und fuer den steht die Lehre seit August schon im
cube-Abschnitt: der EDID-Vorzugsmodus hat 49.99 Hz, die Modusliste kennt aber
99.98 Hz. Die Book-Zeile hatte das nur nie mitbekommen. Unter Hyprland war der
Fix `highrr`; Sway kennt kein solches Schluesselwort, dort muss der Modus
ausgeschrieben werden (`mode 3440x1440@99.982Hz`, s. Begruendung zum Wert im
cube-Zweig von `sway/monitors.tmpl`). Beide Modi am Geraet gegengeprueft
(08.10.2026): die Liste kennt bei dieser Aufloesung nur 49.99, 59.97 und
99.98 Hz. Liegt nach dem Start eine der ersten beiden an, hat die Zeile nicht
gegriffen.

**Was nicht repariert ist.** Der Cross-GPU-Blit und der Legacy-Pfad bleiben —
die sind Eigenschaft von nouveau auf Ampere, nicht von der Config. Offene
Optionen, keine davon bisher probiert:

- **`akmod-nvidia` aus RPM Fusion.** Der proprietaere Treiber taktet die Karte
  hoch und kann Atomic. Preis: RPM Fusion ist bisher in `bootstrap.sh` gar
  nicht eingerichtet, und der Treiber braucht auf Wayland eigene
  Env-Variablen — fuer die es in diesem Repo keinen Ort gibt (keine eigene
  Session-Datei, s. bootstrap.sh).
- **Externen Monitor weglassen**, wenn es aufs Tempo ankommt. Das Panel haengt
  an der AMD, ist Atomic, laeuft mit 240 Hz und ist von alledem nicht betroffen.

## Citrix (`wfica`) auf dem Book

Der ICA-Client ist reines X11 und laeuft ueber XWayland. Zwei Effekte,
aufgenommen am 03.09.2026 unter Hyprland. **Beide sind mit dem Sway-Umstieg
wieder offen** — der eine, weil der Fix keinen Ort mehr hat, der andere war es
schon vorher.

### Klick landet oben links neben dem Cursor (unter Sway ungeprueft)

**Symptom.** In der Citrix-Sitzung traf der Klick nicht die Pfeilspitze,
sondern einen Punkt oben links davon. Ausserhalb von Citrix nicht bemerkbar.

**Ursache.** Der **Hotspot** ging verloren, und zwar im DRM-Pfad, nicht in
Citrix. Der externe Monitor haengt an der NVIDIA, und nouveau nimmt dort
`DRM_CLIENT_CAP_ATOMIC` nicht an (s. Abschnitt oben) — der Schirm laeuft also
ueber die Legacy-DRM-Schnittstelle. Und die Legacy-Cursor-Ioctl
(`drmModeSetCursor`/`drmModeMoveCursor`) hat **keine Hotspot-Eigenschaft**; die
gibt es erst in der Atomic-API als Plane-Properties `HOTSPOT_X`/`HOTSPOT_Y`.

Dass es ausgerechnet in Citrix auffiel, liegt daran, dass der ICA-Client die
Cursor der Remote-Sitzung durchreicht — mit deren eigenen Hotspots. Der
Standard-Pfeil hat seinen Hotspot fast in der Ecke, da faellt ein verlorener
Hotspot kaum auf; ein Windows-Cursor mit Hotspot in der Mitte schon.

**Der Hyprland-Fix war `cursor:no_hardware_cursors = true`** im book-Zweig:
damit ist die DRM-Cursor-Plane komplett aus dem Spiel, der Compositor rendert
den Cursor mit ins Bild und rechnet den Hotspot selbst. Versatz weg, verifiziert
— und die Befuerchtung, dass jede Mausbewegung dann ein Re-Render plus
Cross-GPU-Blit ausloest und der externe Schirm zaeher wird, hat sich im
Gebrauch nicht bestaetigt.

**Unter Sway steht das offen.** Sway hat keine entsprechende
Konfigurationsoption. Der Hebel waere `WLR_NO_HARDWARE_CURSORS=1`, und das ist
eine Umgebungsvariable fuer den Compositor-Prozess selbst — in diesem Repo gibt
es dafuer keinen Ort, weil bewusst keine eigene Session-Datei existiert
(`bootstrap.sh` begruendet das mit dem Login-Loop). Der Fix ist deshalb
**nicht vorsorglich portiert**: es ist gut moeglich, dass wlroots den Hotspot
auf dem Legacy-Pfad selbst herausrechnet und das Problem hier gar nicht
auftritt.

**Pruefen, bevor man etwas baut:** in der Citrix-Sitzung auf dem externen
Monitor einmal auf etwas Kleines klicken und sehen, ob die Pfeilspitze trifft.
Trifft sie, ist die Sache erledigt. Trifft sie nicht, braucht es erst einen Ort
fuer Compositor-Umgebungsvariablen — und der ist eine eigene Entscheidung, kein
Einzeiler.

### Windows-Cursor auf allen Schirmen, solange Citrix sichtbar ist (offen)

**Symptom.** Sobald das Citrix-Fenster **sichtbar** ist, zeigt der Cursor auch
auf dem internen Panel den Windows-Pfeil — ueber `foot`, ueber allem. Sobald
die Citrix-Workspace nicht mehr angezeigt wird, ist der Cursor sofort wieder
richtig. Nicht davon abhaengig, welches Fenster den Fokus hat: gemessen mit
dem aktiven Fenster = `foot`, Zeiger ueber `foot`, trotzdem Windows-Pfeil.

**Was es NICHT ist** (durchgeprueft, damit es niemand nochmal prueft):

- **Kein Pointer-Grab.** In `/opt/Citrix/ICAClient/wfica` kommt `XGrabPointer`
  gar nicht vor — nur `XUngrabPointer` und, davon getrennt, `fp_XGrabKeyboard`.
  Ein X11-Pointer-Grab haette den Cursor legitim global gesetzt; der Weg ist es
  also nicht.
- **Kein fehlendes Cursor-Theme.** Ein anderes Theme zur Laufzeit zu setzen
  aendert nichts.
- **Keine Fokus-Einstellung.** `follow_mouse`/`mouse_refocus` und Verwandte
  standen alle auf Default und plausibel.
- **Kein Software-Cursor-Nebeneffekt.** Tritt mit Hardware- wie mit
  Software-Cursorn auf.

**Was es sehr wahrscheinlich ist.** `strings` auf dem Client zeigt neben
`XDefineCursor` die internen Namen **`twSetCursorIfVisible`** und
`twRestoreCursorIfMatch` — der Client setzt den Cursor also an *Sichtbarkeit*
gekoppelt, nicht an Zeigerfokus. Unter echtem X11 ist das harmlos, weil
`XDefineCursor` pro Fenster gilt und nur greift, solange der Zeiger drin ist.
Ueber XWayland wird daraus ein `wl_pointer.set_cursor`, und das gilt fuer den
einen Zeiger des Compositors. Genau die Sichtbarkeits-Kopplung erklaert, warum
das Ausblenden der Workspace es sofort behebt.

Dass der Mechanismus in XWayland und nicht im Compositor sitzt, heisst auch:
der Umstieg auf Sway aendert daran voraussichtlich nichts. Verwandte offene
Tickets: hyprwm/Hyprland
[#7698](https://github.com/hyprwm/Hyprland/issues/7698) und
[#9480](https://github.com/hyprwm/Hyprland/issues/9480) — beide beschreiben den
XWayland-Pfad, nicht eine Hyprland-Eigenheit.

**Womit man lebt.** Der Zustand ist kosmetisch — Klicks landen richtig, nur das
Bild des Cursors stimmt nicht. Bleibt Citrix ausgeblendet, ist es weg.
Waere es mehr als kosmetisch, waere der naechste Schritt, `wfica` in einem
**eigenen, verschachtelten X-Server** (Xephyr bzw. rootful XWayland) laufen zu
lassen: dann sind seine `XDefineCursor`-Aufrufe in dessen Fenster eingesperrt
und erreichen den Zeiger des Compositors nicht mehr. Preis waeren Zwischenablage
und Fensterintegration. Bisher nicht probiert.


## Suspend hängt sich auf (gelöst: kein s2idle-Fallback)

**Symptom.** Nach dem automatischen Suspend kommt der Rechner nicht zurück:
schwarzer Bildschirm, keine Reaktion auf Tastatur oder Maus, kein SSH-Login,
und der Power-Button am Gehäuse fährt ihn auch nicht herunter. Es bleibt der
harte Reset.

**Was tatsächlich passiert** (Journal vom 24.08.2026, Boot `-1`, ab 09:03:25 —
`journalctl -b -1` und dann nach `PM: suspend` suchen):

1. Der Idle-Daemon (damals hypridle, heute swayidle) löst nach 15 min
   `systemctl suspend` aus. systemd probiert
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

**Gelöst: der Auslöser in Schritt 1** (25.08.2026). Die Vermutung "zuckende
Funkmaus" war falsch — der Abbruch war nicht sporadisch, sondern **zu 100 %
reproduzierbar**: vier Suspend-Versuche, vier Abbrüche nach je zwei Sekunden,
auch bei komplett unberührter Tastatur.

Die Spur führt über zwei Zähler, die pro Versuch um genau 1 steigen:

```console
$ cat /sys/power/pm_wakeup_irq
7
$ grep -E '^ *(7|28):' /proc/interrupts | awk '{print $1, $NF}'
7: pinctrl_amd          # AMD-GPIO-Controller
28: ACPI:Event          # amd_gpio Pin 3
$ cat /sys/firmware/acpi/interrupts/gpe02
       3  EN     enabled      unmasked
```

GPIO-Pin 3 ist auf diesem Board der `PCIE_WAKE#`-Eingang. Dahinter steckt das
PME des Root-Ports `00:02.1` (`GPP7`), und an dem hängt der komplette
Chipsatz-Zweig — unter anderem der USB-Controller `0f:00.0`:

```
00:02.1 ─ 05:00.0 ─ 06:00.0 ┬─ … ─ 0d:00.0  Realtek RTL8126 5GbE
                            └─ … ─ 0f:00.0  AMD 800-Series Chipset USB
```

**Bewiesen per Bisect.** Weckquellen einzeln stillgelegt, dazwischen je ein
`rtcwake -m mem -s 20` (weckt sich selbst, kein Power-Button nötig). Die
Unterscheidung läuft über die Dauer — unter 15 s heißt abgebrochen:

```console
$ sudo rtcwake -m mem -s 20            # unverändert
   abgebrochen (2s)
$ echo disabled | sudo tee /sys/bus/usb/devices/1-5.4/power/wakeup
$ sudo rtcwake -m mem -s 20            # ohne Weckrecht für den Unifying-Empfänger
   SUSPEND OK (25s geschlafen)
```

Es ist also der **Logitech-Unifying-Empfänger** (`046d:c548`), und zwar nicht,
weil er zuckt, sondern weil er an `0f:00.0` hängt und dort dauerhaft PME# zieht.
Die Hama-Maus mit identisch freigeschaltetem Weckrecht blockiert nichts — sie
saß von Anfang an an `11:00.3`, einem CPU-seitigen Controller.

**Der Fix ist physisch, nicht konfigurativ.** Der Empfänger gehört in eine
Buchse an `11:00.3`, `11:00.4` oder `12:00.0`. An welcher Buchse das hängt,
verrät nur das Umstecken selbst:

```console
$ readlink -f /sys/bus/usb/devices/3-2 | grep -oE '0000:[0-9a-f:.]+' | tail -1
0000:11:00.3
```

Verifiziert am 25.08.2026: 20 s echter S3, danach dGPU wieder
`suspended`/D3hot, Monitor und Netz sauber zurück, keine Fehler im Journal.
Ein Wechsel auf eine andere Buchse **desselben** Controllers reicht nicht — mit
dem Empfänger auf `1-6` statt `1-5.4` bricht es genauso ab.

**Aufwecken geht nur über den Power-Button.** Die Tastatur weckt nicht, auch
nicht mit dem Empfänger am CPU-Controller — ausprobiert, und der Empfänger
meldet nach dem Resume `wakeup_count=0`, hat also nichts gemeldet. `pm_wakeup_irq`
zeigt zwar IRQ 33 (PME des Root-Ports `00:08.1`), das ist aber nur der erste
IRQ *nach* dem Resume und keine Aussage über die Quelle: beim Hochfahren der
Geräte feuern die PMEs an den Root-Ports ohnehin. Nicht darauf hereinfallen.

**Alternative: udev-Regel** (`ATTR{power/wakeup}="disabled"` für
`046d:c548`). Der ursprüngliche Einwand gegen sie war, sie koste das Wecken per
Tastatur — das stimmt nicht, denn das funktioniert hier ohnehin nicht (s. o.).
Sie kostet also nichts und wäre sogar robuster als die Buchse: eine Regel
greift auch dann noch, wenn der Empfänger nach einem Umbau wieder in einer
Chipsatz-Buchse landet. Die Buchsenlösung hat dafür den Vorteil, ohne
zusätzliche Datei auszukommen. Beides ist vertretbar; aktuell steckt nur die
Buchse.

**Nicht genommen: `acpi_mask_gpe=0x02`.** Der maskierte GPE nimmt nur die
*Meldung* über den GPIO-Pfad weg; das PME liegt weiter an, und der Kernel nennt
dann eben die zweite Quelle:

```console
$ echo mask | sudo tee /sys/firmware/acpi/interrupts/gpe02
$ systemctl suspend                    # bricht weiterhin ab
$ cat /sys/power/pm_wakeup_irq
32                                     # PCIe PME 0000:00:02.1 statt 7
```

**Merksatz fürs nächste Mal.** `Wakeup pending. Abort CPU freeze` ist keine
Aussage über das Gerät, das zuckt, sondern über den PCIe-Zweig, an dem es
steckt. Erst `pm_wakeup_irq` lesen, dann den Zweig auflösen — nicht raten.

## Fester Workspace pro App (nur `cube`)

Die Fenster liegen an diesem Arbeitsplatz immer gleich, also steht das auch so
in der Config — im cube-Zweig von `sway/rules.tmpl`:

| WS | App | Klasse |
|---|---|---|
| 1 | Firefox | `org.mozilla.firefox` |
| 2 | Citrix | `Wfica` |
| 3 | Thunderbird | `org.mozilla.thunderbird_esr` |
| 4 | Slack, Element | `com.slack.Slack`, `im.riot.Riot` |
| 5 | *frei* | — |
| 6 | KeePassXC | `org.keepassxc.KeePassXC` |

- **Fensterregel, kein Autostart.** Nichts wird beim Login gestartet; die Regel
  greift erst, wenn man die App selbst öffnet. Wer Thunderbird nie startet, hat
  eine leere 3.
- **Und kein Pinning.** Die Regel greift genau einmal, im Moment des
  Fensteröffnens. Danach ist das Fenster ein Fenster wie jedes andere —
  `$mod+SHIFT+<n>` schiebt es weiter, und es bleibt dort. Die Regel holt es
  nicht zurück.
- **`foot` steht bewusst nicht in der Liste.** Ein Terminal soll dort aufgehen,
  wo man gerade arbeitet; ein fester Platz wäre hier genau die falsche Hilfe.
- **`assign` platziert STILL**, der Workspace wird also *nicht* mitgewechselt:
  die App geht im Hintergrund auf, man bleibt stehen, wo man ist. Unter Hyprland
  war das früher andersherum (dort stand die Regel bewusst ohne `silent`). Wer
  das alte Verhalten will, ersetzt die Zeile durch die auskommentierte Variante
  in `sway/rules.tmpl` (`move container to workspace number N, workspace number
  N`) — die hängt allerdings an der Auswertungsreihenfolge zweier Befehle und
  ist an dieser Stelle noch nicht nachgemessen.
- **Warum nur auf dem cube:** die Aufteilung hängt an diesem Arbeitsplatz —
  Citrix für den Kunden, ein Monitor. Das book verteilt Workspaces über zwei
  Monitore (`sway/monitors.tmpl`) und braucht eine eigene Aufteilung, sobald sie
  feststeht. Deshalb ist die Regeldatei ein chezmoi-Template
  (`sway/rules.tmpl`); Zielname und `include`-Zeile in `sway/config` bleiben
  unverändert.
- Citrix hat in Waybars `window-rewrite` jetzt auch ein Icon: 🪟 (U+1FA9F) für
  die Windows-Sitzung, die dort drin hängt — 🖥 war schon für `foot` vergeben.
  Das Zeichen ist mit `fc-list :charset=1fa9f` gegen NotoEmoji-Regular geprüft,
  es ist jung genug (Emoji 13.0), dass sich das lohnt.
- Die Klassen sind alle am 08.09.2026 live abgelesen (heute: `swaymsg -t
  get_tree`), bis auf
  KeePassXC — das lief beim Gegenprüfen nicht, die Klasse stammt aus der bereits
  verifizierten `window-rewrite`-Liste in `waybar/config.jsonc.tmpl`.

## Keybind-Übersicht

`SUPER+F1` oder der Klick auf **"Keys"** in der Waybar zeigt die Tastenbelegung
als durchsuchbares fuzzel-Popup (tippen filtert).

Der Witz daran: **Quelle ist `sway/binds` selbst.** `dot_local/bin/keybinds`
parst die Datei — Bindings *und* die `# --- Abschnitt ---`-Kommentare, aus denen
die Gliederung im Popup wird. Eine neue Bindung taucht damit automatisch auf.
Eine von Hand gepflegte Zweitliste wäre nach dem dritten neuen Binding falsch,
und das Repo hat mit `drift-check.sh` schon genug Meinung zu Abweichungen.

- Bewusst **nicht** die Live-Bindungsliste des Compositors: die kennt zwar den
  laufenden Zustand, liefert
  aber Modmasken statt Tastennamen und hat keine Abschnitte. Der Unterschied
  fällt nur auf, wenn man Bindings zur Laufzeit ändert —
  die fehlen dann in der Übersicht.
- `$mod` wird beim Anzeigen zu `SUPER`, und `~/.local/bin/` fällt bei den
  eigenen Skripten weg, damit die Zeilen lesbar bleiben.
- **F1 statt des sonst üblichen `SUPER+/`**: der Slash liegt auf de-Layout
  hinter `SHIFT+7`, das Binding wäre also faktisch ein Dreifingergriff.
- Waybar-Modul ist `custom/keybinds`, Beschriftung **Text** ("Keys") wie der
  Rest der Bar — es ist weiterhin kein Nerd Font installiert.

## Benachrichtigungen (swaync)

Seit 10.09.2026 macht **SwayNotificationCenter** (`swaync`) die
Benachrichtigungen, vorher war es mako. Zwei Dinge kamen dazu, und beide waren
der Grund für den Wechsel: jedes Popup hat ein **✕** zum Wegklicken, und es gibt
ein **Panel mit den vergangenen Meldungen** — auch denen, die man verpasst hat.

| Aktion | Taste | Waybar |
|---|---|---|
| Panel auf/zu | `SUPER`+`N` | Linksklick auf **Msg** |
| Nicht stören (DND) | `SUPER`+`SHIFT`+`N` | Rechtsklick auf **Msg** |
| Einzelne Meldung schließen | — | **✕** am Popup |
| Alle löschen | — | Knopf in der Kopfzeile des Panels |

Das Waybar-Modul zeigt `Msg 0` … `Msg 3` (Anzahl ungelesener Meldungen) und im
DND-Zustand `DND 2`. Die Farben folgen der Logik der übrigen Bar: gedämpft im
Normalfall, Mauve wenn etwas ansteht, Gelb für DND — gelb wie der `Wach`-Schalter,
weil beides Zustände sind, die man aktiv wieder abstellen muss.

### Warum nicht mehr mako

Beide Wünsche waren mit mako 1.11 nicht zu erfüllen, und zwar nicht aus
Konfigurationsmangel, sondern prinzipiell:

- **Kein Schließen-Knopf.** mako zeichnet ein Popup mit cairo als *eine* Fläche.
  Es gibt darin keine Widgets, also auch keine Stelle, die einen eigenen Klick
  bekommen könnte. Konfigurierbar ist nur, was ein Klick **aufs ganze Popup**
  tut (`on-button-left`/`-right`/`-middle`). Ein `✕` in die `format`-Zeile zu
  schreiben wäre gegangen — es wäre aber ein gemaltes Zeichen ohne eigene
  Funktion gewesen, also genau die Art Attrappe, die man ein halbes Jahr später
  für kaputt hält.
- **Keine brauchbare History.** `makoctl history` und `makoctl restore` gibt es
  (`makoctl help`, mako 1.11.0), aber das ist ein Ringpuffer im laufenden
  Prozess — `max-history` steht per Default auf 5 und der Inhalt ist nach jedem
  Neustart des Daemons weg. Das trägt "die eine Meldung von eben nochmal", nicht
  "was habe ich heute Vormittag verpasst".

swaync bringt beides von Haus aus, ist ein reguläres Fedora-Paket
(`SwayNotificationCenter`, 0.12.6 in `updates`, **keine COPR** — dieselbe
Überlegung wie bei swaybg statt hyprpaper) und spricht dieselbe
`org.freedesktop.Notifications`-Schnittstelle. Kein Skript im Repo musste
deshalb angefasst werden: `notify-send` aus libnotify bleibt der Client, und
`record` verlässt sich weiter darauf, dass eine kritische Meldung stehen bleibt,
bis man sie wegklickt (vorher `[urgency=high] default-timeout=0`, jetzt
`timeout-critical: 0`).

### Das Waybar-Modul

`custom/notification` in `waybar/common.jsonc.tmpl` — es ist damit in **beiden**
Sessions da, nicht nur unter Sway.

Der eine Punkt, der es von den anderen Custom-Modulen unterscheidet: es hat
**kein `interval` und kein `signal`**. `swaync-client -swb` ist kein
Statusaufruf, der einmal läuft und sich beendet, sondern ein Abonnement — der
Prozess hängt am Daemon und schreibt bei jeder Änderung eine neue JSON-Zeile.
Waybar erkennt genau daran den Dauerbetrieb. Ein `interval` würde den Prozess im
Takt abschießen und neu starten, ein `signal` wäre überflüssig, weil es nichts
zu pollen gibt. Die Anzeige steht dadurch sofort statt nach bis zu einer Sekunde
(anders als bei `custom/recording`, das wirklich pollt).

Text statt Glyphe wie überall — es ist weiterhin kein Nerd Font installiert. Der
DND-Zustand steht deshalb als **Wort** da (`DND`) und nicht nur als Gelbton: das
ist der eine Zustand, in dem man sich sonst wundert, warum nichts mehr aufpoppt,
und eine Farbe allein liest man nach zwei Wochen nicht mehr.

Die Formatzeile heißt `"{icon} {text}"` und **nicht** `"{icon} {}"`. Waybar
mischt seit dem Umstieg auf fmt 10 keine benannten und positionellen
Platzhalter mehr in einem Format; die kurze Schreibweise kostet:

```
[error] custom/notification: mixing manual and automatic argument indexing
        is no longer supported; try replacing "{}" with "{text}"
```

Das steht **nur im Log**. In der Bar sieht man eine Lücke und sucht den Fehler
im Daemon. (Live über den Haufen gefahren beim Bauen des Moduls, 10.09.2026 —
in `common.jsonc.tmpl` steht die Warnung deshalb direkt an der Zeile.)

### Konfiguration: zwei Dateien, eine davon ohne Kommentare

- `swaync/config.json` — Verhalten (Position, Timeouts, Panelbreite, die
  deutschen Beschriftungen).
- `swaync/style.css` — Aussehen. **GTK 4**, nicht cairo wie mako.

**`config.json` ist die einzige Datei im Repo ohne Kommentare**, und das ist
keine Nachlässigkeit: JSON kennt keine. Die Begründungen zu den Werten stehen
deshalb hier. Gegen Tippfehler hilft `"$schema"` in Zeile 2 — die vollständige
Liste aller Schlüssel samt Defaults steht in
`/etc/xdg/swaync/configSchema.json`.

- `timeout: 6`, `timeout-critical: 0` — 1:1 die Zeiten aus der alten
  `mako/config` (swayncs eigener Default wäre 10). Kritisches bleibt stehen,
  bis man es wegklickt; darauf verlässt sich `dot_local/bin/record`.
- `notification-window-width: 400` statt mako-`width: 320` — die 80 px sind der
  Platz, den das ✕ und die Aktionsknöpfe brauchen, ohne den Text zu quetschen.
- `relative-timestamps: false` — der Default zeigt „26 minutes ago", und zwar
  **auf Englisch**: es gibt keine deutsche Übersetzung
  (`/usr/share/locale/de/LC_MESSAGES` enthält nichts von swaync). In einer sonst
  deutschen Oberfläche ist der absolute ISO-Zeitstempel das kleinere Übel — und
  für die eigentliche Frage ans Panel („wann kam das?") ohnehin die bessere
  Antwort.
- `text-empty` und die Texte unter `widget-config` — dieselbe Baustelle,
  einmal eingedeutscht.
- `widgets: ["title", "dnd", "notifications"]` — swayncs Default stellt
  `"inhibitors"` voran. Das Widget listet Anwendungen, die Benachrichtigungen
  unterdrücken; das macht hier niemand, und eine dauerhaft leere Überschrift im
  Panel ist Fläche ohne Aussage.
- `transition-time: 0` — Deko-Nullpunkt. Sway animiert nichts, das Panel soll
  sich nicht als Einziges einblenden.
- `fit-to-screen: true` + `control-center-width: 420` — das Panel geht über die
  volle Höhe am rechten Rand. Auf dem cube (3440×1440) ist das ein schmaler
  Streifen und stört nichts. `control-center-height` steht bewusst **nicht**
  dabei: der Wert wird bei `fit-to-screen` ignoriert und wäre ein Regler, an dem
  man später vergeblich dreht.
- `keyboard-shortcuts: true` — `Escape` schließt das Panel, Pfeiltasten
  navigieren. Ohne das ist ein Panel, das man per Taste öffnet, per Taste nicht
  wieder zuzubekommen.
- `ignore-gtk-theme: true` und `cssPriority: "user"` — beides steht so auch in
  swayncs mitgeliefertem `/etc/xdg/swaync/config.json`; hier bewusst
  übernommen, nicht weggelassen. `ignore-gtk-theme` löscht `GTK_THEME` aus der
  Umgebung, damit ein GTK-Theme nicht in unsere Farben malt. Der Fall tritt auf
  beiden Hosts gerade nicht ein (es gibt kein `~/.config/gtk-4.0/gtk.css` und
  `bootstrap.sh` setzt kein `GTK_THEME`) — der Tag, an dem sich das ändert, soll
  aber nicht der Tag sein, an dem das Panel plötzlich Adwaita-blau ist.

### Das Stylesheet: Variablen statt Selektoren

Der wichtigste Punkt an `swaync/style.css`, und der einzige, der beim Ändern
wirklich weh tut: **swaync lädt zwei Stylesheets.** Erst seinen Default aus
`/etc/xdg/swaync/style.css`, dann unseren. Im Log steht das wörtlich:

```
Loading CSS: "/etc/xdg/swaync/style.css"
Loading CSS: "/home/zoellert/.config/swaync/style.css"
```

Beide landen auf derselben GTK-Priorität. Bei **gleicher Spezifität** gewinnt
also das später geladene — unseres. Bei geringerer verliert es, und zwar
**still**: kein Fehler, keine Warnung, die Regel ist einfach wirkungslos.
Dieselbe Falle wie eine Sway-Fensterregel mit dem falschen Feld.

Der Default ist durchgehend über **CSS-Custom-Properties** gebaut
(`background: rgba(var(--noti-bg), var(--noti-bg-alpha))`), und genau das ist
der vorgesehene Angriffspunkt: `:root` einmal überschreiben, und sämtliche
Regeln des Defaults ziehen die neuen Werte. Deshalb besteht unser Stylesheet
fast nur aus einem `:root`-Block und hat nur eine Handvoll echter Selektoren —
für die Fälle, in denen es keine passende Variable gibt (Rahmenfarbe nach
Dringlichkeit, der gedämpfte Zeitstempel, das eckige Avatarbild). Jeder davon
ist so lang wie sein Gegenstück im Default; kürzer verliert er. Die Ketten sind
brutal:

```css
.notification-row .notification-background .notification
  .notification-default-action .notification-content .text-box .time
```

Zwei Fallen bei den Variablen selbst:

- `--noti-bg` ist eine **Komponentenliste** (`30, 30, 46`), keine Farbe — der
  Default setzt sie in `rgba(var(--noti-bg), var(--noti-bg-alpha))` ein. Ein
  `#1e1e2e` an dieser Stelle ergibt schwarz.
- `--border-radius: 0` erwischt fast alles, aber nicht das Avatarbild: dort
  steht im Default ein fester `border-radius: 100px`, keine Variable. Dafür
  braucht es die eine lange Regel.

Änderungen greifen ohne Abmelden: `swaync-client -R` lädt die Konfiguration neu,
`swaync-client -rs` das Stylesheet.

### Der Umstieg (einmalig, von Hand)

`chezmoi apply` legt die neuen Dateien an, aber zwei Dinge macht es nicht:

```
sudo dnf install SwayNotificationCenter
sudo dnf remove mako          # sonst meldet drift-check.sh es als überzählig
rm -rf ~/.config/mako         # chezmoi löscht eine entfernte Quelle NICHT mit
```

Danach **abmelden und neu anmelden**, nicht nur `SUPER`+`SHIFT`+`C`. Zwei
Gründe: ein Sway-Reload startet die `exec`-Zeilen ohnehin nicht neu, und mako
und swaync belegen denselben DBus-Namen `org.freedesktop.Notifications` — läuft
mako noch, bekommt swaync ihn nicht und beendet sich still. Das Symptom wäre
"gar keine Benachrichtigungen mehr", und man suchte es in der Konfiguration.

### Verworfen

- **mako behalten und die History per `makoctl history -j` in ein
  fuzzel-Popup kippen** (dasselbe Muster wie `bt`, `wifi`, `audio-out`). Hätte
  ins Repo gepasst und wäre ein Skript ohne neues Paket gewesen — scheitert aber
  an der Quelle: fünf flüchtige Einträge sind kein Notification-Center. Und den
  Schließen-Knopf hätte es weiterhin nicht gegeben.
- **dunst** statt swaync: kann Kontextmenü und `history-pop`, aber ebenfalls
  keinen Knopf am Popup und kein Panel. Damit löst es genau denselben halben
  Teil des Problems wie mako, für denselben Preis eines Daemon-Wechsels.
- **swayfx/eigene Bastelei** für die Optik: nicht angefasst. Das Panel ist GTK,
  es reicht ein Stylesheet.

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
  Rückmeldung — swaync ist der Anzeige-Daemon, der *Client* (`notify-send`) fehlt
  auf einem Minimal Install komplett. Ohne ihn kann kein Skript im Repo eine
  Notification schicken. Fehlt er trotzdem, bleibt das Skript still und macht
  den Screenshot ohne Meldung.
- **Kein grimblast** (hyprland-contrib): das hing an derselben COPR wie
  hyprland selbst, deren Inhalt hier niemand kontrolliert — dieselbe Überlegung
  wie bei hyprpaper/swaybg beim Wallpaper, und mit Hyprland ohnehin erledigt.
- Der Fenster-Modus listet über `swaymsg -t get_tree` nur die **sichtbaren
  Fenster** (`.visible == true`, plus `.pid` gegen die Container-Knoten) und gibt
  deren Rechtecke an `slurp -r`. Damit rastet die Auswahl auf Fensterkanten ein,
  statt pixelgenaues Zielen zu verlangen.
- `screen` nutzt `grim -o <monitor>` statt Koordinaten aus `swaymsg -t get_outputs`:
  auf skalierten Monitoren fallen Pixel- und Logikmaße auseinander, `-o` lässt
  grim selbst rechnen.
- Der Dateiname hat Sekundenauflösung. Zwei Screenshots in derselben Sekunde
  überschreiben sich — praktisch nur mit gedrückt gehaltener Taste erreichbar.
- Vorher lag das als zwei Einzeiler direkt in der binds-Datei
  (`grim -g "$(slurp)" - | wl-copy`). Die Semantik von `SHIFT+Print` hat sich
  dabei geändert: früher alle Monitore, jetzt der aktive.

## Bildschirmaufnahme

`dot_local/bin/record`, das Video-Gegenstück zum Screenshot — gleiche Modusnamen,
damit es kein zweites Vokabular zu lernen gibt:

| Taste | Modus | Was |
|---|---|---|
| `SUPER`+`SHIFT`+`R` | `region` | Rechteck mit der Maus (slurp) |
| `SUPER`+`SHIFT`+`CTRL`+`R` | `window` | Fenster anklicken — slurp rastet auf die Kanten ein |
| `SUPER`+`SHIFT`+`ALT`+`R` | `screen` | Der Monitor der aktiven Workspace |

Alle drei rufen `record toggle`: **läuft schon eine Aufnahme, beendet jede der
drei Tasten sie.** Man soll sich nicht merken müssen, mit welcher man angefangen
hat. Ablage ist `<XDG-Videoordner>/Screenrecordings`, überschreibbar per
`$RECORD_DIR`.

```sh
record region|window|screen [--audio[=GERÄT]]
record stop
record status          # JSON für Waybar
record toggle [modus]  # was die Tasten tun
```

- **`wf-recorder`, nicht OBS und nicht gpu-screen-recorder.** OBS ist ein Studio
  mit Szenen und Quellen für eine Aufgabe, die hier aus einem Tastendruck
  besteht; gpu-screen-recorder liegt nur in Fremd-Repos. wf-recorder steht
  regulär in Fedora (0.6.0 in F44), hängt also an keiner COPR, und ist **ein**
  Prozess, den ein Toggle sauber per Signal beendet. Dieselbe Überlegung wie
  swaybg statt hyprpaper und grim statt grimblast.
- **Warum `R` und nicht die Kamera-Taste.** Die MX Keys auf dem cube schickt eine
  feste Kombination (`Win+Shift+S`), und ihre drei stapelbaren Varianten sind von
  den Screenshots belegt. Für eine Aufnahme bliebe nur
  `SUPER+SHIFT+CTRL+ALT+S` — ein Vierfingergriff für eine Taste, die man mitten
  in einer Aufnahme trifft. `R` war auf beiden Hosts komplett frei
  (gegen die Bindungsliste geprüft), beide bekommen deshalb dieselbe Bindung —
  anders als bei den Screenshots, wo zwei Sätze nebeneinander stehen müssen.
- **Ton ist aus, solange nichts anderes gesagt wird.** Ein Toggle, der unbemerkt
  das Mikrofon mitschneidet, ist die falsche Vorgabe. Ein `--audio` schaltet ihn
  für einen CLI-Aufruf dazu, `RECORD_AUDIO=1` dauerhaft — nur so bekommt auch der
  Keybind Ton, der kriegt ja keine Argumente mit. `--audio` allein nimmt die
  Standard-Quelle, also das **Mikrofon**. Für den Ton, der aus den Lautsprechern
  kommt, braucht es die Monitor-Quelle des Sinks:

  ```sh
  pactl list sources short | grep monitor      # Namen ansehen
  record screen --audio=alsa_output.…​.monitor
  ```
- **VP9 in `.webm`, und h264 gibt es hier nicht.** Das ist keine Vorliebe,
  sondern auf dieser Kiste nachgemessen (08.09.2026):

  | Versuch | Ergebnis |
  |---|---|
  | `-c libx264` | `Failed to find the given codec` |
  | `-c h264_vaapi -d /dev/dri/renderD128` (RX 6400) | Filtergraph-Fehler |
  | `-c h264_vaapi -d /dev/dri/renderD129` (Raphael-iGPU) | `avcodec_open2 failed: Function not implemented` |

  Fedora liefert `ffmpeg-free` **ohne** die patentbehafteten Encoder, und
  `mesa-va-drivers` ist gar nicht installiert — die Variante *mit* h264 heißt
  `mesa-va-drivers-freeworld` und kommt aus RPM Fusion, das hier bewusst
  nirgends eingebunden ist. h264 fehlt also in Software **und** auf der GPU;
  wf-recorders Vorgabe ist deshalb libvpx-vp9. (Die RX 6400 wäre ohnehin die
  falsche Karte: Navi 24 hat gar keinen Encoder. Enkodieren könnte nur die
  Raphael-iGPU auf `renderD129`.)

  Entscheidend ist dann der **Container**: `.mp4` ergäbe VP9-in-MP4, genau die
  Kombination, an der Slack, QuickTime und der Windows-Player aussteigen. VP9
  gehört in eine `.webm` — die spielen Firefox, Element und Windows problemlos.
  In der Praxis bestätigt: eine so aufgenommene Datei ist ohne Nacharbeit auf
  Mastodon hochgeladen und dort abgespielt worden (08.09.2026). Für den
  Alltagsfall reicht webm also, der Absatz unten ist der Notfallplan.
  **Wer h264 braucht** (ein Mac-Gegenüber, ein altes Schnittprogramm), kommt um
  RPM Fusion nicht herum: `mesa-va-drivers-freeworld` für die iGPU, dann
  `RECORD_ARGS="-c h264_vaapi -d /dev/dri/renderD129"`. Das ist eine
  Repo-Entscheidung, keine Skript-Einstellung — bisher hängt hier nichts an
  einem Fremd-Repo, und das war der Punkt.
- **30 fps statt der Monitorwiederholrate.** Der cube läuft mit ~100 Hz auf
  3440×1440, encodiert wird in Software. Bei 30 fps sind das gemessene 150–190 %
  eines Kerns — von 24 also gut verkraftbar, und die Bildrate hält durch.
  `RECORD_FPS` hebt an; danach lohnt ein Blick, ob wirklich alle Frames ankommen.
  `RECORD_ARGS` ist der Notausgang für alles Weitere (z. B.
  `-p deadline=good` für Qualität statt Realtime) — bewusst eine Durchreiche
  für alle wf-recorder-Optionen, statt für jede eine eigene Flagge.
- **Kein `all`.** wf-recorder nimmt genau **einen** Output auf. Auf dem cube ist
  das ohnehin dasselbe wie `screen`; auf dem book muss man sich entscheiden. Bei
  `region`/`window` leitet das Skript den Output aus der **Auswahl** ab
  (`swaymsg -t get_outputs`), nicht aus der aktiven Workspace — man zieht das Rechteck
  mit der Maus, und die kann auf dem anderen Monitor landen. Die Kantenlängen
  kommen dabei in physischen Pixeln, `x`/`y` im logischen Raum, deshalb steht im
  Skript `width / scale`.
- **Stoppen per `SIGINT`, nicht `SIGTERM`.** wf-recorder fängt `SIGINT` ab, leert
  seine Puffer und schreibt den Container zu Ende. Abgeschossen bliebe eine Datei
  ohne Abschluss liegen — bei Matroska/WebM ohne Cues und ohne Gesamtlänge, also
  bestenfalls halb abspielbar.
- **Zustand liegt in `$XDG_RUNTIME_DIR/record/`**, nicht in `~/.local/state` wie
  beim Wallpaper: eine Aufnahme darf einen Reboot nicht überleben, ein tmpfs
  räumt das von selbst weg. Die PID-Datei allein gilt dabei nicht als Wahrheit —
  nach einem Absturz kann die Nummer längst einem fremden Prozess gehören,
  deshalb wird zusätzlich `/proc/<pid>/comm` geprüft.
- **Waybar-Modul ist `custom/screenrec`** — nicht zu verwechseln mit
  `custom/recording`, das ist der *Audio*-Aufnahmemodus (Scarlett + CPU, nur
  cube). Deshalb auch ein anderes Signal: 8 statt 7. Ohne Aufnahme liefert
  `record status` leeren Text, und Waybar blendet das Modul komplett aus — es ist
  nur zu sehen, wenn es etwas zu sagen hat. Mit Aufnahme zeigt es `REC m:ss` auf
  roter Fläche; das ist der einzige Ort in `style.css`, an dem Rot nicht "kaputt"
  heißt, sondern genau die Warnung ist, die man braucht, bevor man in ein
  aufgezeichnetes Fenster tippt.
- **`interval: 1` ist hier vertretbar**, weil `record status` bewusst ohne `jq`,
  `date` und `cat` auskommt — reine Bash-Builtins, also kein Fork pro Sekunde.
  Das Signal ist trotzdem nötig, damit Start und Stopp sofort stehen.
- **Kein `on-click` zum Stoppen:** eine laufende Aufnahme per Klick auf die Bar
  zu beenden hieße, mit dem Zeiger *im Bild* herumzufahren.

**Offener Punkt:** eine lange Aufnahme läuft in den Lockscreen. swayidle sperrt
nach 5 Minuten, und `record` hält den Rechner nicht wach — beim Vorführen tippt
und klickt man meist, dann greift der Timer nie, aber sicher ist das nicht. Bis
dahin: vor langen Aufnahmen den **"Wach"**-Schalter der Waybar drücken (s.
"Idle-Verhalten"). Sauber wäre ein kleiner Helfer, der für die Dauer der Aufnahme
einen `zwp_idle_inhibitor` hält — genau das, was Waybar für diesen Schalter tut.

## ToDo-Schnellerfassung

`SUPER+T` öffnet ein fuzzel-Overlay mit einer einzigen Eingabezeile. Tippen,
`Enter` — der Punkt steht als `- [ ] ...` in `<XDG-Dokumente>/todo.md`, das
Popup ist weg, `Esc` verwirft spurlos. `dot_local/bin/todo`:

```sh
todo                  # Overlay              — SUPER+T
todo list             # offene Punkte; Enter hakt den gewählten ab — SUPER+SHIFT+T
todo add "Milch"      # ohne Popup, für die Shell
todo clean            # abgelegte Zeilen löschen
todo edit             # Datei im Editor (xdg-open -> Emacs, s. mimeapps.list)
todo status
```

**Es ist ein Tagesspeicher, kein Langfristplan.** Beim ersten Aufruf nach 05:00
wandert alles, was noch offen ist, als *verfallen* nach unten:

```markdown
# ToDo

## 2026-09-09
- [ ] heute noch: Rechnung
- [x] 2026-09-07 16:40 Saiten wechseln
- [-] 2026-09-08 07:30 Backup prüfen
```

Oben unter der Datumszeile stehen die offenen Punkte, darunter wächst der
Verlauf: `- [x]` abgehakt, `- [-]` verfallen, beide mit dem Zeitpunkt, zu dem
sie dort gelandet sind. Gelöscht wird nichts von selbst — `todo clean` räumt
beide Marker weg, wenn die Datei zu lang wird.

**Warum fuzzel und keine ToDo-App:** das Fenster soll in dem Moment aufgehen, in
dem der Gedanke da ist, und danach sofort wieder verschwinden. Alles mit eigenem
Fenster (GTK-App, Emacs-Frame, Browser-Tab) kostet Start, Fokuswechsel und
Schließen — und wäre ein weiteres Programm, das man pflegt. fuzzel läuft hier
ohnehin (`SUPER+D`, cliphist, keybinds, wifi, bt) und steht per `fuzzel.ini` auf
`layer=overlay`, liegt also auch über Vollbildfenstern. **Kein neues Paket.**

- **Der Eingabetrick ist derselbe wie bei der Passwortabfrage in `wifi`:**
  `--dmenu` OHNE Einträge auf STDIN. fuzzel gibt bei `Enter` dann aus, was
  *getippt* wurde, statt einen Listeneintrag. `--prompt-only` macht genau das
  explizit — liest kein STDIN und setzt `--lines 0`, das Popup ist damit nur die
  eine Zeile. Es braucht also kein eigenes Eingabe-Widget.
- **Der Tag beginnt um 05:00, nicht um Mitternacht.** Was man um halb zwei
  nachts noch notiert, gehört zum angefangenen Tag und soll nicht vier Stunden
  später verfallen sein. `date -d "5 hours ago"` verschiebt genau so, inklusive
  Sommerzeitwechsel; `$TODO_DAY_START` verstellt die Grenze.
- **Welcher Tag in der Datei steht, steht IN der Datei** (`## JJJJ-MM-TT`), nicht
  in einer Statusdatei daneben. Man sieht im Emacs sofort, von wann die Liste
  ist; eine kopierte `todo.md` bringt ihren Tag mit; und eine Datei *ohne*
  Datumszeile ist damit automatisch eine normale Liste, die nie verfällt — das
  ist der Schutz für `einkauf.md`. Verglichen wird "älter als", nicht
  "ungleich": eine Datei mit einem Datum in der Zukunft (Uhr falsch gestellt)
  wird in Ruhe gelassen statt abgeräumt.
- **Die Datei liegt bewusst NICHT im Repo** (gleiche Überlegung wie beim
  Wallpaper: das Repo ist public, eine ToDo-Liste ist privat). Sie wird beim
  ersten Eintrag angelegt, auf einer frischen Maschine ist sie einfach leer.
- **`~/Dokumente/todo.md`, nicht `~/Dokumente/lambdaschmiede/...`**: der
  Unterordner ist der rclone-Mount auf mailbox.org Drive (s. u.). Eine Liste,
  die man auf Tastendruck beschreibt, soll nicht an einer Netzverbindung hängen.
  Zweite Liste ist eine Umgebungsvariable: `TODO_FILE=~/Dokumente/einkauf.md todo`
  — die verfällt nicht, weil sie keine Datumszeile bekommt.
- Pfad über `xdg-user-dir DOCUMENTS`, nicht hart `$HOME/Dokumente` — der
  Ordnername ist lokalisiert. `screenshot` löst `<XDG-Bilder>` genauso auf.
- **Abgehakt wird über den Zeilentext, nicht über eine Zeilennummer:** fuzzel
  1.14 *kann* `--index` (dmenu-Modus, gibt die Position statt des Textes) — die
  Position gilt aber nur für die Liste, die `list` gerade aufgebaut hat. Wer die
  Datei zwischendurch im Emacs umsortiert, hakt damit den falschen Punkt ab; der
  Text überlebt das. Preis dafür: zwei identische offene Zeilen sind zwei
  Punkte, von denen `list` den ersten abhakt. Und weil fuzzel bei fehlendem
  Treffer die *Rohreingabe* liefert, prüft das Skript vor dem Schreiben gegen
  die offene Liste — sonst würde ein Tippfehler still nichts abhaken, was man
  für "erledigt" hält. Beim Vergleich wird rechts getrimmt (Leerzeichen, Tabs,
  CR): sonst reicht ein von Hand angehängtes Leerzeichen oder eine per CRLF
  gespeicherte Datei, und `list` meldet bei jedem Punkt "kein offener Punkt"
  — und nennt dabei genau den Punkt, der dasteht.
- Der ausgewählte Text geht als **Umgebungsvariable** an `awk`, nicht per
  `awk -v`. `-v` jagt den Wert durch die Escape-Verarbeitung: aus `C:\temp`
  wird ein Tabulator. Punkte mit Backslash ließen sich damit nicht abhaken —
  und zwar lautlos, weil die Vorprüfung oben den unversehrten Text sieht und
  das Skript anschließend "Erledigt" meldete.
- Geschrieben wird über eine Temp-Datei **neben** der Zieldatei und `cat`
  zurück. `awk > datei` wäre kein Ersatz — die Shell leert `datei`, *bevor* awk
  sie liest. `mv` wäre atomar, ersetzt aber den Inode und damit Rechte, Symlink
  und Mount-Ziel; `cat` behält die Datei und tauscht nur den Inhalt, ist dafür
  nicht atomar. Auch `add` läuft über diesen Weg, weil neue Punkte *über* den
  Verlauf müssen und nicht ans Dateiende — Preis: `add` braucht ein
  beschreibbares Verzeichnis, ein reines Anhängen käme mit der Datei allein aus.
- Das Format ist eine gewöhnliche Markdown-Checkliste. Nichts daran ist an
  dieses Skript gebunden: mit `SUPER+T` schreiben, im Emacs von Hand
  umsortieren, in ein anderes Dokument kopieren — alles derselbe Text. `- [-]`
  rendert nicht als Kästchen, sondern als Text; das ist gewollt, verfallen ist
  kein Zustand, den man wieder anklickt.
- Kein Waybar-Modul mit Zähler. Wer es will, hat mit `todo status` die Zahl
  schon; das wäre ein `custom/`-Modul nach dem Muster von `custom/keybinds`.

## Compositor: Sway (und der Abschied von Hyprland)

Bis zum **10.09.2026** liefen hier zwei Compositoren nebeneinander: Hyprland aus
der COPR `ashbuk/Hyprland-Fedora` als Hauptsystem und Sway als Zweitsession zum
Ausprobieren. Sway hat gewonnen; Hyprland ist samt Konfiguration, Portal,
Session-Target, COPR und dem Mac-Thin-Client aus dem Repo entfernt.

Was das praktisch heißt:

- **Eine Konfiguration**, `home/dot_config/sway/`: `config` sourct
  `mocha`, `base`, `monitors`, `binds`, `rules`, `effects`. Es gilt die Regel des
  Repos: Funktion in `base`/`binds`/`rules`, Deko **ausschließlich** in `effects`.
  Die Dateien tragen keine Endung — Sway braucht keine.
- **Eine Waybar-Konfiguration**, `waybar/config.jsonc.tmpl`. Vorher waren es
  drei (`common.jsonc.tmpl` plus je eine Variante pro Compositor, per `include`
  verbunden), dazu ein eigenes chezmoi-Template für die Workspace-Icons. Diese
  ganze Aufteilung existierte nur wegen der zwei Sessions und ist ersatzlos weg.
  Der Aufruf in `sway/base` braucht deshalb auch kein `-c` mehr.
- **Die Skripte haben ihre Compositor-Weiche verloren.** `screenshot`, `record`
  und `keybinds` hatten je zwei Zweige und wählten anhand von `SWAYSOCK`. Jetzt
  reden sie nur noch mit `swaymsg`.
- **`hyprlock` ist geblieben**, als einziges `hypr*`-Paket und mit Absicht. Es
  braucht laut `strings /usr/bin/hyprlock` nur Standardprotokolle
  (`ext-session-lock-v1`, `wp-cursor-shape`, `wp-fractional-scale`,
  `wp-viewporter`, `wlr-screencopy`) und läuft unter Sway unverändert. Deshalb
  gibt es `home/dot_config/hypr/` noch — mit genau zwei Dateien,
  `hyprlock.conf` und der Palette `mocha.conf`, die es sourct. Kein `swaylock`:
  das wären zwei Lockscreens zum Pflegen und Themen.
- **`hypridle` ist dagegen gegangen.** Dieselbe Prüfung zeigt neben
  `ext-idle-notify-v1` auch `hyprland-lock-notification-v1`, ein
  Hyprland-eigenes Protokoll. Die Idle-Kette macht `swayidle` (Zeiten und
  Begründungen unverändert: 5 min sperren, 15 min Suspend, **keine**
  dpms-off-Stufe dazwischen — die Herleitung steht bei „Idle-Verhalten").

### Der Mac als Thin Client ist mitgegangen

`wayvnc` hat auf dem cube einen virtuellen Monitor bespielt, damit der Mac als
zweiter Bildschirm derselben Sitzung dienen konnte. Der Aufbau hing vollständig
an `hyprctl output create headless "mac"` — und **Sway 1.11 kennt kein
`create_output`**. Nachbauen ließe er sich auch mit dem Befehl nicht: wayvnc
entscheidet allein am Namenspräfix `HEADLESS-`, ob es den Output auf Zuruf des
Clients resized, und stürzt dabei ab. Genau deshalb hieß der Output drüben
`mac`; Sway würde den Namen selbst vergeben.

Entfernt wurden deshalb `dot_local/bin/remote`, `systemd/user/wayvnc.service`,
`dot_config/wayvnc/`, das Paket `wayvnc` und der Schlüssel-/Firewall-Block aus
`bootstrap.sh`. Per `git log` jederzeit wieder ausgrabbar.

**Zwei Reste bleiben auf der Maschine**, weil `bootstrap.sh` sie angelegt hat und
nicht zurücknimmt:

```
sudo firewall-cmd --permanent --remove-service=vnc-server && sudo firewall-cmd --reload
rm -rf ~/.config/wayvnc            # Serverschluessel und config.secret
sudo dnf copr remove ashbuk/Hyprland-Fedora
```

### Was beim Umstieg auffiel

Nichts davon ist ein Fehler, aber alles davon fällt beim Umstellen auf:

1. **Keine Rundung, keine Animationen.** Sway kann beides nicht. Fenster sind
   eckig und erscheinen ohne Übergang. Wer beides will, bräuchte swayfx.
2. **Apps landen still auf ihrem Workspace** (nur `cube`, s. „Fester Workspace
   pro App"). `assign` platziert, ohne mitzuwechseln — man bleibt stehen, wo man
   ist. Die Alternative (`for_window … move container to workspace number N,
   workspace number N`) steht auskommentiert in `sway/rules.tmpl`.
3. **`SUPER+SHIFT+C` lädt die Konfiguration neu.** Sway liest seine
   Konfiguration nicht von selbst neu ein. Was ein Reload **nicht** tut: die
   `exec`-Zeilen erneut starten — waybar, swaync und swayidle laufen weiter wie
   sie sind.
4. **`app_id` vs. `class`.** Sway hat zwei getrennte Felder: `app_id` trifft nur
   Wayland-Fenster, `class` nur XWayland-Fenster. Deshalb steht Citrix in
   `sway/rules.tmpl` als `class`, alle anderen als `app_id`. Eine Regel mit dem
   falschen Feld fällt **still** durch. Gegenprüfen: `swaymsg -t get_tree`.
5. **Sway kennt kein `env`.** Umgebungsvariablen für die Session gehen über
   `dbus-update-activation-environment` bzw. über eine Sway-Variable vor dem
   Kommando (`$qtenv` in `sway/base`) — die Herleitung steht dort.
6. **Kein `highrr`, kein `auto-right`.** Modus und Position der Monitore stehen
   in `sway/monitors.tmpl` explizit.

### Konfiguration prüfen, ohne die Session anzufassen

```
sway -C
```

Liest die Konfiguration und meldet Fehler, ohne eine laufende Sitzung zu
berühren. Das ist der Weg, eine Änderung zu prüfen, bevor man `SUPER+SHIFT+C`
drückt.
## Nachlese 13.09.2026: Review nach dem swayidle-Fund

Der Fund "Standby eine Sekunde nach dem Entsperren" (s. Idle-Verhalten) war
ein Kommando, dessen Semantik nie gegen das Tool geprüft worden war. Daraufhin
das ganze Repo auf dieselbe Fehlerklasse durchgesehen. Was dabei geändert
wurde, mit Begründung jeweils im Kommentar an der Stelle:

- **`unlock 'pkill -USR1 -x hyprlock'`** statt SIGTERM (`sway/base`). hyprlock
  entsperrt nur auf USR1 sauber; stirbt der Lock-Client ohne `unlock`, bleibt
  die Session laut ext-session-lock-v1 gesperrt, Sway zeigt eine Farbfläche.
- **`SUPER+L` → `loginctl lock-session`** statt `hyprlock` direkt
  (`sway/binds`). Ein Weg zum Sperren, nicht zwei; pidof-Schutz und
  `LockedHint` gelten damit auch für das manuelle Sperren.
- **`output * power on`** statt `dpms on` (`sway/base`): in Sway 1.11 ist
  `dpms` laut `sway-output(5)` nur noch ein deprecated Alias.
- **Umgebung und Session-Target in einer `exec`-Zeile mit `&&`** (`sway/base`).
  Sway wartet zwischen exec-Zeilen nicht; gewann das Target das Rennen, startete
  das Portal ohne `WAYLAND_DISPLAY` in der systemd-Umgebung. Nie beobachtet,
  aber ein Rennen.
- **Lautstärketasten** (`sway/binds`): Sway hat dafür keine Defaults, die
  Tasten taten nichts. Jetzt `wpctl` mit `--locked`, gedeckelt bei 100 %.
- **`wifi pick`** schnitt die SSID bei Offset 26 statt 24 ab — zwei Zeichen
  fehlten, gespeicherte Netze wurden nie erkannt und fragten jedes Mal neu nach
  dem Passwort.
- **`kbdlight`** suchte `ite8291r3-ctl` per Namen; unter SDDM liegt
  `~/.local/bin` nicht im PATH, die Tasten starben mit "fehlt". Jetzt voller
  Pfad (nur book betroffen).
- **`wallpaper`** meldete Fehler per fuzzel-Dmenu, weil angeblich libnotify
  fehle. Es ist installiert; fuzzel ist ein modales Overlay, das aus `exec
  wallpaper restore` beim Login ein blockierendes Popup erzeugt hätte. Jetzt
  `notify-send` wie in allen Nachbarskripten.
- **`record`**: `flock` um Start/Toggle (drei Tasten, zwei Drücke, zwei
  Recorder, einer davon unerreichbar), Zielordner wird erst in `start()`
  aufgelöst (der Sekundentakt der Waybar forkte sonst xdg-user-dir mit).
- **Kommentare**, die auf Hyprland-Dateinamen zeigten (`base.conf`,
  `binds.conf`, `rules.conf`, `exec-once`, `bindl`) oder auf eine nie
  existierende `environment.d/10-device-config.conf`, sind auf die Sway-Namen
  gezogen.

**Nicht gemacht, bewusst:**

- swayidle als systemd-User-Unit mit `Restart=on-failure`. Stirbt swayidle,
  gibt es weder Lock noch Suspend, und nichts zeigt das an — der Punkt ist
  berechtigt. Aber die Unit müsste in einer echten Session getestet werden,
  und die stand an dem Tag nicht zur Verfügung. Offen.
- Das Paket-Aufräumen. Entgegen den Kommentaren in `packages.txt` waren
  `hyprland`, `hypridle`, `xdg-desktop-portal-hyprland`, `wayvnc` und `mako`
  am 13.09. noch installiert und die COPR noch aktiv; das Hyprland-Portal lief
  sogar und wurde von xdg-desktop-portal für GlobalShortcuts/InputCapture
  gewählt. Weg damit:

  ```sh
  sudo dnf remove hyprland hypridle xdg-desktop-portal-hyprland wayvnc mako
  sudo dnf copr remove ashbuk/Hyprland-Fedora
  ```

  `~/.config/wayvnc/` (mit RSA-Key) liegt ebenfalls noch da; chezmoi löscht
  keine Dateien, die es nicht mehr verwaltet.

  **Erledigt um 13:26 (dnf-Transaktion 45, 54 Pakete) — mit einem Opfer.**
  Die Transaktion hat `hyprlock-0.9.6` als „Dependency" mit entfernt. Das war
  kein dnf-Fehler: hyprlock gibt es in den Fedora-Repos nicht (nur `hyprlang`),
  es kam wie Hyprland aus der COPR `ashbuk/Hyprland-Fedora`, und mit der COPR
  war auch sein einziger Lieferant weg. `packages.txt` behauptete das
  Gegenteil („das einzige hypr*-Paket, das geblieben ist") — die Aussage
  stimmte für das Protokoll-Argument, nicht für die Paketquelle. Aufgefallen
  ist es erst beim dGPU-Suspend-Test um 15:32: swayidle ruft
  `loginctl lock-session`, Sway meldet den Lock, swayidles `lock`-Kommando
  läuft in `sh: hyprlock: Kommando nicht gefunden`, und der Rechner schläft
  ohne Sperre ein und wacht offen wieder auf. Bis das ersetzt ist, sperrt
  weder die 5-Minuten-Stufe noch `SUPER+L` irgendetwas.

  **Entscheidung: swaylock.** Die drei Kandidaten in Fedora bzw. per COPR:
  hyprlock zurück über `ashbuk/Hyprland-Fedora` (Config bleibt, aber der
  Sperrbildschirm hängt dauerhaft an einer Drittquelle, die gerade wegen
  Drift entfernt wurde), gtklock 4.0 (Fedora, GTK, Uhr per Modul, Theming
  von null) oder swaylock 1.8.6 — schon installiert als Recommends von
  `sway-config-upstream`, kann `-f` und SIGUSR1-Unlock, also genau die zwei
  Eigenschaften, die die swayidle-Kette braucht. Preis: keine Uhr und kein
  Datum auf dem Sperrbildschirm. Umgesetzt: `swaylock/config` (Mocha,
  flache Farbe, Ring statt Eingabefeld), `sway/base` lock/unlock auf
  swaylock, `kbdlight` liest die Palette aus `sway/mocha`, `hypr/` ist aus
  dem Repo raus, `packages.txt` führt swaylock statt hyprlock. Das
  Verzeichnis `~/.config/hypr/` bleibt wie `~/.config/wayvnc/` liegen, bis es
  jemand von Hand löscht.

Lehre aus dem Review selbst: ein Skript, dessen Fehlerpfad oder Erfolgspfad
etwas auf den Bildschirm bringt (slurp, fuzzel, notify-send), testet man nicht
in der laufenden Session — auch nicht "nur den Fehlerpfad". Lock-Logik mit einer
reinen Shell-Nachbildung prüfen, nicht mit dem echten Skript.

## Login-Screen (SDDM)

Ersetzt den früheren TTY1-Autostart. Der ist nicht weg, sondern zum Notfallpfad
geworden: `.bash_profile` startet `sway` nur noch dann direkt, wenn
`sddm.service` **nicht** läuft — also wenn der Display-Manager kaputt ist. Damit
bleibt die alte "eine Komponente weniger"-Resilienz erhalten, ohne dass sich
beide Startwege ins Gehege kommen.

- `sddm` + `sddm-wayland-generic` (packages.txt). Das Subpaket steht explizit
  drin, damit die Wahl feststeht: `sddm` verlangt ein virtuelles
  `sddm-greeter-displayserver`, das auch `sddm-x11` erfüllen würde — dnf könnte
  sonst Xorg auf ein System ziehen, das keins hat.
- **Der Greeter läuft in weston, nicht in der Session-Umgebung.** `sddm-wayland-generic`
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
- **Keine eigene Session-Datei** — es gilt die aus dem `sway`-Paket
  ("Sway" im Session-Menü des Greeters). Zu Hyprland-Zeiten stand hier mal eine
  eigene mit `Exec=/bin/bash -lc "exec start-hyprland"`, die einen
  **Login-Loop** erzeugt hat: Session startet, stirbt sofort, Greeter kommt
  wieder. Zwei Denkfehler, die für jeden Compositor gelten: ein
  `start-*`-Wrapper ist für den **TTY**-Start gedacht (er macht das Session-
  und D-Bus-Setup, das es ohne Display-Manager sonst nicht gäbe) — unter SDDM
  erledigt das der Display-Manager bereits. Und Anführungszeichen im `Exec=`
  folgen der Desktop-Entry-Spec, nicht Shell-Quoting.
  Der Session-Log dazu steht **nicht** im journal, sondern in
  `~/.local/share/sddm/wayland-session.log` — die Datei ist bei Loops die
  einzige brauchbare Quelle.
- **`~/.local/bin` ist unter SDDM nicht im PATH**, weil die Session ohne
  Login-Shell startet. `keylight` und `wallpaper` werden deshalb in
  `sway/binds` und `sway/base` mit vollem Pfad aufgerufen (`~/.local/bin/...`,
  Sway führt `exec` über `/bin/sh -c` aus, die Tilde wird expandiert).
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
    kein Weg: Sway führt `exec` über ein nicht-interaktives `/bin/sh` aus,
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

## Tastaturbeleuchtung (nur `book`)

Das `book` ist ein **TUXEDO Stellaris/Polaris AMD Gen4** (Uniwill-Barebone
`GMxRGxx`) mit RGB-Tastatur. Out of the box leuchtet davon nichts, und
`/sys/class/leds/` enthält nur NIC-LEDs und Capslock:

```console
$ ls /sys/class/leds/
enp3s0-0::lan  input3::capslock  input3::numlock  input3::scrolllock  phy0-led
```

**Warum.** Der Mainline-Treiber `uniwill_laptop` ist geladen und kennt das Board
— `GMxRGxx` steht in seiner DMI-Alias-Liste, und er registriert die Hotkeys.
Die Beleuchtung macht er aber nicht: die hängt an einem eigenen USB-Controller,

```console
$ grep -l 048d /sys/bus/usb/devices/*/idVendor
/sys/bus/usb/devices/5-1.1/idVendor      # 048d:6004 "ITE Device(8291)", rev 0.03
```

und für den gibt es im Fedora-Kernel kein Modul. Zuständig wäre `ite_8291`, das
es nur out-of-tree im DKMS-Paket `tuxedo-drivers` aus TUXEDOs eigenem RPM-Repo
gibt.

**Nicht genommen: das DKMS-Paket.** Es funktioniert und registriert eine echte
`led`-Klasse, muss aber bei jedem Kernel-Update neu gebaut werden. Auf Fedora
mit seiner Update-Frequenz ist das genau die Sorte beweglicher Teil, die
irgendwann nach einem Reboot fehlt — und dann sucht man den Fehler bei der
Beleuchtung statt beim Modulbau.

**Genommen: Userspace über libusb.** `ite8291r3-ctl` (GPL-2.0, PyPI) spricht den
Controller direkt an. Kein Kernelmodul, überlebt Kernel-Updates ersatzlos.
Nötig ist nur Zugriff auf den Geräteknoten, und das macht
`udev/60-ite8291-kbdlight.rules` mit demselben `TAG+="uaccess"` wie die
Stream-Deck-Regel:

```console
$ getfacl -p /dev/bus/usb/005/003 | grep '^user:'
user::rw-
user:zoellert:rw-
```

Installiert wird per `pipx` und **auf `==0.4` gepinnt** (wie das SDDM-Theme),
und nur, wenn der Controller wirklich steckt — auf dem cube wäre es Fracht.
Das Tool selbst liegt bewusst *nicht* im Repo: es steht unter GPL-2.0, dieses
Repo hat gar keine LICENSE-Datei, und eine GPL-Datei hineinzukopieren würde
diese Frage unter der Hand beantworten.

**Der Wrapper.** `dot_local/bin/kbdlight` ist eigener Code und macht das, was
das Tool nicht kann: Toggle mit gemerkter Helligkeit, Auf/Ab in Schritten, und
Farben über **Namen** statt RGB-Tripel. Die Farbwerte werden dabei nicht
dupliziert, sondern zur Laufzeit aus `hypr/mocha.conf` gelesen — derselben
Datei, aus der sich hyprlock die Palette holt, damit Sperrbildschirm und
Beleuchtung nicht auseinanderlaufen. Ein Theme-Wechsel zieht die Beleuchtung damit automatisch
mit.

```console
$ kbdlight color mauve      # Catppuccin Mocha Mauve = cba6f7 = 203,166,247
$ kbdlight status
Helligkeit: 25/50
Farbe:      mauve (203,166,247)
```

**Die Fn-Tasten funktionieren direkt.** Das Input-Device `Uniwill WMI hotkeys`
meldet laut Capability-Bitmap `KBDILLUMTOGGLE`, `KBDILLUMUP` und
`KBDILLUMDOWN` — es braucht also kein Custom-Modul, nur drei Bindings in
`sway/binds`. Sie sind mit `--locked` gesetzt (Hyprlands `bindl`) und gehen damit auch bei gesperrtem
Bildschirm; Licht anmachen ist nichts, wofür man erst das Passwort tippen will.

**Auf dem cube** sagt `kbdlight` sofort, dass kein Controller da ist, statt
kommentarlos nichts zu tun oder einen Python-Traceback zu zeigen — dasselbe
Prinzip wie bei `keylight` ohne konfigurierten Host.

## Portale & Standardbrowser

Drei Schichten, die alle stimmen müssen, damit z. B. Element/Cider bei
OAuth/SSO-Login einen Browser öffnen können. Von unten nach oben, in der
Reihenfolge, in der wir sie live debuggt haben:

- **1. `graphical-session.target` muss aktiv sein.** `xdg-desktop-portal.service`
  hat eine harte Dependency darauf — ohne die bleibt der komplette Portal-Dienst
  im Zustand `Dependency failed`, dauerhaft, egal was sonst stimmt. Ein
  Wayland-Compositor muss systemd explizit sagen "wir sind jetzt eine grafische
  Session"; das macht normalerweise uwsm, das es in F44 nicht gibt, und Sway
  tut es von sich aus NICHT. Fix: `systemd/user/sway-session.target`,
  gestartet per `exec` ganz am Anfang von `sway/base`. Kein Shutdown-Hook —
  beim echten Logout räumt systemd --user sowieso alles ab.
  Diagnose: `systemctl --user status xdg-desktop-portal.service` — `Dependency
  failed` heißt exakt das hier. `systemctl --user cat sway-session.target`
  bestätigt, ob die Unit überhaupt ankam (nach `chezmoi apply` einmalig
  `systemctl --user daemon-reload` nötig, damit neue Units gefunden werden).
- **2. Activation-Environment muss `XDG_DATA_DIRS` enthalten.** Portal-Backends
  erben ihre Umgebung von der D-Bus-/systemd-Activation-Environment, NICHT von
  der Login-Shell. Betrifft `--user`-Flatpaks (Thunderbird, Cider, Element,
  Slack, Signal) — deren `.desktop`-Dateien liegen in
  `~/.local/share/flatpak/exports/share/applications/`; fehlt dieser Pfad in
  dem `XDG_DATA_DIRS`, das das Portal sieht, findet es die Datei nicht.
  `xdg-mime query default` fragt aber die *Login-Shell*, antwortet also trotzdem
  korrekt — das Auseinanderfallen macht den Fehler verwirrend. Fix: `sway/base`
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
  den TTY-Notfallpfad da), sondern manuell in eine eigene `~/.bashrc`
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
  In der Compositor-Konfiguration wäre sie schlecht aufgehoben: Sway kennt kein
  `env`, und in der Activation-Environment müsste man `$XDG_RUNTIME_DIR`
  hartkodieren.
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
Standardgerät ist X11. Live getestet (`x11(); plot(1:3);
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
- **Die naheliegende Gegenregel greift hier nicht.** Eine Regel auf „modal"
  klänge passend, aber `modal` kommt aus dem Protokoll `xdg-dialog-v1`, und
  LibreOffices GTK3-Backend spricht das nicht. Über die App-ID sind Dialoge
  auch nicht zu fassen: sie erben die des
  Hauptfensters. Bliebe Matching auf Fenstertitel — lokalisiert, versionsabhängig,
  also genau die Sorte Regel, die still kaputtgeht.
- **OnlyOffice ist ein Ein-Fenster-Programm** mit Dokument-Tabs und in-App
  gerenderten Dialogen. Da ist nichts zu kacheln, also braucht es auch keine
  Regel in `sway/rules`. Zweiter Grund: die bessere Treue bei
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
swaymsg -t get_tree | grep -iA2 -e class -e onlyoffice   # Klasse + shell
xdg-mime query default application/vnd.openxmlformats-officedocument.wordprocessingml.document
xdg-mime query default application/pdf        # muss firefox.desktop bleiben
fc-list | grep -ci -e carlito -e caladea -e liberation
```

- **OnlyOffice läuft über XWayland** (`swaymsg -t get_tree` → `shell: xwayland`,
  und die Regel in `sway/rules.tmpl` greift deshalb über `class`, nicht
  `app_id`), und das
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
  `window-rewrite` (s. Theming) den echten Wert aus `swaymsg -t get_tree` nehmen —
  dieselbe Regel wie bei allen anderen Klassen dort.

## Dateimanager (Double Commander)

Zwei-Fenster-Dateimanager in der Total-Commander-Tradition: zwei Panels
nebeneinander, das eine ist Quelle, das andere Ziel, und die Funktionstasten
machen die Arbeit — `F3` Betrachten, `F4` Bearbeiten, `F5` Kopieren, `F6`
Verschieben/Umbenennen, `F7` Ordner anlegen, `F8` Löschen. Dazu Tabs pro Panel,
Archive als begehbare Ordner, Mehrfach-Umbenennen, Verzeichnisvergleich und ein
eingebauter FTP/SFTP-Client. Start: **`SUPER+E`** (s. `sway/binds`).

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
Paketname *und* Aufrufname sowohl in `packages.txt` als auch in `sway/binds`
und `mimeapps.list` ausgeschrieben mit `-qt6`.

Nur `doublecmd-qt6` linkt `libwayland-client.so.0` direkt; `qt6-qtwayland` steht
ohnehin schon in `packages.txt`. Kosten: 3 Pakete, 48 MB.

### Drag & Drop in Firefox-Upload-Felder

Das ist der eigentliche Grund für die Paketwahl. Firefox ist hier ein natives
dnf-Paket und läuft nativ auf Wayland (damals abgelesen mit
`hyprctl clients -j | grep xwayland` → `false`; heute `swaymsg -t get_tree`,
Feld `shell`). Ein Wayland-Client, der zieht, bietet die Auswahl per
`wl_data_device` als `text/uri-list` an — genau das nimmt ein
`<input type="file">` entgegen. Beide Seiten nativ, ein Protokoll, fertig.

Über XWayland müsste derselbe Drop durch die XDND-Brücke des XWayland-Managers
übersetzt werden. Die **existiert** — X11-nach-Wayland-DnD ist nicht
grundsätzlich unmöglich —, ist aber der bekannt fragile Weg. Die Qt6-Variante
umgeht sie vollständig, statt sich auf sie zu verlassen.

### Auf Hardware verifiziert (22.08.2026) — bis auf den Drop

Die Paketauswahl war aus den Abhängigkeiten hergeleitet; inzwischen ist sie
nachgemessen:

```sh
swaymsg -t get_tree | grep -iB4 -i doublecmd | grep -e app_id -e shell
```

- **`xwayland: false`** — bestätigt, `doublecmd-qt6` ist ein nativer
  Wayland-Client. Stünde dort `true`, hätte Qt6 trotz allem den xcb-Plugin
  genommen: dann ist `QT_QPA_PLATFORM` in der Umgebung gesetzt oder
  `qt6-qtwayland` fehlt. Erst das reparieren, nicht das Programm wechseln.
  NICHT verwechseln mit `QT_QPA_PLATFORMTHEME`, das wir sehr wohl setzen —
  das ist eine andere Variable (s. Dark Mode unten).
- **Fensterklasse** ist `doublecmd-qt6`, ebenfalls aus derselben Ausgabe. Sie
  gehört geprüft, bevor sie in `sway/rules` oder Waybars `window-rewrite`
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

- `QT_QPA_PLATFORMTHEME=gtk3` in der `dbus-update-activation-environment`-Zeile
  von `sway/base` (Sway kennt kein `env`), plus `$qtenv` vor dem Aufruf in
  `sway/binds`
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
`dbus-update-activation-environment` in `sway/base`. Grund: DC startet nicht nur
über SUPER+E als Kind der Session, sondern auch als Handler für
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

## Drift auflösen (`drift-check.sh pick`)

`./drift-check.sh` listet wie immer die Pakete, die installiert sind, aber nicht
im Repo stehen. `./drift-check.sh pick` legt dieselbe Liste in **fzf**: `TAB`
markiert (mehrere), dann entscheidet eine Taste, was mit dem markierten Schwung
passiert.

| Taste | Aktion |
|---|---|
| `CTRL-R` | entfernen — `dnf remove` |
| `CTRL-P` | nach `packages.txt` übernehmen — gehört dazu, war nur nie eingetragen |
| `CTRL-E` | nach `packages-expected.txt` — soll da sein, gehört aber nicht ins Setup |
| `ESC` | Abbruch, nichts passiert |

Die Liste hat **zwei Spalten**, und die zweite ist der ganze Trick: der
Installationsgrund aus der RPM-Datenbank. Sortiert wird danach — `User` oben,
`Group` unten.

### Warum die Liste ohne diese Spalte unbrauchbar ist

`dnf repoquery --userinstalled` wirft zwei völlig verschiedene Dinge in denselben
Topf. Von den 67 Einträgen auf dem cube sind:

| Reason | Anzahl | Was es heißt |
|---|---|---|
| `User` | 28 | wirklich explizit installiert — **nur hier** lohnt das Nachdenken |
| `Group` | 38 | kam über eine comps-Gruppe der Erstinstallation: `bash`, `glibc`, `coreutils`, `sudo`, `util-linux`. Nichts davon hat je jemand einzeln ausgesucht |
| `External User` | 1 | an dnf vorbei installiert (heruntergeladenes `.rpm`) |

Ohne die Spalte steht der halbe Anaconda-Sockel unkommentiert zwischen den
echten Ad-hoc-Installationen — und dann kann man bei keinem Eintrag einschätzen,
was er da tut. Mit ihr sind es 28 Zeilen, bei denen die Frage „weg oder
behalten?" überhaupt sinnvoll ist.

**Trotzdem nicht gefiltert.** Die `Group`-Pakete verschwinden nicht, sie rutschen
nach unten. Wegzulassen wäre wieder ein Ausschluss, den nicht der Nutzer
getroffen hat — und die Grenze verläuft nicht da, wo man sie vermutet: `kernel`
steht als `User` drin, `sudo` dagegen als `Group`. Wer hier pauschal filtert,
filtert falsch.

### Die Vorschau beantwortet „wo kommt das her?"

Rechts steht zu jedem Eintrag Version, Installationsdatum, Größe — und zwei
Blöcke, die die eigentliche Entscheidung tragen:

```
Woher:                                  Woher:
  3 yum install btop  15.08.2026          1 (leer)  15.08.2026  419 Pakete
Wird gebraucht von:                     Wird gebraucht von:
  Kein Paket benötigt btop                ca-certificates, dracut, …
```

Links ein Befehl, den man selbst getippt hat, und nichts hängt dran — das kann
weg. Rechts eine Transaktion ohne Kommandozeile, die 419 Pakete angefasst hat
(die Anaconda-Erstinstallation), mit vier Abhängigen — das bleibt.

Der Block kommt aus `dnf history list --contains-pkgs`. Das ist die **einzige**
Stelle, an der die Vorschau `dnf` statt `rpm` benutzt: `rpm` liest die lokale
Datenbank und antwortet sofort, `dnf info` geht an den Metadaten-Cache und
braucht pro Cursorschritt eine knappe Sekunde — bei 67 Einträgen der Unterschied
zwischen Durchscrollen und Warten. `--contains-pkgs` ist mit 0,026 s die
Ausnahme, die nichts kostet.

Der letzte Block (`rpm -q --whatrequires`) entscheidet, ob „entfernen" eine
Zeile oder eine Lawine wird.

### Warum es trotzdem eine dritte Kategorie braucht

Auch mit Reason-Spalte und Herkunft bleiben Einträge übrig, die weder ins Setup
gehören noch weg sollen: ein `User`-Paket, das man bewusst ad hoc installiert
hat und ad hoc behalten will. Für die ist `packages-expected.txt` da.

Ohne Platz für diese Kategorie bleibt die Liste dauerhaft lang. Und eine Liste,
die man jedes Mal überliest, meldet irgendwann auch das eine echte Paket nicht
mehr — dann kann man `drift-check.sh` auch gleich löschen.

**Nicht vorbefüllt, mit Absicht.** Es wäre technisch trivial, die 419 Namen aus
`dnf history info 1` einmal einzutragen. Genau das soll nicht passieren: dann
stünde eine generierte Datei im Repo, die nie jemand gelesen hat, und die
Entscheidung „das darf hier stehen" wäre für 419 Pakete auf einmal getroffen
worden, ohne sie je anzusehen. Jeder Eintrag entsteht stattdessen am Gegenstand,
über `CTRL-E`, **mit Begründung** — das Skript fragt sie ab und schreibt sie als
Kommentar mit. Eine Ausnahmeliste ohne Begründungen ist nach einem halben Jahr
nicht mehr von einer Liste vergessener Pakete zu unterscheiden.

### Warum fzf und nicht fuzzel

Das Repo macht jeden GUI-Picker mit fuzzel (`bt`, `wifi`, `audio-out`, …). Für
diesen hier geht das nicht: **fuzzel kann im dmenu-Modus nur einen Eintrag
zurückgeben.** „Sieben hypr-Pakete markieren und in einem Rutsch entfernen" ist
aber genau der Fall, für den das Tool existiert. fzf ist dasselbe Prinzip
(tippen filtert, Enter wählt) für das Terminal, kann `--multi` und liefert über
`--expect` gleich mit, welche Taste gedrückt wurde. Reguläres Fedora-Paket, in
packages.txt eingetragen.

### Die Sicherung ist `dnf` selbst

`CTRL-R` ruft `dnf remove` **ohne `-y`**. Das ist die einzige Sicherung, und sie
ist absichtlich keine eigene: `dnf` zeigt von sich aus die vollständige
Transaktion — inklusive der Pakete, die als Abhängigkeit mitgehen — und fragt
dann nach. Eine selbstgebaute Rückfrage davor wäre eine zweite, schlechtere
Wahrheit, die irgendwann von der ersten abweicht. Wer hier `bash` markiert,
sieht in der dnf-Vorschau, was das bedeutet, und kann mit `n` abbrechen.

Zusätzlich schützt dnf die Pakete aus `/etc/dnf/protected.d/` (auf diesem System
`systemd`, `systemd-udev`, `sudo`, `setup`, `grub2-efi-x64`,
`grub2-tools-minimal`, `selinux-policy-targeted`, `shim-x64`) hart — die lassen sich gar nicht
entfernen. `kernel`, `glibc`, `bash`, `coreutils` und `rpm` stehen da **nicht**
drin; bei denen ist die Transaktionsvorschau die einzige Bremse.

### Der Hyprland-Fall, durchgespielt

Das Tool ist für genau diesen Ablauf gebaut worden, und er ist am 10.09.2026
einmal komplett durchgelaufen (s. „Compositor: Sway"):

1. `hyprland`, `hypridle` und `xdg-desktop-portal-hyprland` aus `packages.txt`
   löschen, `dot_config/hypr/` bis auf `hyprlock.conf` + `mocha.conf` entfernen,
   `hyprland-session.target`, die Portal-Datei und den COPR-Aufruf in
   `bootstrap.sh` mit.
2. `./drift-check.sh pick` — die Pakete stehen jetzt als Drift da (installiert,
   aber nicht mehr im Repo), und zwar mit Reason `User` und der Herkunftszeile
   `15.08. hyprland hyprlock hypridle …` in der dritten Spalte. Tippen filtert
   auf `hypr`, `TAB` markiert, `CTRL-R` entfernt.
3. Auf dem book dasselbe.

Dasselbe gilt für `mako`, das beim Umstieg auf swaync überflüssig wurde: es
taucht in der Liste als `User` / `15.08. hyprland hyprlock hypridle …` auf,
ohne Abhängige.

Was das Tool **nicht** tut: die COPR `ashbuk/Hyprland-Fedora` abräumen. Die ist
eine Repo-Definition, kein Paket — `sudo dnf copr remove ashbuk/Hyprland-Fedora`
gehört zum selben Aufräumen, muss aber von Hand. Genauso wenig räumt es
Konfigurationsreste im Home ab (`~/.config/wayvnc`).

## Betriebsmodus

- Ad-hoc `dnf install` ist erlaubt; was bleibt, wandert SOFORT in packages.txt.
- GUI-Apps nur als Flatpak (flatpaks.txt), außer Firefox (s. o.).
  Dev-Toolchain über SDKMAN/mise.
- Config-Änderungen enden immer im Repo: live editiert ⇒ `chezmoi re-add`.
- `./drift-check.sh` zeigt handinstallierte Pakete, die nicht im Repo stehen;
  `./drift-check.sh pick` löst sie auf (entfernen / übernehmen / als erwartet
  ablegen) — s. eigenen Abschnitt.
- Vor jedem Commit: `git status` + `git diff` (Repo ist public!). TODO: gitleaks-Hook.
