#!/usr/bin/env bash
# _paths.sh — decide em qual pasta (por mês) o check-out de uma data deve ficar.
# Sourceado por generate-checkout.sh, notify-checkout.sh e review-checkout.sh.

# carrega config (identidade + vault), se existir
[ -f "${HOME}/Checkouts/config.sh" ] && source "${HOME}/Checkouts/config.sh"

_month_pt() {
  case "$1" in
    01) echo Janeiro;; 02) echo Fevereiro;; 03) echo Marco;;    04) echo Abril;;
    05) echo Maio;;    06) echo Junho;;     07) echo Julho;;    08) echo Agosto;;
    09) echo Setembro;; 10) echo Outubro;;  11) echo Novembro;; 12) echo Dezembro;;
    *) echo "";;
  esac
}

# pasta do mês dentro do vault do Obsidian (vazio se Obsidian desligado)
obsidian_file_for() {
  local d="$1" ym mm mn
  [ "${OBSIDIAN_ENABLED:-1}" = "0" ] && return 0
  [ -z "${OBSIDIAN_VAULT:-}" ] && return 0
  ym="$(date -d "$d" '+%Y-%m' 2>/dev/null)" || return 0
  mm="${ym#*-}"; mn="$(_month_pt "$mm")"
  echo "${OBSIDIAN_VAULT}/${OBSIDIAN_SUBDIR:-Check-outs}/${ym}-${mn}/checkout-${d}.md"
}

checkout_dir_for() {
  local d="$1" base="${HOME}/Checkouts" ym mm mn
  ym="$(date -d "$d" '+%Y-%m' 2>/dev/null)" || ym=""
  mm="${ym#*-}"; mn="$(_month_pt "$mm")"
  if [ -n "$ym" ] && [ -n "$mn" ]; then echo "${base}/${ym}-${mn}"; else echo "${base}"; fi
}
checkout_file_for() { echo "$(checkout_dir_for "$1")/checkout-$1.md"; }
