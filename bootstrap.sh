#!/usr/bin/env bash
# Systemschicht: COPR + Pakete + Flathub + SDKMAN + chezmoi-Verdrahtung.
# Idempotent — darf beliebig oft laufen.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> COPR: Hyprland (seit Fedora 43 nicht mehr in den offiziellen Repos)"
sudo dnf install -y dnf5-plugins
sudo dnf copr enable -y ashbuk/Hyprland-Fedora   # Name strikt kleingeschrieben!

echo "==> COPR: mise (offiziell empfohlener Weg für Fedora 41+, s. mise-Doku)"
sudo dnf copr enable -y jdxcode/mise

echo "==> dnf-Pakete aus packages.txt"
mapfile -t PKGS < <(sed 's/#.*//' packages.txt | awk 'NF{print $1}')
sudo dnf install -y "${PKGS[@]}"

echo "==> Flathub aktivieren (voll, nicht Fedoras gefilterte Auswahl)"
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if [ -f flatpaks.txt ]; then
    echo "==> Flatpaks aus flatpaks.txt"
    mapfile -t FLATS < <(sed 's/#.*//' flatpaks.txt | awk 'NF{print $1}')
    [ "${#FLATS[@]}" -gt 0 ] && flatpak install --user -y --noninteractive flathub "${FLATS[@]}"
fi

echo "==> udev-Regel: Stream Deck ohne root nutzbar (OpenDeck-Flatpak braucht das trotzdem)"
sudo cp udev/40-streamdeck.rules /etc/udev/rules.d/40-streamdeck.rules
sudo udevadm control --reload-rules
sudo udevadm trigger

echo "==> Podman-Socket (rootless, Docker-API-kompatibel für Tools, die docker.sock erwarten)"
systemctl --user enable --now podman.socket

echo "==> minikube (kein dnf-Paket, offizielle Empfehlung: Binary statt Repo)"
if ! command -v minikube >/dev/null 2>&1; then
    TMP_MINIKUBE="$(mktemp)"
    curl -Lo "$TMP_MINIKUBE" https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install "$TMP_MINIKUBE" /usr/local/bin/minikube
    rm -f "$TMP_MINIKUBE"
else
    echo "    bereits installiert, übersprungen"
fi

echo "==> SDKMAN (Java-Toolchain-Manager, kein dnf-Paket)"
if [ ! -d "$HOME/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
else
    echo "    bereits installiert, übersprungen"
fi

echo "==> SDDM: Catppuccin-Mocha-Theme (kein Fedora-Paket, deshalb Release-Zip)"
SDDM_THEME="catppuccin-mocha-mauve"
SDDM_THEME_VER="v1.1.2"        # gepinnt, nicht 'latest' — sonst ändert sich der
                                # Login-Screen bei jedem bootstrap-Lauf unter der Hand
if [ ! -d "/usr/share/sddm/themes/$SDDM_THEME" ]; then
    TMP_THEME="$(mktemp -d)"
    curl -Lo "$TMP_THEME/theme.zip" \
        "https://github.com/catppuccin/sddm/releases/download/${SDDM_THEME_VER}/${SDDM_THEME}-sddm.zip"
    sudo unzip -q "$TMP_THEME/theme.zip" -d /usr/share/sddm/themes/
    rm -rf "$TMP_THEME"
else
    echo "    bereits installiert, übersprungen"
fi

# theme.conf.user statt theme.conf editieren: SDDM liest die Datei als Override,
# und ein späteres Theme-Update überschreibt sie nicht.
sudo tee "/usr/share/sddm/themes/$SDDM_THEME/theme.conf.user" >/dev/null <<'EOF'
[General]
Font="JetBrains Mono"
FontSize=11
ClockEnabled="true"
CustomBackground="true"
Background="backgrounds/wall.png"
UserIcon="false"
EOF

echo "==> SDDM: Wayland-Greeter + Theme aktivieren"
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-device-config.conf >/dev/null <<EOF
[Theme]
Current=$SDDM_THEME

[General]
# Wayland-Greeter erzwingen — auf diesem System gibt es kein Xorg (s. packages.txt).
DisplayServer=wayland
GreeterEnvironment=QT_WAYLAND_SHELL_INTEGRATION=layer-shell
EOF

# Eigene Session-Datei statt der aus dem COPR-Paket. Zwei Gründe:
#  1. start-hyprland statt nacktem 'Hyprland' — dieselbe Regel wie im .bash_profile.
#  2. bash -l: SDDM startet die Session OHNE Login-Shell, damit fehlt ~/.local/bin
#     im PATH — und genau da liegen 'keylight' und 'wallpaper', die aus binds.conf
#     bzw. exec-once aufgerufen werden. Ohne die Login-Shell scheitern beide still.
sudo tee /usr/share/wayland-sessions/hyprland-start.desktop >/dev/null <<'EOF'
[Desktop Entry]
Name=Hyprland (start-hyprland)
Comment=Hyprland über den offiziellen Wrapper, in einer Login-Shell
Exec=/bin/bash -lc "exec start-hyprland"
Type=Application
EOF

# enable, NICHT --now: --now würde die gerade laufende TTY-Session abschießen.
sudo systemctl set-default graphical.target
sudo systemctl enable sddm.service

echo "==> chezmoi-sourceDir persistieren (sonst kennt 'chezmoi apply' die Source nicht)"
mkdir -p "$HOME/.config/chezmoi"
printf 'sourceDir = "%s"\n' "$(pwd)/home" > "$HOME/.config/chezmoi/chezmoi.toml"

echo "==> Fertig. Weiter mit: chezmoi apply && reboot"
echo "    Login danach:      SDDM statt TTY-Autostart — Session 'Hyprland (start-hyprland)' wählen"
echo "    Wallpaper danach:  Bilder nach ~/Pictures/wallpapers legen, dann SUPER+SHIFT+W"
echo "    Toolchain danach:  source ~/.sdkman/bin/sdkman-init.sh && cd ~ && sdk env install"
echo "    Kubernetes danach: minikube config set rootless true && minikube start --driver=podman --container-runtime=containerd"
echo "    Ruby/Node danach:  einmalig 'eval \"\$(mise activate bash)\"' in ~/.bashrc eintragen (nicht Teil des Repos), dann neu einloggen"
