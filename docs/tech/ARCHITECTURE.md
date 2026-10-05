# Arquitetura técnica do remake

Estado: **proposta** (pré-produção). Godot 4.7 stable, GDScript tipado, Forward+.
Este documento descreve *como* o jogo vai ser construído, independentemente da
direção de design que vier a ser escolhida (A, B, C ou mistura — ver
`docs/DECISIONS.md`, "Em aberto"). Onde a arquitetura depende de uma decisão
em aberto, isso está assinalado e há uma proposta na secção
[Decisões propostas](#decisões-propostas).

Princípios, todos derivados das lições do original (`docs/legacy/PROJECT_AUDIT.md`):

- **Medir antes de afirmar.** Nenhuma escolha de performance entra em `game/`
  sem um spike que a meça em cena real.
- **Poucos sistemas globais.** Autoloads e singletons escondem dependências e
  dificultam testes e o fecho limpo do jogo (o original saía com ObjectDB e
  recursos por libertar).
- **Dados separados de comportamento.** Balanceamento em Resources `.tres`,
  editáveis no inspector e testáveis sem cena.
- **Cada sistema serve um pilar.** Se um sistema não tem pilar, não é criado.

---

## 1. Estrutura de pastas de `game/` e convenções

```
game/
  main.tscn / main.gd        cena raiz: troca de estados da run
  autoload/                  os únicos autoloads (secção 2)
  core/                      código sem cena: state machine, save, telemetria, utils
  data/                      definições de Resource (scripts) — *_data.gd
    weapons/ enemies/ cards/ islands/ missions/   instâncias .tres
  states/                    uma cena por estado da run (menu, boat, island, extraction, debrief)
  player/                    personagem, câmara média, input
  weapons/                   disparo, hitscan, recoil, munição
  horde/                     simulação de inimigos, flow field, spatial hash, render
  world/                     ilhas, spawners, objetivos, extração
  ui/                        HUD, menus, debrief
  debug/                     painel de debug, overlays, bot de soak (fora do build final)
```

Regra: uma pasta por *sistema*, não por *tipo de ficheiro*. Cena, script e
recursos de um sistema vivem juntos; só `data/` é transversal.

**Convenções de nomes**

| Coisa | Convenção | Exemplo |
|---|---|---|
| Ficheiros e pastas | `snake_case` | `flow_field.gd`, `dawn_beach.tscn` |
| `class_name` | `PascalCase`, só quando outro script precisa do tipo | `HordeSim`, `WeaponData` |
| Resources de dados | sufixo `Data`, ficheiro `*_data.gd` | `EnemyData` |
| Instâncias `.tres` | `<tipo>_<id>.tres` | `weapon_rifle.tres` |
| Sinais | verbo no passado | `enemy_killed`, `run_ended` |
| Constantes / enums | `UPPER_SNAKE` / `PascalCase` | `MAX_ENEMIES`, `enum RunState` |
| Membros privados | prefixo `_` | `_positions` |
| Testes | `tests/test_<sistema>.gd` | `tests/test_save_migration.gd` |

GDScript **sempre tipado** (`var hp: int`, `-> void`, `Array[EnemyData]`,
`PackedVector3Array`). Ativar nas Project Settings os avisos
`untyped_declaration` e `unsafe_*` como *warning* (ou *error* quando estável):
o tipado apanha erros cedo e é mais rápido em GDScript.

## 2. Autoloads, event bus e state machine da run

### Autoloads (três, no máximo)

| Autoload | Responsabilidade | Porquê global |
|---|---|---|
| `Events` | event bus: só declara sinais | desacopla UI/telemetria/áudio da lógica |
| `Save` | carregar/gravar perfil + migrações | o perfil sobrevive a todas as cenas |
| `Telemetry` | registar eventos da run e escrever JSON | precisa de existir antes e depois da ilha |

Tudo o resto (horda, jogador, armas, missão) **pertence à cena do estado**
e morre com ela. Assim, sair da ilha liberta tudo de uma vez e os testes podem
instanciar um sistema sem arrancar o jogo inteiro.

Cuidados conhecidos (lição do original): `preload` de scripts que referem
autoloads falha quando se corre com `--script`; nesses casos usar `load()` em
runtime, ou injetar a dependência. Os autoloads não guardam referências a
nós de cenas (evita fugas ao sair).

### Event bus

`Events` é um ficheiro só com sinais tipados:

```gdscript
extends Node
signal enemy_killed(enemy_id: int, data: EnemyData, headshot: bool)
signal player_damaged(amount: int, source: StringName)
signal objective_completed(objective_id: StringName)
signal run_state_changed(from: int, to: int)
```

Regra de uso: o bus serve para **notificações entre sistemas que não se
conhecem** (HUD, áudio, telemetria). Chamadas entre um sistema e os seus
filhos são diretas. Não emitir por inimigo por frame — eventos de alta
frequência (por ex. dano) agregam-se e emitem-se uma vez por frame.

### State machine da run

```
MENU ──start──▶ BOAT ──land──▶ ISLAND ──reach_extraction──▶ EXTRACTION ──success──▶ DEBRIEF ──▶ MENU/BOAT
                                  │                              │
                                  └──────────── death ───────────┴─────────────────▶ DEBRIEF
```

- Implementação: `core/run_state_machine.gd` (classe simples, não autoload)
  dentro de `main.gd`. Cada estado é uma **cena** em `states/`; trocar de
  estado = libertar a cena anterior (`queue_free`) e instanciar a próxima.
- Transições válidas numa tabela; uma transição inválida é erro (`push_error`)
  e é testada headless.
- `RunContext` (RefCounted) atravessa os estados: missão escolhida, loadout,
  cartas, seed, estatísticas. Termina no debrief, que decide o que passa para
  o perfil (Intel) e fecha a telemetria.
- `BOAT` é o hub entre ilhas (loadout, escolha de missão). Se a decisão sobre
  "base" (DECISIONS, ponto 4) for "nenhuma", o estado fica reduzido a um menu.

## 3. Dados em Resources

Scripts em `game/data/`, instâncias `.tres` nas subpastas. Campos mínimos;
acrescentar só quando um sistema os usar.

```gdscript
class_name WeaponData extends Resource
@export var id: StringName
@export var display_name: String
@export var damage: float = 20.0
@export var headshot_multiplier: float = 2.0
@export var fire_rate: float = 8.0          # tiros/s
@export var magazine_size: int = 30
@export var reload_time: float = 1.8
@export var spread_deg: float = 1.5
@export var range_m: float = 60.0
@export var pellets: int = 1                 # >1 = caçadeira
@export var penetration: int = 0             # inimigos atravessados
@export var dismember_chance: float = 0.2

class_name EnemyData extends Resource
@export var id: StringName
@export var max_hp: float = 50.0
@export var speed: float = 3.0
@export var damage: float = 10.0
@export var attack_range: float = 1.2
@export var radius: float = 0.4              # separação e colisão
@export var head_height: float = 1.6         # centro da cabeça, para headshot
@export var head_radius: float = 0.15
@export var is_special: bool = false         # especiais = nós completos (secção 4)
@export var mesh: Mesh
@export var threat_cost: int = 1             # orçamento do spawner

class_name CardData extends Resource
@export var id: StringName
@export var title: String
@export_multiline var description: String
@export var rarity: int = 0
@export var max_stacks: int = 1
@export var modifiers: Dictionary[StringName, float] = {}   # "damage_mult": 1.1

class_name IslandData extends Resource
@export var id: StringName
@export var scene: PackedScene
@export var difficulty: int = 1
@export var enemy_pool: Array[EnemyData] = []
@export var max_alive: int = 300
@export var spawn_budget_per_min: int = 120

class_name MissionData extends Resource
@export var id: StringName
@export var island: IslandData
@export var objective_type: StringName      # "retrieve", "hold", "destroy"
@export var time_limit_s: float = 0.0       # 0 = sem limite
@export var intel_reward: int = 10
```

Porquê Resources: editáveis no inspector, diffs legíveis em `.tres`, e um
teste pode carregar todos e validar (ids únicos, valores positivos) sem cena.
Regra: **Resources de dados são só-leitura em runtime**; estado mutável
(HP atual, munição) vive nos sistemas. Se for preciso alterar, `duplicate()`.

## 4. Horda: 300+ inimigos

A decisão de escala está em aberto (DECISIONS, ponto 3). A arquitetura abaixo
serve "centenas" e degrada bem para "dezenas"; o custo de a adotar é baixo
se for desenhada desde o início, e alto se for retrofitada (o original usou um
nó com física por zombie e ficou preso).

### Princípio: inimigos são dados, não nós

`HordeSim` (um `Node3D` por ilha) guarda **Structure of Arrays**:

```gdscript
var positions: PackedVector3Array
var velocities: PackedVector3Array
var hp: PackedFloat32Array
var state: PackedByteArray          # IDLE, CHASE, ATTACK, DYING, DEAD
var data_index: PackedInt32Array    # índice em enemy_types: Array[EnemyData]
var limb_mask: PackedByteArray      # bits: braço E/D, cabeça (desmembramento)
var alive_count: int
```

- Pool de capacidade fixa (`max_alive`); morrer = trocar com o último vivo
  (swap-remove), sem alocações durante a run.
- Um único `_physics_process` atualiza todos: lê direção do flow field, aplica
  separação via spatial hash, integra posição, resolve ataques.
- Sem `CharacterBody3D` por zombie, sem `NavigationAgent3D` por zombie.

### Flow field

- Grelha 2D por ilha (célula ~1 m) com custos (terreno, obstáculos, água =
  intransitável). Construída no carregamento por raycasts/shape queries
  contra a física estática (medir na cena real, não nos assets).
- Dijkstra/BFS a partir da célula do jogador; recalculado quando o jogador
  muda de célula, **repartido por vários frames** (orçamento de µs por frame)
  e limitado a um raio útil à volta do jogador.
- Altura do chão por célula guardada na grelha → zombies fazem *grounding*
  por amostragem, sem física.
- Alternativa se o terreno for muito vertical: `NavigationServer3D` para
  rotas macro + flow field local. Decidir no spike `horde_sim`.

### Spatial hash

- Grelha uniforme (célula ≈ 2× raio maior), reconstruída por frame com
  counting sort (`cell_start`/`cell_items` em `PackedInt32Array`).
- Usos: separação entre vizinhos, ataques corpo-a-corpo, **hitscan**, áreas
  de efeito, consulta "inimigos perto do jogador".

### Hitscan, headshot vs body shot

1. Raio da arma: primeiro `PhysicsDirectSpaceState3D.intersect_ray` contra o
   **mundo** (paredes) → distância máxima `t_world`.
2. Percorrer as células do spatial hash ao longo do raio (DDA 2D) até
   `t_world`; testar cada inimigo como **duas formas analíticas**: esfera da
   cabeça (`head_height`, `head_radius`) e cápsula do corpo. Fica o impacto
   mais próximo; cabeça aplica `headshot_multiplier`.
3. `penetration > 0` continua o raio pelos próximos inimigos.
4. Especiais (nós completos) têm colisão física normal e entram no passo 1.

Testável headless: raio + array de posições → resultado esperado (cabeça,
corpo, falha, bloqueado por parede).

### Desmembramento simples

- Ao morrer (ou com `dismember_chance` num impacto forte), define-se um bit em
  `limb_mask`. O render escolhe uma variante de mesh sem esse membro (poucas
  combinações: inteiro / sem cabeça / sem braço) — cada variante é um
  MultiMesh próprio.
- O membro solto é um `RigidBody3D` de um **pool pequeno** (p. ex. 16), com
  tempo de vida curto e sem colisão com outros inimigos. Quando o pool
  esgota, recicla-se o mais antigo. Cadáveres: decalque/mesh estática barata
  com limite global, depois fade.

### Render e LOD de animação

| Distância | Representação | Animação |
|---|---|---|
| perto (≤ N mais próximos, p. ex. 12) | `Skeleton3D` + `AnimationTree` de um pool | completa |
| média | `MultiMeshInstance3D` | Vertex Animation Texture (shader), ou bob/inclinação procedural no início |
| longe | mesmo MultiMesh, mesh de baixo LOD | animação a meia frequência / estática |

- Uma `MultiMeshInstance3D` por (tipo de inimigo × variante de membro);
  `instance_count` fixo, `visible_instance_count` = vivos; buffer escrito de
  uma vez com `multimesh.buffer = PackedFloat32Array` (evita milhares de
  chamadas `set_instance_transform`).
- Fase de animação e tipo de clipe passados por `custom_data`.
- Sem assets externos nesta fase: `CapsuleMesh`/`BoxMesh` combinados, VAT
  gerada por ferramenta própria quando houver modelos.

### Onde fica a física

| Entidade | Nó |
|---|---|
| Jogador | `CharacterBody3D` |
| Especiais (dezenas no máximo) | `CharacterBody3D` + `NavigationAgent3D` |
| Horda comum | dados em `HordeSim`, sem corpo |
| Mundo | `StaticBody3D` (colisões simples, não trimesh do terreno inteiro) |
| Membros soltos, props | `RigidBody3D` em pool |

O jogador colide com a horda via spatial hash (empurrão calculado), não com
corpos físicos. Lição do original: não reativar física pesada de terreno
para zombies.

### Se a GDScript não chegar

Ordem: (1) otimizar GDScript (tipos, Packed arrays, menos chamadas), (2)
atualizar a horda a frequência reduzida para os longe (time slicing), (3)
mover o *hot loop* para GDExtension (C++). C# está fora por decisão atual.

## 5. Save versionado e telemetria

### Save

- Ficheiro `user://profile.json` (JSON legível; fácil de inspecionar e de
  migrar). Escrita atómica: gravar `profile.json.tmp`, depois
  `DirAccess.rename` — evita perfis corrompidos se o jogo crashar a gravar.
  Manter `profile.bak` da versão anterior.
- Formato:

```json
{ "version": 2, "intel": 140, "unlocks": ["weapon_smg"], "stats": {"runs": 12, "deaths": 9},
  "settings": {"mouse_sensitivity": 1.0} }
```

- Migrações em `core/save_migrations.gd`: uma função por salto de versão,
  aplicadas em cadeia (`v1→v2→v3`). Nunca editar uma migração publicada;
  acrescentar nova. Versão desconhecida (maior que a atual) → não sobrescrever,
  avisar.
- **Meta:** só o que está no perfil sobrevive. **Intel conserva-se ao morrer**
  (o debrief soma a Intel recolhida independentemente do resultado). Recursos
  da run (munição, cartas, scrap) vivem em `RunContext` e perdem-se.
- Grava-se em pontos seguros: fim do debrief, alteração de settings. Não
  durante o combate.

### Telemetria por run

- `Telemetry` acumula eventos em memória e escreve
  `user://telemetry/run_<timestamp>_<seed>.json` no debrief (ou ao fechar o
  jogo, marcando `"aborted": true`).
- Conteúdo: versão do jogo, seed, missão, loadout, duração, resultado,
  disparos/acertos/headshots, mortes por tipo, dano recebido por fonte, munição
  recolhida, minutos sem munição, cartas escolhidas, e amostras de
  desempenho a cada 5 s (fps, frame time p50/p99, vivos, memória estática).
- Agregações por frame ficam em contadores; só eventos raros vão para a
  lista. Responde às perguntas que o original não conseguia responder (a
  economia de munição era avaliada com reabastecimento artificial).
- Ferramenta futura: script que resume N ficheiros de telemetria.

## 6. Testes headless

### Convenções

- Ficheiros `tests/test_<sistema>.gd` (jogo) e
  `spikes/<nome>/tests/test_<t>.gd` (spikes).
- `extends SceneTree`, lógica em `_initialize()`, imprime `TEST: ...` por
  verificação e `TEST FAIL: ...` por falha, `quit(0|1)` em **todos** os
  caminhos.
- Determinismo: seed fixa (`seed()` / `RandomNumberGenerator.seed`), sem
  dependência do relógio real; simular N passos chamando a função de update
  diretamente com `delta` fixo.
- Libertar o que se cria (`free()`), para os logs de saída ficarem limpos de
  ObjectDB/recursos por libertar — um log sujo é tratado como defeito.

### Runner único: `tests/run_all.gd`

```bash
godot --headless --path . --script res://tests/run_all.gd                    # tudo
godot --headless --path . --script res://tests/run_all.gd -- --filter=horde  # subconjunto
```

- Descobre `tests/test_*.gd` e `spikes/*/tests/test_*.gd` e corre cada um num
  **subprocesso** (`OS.execute` com `OS.get_executable_path()`). Porquê:
  isolamento — um crash ou estado global de um teste não contamina os outros,
  e cada teste corre como na linha de comandos.
- Um teste falha se o exit code ≠ 0 **ou** se imprimir `TEST FAIL`. O runner
  mostra o output dos testes falhados e devolve exit code 1 se algum falhar
  (ou se não houver testes).
- Limite conhecido: `OS.execute` bloqueante não tem timeout; um teste sem
  `quit()` pendura o runner. Em CI, envolver com `timeout` do sistema.
- Antes de correr testes depois de criar `class_name` novos:
  `godot --headless --path . --import`.

### O que se testa onde

| Em CI / headless | No editor (Windows, pelo utilizador) |
|---|---|
| Carregamento de cenas (smoke) | Sensação da câmara, mira, recoil |
| Validação de todos os `.tres` (ids únicos, ranges) | Leitura visual da horda e do desmembramento |
| State machine: transições válidas/inválidas | FPS real em GPU (RX 590) e VRAM |
| Save: round-trip e cada migração com fixtures antigos | Áudio, UI, legibilidade do HUD |
| Hitscan: cabeça/corpo/parede com casos fixos | Stutter de shaders/compilação |
| Flow field: caminho em mapas pequenos conhecidos | Playtest com perguntas definidas |
| Benchmarks de CPU da simulação (números, não pass/fail rígido) | Sessões longas (soak) com telemetria |

A cloud não tem GPU: nunca concluir nada sobre aspeto ou FPS de render a
partir do headless.

## 7. Orçamento de performance e como medir

Alvo proposto (a confirmar com o utilizador): **60 FPS (16,6 ms) a 1080p na
RX 590**, com **300 inimigos vivos** na ilha mais pesada.

| Sistema | Orçamento por frame (CPU) |
|---|---|
| Simulação da horda (300) | ≤ 2,0 ms |
| Flow field (repartido) | ≤ 0,5 ms |
| Spatial hash rebuild | ≤ 0,3 ms |
| Hitscan (pior caso: caçadeira, 8 pellets) | ≤ 0,3 ms |
| Upload MultiMesh | ≤ 0,5 ms |
| Jogador, especiais, UI, script restante | ≤ 3 ms |
| Render (GPU) | ≤ 10 ms; draw calls < 1 500 |
| Memória | sem crescimento ao longo de 30 min (soak) |

Como medir:

- **Headless (CI/cloud):** benchmarks que corram a simulação N frames com
  `delta` fixo e imprimam média, p99 e máximo em ms com
  `Time.get_ticks_usec()`. Só CPU; registar a máquina no README do spike.
- **Editor/jogo (Windows):** Monitores do Godot (`Performance.get_monitor`:
  `TIME_PROCESS`, `TIME_PHYSICS_PROCESS`, `RENDER_TOTAL_DRAW_CALLS_IN_FRAME`,
  `MEMORY_STATIC`), o Profiler e o painel de debug próprio; telemetria
  de 5 em 5 s no JSON.
- **Soak:** bot que joga sozinho (anda em círculo, dispara ao mais próximo)
  durante 30 min com a mesma seed, sem reabastecimento artificial; comparar
  memória inicial/final e contar erros no log.
- Comparar sempre com o mesmo hardware, renderer, resolução e definições;
  medições de máquinas diferentes não são uma baseline única (lição do
  `PROGRESS.md` original).

## 8. Riscos técnicos e spikes recomendados

| Risco | Impacto | Spike | Critério de sucesso |
|---|---|---|---|
| GDScript lento para 300+ inimigos | escala da horda | `horde_sim` | 300 inimigos ≤ 2 ms CPU headless; curva para 100/300/600/1000 |
| MultiMesh + animação sem bones convincente | leitura da horda | `horde_render` | 300 instâncias animadas com primitivas, 60 FPS na RX 590 (medido pelo utilizador) |
| Flow field em terreno vertical/edifícios | navegação (P0 do original) | `flow_field` | inimigos contornam obstáculos numa ilha de teste; custo de recálculo medido |
| Hitscan analítico diverge do visual | sensação de tiro | `hitscan_hash` | casos de teste cabeça/corpo/parede; verificação visual no editor |
| Câmara média e mira | identidade (decidida) | `camera_medium` (já previsto) | parâmetros aprovados pelo utilizador |
| Crashes/fugas em sessões longas | estabilidade (P0 do original) | `soak_bot` | 30 min sem erros, memória estável, saída sem ObjectDB pendente |
| Migrações de save partidas | perda de progresso | testado em `tests/`, sem spike | round-trip + fixtures de cada versão |
| Desmembramento caro (rigid bodies) | performance em picos | dentro de `horde_render` | pool fixo, sem quedas em 50 mortes/s |

Ordem sugerida: `horde_sim` → `flow_field` → `hitscan_hash` → `horde_render`
→ `soak_bot`. Os três primeiros correm e medem-se em headless; os últimos
precisam de validação do utilizador no Windows.

## Decisões propostas

O utilizador decide; nada disto está em `docs/DECISIONS.md`.

1. Três autoloads no máximo: `Events`, `Save`, `Telemetry`.
2. Horda comum como dados (SoA) + flow field + spatial hash + MultiMesh;
   especiais como nós completos.
3. Hitscan analítico com esfera da cabeça + cápsula do corpo.
4. Save em JSON com versão e migrações em cadeia; Intel conserva-se ao morrer.
5. Orçamento: 60 FPS a 1080p na RX 590 com 300 inimigos vivos.
6. Fallback de performance: GDExtension C++ para o hot loop, antes de C#.
