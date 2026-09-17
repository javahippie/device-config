#!/usr/bin/env bash
# Pakete, die von Hand installiert wurden, aber nicht in packages.txt stehen.
# Ad-hoc-Installieren ist erlaubt — verstecken gilt nicht.
#
# Ohne Argument macht das Skript genau das, was es immer gemacht hat: die Liste
# ausgeben, eine Zeile pro Paket. Das ist bewusst so geblieben, weil es an
# mehreren Stellen im README und in Gewohnheiten steckt.
#
# `pick` ist der Zusatz: dieselbe Liste in fzf, mehrere markieren und in EINEM
# Rutsch entscheiden, was damit passieren soll. Drei Ausgaenge, weil Drift drei
# verschiedene Dinge bedeuten kann:
#
#   CTRL-R  entfernen           — war ein Versuch, kann weg (`dnf remove`)
#   CTRL-P  nach packages.txt   — gehoert dazu, war nur nie eingetragen
#   CTRL-E  als erwartet ablegen — soll da sein, gehoert aber nicht ins Setup
#                                  (packages-expected.txt)
#
# Warum die dritte Kategorie ueberhaupt: `dnf repoquery --userinstalled` zaehlt
# den kompletten Anaconda-Sockel mit. Auf diesem Rechner sind das die 419 Pakete
# aus Transaktion 1 vom 15.08.2026 — deshalb stehen bash, glibc, kernel, sudo
# und systemd in der Drift-Liste, ohne dass jemand sie "von Hand installiert"
# haette. Sie sind weder ein Fehler noch ein Bestandteil des Setups; sie sind
# erwartet. Ohne einen Platz fuer diese Kategorie bleibt die Liste dauerhaft
# rund 60 Zeilen lang, und eine Liste, die man taeglich ueberliest, meldet
# irgendwann auch das eine echte Paket nicht mehr.
#
# packages-expected.txt wird BEWUSST NICHT vorbefuellt (auch nicht automatisch
# aus `dnf history info 1`, was technisch ginge). Jeder Eintrag entsteht durch
# eine eigene Entscheidung am Gegenstand — sonst steht am Ende eine generierte
# Datei im Repo, die niemand je gelesen hat, und genau das soll drift-check
# ja verhindern.
set -euo pipefail
cd "$(dirname "$0")"

EXPECTED=packages-expected.txt

# Namen aus einer Paketliste: Kommentare weg, erstes Wort pro Zeile, sortiert.
# Gleiche Regel fuer packages.txt und packages-expected.txt — die beiden Dateien
# haben mit Absicht dasselbe Format, damit man Zeilen zwischen ihnen hin- und
# herschieben kann, ohne sie umzuschreiben.
names() {
    sed 's/#.*//' "$@" 2>/dev/null | awk 'NF{print $1}' | sort -u
}

drift() {
    comm -23 \
        <(dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sort -u) \
        <(names packages.txt "$EXPECTED")
}

# Dieselbe Liste, aber mit dem einen Feld, das sie ueberhaupt beurteilbar macht:
# dem Installationsgrund aus der RPM-Datenbank.
#
# Der Grund, warum es das braucht: `dnf repoquery --userinstalled` (die Quelle
# von drift()) wirft ZWEI verschiedene Dinge in denselben Topf. Auf diesem
# Rechner sind von 67 Drift-Eintraegen
#
#   38  Group          — kam ueber eine comps-Gruppe der Erstinstallation.
#                        Das sind bash, glibc, coreutils, rpm, sudo: nichts
#                        davon hat je jemand einzeln ausgesucht.
#   28  User           — wirklich explizit installiert. NUR hier lohnt das
#                        Nachdenken, und nur hier ist "entfernen" ueberhaupt
#                        eine sinnvolle Frage.
#    1  External User  — an dnf vorbei installiert (heruntergeladenes .rpm).
#
# Ohne diese Spalte steht der halbe Anaconda-Sockel unkommentiert zwischen den
# echten Ad-hoc-Installationen, und man kann bei keinem Eintrag einschaetzen,
# was er da tut. Deshalb wird auch danach sortiert: User zuerst, Group zuletzt.
#
# Absichtlich NICHT gefiltert: Group-Pakete verschwinden nicht aus der Liste,
# sie rutschen nur nach unten. Wegzulassen waere wieder ein Ausschluss, den
# nicht der Nutzer getroffen hat — und `kernel` steht zum Beispiel als User
# drin, waehrend `sudo` Group ist. Wer hier pauschal filtert, filtert falsch.
drift_annotated() {
    # Ein Strom, zwei Abschnitte, getrennt durch eine Marke — statt `join` ueber
    # zwei Prozesssubstitutionen. `join` verlangt, dass BEIDE Seiten nach dem
    # Schluessel in derselben Kollation sortiert sind; die Reason-Liste ist aber
    # nach "name<TAB>reason" sortiert und die Drift-Liste nach blossem Namen.
    # Das Ergebnis war stillschweigend LEER (erste Fassung dieser Funktion) —
    # join meldet so etwas nicht, es findet einfach nichts.
    # Trenner ist ein LEERZEICHEN, kein Tab: `dnf repoquery --qf` expandiert "\t"
    # nicht, es schreibt die zwei Zeichen literal in die Ausgabe (mit `cat -A`
    # nachgesehen: "bash\tGroup"). Ein awk -F'\t' saehe dann genau ein Feld und
    # faende nie einen Grund — die Spalte stand in einer frueheren Fassung
    # durchgehend auf "?". Deshalb hier Standard-Feldtrennung und der Grund als
    # "alles ab dem ersten Leerzeichen", denn "External User" enthaelt selbst eines.
    #
    # Drei Abschnitte in EINEM Strom, getrennt durch Marken, statt `join` ueber
    # Prozesssubstitutionen: `join` verlangt, dass beide Seiten nach dem
    # Schluessel in derselben Kollation sortiert sind. Waren sie nicht, und das
    # Ergebnis war stillschweigend LEER — join meldet so etwas nicht.
    #
    # awk laeuft mit -F'\t', damit die Herkunftstabelle sauber in vier Felder
    # faellt (die Beschreibung enthaelt Leerzeichen). Die anderen beiden
    # Abschnitte haben keine Tabs, dort ist $0 die ganze Zeile.
    {
        dnf repoquery --installed --qf '%{name} %{reason}\n' 2>/dev/null
        echo '%%MAP%%'
        origin_map
        echo '%%DRIFT%%'
        drift
    } | awk -F'\t' '
        $0 == "%%MAP%%"   { sect = 1; next }
        $0 == "%%DRIFT%%" { sect = 2; next }

        sect == 0 {
            n = substr($0, 1, index($0, " ") - 1)
            if (!(n in reason)) reason[n] = substr($0, index($0, " ") + 1)
            next
        }
        sect == 1 {
            if (!($1 in tx)) { tx[$1] = $2; when[$1] = $3; cmd[$1] = $4 }
            next
        }
        {
            r = ($1 in reason) ? reason[$1] : "?"
            selbst = (r == "User" || r == "External User")

            # Herkunft kurz halten: Transaktion 1 ist die Erstinstallation und
            # hat gar keine Kommandozeile; alles andere zeigt Datum + Befehl
            # ohne das immer gleiche "dnf install -y ".
            if (!($1 in tx))            { h = "ausserhalb von dnf" }
            else if (tx[$1] == 1)       { h = "Erstinstallation (Anaconda)" }
            else {
                c = cmd[$1]
                sub(/^(dnf|yum) install (-y )?(--refresh -y )?/, "", c)
                d = when[$1]; sub(/^[0-9]{4}-/, "", d); gsub(/-/, ".", d)
                h = d " " c
            }
            if (length(h) > 46) h = substr(h, 1, 45) "\342\200\246"

            # Rang: was WIRKLICH eine eigene Entscheidung war, zuerst.
            # "User" allein reicht dafuer nicht — Anaconda markiert in
            # Transaktion 1 selbst 13 Pakete als User (kernel, grub2-*, chrony,
            # authselect, nvme-cli, ...). Erst Reason PLUS Transaktion trennt:
            #   0  selbst installiert, nach der Erstinstallation   (~15)
            #   1  als User markiert, aber aus der Erstinstallation (13)
            #   2  Group — Sockel, nie einzeln ausgesucht           (38)
            rank = 2
            if (selbst) rank = (($1 in tx) && tx[$1] == 1) ? 1 : 0

            printf "%d\t%s\t%s\t%s\n", rank, $1, r, h
        }
    ' | sort -k1,1n -k2,2 | cut -f2- |
        awk -F'\t' '{ printf "%-30s %-14s %s\n", $1, $2, $3 }'
}

# Paketname -> Transaktion, in der es INSTALLIERT wurde (nicht aktualisiert),
# plus Datum und Kommandozeile. Eine Zeile pro Paket, tabgetrennt.
#
# Das ist die Antwort auf "wo kommt das eigentlich her?", und ohne sie ist die
# Drift-Liste nicht zu beurteilen: `btop` steht dann als "yum install btop,
# 15.08." da und `kernel` als "Erstinstallation" — beide sind Reason User,
# aber nur eines davon war je eine Entscheidung.
#
# NEVRA -> Name: alles ab "-<epoch>:" abschneiden. Die Epoche steht in dieser
# Ausgabe immer da ("btop-0:1.4.7-1.fc44.x86_64", "grub2-efi-x64-1:2.12-..."),
# und ein ":" kann in einem Paketnamen nicht vorkommen — der Schnitt ist damit
# eindeutig, anders als ein Schnitt am letzten "-".
#
# Nur "Install": ein spaeteres "Upgrade" desselben Pakets wuerde sonst die
# urspruengliche Herkunft ueberschreiben. Deshalb auch das seen[]-Gatter,
# denn die Transaktionen kommen aufsteigend.
#
# Kostet rund 1,3 s bei 35 Transaktionen und 2070 Paketen. Das laeuft einmal,
# bevor fzf aufgeht — vertretbar fuer die Spalte, die die Liste erst brauchbar
# macht. Pro Paket einzeln zu fragen (`dnf history list --contains-pkgs`) waere
# bei 67 Eintraegen langsamer und in der Vorschau ohnehin schon drin.
origin_map() {
    local id
    for id in $(dnf history list 2>/dev/null | awk '$1 ~ /^[0-9]+$/ {print $1}'); do
        dnf history info "$id" 2>/dev/null
    done | awk '
        /^Transaction ID/ { id = $4 }
        /^Begin time/     { date = $4 }
        /^Description/    { sub(/^Description *: */, ""); desc = $0 }
        /^  Install / {
            pkg = $2; sub(/-[0-9]+:.*$/, "", pkg)
            if (!(pkg in seen)) {
                seen[pkg] = 1
                printf "%s\t%s\t%s\t%s\n", pkg, id, date, desc
            }
        }
    '
}

# Haengt die markierten Pakete unter einer datierten Ueberschrift an eine der
# beiden Listen. Der Grund wird EINMAL fuer den ganzen Schwung abgefragt, nicht
# pro Paket: wer sieben hypr*-Pakete auf einmal abhakt, hat fuer alle sieben
# denselben Grund, und sieben identische Zeilen zu tippen fuehrt nur dazu, dass
# man beim naechsten Mal gar keinen Grund mehr angibt.
#
# Angehaengt wird ans Dateiende, nicht in die passende thematische Sektion:
# automatisch einsortieren hiesse raten, in welchen Block ein Paket gehoert, und
# ein falsch einsortiertes Paket mit richtigem Kommentar ist schlimmer als ein
# angehaengtes. Die Ueberschrift sagt deshalb ausdruecklich, dass das noch von
# Hand passieren muss.
append_to() {
    local file="$1" grund; shift
    echo
    read -r -p "Grund (eine Zeile, landet als Kommentar in $file): " grund
    [ -n "$grund" ] || { echo "Ohne Grund kein Eintrag — abgebrochen."; return 1; }

    {
        echo
        echo "# --- Nachtrag $(date +%d.%m.%Y) (drift-check pick) — noch einsortieren ---"
        echo "# $grund"
        printf '%s\n' "$@"
    } >> "$file"

    echo
    echo "$# Paket(e) an $file angehaengt:"
    printf '  %s\n' "$@"
    echo
    echo "Bitte einsortieren und committen — angehaengt ist nicht gepflegt."
}

usage() {
    cat <<EOF
Aufruf:
  ${0##*/}            Drift auflisten (eine Zeile pro Paket)
  ${0##*/} pick       Drift interaktiv aufloesen (fzf)

pick-Tasten: TAB markieren, dann
  CTRL-R  entfernen (dnf remove)
  CTRL-P  nach packages.txt uebernehmen
  CTRL-E  in $EXPECTED als erwartet ablegen
EOF
}

case "${1:-list}" in
list)
    drift
    ;;

pick)
    command -v fzf >/dev/null || {
        echo "fzf fehlt (steht in packages.txt): sudo dnf install fzf" >&2
        exit 1
    }

    mapfile -t items < <(drift_annotated)
    [ "${#items[@]}" -gt 0 ] || { echo "Kein Drift. Nichts zu tun."; exit 0; }

    # {1} statt {}: die Liste hat seit der Reason-Spalte zwei Felder, und {}
    # wuerde die GANZE Zeile einsetzen ("btop  User") — rpm bekaeme dann zwei
    # Argumente und antwortete fuer das falsche Paket.
    #
    # Vorschau ueber rpm, NICHT ueber `dnf info`: rpm liest die lokale Datenbank
    # und antwortet sofort, dnf geht an den Metadaten-Cache und braucht bei jedem
    # Cursorschritt eine knappe Sekunde — bei 60 Eintraegen ist das der
    # Unterschied zwischen Durchscrollen und Warten.
    #
    # Die Ausnahme ist `dnf history list --contains-pkgs`, das trotzdem drin ist:
    # es beantwortet die Frage, die man beim Draufschauen wirklich hat — WANN
    # und durch WELCHEN BEFEHL kam das Paket her. Bei btop steht da
    # "yum install btop, 15.08.2026", bei bash die Erstinstallation. Gemessen
    # 0,026 s, es kostet also nichts.
    #
    # Der letzte Block ist der wichtigste: was von dem Paket abhaengt. Genau das
    # entscheidet, ob "entfernen" eine Zeile oder eine Lawine ist.
    preview_cmd='
        rpm -qi {1} 2>/dev/null | sed -n "/^Name/p;/^Version/p;/^Install Date/p;/^Size/p;/^Summary/p;/^From repo/p"
        echo
        echo "Woher:"
        dnf history list --contains-pkgs={1} 2>/dev/null | sed "s/^/  /"
        echo
        echo "Wird gebraucht von:"
        rpm -q --whatrequires {1} 2>/dev/null | sed "s/^/  /" | head -15
    '

    # --marker und --pointer duerfen hoechstens ZWEI Spalten breit sein, sonst
    # bricht fzf mit "marker display width should be up to 2" ab — und zwar erst
    # beim Start, nicht beim Parsen der Optionen. Ein huebscheres "[x] " als
    # Markierung ist damit raus.
    out=$(printf '%s\n' "${items[@]}" | fzf \
        --multi \
        --prompt 'Drift: ' \
        --marker '*' \
        --pointer '>' \
        --header 'Spalte 2 = Installationsgrund (User = selbst installiert, Group = Sockel der Erstinstallation)
TAB markieren | CTRL-R entfernen | CTRL-P packages.txt | CTRL-E erwartet | ESC Abbruch' \
        --preview "$preview_cmd" \
        --preview-window 'right,55%,wrap' \
        --expect=ctrl-r,ctrl-p,ctrl-e) || { echo "Abgebrochen."; exit 0; }

    # fzf schreibt mit --expect die gedrueckte Taste in die ERSTE Zeile (leer bei
    # ENTER), danach die Auswahl. Deshalb head/tail statt einfach mapfile.
    key=$(head -1 <<<"$out")
    # Nur das erste Feld: fzf gibt die ganze angezeigte Zeile samt Reason-Spalte
    # zurueck, dnf will aber den blanken Paketnamen.
    mapfile -t sel < <(tail -n +2 <<<"$out" | awk 'NF{print $1}')
    [ "${#sel[@]}" -gt 0 ] || { echo "Nichts markiert."; exit 0; }

    case "$key" in
    ctrl-r)
        # KEIN -y, und das ist die eigentliche Sicherung des ganzen Tools:
        # `dnf remove` zeigt von sich aus die vollstaendige Transaktion — auch
        # die Pakete, die als Abhaengigkeit mitgehen — und fragt dann nach.
        # Eine eigene Nachbau-Rueckfrage waere eine zweite, schlechtere Wahrheit.
        # Wer hier bash markiert, sieht genau das in der Vorschau von dnf und
        # kann immer noch mit n abbrechen.
        echo
        echo "Entfernen (dnf zeigt gleich die vollstaendige Transaktion):"
        printf '  %s\n' "${sel[@]}"
        echo
        sudo dnf remove "${sel[@]}"
        ;;
    ctrl-p)
        append_to packages.txt "${sel[@]}"
        ;;
    ctrl-e)
        append_to "$EXPECTED" "${sel[@]}"
        ;;
    *)
        echo "Keine Aktion gewaehlt (ENTER macht nichts — nimm CTRL-R/P/E)."
        ;;
    esac
    ;;

-h | --help | help)
    usage
    ;;
*)
    echo "Unbekannt: $1" >&2
    usage >&2
    exit 1
    ;;
esac
