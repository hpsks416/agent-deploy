#!/usr/bin/env node
// dsh-replay-web — 可视化引导页 + 点选渲染（基于 dsh-replay，只读不覆盖原日志）
// 零依赖：node:http / node:fs / node:path / node:child_process / node:os
import { createServer } from 'node:http';
import { readdirSync, statSync, existsSync, readFileSync, mkdirSync, rmSync } from 'node:fs';
import { join, basename } from 'node:path';
import { spawn } from 'node:child_process';
import { homedir } from 'node:os';

const HOME = homedir();
const sessionsRoot = join(HOME, '.dsh', 'sessions');
const outDir = join(process.env.TEMP || HOME, 'dsh-replay-out');
const PORT = 7781;

function listSessions() {
  const out = [];
  for (const ws of readdirSync(sessionsRoot)) {
    const wsDir = join(sessionsRoot, ws);
    try { if (!statSync(wsDir).isDirectory()) continue; } catch { continue; }
    for (const s of readdirSync(wsDir)) {
      const dir = join(wsDir, s);
      const j = join(dir, 'session.v3.jsonl.zstd');
      if (existsSync(j)) {
        try {
          const st = statSync(j);
          out.push({ id: s, dir, mb: (st.size / 1048576).toFixed(1), time: st.mtimeMs });
        } catch {}
      }
    }
  }
  return out.sort((a, b) => b.time - a.time).slice(0, 30);
}

function renderSession(sessionDir, id) {
  return new Promise((resolve) => {
    mkdirSync(outDir, { recursive: true });
    const j = join(sessionDir, 'session.v3.jsonl.zstd');
    const html = join(outDir, `${id}.html`);
    // 缓存只在「日志未更新」时复用；日志 mtime 比缓存新 → 删旧缓存重新渲染
    if (existsSync(html) && existsSync(j)) {
      const htmlTime = statSync(html).mtimeMs;
      const logTime = statSync(j).mtimeMs;
      if (htmlTime >= logTime) { resolve(html); return; }
      rmSync(html, { force: true });
    }
    const child = spawn('pnpm', ['dlx', 'dsh-replay', '--file', j, '--out', html], { shell: true, stdio: 'ignore' });
    child.on('close', (code) => {
      if (code === 0 && existsSync(html)) resolve(html);
      else resolve(null);
    });
    child.on('error', () => resolve(null));
  });
}

function guideHtml(sessions) {
  const items = sessions.map((s, i) => {
    const d = new Date(s.time);
    const t = `${String(d.getMonth() + 1).padStart(2, '0')}-${String(d.getDate()).padStart(2, '0')} ${String(d.getHours()).padStart(2, '0')}:${String(d.getMinutes()).padStart(2, '0')}`;
    return `<div class="item"><a href="/replay?id=${encodeURIComponent(s.id)}"><strong>${i + 1}. ${s.id}</strong></a> <span class="meta">${s.mb} MB · ${t}</span><br><code>${s.dir}</code></div>`;
  }).join('\n');
  return `<!DOCTYPE html><html lang="zh-CN"><head><meta charset="utf-8"><title>DSH Session Replay</title>
<style>
body{font-family:system-ui,Segoe UI,sans-serif;max-width:900px;margin:24px auto;padding:0 16px;color:#1a1a1a;background:#fafafa}
h1{font-size:20px}.tip{color:#555}
.item{background:#fff;border:1px solid #e0e0e0;border-radius:8px;padding:10px 14px;margin:10px 0}
.item a{color:#2563eb;text-decoration:none;font-size:15px}
.item a:hover{text-decoration:underline}
.meta{color:#888;font-size:12px}
code{font-size:12px;word-break:break-all;color:#666}
</style></head><body>
<h1>DSH Session Replay · 可视化引导页</h1>
<p class="tip">点选一个会话，自动渲染 timeline（只读，不覆盖原日志）。首次渲染约 10 秒。</p>
${items}
</body></html>`;
}

const server = createServer(async (req, res) => {
  const url = new URL(req.url, 'http://127.0.0.1');
  if (url.pathname === '/') {
    const sessions = listSessions();
    res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
    res.end(guideHtml(sessions));
    return;
  }
  if (url.pathname === '/replay') {
    const id = url.searchParams.get('id');
    const sessions = listSessions();
    const s = sessions.find((x) => x.id === id);
    if (!s) { res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' }); res.end('session not found'); return; }
    const html = await renderSession(s.dir, s.id);
    if (html) {
      res.writeHead(200, { 'Content-Type': 'text/html; charset=utf-8' });
      res.end(readFileSync(html));
    } else {
      res.writeHead(500, { 'Content-Type': 'text/plain; charset=utf-8' });
      res.end('render failed. run manually: pnpm dlx dsh-replay --file "' + join(s.dir, 'session.v3.jsonl.zstd') + '" --out replay.html');
    }
    return;
  }
  res.writeHead(404, { 'Content-Type': 'text/plain; charset=utf-8' });
  res.end('not found');
});

server.on('error', (e) => {
  if (e.code === 'EADDRINUSE') {
    console.log(`service already running at http://127.0.0.1:${PORT}/ — opening browser`);
    const start = spawn('cmd', ['/c', 'start', '', `http://127.0.0.1:${PORT}/`], { shell: true, stdio: 'ignore' });
    start.unref();
    process.stdin.resume(); // keep the process alive so the window does not flash-close
  } else {
    console.error('server error:', e.message);
  }
});

server.listen(PORT, '127.0.0.1', () => {
  console.log(`DSH Session Replay guide: http://127.0.0.1:${PORT}/`);
  console.log('Press Ctrl+C to stop.');
  const start = spawn('cmd', ['/c', 'start', '', `http://127.0.0.1:${PORT}/`], { shell: true, stdio: 'ignore' });
  start.unref();
});
