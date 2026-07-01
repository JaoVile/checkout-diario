#!/usr/bin/env bash
# install.sh — prepara o check-out automático na sua máquina.
# Uso:  cd ~/Checkouts && bash install.sh
set -uo pipefail

BASE="$(cd "$(dirname "$0")" && pwd)"
say() { printf '%s\n' "$*"; }
ok()  { printf '  ✔ %s\n' "$*"; }
warn(){ printf '  ⚠ %s\n' "$*"; }

say "📋 Instalando o check-out automático em: ${BASE}"
say ""

# 1) O sistema assume ~/Checkouts. Avisa se estiver em outro lugar.
if [ "${BASE}" != "${HOME}/Checkouts" ]; then
  warn "Os scripts esperam o repositório em ~/Checkouts."
  warn "Clone (ou mova) para lá:  git clone <url> ~/Checkouts"
  say ""
fi

# 2) Cria sua config e blocklist pessoais a partir dos modelos (não sobrescreve).
if [ -f "${BASE}/config.sh" ]; then
  ok "config.sh já existe (mantido)"
else
  cp "${BASE}/config.example.sh" "${BASE}/config.sh"
  ok "config.sh criado a partir do exemplo — edite seu nome/cargo lá"
fi
if [ -f "${BASE}/blocklist.txt" ]; then
  ok "blocklist.txt já existe (mantido)"
else
  cp "${BASE}/blocklist.example.txt" "${BASE}/blocklist.txt"
  ok "blocklist.txt criado a partir do exemplo"
fi

# 3) Pastas de trabalho.
mkdir -p "${BASE}/.cache" "${BASE}/logs"
chmod +x "${BASE}/bin/"*.sh 2>/dev/null
ok "pastas .cache/ e logs/ prontas; scripts marcados como executáveis"

# 4) Checa dependências.
say ""
say "🔎 Dependências:"
need_ok=1
check() { if command -v "$1" >/dev/null 2>&1; then ok "$1"; else warn "FALTA: $1 — $2"; need_ok=0; fi; }
check node   "instale Node.js (necessário p/ a interface e o extrator do Claude)"
check claude "instale o Claude Code CLI (é quem escreve o check-out)"
check pm2    "instale com: npm i -g pm2  (agendador que mantém tudo ativo)"
check git    "instale git"
command -v notify-send >/dev/null 2>&1 && ok "notify-send (pop-up)" || warn "notify-send ausente — sem pop-up (opcional)"
command -v wl-copy    >/dev/null 2>&1 && ok "wl-copy (clipboard Wayland)" || warn "wl-copy ausente — sem cópia automática (opcional)"
command -v sqlite3    >/dev/null 2>&1 && ok "sqlite3 (histórico do navegador)" || warn "sqlite3 ausente — sem fonte navegador (opcional): sudo apt install sqlite3"

# 5) Registra no pm2 (se disponível).
say ""
if command -v pm2 >/dev/null 2>&1; then
  say "🚀 Registrando no pm2..."
  pm2 start "${BASE}/ecosystem.checkout.config.cjs" && \
  pm2 start "${BASE}/bin/server.js" --name checkout-studio --time 2>/dev/null
  pm2 save
  ok "apps registrados (checkout-diario, checkout-tick, checkout-studio)"
  say ""
  say "  Para sobreviver a reboot, rode uma vez (copie/cole o comando que ele imprimir):"
  say "      pm2 startup"
else
  warn "pm2 não encontrado — pulei o agendamento. Instale e rode:"
  say  "      npm i -g pm2 && pm2 start ${BASE}/ecosystem.checkout.config.cjs && pm2 save"
fi

say ""
say "✅ Pronto!"
say "   1) Edite ${BASE}/config.sh (seu nome, cargo, pastas de projeto, Obsidian)."
say "   2) Interface de ajustes:  http://127.0.0.1:7717"
say "   3) Gerar agora:           bash ${BASE}/bin/generate-checkout.sh"
[ "${need_ok}" = 1 ] || say "   ⚠ Instale as dependências que faltaram acima antes de usar."
