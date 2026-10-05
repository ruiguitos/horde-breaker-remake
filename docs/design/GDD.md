# Horde Breaker — GDD v2 ("Expedition Breaker")

Estado: **proposta** (2026-10-05). Baseia-se em `docs/DECISIONS.md`, no
`BRAINSTORM.md` (incluindo as respostas do utilizador na secção 10) e nos
documentos de `docs/legacy/`. Nada aqui é decisão até entrar em
`DECISIONS.md`; os pontos a confirmar estão na secção 6.

## 1. Pitch e high concept

**Pitch:** *Atravessa um arquipélago infestado, escolhe a rota, cumpre a
missão de cada ilha e rompe a horda até à extração — em 25 minutos.*

**High concept:** um horde shooter de expedição para um jogador, visto de uma
câmara média. A arma dispara sozinha contra o inimigo mais próximo; o jogador
decide **onde estar, para onde olhar e quando investir**: posicionar-se para
que o auto-fire acerte nas cabeças, abrir caminho com o *breaker* (uma
investida que atravessa a horda) e escolher entre ilhas, perks e cartas que
mudam a forma de jogar. Cada run é uma pequena viagem de barco por 3–4 ilhas
compactas, com um objetivo por ilha e um boss no vulcão. O tom é o de Deep
Rock Galactic: perigo a sério, humor seco, zombies que se desfazem em
pedaços de cápsula.

## 2. Pilares

| Pilar | O que significa | O que exclui |
|---|---|---|
| **1. Romper a horda** | A horda (~80–150 ativos) é terreno que se move. O jogador lê a massa, procura o ângulo e abre caminho com o breaker. Posicionamento > pontaria fina. | Sprint e esquiva genérica (o breaker é o único movimento especial); mira manual de precisão como requisito; corredores apertados onde não há para onde ir. |
| **2. Cada ilha é uma decisão** | Entre ilhas escolhe-se rota, risco e recompensa num mapa em grafo. Dentro da ilha decide-se ir ao objetivo, explorar ou extrair cedo. | Mundo aberto grande; viagens vazias; ilhas sem objetivo; base fixa a defender. |
| **3. Builds que mudam a forma de jogar** | Cartas e perks alteram *comportamentos* ("o breaker deixa fogo", "cada 5.º tiro ricocheteia"). Poucas, legíveis, combináveis. | Árvores de 50+ nós; dezenas de "+5 %"; várias moedas; mastery/variantes que só mudam números. |

## 3. Core loops

| Loop | Ações | Decisões do jogador | Recompensa |
|---|---|---|---|
| **30 s — combate** | Mover; auto-fire contra o alvo mais próximo; recarregar; breaker (cooldown); apanhar orbes de XP. | Para onde andar para manter a horda à frente; que especial matar primeiro (virar-se para ele muda o alvo); gastar o breaker para fugir, soltar-se de um Grabber ou abrir um grupo. | Feedback físico (hit-stop, desmembramento, headshot audível); XP; sobreviver ao pico. |
| **5 min — ilha** | Desembarcar → explorar → ativar objetivo (dispara um evento de horda) → voltar ao barco. | Seguir direto ao objetivo ou explorar por caches; quando ativar o evento; ficar mais tempo (mais XP, mais risco) ou partir. | Nível de run → escolher 1 de 3 cartas; caches; acesso à ilha seguinte. |
| **25 min — run** | Dawn Beach → 2–3 ilhas escolhidas num grafo → Volcano (boss) → extração. No barco, entre ilhas: "escolhe 1 de 3" (carta, arma ou cura). | Rota (ilhas com modificador e recompensa anunciados); o que levar no barco; extrair mais cedo com menos Intel ou arriscar o vulcão. | Intel ganho (conserva-se ao morrer, bónus ao extrair); build que cresceu durante a run. |
| **Meta** | Gastar Intel fora da run. | Que perks/slots, armas ou ilhas desbloquear; subir a dificuldade (níveis à Hazard). | Opções novas (horizontais), não números maiores; novos desafios. |

O diretor de horda alterna **crescer → pico → alívio** (Left 4 Dead) em vez
de só escalar com o tempo, para que o loop de 5 min tenha respiração.

## 4. Fantasia, público, plataforma, sessão

- **Fantasia:** "sou o soldado improvável que atravessa um mar de mortos a
  rir-se e volta para contar". Força e ritmo, não sobrevivência ansiosa.
- **Público-alvo:** quem gosta de DRG Survivor / Vampire Survivors mas quer
  mais presença física e decisões de rota; sessões curtas, single-player.
  Em primeiro lugar, o próprio autor (projeto a solo por divertimento).
- **Plataforma:** PC Windows. Teclado/rato e comando desde o início (o
  auto-fire torna o comando natural; o rato só orienta o personagem).
- **Sessão-alvo:** uma run em 20–30 min; uma ilha em 5–8 min; pausa possível
  no barco entre ilhas.

## 5. Vertical slice e "não vamos fazer"

**Objetivo do slice:** 10 minutos divertidos em grey-box (primitivas Godot).

| Elemento | Conteúdo |
|---|---|
| 1 ilha | Dawn Beach compacta (150–200 m), 3 landmarks, barco de chegada/partida. |
| 1 classe | Recruit: arma base infinita + breaker; 1 habilidade ativa (granada). |
| 3 armas | Assault Rifle (base), Shotgun (penetração curta, empurra), Pistola pesada ou lança-chamas (comportamento diferente). |
| 4 inimigos | Zombie normal, Runner, Brute (só cai por trás ou com explosivos) e **Grabber** (prende; o breaker solta). |
| 1 missão | "Activate 3": ligar três geradores; cada um dispara um pico de horda; depois volta ao barco. |
| Progressão | XP → 1 de 3 cartas (6–8 cartas, maioria de comportamento); ecrã de barco com "1 de 3"; Intel no fim. |

**Não vamos fazer (e porquê):**

| Fora | Porquê |
|---|---|
| Construção, torres, acampamento por tiers | Era "outro jogo" no original e ficou órfão; o barco cobre os serviços. |
| Mundo aberto / 768 × 768 m / streaming | Mapa grande para pouco conteúdo; ilhas compactas são viáveis a solo. |
| Skill tree grande, mastery, variantes, várias moedas | Camadas de "+X %" difíceis de equilibrar; perks em slots + Intel chegam. |
| Scrap (no slice) | O "1 de 3" no barco dá a decisão sem uma moeda a explicar. Reavaliar só se o playtest pedir gastos na run. |
| Sprint, salto, agachar | O breaker é o único verbo de movimento; menos inputs, mais legível. |
| Co-op / online | Rede é cara e o autor não tem experiência; single-player primeiro. |
| Assets externos, animação complexa, arte final | Primitivas e desmembramento por partes da cápsula; arte só após o jogo ser divertido. |
| Barco controlável / física naval | A viagem é um ecrã; não serve nenhum pilar. |
| Mais classes antes do slice | Cada classe nova multiplica armas, perks e equilíbrio. |

## 6. Decisões propostas

Para cada ponto em aberto de `DECISIONS.md`. A recomendação respeita a câmara
média e as respostas da secção 10 do brainstorm.

**1. Direção do jogo**
- A (Survivors puro): fácil de ler; género saturado, perde presença física.
- B (shooter tático): tensão; IA/animação caras, pede mira manual.
- **A+B "Expedition Breaker"**: estrutura e escala de A, peso e headshots de B.
- **Recomendação: A+B**, como o utilizador indicou. A câmara média é o meio-termo natural.

**2. Mira e headshots**
- Auto-fire puro ao mais próximo: simples; os headshots tornam-se sorte.
- **Auto-fire com prioridade pela orientação** (alvo no cone para onde o
  personagem olha; cabeça se a linha de tiro estiver livre, senão corpo):
  o jogador "mira" com o corpo; headshots recompensam posição e distância.
- Auto-fire + mira manual opcional (botão): mais controlo; duas formas de
  jogar para equilibrar.
- **Recomendação: a segunda.** Mira manual fica como experiência para depois
  do slice. Pontos fracos visíveis nos especiais somam-se aos headshots.

**3. Escala da horda**
- 30–60 + especiais inteligentes: IA rica; contradiz "romper a horda".
- **80–150 ativos** com especiais simples e legíveis.
- 200–500: espetáculo; exige VAT/flow field desde já e ilegível na câmara média.
- **Recomendação: 80–150**, número final pelo spike S2 (orçamento: 60 FPS
  numa RX 590 com N zombies).

**4. Base**
- Acampamento com construção: rejeitado (lição do original).
- **Barco como ecrã de serviços** entre ilhas ("1 de 3", cura, mapa da rota).
- Sem base nenhuma: mais simples, mas perde o momento de respirar e decidir.
- **Recomendação: barco-ecrã**, sem construção nem moeda no slice.

**5. Pilares e pitch**
- **Recomendação:** os três pilares e o pitch das secções 1–2. Alternativa
  ao pilar 3: "Logística como escolha" (munição especial limitada) — mais
  tático, mas reabre o conflito auto-fire × munição escassa do original.

**6. Contexto do projeto**
- Aprendizagem/diversão sem prazo · portfólio · lançamento na Steam.
- **Recomendação: diversão + aprendizagem**, como indicado. Consequência:
  marcos pequenos (spike → slice), nada que exija arte, rede ou prazo;
  uma eventual página Steam só se o slice for divertido para outras pessoas.

**Outras propostas (decorrentes destas):**
- **Câmara:** preset "Média" (~35°, ~10 m, FOV ~60°) com **yaw fixo** no
  slice — o auto-fire dispensa rodar a câmara e evita enjoo/ruído; o spike
  `camera_medium` confirma ou rejeita.
- **Munição:** arma base infinita; armas especiais com munição limitada
  vinda do barco/caches. Evita auto-fire a gastar munição escassa.
- **Breaker:** investida curta (~5 m) que empurra e atordoa, atravessa
  zombies normais, solta Grabbers, ~6 s de cooldown. O Bull Rush do Renegade
  passa a ser uma carta/perk que modifica o breaker.

## 7. Perguntas para o utilizador

1. Câmara de yaw fixo no slice te parece bem, ou queres rodar a câmara com o rato/stick direito?
2. A orientação do personagem deve vir do movimento (twin-stick "solto") ou do rato/stick direito (twin-stick clássico)?
3. A 3.ª arma do slice: pistola pesada (precisão/headshots) ou lança-chamas (área/controlo)?
4. O que conta como "morrer conserva o Intel": todo o Intel ganho, ou uma parte, com bónus ao extrair?
5. Perks em slots: quantos slots no início (proposta: 2) e desbloqueados como (Intel ou marcos)?
6. Dificuldade à Hazard (DRG) faz parte do slice ou fica para depois?
7. Humor DRG: só no texto/vozes-de-rádio do barco, ou também em nomes de cartas e inimigos?
