// Minimal MCP stdio client for the godot-mcp spike (no dependencies; Node >= 18).
// Env: PKG_DIR (folder where `npm install --prefix PKG_DIR @coding-solo/godot-mcp@<pinned>` ran),
//      GODOT_PATH (Godot 4.7.x console exe), WORK_DIR (scratch folder OUTSIDE the repo),
//      MODE=list|run (default list), SCENARIO (default ./scenario_basic.mjs; use ./scenario_long.mjs for pass 2).
import { spawn } from 'node:child_process';
import { join } from 'node:path';

const PKG_DIR = process.env.PKG_DIR;
const GODOT_PATH = process.env.GODOT_PATH;
const MODE = process.env.MODE ?? 'list';
const entry = join(PKG_DIR, 'node_modules', '@coding-solo', 'godot-mcp', 'build', 'index.js');

const child = spawn(process.execPath, [entry], {
  env: { ...process.env, GODOT_PATH, DEBUG: 'true' },
  stdio: ['pipe', 'pipe', 'pipe'],
});
let stderrBuf = '';
child.stderr.on('data', (d) => { stderrBuf += d.toString(); });

// stdout must carry only JSON-RPC lines; anything else is recorded, not ignored.
let stdoutBuf = '';
const pending = new Map();
const stray = [];
let nextId = 1;
child.stdout.on('data', (chunk) => {
  stdoutBuf += chunk.toString();
  let nl;
  while ((nl = stdoutBuf.indexOf('\n')) >= 0) {
    const line = stdoutBuf.slice(0, nl).trim();
    stdoutBuf = stdoutBuf.slice(nl + 1);
    if (!line) continue;
    let msg;
    try { msg = JSON.parse(line); } catch { stray.push(line); continue; }
    if (msg.id !== undefined && pending.has(msg.id)) {
      pending.get(msg.id)(msg);
      pending.delete(msg.id);
    } else {
      stray.push(line);
    }
  }
});

function send(obj) { child.stdin.write(JSON.stringify(obj) + '\n'); }
function rpc(method, params, timeoutMs = 180000) {
  const id = nextId++;
  send({ jsonrpc: '2.0', id, method, params });
  return new Promise((resolve, reject) => {
    const timer = setTimeout(() => { pending.delete(id); reject(new Error(`timeout em ${method}`)); }, timeoutMs);
    pending.set(id, (msg) => { clearTimeout(timer); resolve(msg); });
  });
}
async function callTool(name, args = {}) {
  const r = await rpc('tools/call', { name, arguments: args });
  if (r.error) return { ok: false, text: `JSON-RPC error: ${JSON.stringify(r.error)}` };
  const text = (r.result?.content ?? []).map((c) => c.text ?? JSON.stringify(c)).join('\n');
  return { ok: !r.result?.isError, text };
}

let exitCode = 0;
try {
  const init = await rpc('initialize', {
    protocolVersion: '2024-11-05',
    capabilities: {},
    clientInfo: { name: 'horde-breaker-spike', version: '0.0.1' },
  });
  console.log('initialize:', JSON.stringify(init.result ?? init.error));
  send({ jsonrpc: '2.0', method: 'notifications/initialized' });
  const tl = await rpc('tools/list', {});
  const tools = tl.result?.tools ?? [];
  console.log(`tools (${tools.length}):`);
  if (MODE === 'list') {
    for (const t of tools) {
      console.log(`- ${t.name}: ${JSON.stringify(t.inputSchema?.properties ?? {})} required=${JSON.stringify(t.inputSchema?.required ?? [])}`);
    }
  } else {
    const { runScenario } = await import(new URL(process.env.SCENARIO ?? './scenario_basic.mjs', import.meta.url));
    await runScenario({ callTool, WORK_DIR: process.env.WORK_DIR, GODOT_PATH });
  }
} catch (e) {
  console.log('ERRO:', e.message);
  exitCode = 1;
} finally {
  child.kill();
  console.log('stdout nao-JSON (primeiras 5):', JSON.stringify(stray.slice(0, 5)));
  console.log('stderr do servidor (ultimas 30 linhas):\n' + stderrBuf.split('\n').slice(-30).join('\n'));
  process.exit(exitCode);
}
