#!/usr/bin/env bash
# Systemschicht des Cube: Pakete + Flathub. Idempotent — darf beliebig oft laufen.
set -euo pipefail
cd "$(dirname "$0")"

echo "==> dnf-Pakete aus packages.txt"
# Kommentare und Leerzeilen filtern, Inline-Kommentare abschneiden
mapfile -t PKGS < <(sed 's/#.*//' packages.txt | awk 'NF{print $1}')
sudo dnf install -y "${PKGS[@]}"

echo "==> Flathub aktivieren (voll, nicht Fedoras gefilterte Auswahl)"
flatpak remote-add --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

echo "==> SDKMAN (Java-Toolchain-Manager, kein dnf-Paket)"
if [ ! -d "$HOME/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
else
    echo "    bereits installiert, übersprungen"
fi

echo "==> Fertig. Weiter mit: chezmoi init --apply --source ./home"
echo "    Danach Toolchain ziehen:  source ~/.sdkman/bin/sdkman-init.sh && cd ~ && sdk env install"
