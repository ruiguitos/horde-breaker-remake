# Mudar de motor? Avaliação (2026-10-18)

Estado: **proposta**. Nenhuma decisão tomada. A recomendação está na secção 5 e
fica registada em `docs/DECISIONS.md` só quando o utilizador a aprovar.

Feita por uma leitura do repositório e por uma consulta de leitura ao Codex
(sem edições, sem testes, sem benchmarks). Os números são de contagem de linhas
e ficheiros, não de esforço medido.

## 1. O que existe hoje

| Parte | Tamanho | Motor |
|---|---:|---|
| Regras de jogo (`island_run.gd`) | 3 873 linhas | Estado e algoritmos, **sem nós** |
| Horda (`horde.gd`, `flow_field.gd`) | 625 linhas | Arrays, espaço de hash, BFS. Quase sem Godot |
| Diretor, cartas, power-ups | 365 linhas | Pequenos; tipos e dados ligados ao Godot |
| Cena e interface (`island.gd`, `hud.gd`, menus) | ~7 000 linhas | Nós, câmaras, input, UI |
| Dados (`.tres`) | 111 ficheiros | Recursos do Godot |
| Testes | 54 ficheiros | `SceneTree`, carregamento de recursos |
| Addons | 10 pastas | Terrain3D, Sky3D, Phantom Camera, Color grading (compositor), dialogue_manager, guide, yard, road-generator, GD-Sync (desligado), boot_splash_plus |
| Modelos e texturas | GLB do Blender, Poly Haven, Quaternius, OSM | Portáveis em formato; importação e materiais não |

Total: **26 231 linhas de GDScript em 77 ficheiros**.

O ponto que mais conta: a parte de regras (`island_run.gd`, horda, diretor,
cartas) não depende de nós. O que depende do Godot é a cena, a câmara, o
terreno, o céu, a composição, a UI, o input e a importação dos recursos.

## 2. Portabilidade, por parte

- **Transfere bem:** regras, horda (com os algoritmos iguais), diretor, cartas,
  power-ups, dados (valores e esquemas), testes (asserções e cenários).
- **Reescreve-se:** `SceneTree` e o executor de testes, a carga de recursos, o
  MultiMesh, os shaders, o input, a UI, o terreno (Terrain3D), o céu (Sky3D), a
  composição de cor e a pipeline de importação dos GLB.
- **Conversão:** os `.res` das texturas e os `.tres` (exportar para JSON
  versionado é o caminho).

## 3. Opções, com o esforço de ordem de grandeza

Estimativas do Codex, para recuperar a funcionalidade atual, em
dedicação concentrada. Um principiante a tempo parcial demora muito mais.

| Opção | Esforço | O que se perde | Encaixe |
|---|---|---|---|
| Ficar no Godot 4.7.2 | nenhum | nada | o melhor para este jogo |
| Godot 4.x mais recente | 1 a 5 dias para avaliar; semanas se os addons partirem | pouco; validar addons e exportação | bom, numa cópia à parte |
| Unity (C#) | 3 a 9+ meses | Terrain3D, Sky3D, grading, testes | razoável se C# for objetivo |
| Unreal (C++/Blueprints) | 6 a 12+ meses | addons e harness | capaz, mas complexo para este âmbito |
| Bevy (Rust) | 6 a 18+ meses | todos os addons e os testes executáveis | bom para aprender Rust, caro para acabar este jogo |
| Motor próprio sobre uma biblioteca | 12 a 24+ meses | tudo | só se construir o motor for o objetivo |

Todas as opções fora do Godot perdem a integração com Terrain3D e Sky3D, a
composição de cor e o harness de testes. Essas partes podem ser recriadas, mas
custam trabalho e validação.

## 4. Análise própria

- **O custo não está na linguagem.** Um motor novo não resolve um gargalo que
  ainda não foi medido. A auditoria de 17 de outubro já separa benchmarks de
  arte e jogo completo. Antes de mudar de motor, falta medir o jogo completo.
- **A arquitetura já separa regras e apresentação.** Isso reduz o custo de uma
  migração, mas não o elimina: as regras ainda usam tipos e dados do Godot
  (`GameData` carrega recursos internamente).
- **O risco maior é a cauda, não a média.** Os 150–300 inimigos, o boss e os
  efeitos juntos ainda não têm medições de FPS p95/p99 em jogo completo.
- **O que mais avança o jogo** é o trabalho que já está em curso: animações
  realistas das armas, o braço em primeira pessoa e a validação a jogar. Essas
  tarefas são iguais em qualquer motor.

## 5. Recomendação

**Ficar no Godot e medir o jogo completo antes de qualquer decisão de motor.**

Experiência barata que responde à pergunta, por ordem:

1. Gravar um percurso repetível por uma ilha exigente, com 150 e 300 inimigos,
   boss, elementos, terreno e HUD.
2. Medir CPU e GPU (média, p95, p99), memória e pausas de carregamento, nas três
   câmaras, com resolução e preset fixos, na RTX 5060.
3. Otimizar o gargalo medido. Se for a simulação, testar uma extensão nativa
   limitada (GDExtension) antes de trocar de motor.

Se a curiosidade por outro motor se mantiver, uma experiência de **dois dias**:
traduzir o `flow_field.gd` (224 linhas) para C# standalone, com fixtures de
grelha bloqueada e distâncias esperadas. Mede o esforço de tradução e o conforto
com a linguagem. **Não** mede desempenho de render nem o custo de migrar o jogo.

## 6. Trabalho que vale a pena em qualquer motor

- **Já cumprido:** regras sem nós; horda orientada a dados; passos de tempo
  explícitos; RNG com semente; saves JSON versionados.
- **Fortalecer:** passar snapshots de dados às regras em vez de deixar
  `GameData` carregar recursos; exportar o conteúdo para JSON versionado
  (valores, IDs, referências, unidades, enums, terreno, marcadores).
- **Fixtures de referência:** navegação, combate, cartas e saves com sementes
  fixas. Sementes iguais em motores diferentes não dão sequências aleatórias
  iguais; os fixtures servem para comparar resultados, não sequências.
- **Dividir `IslandRun` aos poucos:** missões e combate em módulos próprios, sem
  reescrever tudo para uma abstração que pode nunca ser precisa.

## 7. Riscos encontrados na revisão, e o que foi feito

| Risco (Codex) | Verificação | Estado |
|---|---|---|
| O boss ultrapassa o teto em um | Confirmado: `_spawn_boss` não verifica `max_alive` | **Documentado como exceção** (GameData.HORDE_CAP, IslandRun._spawn_boss) e testado (`test_boss_spawn`). Remover outro inimigo para abrir espaço mudaria índices que `_dead` pode ainda guardar |
| O executor aceita execução parcial e saída vazia | Confirmado: saída vazia com código 0 passava | **Corrigido**: silêncio já não passa (`test_run_all`, 10 verificações). A aceitação de códigos de saída do Windows ainda depende de uma linha `TEST:`, sem marcador de fim |
| O executor não tem timeout | Confirmado: `OS.execute` é bloqueante | **Por fazer**: `OS.execute_with_pipe` não devolve o código de saída; um timeout real exige um supervisor à parte |
| Camadas de MultiMesh de reserva por inimigo | Confirmado: as reservas da ilha nunca eram visíveis (a vista de zombies trata os oito tipos) | **Removido** (variáveis, configuração e ciclo por inimigo); ~4 escritas por inimigo por frame deixaram de existir |
| Identidade dos cadáveres por vizinhança | Confirmado: procura do zombie desenhado mais perto, dentro de 1,5 m | **Corrigido**: a morte guarda a semente do zombie (`IslandRun.death_keys`) e o cadáver reconstrói a aparência dessa semente. Listas de frames anteriores removidas |

Efeito das correções: os testes afetados passam (`test_special_models` 51,
`test_zombie_model` 53, `test_death_cause` 4, `test_island_run` 80,
`test_crawlers` 57, `test_expedition` 1, `test_boss_spawn` 3, `test_run_all`
10). A suite completa corre antes do commit.

## 8. Proposta de decisão (para o utilizador)

> **Proposta:** manter o Godot 4.7 como motor. Antes de qualquer mudança de
> motor, medir o jogo completo com um percurso repetível (secção 5).

Se aprovares, regista-se em `DECISIONS.md` com a data e atualizam-se os
documentos afetados. Sem aprovação, o estado fica como está.
