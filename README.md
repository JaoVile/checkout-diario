# 📋 Automação de Check-out Diário

Gera todo dia, às **17:50** (via pm2), um check-out no seu formato a partir de
**tudo que o PC registrou**:
- commits git **e mudanças ainda não commitadas** (trabalho em andamento);
- **trabalho feito via Claude Code** (sessões em `~/.claude/projects`, mesmo sem commit);
- comandos de terminal, sessões/sudo do sistema (journalctl) e apps do pm2;
- **histórico do navegador** (Firefox/Chrome/Brave/Edge — o que foi pesquisado/consultado; opcional, requer `sqlite3`);
- **linha do tempo real** (primeira/última atividade e eventos por hora — dá base honesta pras "horas estimadas").

O texto é escrito pelo Claude no tom do molde. **Toda a varredura é LOCAL** —
nada sai da sua máquina; só o resumo final passa pelo Claude pra ser redigido.

> Nota: o que acontece na **BIOS/firmware** (antes do boot) não é captável por
> nenhum log do sistema — só reinícios aparecem.

## 🚀 Instalação (para começar / compartilhar)
```bash
git clone <url-do-repo> ~/Checkouts
cd ~/Checkouts
bash install.sh          # cria config.sh/blocklist.txt, checa deps, registra no pm2
```
Depois edite `config.sh` (seu nome, cargo, pastas de projeto, Obsidian) — ou use a
interface em `http://127.0.0.1:7717`.

> 🔒 **Privacidade:** `config.sh`, `blocklist.txt`, seus check-outs (`AAAA-MM-Mes/`),
> `.cache/` e `logs/` ficam **fora do git** (veja `.gitignore`). O repositório só
> carrega o **código** e os modelos `*.example`. Seus dados nunca são publicados.

## Arquivos
- `AAAA-MM-Mes/checkout-AAAA-MM-DD.md` → o check-out do dia, organizado em pasta por mês
  (ex: `2026-07-Julho/checkout-2026-07-01.md`). Lógica em `bin/_paths.sh`.
- `blocklist.txt` → bloqueios **permanentes** (o que nunca deve aparecer).
- `bin/collect-activity.sh` → coleta os logs do dia (o "digest" cru).
- `bin/generate-checkout.sh` → coleta + IA escreve + salva (é o que o cron roda).
- `bin/block.sh` → adiciona/remove bloqueios permanentes.
- `bin/review-checkout.sh` → **revisão interativa**: escolhe por dia o que entra.
- `.cache/` digests crus · `logs/` logs de execução.

## Personalização (sem mexer em código)
- `config.sh` → seu nome, cargo, turno e o caminho do **Obsidian** (vault + subpasta).
- `template.md` → o **formato** do seu check-out. Pode ser um molde vazio OU um
  exemplo preenchido: a IA **aprende o padrão** dele (tamanho dos bullets, tom, seções).
  É aqui que cada pessoa põe o jeito dela.

## Abrir pelo menu (Super → "checkout")
O `install.sh` cria um atalho de aplicativo. Tecle **Super** e digite **checkout**:
abre o **Check-out Studio** (garante o servidor no ar e abre a interface, onde
você vê o preview do dia, gera e ajusta tudo). Launcher: `bin/checkout-app.sh`.

## Modos de uso
- **Automático**: às 17:50 o pm2 varre o PC e gera (não faz nada).
- **Híbrido (padrão)**: durante o dia, registre o que os logs não pegam:
  ```bash
  ~/Checkouts/bin/nota.sh "reunião presencial com a Multi, 1h, alinhamento"
  ~/Checkouts/bin/nota.sh "entrei na BIOS pra ativar virtualização"
  ```
  As notas entram no próximo check-out junto com a varredura.
- **Ditado (diga e gere na hora)**:
  ```bash
  ~/Checkouts/bin/checkout-diga.sh "fiz X e Y, call 1h de tarde, turno da tarde"
  ```
  Gera já com pop-up. Se você não disser o tempo, a IA estima.

## Saídas
- `~/Checkouts/AAAA-MM-Mes/checkout-AAAA-MM-DD.md` (local, por mês)
- **Obsidian**: `<vault>/Check-outs/AAAA-MM-Mes/checkout-...md` (cópia automática)

## Uso no dia a dia

### Escolher o que entra (revisão interativa)
```bash
~/Checkouts/bin/review-checkout.sh          # hoje
~/Checkouts/bin/review-checkout.sh 2026-06-28
```
Mostra os itens detectados (repos e apps), você digita os números que **não**
quer hoje. Acrescente `fix` a um número para **bloquear para sempre** (ex: `2fix`).

### Bloquear/desbloquear para sempre
```bash
~/Checkouts/bin/block.sh repo projeto-x  # ignora o repositório "projeto-x"
~/Checkouts/bin/block.sh pm2  meu-app    # ignora o app "meu-app" do pm2
~/Checkouts/bin/block.sh path pessoal    # ignora pastas/comandos com "pessoal"
~/Checkouts/bin/block.sh user smartctl   # ignora sessões/sudo com "smartctl"
~/Checkouts/bin/block.sh unblock projeto-x  # remove o bloqueio
~/Checkouts/bin/block.sh list            # lista os bloqueios ativos
```

### Gerar manualmente (sem revisão)
```bash
~/Checkouts/bin/generate-checkout.sh            # hoje
~/Checkouts/bin/generate-checkout.sh 2026-06-28 # dia específico
```

## Agendamento (pm2 — sempre ativo)
O agendador é o **pm2** (não mais cron). Três apps:
- **`checkout-tick`** → a cada **20 min, das 7h às 17h**, faz uma varredura rápida (~1,5s)
  e **só regera o preview com IA se o trabalho mudou** (compara um hash das seções de
  trabalho). Assim o check-out de hoje fica **sempre pronto** — se você pedir antes do
  fim do expediente, já está lá. Silencioso (sem pop-up).
- **`checkout-diario`** → às **17:50**, gera a versão final e dispara o **pop-up**:
  copia o texto pro clipboard e abre o arquivo — é só colar e enviar.
- **`checkout-studio`** → a interface web (sempre online em :7717).

```bash
pm2 list                       # ver o app checkout-diario
pm2 restart checkout-diario    # rodar agora (gera + pop-up)
pm2 logs checkout-diario       # acompanhar
```
Config em `ecosystem.checkout.config.cjs`. Sobrevive a reboot (`pm2 save` +
`pm2 startup` já configurados). Pop-up/clipboard: `bin/notify-checkout.sh`.

Rode `review-checkout.sh` quando quiser escolher/refazer manualmente.

## Opcional: timestamps no terminal
Para captar comandos por horário exato, adicione ao seu `~/.bashrc`:
```bash
export HISTTIMEFORMAT="%F %T "
```
(Sem isso, os comandos ainda aparecem, só sem data confiável.)
