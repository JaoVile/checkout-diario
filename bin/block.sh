#!/usr/bin/env bash
# block.sh — gerencia a lista de bloqueios permanentes do check-out.
# Uso:
#   block.sh repo|pm2|path|user <texto>   adiciona um bloqueio
#   block.sh unblock <texto>              remove qualquer regra que contenha <texto>
#   block.sh list                         mostra os bloqueios ativos
set -uo pipefail
BLOCKFILE="${HOME}/Checkouts/blocklist.txt"

cmd="${1:-list}"
case "$cmd" in
  repo|pm2|path|user)
    val="${2:-}"; [ -z "$val" ] && { echo "uso: block.sh $cmd <texto>"; exit 1; }
    rule="${cmd}:${val}"
    if grep -qxF "$rule" "$BLOCKFILE" 2>/dev/null; then
      echo "já existe: $rule"
    else
      printf '%s\n' "$rule" >> "$BLOCKFILE"
      echo "bloqueado p/ sempre: $rule"
    fi ;;
  unblock)
    val="${2:-}"; [ -z "$val" ] && { echo "uso: block.sh unblock <texto>"; exit 1; }
    tmp="$(mktemp)"; grep -vF "$val" "$BLOCKFILE" > "$tmp" && mv "$tmp" "$BLOCKFILE"
    echo "removidas regras contendo: $val" ;;
  list|*)
    echo "Bloqueios ativos:"
    active="$(grep -vE '^\s*#|^\s*$' "$BLOCKFILE" 2>/dev/null)"
    if [ -n "$active" ]; then printf '%s\n' "$active" | sed 's/^/  • /'; else echo "  (nenhum)"; fi ;;
esac
