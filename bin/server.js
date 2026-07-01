#!/usr/bin/env node
// server.js — Check-out Studio: interface web local (127.0.0.1) para ajustar tudo.
// Sem dependências externas (http + fs + child_process). Roda como app pm2.
const http = require('http');
const fs = require('fs');
const path = require('path');
const { execFile } = require('child_process');

const HOME = process.env.HOME;
const BASE = path.join(HOME, 'Checkouts');
const BIN = path.join(BASE, 'bin');
const CONFIG = path.join(BASE, 'config.sh');
const BLOCKLIST = path.join(BASE, 'blocklist.txt');
const TEMPLATE = path.join(BASE, 'template.md');
const PORT = 7717;

const MONTHS = ['', 'Janeiro', 'Fevereiro', 'Marco', 'Abril', 'Maio', 'Junho',
  'Julho', 'Agosto', 'Setembro', 'Outubro', 'Novembro', 'Dezembro'];
const today = () => new Date(Date.now() - new Date().getTimezoneOffset() * 60000).toISOString().slice(0, 10);
function checkoutPath(date) {
  const [y, m] = date.split('-');
  return path.join(BASE, `${y}-${m}-${MONTHS[+m]}`, `checkout-${date}.md`);
}
const read = f => { try { return fs.readFileSync(f, 'utf8'); } catch { return ''; } };

// ---------- config.sh parse/update ----------
function parseVal(raw) {
  raw = raw.trim();
  if (raw[0] === '"') { const e = raw.indexOf('"', 1); return raw.slice(1, e); }
  const h = raw.indexOf('#'); return (h >= 0 ? raw.slice(0, h) : raw).trim();
}
function getConfig() {
  const c = read(CONFIG); const out = {};
  for (const ln of c.split('\n')) {
    const m = ln.match(/^export\s+(\w+)=(.*)$/);
    if (m) out[m[1]] = parseVal(m[2]);
  }
  return out;
}
function setVal(content, key, value, quote) {
  const re = new RegExp(`^(export\\s+${key}=)(.*)$`, 'm');
  const valStr = quote ? JSON.stringify(String(value)) : String(value);
  if (re.test(content)) {
    return content.replace(re, (m, p1, rest) => {
      const cm = rest.match(/(\s+#.*)$/); return `export ${key}=${valStr}${cm ? cm[1] : ''}`;
    });
  }
  return content.replace(/\n*$/, '') + `\nexport ${key}=${valStr}\n`;
}

// ---------- blocklist ----------
function getBlocks() {
  return read(BLOCKLIST).split('\n').map(l => l.trim())
    .filter(l => l && !l.startsWith('#') && /^(repo|pm2|path|user):/.test(l))
    .map(l => { const i = l.indexOf(':'); return { cat: l.slice(0, i), val: l.slice(i + 1) }; });
}
function addBlock(cat, val) {
  const rule = `${cat}:${val}`;
  const c = read(BLOCKLIST);
  if (c.split('\n').some(l => l.trim() === rule)) return;
  fs.writeFileSync(BLOCKLIST, c.replace(/\n*$/, '') + `\n${rule}\n`);
}
function removeBlock(cat, val) {
  const rule = `${cat}:${val}`;
  fs.writeFileSync(BLOCKLIST, read(BLOCKLIST).split('\n').filter(l => l.trim() !== rule).join('\n'));
}

// ---------- API ----------
function state() {
  const cfg = getConfig();
  const d = today();
  return {
    today: d,
    config: {
      nome: cfg.CHECKOUT_NOME || '', cargo: cfg.CHECKOUT_CARGO || '', turno: cfg.CHECKOUT_TURNO || '',
      mode: cfg.CHECKOUT_MODE || 'englobado',
      obsidian_enabled: (cfg.OBSIDIAN_ENABLED ?? '1') !== '0',
      obsidian_vault: cfg.OBSIDIAN_VAULT || '',
      sources: {
        git: (cfg.CHECKOUT_SRC_GIT ?? '1') !== '0',
        terminal: (cfg.CHECKOUT_SRC_TERMINAL ?? '1') !== '0',
        sistema: (cfg.CHECKOUT_SRC_SISTEMA ?? '1') !== '0',
        pm2: (cfg.CHECKOUT_SRC_PM2 ?? '1') !== '0',
        claude: (cfg.CHECKOUT_SRC_CLAUDE ?? '1') !== '0',
        browser: (cfg.CHECKOUT_SRC_BROWSER ?? '0') !== '0',
      },
    },
    blocks: getBlocks(),
    template: read(TEMPLATE),
    note_today: read(path.join(BASE, '.cache', `notas-${d}.txt`)),
    latest: read(checkoutPath(d)),
  };
}
function saveConfig(body) {
  let c = read(CONFIG);
  c = setVal(c, 'CHECKOUT_NOME', body.nome || '', true);
  c = setVal(c, 'CHECKOUT_CARGO', body.cargo || '', true);
  c = setVal(c, 'CHECKOUT_TURNO', body.turno || '', true);
  c = setVal(c, 'CHECKOUT_MODE', body.mode === 'reduzido' ? 'reduzido' : 'englobado', true);
  c = setVal(c, 'OBSIDIAN_ENABLED', body.obsidian_enabled ? 1 : 0, false);
  if (typeof body.obsidian_vault === 'string') c = setVal(c, 'OBSIDIAN_VAULT', body.obsidian_vault, true);
  const s = body.sources || {};
  c = setVal(c, 'CHECKOUT_SRC_GIT', s.git ? 1 : 0, false);
  c = setVal(c, 'CHECKOUT_SRC_TERMINAL', s.terminal ? 1 : 0, false);
  c = setVal(c, 'CHECKOUT_SRC_SISTEMA', s.sistema ? 1 : 0, false);
  c = setVal(c, 'CHECKOUT_SRC_PM2', s.pm2 ? 1 : 0, false);
  c = setVal(c, 'CHECKOUT_SRC_CLAUDE', s.claude ? 1 : 0, false);
  c = setVal(c, 'CHECKOUT_SRC_BROWSER', s.browser ? 1 : 0, false);
  fs.writeFileSync(CONFIG, c);
}
function addNote(text) {
  const d = today();
  const f = path.join(BASE, '.cache', `notas-${d}.txt`);
  fs.mkdirSync(path.dirname(f), { recursive: true });
  const hm = new Date().toTimeString().slice(0, 5);
  fs.appendFileSync(f, `- [${hm}] ${text}\n`);
}
function generate(cb) {
  execFile('bash', [path.join(BIN, 'generate-checkout.sh')],
    { timeout: 240000, env: { ...process.env, CHECKOUT_NOTIFY: '1' } },
    (err) => cb(err, read(checkoutPath(today()))));
}

// ---------- HTTP ----------
function send(res, code, type, data) { res.writeHead(code, { 'Content-Type': type }); res.end(data); }
function json(res, code, obj) { send(res, code, 'application/json', JSON.stringify(obj)); }
function readBody(req, cb) {
  let b = ''; req.on('data', d => b += d); req.on('end', () => { try { cb(JSON.parse(b || '{}')); } catch { cb({}); } });
}

const server = http.createServer((req, res) => {
  const u = new URL(req.url, 'http://localhost');
  const p = u.pathname;
  try {
    if (p === '/' || p === '/index.html') return send(res, 200, 'text/html; charset=utf-8', HTML);
    if (p === '/api/state') return json(res, 200, state());
    if (p === '/api/config' && req.method === 'POST') return readBody(req, b => { saveConfig(b); json(res, 200, { ok: true }); });
    if (p === '/api/template' && req.method === 'POST') return readBody(req, b => { fs.writeFileSync(TEMPLATE, b.content || ''); json(res, 200, { ok: true }); });
    if (p === '/api/note' && req.method === 'POST') return readBody(req, b => { if (b.text) addNote(b.text); json(res, 200, { ok: true }); });
    if (p === '/api/block' && req.method === 'POST') return readBody(req, b => {
      if (b.action === 'add') addBlock(b.cat, b.val); else if (b.action === 'remove') removeBlock(b.cat, b.val);
      json(res, 200, { ok: true, blocks: getBlocks() });
    });
    if (p === '/api/generate' && req.method === 'POST') return generate((err, content) => json(res, 200, { ok: !err, content, error: err ? String(err) : null }));
    send(res, 404, 'text/plain', 'not found');
  } catch (e) { json(res, 500, { error: String(e) }); }
});
server.listen(PORT, '127.0.0.1', () => console.log(`Check-out Studio em http://127.0.0.1:${PORT}`));

// ---------- página (HTML+CSS+JS inline) ----------
const HTML = `<!doctype html><html lang="pt-br"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Check-out Studio</title>
<style>
:root{--bg:#0f1115;--card:#181b22;--bd:#2a2f3a;--fg:#e6e9ef;--mut:#8b93a7;--ac:#5b8cff;--ok:#3ecf8e;--warn:#ff6b6b}
*{box-sizing:border-box}body{margin:0;background:var(--bg);color:var(--fg);font:14px/1.5 system-ui,Segoe UI,Roboto,sans-serif}
.wrap{max-width:1100px;margin:0 auto;padding:24px}h1{font-size:20px;margin:0 0 4px}.sub{color:var(--mut);margin-bottom:20px}
.grid{display:grid;grid-template-columns:1fr 1fr;gap:16px}@media(max-width:820px){.grid{grid-template-columns:1fr}}
.card{background:var(--card);border:1px solid var(--bd);border-radius:12px;padding:16px}
.card h2{font-size:13px;text-transform:uppercase;letter-spacing:.06em;color:var(--mut);margin:0 0 12px}
label{display:block;font-size:12px;color:var(--mut);margin:8px 0 4px}
input[type=text],textarea,select{width:100%;background:#0d0f14;border:1px solid var(--bd);color:var(--fg);border-radius:8px;padding:8px 10px;font:inherit}
textarea{min-height:120px;resize:vertical;font-family:ui-monospace,Menlo,monospace;font-size:12px}
.row{display:flex;gap:10px}.row>*{flex:1}
.chk{display:flex;align-items:center;gap:8px;color:var(--fg);font-size:13px;margin:6px 0}.chk input{width:16px;height:16px;accent-color:var(--ac)}
button{background:var(--ac);color:#fff;border:0;border-radius:8px;padding:9px 14px;font:inherit;font-weight:600;cursor:pointer}
button.ghost{background:transparent;border:1px solid var(--bd);color:var(--fg)}button:disabled{opacity:.5;cursor:wait}
.btns{display:flex;gap:10px;margin-top:12px;flex-wrap:wrap}
.blk{display:flex;align-items:center;gap:8px;background:#0d0f14;border:1px solid var(--bd);border-radius:6px;padding:5px 8px;margin:4px 0;font-size:12px}
.blk .cat{color:var(--ac);font-weight:600}.blk .x{margin-left:auto;color:var(--warn);cursor:pointer;font-weight:700}
.tag{font-size:11px;color:var(--mut)}
pre{background:#0d0f14;border:1px solid var(--bd);border-radius:8px;padding:14px;white-space:pre-wrap;word-break:break-word;max-height:520px;overflow:auto;font-size:12.5px}
.toast{position:fixed;bottom:20px;right:20px;background:var(--ok);color:#04130c;padding:10px 16px;border-radius:8px;font-weight:600;opacity:0;transition:.3s;pointer-events:none}
.toast.show{opacity:1}.spin{display:inline-block;width:14px;height:14px;border:2px solid #fff;border-right-color:transparent;border-radius:50%;animation:r .7s linear infinite;vertical-align:-2px}
@keyframes r{to{transform:rotate(360deg)}}
small.note{color:var(--mut)}
</style></head><body><div class="wrap">
<h1>📋 Check-out Studio</h1><div class="sub">Ajuste tudo e gere seu check-out — <span id="today"></span></div>
<div class="grid">
  <div>
    <div class="card"><h2>Identidade & Obsidian</h2>
      <div class="row"><div><label>Nome</label><input id="nome" type="text"></div><div><label>Cargo</label><input id="cargo" type="text"></div></div>
      <div class="row"><div><label>Turno</label><select id="turno"><option value="">(automático)</option><option>manhã</option><option>tarde</option><option>noite</option></select></div>
      <div><label>Obsidian</label><div class="chk"><input type="checkbox" id="obs_on"><span>Salvar no vault</span></div></div></div>
      <label>Caminho do vault</label><input id="obs_vault" type="text" placeholder="/home/.../Obsidian Vault">
      <label>Modo do check-out</label>
      <select id="mode"><option value="englobado">Englobado (padrão — valoriza tudo que fez)</option><option value="reduzido">Reduzido (sutil — enxuto)</option></select>
    </div>
    <div class="card" style="margin-top:16px"><h2>Fontes de coleta</h2>
      <div class="chk"><input type="checkbox" id="s_git"><span>Git (commits + não-commitado)</span></div>
      <div class="chk"><input type="checkbox" id="s_claude"><span>Claude Code (trabalho via IA)</span></div>
      <div class="chk"><input type="checkbox" id="s_terminal"><span>Terminal (histórico)</span></div>
      <div class="chk"><input type="checkbox" id="s_sistema"><span>Sistema (journalctl)</span></div>
      <div class="chk"><input type="checkbox" id="s_pm2"><span>pm2 (apps)</span></div>
      <div class="chk"><input type="checkbox" id="s_browser"><span>Navegador (histórico/pesquisas — requer sqlite3)</span></div>
    </div>
    <div class="card" style="margin-top:16px"><h2>Bloqueios (não entram no check-out)</h2>
      <div id="blocks"></div>
      <div class="row" style="margin-top:8px">
        <select id="b_cat" style="flex:0 0 110px"><option value="repo">repo</option><option value="pm2">pm2</option><option value="path">path</option><option value="user">user</option></select>
        <input id="b_val" type="text" placeholder="nome a bloquear">
        <button class="ghost" style="flex:0 0 auto" onclick="addBlock()">+ adicionar</button>
      </div>
    </div>
  </div>
  <div>
    <div class="card"><h2>Ações</h2>
      <label>Nota rápida (reunião, BIOS, presencial…)</label>
      <div class="row"><input id="note" type="text" placeholder="o que os logs não pegam"><button class="ghost" style="flex:0 0 auto" onclick="addNote()">add</button></div>
      <small class="note" id="notes_today"></small>
      <div class="btns"><button id="gen" onclick="gen()">▶ Gerar agora</button><button class="ghost" onclick="copyOut()">📋 Copiar</button><button class="ghost" onclick="saveAll()">💾 Salvar ajustes</button></div>
    </div>
    <div class="card" style="margin-top:16px"><h2>Preview do check-out</h2><pre id="preview">(carregando…)</pre></div>
    <div class="card" style="margin-top:16px"><h2>Template (a IA aprende este padrão)</h2>
      <textarea id="template"></textarea>
      <div class="btns"><button class="ghost" onclick="saveTemplate()">💾 Salvar template</button></div>
    </div>
  </div>
</div></div>
<div class="toast" id="toast"></div>
<script>
const $=id=>document.getElementById(id);
let S={};
function toast(m){const t=$('toast');t.textContent=m;t.classList.add('show');setTimeout(()=>t.classList.remove('show'),1800);}
async function api(p,m,b){const r=await fetch(p,{method:m||'GET',headers:{'Content-Type':'application/json'},body:b?JSON.stringify(b):undefined});return r.json();}
function renderBlocks(){$('blocks').innerHTML=S.blocks.map(b=>\`<div class="blk"><span class="cat">\${b.cat}</span><span>\${b.val}</span><span class="x" onclick="rmBlock('\${b.cat}','\${b.val.replace(/'/g,"\\\\'")}')">✕</span></div>\`).join('')||'<small class="note">(nenhum)</small>';}
function load(s){S=s;$('today').textContent=s.today;const c=s.config;
 $('nome').value=c.nome;$('cargo').value=c.cargo;$('turno').value=c.turno;$('mode').value=c.mode||'englobado';
 $('obs_on').checked=c.obsidian_enabled;$('obs_vault').value=c.obsidian_vault;
 $('s_git').checked=c.sources.git;$('s_claude').checked=c.sources.claude;$('s_terminal').checked=c.sources.terminal;$('s_sistema').checked=c.sources.sistema;$('s_pm2').checked=c.sources.pm2;$('s_browser').checked=c.sources.browser;
 $('template').value=s.template;$('preview').textContent=s.latest||'(ainda não gerado hoje — clique em Gerar agora)';
 $('notes_today').textContent=s.note_today?('notas de hoje:\\n'+s.note_today):'';
 renderBlocks();}
async function refresh(){load(await api('/api/state'));}
function cfgBody(){return{nome:$('nome').value,cargo:$('cargo').value,turno:$('turno').value,mode:$('mode').value,obsidian_enabled:$('obs_on').checked,obsidian_vault:$('obs_vault').value,sources:{git:$('s_git').checked,claude:$('s_claude').checked,terminal:$('s_terminal').checked,sistema:$('s_sistema').checked,pm2:$('s_pm2').checked,browser:$('s_browser').checked}};}
async function saveAll(){await api('/api/config','POST',cfgBody());toast('ajustes salvos ✔');}
async function saveTemplate(){await api('/api/template','POST',{content:$('template').value});toast('template salvo ✔');}
async function addNote(){const t=$('note').value.trim();if(!t)return;await api('/api/note','POST',{text:t});$('note').value='';toast('nota adicionada ✔');refresh();}
async function addBlock(){const v=$('b_val').value.trim();if(!v)return;const r=await api('/api/block','POST',{action:'add',cat:$('b_cat').value,val:v});S.blocks=r.blocks;$('b_val').value='';renderBlocks();toast('bloqueado ✔');}
async function rmBlock(cat,val){const r=await api('/api/block','POST',{action:'remove',cat,val});S.blocks=r.blocks;renderBlocks();toast('removido ✔');}
async function gen(){const b=$('gen');b.disabled=true;b.innerHTML='<span class="spin"></span> gerando…';await saveAll();const r=await api('/api/generate','POST',{});b.disabled=false;b.textContent='▶ Gerar agora';if(r.ok){$('preview').textContent=r.content;toast('check-out gerado ✔ (copiado e no Obsidian)');}else{toast('erro ao gerar');}}
function copyOut(){const t=$('preview').textContent;navigator.clipboard.writeText(t).then(()=>toast('copiado pra área de transferência ✔'));}
refresh();
</script></body></html>`;
