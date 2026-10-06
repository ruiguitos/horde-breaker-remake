# Ilhas feitas à mão: estado e tarefas pendentes

Documento de passagem de trabalho (para outro agente, por exemplo o Codex,
ou para o utilizador). Lê também `game/README.md`, secção "Ilhas feitas à mão".

## Como funciona

- As ilhas da rota estão em `game/world/handmade/islands/<bioma>_01.tscn`,
  com 256 × 256 m cada.
- São geradas por `tools/dev/build_islands.gd`:
  - o desenho de cada ilha está em `_design_<bioma>()`;
  - o motor esculpe o Terrain3D (`_sculpt`) e coloca os objetos (`_place_*`).
- Comando para gerar:
  `godot --headless --path . --script res://tools/dev/build_islands.gd [-- beach town ...]`
- O que o script imprime para cada ilha:
  - os problemas do `HandmadeIsland.build_map()`;
  - as rotas (fecha cada `Choke_*` e confirma que os objetivos continuam
    acessíveis);
  - a **auditoria** (`_audit`): objetos em água, em estradas, em pontes, em
    praças, em falésias, e edifícios em chão irregular.
- Fotografias (renderização por software, sem GPU):
  - `tools/dev/screenshot.gd` tira a vista de cima e quatro vistas oblíquas;
  - `tools/dev/screenshot_ingame.gd` mostra a ilha dentro do jogo.
  - Comando: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/dev/screenshot.gd -- <cena> <pasta>`
- Testes:
  - `godot --headless --path . --script res://tests/run_all.gd` (todos);
  - `tests/test_handmade.gd` (ilhas feitas à mão);
  - `tests/test_soak_run.gd` (um bot completa runs nas ilhas).

## Auditoria atual (última execução)

```
beach_01  água/irregular: Hut_01 (39,95), Hut_06 (29,111) · estrada: Hut_05 (77,119), Rock_01 (174,105)
town_01   água/irregular: Wall_03 (41,114), Wall_05 (54,110) · praça: Rock_02 (148,55), Rock_05 (158,67)
jungle_01 ponte: Rock_07, Rock_16 · falésia: Rock_08, Rock_16, Rock_20 · água: Rock_16, Rock_20
port_01   água/irregular: Warehouse_01, Warehouse_04, Shed_01
```

## Tarefas

1. **Zero objetos em sítios estranhos.** A `_audit` tem de dizer "no objects
   in odd places" nas quatro ilhas.
   - **Cabanas, muros e armazéns perto da costa:** afastá-los, ou fazer
     `_lot_free` e o desenho exigirem que estejam bem dentro de terra
     (inland > 10 m em todo o retângulo).
   - **Rochas:**
     - `_free()` tem de rejeitar estradas a menos de 1 m e as travessias
       (`_crossing_at`);
     - tem de rejeitar praças em todos os biomas;
     - tem de rejeitar falésias, verificando a inclinação em toda a área da
       rocha (cerca de 3 × 3) e não só no centro.
   - **Vegetação rasteira** (`_place_cover`): rejeitar estradas a menos de
     1,5 m, praças, falésias (inclinação > 0,6) e travessias.
2. **Estradas bem desenhadas.** Hoje são só cor pintada no terreno (borrada,
   resolução de 1 m). Proposta:
   - gerar uma malha em fita por cada `paths[i]` (SurfaceTool), com amostras
     a cada 1 m, à altura do terreno + 0,05, a largura do caminho e bordas
     nítidas;
   - nas cidades e no porto, asfalto com passeio (uma segunda fita, mais
     larga e mais baixa); nos trilhos da praia e da selva, terra;
   - deslocar cada estrada um pouco em y (0,005 × índice) para não haver
     z-fighting nos cruzamentos;
   - pôr as fitas em `Decor/Roads` (não bloqueiam).
3. **Revisão visual de perto.**
   - Acrescentar ao `screenshot.gd` vistas à altura do jogador em cada
     marcador `Choke_*` e `Arena_*`.
   - Corrigir o que parecer errado: árvores a flutuar, pontes desalinhadas
     com o rio, casas enterradas.
4. Depois de cada alteração:
   - correr `build_islands.gd`, os testes e as fotografias;
   - fazer commit para `master` com Conventional Commits.

## Regras do projeto

Ver `CLAUDE.md`:
- documentação e comunicação em português de Portugal; código em inglês;
- GDScript tipado;
- não editar `docs/DECISIONS.md`;
- só assets com licença livre.
