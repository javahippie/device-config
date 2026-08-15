# cube-bootstrap

Reproduzierbares Setup für den Tuxedo Cube: Fedora Minimal + Hyprland.
Struktur: `bootstrap.sh` + `packages.txt` = Systemschicht,
`home/` = chezmoi-Source für die Dotfiles.

## 0. Vorbereitung (jetzt, ohne Hardware)

1. Dieses Repo zu Git pushen (Forgejo/GitHub, egal — muss nur vom
   frischen System aus erreichbar sein).
2. Fedora **Everything**-Netinstall-ISO laden:
   https://fedoraproject.org/everything/download
   (Nicht "Workstation" — die bringt GNOME mit.)
3. Auf einen USB-Stick schreiben, z. B.:
   `sudo dd if=Fedora-Everything-netinst-x86_64-*.iso of=/dev/sdX bs=8M status=progress oflag=direct`
   (oder Fedora Media Writer, wenn's bequem sein soll)

## 1. Installation

- Vom Stick booten, Installer starten.
- **Softwareauswahl: "Minimal Install"** — keine Zusatzgruppen anhaken.
- Partitionierung: Automatisch, Btrfs-Default übernehmen.
- Benutzer anlegen, als Administrator markieren (sudo).
- Root-Account kann deaktiviert bleiben.

## 2. Erster Boot (TTY, nacktes System)

```sh
sudo dnf install -y git chezmoi
git clone <REPO-URL> ~/cube-bootstrap
cd ~/cube-bootstrap
./bootstrap.sh                      # Systemschicht: Pakete, Flathub, greetd-frei
chezmoi init --apply --source ~/cube-bootstrap/home
reboot
```

Nach dem Reboot: am TTY einloggen — `.bash_profile` startet Hyprland
über uwsm automatisch (bewusst kein Display-Manager, eine Fehlerquelle
weniger; wer doch einen will: greetd + tuigreet nachrüsten).

## 3. Danach

- `flatpak install flathub org.mozilla.firefox` etc. — GUI-Apps nur als Flatpak.
- Java-Toolchain über SDKMAN/mise, Container über podman — nichts davon per dnf.
- Neue dnf-Pakete, die bleiben dürfen: **sofort in `packages.txt` nachtragen.**
- Drift-Check: `./drift-check.sh` zeigt, was per Hand installiert wurde
  und (noch) nicht im Repo steht.

## Konventionen

- `home/dot_config/hypr/` ist gesplittet: `base` / `binds` / `rules` / `effects`.
  Deko lebt NUR in `effects.conf` — die startet als expliziter Null-Zustand.
- Jede Zeile in diesem Repo ist selbst geschrieben oder bewusst übernommen.
  Nichts wird aus Fertig-Configs geerbt.
