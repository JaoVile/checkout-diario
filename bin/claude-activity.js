#!/usr/bin/env node
// claude-activity.js — resume o trabalho feito via Claude Code num dia.
// Lê ~/.claude/projects/*/*.jsonl, agrupa por projeto (cwd), respeita bloqueios.
// Para cada projeto extrai: pedidos do usuário (o que foi solicitado) e o
// ÚLTIMO resumo do assistente (o que foi feito / o que falta).
// Uso: node claude-activity.js YYYY-MM-DD     (env BLK = "frag1|frag2|..." a excluir)
const fs = require('fs'), path = require('path');
const DATE = process.argv[2] || new Date().toISOString().slice(0, 10);
const BLK = (process.env.BLK || '').split('|').filter(Boolean);
const root = path.join(process.env.HOME, '.claude', 'projects');
const blocked = p => BLK.some(b => String(p).includes(b));
const clean = s => (s || '').replace(/\s+/g, ' ').trim();
const isNoise = t => !t || t[0] === '<' || t.startsWith('[Request') || t.includes('tool_result') || t.includes('Caveat:');

let dirs = [];
try { dirs = fs.readdirSync(root); } catch { console.log('(sem ~/.claude/projects)'); process.exit(0); }

const proj = {}; // cwd -> { count, prompts:[], summary, sumTs, firstTs, lastTs }
for (const d of dirs) {
  const dir = path.join(root, d);
  let files = [];
  try { files = fs.readdirSync(dir).filter(f => f.endsWith('.jsonl')); } catch { continue; }
  for (const f of files) {
    let raw;
    try { raw = fs.readFileSync(path.join(dir, f), 'utf8'); } catch { continue; }
    for (const ln of raw.split('\n')) {
      if (!ln.trim()) continue;
      let o; try { o = JSON.parse(ln); } catch { continue; }
      const ts = o.timestamp;
      if (!ts || ts.slice(0, 10) !== DATE) continue;
      if (o.type !== 'user' && o.type !== 'assistant') continue;
      const cwd = o.cwd || d;
      const c = o.message && o.message.content;
      let txt = '';
      if (typeof c === 'string') txt = c;
      else if (Array.isArray(c)) { const t = c.find(x => x && x.type === 'text'); txt = t ? t.text : ''; }
      txt = clean(txt);
      if (o.type === 'user' && isNoise(txt)) continue;
      if (!txt) continue;
      if (!proj[cwd]) proj[cwd] = { count: 0, prompts: [], summary: '', sumTs: '', firstTs: ts, lastTs: ts };
      const p = proj[cwd];
      if (ts < p.firstTs) p.firstTs = ts;
      if (ts > p.lastTs) p.lastTs = ts;
      if (o.type === 'user') {
        p.count++;
        if (p.prompts.length < 8) p.prompts.push(txt.slice(0, 160));
      } else { // assistant: guarda o resumo de texto mais recente
        if (ts >= p.sumTs) { p.summary = txt.slice(0, 800); p.sumTs = ts; }
      }
    }
  }
}

const keys = Object.keys(proj).filter(k => !blocked(k));
if (!keys.length) { console.log('(nenhuma sessão do Claude Code neste dia, ou todas bloqueadas)'); process.exit(0); }
keys.sort((a, b) => proj[a].firstTs.localeCompare(proj[b].firstTs));
for (const k of keys) {
  const p = proj[k];
  console.log(`### CLAUDE: ${path.basename(k)}  (${k})`);
  console.log(`    ${p.count} pedidos entre ${p.firstTs.slice(11, 16)} e ${p.lastTs.slice(11, 16)}`);
  console.log(`    O que foi pedido:`);
  for (const pr of p.prompts) console.log(`      • ${pr}`);
  if (p.summary) console.log(`    Resumo do Claude (o que foi feito / o que falta):\n      "${p.summary}"`);
}
