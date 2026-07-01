#!/usr/bin/env bash
# checkout-app.sh — abre a interface do Check-out Studio.
# Garante que o servidor está no ar (sobe se preciso) e abre no navegador.
# É o que o atalho "Check-out" (Super → digite "checkout") executa.
set -uo pipefail
BASE="${HOME}/Checkouts"
URL="http://127.0.0.1:7717"
export PATH="${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin:${PATH}"

up() { curl -s -o /dev/null -m 1 "${URL}/api/state" 2>/dev/null; }

# 1) já está no ar? Se não, tenta subir (pm2, senão node solto).
if ! up; then
  if command -v pm2 >/dev/null 2>&1; then
    pm2 restart checkout-studio >/dev/null 2>&1 \
      || pm2 start "${BASE}/bin/server.js" --name checkout-studio --time >/dev/null 2>&1
  else
    ( cd "${BASE}" && nohup node bin/server.js >/dev/null 2>&1 & )
  fi
  # espera até ~6s o servidor responder
  for _ in $(seq 1 24); do up && break; sleep 0.25; done
fi

# 2) abre a interface no navegador padrão
if command -v xdg-open >/dev/null 2>&1; then
  xdg-open "${URL}" >/dev/null 2>&1 &
else
  notify-send "Check-out" "Abra ${URL} no navegador" 2>/dev/null || echo "Abra ${URL}"
fi
