#!/usr/bin/env bash
# review-checkout.sh — revisão interativa: escolha por dia o que entra no check-out.
# Uso: review-checkout.sh [YYYY-MM-DD]   (padrão: hoje)
set -uo pipefail
DATE="${1:-$(date +%F)}"
BASE="${HOME}/Checkouts"
BIN="${BASE}/bin"
DIGEST="${BASE}/.cache/digest-${DATE}.txt"
EXTRA="${BASE}/.cache/exclude-${DATE}.txt"

echo "🔎 Coletando atividade de ${DATE}..."
bash "${BIN}/collect-activity.sh" "${DATE}" >/dev/null

# Detecta itens: repositórios git e apps pm2 presentes no digest
mapfile -t REPOS < <(grep -oP '^### REPO: \K[^ ]+' "$DIGEST" 2>/dev/null)
mapfile -t APPS  < <(awk '/\[4\] PM2/{f=1} f && /^  • /{print $2}' "$DIGEST" 2>/dev/null)

echo
echo "════════════ ITENS DETECTADOS EM ${DATE} ════════════"
declare -A KIND NAME
i=0
for r in "${REPOS[@]}"; do i=$((i+1)); KIND[$i]=repo; NAME[$i]="$r"; printf "  [%2d] 📦 repo: %s\n" "$i" "$r"; done
for a in "${APPS[@]}";  do i=$((i+1)); KIND[$i]=pm2;  NAME[$i]="$a"; printf "  [%2d] ⚙️  app : %s\n" "$i" "$a"; done
TOTAL=$i
[ "$TOTAL" -eq 0 ] && { echo "  (nada detectado hoje)"; }
echo "═══════════════════════════════════════════════════════"
echo
echo "Digite os NÚMEROS que NÃO quer no check-out de hoje (separados por espaço)."
echo "  • Enter vazio = inclui tudo"
echo "  • Adicione 'fix' a um número p/ bloquear PARA SEMPRE  (ex: 2fix)"
echo -n "> "
read -r ANSWER < /dev/tty

: > "$EXTRA"
for token in $ANSWER; do
  perma=0; num="$token"
  [[ "$token" == *fix ]] && { perma=1; num="${token%fix}"; }
  [[ "$num" =~ ^[0-9]+$ ]] || continue
  [ "$num" -ge 1 ] && [ "$num" -le "$TOTAL" ] || continue
  k="${KIND[$num]}"; n="${NAME[$num]}"
  echo "${k}:${n}" >> "$EXTRA"           # exclusão deste dia
  if [ "$perma" -eq 1 ]; then
    bash "${BIN}/block.sh" "$k" "$n" >/dev/null
    echo "  🔒 $n bloqueado para sempre"
  else
    echo "  ⛔ $n fora só de hoje"
  fi
done

echo
echo "🧠 Gerando check-out com suas escolhas..."
CHECKOUT_EXTRA_BLOCK="$EXTRA" bash "${BIN}/generate-checkout.sh" "${DATE}"
source "${BIN}/_paths.sh"
echo
echo "✅ Pronto: $(checkout_file_for "${DATE}")"
