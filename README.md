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
- `systemctl --user status xdg-desktop-portal-hyprland xdg-desktop-portal-gtk`
- Flatpak-Probe: eines installieren, Datei-Dialog öffnen
- `hyprctl monitors` — echte Namen in `monitors.conf.tmpl` eintragen, apply
- `pidof hypridle` — sollte laufen; nach 5 min Idle sperrt hyprlock automatisch

## Gelernt auf echter Hardware (Fedora 44, August 2026)

- **Hyprland ist seit Fedora 43 aus den offiziellen Repos retired.**
  Quelle ist die COPR `ashbuk/Hyprland-Fedora` (Name strikt kleingeschrieben,
  falsche Schreibweise schlägt STILL fehl). bootstrap.sh richtet sie ein.
- **uwsm und hyprpolkitagent gibt es in F44 nicht.** Ersatz: Start über
  start-hyprland (bringt Session-/D-Bus-Setup mit) + mate-polkit als Agent.
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

## Betriebsmodus

- Ad-hoc `dnf install` ist erlaubt; was bleibt, wandert SOFORT in packages.txt.
- GUI-Apps nur als Flatpak (flatpaks.txt), Dev-Toolchain über SDKMAN/mise.
- Config-Änderungen enden immer im Repo: live editiert ⇒ `chezmoi re-add`.
- `./drift-check.sh` zeigt handinstallierte Pakete, die nicht im Repo stehen.
- Vor jedem Commit: `git status` + `git diff` (Repo ist public!). TODO: gitleaks-Hook.
