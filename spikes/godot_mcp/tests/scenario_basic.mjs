// Pass 1 of the godot-mcp spike. Writes only under WORK_DIR (a scratch folder OUTSIDE the repository).
// The fixture project and the PNG are generated here, so nothing Godot-related lives in the repo.
import { existsSync, readFileSync, writeFileSync, mkdirSync, rmSync, readdirSync, statSync } from 'node:fs';
import { deflateSync, crc32 } from 'node:zlib';
import { join, parse, relative, resolve } from 'node:path';

const sleep = (ms) => new Promise((r) => setTimeout(r, ms));
// Marks the only folder this spike may delete. Written inside the fixture on creation.
const MARKER = '.godot-mcp-spike-fixture';

const FIXTURE = {
  'project.godot': 'config_version=5\n\n[application]\n\nconfig/name="MCP Spike"\nconfig/features=PackedStringArray("4.7", "Forward Plus")\nrun/main_scene="res://main.tscn"\n',
  'main.gd': 'extends Node\n\nfunc _ready() -> void:\n\tprint("MCP_SPIKE_START")\n\tfor t in range(1, 9):\n\t\tawait get_tree().create_timer(1.0).timeout\n\t\tprint("MCP_SPIKE_TICK %d" % t)\n\tprint("MCP_SPIKE_END")\n\tget_tree().quit()\n',
  'main.tscn': '[gd_scene load_steps=2 format=3]\n\n[ext_resource type="Script" path="res://main.gd" id="1_main"]\n\n[node name="Main" type="Node"]\nscript = ExtResource("1_main")\n',
};

// A valid RGB PNG (8-bit, filter 0 on every row). Generated here: a hand-typed base64 PNG was rejected by Godot.
export function makePng(w, h) {
  const stride = w * 3 + 1;
  const raw = Buffer.alloc(stride * h);
  for (let y = 0; y < h; y++) {
    for (let x = 0; x < w * 3; x++) raw[y * stride + 1 + x] = (x * 7 + y * 13) & 0xff;
  }
  const chunk = (type, data) => {
    const len = Buffer.alloc(4); len.writeUInt32BE(data.length);
    const td = Buffer.concat([Buffer.from(type, 'ascii'), data]);
    const crc = Buffer.alloc(4); crc.writeUInt32BE(crc32(td) >>> 0);
    return Buffer.concat([len, td, crc]);
  };
  const ihdr = Buffer.alloc(13);
  ihdr.writeUInt32BE(w, 0); ihdr.writeUInt32BE(h, 4);
  ihdr[8] = 8; ihdr[9] = 2; ihdr[10] = 0; ihdr[11] = 0; ihdr[12] = 0;
  return Buffer.concat([
    Buffer.from([137, 80, 78, 71, 13, 10, 26, 10]),
    chunk('IHDR', ihdr), chunk('IDAT', deflateSync(raw)), chunk('IEND', Buffer.alloc(0)),
  ]);
}

function listFiles(dir, out = []) {
  for (const name of readdirSync(dir)) {
    const p = join(dir, name);
    if (statSync(p).isDirectory()) listFiles(p, out); else out.push(p);
  }
  return out;
}

export async function runScenario({ callTool, WORK_DIR, GODOT_PATH }) {
  const work = resolve(WORK_DIR);
  if (/horde-breaker-remake/i.test(work)) throw new Error('WORK_DIR dentro do repositorio: recusado');
  if (parse(work).root === work) throw new Error('WORK_DIR nao pode ser a raiz de uma unidade: recusado');
  const proj = join(work, 'proj');
  mkdirSync(work, { recursive: true });
  if (existsSync(proj)) {
    // Only the fixture this spike created (it carries the marker) is removed. Anything else is refused, not deleted.
    if (!existsSync(join(proj, MARKER))) throw new Error('proj existe sem o marcador deste spike: recusado (nada apagado)');
    rmSync(proj, { recursive: true, force: true });
  }
  mkdirSync(proj, { recursive: true });
  writeFileSync(join(proj, MARKER), 'criado por scenario_basic.mjs\n', 'utf8');
  for (const [name, text] of Object.entries(FIXTURE)) writeFileSync(join(proj, name), text, 'utf8');
  writeFileSync(join(proj, 'icon.png'), makePng(16, 16));

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

  await step('get_godot_version', 'get_godot_version', {},
    (r) => (r.text.includes('4.7') ? 'versao 4.7.x detetada' : 'versao inesperada'));
  await step('list_projects (recursivo)', 'list_projects', { directory: work, recursive: true },
    (r) => (r.text.includes('proj') ? 'projeto de teste encontrado' : 'projeto nao listado'));
  await step('get_project_info', 'get_project_info', { projectPath: proj });

  await step('create_scene (Node3D)', 'create_scene',
    { projectPath: proj, scenePath: 'scenes/made.tscn', rootNodeType: 'Node3D' },
    () => (existsSync(join(proj, 'scenes', 'made.tscn')) ? 'ficheiro .tscn criado' : 'ficheiro em falta'));
  await step('add_node (MeshInstance3D "Box")', 'add_node',
    { projectPath: proj, scenePath: 'scenes/made.tscn', parentNodePath: 'root', nodeType: 'MeshInstance3D', nodeName: 'Box' },
    () => (read('scenes/made.tscn').includes('name="Box" type="MeshInstance3D"') ? 'no presente logo ao retornar' : 'no AUSENTE ao retornar'));
  await sleep(1000);
  console.log('        -> depois de 1 s: ' + (read('scenes/made.tscn').includes('name="Box"') ? 'presente' : 'ausente'));
  await step('save_scene (variante)', 'save_scene',
    { projectPath: proj, scenePath: 'scenes/made.tscn', newPath: 'scenes/made_variant.tscn' },
    () => (existsSync(join(proj, 'scenes', 'made_variant.tscn')) ? 'variante criada' : 'variante em falta'));

  await step('create_scene (Node2D)', 'create_scene',
    { projectPath: proj, scenePath: 'scenes/sprite.tscn', rootNodeType: 'Node2D' });
  await step('add_node (Sprite2D)', 'add_node',
    { projectPath: proj, scenePath: 'scenes/sprite.tscn', parentNodePath: 'root', nodeType: 'Sprite2D', nodeName: 'Sprite' });
  // Expected to fail here: the PNG is not imported yet. Pass 2 imports and repeats it.
  await step('load_sprite (sem import: falha esperada)', 'load_sprite',
    { projectPath: proj, scenePath: 'scenes/sprite.tscn', nodePath: 'root/Sprite', texturePath: 'icon.png' });

  await step('export_mesh_library (sem malhas, sem import)', 'export_mesh_library',
    { projectPath: proj, scenePath: 'scenes/made.tscn', outputPath: 'mesh_library.res' },
    () => (existsSync(join(proj, 'mesh_library.res')) ? 'ficheiro criado' : 'sucesso reportado mas SEM ficheiro'));
  await step('update_project_uids (sem import)', 'update_project_uids', { projectPath: proj },
    () => `ficheiros .uid: ${listFiles(proj).filter((p) => p.endsWith('.uid')).length}`);
  await step('get_uid (main.gd, sem import)', 'get_uid', { projectPath: proj, filePath: 'main.gd' },
    (r) => (/uid:\/\//.test(r.text) ? 'UID devolvido' : 'sucesso sem uid:// na resposta'));

  await step('run_project (janela curta, ~8 s)', 'run_project', { projectPath: proj });
  await sleep(3500);
  await step('get_debug_output (a meio)', 'get_debug_output', {},
    (r) => (r.text.includes('MCP_SPIKE_START') ? `inicio capturado; ticks: ${(r.text.match(/MCP_SPIKE_TICK/g) || []).length}` : 'sem saida do projeto ainda'));
  await sleep(9000);
  await step('get_debug_output (depois de terminar)', 'get_debug_output', {},
    (r) => (r.ok ? 'saida ainda disponivel' : 'sem processo: a saida de um projeto que terminou nao e devolvida'));
  await step('stop_project (ja terminado)', 'stop_project', {});

  await step('erro: projeto inexistente', 'get_project_info', { projectPath: join(work, 'nao-existe') },
    (r) => (r.ok ? 'aceitou um caminho inexistente' : 'erro claro, sem bloquear o servidor'));
  // The probe target stays inside WORK_DIR (one level above the fixture), never above WORK_DIR.
  const escape = join(proj, '..', 'escape_test.tscn');
  await step('confinamento: scenePath com ..', 'create_scene',
    { projectPath: proj, scenePath: '../escape_test.tscn', rootNodeType: 'Node' },
    () => (existsSync(escape) ? 'ESCREVEU FORA DO PROJETO' : 'recusado; nada escrito fora do projeto'));

  const all = listFiles(proj).map((p) => relative(proj, p).replace(/\\/g, '/'));
  const leftovers = all.filter((p) => /test|tmp|temp/i.test(p));
  console.log('--- ficheiros finais no projeto de teste:');
  console.log(all.sort().join('\n'));
  console.log('--- restos de teste:', leftovers.length ? leftovers.join(', ') : 'nenhum');
  writeFileSync(join(work, 'results_basic.json'), JSON.stringify({ godot: GODOT_PATH, results, files: all.sort(), leftovers }, null, 2));
  console.log(`--- resumo: ${results.filter((r) => r.ok).length}/${results.length} chamadas com ok=true`);
}
