#!/usr/bin/env bash
# nota.sh — registra uma nota manual para o check-out do dia (reunião, presencial,
# BIOS, call, ou qualquer coisa que os logs não capturam).
# Uso:
#   nota.sh "reunião com a Multi às 14h, 1h, alinhamento do fluxo"
#   nota.sh -d 2026-07-02 "texto para outro dia"
set -uo pipefail
DATE="$(date +%F)"
if [ "${1:-}" = "-d" ]; then DATE="$2"; shift 2; fi
TXT="$*"
[ -z "$TXT" ] && { echo "uso: nota.sh \"o que você fez (e tempo/turno se quiser)\""; exit 1; }
F="${HOME}/Checkouts/.cache/notas-${DATE}.txt"
mkdir -p "$(dirname "$F")"
printf -- '- [%s] %s\n' "$(date +%H:%M)" "$TXT" >> "$F"
echo "📝 nota registrada p/ ${DATE}: ${TXT}"
echo "   (entra no próximo check-out automaticamente)"
