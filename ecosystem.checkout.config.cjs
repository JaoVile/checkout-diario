// pm2: agendamento do check-out.
// Padrão pm2 de "tarefa agendada": roda 1x e sai; o cron_restart o reexecuta no horário.
// Detecta o ambiente automaticamente (portável entre máquinas/usuários).
// Inicie o pm2 a partir da sua sessão gráfica para herdar DISPLAY/Wayland/DBus.
const HOME = process.env.HOME;
const UID = process.getuid();
const RUNTIME = process.env.XDG_RUNTIME_DIR || `/run/user/${UID}`;
const GFX = {  // ambiente gráfico p/ notificação chegar à sessão do usuário
  XDG_RUNTIME_DIR: RUNTIME,
  DBUS_SESSION_BUS_ADDRESS: process.env.DBUS_SESSION_BUS_ADDRESS || `unix:path=${RUNTIME}/bus`,
  DISPLAY: process.env.DISPLAY || ":0",
  WAYLAND_DISPLAY: process.env.WAYLAND_DISPLAY || "wayland-1",
  PATH: `${HOME}/.local/bin:/usr/local/bin:/usr/bin:/bin`
};
module.exports = {
  apps: [
    {
      name: "checkout-diario",
      script: `${HOME}/Checkouts/bin/generate-checkout.sh`,
      interpreter: "bash",
      autorestart: false,            // roda e descansa até o próximo horário
      cron_restart: "50 17 * * *",   // FINAL do dia: gera + pop-up às 17:50
      out_file: `${HOME}/Checkouts/logs/pm2-checkout.out.log`,
      error_file: `${HOME}/Checkouts/logs/pm2-checkout.err.log`,
      env: { CHECKOUT_NOTIFY: "1", ...GFX }   // pop-up + clipboard + abrir arquivo
    },
    {
      name: "checkout-tick",
      script: `${HOME}/Checkouts/bin/tick.sh`,
      interpreter: "bash",
      autorestart: false,
      cron_restart: "*/20 7-17 * * *", // a cada 20 min, 7h–17h: varre e prepara o preview (sem pop-up)
      out_file: `${HOME}/Checkouts/logs/pm2-tick.out.log`,
      error_file: `${HOME}/Checkouts/logs/pm2-tick.err.log`,
      env: { ...GFX }                  // sem CHECKOUT_NOTIFY: ticks são silenciosos
    }
  ]
};
