#!/usr/bin/env bash
# checkout-diga.sh — modo ditado: você diz o que fez e gera o check-out na hora
# (combina com a varredura do PC = modo híbrido). Mostra o pop-up no fim.
# Uso: checkout-diga.sh "fiz X e Y, reunião 1h de tarde, turno da tarde"
set -uo pipefail
BIN="${HOME}/Checkouts/bin"
TXT="$*"
[ -z "$TXT" ] && { echo "uso: checkout-diga.sh \"o que você fez hoje (tempo/turno opcionais)\""; exit 1; }
bash "${BIN}/nota.sh" "$TXT"
echo "🧠 Gerando check-out (suas notas + varredura do PC)..."
CHECKOUT_NOTIFY=1 bash "${BIN}/generate-checkout.sh"
source "${BIN}/_paths.sh"
echo "✅ $(checkout_file_for "$(date +%F)")"
