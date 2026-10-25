// ScriptHost: mini "GitHub raw" para pegar código y servirlo como texto plano.
// Sin dependencias. Uso: node server.js  (PORT y BASE_URL opcionales)
const http = require('http');
const fs = require('fs');
const crypto = require('crypto');

const PORT = process.env.PORT || 3000;
const DB = process.env.DB_FILE || './data.json';
const MAX_BYTES = 200 * 1024;
const RATE = { windowMs: 60_000, max: 20 }; // 20 subidas/minuto por IP

let db = {};
try { db = JSON.parse(fs.readFileSync(DB, 'utf8')); } catch {}
const save = () => fs.writeFileSync(DB, JSON.stringify(db));

const esc = s => s.replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const hits = new Map();
const limited = ip => {
  const now = Date.now();
  const arr = (hits.get(ip) || []).filter(t => now - t < RATE.windowMs);
  arr.push(now); hits.set(ip, arr);
  return arr.length > RATE.max;
};

const page = (title, body, hero = false) => `<!doctype html><html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1"><title>${esc(title)}</title>
<link href="https://fonts.googleapis.com/css2?family=Orbitron:wght@600;800&display=swap" rel="stylesheet">
<style>
:root{--ink:#eae6ff;--mut:#a79fd6;--card:rgba(20,12,50,.62);--line:rgba(160,130,255,.3);--glow:#9b6bff;--glow2:#34d6ff}
*{box-sizing:border-box}
body{margin:0;min-height:100vh;color:var(--ink);font:16px system-ui,sans-serif;background:
 radial-gradient(ellipse at 20% 15%,rgba(155,107,255,.35),transparent 50%),
 radial-gradient(ellipse at 85% 30%,rgba(52,214,255,.22),transparent 45%),
 radial-gradient(ellipse at 50% 100%,rgba(255,80,200,.2),transparent 50%),#05030f;overflow-x:hidden}
.stars,.stars:before,.stars:after{position:fixed;inset:0;content:"";pointer-events:none;
 background-image:radial-gradient(1.5px 1.5px at 20px 30px,#fff,transparent),radial-gradient(1px 1px at 90px 120px,#cfe,transparent),
 radial-gradient(1.5px 1.5px at 160px 70px,#fff,transparent),radial-gradient(1px 1px at 230px 190px,#fcf,transparent),radial-gradient(2px 2px at 300px 40px,#fff,transparent);
 background-size:320px 240px;animation:drift 120s linear infinite;opacity:.8}
.stars:before{background-size:210px 170px;animation-duration:80s;opacity:.5}
.stars:after{background-size:450px 330px;animation-duration:200s;opacity:.9}
@keyframes drift{to{background-position:-320px 480px}}
@keyframes twinkle{50%{opacity:.55}}
main{position:relative;max-width:820px;margin:0 auto;padding:20px 16px 60px}
h1,h2{font-family:Orbitron,system-ui,sans-serif}
.logo{display:block;text-align:center;color:var(--mut);text-decoration:none;font:600 14px Orbitron;letter-spacing:.3em;margin:8px 0 18px}
.hero{text-align:center;padding:42px 0 28px}
.hero h1{font-size:clamp(28px,7vw,54px);line-height:1.15;margin:0;font-weight:800;
 background:linear-gradient(90deg,#fff,var(--glow2),var(--glow),#ff7ad9);-webkit-background-clip:text;background-clip:text;color:transparent;
 filter:drop-shadow(0 0 18px rgba(155,107,255,.55))}
.hero p{color:var(--mut);margin:14px 0 0}
.card{background:var(--card);border:1px solid var(--line);border-radius:16px;padding:18px;backdrop-filter:blur(10px);box-shadow:0 0 40px rgba(120,80,255,.18)}
input,textarea,button{font:inherit;width:100%;padding:11px 12px;border-radius:10px;border:1px solid var(--line);background:rgba(8,4,25,.7);color:var(--ink);margin:6px 0}
input:focus,textarea:focus{outline:0;border-color:var(--glow2);box-shadow:0 0 0 3px rgba(52,214,255,.2)}
textarea{height:300px;font-family:ui-monospace,monospace;font-size:14px;resize:vertical}
button{border:0;cursor:pointer;font:700 15px Orbitron;letter-spacing:.08em;background:linear-gradient(90deg,var(--glow),var(--glow2));color:#05030f;transition:transform .15s,box-shadow .15s}
button:hover{transform:translateY(-2px);box-shadow:0 8px 28px rgba(120,80,255,.55)}
pre{background:rgba(8,4,25,.8);padding:12px;border-radius:10px;overflow:auto;border:1px solid var(--line);color:#d8ceff}
a{color:var(--glow2)}.muted{color:var(--mut);font-size:14px}
@media (prefers-reduced-motion:reduce){.stars,.stars:before,.stars:after{animation:none}}
</style></head><body><div class="stars"></div><main>
${hero ? '' : '<a class="logo" href="/">✦ THEPROYECTED ✦</a>'}${body}</main></body></html>`;

const send = (res, code, type, body) => { res.writeHead(code, {'Content-Type': type, 'X-Content-Type-Options': 'nosniff'}); res.end(body); };

http.createServer((req, res) => {
  const base = process.env.BASE_URL || `http://${req.headers.host}`;
  const ip = req.headers['x-forwarded-for']?.split(',')[0] || req.socket.remoteAddress;
  const url = new URL(req.url, 'http://x');

  if (req.method === 'GET' && url.pathname === '/') {
    return send(res, 200, 'text/html; charset=utf-8', page('Theproyected', `
<div class="hero"><h1>Welcome To<br>Theproyected Page</h1>
<p>Pega tu código y obtén un enlace /raw con texto plano para <code>loadstring(game:HttpGet(url))()</code></p></div>
<form class="card" method="POST" action="/new">
<input name="title" placeholder="Título (opcional)" maxlength="80">
<textarea name="code" placeholder="-- pega tu código aquí" required></textarea>
<button>PUBLICAR ✦</button>
<p class="muted" style="margin:8px 0 0">Máx. 200 KB. Publica solo código tuyo o con permiso.</p></form>`, true));
  }

  if (req.method === 'POST' && url.pathname === '/new') {
    if (limited(ip)) return send(res, 429, 'text/plain', 'Demasiadas subidas, espera un minuto.');
    let size = 0; const chunks = [];
    req.on('data', c => { size += c.length; if (size > MAX_BYTES + 2048) req.destroy(); else chunks.push(c); });
    req.on('end', () => {
      const f = new URLSearchParams(Buffer.concat(chunks).toString());
      const code = f.get('code') || '';
      if (!code.trim() || Buffer.byteLength(code) > MAX_BYTES) return send(res, 400, 'text/plain', 'Código vacío o demasiado grande.');
      const id = crypto.randomBytes(5).toString('hex');
      db[id] = { title: (f.get('title') || 'Sin título').slice(0, 80), code, at: Date.now() };
      save();
      res.writeHead(303, { Location: `/v/${id}` }); res.end();
    });
    return;
  }

  let m;
  if (req.method === 'GET' && (m = url.pathname.match(/^\/raw\/([a-f0-9]{10})$/))) {
    const s = db[m[1]];
    return s ? send(res, 200, 'text/plain; charset=utf-8', s.code) : send(res, 404, 'text/plain', 'No existe');
  }

  if (req.method === 'GET' && (m = url.pathname.match(/^\/v\/([a-f0-9]{10})$/))) {
    const s = db[m[1]];
    if (!s) return send(res, 404, 'text/plain', 'No existe');
    const raw = `${base}/raw/${m[1]}`;
    return send(res, 200, 'text/html; charset=utf-8', page(s.title, `
<div class="card"><h2>${esc(s.title)}</h2>
<p>Enlace raw: <a href="${raw}">${raw}</a></p>
<p class="muted">Uso en Lua:</p>
<pre>loadstring(game:HttpGet("${raw}"))()</pre>
<pre>${esc(s.code)}</pre></div>`));
  }

  send(res, 404, 'text/plain', 'No encontrado');
}).listen(PORT, () => console.log(`ScriptHost en http://localhost:${PORT}`));
