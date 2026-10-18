# Arte dos zombies comuns e das armas

Estado a 2026-10-14. Decisão do utilizador: zombies comuns e armas no
**mesmo estilo blocky** do Recruit/Vanguard, mas com **materiais realistas**
(PBR) e **gore forte** nos zombies. Só os zombies comuns (o Walker, o
"Zombie normal" do GDD) na entrega inicial. **Atualização:** os seis
especiais, incluindo Behemoth, já têm modelos distintos e estão integrados;
ver [SPECIAL_ENEMY_MODELS.md](SPECIAL_ENEMY_MODELS.md). O sobrevivente
genérico continua fora desta atualização.

Capturas (Godot com janela, GPU): `docs/design/art/`
(`zombie_crowd` (48 zombies ao acaso), `zombie_variety` (24 lado a lado),
`zombie_lineup`, `zombie_closeup` (com partes em falta), `zombie_back`,
`zombie_walk`, `zombie_corpses`, `zombie_bench`, `weapons`,
`weapons_in_hands`, `fp_*`). Geradas com `tools/dev/zombie_preview.gd`:

```bash
godot --path . --script res://tools/dev/zombie_preview.gd -- <png absoluto> lineup
# planos: lineup, back, walk, closeup, corpses, crowd, variety, weapons, hands,
#         fp_<arma>, bench, bench_empty
```

A ferramenta carrega o soldado, as armas e o view model com `load()` só
nos planos que os usam: os planos de zombies continuam a funcionar
enquanto esses ficheiros estão a ser editados.

## Zombie: abordagem

- **Modelo em código** (`game/world/zombie_model.gd`): caixas, como o
  Recruit, ~1,95 m (o Recruit tem 2,03 m com capacete). Cada caixa sabe a que
  **parte** pertence (bacia, tronco, cabeça, braço/antebraço, coxa/canela),
  quanto **gore** tem, a sua cor ou **slot** de cor e quando aparece
  (condições `Show`). Um `ArrayMesh` indexado por variante, com uma
  superfície por material.
- **4 variantes = 4 cortes de roupa** (uma malha cada): civil (T-shirt,
  camisola de manga comprida, cai-cai ou hoodie, e jeans), trabalhador
  (camisa de linho, mangas em baixo ou arregaçadas, botas), casaco (casaco
  aberto sobre uma T-shirt encharcada) e sem camisa (flanco aberto com
  costelas, calças de sarja). Tudo o resto varia **por zombie** (ver
  "Variação por zombie").
- **Semente por zombie**: `ZombieModel.seed_for(Horde.speeds[i])` (o hash
  da velocidade-base sorteada). A velocidade viaja com o inimigo quando a
  horda compacta os arrays, por isso a variante e o aspeto são sempre os
  mesmos para o mesmo zombie, sem mexer na `Horde` (testado).
- **Animação procedimental na GPU** (`game/world/zombie.gdshader`): o
  esqueleto são pivôs fixos (anca, joelho, cintura, pescoço, ombro,
  cotovelo), como os pivôs do soldado antigo, mas calculados no *vertex
  shader*. Para a pose, por instância só vão 4 números (`INSTANCE_CUSTOM`;
  o aspeto vai na cor da instância): fase do passo, quanto anda,
  investida (ou cambalear, se atordoado) e recuo do golpe / queda. Daí saem
  o andar arrastado (uma perna arrasta), braços esticados, cabeça a
  balançar, investida ao atacar, recuo ao levar um tiro e a queda para trás.
- **Porquê não esqueleto + UAL**: 150 `Skeleton3D` com `AnimationPlayer`
  custariam CPU por osso e por zombie todos os frames. Assim, a horda inteira
  é **um MultiMesh por variante** (4 + sombras), preenchido com um único
  `buffer` por frame (`game/world/zombie_horde_view.gd`).
- **Cadáveres**: quando um zombie morre, o `ZombieHordeView` cria um corpo
  com a mesma variante e a mesma roupa (procura-o onde foi desenhado no
  frame anterior), que
  cai para trás (longe do jogador), fica no chão ~4 s e afunda. Com
  *headshot* cai sem cabeça (a cabeça voa como antes, nos destroços).
- **Pernas e rastejar (2026-10-17)**: o Crawler é o mesmo zombie sem pernas.
  Não há variante nem malha nova: a máscara ganha dois bits, `Show.LEGS`
  (20, as caixas das pernas dependem dele) e `Show.LEGLESS` (21, quatro
  caixas de coto na anca: carne escura, osso na ponta; `ZombieModel.legless_mask`).
  O shader lê o bit 21 e põe a pose de rastejar: tronco, anca e cabeça
  inclinados para a frente (`CRAWL_LEAN` 1,2 rad), afundados (`CRAWL_DROP`
  0,68 m), cabeça levantada (`CRAWL_HEAD_NOD` −0,5), e os braços em
  apoio/recuperação (ver *Correções visuais de 2026-10-17*). A cabeça
  fica a 0,69 m e as mãos a 0,07 m do chão. Só o `ZombieHordeView` põe o bit
  (quando `kind == CRAWLER`). A queda dura 0,4 s (`CRAWL_TRANSITION_TIME`): o
  instância leva `6 + progresso` em `INSTANCE_CUSTOM.w` (a faixa 6–7 está livre
  depois da morte, 4–5), e o shader mistura a pose de pé para a de rastejar.
  Os Crawlers não são escalados em altura (a pose já é baixa); a mira usa a
  pose (`IslandRun.enemy_head/enemy_chest`, constantes `CRAWL_HEAD_HEIGHT` e
  `CRAWL_CHEST_HEIGHT`, testadas contra `ZombieModel.crawl_points`).
  `ZombieModel.crawl_points()` é o espelho em GDScript da pose (para testes).
  Custo: +4 caixas por variante (≈ +96 vértices, cerca de +9 %; as caixas
  escondidas também passam pelo vertex shader). Medição: ver *Desempenho*.
  Os cotos e as abas de calça mudaram em 2026-10-17 (ver abaixo).
- **Estado**: queimadura, veneno, frio, congelado, *flash* de impacto e
  atordoado tingem o zombie, como tingiam a cápsula. A instância manda só um
  índice (`ZombieModel.Status`); as cores estão em `STATUS_TINTS`.
- **Só visual**: posições, velocidades, *hitbox*, altura e *headshot* não
  mudaram. A cabeça em repouso fica a 1,80 m e a lógica aponta a 1,78 m
  (`IslandRun.enemy_head`); a andar desvia no máximo 0,24 m; para os lados e
  em altura nunca mais de 0,2 m (o raio de *headshot* da mira é 0,4 m). Na
  investida a cabeça avança até 0,7 m, mas na direção do jogador, isto é,
  ao longo do raio de mira.

## Variação por zombie (roupa gerada ao acaso)

Pedido do utilizador: com só 4 roupas, uma horda de 150 repetia-se demais.
Agora cada zombie tem um aspeto próprio, **sorteado uma vez** a partir da
sua semente (`ZombieModel.roll_look`, com `RandomNumberGenerator`, por isso
é igual em qualquer máquina) e guardado em cache pelo `ZombieHordeView`.

O que varia:

| Traço | Opções |
|---|---|
| Camisa / T-shirt | 32 cores reais, desbotadas e sujas (azul-marinho, mostarda, bordô, caqui…) |
| Padrão da camisa | liso, riscas, xadrez (flanela), estampado no peito (rachado); 8 cores |
| Corte | T-shirt, manga comprida, cai-cai, hoodie (capuz, bolso, cordões); mangas arregaçadas no trabalhador |
| Casaco | 4 cores (cabedal preto, castanho, bordô, lona verde) |
| Calças | 16 cores (vários azuis de ganga, preto, caqui, castanho…); perna direita às vezes arrancada |
| Pele | 8 tons mortos (cinzento-esverdeado, ceroso, acinzentado, oliva, castanhos acinzentados, azulado), de claro a escuro |
| Cabelo | careca ou 7 cores; às vezes comprido atrás |
| Pés | 4 cores de sapato/bota/ténis, ou descalço |
| Parte em falta | nenhuma, antebraço esquerdo (coto com osso; o braço cai), maxilar (dentes, língua), orelha esquerda, dedos da mão direita (cotos com osso) |
| Corpo | 8 constituições, de magro a pesado (barriga), só na largura e profundidade |
| Desgaste | quantidade de gore, de sangue, de rasgões, de desbotado; sítio das feridas |

Combinações visíveis (sem contar o desgaste): 768 000 comuns (calças × pele
× cabelo × pés × parte em falta × perna × constituição) vezes as roupas de
cada corte: civil 2688, trabalhador 1088, casaco 2176, sem camisa 1 — cerca
de **4,6 mil milhões**. Numa horda de 150 sorteada como no jogo saem 149
roupas diferentes (teste).

Como funciona sem mais malhas nem mais *draw calls*:

- **Cores**: cada caixa tem um **slot** (pele, camisa, calças, sapatos,
  cabelo, casaco, ou fixo para cinto/carne/osso). O shader troca a cor da
  textura pela cor da paleta do zombie, mantendo o detalhe (a luminância da
  textura a dividir pela média, `LAYERS[...]["mean"]`, medida no mipmap
  1×1). As paletas estão em `ZombieModel` (sRGB) e vão para o shader como
  arrays de `vec4`.
- **Partes opcionais**: as alternativas estão todas na malha (manga ou
  braço nu, sapato ou pé descalço, maxilar ou ferida, orelha ou carne viva,
  dedos ou cotos, capuz, cabelo comprido). Cada caixa tem duas condições
  (`ZombieModel.Show`); o zombie manda uma máscara de bits e o *vertex
  shader* encolhe para um ponto as caixas cujas condições não estão ligadas
  (triângulos sem área não desenham nada).
- **Constituição**: o *vertex shader* alarga ou estreita tronco, bacia e
  membros (e desloca os ombros/ancas para fora), e dá barriga aos pesados.
  **A cabeça e o pescoço-pivô nunca mexem**: a altura do *headshot* é a
  mesma (testado: o crânio aparece sempre e `HEAD_CENTER` não muda).
- **Dados por instância**: a cor da instância (`COLOR`), que antes levava o
  tom do estado, leva agora 4 números: índice do estado, máscara, cores e
  desgaste. Os três últimos são inteiros abaixo de 2^24, exatos num float32
  (o Forward+ guarda o buffer do MultiMesh em float32; o renderer de
  compatibilidade comprime-o a meia precisão e estragaria isto).

Lição: um `PackedColorArray` passado a um `uniform vec4 x[N]` de um shader
3D é **convertido para linear** pelo Godot (medido: 0,5 voltou como 0,22).
O shader já convertia de sRGB, por isso a pele ficava quase preta; as
paletas passam como `PackedVector4Array`, que não é convertido.

## Gore (procedimental, sem downloads)

Tudo no *fragment shader*, com ruído 3D (*value noise* + fbm) na posição de
repouso (o sangue não "escorrega" quando o zombie anda):

- feridas abertas (carne vermelha húmida) cujo tamanho cresce com o gore da
  caixa; nas mais fortes aparece **osso**;
- **sangue fresco** (vermelho, brilhante) e **seco** (castanho-escuro, baço),
  escorridos verticais por baixo das feridas, salpicos e grandes manchas
  embebidas;
- **roupa rasgada**: nos materiais de tecido a ferida rasga o pano e mostra
  pele cinzenta com o bordo encharcado;
- pele morta: manchas esverdeadas, nódoas negras, veias, sujidade (mais
  forte nos pés);
- partes que faltam são geometria (coto, maxilar, orelha, dedos, flanco
  aberto), com caixas de carne/osso;
- por zombie: o ruído é amostrado noutro sítio (as feridas mudam de lugar),
  a quantidade de gore vai de 0,7× a 1,2× a de cada caixa, o sangue de pouco
  a encharcado, e os rasgões da roupa (independentes das feridas) de quase
  nenhuns a muitos. Os rasgões mostram a pele do próprio zombie.

## Correções visuais de 2026-10-17

Origem: uma revisão só de leitura do aspeto dos zombies, feita pelo Codex
do utilizador; o utilizador aprovou quatro correções. Só código de jogo,
testes, a ferramenta de captura `tools/dev/zombie_preview.gd` e este
documento (sem Blender, `assets/models/*` nem `docs/design/art/*`). Capturas em `docs/design/zombie_fix/`: `before_*`
(antes) e `after_*` (depois), com `tools/dev/zombie_preview.gd`.

**1. Ferimento do flanco como cavidade (sem-camisa).** Antes era uma placa
de carne e três ossos de 12 mm colados numa caixa de torso intacta. Agora o
torso do sem-camisa é feito de peças: um bloco de trás e uma parede da
frente com uma abertura (x −0,17 a 0,09 m; y 1,14 a 1,34 m). Dentro: chão e
quatro paredes de carne escura (`Kind.MOUTH`), três costelas de osso
recuadas (a 3 a 5 cm do fundo, contra 13 cm da parede) e quatro lábios de
carne em losango nos cantos, a 45°, para a borda ser irregular. As outras
variantes não mudam. Teste: a abertura não é tapada por nenhuma caixa e há
cinco caixas escuras e três costelas dentro dela.

**2. Rastejar com as mãos presas ao chão.** Antes os braços oscilavam com um
seno da fase, mesmo parados. Agora cada mão tem um ciclo de
`CRAWL_STRIDE` = 0,8 m de percurso:

- **apoio** (metade do ciclo, `CRAWL_STANCE` 0,5): a mão fica no chão
  (y = 0,07 m) e desliza para trás no referencial do corpo à velocidade de
  rastejar; o corpo passa por cima dela (o *pull*);
- **recuperação**: a mão levanta `CRAWL_LIFT` 0,10 m (seno) e volta à frente
  (cosseno).

As mãos alternam (meio ciclo). O ombro e o cotovelo vêm de IK de dois ossos
(`crawl_arm`: 0,30 m de ombro a cotovelo, 0,335 m de cotovelo ao centro da
mão) no referencial do torso, por isso o alvo fica no chão mesmo com o
torso inclinado. A fase do Crawler passa a
`ZombieModel.crawl_phase_rate(base) = 2π · (0,4 · base) / 0,8`, a velocidade
real de rastejar, em vez de `0,7 · (3 + 2,6 · base)`. Única mudança na
horda: `zombie_horde_view.gd`. A cadência ficou perto da antiga (6,9 rad/s
para a velocidade-base 2,2; antes 6,1). O corpo deixou de balançar e de
subir/descer ao rastejar, para não mexer nas mãos. Com o zombie parado
(`walk` = 0) o ganho do ciclo vai a zero e as mãos ficam no ponto de
repouso.

- **Variante *worker* sem antebraço** (apoio assimétrico): o coto fica
  parado, pousado na posição de repouso, sem ciclo; a mão direita faz o
  puxão sozinha, com o mesmo ciclo. O coto fica a cerca de 0,3 m do chão,
  por isso não pode plantar-se. **Escolha de autor, a confirmar a olho.**
- **Espelho CPU**: `ZombieModel.crawl_points(cycle)` usa o mesmo IK e ciclo.
  A cabeça e o torso não mudaram: `CRAWL_HEAD_HEIGHT` 0,685 m e
  `CRAWL_CHEST_HEIGHT` 0,44 m continuam a bater com a pose (testes).
- **Limites**: a mão fica exatamente no chão à velocidade nominal. Com frio
  (que abranda o Crawler) desliza um pouco, porque a fase não integra a
  velocidade real (só a nominal, `base × 0,4`).

**3. Cotos irregulares.** Comprimento por variante (`STUMP_LENGTHS`:
0,16 / 0,10 / 0,13 / 0,08 m, o esquerdo +2 cm). Uma ponta de osso sai 5 cm
para além da carne. Duas abas de calça por coto (por fora e atrás), com
desgaste 0,9 (encharcadas), inclinadas (±0,12 rad). Continuam a ser caixas.
Testes: quatro comprimentos diferentes, uma ponta de osso por coto, quatro
abas por Crawler.

**4. Materiais.**

- **Pele** (camada da pele, `rot`): a textura de couro usa só 30 % do seu
  detalhe (60 % nas roupas), para a pele não parecer couro; manchas finas
  (*mottling*, ±17 %) e cor quente ou fria; **livor**: manchas roxo-azuladas (mistura 0,75) onde o sangue
  assentou, mais no corpo baixo (`smoothstep(1.3, 0.6, y)` no shader), com veias
  escuras; manchas esverdeadas de decomposição.
- **Órbitas**: a pele à volta de cada olho escurece 70 % num raio de 3 a
  6,5 cm e a normal dobra-se para dentro (tigela).
- **Olhos**: calote com normal abaulada e pupila escura (dilatada), em vez
  da placa pálida plana.
- **Rasgos de tecido**: a borda desfiada passa a cor plana (desbotada, 45 %)
  e a normal fica lisa onde o pano está rasgado ou desfiado: o tramado não
  aparece no rasgo. O tecido por rasgar mantém o tramado.

Geometria (caixas e vértices por variante; entre parênteses, antes destas
correções, calculado): civil 59 caixas / 1416 vértices (antes
55 / 1320), trabalhador 55 / 1320 (51 / 1224), casaco 53 / 1272 (49 /
1176), sem camisa 67 / 1608 (52 / 1248). O sem-camisa é o que mais cresce
(+11 caixas com a cavidade); cada variante tem +4 caixas de coto.

Testes: `tests/test_crawlers.gd` (mão planted, recuperação, fase = velocidade,
abas, cabeça e peito) e `tests/test_zombie_model.gd` (cavidade, cotos).

## Crawler com o corpo do GLB (2026-10-18)

O Crawler passa a desenhar o modelo `assets/models/characters/crawler_original/crawler.glb`
(Codex do utilizador, CC0), em vez das caixas do Walker na pose de rastejar. O
procedimento de 2026-10-17 (ciclo, IK, fase por distância percorrida) mantém-se;
muda só o corpo e o que o shader faz com ele. Capturas em
`docs/design/crawler_integration/`: `crawl_stride` (4 Crawlers a 0; 0,2; 0,4 e
0,6 m percorridos), `crawl_close`, `crawl_crowd` (60 ao acaso), `crawl_topple`
(tombamento em três fases) e `crawl_death` (mortes, uma sem cabeça).

**Escolhas e porquê.**

- **Malha única, carregada em tempo de execução** (`game/world/crawler_body.gd`):
  `GLTFDocument` lê o GLB do ficheiro (sem depender da importação do editor), junta
  as oito peças numa malha só e guarda em cada vértice a peça (corpo, cabeça,
  braço esquerdo, braço direito), o peso do braço e a rugosidade. A horda desenha
  os Crawlers numa `MultiMesh` própria (`CRAWLER_VARIANT`), por isso o custo por
  zombie continua a ser uma instância.
- **Shader próprio** (`game/world/crawler_body.gdshader`), em vez de meter o GLB em
  `zombie.gdshader`: o shader dos Walkers fica intacto. O shader repete só o que o
  corpo precisa: a fase (`CRAWL_STRIDE` 0,8 m, `CRAWL_STANCE` 0,5, `CRAWL_LIFT` 0,10 m),
  o IK de dois ossos e a pose da cabeça.
- **Articulações do GLB, não as do procedimento.** Ombros (0,46 m), pulsos
  (0,056 m) e pivô da cabeça (0,685 m) vêm dos nós do ficheiro. Os ossos do braço
  são as distâncias ombro-cotovelo (0,262 m) e cotovelo-pulso (0,276 e 0,267 m,
  esquerdo e direito); o cotovelo (0,25; 0,20; 0,61 m) foi estimado da geometria
  do braço, e a IK de repouso cai nesse ponto a menos de 1 mm.
- **Braço e mão.** O braço é um só sólido no GLB, com o cotovelo fletido. Cada
  vértice recebe um peso (0 no braço superior, 1 no antebraço, mistura junto ao
  cotovelo). A mão é transladada com o pulso e não roda: fica plana no chão.
  Assim a mão não pode afundar-se nem descolar-se do antebraço.
- **Curso centrado para trás, 0,16 m** (`CRAWL_CENTRE_Z`, `CrawlerBody.CENTRE_Z`).
  Medido: com o curso centrado no ponto de repouso, a fase da frente do apoio
  (+0,2 m) fica a 0,615 m do ombro e o alcance do braço é 0,538 m, por isso o IK
  não chegava ao pulso. Descentrado, o alcance máximo usado é 0,506 m. O apoio
  continua com os mesmos 0,8 m de percurso por ciclo e a mão continua no chão.
  Com o Crawler parado (`walk` = 0) as mãos ficam na pose do GLB.
- **Tombamento** (`TOPPLE_ANGLE` 0,8 rad, pivô `TOPPLE_PIVOT_Z` 1,03 m, logo à
  frente dos dedos): o traseiro sobe e o corpo deita-se nas mãos em 0,4 s. Com o
  pivô nos dedos, todo o corpo fica acima do chão (medido, +8 mm no mínimo; com
  o pivô à altura das mãos os dedos afundavam 0,13 m parados e 0,16 m com o curso;
  detetado numa revisão do Codex e corrigido).
- **Morte.** Achata o corpo para 35 % da altura (a normal corrige-se pela
  transposta inversa). Sem cabeça: a cabeça colapsa para o pescoço.
- **Cores.** As roupas (`cloth_shirt`, `cloth_trousers`) tiram a cor da paleta do
  zombie (camisa e calças), para o bando ter variedade como os Walkers. A pele, o
  osso e as feridas usam as cores do GLB (com o sangue por vértice).
- **Triângulos de área nula.** O GLB tem 4728, dos quais 96 têm área zero; a malha
  guarda 4632 (é o que se desenha).
- **Alvo de mira (contrato, não mudou).** `CRAWL_HEAD_HEIGHT` 0,685 m é o pivô da
  cabeça do GLB; o centro visual da cabeça está a cerca de 0,79 m. Ver "Por fazer".

**Limites conhecidos.**

- **Cabeça solta do tronco.** O GLB levantou a cabeça 0,095 m mas o pescoço do
  tronco ficou na altura antiga (NOTES do modelo). A distância mínima entre
  vértices da cabeça e do tronco é de 3,2 cm. Corrige-se no Blender, não no jogo.
- **Aspeto igual.** Todos os Crawlers têm a mesma cabeça e o mesmo corpo; só a
  roupa muda de cor.
- **Um vértice a −1 mm** do chão durante a recuperação do braço. Dentro da
  tolerância do teste (−2 mm) e invisível.
- **GPU.** Ver os números abaixo: é o custo real desta mudança.

**Testes** (`tests/test_crawlers.gd`, headless, 57 linhas `TEST:` sem falhas):
o GLB carrega (4728 triângulos, 96 descartados), pivô da cabeça 0,685 m, pulsos
0,056 m, malha de 0 a 0,929 m; a pose de repouso não move nada; a cadeia do
braço chega ao alvo em todo o ciclo (erro 0 m); a mão fica no chão no apoio,
recua 0,8 m por ciclo e levanta 0,10 m na recuperação; em repouso as mãos não
se movem; o tombamento não desce abaixo do chão; a fase do Crawler dá uma volta
por 0,8 m percorridos; sem o GLB (`CrawlerBody.enabled = false` ou ficheiro em
falta) o Crawler é o Walker em pose de rastejar. Os testes de geometria dos
especiais (`test_special_models.gd`) também cobrem o novo `Zombies_crawler`.

**Desempenho** (Windows 11, RTX 5060, Godot 4.7.2, 1600×900, vsync desligado,
sombras ligadas; `zombie_preview.gd bench_crawl` e `bench_crawl_proc`, 500 frames,
duas corridas cada; `bench_empty` = 0,56 ms de GPU):

| Medida | Procedural (Walker em pose) | GLB | Diferença |
|---|---|---|---|
| 150 Crawlers, GPU | 1,01 ms | 1,53 ms | **+0,52 ms** |
| 150 Crawlers, `ZombieHordeView.draw` (janela) | 0,45–0,46 ms | 0,44–0,48 ms | ≈ 0 |
| 150 Crawlers, `draw` (headless, teste) | 0,42–0,45 ms | 0,41 ms | ≈ 0 |
| Triângulos por Crawler | 708 | 4632 | ×6,5 |

O CPU fica dentro do orçamento (+0,1 ms): a diferença é ruído. O custo é de GPU:
o GLB tem ~6,5 vezes os triângulos. Mitigações, se o jogo pedir: uma versão com
menos triângulos (o GLB tem muitas faces pequenas nas feridas e nos dentes),
desligar a projeção de sombra dos Crawlers, ou um LOD. Não foram feitas.

**Por fazer (decisões do utilizador).**

- Confirmar a altura de mira: o pivô da cabeça do GLB (0,685 m) fica na base da
  cabeça; o centro visual está a ~0,79 m. Se os headshots falharem a olho,
  `CRAWL_HEAD_HEIGHT` pode subir (é contrato; não foi mudado).
- Fechar o pescoço no GLB (ver limites).
- Se o custo de GPU de +0,52 ms for demais, escolher uma das mitigações acima.
- Playtest no editor do Windows: os testes são headless, por isso o aspeto só se
  confirma com GPU. Verificado aqui por captura com janela (Godot compilou o shader
  sem erros no log): as mãos ficam no chão nas quatro fases do passo, o tombamento
  e a morte têm forma razoável. Falta ver o ritmo do passo em jogo e a leitura da
  cabeça para os tiros.

## Armas

- **Atualização de 2026-10-15, pedido do utilizador:** os cinco modelos em
  caixas foram substituídos pelos GLB originais de Blender em
  `assets/models/weapons/tactical_original/`, com materiais PBR próprios.
  Origem no punho (mão direita), cano para -Z, `Muzzle` próprio na ponta.
  Comprimentos reais: SMG 0,74 m, espingarda de assalto 0,9608 m,
  metralhadora e caçadeira 1,04 m, marksman 1,12 m.
- `WeaponModel` mantém a calibração da pega dos rigs entregues, agrupa as
  peças por material numa malha partilhada e conserva todos os triângulos,
  UVs, normais e tangentes. O disparo usa sempre o cano da arma equipada.
  A mão esquerda ajusta-se ao guarda-mão de cada arma sem alongar ossos.
  Implementação e limites em [WEAPON_MODELS.md](WEAPON_MODELS.md).
- **Terceira pessoa e Armory**: `SoldierModel.set_weapon` põe a
  `WeaponModel` no `WeaponMount` da mão; a espingarda original do GLB fica
  escondida.
- **Primeira pessoa**: `ViewModel` usa a mesma `WeaponModel`, sem sombras, a
  50 % (antes 60 %; com a coronha real ficava grande demais). A marksman
  chega a 0,865 m à frente do olho.
- As silhuetas da Armory desenhadas em código (`armory_art.gd`) não mudaram.

## Texturas (Poly Haven, CC0)

`tools/art/fetch_polyhaven_textures.py` descarrega (só da API da Poly Haven)
e `tools/art/pack_textures.gd` empacota no formato das texturas das ilhas
(`assets/textures/polyhaven/<id>_diffuse|_nor_gl|_rough.res`: RGBA8 →
mipmaps → S3TC, `ImageTexture`). Registadas em `assets/LICENSES.md`.

| Id | Uso | Tamanho | Disco |
|---|---|---|---|
| leather_white | pele (tingida de cinzento-verde) | 512 | 3 × 171 KB |
| cotton_jersey | T-shirts, calças caqui | 512 | 3 × 171 KB |
| denim_fabric_06 | jeans | 512 | 3 × 171 KB |
| fabric_leather_02 | casaco, cinto, botas, cabelo | 512 | 3 × 171 KB |
| rough_linen | camisa de trabalho | 512 | 3 × 171 KB |
| blue_metal_plate | aço/gunmetal (diffuse em cinzento) | 1k | 3 × 683 KB |
| rubberized_track | polímero (diffuse em cinzento) | 1k | 3 × 683 KB |
| american_walnut_veneer | coronhas de nogueira | 1k | 3 × 683 KB |
| rusty_metal_04 | (já existia) cobertura do cano da metralhadora | — | 0 |

Total novo: **≈ 8,9 MB** (2,6 MB zombies + 6,3 MB armas). Os zombies usam
512 px porque são pequenos no ecrã; as armas 1k porque a primeira pessoa as
mostra de perto.

## Desempenho (medido)

Ambiente: Windows 11, RTX 5060, Godot 4.7.2, 1600×900, Forward+, sombras do
sol ligadas, vsync desligado (`zombie_preview.gd bench` vs `bench_empty`,
500 frames).

| Medida | Valor |
|---|---|
| 150 zombies a andar, GPU | +0,43 ms (0,56 → 0,99 ms) |
| 150 zombies, CPU de render | +0,09 ms (0,17 → 0,26 ms) |
| `ZombieHordeView.draw` (GDScript, 150) | 0,39 ms com janela; ~0,5 ms headless |
| caminho antigo (cápsula+cabeça+2 braços), headless | ~0,3 ms (sem custo real do RenderingServer) |
| construir as 4 malhas | ~7–9 ms, uma vez por sessão |

Limites: o caminho antigo só foi medido headless (o RenderingServer falso
não custa nada, por isso subestima-o); a GPU mediu-se numa planície vazia,
não numa ilha.

**Variação por zombie** (2026-10-14, mesmo ambiente e mesma medição, 3–4
corridas de cada; a GPU variou menos de 0,02 ms entre corridas):

| Medida | Antes (4 roupas fixas) | Depois (aspeto por zombie) |
|---|---|---|
| 150 zombies, GPU | 0,96 ms (vazio 0,56) | 1,02–1,03 ms (**+0,065 ms**) |
| 150 zombies, CPU de render | 0,15–0,18 ms | 0,16–0,18 ms |
| `ZombieHordeView.draw` (150, com janela) | 0,34 ms | 0,33 ms |
| `ZombieHordeView.draw` headless (teste) | — | 0,30 ms |
| construir as 4 malhas | ~7–9 ms | 8 ms |

**Crawlers** (2026-10-17, `tests/test_crawlers.gd`, só CPU headless: **não é
medição de GPU**, não houve janela nem GPU nesta sessão): `ZombieHordeView.draw`
com 150 Walkers ≈ 0,44–0,46 ms; com 150 Crawlers ≈ 0,50–0,51 ms (+≈0,06 ms,
duas corridas em sequência, sem outros testes em paralelo). A GPU por medir no
editor do utilizador (`zombie_preview.gd bench`): o esperado é uns centésimos
de ms a mais por caixas extra.

A primeira versão custava +0,14 ms de GPU: as caixas alternativas
escondidas continuam a passar pelo *vertex shader* (também nas sombras).
Indexar as malhas (`SurfaceTool.index()`: 24 cantos partilhados por caixa
em vez de 36 vértices soltos) desceu para +0,065 ms. Cada variante tem agora
45–51 caixas (1080–1224 vértices, 540–612 triângulos), das quais ~10 ficam
escondidas em cada zombie. O `draw` não ficou mais caro porque o aspeto vem
de uma cache (dicionário velocidade → aspeto) em vez de um `hash()` por
zombie e por frame. Não há LOD.

**Correções de 2026-10-17** (mesma máquina, mas com outros processos a
usar GPU e CPU durante a sessão: um Godot aberto desde as 13:03 e outras
aplicações; por isso **não é medição limpa**):

| Medida | Valor |
|---|---|
| 150 Walkers, `ZombieHordeView.draw` (headless, CPU) | 0,54 a 0,73 ms |
| 150 Crawlers, `ZombieHordeView.draw` (headless, CPU) | 0,57 a 0,61 ms |
| `bench` / `bench_empty` (GPU, janela) | **não utilizável**: a cena vazia dava 18 a 22 ms de GPU (não 0,56 ms) |

Estimativa, não medida: cerca de +24 mil vértices no total da horda (+13 %, sobretudo
o sem-camisa), mais umas contas no fragment shader (ruído da pele e da
órbita só nos pixels de pele e de cara; o `if` das órbitas só corre na
cabeça). Por medir no editor do utilizador: `zombie_preview.gd bench` e
`bench_empty` com o computador livre, comparado com os números de 2026-10-14.

## Ligações ao resto do jogo

Edições mínimas fora dos ficheiros novos:

- `game/world/island.gd`: cria `_zombies` (`ZombieHordeView`); em
  `_draw_enemies` chama `_zombies.draw(...)` e esconde as cápsulas dos tipos
  que ele desenha; no ciclo de mortes chama `_zombies.on_death(...)` e os
  destroços de zombies comuns passam a cor de carne/pele.
- `game/world/soldier_model.gd`: `set_weapon` usa `WeaponModel`.
- `game/world/view_model.gd`: `set_weapon` usa `WeaponModel`; escala 50 %.
- Testes: `tests/test_zombie_model.gd`, `tests/test_weapon_models.gd`
  (novos); `tests/test_recruit_animation.gd` (a espingarda do GLB fica
  sempre escondida; as 104 peças contam-se sem as da arma).
- A variação por zombie não mexeu em `island.gd`: a API do
  `ZombieHordeView` (`draw`, `on_death`, `handles`) é a mesma.
  `ZombieModel.SKIN_TINT` continua a existir para os destroços da cabeça.

## Inimigos especiais — integrados

Runner, Brute, Grabber, Behemoth, Bloater e Screamer têm geometrias e
perfis de pose próprios em `special_enemy_model.gd`. Partilham o formato
CUSTOM0/CUSTOM1/CUSTOM2, os estados e os cadáveres do `ZombieHordeView`.
Os sete tipos do jogo são agora desenhados com modelos; a ilha esconde as
cápsulas de todos eles. Detalhes, imagens e testes em
[SPECIAL_ENEMY_MODELS.md](SPECIAL_ENEMY_MODELS.md).

## Decisões propostas

- Runner com modelo próprio: implementado na atualização dos especiais.
- ~~Variação de tom de pele/roupa por instância~~: feito (ver "Variação por
  zombie").
- Dar ao zombie um pouco mais de variação de altura (±5 %). Ficou de fora
  porque mexe na altura da cabeça e o *headshot* aponta a uma altura fixa
  por tipo; exigiria passar a altura de cada zombie para
  `IslandRun.enemy_head()`.
- Variar também a mão em falta (hoje só a esquerda perde o antebraço e só a
  direita perde dedos) e juntar uma variante de roupa de trabalho
  (fato-macaco/colete refletor) ou de hospital, se o jogo pedir.
