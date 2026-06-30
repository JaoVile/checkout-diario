#!/usr/bin/env bash
# collect-activity.sh — coleta toda a atividade do PC de um dia e gera um "digest" cru.
# Uso: collect-activity.sh [YYYY-MM-DD]   (padrão: hoje)
# Respeita bloqueios de:
#   - ~/Checkouts/blocklist.txt           (permanentes)
#   - $CHECKOUT_EXTRA_BLOCK (arquivo)     (exclusões só deste dia, opcional)
# Saída: imprime o digest no stdout (e salva em ~/Checkouts/.cache/digest-DATA.txt)

set -uo pipefail

DATE="${1:-$(date +%F)}"
HOME_DIR="${HOME}"
BASE="${HOME_DIR}/Checkouts"
OUT_CACHE="${BASE}/.cache/digest-${DATE}.txt"
BLOCKFILE="${BASE}/blocklist.txt"

# carrega config (toggles de fontes); default = tudo ligado
[ -f "${BASE}/config.sh" ] && source "${BASE}/config.sh"
on() { [ "${1:-1}" = "1" ]; }

# pastas onde procurar repositórios. Configurável em config.sh via
# CHECKOUT_PROJECT_DIRS="~/github ~/code ..." (lista separada por espaço).
if [ -n "${CHECKOUT_PROJECT_DIRS:-}" ]; then
  # expande ~ e variáveis de cada item
  read -r -a _pd <<< "${CHECKOUT_PROJECT_DIRS}"
  SEARCH_DIRS=()
  for d in "${_pd[@]}"; do SEARCH_DIRS+=("${d/#\~/$HOME_DIR}"); done
  SEARCH_DIRS+=("${HOME_DIR}/Checkouts")
else
  SEARCH_DIRS=("${HOME_DIR}/github" "${HOME_DIR}/Projetos" "${HOME_DIR}/Checkouts")
fi
GIT_EMAIL="$(git config --global user.email 2>/dev/null)"
GIT_NAME="$(git config --global user.name 2>/dev/null)"
SINCE="${DATE} 00:00:00"
UNTIL="${DATE} 23:59:59"

# ── carrega bloqueios (permanentes + do dia) em arrays por categoria ──
declare -a BLK_REPO BLK_PM2 BLK_PATH BLK_USER
load_blocks() {
  local f="$1"; [ -f "$f" ] || return 0
  local line key val
  while IFS= read -r line; do
    line="${line#"${line%%[![:space:]]*}"}"   # ltrim
    line="${line%"${line##*[![:space:]]}"}"    # rtrim
    [ -z "$line" ] && continue
    case "$line" in \#*) continue;; esac
    key="${line%%:*}"; val="${line#*:}"
    val="${val#"${val%%[![:space:]]*}"}"
    [ -z "$val" ] && continue
    case "$key" in
      repo) BLK_REPO+=("$val");;
      pm2)  BLK_PM2+=("$val");;
      path) BLK_PATH+=("$val");;
      user) BLK_USER+=("$val");;
    esac
  done < "$f"
}
load_blocks "$BLOCKFILE"
[ -n "${CHECKOUT_EXTRA_BLOCK:-}" ] && load_blocks "$CHECKOUT_EXTRA_BLOCK"

# blocked CATEGORY VALUE -> 0 se bloqueado
blocked() {
  local cat="$1" val="$2" p; local -n arr="BLK_${cat}"
  for p in "${arr[@]:-}"; do
    [ -z "$p" ] && continue
    [[ "$val" == *"$p"* ]] && return 0
  done
  return 1
}

exec > >(tee "${OUT_CACHE}") 2>/dev/null

echo "###############################################"
echo "# DIGEST DE ATIVIDADE — ${DATE}"
echo "# Usuário git: ${GIT_NAME} <${GIT_EMAIL}>"
echo "# Gerado em: $(date '+%F %T')"
[ ${#BLK_REPO[@]}${#BLK_PM2[@]}${#BLK_PATH[@]}${#BLK_USER[@]} != 0000 ] && \
  echo "# Bloqueios ativos: repo[${BLK_REPO[*]:-}] pm2[${BLK_PM2[*]:-}] path[${BLK_PATH[*]:-}] user[${BLK_USER[*]:-}]"
echo "###############################################"

# ─────────────────────────────────────────────────────────
echo
echo "========== [0] NOTAS MANUAIS (ditadas por você) =========="
NOTAS="${BASE}/.cache/notas-${DATE}.txt"
if [ -s "$NOTAS" ]; then cat "$NOTAS"; else echo "(sem notas manuais hoje)"; fi

# ─────────────────────────────────────────────────────────
echo
echo "========== [1] GIT — COMMITS DO DIA =========="
if ! on "${CHECKOUT_SRC_GIT:-1}"; then echo "(fonte git desligada)"; else
found_any=0
for base in "${SEARCH_DIRS[@]}"; do
  [ -d "$base" ] || continue
  while IFS= read -r gitdir; do
    repo="$(dirname "$gitdir")"
    name="$(basename "$repo")"
    blocked REPO "$name" && continue
    blocked PATH "$repo" && continue
    log="$(git -C "$repo" log --all --author="${GIT_EMAIL}" \
            --since="$SINCE" --until="$UNTIL" \
            --pretty=format:'%H%x09%ad%x09%s' --date=format:'%H:%M' 2>/dev/null)"
    if [ -z "$log" ] && [ -n "$GIT_NAME" ]; then
      log="$(git -C "$repo" log --all --author="${GIT_NAME}" \
              --since="$SINCE" --until="$UNTIL" \
              --pretty=format:'%H%x09%ad%x09%s' --date=format:'%H:%M' 2>/dev/null)"
    fi
    [ -z "$log" ] && continue
    found_any=1
    echo
    echo "### REPO: ${name}  (${repo})"
    branch="$(git -C "$repo" rev-parse --abbrev-ref HEAD 2>/dev/null)"
    echo "    branch atual: ${branch}"
    while IFS=$'\t' read -r hash hora msg; do
      [ -z "$hash" ] && continue
      stat="$(git -C "$repo" show --stat --oneline "$hash" 2>/dev/null \
              | tail -n +2 | grep -E 'file[s]? changed' | sed 's/^ *//')"
      files="$(git -C "$repo" show --name-only --pretty=format: "$hash" 2>/dev/null \
              | grep -v '^$' | head -8 | sed 's/^/        - /')"
      echo "  • ${hora}  ${msg}"
      [ -n "$stat" ] && echo "        (${stat})"
      [ -n "$files" ] && echo "$files"
    done <<< "$log"
  done < <(find "$base" -maxdepth 4 -name .git -type d 2>/dev/null)
done
[ "$found_any" -eq 0 ] && echo "(nenhum commit seu encontrado neste dia)"

# ─────────────────────────────────────────────────────────
echo
echo "========== [1b] GIT — TRABALHO EM ANDAMENTO (não commitado) =========="
echo "(arquivos alterados/criados mas ainda sem commit — só faz sentido p/ o dia de hoje)"
wip_any=0
for base in "${SEARCH_DIRS[@]}"; do
  [ -d "$base" ] || continue
  while IFS= read -r gitdir; do
    repo="$(dirname "$gitdir")"; name="$(basename "$repo")"
    blocked REPO "$name" && continue
    blocked PATH "$repo" && continue
    porc="$(git -C "$repo" status --porcelain 2>/dev/null)"
    [ -z "$porc" ] && continue
    wip_any=1
    n="$(printf '%s\n' "$porc" | grep -c .)"
    stat="$(git -C "$repo" diff --shortstat 2>/dev/null | sed 's/^ *//')"
    echo
    echo "### REPO: ${name}  (${n} arquivos sem commit) ${stat:+— $stat}"
    printf '%s\n' "$porc" | head -12 | sed 's/^/        /'
  done < <(find "$base" -maxdepth 4 -name .git -type d 2>/dev/null)
done
[ "$wip_any" -eq 0 ] && echo "(nada em andamento sem commit)"
fi

# ─────────────────────────────────────────────────────────
echo
echo "========== [2] TERMINAL — COMANDOS =========="
HIST="${HOME_DIR}/.bash_history"
if ! on "${CHECKOUT_SRC_TERMINAL:-1}"; then echo "(fonte terminal desligada)"; else
filter_path() {  # remove linhas que casem com BLK_PATH
  if [ ${#BLK_PATH[@]} -eq 0 ]; then cat; return; fi
  local pat; pat="$(printf '%s\n' "${BLK_PATH[@]}" | paste -sd'|')"
  grep -ivE "$pat"
}
if [ -f "$HIST" ]; then
  if grep -q '^#[0-9]\{9,\}' "$HIST" 2>/dev/null; then
    day_start=$(date -d "${DATE} 00:00:00" +%s 2>/dev/null)
    day_end=$(date -d "${DATE} 23:59:59" +%s 2>/dev/null)
    awk -v s="$day_start" -v e="$day_end" '
      /^#[0-9]+$/ { ts=substr($0,2)+0; next }
      { if (ts>=s && ts<=e && length($0)>0) {
          cmd=$0
          if (cmd !~ /^(ls|cd|clear|pwd|c|h|cn|xh|x|x c|x h)$/) print cmd
      } }' "$HIST" | filter_path | sort | uniq -c | sort -rn | head -60 | sed 's/^ *//;s/^[0-9]* /  $ /'
  else
    echo "(.bash_history ainda sem timestamps — timestamps passam a valer nas próximas sessões)"
    echo "Últimos comandos relevantes (sem data confiável):"
    grep -vE '^(ls|cd|clear|pwd|c|h|cn|xh|x|x c|x h)$' "$HIST" 2>/dev/null \
      | filter_path | tail -40 | sort | uniq -c | sort -rn | head -30 | sed 's/^ *//;s/^/  $ /'
  fi
else
  echo "(sem ~/.bash_history)"
fi
fi

# ─────────────────────────────────────────────────────────
echo
echo "========== [3] SISTEMA — SESSÕES & EVENTOS (journalctl) =========="
filter_user() {  # remove linhas que casem com BLK_USER
  if [ ${#BLK_USER[@]} -eq 0 ]; then cat; return; fi
  local pat; pat="$(printf '%s\n' "${BLK_USER[@]}" | paste -sd'|')"
  grep -ivE "$pat"
}
if ! on "${CHECKOUT_SRC_SISTEMA:-1}"; then echo "(fonte sistema desligada)"; else
echo "--- Sessões de login/logout no dia ---"
{ last -s "${DATE} 00:00:00" -t "${DATE} 23:59:59" 2>/dev/null | grep -vE '^$|^wtmp' | head -15 \
  || echo "(last indisponível)"; } | filter_user

echo
echo "--- Comandos sudo no dia ---"
{ journalctl --since "$SINCE" --until "$UNTIL" _COMM=sudo -o cat 2>/dev/null \
  | grep -oE 'COMMAND=.*' | sort | uniq -c | sort -rn | head -20 | sed 's/^ *//' \
  || echo "(sem registros sudo)"; } | filter_user

echo
echo "--- Resumo de erros/avisos do sistema (amostra das unidades) ---"
# só o campo da unidade + limite de entradas: evita despejar centenas de milhares de linhas
journalctl --since "$SINCE" --until "$UNTIL" -p warning..err -o json --output-fields=_SYSTEMD_UNIT -n 4000 2>/dev/null \
  | sed -n 's/.*"_SYSTEMD_UNIT":"\([^"]*\)".*/\1/p' | sort | uniq -c | sort -rn | head -15 | sed 's/^ *//' \
  | filter_user || echo "(sem erros/avisos relevantes)"
fi

# ─────────────────────────────────────────────────────────
echo
echo "========== [4] PM2 — APLICAÇÕES =========="
if ! on "${CHECKOUT_SRC_PM2:-1}"; then echo "(fonte pm2 desligada)"; elif command -v pm2 >/dev/null 2>&1; then
  BLK_PM2_JOINED="$(printf '%s|' "${BLK_PM2[@]:-}")"
  pm2 jlist 2>/dev/null | BLK="$BLK_PM2_JOINED" node -e '
    let raw=""; process.stdin.on("data",d=>raw+=d); process.stdin.on("end",()=>{
      try{
        const apps=JSON.parse(raw||"[]");
        const blk=(process.env.BLK||"").split("|").filter(Boolean);
        const vis=apps.filter(a=>!blk.some(b=>String(a.name).includes(b)));
        if(!vis.length){console.log("(nenhum app no pm2 — ou todos bloqueados)");return;}
        for(const a of vis){
          const e=a.pm2_env||{};
          const up = e.pm_uptime ? new Date(e.pm_uptime).toISOString().replace("T"," ").slice(0,16) : "?";
          console.log(`  • ${a.name}  [${e.status}]  restarts=${e.restart_time||0}  cpu=${(a.monit||{}).cpu||0}%  mem=${Math.round(((a.monit||{}).memory||0)/1048576)}MB  desde=${up}`);
        }
      }catch(err){console.log("(erro ao ler pm2 jlist)");}
    });' 2>/dev/null || echo "(erro pm2)"
else
  echo "(pm2 não instalado)"
fi

# ─────────────────────────────────────────────────────────
echo
echo "========== [5] CLAUDE CODE — TRABALHO ASSISTIDO POR IA =========="
echo "(sessões do Claude Code no dia — captura trabalho mesmo SEM commit no git)"
if ! on "${CHECKOUT_SRC_CLAUDE:-1}"; then echo "(fonte Claude Code desligada)"; else
CLAUDE_BLK="$(printf '%s|' "${BLK_REPO[@]:-}" "${BLK_PATH[@]:-}")"
BLK="$CLAUDE_BLK" node "${BASE}/bin/claude-activity.js" "${DATE}" 2>/dev/null \
  || echo "(não foi possível ler as sessões do Claude Code)"
fi

echo
echo "###############################################"
echo "# FIM DO DIGEST — ${DATE}"
echo "###############################################"
