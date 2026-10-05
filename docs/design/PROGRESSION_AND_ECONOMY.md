# Progressão e economia

Proposta de 2026-10-05. **Não é decisão**: as decisões fechadas vivem em
`docs/DECISIONS.md`. Parte das respostas do utilizador em
`BRAINSTORM.md` §10 (direção A+B, auto-fire normal, headshots, breaker comum,
barco como ecrã entre ilhas, perks em slots, meta em Intel).

## 0. Resumo

O original tinha **12 camadas** de progressão (Scrap, Credits, XP de run, XP
de personagem, cartas, skill tree de 57 compras, ARMORY, mastery, variantes,
evoluções, melhorias da base, outposts), quase todas "+X%". Proposta:

| Camada | Dura | Ganha-se com | Gasta-se em | Tipo de escolha |
|---|---|---|---|---|
| **Run** | uma run | XP (orbes) | cartas, evoluções; no barco: escolhe 1 de 3 | build desta run |
| **Meta** | para sempre | **Intel** | desbloqueios horizontais | o que entra nas próximas runs |

Sem Scrap, sem Credits, sem XP de personagem, sem skill tree, sem mastery,
sem variantes, sem melhorias de base. **Uma moeda no total.**

Porquê duas camadas: um jogador novo tem de perceber "porque é que fiquei
mais forte" em duas frases. *"Na run sobes de nível e escolhes cartas. Entre
runs gastas Intel para ter mais opções."* Cada camada extra precisa de UI,
save, equilíbrio e testes — é o tipo de custo que afundou o original.

---

## 1. Camada da run

### 1.1 XP e curva de níveis

- Inimigos largam **orbes de XP** (recolha por íman curto, como no original).
  Valores de partida: Normal 1, Runner 1, Spitter 3, Grabber 4, Brute 6,
  elite 15, boss 50. Missões de ilha dão um bónus fixo (25 XP).
- XP para passar do nível *n* ao *n+1*:

  `xp(n) = 10 + 5 × (n − 1) + round(0,6 × (n − 1)²)`

| Nível | XP deste nível | XP acumulado | Alvo de tempo |
|---|---|---|---|
| 2 | 10 | 10 | < 1 min |
| 5 | 40 | 118 | ~4 min |
| 10 | 104 | 496 | ~12 min |
| 15 | 198 | 1284 | ~25 min (fim de run) |
| 20 | 322 | 2632 | só em dificuldades altas |

- Alvo: **~14 escolhas de carta por run de 25 min**, mais frequentes no
  início (o jogador sente a build a formar-se cedo) e mais espaçadas no fim.
  O original pedia `12 + 8(n−1) + 1,35(n−1)²`, mais íngreme; com horda de
  80–150 inimigos e ~1300–1600 abates por run, esta curva bate nos alvos.
  **Números a medir** no vertical slice com telemetria (abates/min, XP/min).
- Subir de nível **pausa** e mostra 3 cartas (como no original: sem prazo,
  fila para subidas simultâneas, proteção contra duplo clique).
- **1 reroll** por run (Intel desbloqueia +1, ver §3). Sem "banish" no slice.

### 1.2 Regras das cartas

- Cada carta tem **até 3 ranks** (original: 5). Menos ranks = mais variedade
  de cartas por run e escolhas mais legíveis.
- Máximo de **6 cartas diferentes** por run. Ao chegar a 6, só aparecem
  ranks das que já tens e evoluções. Força uma build, não "tudo um pouco".
- Cartas de comportamento disparam em **eventos** (acerto, headshot, abate,
  recarga, breaker, dano recebido), nunca em "quando apontas". Assim
  funcionam com auto-fire, que é o modo normal.
- Efeitos encadeados **não se reativam** entre si (uma explosão de carta não
  dispara "ao abater" de outra carta). Lição do original: evita loops e
  custo de CPU imprevisível.
- Cada efeito de comportamento tem limite de alvos e é testado com horda
  cheia (consultas ao spatial hash, não procuras globais por frame).

### 1.3 Catálogo (18 cartas: 6 stats, 12 comportamento)

Nomes em inglês (texto do jogo). Valores são pontos de partida.

**Stats (⅓)**

| Carta | Rank 1 / 2 / 3 |
|---|---|
| **Hollow Points** | +12 / +24 / +36% dano |
| **Hair Trigger** | +10 / +20 / +30% cadência |
| **Speed Loader** | −15 / −30 / −45% tempo de recarga |
| **Thick Skin** | +20 / +40 / +60 HP máx. (cura o valor ganho) |
| **Long Barrel** | +2 / +4 / +6 m alcance do auto-fire |
| **Magnet Boots** | +40 / +80 / +120% raio de recolha |

**Comportamento (⅔)**

| Carta | Efeito (rank 1 → 3) | Pilar |
|---|---|---|
| **Every Fifth** | cada 5.º tiro explode (raio 1,5 → 2 → 2,5 m) | romper a horda |
| **Ricochet** | balas saltam para 1 → 2 → 3 inimigos próximos (50% dano) | builds |
| **Piercing Rounds** | balas atravessam 1 → 2 → 3 inimigos | romper a horda |
| **Headhunter** | headshot marca o inimigo: +25 → 40 → 60% dano recebido por 3 s | headshots |
| **Skull Popper** | abate por headshot faz a cabeça explodir (dano em área pequeno) | headshots / tom |
| **Scorched Path** | o breaker deixa rasto de fogo 3 → 4 → 5 s | breaker |
| **Shockwave** | o breaker empurra num cone mais largo e atordoa 0,5 → 0,8 → 1,2 s | breaker |
| **Second Charge** | breaker ganha 2.ª carga; rank 2/3 reduzem cooldown 15 / 30% | breaker |
| **Kick-Back Reload** | ao recarregar empurra a horda à volta (raio 2 → 3 → 4 m) | romper a horda |
| **Last Round** | a última bala do carregador causa ×3 → ×4 → ×5 dano | builds |
| **Adrenaline** | ao receber dano: +30% velocidade e cadência 2 → 3 → 4 s (cd 8 s) | sobreviver |
| **Scavenger's Luck** | abates têm 3 → 5 → 7% de largar cura ou munição especial | logística |

Notas:

- **Every Fifth**, **Kick-Back Reload** e **Scorched Path** vêm diretamente
  do brainstorm.
- Quatro cartas tocam no **breaker** de propósito: é o verbo do título e é
  comum a todas as classes, logo todas as builds podem investir nele.
- Duas cartas recompensam **headshots**: o auto-fire mira o corpo por
  defeito; a classe/perks/cartas decidem quanto procura a cabeça (ver §4,
  perk *Marksman's Eye*). Isto depende da decisão de mira ainda em aberto.
- Cartas que não fazem sentido em auto-fire (p. ex. "mira mais estável",
  "zoom") foram excluídas.

### 1.4 Raridades e sorteio

Três raridades em vez de cinco — o jogador lê-as pela cor da moldura:

| Raridade | Peso base | Conteúdo |
|---|---|---|
| Common (cinza) | 60 | cartas de stats e ranks seguintes |
| Rare (azul) | 30 | primeiro rank das cartas de comportamento |
| Evolution (dourado) | — | só aparece se os requisitos estiverem cumpridos (garantida, ver 1.5) |

Regras de sorteio, por ordem:

1. Excluir cartas no rank máximo e, se já há 6 cartas, cartas novas.
2. Se há uma evolução disponível, ocupa **um** dos 3 lugares.
3. Garantir **pelo menos 1 carta de comportamento** em cada oferta enquanto
   houver alguma elegível (os ⅔ têm de se notar).
4. Ranks de cartas que já tens têm peso ×1,5 (ajuda a completar builds).
5. Sem repetidos dentro da mesma oferta.
6. Sorteio com **seed da run** (reproduzível para testes e telemetria).

### 1.5 Evoluções de armas

Regra: **arma no slot + carta específica no rank 3 → evolução** oferecida na
próxima subida de nível (ou no barco, ver §2). Substitui a arma; não ocupa
lugar de carta. Uma evolução por arma.

| Arma | + Carta (rank 3) | Evolução | Efeito |
|---|---|---|---|
| Assault Rifle | Every Fifth | **Breach Rifle** | todos os tiros têm micro-explosão; cada 5.º é grande |
| Pistol (base de várias classes) | Last Round | **Hand Cannon** | carregador de 6, cada bala perfura tudo em linha |
| Shotgun | Kick-Back Reload | **Riot Breaker** | cada disparo empurra em cone; recarga dispara uma onda |
| SMG | Ricochet | **Pinball** | ricochetes ilimitados até 0,5 s, dano decrescente |
| Grenade Launcher (especial) | Scorched Path | **Napalm Tube** | granadas deixam poças de fogo |
| Railgun (especial) | Piercing Rounds | **Line Breaker** | atravessa tudo e pára o avanço da horda na linha |

O slice só precisa das duas primeiras (AR + Pistol do Recruit).

### 1.6 Armas e munição

Decisão recomendada (vem do brainstorm, Helldivers 1 / Enter the Gungeon):

- **Slot 1 — arma base, munição infinita.** Carregador e recarga existem
  (dão ritmo e alimentam cartas como *Last Round* e *Kick-Back Reload*),
  mas a reserva é infinita. Com auto-fire, munição escassa na arma base era
  a fonte de frustração do original (auditoria: 1,12 munições por abate).
- **Slot 2 — arma especial, munição limitada.** Forte, com comportamento
  marcado (shotgun, lança-granadas, railgun, lança-chamas). Começa com 3
  carregadores; repõe-se em drops raros de inimigos especiais, em caixas da
  ilha e no barco. Disparo **manual** (botão), não auto-fire: é o momento
  de decisão do jogador ("gasto agora ou guardo para o Brute?").
- Sem compras de munição. Logística é **escolha** (no barco: munição vs
  carta vs cura), não ansiedade.
- Trocar de arma especial durante a run: caixas de arma na ilha (como no
  original) e opção do barco. A especial antiga é largada.

---

## 2. Economia da run: Scrap ou "escolhe 1 de 3"?

O jogo tem ~4 paragens de barco por run (Dawn Beach → 2–3 ilhas → Volcano).

### Opção A — Cortar o Scrap: "escolhe 1 de 3" no barco

Ao subir ao barco, o ecrã mostra três ofertas, uma de cada tipo:

| Tipo | Exemplo |
|---|---|
| **Carta** | uma carta Rare ou um rank escolhido (sem custo de nível) |
| **Arma** | arma especial nova (ou evolução, se elegível) com carregadores cheios |
| **Abastecimento** | cura total **+** reabastecer munição especial |

O jogador escolhe uma. A cura é sempre opção, logo nunca há uma run
"impossível" por falta de recursos.

Variante útil: a missão da ilha pode ter **objetivo bónus** (p. ex. acabar
o Hold Zone sem perder o ponto); cumprido, o barco oferece **2 de 3**.
Isto liga a recompensa ao pilar "cada ilha é uma decisão" sem moeda.

### Opção B — Manter uma moeda (Scrap) e uma loja no barco

Inimigos/caixas largam Scrap; o barco vende cartas, armas, cura, munição.

### Comparação

| Critério | A — escolhe 1 de 3 | B — Scrap + loja |
|---|---|---|
| Regras a explicar | 1 ("escolhe uma") | 3 (ganhar, preços, guardar ou gastar) |
| Equilíbrio | pesos de sorteio | preços × taxa de drop × inflação por ilha |
| Decisão interessante | troca clara (poder vs sobrevivência) | "guardar para depois" pode ser interessante… ou só contabilidade |
| Risco de falhar | baixo; padrão de Slay the Spire/Hades | alto; o original nunca validou se o Scrap "tinha utilidade" (auditoria P0.3) |
| Drops no chão | só XP, cura, munição especial | XP + Scrap + … (mais objetos, mais UI) |
| Custo de implementação (solo, iniciante) | ecrã com 3 botões | inventário, preços, UI de loja, save |
| Explorar a ilha recompensa? | sim, via caixas (arma, munição) e bónus | sim, via Scrap |

### Recomendação: **Opção A — cortar o Scrap.**

Razões: menos sistemas, a decisão do barco fica mais nítida, e o único
argumento forte pela moeda (decisões de poupança entre ilhas) não é um dos
pilares. **Condição de reabertura:** se os playtests mostrarem que os
jogadores querem planear gastos ou que explorar a ilha não compensa, testar
uma moeda simples *dentro do mesmo ecrã* (p. ex. "reroll da oferta por X").
Até lá, não há Scrap no vertical slice.

---

## 3. Camada meta: Intel

### 3.1 Ganhar Intel

Intel = informação recolhida sobre a infeção; a fantasia encaixa num
desbloqueio "aprendemos como fazer isto".

| Fonte | Intel |
|---|---|
| Missão de ilha cumprida | 10 |
| Objetivo bónus | +5 |
| Elite morto | 3 |
| Boss (Volcano) | 25 |
| Extração bem-sucedida | ×1,5 a tudo o que se ganhou na run |
| Morrer | **conserva-se** tudo o que se ganhou (sem multiplicador) |

Uma run típica: ~30–45 Intel ao morrer a meio, ~80–100 ao extrair.
Extrair vale mais, mas morrer nunca é run perdida.

### 3.2 Gastar Intel — só desbloqueios horizontais

Regra: **Intel abre opções, não dá números**. Nada de "+5% dano permanente".
Quem joga 50 runs tem *mais escolha*, não personagem mais forte; a dificuldade
vem dos níveis abaixo.

| Categoria | Exemplos | Custo indicativo |
|---|---|---|
| **Classes** | Renegade, Medic | 150, 250 |
| **Armas especiais** (entram no sorteio) | Shotgun (inicial), Grenade Launcher, Railgun, Flamethrower | 40–80 |
| **Cartas** (entram no catálogo) | o catálogo começa com 12 de 18; as outras 6 desbloqueiam-se | 30 cada |
| **Perks** (para slots de classe) | ver §4 | 40–100 |
| **Slots de perk** | 2.º e 3.º slot por classe | 60, 120 |
| **Conveniência** | +1 reroll por run (máx. 3) | 50, 100 |
| **Modificadores de expedição** | ver 3.3 | desbloqueados pela dificuldade |

Começar com o catálogo **incompleto** é intencional: as primeiras runs têm
menos cartas para aprender, e cada desbloqueio é conteúdo novo, não número.

### 3.3 Dificuldade (estilo Hazard do DRG / Heat do Hades)

- **Hazard 1–5.** Extrair num Hazard desbloqueia o seguinte. Cada nível
  muda a composição da horda (mais especiais, elites), não só vida.
- A partir de Hazard 3, **modificadores** opcionais por run (p. ex.
  "Spitters ×2", "noite", "orbes desaparecem mais depressa") que dão
  +10–25% de Intel. É a forma de "progredir" depois de desbloquear tudo.

### Cortado do original

Credits (→ Intel), XP de personagem e skill tree (→ perks em slots),
ARMORY de compra (→ desbloqueio que entra no sorteio da run), mastery e
variantes (→ ficam para depois, se faltar objetivo de longo prazo; seriam
desbloqueios de perks, não personagens), melhorias da base e outposts
(→ o barco faz o papel, sem construção).

---

## 4. Classes

Estrutura de cada classe:

- **Loadout inicial**: arma base (infinita) + arma especial inicial.
- **Passiva** sempre ligada (identidade).
- **Habilidade ativa** com cooldown (tecla própria, distinta do breaker).
- **Slots de perk** (1 no início, até 3 com Intel). Perks são escolhidos
  **antes da run**, no ecrã de classe, e não mudam durante a run.
- O **breaker** (investida sem sprint) é igual em todas; as classes só o
  modificam via perks.

### 4.1 Recruit — classe do vertical slice

Fantasia: soldado versátil, aprende o jogo.

- **Loadout:** Assault Rifle (base) + Shotgun (especial).
- **Passiva — Drilled:** recarga 30% mais rápida (herdada do original).
- **Ativa — Frag Grenade:** granada lançada na direção do movimento, raio
  4 m, cd 12 s. Ensina "abrir espaço" sem complexidade.
- **Perks** (o slice precisa só dos 4 primeiros):

| Perk | Efeito |
|---|---|
| **Marksman's Eye** | o auto-fire prioriza a cabeça (menos cadência efetiva, mais headshots) |
| **Breaching Charge** | o breaker larga uma granada pequena no fim da investida |
| **Spare Mag** | +1 carregador de arma especial no início e em cada barco |
| **Field Ration** | a opção "Abastecimento" no barco também dá +20 HP máx. |
| **Cook-Off** | a Frag Grenade tem 2 cargas |
| **Tunnel Vision** | +25% dano ao alvo do auto-fire, −30% alcance |

### 4.2 Renegade — tanque de curta distância (desbloqueio)

- **Loadout:** Shotgun-pistol curta (base) + Grenade Launcher (especial).
- **Passiva — Hard Head:** 150 HP; knockback recebido reduzido a metade.
- **Ativa — Ground Slam:** salto curto + impacto em área que derruba.
  Substitui o Bull Rush (que duplicava o breaker, como pediu o utilizador).
- **Perks de exemplo:** *Unstoppable* (o breaker não pára ao bater num
  Brute), *Bloodlust* (abates a < 3 m curam 2 HP), *Shrapnel Slam*.

### 4.3 Medic — sobrevivência e controlo (desbloqueio)

- **Loadout:** SMG (base) + Dart Rifle (especial: dardos que envenenam e
  propagam a inimigos próximos).
- **Passiva — Self-Care:** regenera 3 HP/s após 4 s sem dano (original).
- **Ativa — Med Drone:** drone 8 s que cura e dispara dardos lentos. Funciona
  a solo (regra do original: nada depende de aliados).
- **Perks de exemplo:** *Triage* (cura sobre o máximo vira escudo
  temporário), *Contagion* (veneno salta ao morrer), *Adrenal Shot*.

Três classes é o teto até o slice provar o jogo. Classes novas só com papel,
passiva e ativa que não repitam estas (regra do `CONTENT_EXPANSION_PLAN`
original, mantida).

---

## 5. Ritmo de desbloqueios

Hipótese: ~65 Intel por run em média nas primeiras 10 runs (mais mortes do
que extrações), ~90 depois. Os custos de §3.2 estão afinados para isto.

| Ao fim de | Intel acumulado (aprox.) | O jogador tem | Sensação pretendida |
|---|---|---|---|
| **1 run** | 30–60 | Recruit, AR + Shotgun, 12 cartas, 1 slot de perk com 2 perks iniciais, 1 reroll. Desbloqueia a 1.ª arma especial nova **ou** 1–2 cartas. | "Já há algo novo para experimentar." |
| **5 runs** | ~300 | +Grenade Launcher, +3–4 cartas, 2.º slot de perk, +2 perks, Renegade (150). Primeira extração provável → Hazard 2. | "Tenho escolhas antes da run." |
| **10 runs** | ~650 | catálogo completo (18 cartas), 3–4 armas especiais, Medic, 2 slots em 2 classes, +1 reroll. Hazard 2–3, primeiros modificadores. | "Conheço o jogo; agora quero builds." |
| **20 runs** | ~1500 | tudo desbloqueado (todas as classes, armas, perks, 3 slots). O que resta: Hazard 4–5, modificadores, completar evoluções. | "Jogo pelo desafio, não pelos desbloqueios." |

Total desbloqueável estimado: ~1400–1600 Intel. Se o vertical slice só tiver
o Recruit, a tabela encolhe para "5 runs → tudo do slice"; é intencional,
para testar se o loop vale sem meta.

---

## 6. Decisões propostas

O utilizador decide; nada disto entra em `DECISIONS.md` sem confirmação.

1. **Duas camadas**: run (XP → cartas/evoluções) e meta (Intel →
   desbloqueios horizontais). Tudo o resto do original fica fora.
2. **Cortar o Scrap.** Entre ilhas, o barco oferece "escolhe 1 de 3"
   (carta / arma / abastecimento); objetivo bónus dá 2 de 3.
3. **Munição:** arma base infinita (com carregador) em auto-fire; arma
   especial limitada, disparo manual.
4. **Cartas:** 3 ranks, máximo 6 cartas por run, 18 no catálogo final
   (12 no início), 3 raridades, pelo menos 1 de comportamento por oferta.
5. **Evoluções:** arma + carta específica no rank 3.
6. **Intel conserva-se ao morrer**; extrair multiplica ×1,5.
7. **Meta sem "+X%" permanente**; dificuldade via Hazard 1–5 e modificadores.
8. **Classes:** passiva + ativa + loadout + 1–3 slots de perk; perks fixos
   durante a run. Recruit no slice; Renegade perde o Bull Rush para Ground Slam.

## 7. Perguntas para o utilizador

1. A arma especial deve disparar **manualmente** (botão) enquanto a base
   está em auto-fire? É a única decisão de "quando disparar" que sobra.
2. O auto-fire mira ao corpo por defeito e a cabeça só com perk/carta, ou
   há outra forma de o jogador influenciar headshots (p. ex. segurar um
   botão para "mirar à cabeça" com menor cadência)?
3. Concordas com **morrer = conservar 100% do Intel** (vs 50%)? 100% é mais
   amigável; tira algum peso à decisão de extrair.
4. Limite de **6 cartas** por run: parece-te bem, ou preferes sem limite
   (mais caos, estilo Vampire Survivors)?
5. O catálogo deve começar **incompleto** (12/18) e abrir-se com Intel, ou
   tudo disponível desde a 1.ª run e o Intel só para classes/armas/perks?
6. Mastery/variantes do original: cortar de vez, ou guardar como ideia
   para "depois de tudo desbloqueado"?
7. Para o vertical slice: há camada meta, ou testamos **só a run** primeiro
   (recomendação: só a run; Intel entra depois de o loop ser divertido)?
