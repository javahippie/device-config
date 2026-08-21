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
# --refresh ist nicht optional: ohne das nimmt dnf5 den Metadaten-Cache, und der
# ist auf einer frisch installierten Maschine Wochen alt. Die darin verzeichneten
# RPM-Pfade sind dann längst durch neuere Builds ersetzt — der Mirror antwortet
# mit 404 (NICHT "No match for argument", das wäre ein falscher Paketname).
# Genau so sind die drei Font-Pakete beim ersten Lauf gescheitert.
sudo dnf install --refresh -y "${PKGS[@]}"

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

echo "==> Bluetooth-Dienst (bluez installiert die Unit, aktiviert sie aber nicht)"
# --now ist hier gefahrlos, im Gegensatz zu sddm: der Dienst hängt an keiner Session.
sudo systemctl enable --now bluetooth.service

echo "==> minikube (kein dnf-Paket, offizielle Empfehlung: Binary statt Repo)"
if ! command -v minikube >/dev/null 2>&1; then
    TMP_MINIKUBE="$(mktemp)"
    curl -Lo "$TMP_MINIKUBE" https://storage.googleapis.com/minikube/releases/latest/minikube-linux-amd64
    sudo install "$TMP_MINIKUBE" /usr/local/bin/minikube
    rm -f "$TMP_MINIKUBE"
else
    echo "    bereits installiert, übersprungen"
fi

echo "==> lazydocker (kein Fedora-Paket — geprüft, 404 —, also Release-Binary wie minikube)"
LAZYDOCKER_VER="0.25.2"        # gepinnt, nicht 'latest': sonst wandert die Version
                                # bei jedem bootstrap-Lauf unbemerkt weiter
if ! command -v lazydocker >/dev/null 2>&1; then
    TMP_LD="$(mktemp -d)"
    LD_TGZ="lazydocker_${LAZYDOCKER_VER}_Linux_x86_64.tar.gz"
    LD_URL="https://github.com/jesseduffield/lazydocker/releases/download/v${LAZYDOCKER_VER}"
    curl -Lo "$TMP_LD/$LD_TGZ" "$LD_URL/$LD_TGZ"
    curl -Lo "$TMP_LD/checksums.txt" "$LD_URL/checksums.txt"
    # Anders als bei minikube liefert das Projekt Prüfsummen — dann auch nutzen.
    # Schlägt das fehl, bricht der Bootstrap ab (set -e), statt eine kaputte
    # oder untergeschobene Binary zu installieren.
    ( cd "$TMP_LD" && grep " ${LD_TGZ}\$" checksums.txt | sha256sum -c - )
    tar -xzf "$TMP_LD/$LD_TGZ" -C "$TMP_LD" lazydocker
    sudo install "$TMP_LD/lazydocker" /usr/local/bin/lazydocker
    rm -rf "$TMP_LD"
else
    echo "    bereits installiert, übersprungen"
fi

echo "==> Apache NetBeans (kein Fedora-Paket, kein nutzbares COPR — RPM bewusst statt Flatpak)"
# Bezugswege, alle geprüft:
#   Fedora-Repos      — nichts vorhanden.
#   COPR              — nur faux/netbeans, ein Testprojekt mit chroots=0, also
#                       ohne jeden Build. Unbrauchbar.
#   Flathub           — org.apache.netbeans EXISTIERT dort in Version 31.
#                       Bewusst NICHT genommen: die Sandbox schneidet die IDE von
#                       ~/.sdkman/candidates/java, ~/.m2 und ~/sources ab. Das
#                       ließe sich mit `flatpak override` aufbohren, aber dann
#                       hat man eine Sandbox, die überall Löcher hat — der Zweck
#                       ist damit weg und der Wartungsaufwand bleibt.
#   Apache direkt     — nur ein plattformunabhängiges .zip ohne JDK.
#
# Also das RPM von Codelerity, die die Linux-Pakete für das NetBeans-Projekt
# bauen. Es bringt ein eigenes JDK unter /usr/lib/apache-netbeans/jdk mit und
# landet, anders als minikube/lazydocker, ordentlich in der RPM-Datenbank —
# `dnf remove` und `drift-check.sh` sehen es also.
#
# Preis dieser Entscheidung: es gibt KEIN dnf-Repo dahinter, also auch kein
# `dnf upgrade` für NetBeans. Die Version unten muss bei jedem Release von Hand
# gebumpt werden, sonst bleibt sie stehen.
#
# Das RPM ist UNSIGNIERT (`rpm -qi` zeigt "Signature: (none)"). Die SHA256 ist
# damit die einzige Integritätsprüfung und nicht optional; sie stammt von
# https://www.codelerity.com/netbeans/ und gehört bei jedem Bump mit aktualisiert.
#
# 632 MB Download — der Bootstrap läuft dadurch spürbar länger.
NETBEANS_VER="31"
NETBEANS_TAG="v31-build1"      # gepinnt, nicht 'latest' — s. lazydocker oben
NETBEANS_SHA="e6e52873f76a449840484ba6c984b46a6a0bdf5dda42a3a453db9890a7eec6ec"
if ! rpm -q apache-netbeans >/dev/null 2>&1; then
    TMP_NB="$(mktemp -d)"
    NB_RPM="apache-netbeans-${NETBEANS_VER}-0.x86_64.rpm"
    curl -Lo "$TMP_NB/$NB_RPM" \
        "https://github.com/codelerity/netbeans-packages/releases/download/${NETBEANS_TAG}/${NB_RPM}"
    echo "${NETBEANS_SHA}  ${TMP_NB}/${NB_RPM}" | sha256sum -c -
    sudo dnf install -y "$TMP_NB/$NB_RPM"
    rm -rf "$TMP_NB"
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

echo "==> SDDM: Theme aktivieren"
# NUR das Theme setzen, sonst nichts. Alles, was hier mal an [General]-Keys stand
# (DisplayServer, GreeterEnvironment), war falsch und hat den Greeter zerlegt:
#  - DisplayServer=wayland ist bei Fedora ohnehin Default. sddm-wayland-generic
#    liefert laut Spec KEINE Dateien, es zieht nur weston rein und markiert die
#    Displayserver-Wahl.
#  - QT_WAYLAND_SHELL_INTEGRATION=layer-shell war der eigentliche Killer: der
#    Greeter-Compositor ist weston, und weston kann kein wlr-layer-shell (das ist
#    ein wlroots-Protokoll — Hyprland kann es, weston nicht). Qt kam hoch, bekam
#    keine Surface und war nach einer Sekunde weg: schwarzer Bildschirm, kein
#    Input, im journal NUR die PAM-Zeilen von sddm-helper.
# Merksatz: Greeter-Umgebung ist NICHT die Session-Umgebung. Was für Hyprland
# richtig ist, gilt hier nicht.
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-device-config.conf >/dev/null <<EOF
[Theme]
Current=$SDDM_THEME
EOF

# KEINE eigene Session-Datei. Hier stand mal eine mit
# `Exec=/bin/bash -lc "exec start-hyprland"` — die hat einen Login-Loop erzeugt
# (Session startet, stirbt sofort, Greeter kommt wieder). Zwei Denkfehler drin:
#  1. start-hyprland ist der Wrapper für den TTY-Start: er macht Session- und
#     D-Bus-Setup, das es ohne Display-Manager sonst nicht gibt. Unter SDDM macht
#     das der Display-Manager schon — der Wrapper ist da falsch, nicht nötig.
#  2. Anführungszeichen im Exec= einer .desktop-Datei folgen der
#     Desktop-Entry-Spec, nicht Shell-Quoting.
# Es gilt die Session-Datei aus dem COPR-Paket, unangetastet.
#
# Folge davon: SDDM startet die Session OHNE Login-Shell, ~/.local/bin ist also
# nicht im PATH. Deshalb rufen binds.conf und base.conf 'keylight' und
# 'wallpaper' mit vollem Pfad auf — robuster als eine Login-Shell-Krücke.

# enable, NICHT --now: --now würde die gerade laufende TTY-Session abschießen.
sudo systemctl set-default graphical.target
sudo systemctl enable sddm.service

echo "==> chezmoi-sourceDir persistieren (sonst kennt 'chezmoi apply' die Source nicht)"
mkdir -p "$HOME/.config/chezmoi"
printf 'sourceDir = "%s"\n' "$(pwd)/home" > "$HOME/.config/chezmoi/chezmoi.toml"

echo "==> Fertig. Weiter mit: chezmoi apply && reboot"
echo "    Login danach:      SDDM statt TTY-Autostart — Session 'Hyprland' wählen"
echo "    Wallpaper danach:  Bilder nach ~/Pictures/wallpapers legen, dann SUPER+SHIFT+W"
echo "    lazydocker danach: export DOCKER_HOST=\"unix://\$XDG_RUNTIME_DIR/podman/podman.sock\" in ~/.bashrc"
echo "    Toolchain danach:  source ~/.sdkman/bin/sdkman-init.sh && cd ~ && sdk env install"
echo "    Kubernetes danach: minikube config set rootless true && minikube start --driver=podman --container-runtime=containerd"
echo "    Ruby/Node danach:  einmalig 'eval \"\$(mise activate bash)\"' in ~/.bashrc eintragen (nicht Teil des Repos), dann neu einloggen"
