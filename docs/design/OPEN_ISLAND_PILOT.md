# Piloto da ilha aberta — `beach_01` a 512 × 512 m

Plano escrito a 2026-11-15, a partir da decisão do utilizador do mesmo dia
(`docs/DECISIONS.md`): ilhas abertas, com piloto na `beach_01` a 512 × 512 m, uma missão
principal e 2 a 3 opcionais, e a extração aberta quando a principal acaba. As Berlengas
ficam como estão. Só se alarga às outras ilhas se o piloto resultar. Lista ativa: `TODO.md`.

## Porquê

A análise de 2026-11-04 apontou a decisão como o elo mais fraco do jogo (pilar P2): hoje,
dentro de uma ilha, não há nada para escolher. Uma ilha maior com missões opcionais dá ao
jogador uma pergunta a cada momento: vou àquele objetivo antes de extrair, ou saio já?

## O que muda para o jogador

- A ilha tem quatro vezes a área. A pé, de ponta a ponta, são cerca de 85 s a 6 m/s.
- A **missão principal** é a de hoje, sorteada pela rota. Acabá-la abre a extração.
- As **missões secundárias** são 2 ou 3 por ilha, marcadas no minimapa desde o início, todas
  opcionais. Cada uma dá uma recompensa que se vê antes de ir: Intel, uma carta, ou mantimentos
  (vida e munição).
- **Risco:** a horda não espera. Quanto mais tempo na ilha, mais o diretor aperta, como hoje.
  Morrer perde o bónus de extração, como hoje.
- A extração continua no barco. Pode-se extrair logo que a principal acabe, ou depois.

## Missões secundárias do piloto

Todas reaproveitam mecânicas que já existem; nenhum sistema de combate novo.

| Secundária | Mecânica de origem | Recompensa proposta (a afinar a jogar) |
|---|---|---|
| Esconderijo de Intel | caixas (`_open_cache`) e Intel Search | +Intel |
| Sobrevivente perdido | Rescue | uma carta grátis no barco |
| Ninho | Nests (um só ninho) | mantimentos: vida e munição cheias |

A principal nunca repete a mecânica de uma secundária na mesma ilha.

## Estado

- **Etapa 1 feita (2026-11-15).** `game/world/side_task.gd` (classe `SideTask`), lista
  `IslandRun.side_tasks`, um esconderijo de Intel sorteado entre dois marcadores `Side_Cache_*` da
  `beach_01` atual, anel dourado no mundo, Intel no total da ilha e no `island_log`
  (`side_tasks`, `side_done`). Teste: `tests/test_side_tasks.gd`. Valores provisórios em
  `game/data/game_data.gd` (`SIDE_TASK_RADIUS` 3 m, `SIDE_CACHE_SECONDS` 4 s,
  `SIDE_CACHE_INTEL` 25). A fixture da praia ganhou os dois marcadores novos; os antigos
  continuam todos verificados.
- **Etapa 2 feita (2026-11-15).** O HUD mostra, por baixo do objetivo e dentro da mesma placa,
  uma linha por secundária: «OPTIONAL · INTEL STASH · +25 INTEL · 111 m», os segundos enquanto
  se trabalha nela e um visto quando acaba. O minimapa marca-a com um losango dourado e põe
  OPTIONAL na legenda. O ecrã de fim de ilha e o debrief contam as secundárias feitas. Captura:
  `docs/design/open_island_pilot/stage2_hud.png`. Testes no mesmo `tests/test_side_tasks.gd`.
- **Etapa 3 feita (2026-11-15).** Duas secundárias novas na `beach_01` atual, cada uma sorteada
  entre dois marcadores: **sobrevivente perdido** (`Side_Survivor_*`, 3 s ao lado dele; dá uma
  carta para escolher logo ali, e não no barco, como o plano dizia, porque usa o mecanismo de
  cartas que já existe) e **ninho** (`Side_Nest_*`, 8 s a armar a carga; o primeiro momento chama
  um pico da horda de 12 s; dá vida e munição cheias). A ilha tem agora três secundárias. Uma
  missão principal com a mesma mecânica tira a secundária correspondente (`side_kinds_left_out`):
  Rescue e Escort tiram o sobrevivente, Nests tira o ninho, Intel Search tira o esconderijo.
- **Etapa 4, primeira passagem (2026-11-15).** A `beach_01` foi reconstruída a 512 × 512 m (quatro
  regiões de Terrain3D). O gerador (`tools/dev/build_islands.gd`) passou a aceitar o tamanho por
  desenho (`N`, `C`); a praia é o desenho de 256 m escalado ×2 (`_scale_open`): posições, costa,
  rio, caminhos, marcadores e florestas escalam, mas larguras, casas e folgas não, e a aldeia e a
  torre mantêm o seu próprio espaçamento. `horde_radius` 140 na ilha aberta. O dressing segue o
  barco e a escala (`_landing_shift`, `_scale`) e pinta as quatro regiões. Resultado: 125 310
  células transitáveis (antes 28 035), sem problemas no Check map. Capturas:
  `stage4_overview.png` e `stage4_landing.png`.
  - **O que falta nesta etapa:** a ilha está vazia entre os objetivos (era o risco anunciado). As
    três zonas próprias (enseada, bosque, ruína) ainda não foram desenhadas: as secundárias estão
    nos sítios antigos ×2. A erva e as florestas ficaram ralas para a área.
  - Corrigido pelo caminho: as estradas desenhadas em malha alinhada com a grelha não marcavam as
    células de estrada (um centro na diagonal não cai em nenhum dos dois triângulos), e o som dos
    passos no início do caminho era areia (`HandmadeIsland._cell_in_triangle`).
  - A fixture da praia foi regravada de propósito (`tools/dev/capture_beach_baseline.gd`). Dois
    testes que usavam a praia como parte de expedição de 256 m escalam agora a área de jogo.
  - Gerar a praia pelo `build_islands.gd` não deixa os materiais do dressing gravados nas casas;
    o `apply_beach_dressing.gd` sim. Depois de gerar, correr sempre o `apply_beach_dressing.gd`.
- As três decisões propostas abaixo ficaram por responder; a etapa 1 usa a recompensa da tabela.

## Etapas

Cada etapa acaba com testes a passar, a suite completa verde e um commit. Nenhuma toca nas
Berlengas nem nas outras quatro ilhas.

1. **Tarefas da ilha (código, sem mudar o mapa).** A ilha passa a ter uma lista de tarefas: uma
   principal e as secundárias. A principal usa o código de hoje; as secundárias são objetos
   pequenos, cada um com início, progresso, fim e recompensa. Começa por uma secundária só (o
   esconderijo de Intel), na `beach_01` atual. Teste novo: uma run com a secundária feita e outra
   sem ela; a extração só abre com a principal.
   - Ponto de atenção: hoje o código decide por `if mission ==` em 92 sítios entre
     `island_run.gd`, `island.gd` e `hud.gd`. A etapa não reescreve isso; acrescenta as
     secundárias ao lado. A arrumação das missões fica para depois do piloto, se resultar.
2. **HUD e minimapa.** O objetivo no topo mostra a principal; as secundárias aparecem numa
   lista curta por baixo, com a recompensa. O minimapa marca as secundárias com um ícone próprio.
   O ecrã de fim de ilha e o debrief dizem que secundárias se fizeram.
3. **As outras duas secundárias** (sobrevivente e ninho), ainda na ilha atual.
4. **A ilha a 512 m.** Novo desenho em `tools/dev/build_islands.gd` (`_design_beach`): a aldeia
   e a torre de hoje no centro, e três zonas novas, uma por secundária (uma enseada, um bosque e
   uma ruína). Terreno com quatro regiões de Terrain3D de 256 m. Marcadores novos: bolsas de
   secundárias (`Side_Cache_*`, `Side_Survivor_*`, `Side_Nest_*`), com a seed a escolher, como os
   geradores. Reaplicar o dressing (`tools/dev/beach_dressing.gd`) e alargar as posições das
   peças à ilha nova. Fixture de preservação nova, porque o layout muda de propósito.
5. **Navegação e desempenho.** `horde_radius` (a horda só calcula caminhos à volta do jogador,
   como na Berlenga) e medição com `tools/dev/bench_frame.gd` e `tools/dev/bench_island.gd`:
   tempo por frame, draw calls e memória, com 150 e 300 inimigos, nas três câmaras.
6. **Ver a jogar e decidir.** O utilizador joga a ilha nova em Threat 1 e 2. Decide: fica,
   ajusta, ou volta atrás. Só então se pensa nas outras ilhas.

## O que se mede

- Tempo por ilha (meta proposta: 12 a 15 minutos com todas as secundárias).
- Quantas secundárias se fazem por run, e quais se ignoram.
- Mortes antes da extração, com e sem secundárias.
- Tempo por frame e draw calls na ilha nova, contra a `beach_01` de hoje.

A telemetria já grava o `island_log` de cada ilha; acrescentam-se as secundárias feitas.

## Riscos

- **Caminhadas longas sem nada:** a 512 m pode haver zonas vazias. Mitigação: cada zona nova tem
  uma secundária e um gargalo; nada a mais de 40 s a pé de um objetivo.
- **Recompensas desequilibradas:** uma secundária que valha sempre a pena deixa de ser decisão.
  Valores iniciais pequenos, afinados a jogar.
- **Desempenho:** uma grelha 4× maior. A Berlenga já mostra que funciona com `horde_radius`,
  mas mede-se antes de dar como certo.
- **Trabalho perdido:** o dressing e o terreno da praia atual são refeitos na etapa 4. O script
  de autoria guarda as regras; as posições mudam.

## Decisões propostas (para o utilizador)

1. As recompensas da tabela acima, ou outras?
2. As secundárias veem-se no minimapa desde o início, ou só quando o jogador se aproxima?
3. A meta de 12 a 15 minutos por ilha é aceitável numa run de 3 ilhas (cerca de 40 minutos)?
