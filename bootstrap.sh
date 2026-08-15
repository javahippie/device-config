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

echo "==> chezmoi-sourceDir persistieren (sonst kennt 'chezmoi apply' die Source nicht)"
mkdir -p "$HOME/.config/chezmoi"
printf 'sourceDir = "%s"\n' "$(pwd)/home" > "$HOME/.config/chezmoi/chezmoi.toml"

echo "==> Fertig. Weiter mit: chezmoi apply && reboot"
echo "    Toolchain danach:  source ~/.sdkman/bin/sdkman-init.sh && cd ~ && sdk env install"
echo "    Kubernetes danach: minikube config set rootless true && minikube start --driver=podman --container-runtime=containerd"
echo "    Ruby/Node danach:  einmalig 'eval \"\$(mise activate bash)\"' in ~/.bashrc eintragen (nicht Teil des Repos), dann neu einloggen"
