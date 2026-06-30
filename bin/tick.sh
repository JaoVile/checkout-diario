#!/usr/bin/env bash
# tick.sh — roda a cada ~20 min durante o expediente. Faz uma varredura rápida
# e SÓ regera o check-out (com IA) se algo mudou desde a última vez.
# Assim o preview do dia fica sempre pronto, sem chamar a IA à toa.
set -uo pipefail
DATE="$(date +%F)"
BASE="${HOME}/Checkouts"; BIN="${BASE}/bin"
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"
RUNLOG="${BASE}/logs/tick-${DATE}.log"
exec >>"${RUNLOG}" 2>&1
echo "---- tick $(date '+%T') ----"

# 1) varredura rápida (sem IA)
bash "${BIN}/collect-activity.sh" "${DATE}" >/dev/null 2>&1
DIGEST="${BASE}/.cache/digest-${DATE}.txt"
[ -s "${DIGEST}" ] || { echo "digest vazio, abortando"; exit 0; }

# 2) hash só do conteúdo que VIRA trabalho no check-out: [0] notas, [1]/[1b] git, [5] Claude.
#    Ignora [2] terminal, [3] sistema e [4] pm2 (cpu/mem/uptime mudam toda hora = ruído).
NEWHASH="$(awk '
  /========== \[0\]/{a=1} /========== \[2\]/{a=0}
  /========== \[5\]/{b=1} /# FIM DO DIGEST/{b=0}
  (a||b)' "${DIGEST}" | md5sum | cut -d' ' -f1)"
HASHFILE="${BASE}/.cache/lasthash-${DATE}.txt"
OLD="$(cat "${HASHFILE}" 2>/dev/null || true)"

if [ "${NEWHASH}" = "${OLD}" ]; then
  echo "sem mudança desde o último tick — preview já está atualizado, pula a IA"
  exit 0
fi

# 3) algo mudou → regera o preview (reusa a varredura, SEM pop-up)
echo "mudança detectada → regerando preview..."
CHECKOUT_SKIP_COLLECT=1 bash "${BIN}/generate-checkout.sh" "${DATE}" >/dev/null 2>&1 \
  && { echo "${NEWHASH}" > "${HASHFILE}"; echo "preview pronto ✔"; } \
  || echo "falha ao regerar (preview anterior mantido)"
