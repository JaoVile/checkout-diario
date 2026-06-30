#!/usr/bin/env bash
# generate-checkout.sh — gera o CHECK-OUT DO DIA: coleta logs -> IA escreve -> salva arquivo.
# Uso: generate-checkout.sh [YYYY-MM-DD]   (padrão: hoje)

set -uo pipefail

DATE="${1:-$(date +%F)}"
BASE="${HOME}/Checkouts"
BIN="${BASE}/bin"
RUNLOG="${BASE}/logs/run-${DATE}.log"
source "${BIN}/_paths.sh"
OUT="$(checkout_file_for "${DATE}")"
# saída alternativa (preview/teste) sem mexer no checkout canônico nem no Obsidian
[ -n "${CHECKOUT_OUT_OVERRIDE:-}" ] && OUT="${CHECKOUT_OUT_OVERRIDE}"
mkdir -p "$(dirname "${OUT}")"
DIGEST="${BASE}/.cache/digest-${DATE}.txt"
PROMPT="${BIN}/prompt-checkout.md"

# garante o PATH do claude/node em ambiente de cron (não-interativo)
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

exec >>"${RUNLOG}" 2>&1
echo "==== RUN $(date '+%F %T') para o dia ${DATE} ===="

# 1) Coleta o digest (pode reaproveitar um digest recém-coletado pelo tick)
if [ "${CHECKOUT_SKIP_COLLECT:-0}" = "1" ] && [ -s "${DIGEST}" ]; then
  echo "[1/3] Reusando varredura recente..."
else
  echo "[1/3] Coletando atividade..."
  bash "${BIN}/collect-activity.sh" "${DATE}" >/dev/null
fi
if [ ! -s "${DIGEST}" ]; then
  echo "ERRO: digest vazio em ${DIGEST}"; exit 1
fi

# 2) IA escreve o check-out (claude headless)
echo "[2/3] Gerando texto com o Claude..."

# monta o prompt: identidade (config) + template editável (learn-from-example)
NOME="${CHECKOUT_NOME:-Dev}"; CARGO="${CHECKOUT_CARGO:-}"
if [ -n "${CHECKOUT_TURNO:-}" ]; then
  TURNO_INSTR="O turno de trabalho é '${CHECKOUT_TURNO}'. Inclua se o template tiver lugar para isso."
else
  TURNO_INSTR="Se os horários indicarem claramente o turno (manhã/tarde/noite), pode mencionar; senão, omita."
fi
# modo do check-out: englobado (padrão) ou reduzido. Env CHECKOUT_EXPAND ainda funciona p/ override.
MODE="${CHECKOUT_MODE:-englobado}"
[ "${CHECKOUT_EXPAND:-}" = "1" ] && MODE="englobado"
[ "${CHECKOUT_EXPAND:-}" = "0" ] && MODE="reduzido"
if [ "$MODE" = "reduzido" ]; then
  EXPAND_INSTR="MODO REDUZIDO (sutil): seja conciso e discreto — no máximo 1 a 2 bullets por projeto, frases curtas, sem minúcias. Um resumo enxuto e modesto do dia. Continua PROIBIDO inventar."
else
  EXPAND_INSTR="MODO ENGLOBADO/MAXIMIZAR (padrão): seja EXAUSTIVO — capture TODO trabalho real das fontes (cada commit, cada arquivo alterado, cada tarefa do Claude, cada nota), com bullets detalhados e horas concretas, valorizando ao máximo o que foi feito. Mas continua PROIBIDO inventar: só o que está nas fontes."
fi
TEMPLATE_CONTENT="$(cat "${BASE}/template.md" 2>/dev/null)"
TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{NOME\}/$NOME}"
TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{CARGO\}/$CARGO}"
TEMPLATE_CONTENT="${TEMPLATE_CONTENT//\{DATA\}/$DATE}"

INSTRUC="$(cat "${PROMPT}")"
INSTRUC="${INSTRUC//\{NOME\}/$NOME}"
INSTRUC="${INSTRUC//\{CARGO\}/$CARGO}"
INSTRUC="${INSTRUC//\{TURNO_INSTR\}/$TURNO_INSTR}"
INSTRUC="${INSTRUC//\{EXPAND_INSTR\}/$EXPAND_INSTR}"
INSTRUC="${INSTRUC//\{TEMPLATE\}/$TEMPLATE_CONTENT}"

INPUT="${INSTRUC}

A DATA de hoje é ${DATE}.

================= DIGEST CRU (use isto) =================
$(cat "${DIGEST}")
========================================================"

if ! printf '%s' "${INPUT}" | claude -p --model claude-sonnet-4-6 > "${OUT}.tmp" 2>"${BASE}/logs/claude-err-${DATE}.log"; then
  echo "ERRO: claude falhou. Veja logs/claude-err-${DATE}.log"
  rm -f "${OUT}.tmp"
  exit 1
fi

# limpa eventuais cercas ``` que o modelo possa ter colocado
sed -i 's/^```.*$//' "${OUT}.tmp"
mv "${OUT}.tmp" "${OUT}"

# 3) Pronto
echo "[3/3] Check-out salvo em: ${OUT}"

# 3b) Copia pro Obsidian, se configurado (pulado em modo preview/override)
OBS=""; [ -z "${CHECKOUT_OUT_OVERRIDE:-}" ] && OBS="$(obsidian_file_for "${DATE}")"
if [ -n "${OBS}" ]; then
  mkdir -p "$(dirname "${OBS}")" && cp "${OUT}" "${OBS}" \
    && echo "[3b] Copiado pro Obsidian: ${OBS}" \
    || echo "(aviso: não consegui copiar pro Obsidian)"
fi

# 4) Notifica na tela (pop-up + clipboard + abre), se solicitado
if [ "${CHECKOUT_NOTIFY:-0}" = "1" ]; then
  echo "[4] Notificando na tela..."
  bash "${BIN}/notify-checkout.sh" "${DATE}" || echo "(aviso: notificação falhou, arquivo OK)"
fi

echo "==== FIM $(date '+%F %T') ===="
echo "OK -> ${OUT}"
