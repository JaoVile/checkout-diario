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

# 1) varredura rápida (sem IA)
bash "${BIN}/collect-activity.sh" "${DATE}" >/dev/null 2>&1
DIGEST="${BASE}/.cache/digest-${DATE}.txt"
[ -s "${DIGEST}" ] || { echo "$(date '+%H:%M')  •  digest vazio, abortando"; exit 0; }

# resumo do que está captado agora (p/ a aba de Logs mostrar a evolução)
# assinatura estável do navegador: só o CONJUNTO de domínios do dia
# (ignora contagem/hora/título) — muda quando surge site novo, não a cada visita.
browser_domains() {
  awk '/========== \[6\]/{f=1} /========== \[7\]/{f=0} f' "$DIGEST" 2>/dev/null \
    | grep -oE '\([0-9]+x\) [^ ]+' | awk '{print $2}' | sort -u
}
digest_summary() {
  local c w cl n b
  c=$(grep -cE '^  • [0-9]{2}:[0-9]{2} ' "$DIGEST" 2>/dev/null); c=${c:-0}
  w=$(grep -c 'arquivos sem commit)' "$DIGEST" 2>/dev/null); w=${w:-0}
  cl=$(grep -c '^### CLAUDE:' "$DIGEST" 2>/dev/null); cl=${cl:-0}
  n=$(grep -cE '^- \[' "${BASE}/.cache/notas-${DATE}.txt" 2>/dev/null); n=${n:-0}
  b=$(browser_domains | grep -c .); b=${b:-0}
  echo "${c} commits · ${w} repos WIP · ${cl} Claude · ${b} sites · ${n} notas"
}
SUMMARY="$(digest_summary)"
HM="$(date '+%H:%M')"

# 2) hash do conteúdo que VIRA trabalho: [0] notas, [1]/[1b] git, [5] Claude
#    + a assinatura estável de domínios do navegador (dia inteiro navegando também
#    dispara regeneração quando aparece site novo). Ignora [2] terminal, [3] sistema,
#    [4] pm2, contagens/horas voláteis e a [7] jornada (só horário, ruído).
NEWHASH="$( { awk '
    /========== \[0\]/{a=1} /========== \[2\]/{a=0}
    /========== \[5\]/{b=1} /========== \[6\]/{b=0}
    (a||b)' "${DIGEST}"
  browser_domains
  } | md5sum | cut -d' ' -f1)"
HASHFILE="${BASE}/.cache/lasthash-${DATE}.txt"
OLD="$(cat "${HASHFILE}" 2>/dev/null || true)"

if [ "${NEWHASH}" = "${OLD}" ]; then
  echo "${HM}  •  sem mudança — preview já atualizado  ·  ${SUMMARY}"
  exit 0
fi

# 3) algo mudou → regera o preview (reusa a varredura, SEM pop-up)
echo "${HM}  •  MUDANÇA detectada → regerando preview  ·  ${SUMMARY}"
CHECKOUT_SKIP_COLLECT=1 bash "${BIN}/generate-checkout.sh" "${DATE}" >/dev/null 2>&1 \
  && { echo "${NEWHASH}" > "${HASHFILE}"; echo "$(date '+%H:%M')  •  preview atualizado ✔  ·  ${SUMMARY}"; } \
  || echo "$(date '+%H:%M')  •  falha ao regerar (preview anterior mantido)"
