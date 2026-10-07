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
  - a **auditoria** (`_audit`): objetos em água, rios, estradas, pontes,
    praças ou falésias, edifícios em chão irregular ou perto da costa, e
    estradas na água ou em falésias. Com problemas, o script acaba com
    código 1.
- Fotografias (renderização por software, sem GPU):
  - `tools/dev/screenshot.gd` tira a vista de cima e quatro vistas oblíquas;
  - `tools/dev/screenshot_ingame.gd` mostra a ilha dentro do jogo.
  - Comando: `xvfb-run -a -s "-screen 0 1280x720x24" godot --path . --rendering-driver opengl3 --resolution 1280x720 --script res://tools/dev/screenshot.gd -- <cena> <pasta>`
  - No Windows (com GPU): `godot --path . --resolution 1280x720 --script res://tools/dev/screenshot.gd -- <cena> <pasta>`
  - Também grava `close_<marcador>.png`, uma vista de perto de cada `Choke_*` e `Arena_*`.
- Testes:
  - `godot --headless --path . --script res://tests/run_all.gd` (todos);
  - `tests/test_handmade.gd` (ilhas feitas à mão);
  - `tests/test_soak_run.gd` (um bot completa runs nas ilhas).

## Auditoria atual (última execução)

```
beach_01  audit: no objects in odd places · todos os gargalos com rota alternativa
town_01   audit: no objects in odd places · todos os gargalos com rota alternativa
jungle_01 audit: no objects in odd places · todos os gargalos com rota alternativa
port_01   audit: no objects in odd places · todos os gargalos com rota alternativa
```

Medido em Windows (Godot 4.7.2): os testes de `tests/` passam todos e o bot
do `test_soak_run` completa as quatro ilhas. No Windows o processo do Godot
crasha ao sair (código 139 / -1073741819), também com o script antigo: lê
as linhas `TEST FAIL` e a auditoria, não o código de saída.

## O que foi feito (Claude, com revisão do Codex)

1. **Uma só regra de colocação:** `_spot_problem(pts, kind)` diz porque é
   que um objeto (`building`, `rock`, `tree`, `cover`) ficaria mal: água,
   costa, rio, ponte, estrada, praça, falésia ou chão irregular. A colocação
   e a `_audit` usam-na sobre a pegada real, por isso nunca discordam.
   - As rochas são colocadas, medidas com `HandmadeIsland._footprint` e
     retiradas se falharem; afundam até ao ponto mais baixo da pegada.
   - Cada tufo de vegetação é guardado em `_cover_spots` (sem GPU o
     `MultiMesh` não guarda as posições) e auditado.
   - Os edifícios desenhados à mão (cabanas, pátio, ruínas, armazéns,
     barracão) foram mudados de sítio; `_lot_free` testa todas as células.
2. **Terreno:** os planaltos só existem em terra (na costa acabam numa
   falésia sobre o mar); os lados das rampas são suaves junto ao pé; as
   praças são niveladas antes dos edifícios, com uma borda de 7 m; a
   suavização das estradas lê uma cópia das alturas.
3. **Pontes a sério:** água por baixo; tabuleiro inclinado de margem a
   margem, com guardas, no grupo `Bridges/` (as células por baixo andam-se à
   altura do tabuleiro; a água junto às guardas fica à mesma altura na grelha
   para as unidades não afundarem na beira). Os caminhos passam a direito
   sobre as pontes.
4. **Estradas desenhadas:** malhas em fita (`_place_roads`), curvas
   arredondadas, junções sem sobreposição visível, passeios na cidade, risco
   ao centro nas ruas largas, estreitamento das ruas largas para pontes
   estreitas. Proposta do Codex não seguida: união de polígonos (precisa de
   triangulação com buracos).
5. **Desenho:** estradas a começar no desembarque e a acabar no topo das
   rampas; igreja da cidade mais a leste, com rampas de 14 m que acabam nas
   ruas e uma rampa sudoeste (a norte descia para o canal); duna da praia
   mais curta para a volta pelo norte; caminho da brecha a direito.
6. **Verificação:** auditoria de estradas, caches na verificação de rotas,
   código de saída 1 com problemas, vistas de perto nos marcadores
   (`screenshot.gd`), teste das quatro ilhas e das pontes (`test_handmade`).

## Experiência: Road Generator nas ilhas feitas à mão

`build_islands.gd -- town --roadgen` constrói a cidade com as estradas do
Road Generator em vez das fitas e grava em
`game/world/handmade/trials/town_roadgen.tscn` (fora da rota: abre-a no
editor ou joga com F6 em `island.tscn`, campo **Handmade Scene**). Cada
caminho é cortado nos cruzamentos (`RoadIntersection`) e nas pontes; os
troços são cadeias de `RoadPoint` a cada ~8 m.

Comparação (fotografias de perto):
- **Melhor:** faixas pintadas, lancis, cruzamentos com cantos curvos.
- **Pior:** a estrada não segue o relevo (curva rígida entre pontos): na
  rampa da igreja o terreno atravessa o asfalto. Resolve-se achatando o
  Terrain3D por baixo da estrada (o addon tem um conector), o que obriga a
  desenhar as estradas antes de esculpir. Pára antes das pontes e não
  estreita para elas. Só faz asfalto (a terra batida continua em fita).

## Ilha real: Berlenga Grande

`islands/beach_berlenga.scn` é a Berlenga Grande, com 1,5 km, feita a partir
de dados abertos por `tools/real_island/build.gd`. O README dessa pasta tem o
como, as medições e os limites. Para caber no jogo foi preciso mudar:
- **o campo de fluxo:** tem um raio máximo (`horde_radius`), e um novo alvo
  espera que o cálculo em curso acabe;
- **os inimigos deixados para trás:** são substituídos por outros perto do
  jogador;
- **o minimapa:** acompanha o jogador;
- **a conversão para a grelha:** passou a ser feita sem ciclos lentos e leva
  cerca de 1 s para 2 milhões de células;
- **as rochas:** os nós `Scatter` em `Rocks/` bloqueiam;
- **o barco:** fica ancorado na direção do marcador.

A mesma ferramenta faz Hashima (`islands/port_hashima.scn`, rota Port):
prédios de betão com janelas, paredão, entulho e erva só nas zonas verdes.
As próximas ilhas reais (selva, cidade, vulcão) fazem-se uma de cada vez,
com aprovação do utilizador.

## Tarefas pendentes

- Picos de simulação: numa medição apareceram passos de 76 ms na `port_01` e
  de 117 ms em Hashima. Ao repetir, o pior passo foi de 6,7 e 8,5 ms. Pode
  ter sido carga da máquina naquele momento; voltar a medir se aparecerem
  quebras no jogo.

- Berlenga: falta um ecrã de créditos com "© OpenStreetMap contributors"
  (obrigatório pela ODbL quando o jogo for distribuído).
- Berlenga: o farol é uma caixa simples e o forte não tem modelo.
- Árvores ainda podem ter a copa sobre uma estrada ou um telhado (a regra
  só olha para o tronco).
- As falésias do terreno têm resolução de 1 m: de perto, as paredes das
  rampas parecem serrilhadas. É do grey-box; resolve-se com modelos de rocha.

## Regras do projeto

Ver `CLAUDE.md`:
- documentação e comunicação em português de Portugal; código em inglês;
- GDScript tipado;
- não editar `docs/DECISIONS.md`;
- só assets com licença livre, mais os dados do OpenStreetMap (ODbL, aceite
  pelo utilizador).
