#!/usr/bin/env bash
# notify-checkout.sh — quando o check-out está pronto: copia pro clipboard,
# mostra um pop-up e abre o arquivo na tela.
# Uso: notify-checkout.sh [YYYY-MM-DD]
set -uo pipefail
DATE="${1:-$(date +%F)}"
BASE="${HOME}/Checkouts"
source "${BASE}/bin/_paths.sh"
FILE="$(checkout_file_for "${DATE}")"

# env gráfico (necessário quando chamado pelo pm2/daemon, não pelo terminal)
export XDG_RUNTIME_DIR="${XDG_RUNTIME_DIR:-/run/user/$(id -u)}"
export DBUS_SESSION_BUS_ADDRESS="${DBUS_SESSION_BUS_ADDRESS:-unix:path=${XDG_RUNTIME_DIR}/bus}"
export DISPLAY="${DISPLAY:-:0}"
export WAYLAND_DISPLAY="${WAYLAND_DISPLAY:-wayland-1}"

[ -s "$FILE" ] || { command -v notify-send >/dev/null && notify-send -u critical "❌ Check-out ${DATE}" "Arquivo não gerado. Veja ~/Checkouts/logs/."; exit 1; }

# 1) copia o texto inteiro pro clipboard (pronto pra colar/enviar)
if command -v wl-copy >/dev/null 2>&1; then wl-copy < "$FILE"
elif command -v xclip >/dev/null 2>&1; then xclip -selection clipboard < "$FILE"; fi

# 2) resumo curto pro corpo do pop-up
horas="$(grep -m1 'Total de horas' "$FILE" | sed 's/[📊]//g; s/^ *//')"
projs="$(grep -c '^🟢' "$FILE")"

# 3) pop-up
if command -v notify-send >/dev/null 2>&1; then
  notify-send -u normal -t 0 -i document-edit \
    "📋 Check-out de ${DATE} pronto" \
    "${projs} projeto(s) · ${horas:-horas calculadas}
✅ Copiado pra área de transferência — é só colar e enviar."
fi

# 4) abre o arquivo na tela
command -v xdg-open >/dev/null 2>&1 && setsid xdg-open "$FILE" >/dev/null 2>&1 &
exit 0
