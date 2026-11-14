---
titulo: "docs/history/beach_pilot_20261114/CLAUDE_PLAN.md"
tipo: "referencia"
estado: "relatorio_historico"
atualizado: "2026-11-14"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/history/beach_pilot_20261114/CLAUDE_PLAN.md"]
---

# docs/history/beach_pilot_20261114/CLAUDE_PLAN.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original. Arquivo: não usar como lista de trabalho atual.

Fonte: `docs/history/beach_pilot_20261114/CLAUDE_PLAN.md` · SHA-256: `0866555f3cde7fa558481cdcff78520482d27024a8b0d1e8d459f9fdd02386c8`

# Recomendação para o piloto visual da `beach_01`

Isto é só uma recomendação. Não alterei ficheiros nem corri o Godot. O que digo vem da leitura do código e da cena.

## 1. Onde guardar o acabamento para que não se perca

**Uma cena de decoração separada, posta dentro de `Decor`, serve bem.** É a opção mais simples e segura.

- **Ficheiro novo:** `game/world/handmade/dressing/beach_01_dressing.tscn`. A raiz é um `Node3D` chamado `Dressing`, com dois grupos: `Beach/` e `Facades/`.
- **Não o pôr em `islands/`.** A função `HandmadeIsland.island_paths()` escolhe para a rotação qualquer ficheiro `beach_*.tscn` dessa pasta. Um `beach_01_dressing.tscn` ali seria sorteado como ilha.
- **Ligação à ilha:** a cena entra como instância em `beach_01.tscn`, no caminho `Decor/Dressing`. Assim aparece no editor e no jogo, porque `island.gd` instancia a cena inteira (`_handmade = scene.instantiate()`).
- **Porque a grelha não a vê:** `_children_of()` só lê os filhos diretos de `Buildings`, `Rocks`, `Trees` e `Bridges`, e de `Decor/Roads`. `object_boxes()` também só lê `Buildings` e `Rocks`. Uma instância em `Decor/Dressing` não bloqueia células nem mexe nas caixas da câmara.
- **Sobreviver a uma reconstrução:** `build_islands.gd` cria a raiz do zero e grava por cima da cena. Proponho uma função pequena, `_add_dressing(name)`, chamada em `_build_scene()` logo depois de `_place_cover()`:
  - se existir `res://game/world/handmade/dressing/<name>_dressing.tscn`, fazer `instantiate()`, dar-lhe o nome `"Dressing"` e chamar `_add(inst, "Decor")`;
  - `_add` só define o `owner` da raiz da instância, por isso a peça continua a ser uma instância e não é achatada para dentro da ilha.

**Perigos:**
- **Nunca pôr peças como filhos de `Buildings/Hut_*`.** `_block_shape()` projeta os triângulos de todas as malhas descendentes. O toldo (1,2 m de profundidade) bloquearia a fila de células à frente da porta, e `object_boxes()` cresceria.
- **Nunca usar os nomes `Roads` ou `SeaPreview`.** Ambos têm significado: um marca piso de estrada, o outro é escondido em `_use_handmade_world()`.
- **A `beach_01` atual já tem edições manuais.** Por exemplo, as alturas Y de `Generator4..6` (0,8; 0,71; 0,96) e `unique_id` sequenciais. Antes de reconstruir, ver o `git diff` da cena e confirmar que não se perde nada.
- **Opcional, conteúdo só do preset horror:** criar um grupo `Decor/Dressing/HorrorOnly`. Em `island.gd::_use_handmade_world()` basta `visible = _horror()`, porque o contexto já está definido nesse momento.
- **Materiais (a medir):** cada GLB foi importado com os seus próprios PNG extraídos (`*_scenery_albedo.png` ×13). Instanciar os GLB diretamente pode carregar 13 cópias do atlas, mesmo com uma substituição em runtime.
  - Correção limpa: nas opções de importação dos 13 `.glb`, apontar o material para um único `.tres` partilhado, equivalente a `scenery_kit.gd::material()`.
  - Medir antes e depois com `RenderingServer.get_rendering_info(RENDERING_INFO_TEXTURE_MEM_USED)`. Atualizar o comentário de `scenery_kit.gd` que diz "not wired into the island".

## 2. Onde pôr as peças

**Origens das peças** (segundo `original_scenery_kit/README.md`):
- Praia: centro da base, em Y=0, frente para −Z.
- Fachadas: centro da face traseira, em Z=0, e a peça projeta-se para +Z.

**Cabanas:** cada corpo mede 7×6 m. As paredes ficam a ±3,5 em X e ±3 em Z, à volta da origem da `Hut_*`. A parede vai até Y≈+2,9. O telhado é um prisma com a cumeeira ao longo de Z e as águas viradas para ±X.

| Cabana (origem) | Face útil | Transform local da peça |
|---|---|---|
| `Hut_01` (51,5; 95) | sul, virada para a praça | `window_shutters` (−1,6; 1,4; 3,0) |
| `Hut_02` (63,5; 95) | sul | `door_frame` (0; ~0; 3,0) e `wall_lantern` (1,0; 2,0; 3,0) |
| `Hut_03` (75,5; 95) | sul | `canvas_awning` (0; 2,4; 3,0) |
| `Hut_04` (77,5; 107) | oeste, virada para a praça | `tavern_sign` (−3,5; 2,2; 1,5), `rotation.y = −90°` |
| `Hut_06` (87,5; 99) | telhado | `chimney` em x≈+2,0, base ≈3,8 (a cumeeira está a 5,1) |
| `Tower_01` (121,5; 7; 39,5) | sul | `small_balcony` a meia altura, z=+3,5 |

**A escada exterior** (1,22 × 2,39 × 1,82 m) é a única fachada que assenta no chão e parece um obstáculo. Não há sítio óbvio onde as células já estejam bloqueadas. No piloto, só a colocaria se a grelha (botão "Check map") mostrar uma face junto a células já bloqueadas. Caso contrário, deixava-a de fora e o utilizador decide se passa a ser um objeto bloqueante, através do gerador.

Pôr as peças em Y=0 de cada cabana não chega: o chão é irregular (as origens variam de 0,66 a 1,05). A soleira da porta tem de ficar à altura do terreno.

**Peças de praia:**

| Peça | Onde |
|---|---|
| `crooked_dock_post` | em linha nos flancos do barco (x≈124/132, z 218–224), nas células de mar que já bloqueiam. Dá a ideia de um "pequeno cais" |
| `stranded_hull` (5,27 m) | metade dentro de água, a SO ou SE da praia de desembarque (≈110; 216 ou ≈150; 214), só em células já bloqueadas |
| `driftwood` e `fallen_fishing_net` | junto a `Rock_15` (149,7; 210,4) e a `Rock_01` (135,2; 202,8), e nas margens da ribeira, longe do vau (55; 143, largura 8) e do tabuleiro da ponte (128; 149) |
| `dead_tree` (4,3 m) | rebordo da colina ou do planalto, ou margem da ribeira, em células bloqueadas e longe de `Choke_BluffRamp` (128; 80) |

## 3. Terreno, materiais e vegetação sem mexer na grelha

- **Não editar alturas.** `build_map()` só lê a `height_map`; mudar cores ou texturas não altera a grelha.
- **Não pintar o Terrain3D no editor.** `_build_scene()` apaga a pasta `beach_01_data` e volta a importar `[height, null, color]`, por isso a pintura perder-se-ia. Fazer as mudanças em `_colour()` só para a `beach`:
  - uma faixa de areia molhada por altura, entre `sea_level` e cerca de +0,8 m;
  - uma transição areia/erva menos regular, usando um `FastNoiseLite` próprio com seed fixa.
- **Perigo crítico em `_colour()`:** tem de manter exatamente **um** `_rng.randf()` por píxel. O ciclo das cores corre antes de `_place_trees` e `_place_rocks`, que usam o mesmo `_rng`. Mudar o número de chamadas mexe árvores e rochas, e portanto a grelha.
- **Não tocar em `ground_assets.res`.** É partilhado por todas as ilhas.
- **Vegetação:** só acrescentar entradas **no fim** de `cover` em `_design_beach()`. `_place_cover()` corre em último e está em `Decor`, portanto não bloqueia. Usar peças baixas (≤0,6 m, por exemplo `Pebble_Round_2` e relva curta) para não esconder inimigos.
  - Não mexer em `forests` nem em `rock_count`: ambos alteram `Trees/` e `Rocks/`, logo a grelha.
- **Linhas de visão:** manter peças com mais de 1 m de altura a pelo menos ~6 m de todos os `Markers`: `Generator*`, `Cache*`, `Choke_*`, `Arena_*`, `Boat` e `PlayerStart`.
- **Câmara:** a decoração não entra em `_building_boxes`, por isso a câmara em 3.ª pessoa pode atravessar o casco ou o toldo. É aceitável num piloto, mas convém verificar.

## 4. Verificações e capturas

**Teste novo, `tests/test_beach_dressing.gd`** (`extends SceneTree`, `quit()` em todos os caminhos):

1. `beach_01` tem `Decor/Dressing`, a instância vem do caminho em `dressing/` e aparecem as 13 peças.
2. **Grelha igual:** correr `build_map()`, apagar `Decor/Dressing`, correr de novo. `field.blocked`, `wall_cells`, `cover`, o tamanho de `object_boxes()` e todos os marcadores têm de ser iguais byte a byte.
3. **Linha de base:** registar *antes* de qualquer mudança o número de células caminháveis e o md5 de `field.blocked`. Isto apanha alterações acidentais ao terreno ou ao `_rng`.
4. **Regras de cada peça** (AABB no plano XZ):
   - nada sobre células `COVER_ROAD` ou de tabuleiro;
   - distância mínima a cada marcador;
   - as peças "sólidas" (`StrandedHull*`, `DeadTree*`, `ExteriorStair*`) só sobre células já bloqueadas;
   - as restantes peças no chão com altura ≤0,6 m.
5. **Fachadas:** a face traseira fica a ≤0,15 m do plano da parede, calculado pela AABB de `Buildings/Hut_*/Body`. Apanha desvios se uma cabana mudar de sítio.
6. `HandmadeIsland.island_paths(&"beach") == [".../beach_01.tscn"]`.
7. Voltar a correr os testes existentes: `test_handmade.gd` (sem problemas, 1 ponte, estradas), `test_beach_cover_handmade.gd`, `test_objective_pools.gd`, `test_scenery_graphics.gd` e `test_smoke.gd`.

Se reconstruírem com `build_islands.gd -- beach`: confirmar no relatório de `_check_routes` e `_audit` que há 0 problemas, que `Decor/Dressing` continua lá, e rever o `git diff`.

**Capturas antes/depois** (precisam de GPU; o utilizador faz no Windows):
- Comando: `godot --path . --script res://tools/dev/screenshot_ingame.gd -- res://game/world/handmade/islands/beach_01.tscn <out.png> X Z [horror]`.
- Posições: desembarque (128; 205), aldeia (55; 117), ponte (128; 140), passagem nas dunas (197; 95), torre (125; 48).
- Fazer cada uma em normal e em horror, com as mesmas definições gráficas.
- Fazer também o PNG do botão "Check map" (`beach_01_grid.png`) antes e depois. Os dois têm de ser idênticos píxel a píxel.
- Para desempenho existe `tools/dev/bench_island.gd`. Não li o script, por isso é preciso confirmar os argumentos. Usar a mesma horda e a mesma qualidade, e registar ms e memória de texturas.

**Pendente de confirmação no editor:** as origens exatas da chaminé e da escada, a altura real da torre (não li `BoxMesh_hmoka`), e se os 13 GLB carregam de facto texturas em duplicado.
