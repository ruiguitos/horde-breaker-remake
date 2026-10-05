# Arquitetura técnica do remake

Estado: **proposta** (pré-produção). Godot 4.7 stable, GDScript tipado,
Forward+. Este documento guarda **contratos e porquês**; prioridades vivem
noutro sítio e decisões fechadas só em `docs/DECISIONS.md`.

Pontos ainda em aberto em `DECISIONS.md` (escala da horda, mira, base,
direção) afetam partes deste documento. Onde isso acontece, a arquitetura foi
escolhida para **funcionar nos dois cenários** (dezenas de especiais
inteligentes *e* centenas de comuns) e está marcado com ⚠️.

---

## 1. Estrutura de `game/` e convenções de nomes

Organização **por feature**, não por tipo de ficheiro: tudo o que pertence à
horda vive junto. Assim um sistema órfão vê-se (e apaga-se) de uma vez — lição
do original.

```
game/
  main.tscn                  cena raiz: só arranca o RunStateMachine
  core/                      autoloads e infraestrutura sem gameplay
    events.gd                event bus (autoload Events)
    save/                    save_service.gd, migrations/
    telemetry/               run_telemetry.gd
  run/                       state machine da run e estados
    run_state_machine.gd
    states/                  menu_state.gd, boat_state.gd, island_state.gd…
  player/                    player.tscn, player.gd, camera_rig.tscn
  weapons/                   weapon.gd, hitscan.gd, projectiles/
  horde/                     simulação de dados (ver secção 4)
    horde_sim.gd, flow_field.gd, spatial_hash.gd, horde_renderer.gd
    specials/                especiais com cena própria (Screamer, Grabber…)
  cards/                     card_effect.gd e efeitos de comportamento
  islands/<island_id>/       cena da ilha, navegação, spawns
  missions/                  templates (hold_zone.gd, carry.gd…)
  ui/                        hud/, menus/, debrief/
  data/                      .tres: weapons/, enemies/, cards/, islands/, missions/
  resources/                 scripts dos Resources (weapon_data.gd…)
  debug/                     painel de debug, overlays (excluído do build final)
```

Convenções:

| Coisa | Convenção | Exemplo |
|---|---|---|
| Ficheiros e pastas | `snake_case` | `flow_field.gd`, `dawn_beach/` |
| `class_name`, nós em cena | `PascalCase` | `class_name FlowField` |
| Funções, variáveis | `snake_case`; privadas com `_` | `_rebuild_cells()` |
| Constantes, enums | `SCREAMING_SNAKE_CASE` / `PascalCase` | `MAX_ENEMIES`, `enum State { IDLE }` |
| Sinais | passado, `snake_case` | `enemy_killed`, `run_ended` |
| Recursos `.tres` | `<id>.tres` com `id: StringName` igual | `data/weapons/assault_rifle.tres` |
| Testes | `tests/test_<sistema>.gd` | `tests/test_spatial_hash.gd` |

Regras: tipagem estática obrigatória (`var hp: int`, `-> void`); ativar nas
Project Settings os avisos `untyped_declaration` e `unsafe_*` como *warning*
(e mais tarde *error*). Um script = uma responsabilidade; acima de ~300
linhas é sinal para dividir.

## 2. Autoloads, event bus e state machine da run

### Autoloads: só três

| Autoload | Responsabilidade | Porquê global |
|---|---|---|
| `Events` | event bus (só sinais, sem estado) | desacopla HUD, áudio, telemetria do gameplay |
| `SaveService` | ler/gravar/migrar o perfil meta | o perfil existe antes e depois de qualquer cena |
| `Telemetry` | acumular eventos da run e escrever JSON | ouve tudo, não pertence a nenhuma cena |

Tudo o resto (horda, diretor, missão, economia da run) é **nó dentro da cena
da ilha ou da run**, criado e destruído com ela. Porquê o mínimo: no original
os autoloads acumularam estado entre cenas (o `RESUME RUN` guardava a
instância em memória) e dificultaram testes; além disso `preload` de scripts
que dependem de autoloads falha a partir de `--script`. Um sistema que é nó
pode ser instanciado sozinho num teste headless.

O estado da run (`RunState`: ilha atual, cartas, Scrap, Intel recolhida, seed)
é um `RefCounted` que pertence ao `RunStateMachine` e é **passado** aos
estados, não um autoload.

### Event bus

`game/core/events.gd` declara sinais tipados e nada mais:

```gdscript
extends Node
signal enemy_killed(enemy_type: StringName, position: Vector3, was_headshot: bool)
signal player_damaged(amount: int, source: StringName)
signal mission_completed(mission_id: StringName)
signal run_state_changed(from: StringName, to: StringName)
```

Regras de uso:
- O bus serve para **notificar** ("aconteceu X"), não para pedir ("faz X").
  Pedidos são chamadas diretas a uma referência conhecida.
- Dentro de uma feature usam-se sinais locais; o bus é para quem está longe
  (HUD, áudio, telemetria, desbloqueios).
- **Não** emitir por inimigo por frame. A horda emite eventos agregados
  (uma morte = um sinal é aceitável; "posição mudou" não é).

### State machine da run

```
MENU ──start──▶ BOAT ──sail──▶ ISLAND ──extract──▶ EXTRACTION ──▶ DEBRIEF ──▶ MENU
                  ▲                │                     │
                  └──next island───┘◀────────────────────┘ (se a run continua)
                       ISLAND ──player died──▶ DEBRIEF
```

- Implementação: `RunStateMachine` (Node em `main.tscn`) com estados como
  classes `RunState*` que implementam `enter(ctx)`, `exit()`, `update(dt)`.
  Transições só via `transition_to(&"boat")`, que valida a tabela acima e
  emite `Events.run_state_changed`.
- Cada estado **carrega e liberta a sua cena** (`ISLAND` instancia a ilha;
  ao sair faz `queue_free` e espera um frame). Nada sobrevive entre estados
  exceto `RunState` e os autoloads — isto ataca diretamente as fugas de
  ObjectDB/recursos ao sair que o original nunca resolveu.
- `EXTRACTION` existe como estado separado porque a regra de risco
  ("extrair cedo com menos") e a gravação da Intel acontecem aí, uma vez.
- Cenas pesadas carregam com `ResourceLoader.load_threaded_request` durante
  o estado `BOAT` (a viagem de barco é a cortina de carregamento).

## 3. Dados em Resources

Dados de design em `.tres` editáveis no inspetor; código nunca tem números
de balanço "mágicos". Todos herdam de `GameData` (`id: StringName`,
`display_name: String`). Campos mínimos:

```gdscript
class_name WeaponData extends GameData
@export var damage: float = 30.0
@export var headshot_multiplier: float = 2.0
@export var fire_rate: float = 8.0            # tiros/s
@export var magazine_size: int = 30
@export var reload_time: float = 1.8
@export var range_m: float = 40.0
@export var spread_deg: float = 1.5
@export var pellets: int = 1
@export var penetration: int = 0              # inimigos atravessados
@export var ammo_kind: StringName = &"infinite"   # infinite | special
@export var behaviors: Array[StringName] = []     # ricochet, burn, explode…
@export var evolves_with_card: StringName = &""

class_name EnemyData extends GameData
@export var max_hp: float = 100.0
@export var speed: float = 3.5
@export var damage: float = 10.0
@export var attack_range: float = 1.2
@export var head_height: float = 1.6           # altura do centro da cabeça
@export var head_radius: float = 0.18
@export var body_radius: float = 0.35
@export var headshot_only_kill: bool = false
@export var is_special: bool = false           # true → cena própria (ver §4)
@export var special_scene: PackedScene
@export var dismember_threshold: float = 0.6   # fração do HP num só golpe
@export var drop_table: Dictionary = {}        # &"scrap": [chance, min, max]
@export var threat_cost: float = 1.0           # orçamento do diretor

class_name CardData extends GameData
@export var rarity: int = 0
@export var max_stacks: int = 1
@export var stat_mods: Dictionary = {}         # &"fire_rate": 0.1 (= +10%)
@export var effect_script: Script              # comportamento (CardEffect)
@export var requires: Array[StringName] = []
@export var tags: Array[StringName] = []

class_name IslandData extends GameData
@export var scene: PackedScene
@export var size_m: Vector2 = Vector2(200, 200)
@export var biome: StringName
@export var allowed_missions: Array[StringName] = []
@export var max_active_enemies: int = 300
@export var base_threat: float = 1.0
@export var flow_cell_size: float = 1.0

class_name MissionData extends GameData
@export var template: StringName               # hold_zone, carry, activate_3…
@export var duration_s: float = 0.0            # 0 = sem relógio
@export var target_count: int = 1
@export var director_profile: StringName = &"default"
@export var reward_scrap: int = 0
@export var reward_intel: int = 0
```

Notas: as cartas "⅔ comportamento" vivem em `effect_script` (subclasse de
`CardEffect` com hooks `on_shot`, `on_kill`, `on_dash`, `on_reload`), não em
`if` espalhados pelo código das armas. Um teste headless carrega todos os
`.tres` de `data/` e valida ids únicos e referências (cartas `requires`,
`evolves_with_card`).

## 4. Horda: 300+ inimigos

Princípio: **um zombie comum não é um nó**. 300 `CharacterBody3D` com
`move_and_slide`, `AnimationTree` e `NavigationAgent3D` custam caro no CPU
(física + scene tree + skinning); no original, a física pesada nos zombies
foi um problema recorrente. Os comuns são **linhas em arrays**; só o que
precisa de física ou IA rica é nó.

### Camadas

```
HordeSim (Node, _physics_process)    dados: arrays paralelos
  ├─ FlowField        direção para o jogador por célula
  ├─ SpatialHash      vizinhança e consultas de tiro
  └─ HordeRenderer    MultiMeshInstance3D por tipo/LOD
Specials (CharacterBody3D)            Screamer, Grabber, Bloater, bosses
```

**Simulação em arrays (SoA)** em `HordeSim`, com capacidade fixa e
free-list (pooling sem alocar):
`PackedVector3Array positions, velocities`; `PackedFloat32Array hp, anim_time`;
`PackedInt32Array type_idx, state, flags` (alive, headless, sem braço…).
Iterar arrays empacotados em GDScript é o caminho mais barato disponível sem
C#/GDExtension; o spike mede se chega (ver §8).

**Flow field** por ilha: grelha 2D (célula ~1 m; ilha de 200 m = 40 000
células) com custo por célula (bake a partir da geometria estática com
raycasts/shape queries de cima para baixo). Dijkstra/BFS a partir da célula
do jogador, **recalculado só quando o jogador muda de célula e no máximo a
~5 Hz**, eventualmente em `WorkerThreadPool`. Cada zombie lê a direção da
sua célula: O(1) por zombie, independente de N. Substitui 300 pedidos de
navmesh. Especiais podem usar `NavigationAgent3D` normal.

**Spatial hash**: grelha uniforme (célula ~2 m) reconstruída por frame
(contagem + prefix sum em `PackedInt32Array`, sem dicionários). Usos:
separação entre zombies (só vizinhos das 9 células), ataque ao jogador,
explosões em área e **hitscan**.

**Movimento e colisão**: velocidade = direção do flow field + separação +
pequeno ruído. Sem física: a altura vem de um heightmap da ilha amostrado
(bake), e paredes estão "dentro" do flow field (células bloqueadas). O
jogador colide com a horda via empurrão por dados (o `HordeSim` afasta-o se
estiver dentro do raio), e o *breaker* (dash) aplica impulso aos zombies no
spatial hash num cone.

**Render**: um `MultiMeshInstance3D` por tipo de inimigo e LOD, com
`use_custom_data` para passar tempo de animação/variação ao shader e
`instance_count` fixo + `visible_instance_count`. Atualizar
`multimesh.buffer` de uma vez (um `PackedFloat32Array`) em vez de
`set_instance_transform` por instância.

**LOD de animação**:

| Distância à câmara | Representação |
|---|---|
| < ~8 m, até ~12 zombies | nó com rig completo (`Skeleton3D` + `AnimationPlayer`), emprestado de um pool; necessário para desmembramento visível e reações |
| 8–35 m | MultiMesh com animação no vertex shader (de início balanço procedural; mais tarde Vertex Animation Textures) |
| > 35 m / fora do frustum | MultiMesh com pose fixa ou não desenhado; a simulação corre a menor frequência (1 em cada 2–4 ticks) |

Na cena de spike tudo isto é primitivas (`CapsuleMesh` + `SphereMesh` para a
cabeça); sem assets externos.

**Onde fica a física (CharacterBody)**: jogador, especiais (≤ ~20 ativos),
bosses, projéteis lentos visíveis e pickups com `Area3D`. Estes registam-se
também no spatial hash (como "proxy") para que o hitscan e as explosões os
encontrem pelo mesmo caminho. ⚠️ Se a decisão de escala for "dezenas de
especiais inteligentes", o mesmo desenho aguenta: aumenta-se o teto de nós
especiais e baixa-se o de comuns.

### Hitscan: headshot vs body shot

Raio do cano até `range_m`:
1. **Mundo**: um `PhysicsRayQueryParameters3D` contra a geometria estática
   dá a distância máxima (o tiro para numa parede).
2. **Horda**: percorrer as células do spatial hash ao longo do raio (DDA
   2D), e para cada zombie testar **duas esferas analíticas**: cabeça
   (`position + up*head_height`, `head_radius`) e corpo (cápsula aproximada
   por esfera/segmento, `body_radius`). Fica com o impacto mais próximo.
   Cabeça → `damage * headshot_multiplier`.
3. **Especiais**: o mesmo teste matemático contra os proxies (ou o raycast
   físico do passo 1, se tiverem `Area3D` de hitbox).
4. `penetration > 0` continua o percurso a partir do impacto.

Isto é matemática pura e testável headless (testes com posições fixas:
"raio a 1,6 m de altura acerta na cabeça; a 1,0 m no corpo; atrás de parede
não acerta"). ⚠️ O peso real do headshot depende da decisão de mira; o
contrato já o suporta com o multiplicador.

### Desmembramento simples

- Flags em `flags[i]`: `NO_HEAD`, `NO_ARM_L`, `NO_ARM_R`. Um golpe que
  excede `dismember_threshold * max_hp` numa região remove-a: headshot forte
  → `NO_HEAD` (morte); body shot forte no lado → braço.
- Render: as partes são **malhas separadas** no MultiMesh (corpo, cabeça,
  braço) — esconder uma parte é pôr escala zero na instância dessa parte. Sem
  cortar malhas em runtime.
- O pedaço que cai é um `RigidBody3D` de um **pool pequeno (~24)** com tempo
  de vida curto; se o pool esgota, reutiliza-se o mais antigo. Gameplay:
  `NO_ARM_*` reduz dano de ataque (dá sentido ao "contra claro").

## 5. Save versionado e telemetria

### Save do perfil (meta)

Ficheiro `user://profile.json` (JSON legível ajuda a depurar; trocar para
binário só se houver razão). Escrita atómica: gravar `profile.json.tmp`,
depois `DirAccess.rename` sobre o original; manter `profile.bak`.

```json
{
  "version": 3,
  "intel": 1240,
  "unlocks": ["weapon:shotgun", "class:medic"],
  "hazard_max": 2,
  "stats": { "runs": 17, "extractions": 6 }
}
```

- **A Intel conserva-se ao morrer**: a Intel ganha numa run é somada ao
  perfil e gravada em `EXTRACTION` **e** em `DEBRIEF` por morte. ⚠️ Se o
  design decidir "morrer perde X% da Intel da run", é uma linha nesse
  ponto; o banco já guardado nunca se perde.
- Recolher Intel durante a run não grava o perfil; grava-se num ponto único
  (fim da run) para evitar estados intermédios. Crash a meio = perde a Intel
  da run atual, nunca o banco.
- **Migrações**: `SaveService.CURRENT_VERSION` e um array ordenado de
  funções `migrate_vN_to_vN+1(data: Dictionary) -> Dictionary` em
  `core/save/migrations/`. Ao carregar: aplicar em cadeia até à versão atual,
  gravar, nunca saltar versões. Save de versão **maior** que a atual → não
  tocar e avisar. Cada migração tem um teste com um JSON fixo de exemplo
  (`tests/fixtures/profile_v1.json` → esperado v2).
- Runs **não** se gravam a meio (decisão de âmbito: evita o problema do
  `RESUME RUN` do original). Proposta abaixo.

### Telemetria por run

`Telemetry` ouve `Events` e escreve `user://telemetry/run_<timestamp>.json`
no fim de cada run (também em morte e ao sair do jogo):

```json
{
  "schema": 1, "build": "0.1.0", "seed": 12345, "hazard": 1,
  "class": "recruit", "loadout": ["assault_rifle"],
  "result": "extracted", "duration_s": 1430,
  "islands": [{ "id": "dawn_beach", "mission": "hold_zone",
               "time_s": 310, "kills": 412, "damage_taken": 230 }],
  "shots": 3100, "hits": 2050, "headshots": 640,
  "ammo_collected": 900, "seconds_without_ammo": 12,
  "cards": ["fire_dash", "explosive_5th"],
  "intel_gained": 85, "scrap_gained": 300,
  "perf": { "fps_p50": 60, "fps_p1": 48, "frame_ms_max": 31.2,
            "max_alive_enemies": 287, "mem_static_mb": 410 }
}
```

Isto alimenta o debrief ("telemetria real") e responde às perguntas que o
original deixou por medir (munição, minutos sem munição, frame time). A
telemetria só agrega contadores; nunca guarda eventos por frame.

## 6. Testes headless

Convenções (as de `CLAUDE.md`): `extends SceneTree`, lógica em
`_initialize()`, imprime `TEST: ...` / `TEST FAIL: ...`, `quit(0|1)` em
todos os caminhos. Usar `load()` em runtime para scripts que dependem de
autoloads.

**Runner único: `tests/run_all.gd`**

```bash
godot --headless --path . --script res://tests/run_all.gd           # todos
godot --headless --path . --script res://tests/run_all.gd -- horde  # filtro
```

- Descobre `res://tests/test_*.gd` e `res://spikes/*/tests/test_*.gd`.
- Corre **cada ficheiro num subprocesso** (`OS.execute` com
  `OS.get_executable_path()`): um teste que crasha, fuga de memória ou deixa
  autoloads sujos não contamina os seguintes.
- Falha se o exit code ≠ 0 **ou** se a saída contém `TEST FAIL` (apanha
  testes que esquecem de devolver 1). Imprime a saída só dos que falham.
- Exit code ≠ 0 se algum falhar ou se não encontrar testes.
- Limite conhecido: `OS.execute` bloqueia; um teste sem `quit()` pendura o
  runner. Em CI, envolver com `timeout 600 godot ...`.

**O que se testa onde**

| Em CI / headless | Só no editor (manual, Windows) |
|---|---|
| Lógica pura: hitscan cabeça/corpo, spatial hash, flow field (caminho contorna obstáculo), desmembramento por limiar | Leitura visual da horda, LOD a "saltar", oclusão |
| Dados: todos os `.tres` carregam, ids únicos, referências válidas | Game feel: hit-stop, knockback, shake, som |
| State machine: transições válidas/ inválidas, cenas libertadas | Câmara média e legibilidade da mira |
| Save: migrações com fixtures, escrita atómica, Intel após morte | Performance real com GPU (ver §7) |
| Cenas instanciam sem erros (smoke) | Comando físico (gamepad) |
| Benchmark de CPU da simulação (imprime ms; não falha por número em CI partilhada) | |

No headless não há GPU: medições de render e VRAM só valem no editor/build.

## 7. Orçamento de performance

Alvo (proposta, a confirmar): **60 FPS estáveis (16,6 ms) em 1080p numa
RX 590**, com **300 comuns vivos + 10 especiais**, cena de ilha completa.
Teto de stress: 500 comuns a ≥ 45 FPS.

| Fatia (por frame, 60 FPS) | Orçamento |
|---|---|
| Simulação da horda (movimento, separação, hash) | ≤ 3 ms |
| Flow field (amortizado) | ≤ 0,5 ms |
| Upload MultiMesh | ≤ 1 ms |
| Física (jogador, especiais, pickups) | ≤ 2 ms |
| Resto do gameplay + UI | ≤ 2 ms |
| Render (GPU) | ≤ 10 ms |
| Draw calls | < 1 500; horda < 50 |
| Memória estática | < 1,5 GB |

Como medir:
- **Monitores em código**: `Performance.get_monitor(TIME_PROCESS,
  TIME_PHYSICS_PROCESS, RENDER_TOTAL_DRAW_CALLS_IN_FRAME, MEMORY_STATIC,
  OBJECT_NODE_COUNT)` + `Time.get_ticks_usec()` à volta de cada passo do
  `HordeSim`. Expor no painel de debug e na telemetria (`perf`).
- **Percentis, não médias**: guardar frame times e reportar p50, p1 (1%
  piores) e máximo; picos de 30 ms estragam mais do que a média revela.
- **Cena de benchmark fixa** (seed fixa, N zombies, jogador a orbitar),
  duração 60 s, mesmo hardware e definições; registar hardware, driver,
  resolução e renderer junto dos números.
- **Bot de soak**: 15–30 min sem reabastecimento artificial, a registar
  memória ao longo do tempo (fugas) e erros. O original tinha um benchmark
  que reabastecia munição e por isso não mediu a economia — não repetir.
- Profiler e Visual Profiler do editor para descobrir *onde*; os números
  oficiais saem da cena de benchmark.

## 8. Riscos técnicos e spikes recomendados

| Risco | Porque preocupa | Spike (pasta) | Pergunta a responder |
|---|---|---|---|
| GDScript lento para iterar 300–500 zombies | Pode estourar os 3 ms | `horde_sim_bench` | ms/frame para N = 100/300/500/1000 com separação; fica abaixo do orçamento? Senão, avaliar GDExtension/C# (decisão do utilizador) |
| Flow field em terreno com desnível, pontes e falésias | Zombies presos ou a atravessar paredes | `flow_field` | custo de rebuild 200×200; contorna obstáculos; como representar rampas |
| Hitscan contra dados não bate certo com o que se vê | Headshots "roubados" | `hitscan_horde` | precisão cabeça/corpo vs modelo animado no shader; custo por tiro com 300 alvos |
| MultiMesh + animação no shader | Horda rígida e feia, ou cara | `multimesh_lod` | draw calls e ms de GPU na RX 590; transição rig ↔ MultiMesh sem "pop" |
| Desmembramento com partes separadas | Multiplica instâncias | dentro de `multimesh_lod` | custo de 3 partes por zombie |
| Câmara média esconde a horda atrás | Mortes injustas | `camera_medium` (já previsto) | parâmetros; pistas de borda do ecrã |
| Fugas ao trocar de cena | O original tinha ObjectDB/recursos por libertar ao sair | `scene_lifecycle` | 50 ciclos boat ↔ island sem crescer memória nem avisos de fuga |
| Save corrompido / migrações | Perder progresso mata a confiança | testes em `tests/` (não precisa spike) | migrações em cadeia com fixtures |

Ordem sugerida: `horde_sim_bench` → `hitscan_horde` → `flow_field` →
`multimesh_lod`. O primeiro decide se o resto da arquitetura da horda se
mantém em GDScript.

## Decisões propostas

Para o utilizador decidir (não estão em `DECISIONS.md`):

1. Autoloads limitados a `Events`, `SaveService`, `Telemetry`.
2. Zombies comuns como dados (arrays + flow field + MultiMesh); só especiais
   e jogador com `CharacterBody3D`.
3. Sem gravação a meio da run; o perfil meta grava-se só no fim da run.
4. A Intel acumulada nunca se perde; a regra para a Intel *da run* em caso de
   morte (toda/parte) fica para o design.
5. Orçamento: 60 FPS em 1080p na RX 590 com 300 comuns + 10 especiais.
6. Se o spike `horde_sim_bench` falhar o orçamento, considerar GDExtension
   (C++) apenas para o `HordeSim`, mantendo o resto em GDScript.
