# Mundo e missões

Proposta de 2026-10-05 para a direção A+B ("Expedition Breaker"), câmara
média e horda de ~80–150 inimigos ativos. **Nada aqui é decisão** até entrar
em `docs/DECISIONS.md`; as propostas estão na secção 7.

> **Parcialmente substituído (2026-10-24).** O mapa em grafo da §1.1 deu lugar
> a rotas sorteadas entre ilhas (decisão de 2026-10-14). Os templates da §3
> foram implementados com outros números: o Activate usa 8 s por gerador, não
> 20 s, e há 11 missões. O estado real está em `game/README.md` e em
> `docs/design/OBJECTIVES_PROPOSAL.md`. O que continua válido são as regras de
> layout da §2.1 e as fichas de identidade das ilhas da §4.

Fontes: `BRAINSTORM.md` (secções 2, 4 e 10) e, como referência histórica,
`legacy/ARCHIPELAGO_GAMEPLAY_PLAN.md`, `legacy/MAP_DESIGN.md`,
`legacy/HUD_AND_OUTER_MISSIONS.md` e `legacy/PROJECT_AUDIT.md`.

**O que muda em relação ao original, e porquê:**

| Original | Remake | Porquê |
|---|---|---|
| Arquipélago contínuo de 768 × 768 m, 7 ilhas, ferries, nevoeiro | Uma cena compacta por ilha; a viagem é um ecrã | Mundo grande para pouco conteúdo; streaming e navegação entre ilhas custaram caro |
| Missões fixas por ilha (ninhos sempre na Forest, relés sempre nos Cliffs) | Templates de missão × ilha × modificador | Rejogabilidade sem modelar mapas novos |
| Acampamento com 4 tiers, torres, Scrap e outposts | Barco como ecrã de serviços, "escolhe 1 de 3" | Sistemas órfãos e uma moeda a mais (ver secção 5) |
| Missões opcionais de "ficar 8 s perto de um altar" | Cada missão tem um evento de horda | O pilar é *romper a horda*; estar parado perto de um objeto não o serve |

---

## 1. Estrutura da expedição

### 1.1 Mapa em grafo

A expedição é um grafo pequeno em **camadas**, à Slay the Spire / FTL, visto
no ecrã do barco. Cada camada tem 2–3 nós; cada nó é *ilha + missão +
modificador*, e o jogador vê os três antes de escolher.

```text
Camada 0        Camada 1             Camada 2             Camada 3
(início)        (escolha)            (escolha)            (final)

                ┌─ Shadow Forest ─┬─ High Cliffs ──┐
Dawn Beach ─────┤  Destroy Nests  │  Hold Zone     │
 Salvage        │  [Fog]          │  [Elite Hunt]  ├──── Volcano Peak
 (tutorial)     │                 ╳                │      Boss + extração
                └─ High Cliffs ───┴─ Shadow Forest ┘
                   Activate 3        Carry
                   [Double Loot]     [Night]
```

Regras do grafo:

- **4 camadas** no vertical slice: Dawn Beach → escolha → escolha → Volcano
  Peak. Mais tarde 5 (com uma ilha nova ou uma repetição com outro template).
- Cada nó mostra **ilha, template, modificador e recompensa** do nó. Escolha
  sem informação não é escolha ("cada ilha é uma decisão").
- Cada nó liga a **1–2 nós** da camada seguinte; nunca a todos, senão a rota
  deixa de importar.
- A mesma ilha pode aparecer em camadas diferentes com template diferente. Com
  4 ilhas, isto é o que dá variedade sem mapas novos.
- O grafo é gerado por **seed** a partir de tabelas (ilhas permitidas por
  camada, templates permitidos por ilha). Determinístico: a mesma seed dá a
  mesma expedição, o que ajuda testes e partilha.
- A camada final é sempre Volcano Peak (boss + extração).

### 1.2 Durações-alvo

| Unidade | Alvo | Notas |
|---|---|---|
| Atravessar uma ilha em linha reta | 60–90 s | herdado do original; confirma o tamanho de 150–250 m |
| Uma ilha completa | **4–6 min** | chegar (≈30 s) → explorar (1–2 min) → missão com evento (2–3 min) → saída (≈30 s) |
| Ecrã do barco | 30–60 s | sem relógio; o diretor pausa |
| Run completa | **20–25 min** | 3 ilhas + boss ≈ 4 × 5 min + barco; cabe no pitch "25 minutos" |
| Run com extração antecipada | 8–15 min | uma ou duas ilhas e sair |

A pressão vem do **diretor** (crescer → pico → alívio), não de um relógio
global apertado. O relógio aparece só em templates que o pedem (Salvage).

### 1.3 Extração antecipada vs continuar

Depois de cada ilha, no barco, o jogador escolhe:

- **Continuar**: escolhe o próximo nó. Mais Intel no fim, mas morrer na
  ilha seguinte perde os bónus de conclusão acumulados.
- **Extrair**: termina a run com sucesso parcial.

Proposta de regras (sem Scrap; a meta-moeda é **Intel**, e morrer conserva o
Intel já ganho, conforme a resposta 7 do utilizador):

| Situação | Intel |
|---|---|
| Intel recolhido nas ilhas (caches, elites, objetivos) | sempre conservado, morrendo ou não |
| Bónus de conclusão por ilha | só se a run terminar por extração (antecipada ou final) |
| Extração final (boss derrotado) | bónus de conclusão × 1,5 + desbloqueio de "vitória" |

Assim, morrer não apaga o esforço (o utilizador pediu isto), mas extrair
continua a valer a pena e continuar é uma aposta real. Os números exatos vêm
do playtest.

---

## 2. Ilhas como cenas compactas (150–250 m)

Cada ilha é **uma cena Godot** própria, carregada ao desembarcar. Só existe
uma ilha em memória: navegação (flow field), spawns e orçamento de horda são
locais. Isto remove de raiz os problemas do original com streaming, ferries
e ilhas distantes a ocupar o diretor.

Tamanho: 150–250 m de lado jogável, com mar à volta como limite natural
(sem paredes invisíveis à vista).

### 2.1 Regras de layout para câmara média

A câmara média (~35°, ~10 m, FOV ~60°, parâmetros finais pelo spike
`camera_medium`) vê aproximadamente 20–25 m à frente e pouco atrás. O layout
tem de compensar isso.

**Legibilidade**

1. **Chão legível**: caminhos com material/cor distintos do terreno de
   ataque; o jogador lê "por aqui corre-se" sem HUD.
2. **Objetivos com cor reservada** (p. ex. amarelo/âmbar só para objetivos,
   vermelho só para perigo). Nunca usar estas cores em dressing.
3. **Silhuetas de inimigos acima do ruído**: vegetação baixa (< 0,6 m) na
   maior parte da área jogável; nada que esconda uma cápsula de 1,8 m nos
   corredores de combate.

**Oclusão**

4. **Objetos altos (> 3 m) longe dos corredores**, ou com fade/recorte quando
   ficam entre a câmara e o jogador. Regra prática: num raio de ~6 m dos
   caminhos principais, só objetos baixos ou que tenham recorte.
5. **Nada de tetos** sobre áreas jogáveis, exceto interiores curtos e
   marcados (gruta, túnel) com câmara que se aproxima.
6. **Falésias e paredes atrás do jogador** (do lado da câmara) são
   proibidas nos corredores principais; usam-se do lado oposto, onde
   enquadram em vez de taparem.

**Rotas de fuga**

7. **Nunca um beco sem saída** (regra do original): cada área de combate tem
   ≥ 2 saídas. Se for preciso um beco, marca-se (portão, rochas) e fica fora
   dos encontros.
8. **Regra dos 3 segundos** (do original): de qualquer ponto, uma rota de
   fuga está a ~3 s de corrida (~15–18 m).
9. **Laços (loops)**: cada zona de missão fica dentro de pelo menos um laço
   que se pode contornar com a horda atrás ("kiting"). Um laço por zona de
   missão é o mínimo; é o que torna 150 zombies jogáveis.
10. **Estrangulamentos opcionais**: pontes, desfiladeiros e portões onde o
    jogador pode *escolher* segurar a horda; nunca obrigatórios para avançar.

**Ritmo aberto/fechado**

11. Alternar **aberto** (clareira, praia, planalto: horda espalha-se, armas de
    alcance valem) e **fechado** (trilho, desfiladeiro, ruínas: horda
    concentra-se, shotgun/explosivos valem). Alvo do original: ~60 %
    obstruído / 40 % aberto por zona, ajustado por ilha.
12. Os eventos de horda acontecem em **zonas abertas com bordas fechadas**:
    espaço para o breaker e para kiting, entradas da horda legíveis.

**Landmarks**

13. **3 landmarks por ilha**, visíveis de quase toda a ilha e com silhueta
    única. Servem orientação sem HUD e dão nome às zonas ("vai à torre").
14. A **saída (cais/barco)** é sempre um landmark, visível ou indicada pelo
    som/luz, para a retirada nunca depender do minimapa.

**Spawns**

15. Spawns **fora do ecrã** (com câmara média, > ~25 m e fora do frustum) e
    nunca no caminho de regresso ao barco nos primeiros 30 s.
16. Pontos de spawn em anel na periferia da ilha + "tocas" temáticas
    (água, grutas, ruínas) que o jogador aprende a ler.

### 2.2 Estrutura-tipo de uma ilha

```text
         [Landmark 2]
   zona B (fechada) ── zona C (aberta, missão)
        │      ╲            │   ╲
        │       laço        │    [Landmark 3]
        │      ╱            │
   zona A (aberta) ──── caminho secundário
        │
   CAIS / BARCO  [Landmark 1]   ← chegada e saída
```

3–4 zonas, cada uma com 2+ ligações. A missão usa 1–3 zonas; o resto é
exploração com caches e elites opcionais.

---

## 3. Templates de missão

Cada template define fases, sucesso/falha, um **evento de horda** (o pico do
diretor) e uma recompensa. A ilha fornece os "sockets" (pontos marcados na
cena onde o template coloca objetos); o template não conhece a ilha.

Regra comum: **a missão nunca termina a run por si só** exceto se o jogador
morrer. Falhar uma missão significa perder a recompensa e voltar ao barco
com menos, não um ecrã de game over.

### 3.1 Hold Zone (segurar zona)

- **Fases:** chegar ao círculo → ativar → segurar 90 s (barra só avança com
  o jogador dentro) → zona estabiliza.
- **Sucesso:** barra a 100 %. **Falha:** morte (sair só pausa).
- **Evento de horda:** ondas contínuas a partir de 3 direções marcadas;
  Screamer aos 50 %.
- **Recompensa:** 1 carta à escolha de 3 + Intel.
- **Porquê:** é o teste mais puro de "romper a horda" e do breaker.

### 3.2 Activate 3 (ativar três)

- **Fases:** três terminais espalhados; cada um carrega 20 s com o jogador
  perto (afastar-se pausa, dano interrompe, como os relés do original).
- **Sucesso:** 3/3. **Falha:** morte.
- **Evento de horda:** cada ativação chama uma vaga; a terceira é o pico.
- **Recompensa:** atalho/bónus na ilha + carta.
- **Porquê:** obriga a atravessar a ilha e a escolher a ordem.

### 3.3 Destroy Nests (destruir ninhos)

- **Fases:** 3–4 ninhos com vida; cada ninho produz inimigos enquanto existe.
- **Sucesso:** todos destruídos. **Falha:** morte.
- **Evento de horda:** ao destruir metade, os restantes "acordam" e geram
  mais depressa; o último tem um Armored de guarda.
- **Recompensa:** arma especial (munição limitada) ou carta.
- **Porquê:** objetivo agressivo; recompensa quem ataca em vez de fugir.

### 3.4 Carry (transportar)

- **Fases:** apanhar a carga → levá-la ao barco/ponto. Com carga: sem
  disparar com a arma principal (só breaker e habilidade) ou velocidade
  reduzida, a decidir no playtest. Largar é possível.
- **Sucesso:** carga entregue. **Falha:** carga destruída (tem vida) ou morte.
- **Evento de horda:** ao apanhar, horda em perseguição; Grabbers tentam
  roubar a carga.
- **Recompensa:** grande (Intel elevado ou evolução de arma).
- **Porquê:** muda o verbo — o jogador foge através da horda em vez de a
  enfrentar. Humor DRG: a carga pode ser algo ridículo (um barril de cerveja
  da tripulação).

### 3.5 Hunt Elite (caçar elite)

- **Fases:** pistas (rastos, gritos) → encontrar o elite → combate → recolher
  o troféu.
- **Sucesso:** elite morto. **Falha:** morte; o elite foge para outra zona
  se perder 50 % e o jogador o perder de vista (não é falha, é perseguição).
- **Evento de horda:** o elite chama horda a cada terço de vida.
- **Recompensa:** carta rara/evolução.
- **Porquê:** mini-boss; prepara o boss do vulcão.

### 3.6 Salvage (contra o relógio)

- **Fases:** naufrágio com 5–8 caixas; relógio de 3 min até a maré/tempestade
  fechar a zona → regressar ao barco.
- **Sucesso:** voltar ao barco antes do fim (com as caixas que houver).
  **Falha:** não há; menos caixas = menos recompensa. Ficar de fora quando o
  relógio acaba = horda máxima até chegar ao barco.
- **Evento de horda:** intensidade cresce com o relógio; últimos 30 s em pico.
- **Recompensa:** proporcional às caixas (Intel + escolha de 1 de 3).
- **Porquê:** ganância vs segurança dentro da ilha; bom template de tutorial
  (Dawn Beach) porque não falha.

### 3.7 Defend the Boat (defender o barco)

- **Fases:** o barco fica avariado no cais → reparar 3 peças (recolhidas
  perto) → defender durante a reparação final (60 s).
- **Sucesso:** reparação completa. **Falha:** barco destruído = sai-se na
  mesma, mas com a próxima ilha com penalização (p. ex. sem escolha 1 de 3).
  Nunca soft-lock.
- **Evento de horda:** horda converge no cais; Bloaters contra o casco.
- **Recompensa:** escolha extra no próximo ecrã do barco.
- **Porquê:** dá peso ao barco como "base" sem sistema de construção.

### 3.8 Volcano Finale (só Volcano Peak)

- **Fases:** desativar 3 selos (Activate 3 curto) → arena do boss → boss →
  correr ao ponto de extração com a horda final.
- **Sucesso:** chegar à extração. **Falha:** morte.
- **Evento de horda:** cada selo é uma vaga; durante o boss, adds limitados;
  depois do boss, "horda final" sem limite de tempo até à extração.
- **Recompensa:** fim da run com bónus de vitória.
- Como no original: **nem o relógio nem a morte do boss terminam a run
  sozinhos** — termina-se ao chegar à extração.

### 3.9 Resumo

| Template | Verbo | Duração | Pode falhar sem morrer? | Slice? |
|---|---|---|---|---|
| Salvage | recolher/decidir | 3 min | não (recompensa parcial) | ✅ tutorial |
| Hold Zone | segurar | 2–3 min | não | ✅ |
| Activate 3 | atravessar | 3 min | não | depois |
| Destroy Nests | atacar | 2–4 min | não | depois |
| Carry | fugir | 2–3 min | sim (carga destruída) | depois |
| Hunt Elite | perseguir | 2–3 min | não | depois |
| Defend the Boat | defender | 3 min | sim (penalização) | depois |
| Volcano Finale | tudo | 5–6 min | não | versão curta |

O vertical slice (1 ilha, 1 missão) precisa só de **Hold Zone** ou
**Salvage**. Recomendo Hold Zone: testa breaker, Grabber e diretor de uma vez.

---

## 4. Fichas das ilhas

### 4.1 Dawn Beach — "o recrutamento"

- **Identidade:** praia ao amanhecer, destroços da tripulação anterior, horda
  ligeira. Ilha de ensino e de arranque da run. Cores quentes e claras.
- **Zonas:** cais (chegada), praia larga (aberta), dunas com vedações
  (fechada), farol/acampamento abandonado (missão).
- **Landmarks:** farol, navio encalhado, torre de sinalização (herdada do
  original).
- **Missões:** Salvage (por omissão: tutorial que não falha), Hold Zone.
- **Inimigos-tema:** normais e Runners; sem especiais na primeira visita.
- **Do original:** a praia e a ideia de "escolha de rota" saem daqui; o
  acampamento com tiers **não** (secção 5).
- **Humor:** o último expedicionário deixou notas passivo-agressivas nos
  caixotes.

### 4.2 Shadow Forest — "controlo e emboscada"

- **Identidade:** pântano, nevoeiro, vegetação densa, linhas de visão curtas,
  Spitters. Sons como aviso antes da imagem.
- **Zonas:** trilho de tábuas (fechado, laço), clareira da cripta (aberta),
  estação de bombagem (mista), margem do pântano (lenta: água abranda todos).
- **Landmarks:** árvore morta gigante, cripta submersa, Rope Bridge.
- **Missões:** Destroy Nests (herdada), Hunt Elite, Carry.
- **Layout:** a densidade é cenário, não corredor: a vegetação alta fica
  *fora* dos caminhos (regra 4); o nevoeiro é luz/cor, não oclusão real.
- **Do original:** ninhos que se abatem, ponte que pode cair mas tem sempre
  reparação (regra anti-soft-lock).

### 4.3 High Cliffs — "posição e alcance"

- **Identidade:** planaltos em degraus, vento, visibilidade longa, menos
  inimigos mas a chegar de mais longe. Recompensa armas de alcance.
- **Zonas:** pedreira (aberta, baixa), comboio militar acidentado (fechada),
  plataformas dos relés (elevadas, ligadas por rampas), gruta lateral (atalho).
- **Landmarks:** torre de vigia, comboio tombado, entrada das ruínas antigas.
- **Missões:** Activate 3 (relés em alturas diferentes, herdado), Hold Zone
  num planalto, Defend the Boat.
- **Layout:** cuidado com a câmara média — falésias sempre do lado oposto à
  câmara; desníveis lidos por sombras e cor. Rampas largas (≥ 4 m) para a
  horda não engarrafar de forma invisível.
- **Do original:** relés que carregam e não se perdem depois de ativos.

### 4.4 Volcano Peak — "o fim"

- **Identidade:** rocha escura, lava como fronteira (não como armadilha
  escondida), céu vermelho. Sem descanso: o diretor começa mais alto.
- **Zonas:** desembarque (curto, seguro 20 s), três condutas/selos à volta da
  cratera, arena do boss (aberta e circular com pilares para quebrar linha
  de visão), ponto de extração do lado oposto ao cais.
- **Landmarks:** a cratera (visível de todo o lado), a torre de extração, o
  rio de lava.
- **Missões:** Volcano Finale (sempre). Modificadores podem variar.
- **Do original:** sequência selos → arena → boss → horda final → extração;
  o boss "The Breaker" pode manter o nome (piada sobre o título).

### 4.5 Ilhas futuras (não no slice)

Ironworks, Mourning Isle e Shipwreck Rocks do original ficam como reserva:
só entram quando as quatro acima estiverem divertidas. Shipwreck é natural
para Salvage; Mourning para Hunt Elite.

---

## 5. Base: três opções

| | Acampamento com tiers | **Barco como base móvel** | Sem base |
|---|---|---|---|
| O que é | Dawn Beach com 4 tiers, torres, Scrap (o original) | Ecrã/menu entre ilhas: escolhe 1 de 3, cura, ver o grafo, extrair | Ilhas seguidas; recompensas só dentro das ilhas |
| Serve os pilares? | "Cada ilha é uma decisão" fica diluído: o jogador volta ao centro | Sim: o barco é o momento da decisão de rota e de build | Parcialmente: perde-se o momento de pausa e escolha |
| Custo de produção | Muito alto: construção, navegação dinâmica, arte, balanceamento, uma moeda | Baixo: um ecrã de UI, sem 3D novo obrigatório | Mínimo |
| Risco (lições do original) | Já foi um sistema órfão; "dois jogos num" | Baixo; pode crescer (barco 3D, tripulação) se fizer falta | Run sem ritmo de alívio |
| Ritmo | Pausa longa na base | Pausa curta e controlada (30–60 s) | Nenhuma pausa |
| Encaixa no "sem Scrap"? | Não: depende do Scrap | Sim: escolhe 1 de 3 | Sim |

**Recomendação: barco como base móvel, em forma de ecrã** (alinhado com a
preferência do utilizador). Conteúdo do ecrã do barco:

1. **Resultado da ilha** (curto: o que ganhaste).
2. **Escolhe 1 de 3**: tipicamente uma carta, uma arma especial e uma cura;
   modificadores podem trocar a oferta.
3. **Mapa da expedição**: escolher o próximo nó.
4. **Extrair ou continuar** (secção 1.3).

Sem construção, sem moeda da run. Humor: o barco tem um capitão rabugento que
comenta as escolhas (texto curto, à DRG Mission Control). Mais tarde, se o
playtest pedir, o barco pode ganhar um cenário 3D simples — sem mudar a
mecânica.

---

## 6. Modificadores de ilha

Um modificador por nó (visível no grafo). Cada um muda **como** se joga, não
só números. A recompensa sobe com os modificadores negativos.

| # | Modificador | Efeito | Muda o jogo porque… |
|---|---|---|---|
| 1 | **Fog** | visibilidade reduzida, indicadores de borda mais fortes | joga-se pelo som e pela borda do ecrã |
| 2 | **Night** | só luz do jogador e de objetos; inimigos com olhos visíveis | landmarks iluminados tornam-se essenciais |
| 3 | **Screamer Colony** | mais Screamers | prioridade de alvo; matar primeiro |
| 4 | **Armored Patrol** | Armored mais comuns | posicionamento por trás / explosivos |
| 5 | **Low Tide** | caminhos extra pela praia/água | mais laços de fuga; rota diferente |
| 6 | **Volatile** | barris explosivos espalhados (inimigos também os rebentam) | usar o terreno contra a horda; risco para o jogador |
| 7 | **Elite Hunt** | um elite errante extra com recompensa | objetivo opcional dentro da missão |
| 8 | **Double Loot** | caches dão o dobro, horda +25 % | ganância explícita |
| 9 | **Rushed** | relógio global de 4 min na ilha | estilo Salvage em qualquer template |
| 10 | **Quiet** | horda mais pequena, sem caches | ilha de "descanso" para recuperar |

Para o slice basta **nenhum modificador**; os primeiros a implementar são
Fog (visual + teste aos indicadores) e Double Loot (só números).

Mais tarde, o nível de dificuldade (Hazard do DRG) pode significar
"modificadores obrigatórios por nó".

---

## 7. Decisões propostas e perguntas

### 7.1 Decisões propostas

1. **Expedição em grafo de 4 camadas** (Dawn Beach → escolha → escolha →
   Volcano Peak), nós com ilha + template + modificador visíveis, gerado por
   seed.
2. **Uma cena por ilha, 150–250 m**, só a ilha ativa em memória; sem mundo
   contínuo nem ferries.
3. **Run de 20–25 min**, ilha de 4–6 min; extração antecipada possível em
   cada ecrã do barco.
4. **Intel recolhido conserva-se sempre; bónus de conclusão só ao extrair.**
5. **Templates como sistema**: ilha fornece sockets, template coloca objetos.
   Slice com **Hold Zone** (e Salvage como tutorial de Dawn Beach se houver
   tempo).
6. **Barco = ecrã de serviços** (escolhe 1 de 3, mapa, extrair), sem
   construção, torres nem Scrap. Acampamento com tiers vai para "não vamos
   fazer".
7. **Regras de layout da secção 2.1** como checklist de cada ilha (sobretudo
   laços, regra dos 3 s, objetos altos fora dos corredores, 3 landmarks).
8. **Modificadores** entram depois do slice, começando por Fog e Double Loot.

### 7.2 Perguntas para o utilizador

1. **Ilha do slice:** Dawn Beach (fácil de ler, praia aberta) ou Shadow
   Forest (mais identidade, mas testa oclusão mais cedo)? Proponho Dawn Beach
   com Hold Zone.
2. **Carry:** com a carga nas mãos, o jogador não dispara (mais tenso) ou
   anda mais devagar (mais simples)?
3. **Falhar uma missão** deve ser possível sem morrer (Carry, Defend the Boat)
   ou preferes que todas as missões só falhem com a morte?
4. **Extração antecipada**: o bónus de conclusão perde-se ao morrer — parece
   justo, ou preferes que morrer conserve tudo?
5. **Rejogar a mesma ilha** na mesma run com outro template (p. ex. High
   Cliffs duas vezes) é aceitável, ou cada ilha só uma vez por run?
6. **Capitão do barco** com falas humorísticas: queres uma personagem fixa
   (à Mission Control do DRG) ou só texto neutro por agora?
7. **Ilhas extra** (Ironworks, Mourning, Shipwreck): ficam reservadas para
   depois, ou cortamos já para a lista "não vamos fazer"?

## Gráficos da cena: estrada, bioma e praia (2026-10-24)

- **Estrada no preset horror:** só o preset horror a escurece (asfalto quase
  escuro: asfalto de albedo 0,30, luminância perto de 0,30; antes 0,20). Nas ilhas normais fica como estava. O céu e o
  nevoeiro não mudam. As ilhas feitas à mão têm a estrada em malhas
  (`Roads/Surface`); as geradas usam o gestor de estradas do addon. Ambas passam por
  `IslandRoads.darken()`, chamada em `Island._ready()` depois de `_build_world()`.
- **Luz do preset horror:** a luz ambiente da cena sobe de 1,0 (o valor do Sky3D) para 1,3
  (`HORROR_AMBIENT_ENERGY`, em `game/world/island.gd`). Na captura da `beach_01` no mesmo
  enquadramento, a média de luminância passou de 15,6 % para 15,9 % (estrada 13,1 % para
  13,7 %, figura 15,9 % para 16,3 %). Com 1,6 foi 16,1 %: neste caminho a luz ambiente dá
  pouco. A causa da imagem ainda escura não está verificada (a contribuição do céu do
  Sky3D ou a contra-luz são hipóteses). A exposição fica em 1,0 (`Visuals.apply_post`),
  por isso não foi ajustada.
- **Cor por bioma, discreta:** a gradação de cada bioma (`game/data/biomes/*.tres`)
  tem tintas até 0,25. O porto fica cinzento (tintas abaixo de 0,1), o vulcão laranja
  com sombras escuras, a praia quente e clara, a selva fria e verde. Só muda a cor;
  texturas e a legibilidade dos avisos ficam iguais. Os valores são propostas a
  confirmar no editor.
- **Vegetação rasteira na praia:** erva e seixos em dois MultiMesh
  (`game/world/beach_vegetation.gd`). No máximo 400 instâncias num raio de 60 m do
  jogador, em chão aberto do bioma (sem estrada, pontes, edifícios nem água; a pintura do terreno não é lida). Os locais são
  sorteados uma vez por ilha, com seed fixa, por isso não tremem ao andar. Desligada
  no preset Low. Medido em headless (`tests/test_scenery_graphics.gd`): mapa de praia com
  estradas marcadas 231 ms (inclui o plano das estradas), construção da vegetação
  6,9 ms, colocação 0,35 ms, 400 instâncias (301 erva, 99 seixos) de 2400 locais. O custo de frame na GPU não foi medido. A vegetação vale para as ilhas geradas e para as
  feitas à mão: `Island._build_beach_cover()` é chamada em `_build_world()`, depois de o
  chão e as estradas estarem no mapa, nos dois caminhos. Na `beach_01`
  (`tests/test_beach_cover_handmade.gd`): 2400 locais, nenhum sobre estrada, deck, edifício
  ou água; 400 instâncias no raio (299 erva, 101 seixos). Uma ilha de selva feita à mão
  não tem vegetação.
