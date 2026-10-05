# Horde Breaker — Design do Mapa

Documento de **design** do mapa: o que ele tem de fazer ao jogador e que peças
são precisas para lá chegar. A implementação está na secção 8.

Estado: **aprovado e em construção.** Ver a secção 8 no fim para o que já está
feito e o que falta.

---

## 1. O que o mapa tem de conseguir

O jogo é um horde shooter em terceira pessoa com auto-fire, orbes de XP,
extração ao fim de 10 minutos e progressão permanente. O mapa serve esse loop —
não é cenário decorativo. Cinco exigências, por ordem de importância:

1. **Legibilidade em pânico.** Com 100 zombies atrás, o jogador tem de saber
   para onde fugir *sem* abrir o mapa. Isto decide quase toda a estrutura.
2. **Ritmo alternado.** Espaços abertos (arma de longo alcance útil, horda
   espalha-se) alternados com apertados (shotgun e AoE brilham, horda concentra-se).
   Um mapa todo aberto ou todo apertado torna metade do arsenal inútil.
3. **Risco espacial.** O loot bom tem de estar onde é perigoso ir buscá-lo, e
   o caminho de volta tem de ser pior que o de ida.
4. **Orientação sem HUD.** O jogador tem de saber onde está o acampamento por
   marcos visíveis, não pela bússola.
5. **Barato de desenhar.** Peças
   reutilizadas, oclusão natural, poucos materiais distintos.

---

## 2. Estrutura macro: anéis + dois eixos

Mundo 8×8 setores (512×512 m), extração no centro.

```
        ┌─────────┬─────────┬─────────┬─────────┐
        │ INDUSTR │  URBANO │  URBANO │ INDUSTR │
        │         │         │         │         │
        ├─────────┼─────────┼─────────┼─────────┤
        │  URBANO │ SUBÚRB. │ SUBÚRB. │  URBANO │
        │         │         │         │         │
        ├─────────┼════ACAMPAMENTO════┼─────────┤   ← eixo E-O
        │  URBANO │ SUBÚRB. │ SUBÚRB. │  URBANO │
        │         │         │         │         │
        ├─────────┼─────────┼─────────┼─────────┤
        │ INDUSTR │  URBANO │  URBANO │ INDUSTR │
        └─────────┴────╫────┴────╫────┴─────────┘
                       ↑ eixo N-S
```

### Anel 0 — Acampamento (centro)
Aberto, boa visibilidade em 360°, cercado por barricadas baixas com **quatro
entradas** (uma por cardeal). O único sítio do mapa sem obstáculos altos: é aqui
que se vê a horda a chegar. Zona de extração.

### Anel 1 — Subúrbios
Casas baixas, quintais, cercas de madeira, garagens, carros nas entradas.
Linhas de visão curtas-médias, muitos cantos, muitas rotas paralelas. Perigo
médio, loot básico (munições, sucata). **É o anel-tampão**: dá para fugir por
vários lados.

### Anel 2 — Urbano e Industrial
- **Urbano:** prédios de 3–5 pisos, ruas estreitas, praças ocasionais, becos.
  Estrangulamentos naturais. Loot bom.
- **Industrial (cantos):** armazéns grandes com interior praticável, pátios de
  contentores, guindastes. Espaços interiores amplos = arenas de horda. Melhor
  loot do mapa, incluindo caixas de arma.

### Os dois eixos
Duas avenidas largas (16–20 m) que atravessam o mapa de lado a lado e cruzam-se
no acampamento. Função tripla:

- **autoestrada de fuga** — sempre corríveis, sem obstáculos que travem;
- **orientação** — estejas onde estejas, encontrar um eixo leva-te a casa;
- **ritmo** — são os espaços mais abertos fora do acampamento, onde as armas
  de alcance compensam.

Regra: de qualquer ponto do mapa, um eixo está a menos de ~40 m.

---

## 3. Vocabulário de peças

Peças modulares de **8×8 m** (célula do GridMap). As 448 peças reais vieram dos
packs CC0; a tabela abaixo é o vocabulário de design que elas preenchem.

### Ruas
| Peça | Notas |
|---|---|
| Reta | com passeio e candeeiros |
| Cruzamento | 4 saídas |
| T | 3 saídas |
| Curva | 2 saídas |
| Avenida (eixo) | dupla largura, separador central |

### Quarteirões
| Peça | Interior? | Papel |
|---|---|---|
| Casa suburbana + quintal | não | cobertura, cantos, ritmo |
| Fila de lojas + estacionamento | não | espaço médio aberto |
| Prédio urbano | não | bloqueia visão, define becos |
| Armazém | **sim**, 2 entradas | arena de horda, loot alto |
| Praça / parque | — | espaço aberto, respirar |
| Estacionamento | — | carros como cobertura |
| Bloqueio militar | — | estrangulamento, loot médio |

### Adereços (o que o utilizador pediu poder acrescentar)
Carros abandonados, autocarro tombado, contentores, árvores, arbustos,
candeeiros, caixotes, barreiras, tendas, sacos de areia, destroços.

Os carros abandonados valem por três: **cobertura** para o jogador,
**obstáculo de navegação** que divide a horda, e **fonte de sucata**.

---

## 4. Regras de composição

Estas regras é que fazem a diferença entre um mapa e um amontoado de peças.

1. **Nunca um beco sem saída.** Cada setor tem ≥2 entradas e ≥2 saídas. Se uma
   peça criar um beco, é sinalizada visualmente (portão, muro pintado).
2. **60/40.** Aproximadamente 60% construído, 40% praticável aberto. Medido por
   setor, não pelo mapa todo.
3. **Um marco por setor.** Torre de água, guindaste, antena, prédio mais alto,
   outdoor. Visível de 100+ m. É o que permite orientação sem HUD.
4. **Estrangulamentos nas fronteiras.** As passagens entre anel 1 e anel 2
   apertam — recompensa quem prepara a retirada.
5. **Loot escala com a distância ao centro.** Anel 1 munições e sucata; anel 2
   caixas de arma, caches grandes, POIs.
6. **Regra dos 3 segundos.** De qualquer ponto, o jogador tem de conseguir
   chegar a uma rota de fuga em ~3 s de corrida. Testa-se andando pelo mapa.
7. **Silhuetas distintas por anel.** Subúrbio baixo e claro; urbano alto e
   cinzento; industrial largo e enferrujado. O jogador sabe em que anel está
   pela cor periférica.

---

## 5. Como isto se implementa (esboço)

Compatível com o que já existe (streaming 8×8, worker threads, seed por perfil):

1. **Peças autoradas** como cenas Godot ou numa `MeshLibrary` (GridMap).
2. **Setor pintado** — cada setor é uma grelha 8×8 de células de 8 m nas três
   camadas de GridMap da `test_arena.tscn`.
3. **Gerador por seed** escolhe as peças respeitando as regras do ponto 4 e
   garantindo ligação das estradas nas fronteiras entre setores (contrato de
   bordo — já existe algo assim em `sector_edge_contract.gd`).
4. **Navegação** continua pré-cozinhada na worker thread, como agora.

Isto mantém: streaming, geração por seed, variedade entre partidas.
Isto substitui: a grelha de ruas atual e o pack Downtown.

---

## 6. Notas de desempenho

Com Forward+ há folga (140 inimigos a 143 FPS), mas o mapa deve ajudar:

- **poucos materiais distintos** — permite agrupar draw calls;
- **peças repetidas** em vez de geometria única por sítio;
- **prédios como caixas ocas** — bloqueiam a visão, e o que não se vê não se
  desenha; a oclusão natural do urbano é o melhor amigo do frame rate;
- **adereços com `visibility_range_end`** — carros e arbustos desaparecem ao
  longe sem se notar;
- **nada de interiores praticáveis fora dos armazéns**, e esses com portas que
  ocluem.

---

## 7. Decisões tomadas

1. **Base do mapa:** Terrain3D persistente, não uma grelha plana visível.
2. **Escala:** 8×8 setores de 64 m, numa área jogável de 512×512 m.
3. **Renderer:** Forward+.
4. **Passagem atual:** apenas terreno fora do acampamento. Os modelos antigos
   não definem a futura composição do mapa.
5. **Regresso de conteúdo:** caminhos primeiro; landmarks, POIs e dressing
   depois, em lotes pequenos e medidos.
6. **Forma de protótipo:** ilha grande, com costa navegável recortada pelo mar.
   As alternativas e os critérios de decisão estão em
   `docs/TERRAIN_MAP_OPTIONS.md`.

---

## 8. Estado da obra

### ✅ Feito

| Passo | Detalhe |
|---|---|
| **Demolição** | gerador procedural de estradas, `city_layout_generator`, `road_graph`, `sector_edge_contract`, `city_layout_rules` e o debug overlay removidos (863 linhas) |
| **Terrain3D integral** | 9 regiões persistentes cobrem os 64 setores e substituem o chão plano visível |
| **Costa** | barreira invisível persistente com 128 segmentos e espuma num único mesh; paredes quadradas removidas |
| **Percursos** | anel interior, anel costeiro e três ligações, nivelados na própria altura do terreno |
| **Biomas** | praia, relva, floresta norte/oeste, zona seca leste e rocha por altura/declive |
| **Landmarks** | Twin Ridge, Red Plateau, West Rise e South Cape, também identificados no mapa tático |
| **Mapa tático** | setores recortados pela silhueta costeira; mar, caminhos e landmarks visíveis |
| **Renderer** | Forward+: 140 inimigos medidos a 99,6 FPS nesta passagem visual |
| **Camadas GridMap** | `MapRoads`, `MapStructures`, `MapProps` mantidas vazias apenas como pontos de extensão |
| **Navegação** | vértices dos setores seguem a mesma função de altura do terreno; sem bloqueios invisíveis |
| **Gerador** | passou a colocar **só conteúdo** (caches, munições, arma, spawns); 894 → 339 linhas |
| **Assets** | 448 modelos importados, só glTF, com `SOURCE.md` e licença por pack |
| **Escala dos packs** | Kenney e KayKit vêm em miniatura (edifício ≈ 1 m); escalados no `build_tile_library.gd` — cidade ×6, fábrica/cemitério/KayKit ×4, carros ×1,8 |
| **Limpeza visual** | casas, estradas, props, dressing natural e POIs antigos retirados; acampamento preservado |

### ❌ Falta

- **Playtest humano prolongado** — sensação dos declives, rotas de fuga,
  visibilidade e leitura espacial; os testes técnicos automáticos já passam.
- **POIs e dressing** — reintroduzir por lotes pequenos depois da aprovação dos
  percursos, sem voltar a preencher a ilha inteira com a cidade antiga.
- **Otimização visual** — recuperar parte da baseline anterior sem retirar a
  leitura dos caminhos, biomas e costa; a medição atual continua acima de 60 FPS.

### Ferramentas

```
tools/build_tile_library.gd    packs → resources/map_tiles_pack.meshlib (+ mede módulos)
tools/paint_world.gd           limpa as três camadas legadas da arena
tools/build_terrain3d_world_data.gd  regenera as 9 regiões Terrain3D
tools/apply_skyboxes.gd        liga os céus aos presets de atmosfera
```
