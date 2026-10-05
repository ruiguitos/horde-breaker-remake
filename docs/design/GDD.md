# Horde Breaker — GDD v2 ("Expedition Breaker")

Estado: **proposta** (2026-10-05). Baseia-se em `docs/DECISIONS.md`, no
`BRAINSTORM.md` (incluindo as respostas do utilizador, secção 10) e nos
documentos de `docs/legacy/`. O que aqui está só passa a decisão quando o
utilizador o registar em `DECISIONS.md`. Este documento é a fonte única para
visão, pilares e loops; detalhes de sistemas vão para documentos próprios.

## 1. Pitch e high concept

**Pitch:** *Atravessa um arquipélago infestado de barco, cumpre a missão de
cada ilha e rompe a horda até à extração, numa expedição de 25 minutos.*

**High concept:** Horde Breaker é um horde shooter single-player com câmara
média, para PC. O jogador é um soldado de uma empresa de "recuperação de
ativos" pouco escrupulosa, largado num arquipélago tomado por zombies. A arma
dispara sozinha contra o alvo mais próximo; o trabalho do jogador é
**posicionar-se, escolher para onde olhar** (cabeça ou corpo, especial ou
massa) e **investir pela horda** com o *breaker* quando ela fecha o caminho.
Entre ilhas, o barco serve de ecrã de serviços: escolhe 1 de 3 recompensas e
a próxima ilha no mapa da expedição. Morrer acaba a run, mas o **Intel**
recolhido fica e desbloqueia perks, armas e dificuldades. Tom: humor de
empresa cínica ao estilo Deep Rock Galactic, zombies de cápsula que perdem
pedaços.

## 2. Pilares

| Pilar | O que significa | O que exclui |
|---|---|---|
| **1. Romper a horda** | A horda é terreno que se move. O jogador lê-a, escolhe a abertura e atravessa-a com o breaker; o auto-fire trata do "quem", o jogador trata do "onde" e do "quando". Headshots e especiais recompensam atenção. | Sprint, cobertura, stealth, munição escassa que obrigue a contar balas, armas melee, combate que se ganha parado num canto. |
| **2. Cada ilha é uma decisão** | Rota, risco e recompensa são escolhidos no barco antes de cada ilha; dentro dela, desvios opcionais anunciam o que dão. Ilhas compactas, legíveis, com uma missão clara. | Mundo aberto, mapa contínuo gigante, exploração sem objetivo, construção de base, torres, acampamento com tiers. |
| **3. Builds que mudam a forma de jogar** | Cartas e perks alteram **comportamento** (o breaker deixa fogo, cada 5.º tiro ricocheteia), não só números. Poucas camadas: cartas na run, perks em slots e Intel na meta. | Skill trees de dezenas de nós, várias moedas, "+5% dano" como recompensa principal, mastery, variantes de classe no slice. |

Regra: uma feature que não sirva um pilar vai para a lista "não vamos fazer".

## 3. Core loops

| Loop | Ações | Decisões do jogador | Recompensa |
|---|---|---|---|
| **30 s — combate** | Mover; o auto-fire dispara; apontar o cursor/stick para orientar o foco; breaker (investida com cooldown); recolher orbes de XP. | Para onde vou? Foco na cabeça do alvo próximo ou no especial ao fundo? Gasto o breaker agora para sair do cerco ou guardo-o para o Grabber? | Zombies a desfazer-se, orbes, cartas ao subir de nível; sensação de abrir caminho. |
| **5 min — ilha** | Desembarcar → seguir até ao objetivo → evento de horda (p. ex. Hold Zone) → voltar ao barco. Desvio opcional com recompensa anunciada. | Faço o desvio (mais XP/Intel, mais tempo e risco) ou vou direto? Que carta escolho ao subir de nível? | Missão cumprida, Intel da ilha, uma ou duas cartas novas. |
| **25 min — run** | Barco → mapa em grafo → 3 ilhas → ilha final com boss → extração. Entre ilhas: ecrã do barco com "escolhe 1 de 3" (carta, arma, cura). | Que rota (ilhas com modificadores diferentes)? Cura agora ou arma nova? Extraio cedo com menos Intel ou arrisco a ilha final? | Extração = bónus grande de Intel; morte = conserva o Intel já recolhido. |
| **Meta — entre runs** | Gastar Intel em desbloqueios; equipar perks nos slots; escolher dificuldade. | Que perks equipo (poucos slots)? Desbloqueio arma nova ou slot de perk? Subo a dificuldade? | Mais opções (não mais poder bruto): armas, perks, classes futuras, níveis de dificuldade. |

## 4. Fantasia, público, plataforma e sessão

- **Fantasia:** "Sou o contratado que entra onde mais ninguém entra, abre
  caminho à força por uma parede de mortos-vivos e sai com os dados — com
  piadas de escritório pelo rádio."
- **Público-alvo:** primeiro, o próprio autor (projeto a solo, por
  divertimento). Depois, jogadores de DRG Survivor, Vampire Survivors e
  Helldivers que gostam de runs curtas mas querem mais posicionamento do que
  um survivors clássico.
- **Plataforma:** PC Windows. Teclado/rato (WASD + cursor para foco, espaço
  ou botão direito para breaker) e comando (stick esquerdo move, direito
  orienta o foco, gatilho para breaker). Os dois são de primeira classe desde
  o slice; o auto-fire torna o comando natural.
- **Sessão-alvo:** run de 20–30 min; ilha de 5–8 min. Deve ser possível parar
  no ecrã do barco (save simples entre ilhas — ver 6.7).

## 5. Âmbito do vertical slice

Objetivo: **10 minutos divertidos em grey-box** (primitivas Godot, sem assets
externos) antes de qualquer outro conteúdo.

- **1 ilha** compacta (~150–200 m), 3 landmarks, chegada e saída de barco.
- **1 classe:** Recruit — vida média, passiva simples (recarga rápida).
- **3 armas:** Assault Rifle (base, munição infinita), Shotgun (cone,
  empurra), uma arma de comportamento (p. ex. rifle que penetra). Uma de cada
  vez + troca por recompensa.
- **4 inimigos:** Normal (massa), Runner (rápido, frágil), Brute (tanque,
  knockback, ponto fraco) e **Grabber** (agarra o jogador; o breaker solta-o).
- **1 missão:** Hold Zone (ficar num círculo X segundos durante evento de
  horda), depois extração ao barco.
- **Sistemas mínimos:** auto-fire com zonas cabeça/corpo, breaker, orbes de
  XP + ~8 cartas (⅔ de comportamento), diretor de horda com orçamento
  (~80–150 ativos, número final pelo spike S2), desmembramento simples,
  HUD mínimo com indicadores na borda do ecrã, ecrã do barco com 1 de 3,
  Intel contado no fim (gastar Intel pode ficar para depois do slice).

### Não vamos fazer (e porquê)

| Fora | Porquê |
|---|---|
| Construção, torres, acampamento com tiers | Foi o maior sistema órfão do original; não serve nenhum pilar. O barco é um ecrã. |
| Scrap / moeda na run | Uma moeda a menos para equilibrar e explicar; "escolhe 1 de 3" dá a decisão sem economia. Reavaliar só se os playtests pedirem gastos na run. |
| Skill tree grande, mastery, variantes | Camadas de "+X%" que diluíam as escolhas. Perks em slots chegam. |
| Sprint, salto, agachar, cobertura | O breaker é o verbo de mobilidade; o resto não serve o pilar 1. |
| Mundo aberto, streaming, Terrain3D, 7 ilhas | Mundo grande demais para o conteúdo. Ilhas como cenas separadas. |
| Multiplayer / co-op | Rede é cara e o autor está a aprender. Single-player só. |
| Mais classes no slice | Primeiro provar o Recruit. Classes futuras partilham o breaker. |
| Armas melee | O original já as cortou; o breaker cobre o contacto. |
| Barco controlável, física naval | Viagem é transição de ecrã. |
| Arte/animação final, assets externos | Grey-box com primitivas até o slice ser divertido. |
| Narrativa com cutscenes | O humor vive no rádio e no texto curto do barco. |

## 6. Decisões propostas

Para cada ponto em aberto em `docs/DECISIONS.md`. Todas assumem a câmara
média já decidida.

### 6.1 Direção do jogo
- **A+B "Expedition Breaker"** — leitura da horda da câmara média, escala
  intermédia, posicionamento e headshots. *Prós:* casa com a câmara e com as
  respostas. *Contras:* género híbrido, exige afinar bem o auto-fire.
- **A puro (survivors)** — *Prós:* mais simples. *Contras:* saturado; a
  câmara média desperdiça-se.
- **B puro (tático)** — *Prós:* tensão. *Contras:* IA e animação caras, pede co-op.

**Recomendação: A+B**, tal como o utilizador respondeu.

### 6.2 Mira e headshots (auto-fire é o normal)
- **a) Foco por cursor:** o auto-fire escolhe o alvo mais próximo **do
  cursor/stick direito** dentro do alcance; se o cursor está sobre a cabeça
  (zona visível maior no ecrã), o tiro vai à cabeça. *Prós:* o jogador
  controla "quem" e "onde" sem premir gatilho; funciona em comando.
  *Contras:* precisa de afinar raio de captura na câmara média.
- **b) Auto-fire ao mais próximo + chance de headshot por stat:** *Prós:*
  trivial. *Contras:* headshots viram número, não habilidade (pilar 1 perde).
- **c) Auto-fire ao corpo + botão "tiro focado" manual à cabeça:** *Prós:*
  skill explícita. *Contras:* dois modos de disparo, volta o conflito do original.

**Recomendação: a)**, validada num spike de mira com a câmara média.

### 6.3 Escala da horda
- **~80–150 ativos com especiais** (Grabber, Brute com contra claro). *Prós:*
  cabe em Godot com MultiMesh/dados; especiais legíveis. *Contras:* menos
  "mar de zombies".
- **200–500 (survivors).** *Prós:* espetáculo. *Contras:* técnica arriscada
  para quem começa; inimigos viram partículas.
- **30–80 inteligentes.** *Prós:* tensão. *Contras:* pede IA cara.

**Recomendação: 80–150**, número final fixado pelo spike S2 (FPS medido).

### 6.4 Base
- **Barco como ecrã de serviços** (1 de 3, mapa da rota, cura). *Prós:* zero
  construção, ritmo entre ilhas, save natural. *Contras:* menos "lar".
- **Barco percorrível 3D** com estações. *Prós:* imersão. *Contras:* mais
  cena, mais UI no mundo.
- **Sem base** (só mapa). *Prós:* mínimo. *Contras:* perde a pausa logística.

**Recomendação: barco como ecrã**; um barco percorrível pode vir depois.

### 6.5 Pilares e pitch
- **Os três da secção 2** com o pitch da secção 1. *Prós:* derivam do título
  e das respostas. *Contras:* pilar 3 compete com o "menos camadas".
- **Trocar o pilar 3 por "Humor de empresa cínica".** *Prós:* identidade.
  *Contras:* tom não decide features de gameplay.

**Recomendação: os três da secção 2**; o tom fica como diretriz de estilo.

### 6.6 Contexto do projeto
- **Aprendizagem por divertimento, sem prazo**, marcos por spike/slice.
  *Prós:* honesto com a realidade. *Contras:* risco de deriva sem marcos.
- **Alvo Steam a longo prazo.** *Prós:* motivação. *Contras:* pressão de
  âmbito cedo demais.

**Recomendação: a primeira**, com marcos (spikes → slice → playtest) e Steam
só reavaliado depois de o slice ser divertido.

### 6.7 Extra (resultantes das respostas)
- **Economia:** cortar Scrap; run = XP→cartas + barco 1 de 3; meta = Intel.
- **Breaker:** investida curta (~4–6 m) que empurra e atordoa, solta de
  Grabber, cooldown ~6 s; igual para todas as classes; cartas modificam-na.
- **Save:** só entre ilhas (no barco) e na meta. Recomendado pela sessão-alvo.

## 7. Perguntas para o utilizador

1. Confirmas os três pilares e o pitch como estão, para irem para `DECISIONS.md`?
2. Mira por foco de cursor (6.2 a) parece-te bem, ou preferes outro modelo de headshot?
3. Confirmas o corte do Scrap no slice e o barco com "escolhe 1 de 3"?
4. A arma base tem munição infinita? (proposta: sim; armas especiais com munição limitada mais tarde)
5. Breaker: em teclado/rato preferes espaço ou botão direito?
6. Missão do slice: Hold Zone serve, ou preferes Carry / Destroy Nests?
7. Gastar Intel entra já no slice ou só depois de o combate estar divertido?
8. Queres poder parar a meio de uma run (save no barco) logo desde o início?
