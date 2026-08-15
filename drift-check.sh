#!/usr/bin/env bash
# Zeigt Pakete, die von Hand installiert wurden, aber nicht in packages.txt stehen.
# Ad-hoc-Installieren ist erlaubt — verstecken gilt nicht.
set -euo pipefail
cd "$(dirname "$0")"

comm -23 \
  <(dnf repoquery --userinstalled --qf '%{name}\n' 2>/dev/null | sort -u) \
  <(sed 's/#.*//' packages.txt | awk 'NF{print $1}' | sort -u)
