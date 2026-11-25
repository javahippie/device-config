#!/usr/bin/env bash
# Systemschicht: COPR + Pakete + Flathub + SDKMAN + chezmoi-Verdrahtung.
# Idempotent — darf beliebig oft laufen.
set -euo pipefail
cd "$(dirname "$0")"

# dnf5-plugins liefert das `copr`-Unterkommando. Frueher stand hier zusaetzlich
# `copr enable ashbuk/Hyprland-Fedora` — Hyprland ist am 10.09.2026 samt COPR
# entfernt worden, Sway kommt regulaer aus Fedora. Wer die COPR noch aktiviert
# hat, raeumt sie mit `sudo dnf copr remove ashbuk/Hyprland-Fedora` weg;
# bootstrap.sh fasst sie nicht an, weil "einmal aktiviert" kein Zustand ist,
# den dieses Skript angelegt hat.
sudo dnf install -y dnf5-plugins

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

echo "==> Gruppe 'pipewire': Realtime-Prioritaeten fuer Audio"
# Fedora liefert mit dem pipewire-Paket eine Datei in /etc/security/limits.d/
# aus, die '@pipewire - rtprio 70' setzt. Die Regel greift aber NUR fuer
# Mitglieder dieser Gruppe — und in die traegt Fedora niemanden ein. Ohne den
# Schritt hier ist 'ulimit -r' schlicht 0, PipeWire faellt auf rtkit zurueck und
# bekommt Prioritaet 20 statt der in pipewire.conf angefragten 60. Hoerbar wird
# das als Knacken, sobald der Puffer klein wird.
#
# Hostunabhaengig: RT-faehiges PipeWire will man auf jeder Maschine, es kostet
# nichts.
#
# Angenehmer Nebeneffekt: das Rlimit vererbt sich ueber die PAM-Session auch in
# Flatpak-Sandboxes. Eine Anwendung dort braucht dann keine eigene
# rtkit-Berechtigung mehr, um Realtime zu bekommen.
#
# Muss NACH dem dnf-Lauf stehen — die Gruppe legt erst das pipewire-Paket an.
if ! getent group pipewire >/dev/null; then
    echo "    !! Gruppe 'pipewire' existiert nicht (liefert normalerweise das"
    echo "       pipewire-Paket mit) — uebersprungen."
elif [[ ",$(getent group pipewire | cut -d: -f4)," == *",$(id -un),"* ]]; then
    # Bewusst gegen /etc/group geprueft und nicht gegen 'id -nG': letzteres
    # zeigt die Gruppen der LAUFENDEN Session und aendert sich durch usermod
    # nicht. Ein zweiter Bootstrap in derselben Sitzung wuerde sonst jedes Mal
    # "hinzugefuegt" melden, obwohl laengst nichts mehr passiert.
    echo "    schon Mitglied"
else
    sudo usermod -aG pipewire "$(id -un)"
    echo "    hinzugefuegt — wirkt ERST NACH AB- UND ANMELDEN. PAM vergibt das"
    echo "    Rlimit beim Session-Start; ein neues Terminal reicht NICHT."
    echo "    Gegenprobe danach: 'ulimit -r' muss 70 sagen, und"
    echo "    'ps -Lo cls,rtprio -p \$(pgrep -x pipewire)' den Data-Loop auf RR 60."
fi

echo "==> Flathub aktivieren (voll, nicht Fedoras gefilterte Auswahl)"
flatpak remote-add --user --if-not-exists flathub https://dl.flathub.org/repo/flathub.flatpakrepo

if [ -f flatpaks.txt ]; then
    echo "==> Flatpaks aus flatpaks.txt"
    mapfile -t FLATS < <(sed 's/#.*//' flatpaks.txt | awk 'NF{print $1}')
    [ "${#FLATS[@]}" -gt 0 ] && flatpak install --user -y --noninteractive flathub "${FLATS[@]}"
fi

echo "==> udev-Regeln: Stream Deck und ITE-8291-Tastaturbeleuchtung ohne root, kein USB-Wakeup"
# Alle drei Regeln sind hostunabhängig: fehlt die Hardware, laufen sie ins Leere.
# 70-usb-no-wakeup: Logi-Bolt-Empfaenger und Hama-Maus verlieren das Weckrecht,
# weil ein anliegendes USB-Weck-Signal den S3 abbricht und die RX 6400 in D0
# das Zurueckrollen nicht ueberlebt (28.09.2026, s. README "Suspend haengt
# sich auf"). Kostet nichts: Wecken per Tastatur geht auf dem Board ohnehin nicht.
sudo cp udev/40-streamdeck.rules /etc/udev/rules.d/40-streamdeck.rules
sudo cp udev/60-ite8291-kbdlight.rules /etc/udev/rules.d/60-ite8291-kbdlight.rules
sudo cp udev/70-usb-no-wakeup.rules /etc/udev/rules.d/70-usb-no-wakeup.rules
sudo udevadm control --reload-rules
sudo udevadm trigger
# trigger kehrt zurueck, bevor udevd fertig ist -- wer direkt danach
# /sys/.../power/wakeup liest, sieht noch den alten Wert (so am 28.09.2026).
sudo udevadm settle

# RGB-Tastaturbeleuchtung im "book". Nur wenn der Controller wirklich steckt —
# auf dem cube wäre das Tool sinnlose Fracht. Version gepinnt wie beim
# SDDM-Theme: ein späterer Bootstrap soll nicht unter der Hand eine andere
# Version ziehen und das Verhalten ändern.
# Kein DKMS-Modul (ite_8291 aus TUXEDOs Repo) — s. README, Abschnitt
# "Tastaturbeleuchtung".
if lsusb 2>/dev/null | grep -qi '048d:6004' \
   || grep -qs 048d /sys/bus/usb/devices/*/idVendor; then
    echo "==> ITE-8291-Controller erkannt: Steuertool installieren"
    pipx install 'ite8291r3-ctl==0.4' || echo "    (bereits installiert)"
fi

echo "==> Podman-Socket (rootless, Docker-API-kompatibel für Tools, die docker.sock erwarten)"
systemctl --user enable --now podman.socket

echo "==> Bluetooth-Dienst (bluez installiert die Unit, aktiviert sie aber nicht)"
# --now ist hier gefahrlos, im Gegensatz zu sddm: der Dienst hängt an keiner Session.
sudo systemctl enable --now bluetooth.service

echo "==> Drucken/Scannen: avahi-Daemon (Discovery-Grundlage für CUPS UND sane-airscan)"
# Beide reden per D-Bus mit avahi, nicht über glibc — ohne laufenden Daemon
# bleibt `lpinfo -v` leer und der Scanner taucht nirgends auf. Keine Fehlermeldung,
# nur nichts. --now ist gefahrlos, der Dienst hängt an keiner Session.
sudo systemctl enable --now avahi-daemon.service

echo "==> CUPS"
# cups.service, NICHT nur die von Fedora vorkonfigurierte cups.socket: die startet
# den Server erst beim ersten Zugriff, und der hat dann die DNS-SD-Landschaft noch
# nicht gesehen. Ergebnis wäre ein Druckdialog, der beim Öffnen leer ist und sich
# erst Sekunden später füllt — oder gar nicht, wenn die App nur einmal fragt.
sudo systemctl enable --now cups.service

echo "==> nss-mdns verdrahten (.local-Auflösung für glibc)"
# Das Paket nss-mdns liefert NUR die .so-Dateien: kein Post-Scriptlet, keine
# nsswitch-Änderung (geprüft, `dnf repoquery --scripts nss-mdns` ist leer).
# Ohne diesen Schritt ist es installiert und trotzdem vollständig wirkungslos.
#
# Und NICHT /etc/nsswitch.conf von Hand editieren: die Datei gehört authselect
# ("Generated by authselect / Do not modify this file manually" steht oben drin),
# ein Handeingriff ist beim nächsten `authselect apply-changes` weg. with-mdns4
# setzt den Eintrag außerdem an die richtige STELLE — vor `resolve`. Dahinter
# wäre er wirkungslos, denn `resolve [!UNAVAIL=return]` bricht die Kette ab,
# sobald systemd-resolved erreichbar ist (und das ist es hier immer).
#
# Idempotent: enable-feature auf ein bereits aktives Feature ist ein No-op.
# Kein with-mdns6 — auf einem IPv4-Netz kostet das nur zusätzliche Timeouts.
sudo authselect enable-feature with-mdns4

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

echo "==> Java/AWT: Sway als non-reparenting WM bekanntmachen"
# Gefunden am NetBeans (deshalb steht es direkt hier), gilt aber für JEDE
# Swing-Anwendung auf dieser Session — die vollständige Herleitung steht in der
# installierten Datei selbst.
#
# BEWUSST NICHT auf cube eingegrenzt: beide Hosts fahren Sway, und das Problem hängt am Compositor, nicht an der
# Hardware.
#
# 0644 root:root wie ausgeliefert — /etc/environment wird von pam_env für JEDE
# Anmeldung gelesen und muss deshalb für alle lesbar sein. Sonst hängt nichts
# an den Rechten: der Inhalt wird nicht ausgeführt, sondern nur als KEY=WERT
# übernommen.
sudo install -o root -g root -m 0644 \
    system/java-nonreparenting.environment /etc/environment

echo "==> RNNoise-LADSPA-Plugin (Mikrofon-Rauschunterdrückung für PipeWire)"
# Kein Fedora-Paket: das Repo-Paket 'rnnoise' liefert NUR /usr/lib64/librnnoise.so,
# also die Bibliothek ohne Plugin-Wrapper. Ein noise-suppression-for-voice gibt es
# in Fedora nicht (geprüft). Also Release-Binary wie bei minikube/lazydocker.
# Verkabelt wird es von dot_config/pipewire/pipewire.conf.d/99-rnnoise.conf.
RNNOISE_VER="1.10"             # gepinnt, nicht 'latest' — s. lazydocker oben
RNNOISE_SHA="811390b6eb6e28dde023c70590c74d26e74ebb2e595bcf4b95af2341db160e99"
RNNOISE_SO="/usr/local/lib/ladspa/librnnoise_ladspa.so"
RNNOISE_STAMP="/usr/local/lib/ladspa/.rnnoise-version"
# Existenz der .so allein reicht als Test NICHT: nach einem Versions-Bump oben
# wäre sie ja da, nur eben die alte. Deshalb die Version danebenlegen.
if [ "$(cat "$RNNOISE_STAMP" 2>/dev/null || true)" != "$RNNOISE_VER" ]; then
    TMP_RNN="$(mktemp -d)"
    curl -Lo "$TMP_RNN/linux-rnnoise.zip" \
        "https://github.com/werman/noise-suppression-for-voice/releases/download/v${RNNOISE_VER}/linux-rnnoise.zip"
    # Das Projekt veröffentlicht KEINE checksums.txt (anders als lazydocker).
    # Die Summe hier ist die des geprüften v1.10-Assets — sie muss beim
    # Versions-Bump mit angefasst werden, sonst bricht der Bootstrap hier ab.
    echo "${RNNOISE_SHA}  ${TMP_RNN}/linux-rnnoise.zip" | sha256sum -c -
    # Nur das LADSPA-Plugin. Das Archiv enthält außerdem VST3/LV2/VST-Varianten
    # (~50 MB entpackt), die hier niemand braucht.
    unzip -qo "$TMP_RNN/linux-rnnoise.zip" "linux-rnnoise/ladspa/librnnoise_ladspa.so" -d "$TMP_RNN"
    sudo install -Dm0644 "$TMP_RNN/linux-rnnoise/ladspa/librnnoise_ladspa.so" "$RNNOISE_SO"
    echo "$RNNOISE_VER" | sudo tee "$RNNOISE_STAMP" >/dev/null
    rm -rf "$TMP_RNN"
else
    echo "    bereits installiert (v$RNNOISE_VER), übersprungen"
fi

echo "==> SDKMAN (Java-Toolchain-Manager, kein dnf-Paket)"
if [ ! -d "$HOME/.sdkman" ]; then
    curl -s "https://get.sdkman.io" | bash
else
    echo "    bereits installiert, übersprungen"
fi

echo "==> Emacs-Pakete aus ELPA — ESS, markdown-mode, Magit, Treemacs, clojure-mode, Paredit"
# Die ersten drei gibt es in Fedora nicht oder nicht brauchbar (`dnf search
# emacs-ess` / `emacs-markdown` / `emacs-treemacs`: jeweils keine Übereinstimmung;
# emacs-magit existiert, s. u.).
#
# ess, markdown-mode und magit kommen aus GNU bzw. NonGNU ELPA — den zwei
# Archiven, die Emacs 30 ab Werk kennt. Beide signieren, die Installation legt
# neben <paket>-<ver>/ eine <paket>-<ver>.signed ab; das ersetzt die gepinnte
# SHA-256, die bei minikube & Co. nötig ist.
#
# magit: Fedora hat zwar ein emacs-magit, aber 4.2.0 vom Dezember 2024 (Stand
# 10/2026) und läuft gegen das eingebaute transient 0.7 aus emacs-common. NonGNU ELPA liefert
# 4.7.1 samt transient 0.13 aus GNU ELPA, alles signiert — derselbe Weg wie bei
# ess. Beides zugleich wäre die schlechteste Variante: package.el zieht die
# ELPA-Kopie von transient vor der eingebauten, und das alte Fedora-Magit liefe
# dann gegen eine Bibliothek, gegen die es nie gebaut wurde. Also NUR ELPA.
# Magit zieht sieben Abhängigkeiten nach (compat, cond-let, llama, with-editor,
# transient, magit-section, seq) — alle aus GNU/NonGNU ELPA, keine aus MELPA.
#
# clojure-mode und paredit: beide aus NonGNU ELPA (signiert). MELPA hat sie
# zwar auch, mit Datumsversion — die Prioritaeten unten halten sie auf NonGNU.
#
# treemacs gibt es NUR auf MELPA, und MELPA signiert nicht. Das ist die bewusste
# Ausnahme von der Regel oben und der einzige Grund, warum MELPA hier überhaupt
# auftaucht. Unsigniert bleiben dadurch treemacs selbst und vier seiner acht
# Abhängigkeiten (s, ht, pfuture, cfrs).
#
# package-archive-priorities ist das, was die Ausnahme eine Ausnahme bleiben
# lässt: MELPA versioniert nach Datum (20260812.1430) und schlägt damit JEDE
# GNU-ELPA-Version. Ohne die Zeile würden ess und markdown-mode hier still auf
# unsignierte MELPA-Kopien wechseln, und von treemacs' Abhängigkeiten käme keine
# einzige mehr aus GNU ELPA. Mit ihr zieht MELPA nur für das, was es sonst
# nirgends gibt. Dieselbe Liste steht in dot_config/emacs/init.el — hier
# notgedrungen doppelt, denn dieses Skript läuft vor dem ersten `chezmoi apply`.
#
# package-user-dir wird ausdrücklich gesetzt, und das ist kein Schmuck:
# bootstrap.sh läuft VOR dem ersten `chezmoi apply`, ~/.config/emacs existiert
# also noch nicht. Emacs 30 nimmt das XDG-Verzeichnis aber nur, wenn es schon da
# ist, und fiele sonst auf ~/.emacs.d zurück (nachgemessen). ESS läge dann an
# einer Stelle, an der der spätere Emacs es nie sucht.
EMACS_ELPA="$HOME/.config/emacs/elpa"
for pkg in ess markdown-mode magit treemacs clojure-mode paredit; do
    if compgen -G "$EMACS_ELPA/$pkg-[0-9]*" >/dev/null; then
        echo "    $pkg bereits installiert, übersprungen"
        continue
    fi
    mkdir -p "$EMACS_ELPA"
    emacs --batch --eval "(progn
        (setq package-user-dir \"$EMACS_ELPA\")
        (require 'package)
        (add-to-list 'package-archives '(\"melpa\" . \"https://melpa.org/packages/\") t)
        (setq package-archive-priorities '((\"gnu\" . 10) (\"nongnu\" . 5) (\"melpa\" . 0)))
        (package-initialize)
        (package-refresh-contents)
        (package-install '$pkg))"
done

echo "==> Java-Language-Server (Eclipse jdtls) nach ~/.local/opt/jdtls"
# Fuer Eglot in Emacs (java-ts-mode, s. dot_config/emacs/init.el). Kein
# Fedora-Paket, kein Flathub — Eclipse liefert ein Tarball mit .sha256 daneben.
# Gepinnt wie llama.cpp unten: Milestone-Build, nicht "latest", und bewusst
# nicht der Build vom selben Tag (1.63.0 erschien am 19.10. um 13:22, an dem
# Tag, an dem das hier entstand). Update = Version + Dateiname hier aendern.
# Gilt fuer beide Hosts: ~53 MB, gestartet wird jdtls erst beim ersten .java.
JDTLS_VERSION=1.62.0
JDTLS_TARBALL=jdt-language-server-1.62.0-202610131109.tar.gz
JDTLS_DIR="$HOME/.local/opt/jdtls"
if [ ! -x "$JDTLS_DIR/$JDTLS_VERSION/bin/jdtls" ]; then
    TMP_JDTLS="$(mktemp -d)"
    curl -fsSL -o "$TMP_JDTLS/$JDTLS_TARBALL" \
        "https://download.eclipse.org/jdtls/milestones/$JDTLS_VERSION/$JDTLS_TARBALL"
    curl -fsSL -o "$TMP_JDTLS/sum" \
        "https://download.eclipse.org/jdtls/milestones/$JDTLS_VERSION/$JDTLS_TARBALL.sha256"
    # Die .sha256 enthaelt nur den Hash, ohne Dateinamen — sha256sum -c braucht beides.
    (cd "$TMP_JDTLS" && echo "$(awk '{print $1}' sum)  $JDTLS_TARBALL" | sha256sum -c --quiet)
    mkdir -p "$JDTLS_DIR/$JDTLS_VERSION"
    tar -xzf "$TMP_JDTLS/$JDTLS_TARBALL" -C "$JDTLS_DIR/$JDTLS_VERSION"
    rm -rf "$TMP_JDTLS"
else
    echo "    bereits installiert ($JDTLS_VERSION), übersprungen"
fi
ln -sfn "$JDTLS_VERSION" "$JDTLS_DIR/current"

echo "==> Suspend: nur S3, kein s2idle-Fallback"
# systemd probiert per Default `SuspendState=mem standby freeze` der Reihe nach
# durch. Auf diesem Board ist das eine Falle, und sie hat den Rechner am
# 24.08.2026 hart aufgehaengt (Journal Boot -1, ab 09:03:25):
#
#  1. Der Idle-Daemon (damals hypridle, heute swayidle) loest nach 15 min
#     `systemctl suspend` aus. Erster Versuch `mem`
#     = S3. Der Kernel bricht beim Einfrieren der CPUs ab:
#     "Wakeup pending. Abort CPU freeze" — ein Wakeup-Event lag schon an.
#     Das allein ist harmlos, der Kernel rollt sauber zurueck.
#  2. Weil `mem` einen Fehler zurueckgibt, faellt systemd auf `freeze` = s2idle
#     zurueck. Die iGPU lehnt das ab, das BIOS ist nicht dafuer konfiguriert:
#     "Unsupported suspend state 1" -> amdgpu_pmops_suspend returns -22.
#  3. Beim Zurueckrollen aus diesem halben s2idle antwortet die SMU der dGPU
#     nicht mehr: "SMU: No response", "RunDcBtc failed",
#     "resume of IP block <smu> failed -62". Die Karte kommt nicht wieder hoch.
#  4. Ab da laeuft der sdma0-Ring der dGPU in einer Endlosschleife aus Timeout
#     und Reset, alle zwei Sekunden, 70 Minuten lang. Kernel und Netzwerk sind
#     formal noch da, aber der Compositor haengt am toten Device — kein Bild,
#     kein SSH-Login, und der Power-Button hilft auch nicht mehr, weil das
#     ACPI-Event bei logind zwar ankommt, das Herunterfahren aber auf die
#     Session wartet. Es bleibt der harte Reset.
#
# Der Fallback ist der einzige Schritt in der Kette, der hier nichts bringt:
# s2idle kann dieses Board nicht. Ohne ihn endet Schritt 1 damit, dass der
# Rechner einfach wach bleibt und es fuenf Minuten spaeter nochmal versucht.
#
# NICHT stattdessen `mem_sleep_default=deep` in die Kernel-Cmdline: das setzt
# nur, was /sys/power/mem_sleep ohnehin schon auf [deep] stehen hat, und
# aendert an systemds Fallback-Liste genau nichts.
sudo mkdir -p /etc/systemd/sleep.conf.d
sudo tee /etc/systemd/sleep.conf.d/10-device-config.conf >/dev/null <<'EOF'
[Sleep]
SuspendState=mem
EOF

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
#    ein wlroots-Protokoll — Sway kann es, weston nicht). Qt kam hoch, bekam
#    keine Surface und war nach einer Sekunde weg: schwarzer Bildschirm, kein
#    Input, im journal NUR die PAM-Zeilen von sddm-helper.
# Merksatz: Greeter-Umgebung ist NICHT die Session-Umgebung. Was für die
# Sway-Session richtig ist, gilt hier nicht.
sudo mkdir -p /etc/sddm.conf.d
sudo tee /etc/sddm.conf.d/10-device-config.conf >/dev/null <<EOF
[Theme]
Current=$SDDM_THEME
EOF

# KEINE eigene Session-Datei. sway bringt seine wayland-sessions/sway.desktop
# selbst mit, die gilt unangetastet.
#
# Hier stand zu Hyprland-Zeiten mal eine eigene mit
# `Exec=/bin/bash -lc "exec start-hyprland"` — die hat einen Login-Loop erzeugt
# (Session startet, stirbt sofort, Greeter kommt wieder). Zwei Denkfehler drin,
# die auch fuer jeden kuenftigen Compositor gelten:
#  1. Ein `start-*`-Wrapper ist fuer den TTY-Start gedacht: er macht Session- und
#     D-Bus-Setup, das es ohne Display-Manager sonst nicht gibt. Unter SDDM macht
#     das der Display-Manager schon — der Wrapper ist da falsch, nicht nötig.
#  2. Anführungszeichen im Exec= einer .desktop-Datei folgen der
#     Desktop-Entry-Spec, nicht Shell-Quoting.
#
# Folge davon: SDDM startet die Session OHNE Login-Shell, ~/.local/bin ist also
# nicht im PATH. Deshalb rufen sway/binds und sway/base 'keylight' und
# 'wallpaper' mit vollem Pfad auf — robuster als eine Login-Shell-Krücke.

# Lokale LLMs: llama.cpp-Router und OpenCode (nur cube).
#
# Beides handinstalliert unter ~/.local/opt/<tool>/<version> mit Symlink
# `current`, weil dnf hier nicht hilft: Fedoras llama-cpp ist Build b6153 vom
# August 2025 und gegen HIP gebaut, das die RX 6400 (gfx1034) nicht kennt;
# OpenCode gibt es gar nicht als Paket. Versionen sind GEPINNT, bewusst kein
# "latest": ein Modell, das gestern lief, soll heute genauso laufen. Update ist
# eine Zeile hier plus Symlink. Die Hostweiche dazu steht ausserdem in
# home/.chezmoiignore (Unit, Presets, OpenCode-Config).
#
# NUR CUBE: 64 GB RAM und 12 Kerne sind die Voraussetzung, auf dem book waere
# ein 20-GB-Modell nicht einmal ladbar. Modelle selbst laedt das Script NICHT,
# das sind 50 GB aus Hugging Face: `llm pull <URL>` nach dem ersten Login.
if [ "$(hostname -s)" = cube ]; then
    echo "==> Lokale LLMs: llama.cpp + OpenCode nach ~/.local/opt (nur cube)"
    LLAMA_BUILD=b11429      # = Release v0.6.0 vom 05.10.2026 (stabiler Tag, kein Tagesbuild)
    OPENCODE_VERSION=v1.19.0
    OPT="$HOME/.local/opt"
    mkdir -p "$OPT/llama.cpp" "$OPT/opencode" "$HOME/.local/share/llama.cpp/models"

    if [ ! -x "$OPT/llama.cpp/$LLAMA_BUILD/llama-server" ]; then
        # Vulkan-Build: laeuft ueber RADV auf jeder AMD-Karte, ohne ROCm.
        # --strip-components=1, weil das Archiv ein Verzeichnis mit Build-Nummer
        # enthaelt, der Name hier aber selbst schon der Versionsordner ist.
        mkdir -p "$OPT/llama.cpp/$LLAMA_BUILD"
        curl -fsSL "https://github.com/ggml-org/llama.cpp/releases/download/$LLAMA_BUILD/llama-$LLAMA_BUILD-bin-ubuntu-vulkan-x64.tar.gz" \
            | tar -xz -C "$OPT/llama.cpp/$LLAMA_BUILD" --strip-components=1
    fi
    ln -sfn "$LLAMA_BUILD" "$OPT/llama.cpp/current"

    if [ ! -x "$OPT/opencode/$OPENCODE_VERSION/opencode" ]; then
        mkdir -p "$OPT/opencode/$OPENCODE_VERSION"
        curl -fsSL "https://github.com/anomalyco/opencode/releases/download/$OPENCODE_VERSION/opencode-linux-x64.tar.gz" \
            | tar -xz -C "$OPT/opencode/$OPENCODE_VERSION"
    fi
    ln -sfn "$OPENCODE_VERSION" "$OPT/opencode/current"

    # Die Unit kommt per chezmoi; enable --now ist hier unkritisch, anders als
    # bei sddm unten: der Router laedt ohne Anfrage kein Modell und belegt
    # im Leerlauf nichts.
    systemctl --user daemon-reload
    systemctl --user enable --now llama-server.service
fi

# enable, NICHT --now: --now würde die gerade laufende TTY-Session abschießen.
sudo systemctl set-default graphical.target
sudo systemctl enable sddm.service

echo "==> chezmoi-sourceDir persistieren (sonst kennt 'chezmoi apply' die Source nicht)"
mkdir -p "$HOME/.config/chezmoi"
printf 'sourceDir = "%s"\n' "$(pwd)/home" > "$HOME/.config/chezmoi/chezmoi.toml"

echo "==> Fertig. Weiter mit: chezmoi apply && reboot"
echo "    Login danach:      SDDM statt TTY-Autostart — Session 'Sway' wählen"
echo "    Konfig pruefen:    'sway -C' liest die Konfiguration und meldet Fehler,"
echo "                       ohne eine laufende Session anzufassen."
echo "    Wallpaper danach:  Bilder nach ~/Pictures/wallpapers legen, dann SUPER+SHIFT+W"
echo "    lazydocker danach: export DOCKER_HOST=\"unix://\$XDG_RUNTIME_DIR/podman/podman.sock\" in ~/.bashrc"
echo "    Toolchain danach:  source ~/.sdkman/bin/sdkman-init.sh && cd ~ && sdk env install"
echo "    Kubernetes danach: minikube config set rootless true && minikube start --driver=podman --container-runtime=containerd"
echo "    Ruby/Node danach:  einmalig 'eval \"\$(mise activate bash)\"' in ~/.bashrc eintragen (nicht Teil des Repos), dann neu einloggen"
