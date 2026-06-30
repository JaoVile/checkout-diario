#!/usr/bin/env bash
# config.example.sh — modelo de configuração.
# O install.sh copia este arquivo para config.sh (que é pessoal e fica fora do git).
# Edite o seu config.sh à vontade.

export CHECKOUT_NOME="Seu Nome"
export CHECKOUT_CARGO="Desenvolvimento"
export CHECKOUT_TURNO=""          # opcional: "manhã", "tarde", "noite" (vazio = a IA deduz pelos horários)
export CHECKOUT_MODE="englobado"  # "englobado" (padrão, valoriza tudo que foi feito) ou "reduzido" (sutil/enxuto)

# Onde procurar seus repositórios (lista separada por espaço; ~ é expandido).
# Ex: "~/github ~/code ~/work". Deixe vazio para usar ~/github e ~/Projetos.
export CHECKOUT_PROJECT_DIRS="~/github ~/Projetos"

# Saída no Obsidian (opcional). Ponha 0 se não usar Obsidian.
export OBSIDIAN_ENABLED=0
export OBSIDIAN_VAULT="${HOME}/Documentos/Obsidian Vault"
export OBSIDIAN_SUBDIR="Check-outs"

# Fontes de coleta (1 = ligada, 0 = desligada)
export CHECKOUT_SRC_GIT=1        # commits + trabalho não-commitado
export CHECKOUT_SRC_TERMINAL=1   # histórico de comandos
export CHECKOUT_SRC_SISTEMA=1    # journalctl (sessões/sudo/erros)
export CHECKOUT_SRC_PM2=1        # apps do pm2
export CHECKOUT_SRC_CLAUDE=1     # trabalho via Claude Code
