# Expedição Berlenga

A Berlenga Grande (`tools/real_island/`, 1,5 km) deixa de ser uma ilha do
sorteio da rota Beach. Passa a ser uma **viagem completa em 4 partes**, que
se percorrem a pé de uma para a outra.

## Decidido pelo utilizador (2026-10-08, na conversa)

- **Divisão:** a ilha principal divide-se em quatro partes.
- **Transição a pé, sem barco:** a saída de cada parte é um caminho real até
  à seguinte. Ao chegar lá há um carregamento curto, e a parte seguinte
  começa com a vida, as armas e as cartas que o jogador tinha.
- **Viagem completa:** escolher a Berlenga é fazer as 4 partes seguidas,
  cada uma com o seu objetivo, e a última tem o final. Fica ao lado das
  viagens atuais por várias ilhas.

Decisão registada em `docs/DECISIONS.md` a 2026-10-11, por pedido explícito
do utilizador.

**Porquê:** com 1,5 km, uma missão é demasiado longa. O bot leva 6 minutos
só no Activate, e foi preciso o `horde_radius` e a reciclagem de inimigos.
Partes de 400 a 600 m têm a escala da Hashima, que joga bem. A ilha real dá
um percurso de expedição natural, do desembarque ao forte.

## As quatro partes

Os cortes são do Codex, feitos sobre os caminhos do OSM e o mapa de
alcance. As coordenadas são da ilha, em metros: x para leste, z para sul,
origem a noroeste. Os quatro polígonos cobrem a ilha inteira; o mar e as
falésias continuam bloqueados.

```text
P1 [(650,0),(1466,0),(1466,1466),(880,1466),(880,800),(865,630),(800,540),(650,400)]
P2 [(0,0),(650,0),(650,400),(800,540),(865,630),(880,800),(523,800),(0,800)]
P3 [(0,800),(523,800),(523,850),(500,880),(500,1466),(0,1466)]
P4 [(523,800),(880,800),(880,1466),(500,1466),(500,880),(523,850)]
```

| # | Parte | Entrada → saída (em caminhos do OSM) | Área transitável | Percurso obrigatório | Objetivo |
|---|---|---|---|---|---|
| 1 | **Carreiro do Mosteiro**: o desembarque, o Bairro dos Pescadores e o planalto nordeste | a praia (880, 652) → a estrada 441503021 em (835, 589) | cerca de 240 mil m² | cerca de 540 m | **Rescue**: o sobrevivente no bairro (1011, 720), levado até à saída |
| 2 | **Planalto do Farol**, mais o planalto noroeste | (835, 589) → o caminho 233892909 em (521, 800) | cerca de 256 mil m² | 600 a 700 m | **Activate**: geradores em (710, 633), (675, 674) e (745, 665) |
| 3 | **Costa Sudoeste** | (521, 800) → a ligação 38298331 em (523, 822) | cerca de 171 mil m² | cerca de 420 m | **Hold Sequence**: três miradouros por ordem, `HoldPoint_1` (447, 837), `HoldPoint_2` (408, 918) e `HoldPoint_3` no afloramento (431, 983); depois volta-se à saída, junto ao início |
| 4 | **Forte de São João Baptista** | (523, 822) → o cais do forte (610, 1019) | cerca de 43 mil m² | 300 a 350 m | **Final (holdout)**: defender o pátio (637, 1045) até chegar o barco de resgate, e depois embarcar no cais |

**Caixas, como desvios opcionais:**
- **Parte 1:** (1059, 768) e (909, 560).
- **Parte 2:** (621, 642).
- **Parte 3:** (301, 1052).
- **Parte 4:** (536, 835).

**Notas do Codex:**
- **Costa Sudoeste em vez da Costa Oeste:** o noroeste não tem caminhos que
  suportem uma missão em sequência, por isso fica dentro da parte 2.
- **Ordem 1 → 2 → 3 → 4:** as partes 2, 3 e 4 ligam-se por um triângulo de
  caminhos. Fazer 1 → 2 → 4 tiraria a terceira missão obrigatória.
- **Tamanhos:** as partes 1 e 2 continuam grandes (cerca de 700 m de lado)
  e mantêm o `horde_radius`. O forte é pequeno, como convém a um final.
- **Fronteira 2 ↔ 4:** cruza também o Caminho do Forte (233892907), em
  (559, 800). Essa passagem fica fechada.
- **Portais:** cada passagem entre partes é uma faixa comum de 12 m, ao
  longo do caminho, que pertence às duas partes.
- **Cais:** hoje é só decoração. Passa a ser um tabuleiro transitável em
  `Bridges/`, ligado às escadas.
- **Missões:** o `IslandRun` escolhe hoje o local do Rescue e do Defend pelo
  gerador mais longe do barco. Passa a usar os marcadores `RescueTarget`,
  `DefendZone` e `Exit`. A parte 3 usa `HoldPoint_1..3` (2026-10-11): a
  ida e a volta entre os três pontos obriga a atravessar a horda, em vez de
  ficar parado num só círculo como no Defend.

Estes são os objetivos com os tipos de missão de hoje, mais o final novo.
A nota do utilizador sobre objetivos diferentes em cada mapa pode
substituí-los mais tarde.

## Como funciona (técnico)

- **Um terreno para as 4 partes:**
  - o construtor grava o terreno uma vez e quatro cenas
    `HandmadeIsland` que apontam para a mesma pasta de terreno;
  - as cenas ficam em `game/world/handmade/expeditions/berlenga/`, fora de
    `islands/`, para não entrarem no sorteio.
- **Área jogável:**
  - cada cena tem um polígono `play_area`, e o `build_map` bloqueia as
    células de fora;
  - o resto da ilha continua visível: do forte vê-se o farol;
  - os limites têm de parecer naturais, com muros de pedra solta, rochas e
    escarpas. Uma barreira invisível a meio de um prado não serve.
- **Grelha e horda:** cada parte tem a escala da Hashima, sem
  `horde_radius`.
- **Saída de cada parte:**
  - nas partes 1 a 3, um marcador `Exit` no caminho para a parte seguinte
    faz o papel que o barco tem hoje (chegar lá termina a parte);
  - na parte 4, o barco de resgate no cais.
- **Entre partes:**
  - um ecrã de acampamento substitui o barco, com os mesmos serviços
    (curar, munições, cartas) mas sem escolha de rota;
  - reutiliza o `boat.gd` com outro fundo.
- **Escolha da viagem:** no Armory, START RUN pergunta "Archipelago"
  (a viagem atual) ou "Berlenga Expedition".
- **TEST ISLAND:** lista também as 4 partes, para se testar cada uma.
- **A Berlenga inteira (`beach_berlenga.scn`):** sai da rota Beach. Fica
  como fonte das partes e para o TEST ISLAND.

## Divisão do trabalho (subagentes + Codex)

1. **Subagente A, construtor:**
   - as partes no preset (`parts`: polígono, entrada, saída, objetivo);
   - uma cena por parte com terreno partilhado;
   - os limites naturais;
   - verificar com `check_kits` e `reach.png` que cada parte é jogável.
2. **Subagente B, fluxo da viagem:**
   - `RunContext` com a expedição e a parte;
   - a escolha no Armory e o ecrã de acampamento;
   - o `main.gd`;
   - os testes headless.
3. **Subagente C, missões e saída:**
   - o marcador `Exit` e a extração a pé no `IslandRun`;
   - o objetivo de cada parte e o final no forte;
   - HUD e minimapa.
4. **Codex:** revê os cortes, os objetivos e cada parte.
5. **Claude:** a base comum, a integração, os testes, o bot e o commit.

## Riscos (Codex)

- **Grelha:** a pasta de terreno partilhada poupa espaço em disco, mas cada
  parte continua com uma grelha de 2,1 milhões de células. Carrega-se uma
  cena de cada vez. Mais tarde pode recortar-se a grelha, com origem local.
- **Minimapa:** hoje mostra as células bloqueadas como mar. Tem de separar
  o terreno da máscara da parte, escurecer o exterior e mostrar a `Exit`.
- **Inimigos perto das fronteiras:** o `_spawn_enemy()` já recusa células
  bloqueadas ou inalcançáveis. Falta rever o boss e as invocações.
