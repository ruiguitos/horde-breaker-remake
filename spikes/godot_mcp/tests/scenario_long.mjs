// Pass 2 of the godot-mcp spike. Runs on the project left by scenario_basic.mjs (does not delete it).
// It imports with Godot itself (outside the MCP), repeats the calls that need imported resources,
// then checks debug output and stop_project while a 30-second project is running.
import { execFileSync } from 'node:child_process';
import { existsSync, readFileSync, writeFileSync, readdirSync, statSync } from 'node:fs';
import { join, parse, resolve } from 'node:path';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
const LONG_MAIN = 'extends Node\n\nfunc _ready() -> void:\n\tprint("MCP_SPIKE_START")\n\tfor t in range(1, 31):\n\t\tawait get_tree().create_timer(1.0).timeout\n\t\tprint("MCP_SPIKE_TICK %d" % t)\n\tprint("MCP_SPIKE_END")\n\tget_tree().quit()\n';

function listFiles(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) listFiles(p, out); else out.push(p);
  }
  return out;
}

export async function runScenario({ callTool, WORK_DIR, GODOT_PATH }) {
  const work = resolve(WORK_DIR);
  if (/horde-breaker-remake/i.test(work) || parse(work).root === work) throw new Error('WORK_DIR recusado (repositorio ou raiz de unidade)');
  const proj = join(work, 'proj');
  if (!existsSync(join(proj, '.godot-mcp-spike-fixture'))) throw new Error('proj sem o marcador deste spike: recusado');
  if (!existsSync(join(proj, 'project.godot'))) throw new Error('correr primeiro scenario_basic.mjs');
  const results = [];
  const step = async (name, tool, args, check) => {
    const t0 = Date.now();
    let r;
    try { r = await callTool(tool, args); } catch (e) { r = { ok: false, text: 'EXC ' + e.message }; }
    const ms = Date.now() - t0;
    let verdict = null;
    try { verdict = check ? check(r) : null; } catch (e) { verdict = 'verificacao falhou: ' + e.message; }
    results.push({ name, tool, ok: r.ok, ms, verdict, text: r.text.slice(0, 600) });
    console.log(`[${r.ok ? 'OK ' : 'ERR'}] ${name} (${ms} ms): ${r.text.replace(/\s+/g, ' ').slice(0, 220)}`);
    if (verdict !== null) console.log(`        -> ${verdict}`);
    return r;
  };
  const read = (rel) => readFileSync(join(proj, rel), 'utf8');

  // Phase A: import with Godot (not through the MCP), then the calls that need imported resources.
  let importNote;
  try {
    execFileSync(GODOT_PATH, ['--headless', '--path', proj, '--import'], { timeout: 180000, stdio: 'ignore' });
    importNote = 'import concluido (exit 0)';
  } catch (e) {
    importNote = `import com codigo ${e.status ?? e.code} (ver quirk 5/139 do Windows)`;
  }
  console.log('--- ' + importNote);
  console.log('--- .uid apos import: ' + listFiles(proj).filter((p) => p.endsWith('.uid')).map((p) => p.slice(proj.length + 1)).join(', '));

  await step('update_project_uids (apos import)', 'update_project_uids', { projectPath: proj },
    () => `ficheiros .uid: ${listFiles(proj).filter((p) => p.endsWith('.uid')).length}`);
  await step('get_uid (main.gd, apos import)', 'get_uid', { projectPath: proj, filePath: 'main.gd' },
    (r) => (/uid:\/\//.test(r.text) ? 'UID devolvido' : 'sem uid:// na resposta'));
  await step('load_sprite (icon.png, apos import)', 'load_sprite',
    { projectPath: proj, scenePath: 'scenes/sprite.tscn', nodePath: 'root/Sprite', texturePath: 'icon.png' },
    () => (read('scenes/sprite.tscn').includes('icon.png') ? 'textura referenciada no .tscn' : 'textura nao referenciada'));

  // Is the file already on disk when add_node returns? Checked immediately and after 1 s.
  await step('add_node Label (leitura imediata)', 'add_node',
    { projectPath: proj, scenePath: 'scenes/made.tscn', parentNodePath: 'root', nodeType: 'Label', nodeName: 'Tag' },
    () => (read('scenes/made.tscn').includes('name="Tag"') ? 'presente logo ao retornar' : 'AUSENTE ao retornar'));
  await sleep(1000);
  console.log('        -> depois de 1 s: ' + (read('scenes/made.tscn').includes('name="Tag"') ? 'presente' : 'continua ausente'));

  // Phase B: a 30-second project, read while running, stopped while running.
  writeFileSync(join(proj, 'main.gd'), LONG_MAIN, 'utf8');
  await step('run_project (30 s)', 'run_project', { projectPath: proj });
  await sleep(9000);
  await step('get_debug_output (aos ~9 s)', 'get_debug_output', {},
    (r) => `ticks ate agora: ${(r.text.match(/MCP_SPIKE_TICK/g) || []).length}`);
  await sleep(6000);
  await step('get_debug_output (aos ~15 s)', 'get_debug_output', {},
    (r) => `ticks ate agora: ${(r.text.match(/MCP_SPIKE_TICK/g) || []).length}`);
  await step('stop_project (a meio)', 'stop_project', {});
  await sleep(1500);
  await step('get_debug_output (depois de parar)', 'get_debug_output', {});

  writeFileSync(join(work, 'results_long.json'), JSON.stringify({ importNote, results }, null, 2));
  console.log(`--- resumo: ${results.filter((r) => r.ok).length}/${results.length} chamadas com ok=true`);
}
