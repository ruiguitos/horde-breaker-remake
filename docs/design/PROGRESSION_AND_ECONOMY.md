# Progressão e economia

Proposta de 2026-10-05. **Não é decisão**: as decisões fechadas vivem em
`docs/DECISIONS.md`. Parte das respostas do utilizador em
`BRAINSTORM.md` §10 (direção A+B, auto-fire como modo normal, headshots,
breaker comum, barco como ecrã entre ilhas, perks em slots, meta em Intel).

## 0. Ponto de partida: o que o original tinha a mais

| Camada do original | O que fazia | Destino no remake |
|---|---|---|
| Scrap | moeda da run: munição, cura, torres, melhorias da base | **cortar** (ver §2) |
| Credits | moeda permanente: classes, armas, mastery | substituída por **Intel** |
| Run XP | níveis da run → cartas | **fica** |
| Character XP | níveis por classe, sem teto → skill points | **cortar** |
| Cartas (11, 5 raridades) | quase tudo "+X%" | **fica**, com catálogo novo |
| Skill tree (57 compras/classe; proposta de 36 nós) | "+X%" permanentes | **perks em slots** |
| ARMORY | comprar e equipar armas | fundido nos desbloqueios de Intel |
| Mastery + variantes | desafios → Credits → variante | **cortar** (os desafios podem voltar como fonte de Intel) |
| Evoluções por mortes | arma melhora com abates | **evoluções por carta** (§1.4) |
| Base, torres, outposts | construção e melhorias | **cortar**; o barco faz de serviço |

Resultado: **duas camadas**.

- **Run** (perde-se ao acabar): XP → cartas → evoluções; escolhas no barco.
- **Meta** (fica sempre): Intel → desbloqueios horizontais e dificuldade.

Regra que liga as duas: **a meta dá opções, não números**. Um jogador com
50 runs tem mais escolhas do que um com 1 run, mas não tem +40% de dano.
Isto mantém o equilíbrio controlável por uma pessoa sozinha e é a lição
direta da skill tree do original (ao nível 114 tudo estava comprado e as
classes deixavam de ser diferentes).

## 1. Camada da run

### 1.1 XP e orbes

- Inimigos largam orbes de XP; o íman de recolha é curto (≈ 2 m) para que
  recolher seja uma decisão de movimento, não automático.
- Valores iniciais: normal 1, especial 5, elite 15, boss 50. Objetivo de ilha
  cumprido: bónus de XP igual a ~1 nível.
- O XP é **partilhado pela run toda**, não por classe e não persiste.

### 1.2 Curva de níveis

Alvo: uma run de ~25 min (Dawn Beach + 2–3 ilhas + Volcano) chega ao
**nível 12–15**, ou seja, 11–14 escolhas de carta. Menos do que isto e as
builds não se formam; muito mais e as escolhas perdem peso (o problema dos
survivors com 40 níveis).

Fórmula proposta (XP para passar do nível *n* ao *n+1*):

```
xp_needed(n) = 8 + 6 × (n − 1) + (n − 1)²
```

| Nível | XP para o seguinte | XP acumulado | Quando, aproximadamente |
|---|---|---|---|
| 1 | 8 | 0 | início |
| 2 | 15 | 8 | 1.º minuto (primeira carta cedo) |
| 4 | 35 | 52 | fim de Dawn Beach |
| 6 | 63 | 148 | ilha 1 |
| 8 | 99 | 312 | ilha 2 |
| 10 | 143 | 560 | ilha 3 |
| 12 | 195 | 908 | Volcano |
| 15 | 284 | 1652 | run excelente |

Com ~80–150 inimigos ativos e ~1 000–1 500 abates por run, isto dá a meta
acima. **Os números são para ajustar com telemetria** (XP/minuto e nível
final por run), não para defender.

Regras herdadas do original que funcionaram e ficam: o ecrã de escolha pausa;
subidas simultâneas ficam em fila; ofertas recalculadas após cada escolha;
nunca há duplo clique a conceder duas cartas.

### 1.3 Catálogo de cartas (18)

Princípios:

- **Auto-fire é o modo normal**: nenhuma carta pode depender de o jogador
  carregar no gatilho. Gatilhos válidos: "a cada N tiros", "ao recarregar",
  "ao abater", "ao fazer headshot", "ao usar o breaker", "ao ser atingido",
  "parado/em movimento", "ao apanhar orbes".
- **Headshots contam**: o auto-fire mira ao corpo por defeito; cartas e
  armas podem puxar a mira para a cabeça. Assim a decisão do jogador é
  *posição e build*, não pontaria.
- ⅓ stats (6 cartas), ⅔ comportamento (12 cartas). As de stats têm até
  3 níveis; as de comportamento têm 1 nível (ou 2, onde indicado).
- Cada carta funciona sozinha; as sinergias são bónus, não requisitos.

**Stats (6)**

| Carta | Efeito por nível | Níveis | Raridade |
|---|---|---|---|
| Hot Barrel | +12% cadência | 3 | comum |
| Hollow Points | +15% dano | 3 | comum |
| Deep Pockets | +25% carregador e reserva das armas especiais | 3 | comum |
| Thick Skin | +20 vida máxima e cura 20 | 3 | comum |
| Light Boots | +8% velocidade de movimento | 3 | comum |
| Long Sights | +1,5 m de alcance de auto-fire | 3 | incomum |

**Comportamento (12)**

| Carta | Efeito | Gatilho | Raridade |
|---|---|---|---|
| Fifth Round | cada 5.º tiro explode (raio 2 m) | N tiros | incomum |
| Ricochet | balas saltam para 1 inimigo próximo (2 no nível 2) | impacto | incomum |
| Piercing Rounds | balas atravessam 1 inimigo (2 no nível 2) | impacto | incomum |
| Headhunter | o auto-fire prioriza a cabeça; headshots ×2,5 em vez de ×2 | headshot | raro |
| Shockwave Reload | recarregar empurra a horda num raio de 3 m | recarga | incomum |
| Scorched Path | o breaker deixa um rasto de fogo durante 3 s | breaker | incomum |
| Second Wind | abates reduzem o cooldown do breaker em 0,2 s | abate | comum |
| Chain Pop | inimigos mortos por headshot explodem (dano pequeno, sem cadeia infinita) | headshot | raro |
| Overwatch | parado ≥ 1 s: +40% cadência até te mexeres | posição | incomum |
| Run and Gun | em movimento: balas abrandam o alvo 30% durante 1 s | posição | incomum |
| Scavenger | orbes de XP têm 5% de largar munição especial | recolha | comum |
| Last Stand | abaixo de 25% de vida: breaker sem cooldown durante 4 s (1× por ilha) | ser atingido | raro |

Notas de implementação (para o código, mais tarde):

- Efeitos de abate e explosão **não se ativam a partir de outros efeitos**
  (Chain Pop não dispara Chain Pop), como já pedia o original.
- Ricochet e Piercing usam o spatial hash da horda, sem novas pesquisas
  globais por frame.
- Cartas são `Resource` com id, raridade, nível máximo, tags (para
  evoluções) e uma lista de efeitos; o mesmo formato serve armas e perks.

### 1.4 Evoluções de armas

Inspiração: Vampire Survivors / DRG Survivor. Uma **evolução** = arma + carta
específica no nível máximo + ter cumprido o objetivo da ilha atual. A
evolução aparece como oferta especial no barco (§2), nunca de surpresa.
Assim recompensa planeamento e liga a evolução ao pilar "cada ilha é uma
decisão".

| Arma | Carta necessária | Evolução | O que muda |
|---|---|---|---|
| Assault Rifle (base do Recruit) | Hot Barrel 3 | **Storm Rifle** | rajadas de 3 com spread estreito; cada rajada completa no mesmo alvo atordoa 0,3 s |
| Shotgun | Shockwave Reload | **Breacher** | cada disparo empurra como um mini-breaker |
| SMG | Ricochet | **Pinball** | todos os projéteis ricocheteiam 2× |
| Marksman Rifle | Headhunter | **Executioner** | headshots perfuram em linha toda a fila |
| Grenade Launcher | Fifth Round | **Cluster** | cada granada larga 3 sub-granadas |

Uma evolução por run em média; duas numa run boa. No vertical slice basta
**uma** (Storm Rifle) para validar a regra.

### 1.5 Raridades e regras de sorteio

Três raridades em vez de cinco (o original tinha cinco e a diferença entre
elas não se notava):

| Raridade | Peso base | Cor | Uso |
|---|---|---|---|
| Comum | 60 | branco | stats e utilidades seguras |
| Incomum | 30 | verde | maioria do comportamento |
| Rara | 10 | dourado | cartas que mudam a build |

Regras:

1. Cada subida de nível mostra **3 cartas distintas**.
2. Excluir cartas no nível máximo.
3. **Garantia de comportamento**: pelo menos 1 das 3 é de comportamento
   (impede ofertas só "+X%").
4. **Peso de sinergia**: cartas que partilham tag com uma carta que o
   jogador já tem recebem ×1,5 no peso. Builds formam-se sem ser forçadas.
5. **Proteção contra azar**: se 3 ofertas seguidas não tiverem rara, a
   seguinte tem uma.
6. **Reroll**: 1 por run no slice (mais via perk). Sem banish no slice.
7. Limite de **6 cartas de comportamento** diferentes por run, para o ecrã
   e a cabeça do jogador continuarem legíveis. Stats não contam.

## 2. Economia da run

### 2.1 Cortar o Scrap ou manter uma moeda?

| | A — Cortar o Scrap: "escolhe 1 de 3" no barco | B — Manter uma moeda da run (Scrap) |
|---|---|---|
| O que o jogador faz | entre ilhas, escolhe 1 de 3 ofertas (carta, arma, cura/munição) | apanha Scrap, gasta-o numa loja no barco |
| Decisões | uma decisão clara por ilha, sempre interessante | várias pequenas (poupar vs gastar); ricas mas lentas |
| Ritmo | rápido; o barco é um ecrã de 10–20 s | o barco vira loja; tende a demorar |
| Equilíbrio | ofertas controladas pelo designer | preços × drops × duração: 3 variáveis acopladas |
| UI e código | um painel reutiliza o das cartas | moeda no HUD, drops, íman, loja, preços, testes de saldo |
| Risco | menos sensação de "acumular" | duplica o papel do XP (duas coisas a apanhar do chão) |
| Original | — | "quanto Scrap realmente tem utilidade" ficou por responder (PROJECT_AUDIT P0.3) |

**Recomendação: A, cortar o Scrap.** Razões:

1. O XP já cumpre o papel de "apanhar coisas do chão para ficar mais forte".
   Uma segunda moeda no chão compete pela mesma atenção sem nova decisão.
2. A decisão interessante do Scrap era *em que gasto?*; o "1 de 3" mantém
   essa decisão sem preços para equilibrar.
3. Projeto a solo, sem experiência: cada sistema a menos é semanas a menos.
4. É reversível: se os playtests mostrarem falta de decisões de gasto, a
   moeda volta como **custo de reroll/ofertas extra**, não como loja.

### 2.2 O barco entre ilhas

Depois de cada ilha, o ecrã do barco mostra:

1. **Escolhe 1 de 3** — uma oferta de cada tipo:
   - **Carta**: uma carta rara ou a evolução disponível (§1.4).
   - **Arma**: uma arma especial com munição cheia (substitui a atual).
   - **Abastecer**: cura completa + reserva de munição especial cheia.
2. **Mapa** da expedição: escolher a próxima ilha (grafo).
3. Bónus de missão: cumprir o objetivo opcional da ilha acrescenta uma 4.ª
   opção ou melhora uma das três (p. ex. "Abastecer" também dá 1 reroll).

A decisão "cura vs poder" é o equivalente de "gastar Scrap em munição vs
upgrades", sem moeda.

### 2.3 Munição

- **Arma base: munição infinita**, com carregador e recarga. A recarga é
  ritmo e gatilho de cartas (Shockwave Reload), não escassez.
- **Arma especial (1 slot): munição limitada**, sem recarga no terreno a não
  ser por caixas raras, carta Scavenger ou a opção "Abastecer" do barco.
  Quando esvazia, o jogador volta à arma base automaticamente.
- O auto-fire usa a arma especial enquanto tiver munição e **o jogador pode
  guardá-la** (tecla de troca), para a gastar num pico ou boss.
- Isto resolve o conflito do original (auto-fire a gastar munição escassa):
  nunca se fica sem conseguir disparar; a escassez só existe onde é escolha.

## 3. Camada meta: Intel

### 3.1 A moeda

- **Intel** é a única moeda permanente. **Conserva-se ao morrer**.
- Ganha-se por: ilha concluída (+10), objetivo opcional (+5), boss (+20),
  extração (+30 e ×1,5 em tudo o que foi ganho na run). Morrer conserva
  100% do ganho; extrair dá mais. Assim arriscar mais uma ilha é decisão
  real, sem punir o jogador novo.
- Valor de referência: run média ~40–60 Intel; run com extração ~100.

### 3.2 Desbloqueios horizontais

Tudo o que o Intel compra **acrescenta opções**:

| Categoria | Exemplos | Custo indicativo |
|---|---|---|
| Armas no pool | Shotgun, SMG, Marksman Rifle, Grenade Launcher | 40–80 |
| Cartas no pool | as 6 cartas raras/incomuns mais complexas começam bloqueadas | 30 cada |
| Classes | Vanguard, Field Medic | 150 / 200 |
| Perks | novos perks para os slots (§4) | 40–60 |
| Slots de perk | 2.º e 3.º slot por classe | 100 / 200 |
| Modificadores | "ilhas com nevoeiro", "só headshots contam XP" (opções com bónus de Intel) | 50 |

O pool começa pequeno de propósito: as primeiras runs são fáceis de ler e
cada desbloqueio é algo novo a experimentar.

### 3.3 Níveis de dificuldade

Inspiração: Hazard (DRG) e Heat (Hades).

- **Threat 1–5**. Threat 1 disponível de início; vencer (extrair) num
  Threat desbloqueia o seguinte.
- Cada nível acrescenta uma regra legível, não só +HP: mais especiais,
  diretor com menos alívio, Screamers chamam mais horda, ofertas do barco
  passam a 2, boss com fase extra.
- Multiplicador de Intel: ×1 / ×1,25 / ×1,5 / ×1,75 / ×2.
- É aqui que a meta dá "progressão vertical": o jogador fica mais forte por
  saber jogar e escolhe o desafio, não por números permanentes.

## 4. Classes

### 4.1 Regras comuns

- **Breaker** (investida comum a todas as classes, sem sprint) com o mesmo
  cooldown base; as classes modificam-no com perks, não o substituem.
- Cada classe = **habilidade ativa + passiva + loadout inicial** + perks
  próprios. Sem XP por classe, sem árvore.
- **Perks em slots**: 1 slot no início, até 3 com Intel. Perks são trocados
  livremente no barco antes da run (não durante). Cada perk é um
  comportamento pequeno ou um sidegrade com custo.

### 4.2 As três classes

| | **Recruit** (slice) | **Vanguard** | **Field Medic** |
|---|---|---|---|
| Papel | versátil, aprende o jogo | linha da frente, controlo da horda | sobrevivência, resistência |
| Loadout | Assault Rifle (base) + sem especial | Shotgun (base, infinita) + sem especial | SMG (base) + sem especial |
| Ativa | **Frag Grenade**: explosão em área, 20 s | **Anchor**: cravar no chão; empurra a horda e dá 50% de redução de dano 3 s, 25 s | **Stim Field**: área que cura 6 s, 30 s |
| Passiva | recarga 30% mais rápida | breaker atordoa 0,5 s | regenera 2 HP/s após 4 s sem dano |
| Perks (exemplos) | *Cooked Frag* (granada maior, cooldown +5 s), *Drill Sergeant* (1 reroll extra por run), *Spare Mag* (1.º carregador de cada ilha não gasta munição especial) | *Bulldozer* (breaker mais longo, cooldown +2 s), *Point Blank* (+30% dano a ≤ 4 m, −2 m alcance), *Shrug Off* (Grabber solta-te sozinho em 1 s) | *Triage* (Stim cura mais, dura menos), *Field Kit* (opção "Abastecer" do barco também dá carta comum), *Adrenaline* (ao curar, +20% cadência 3 s) |

O **Renegade** do original passa a **Vanguard**: o Bull Rush tinha de mudar
porque o breaker é agora comum; a identidade de "aguentar pressão" passa
para a ativa (Anchor) e para a passiva.

O **Recruit** é a única classe do vertical slice: 1 slot de perk e 3 perks.

## 5. Ritmo de desbloqueios

Assumindo ~50 Intel por run em média (mais nas runs com extração).

| Runs | Intel acumulado | O que o jogador tem |
|---|---|---|
| 1 | ~30 | Recruit, AR, 12 cartas no pool, 1 perk (*Spare Mag*), Threat 1. Aprendeu o loop. Primeiro desbloqueio quase garantido: uma arma especial (Shotgun) |
| 5 | ~250 | 2–3 armas especiais, 2–3 cartas novas, 2.º perk do Recruit, **2.º slot de perk**. Provavelmente primeira extração → Threat 2 |
| 10 | ~550 | **Vanguard** desbloqueado, todas as armas do slice, a maioria das cartas, 1.º modificador. Threat 2–3 |
| 20 | ~1 200 | **Field Medic**, 3.º slot de perk numa classe, quase todo o catálogo. A partir daqui a motivação é Threat 4–5 e modificadores |

Objetivo de design: **algo novo em cada 1–2 runs** até à run 20, e nunca um
desbloqueio que torne o jogo mais fácil sem escolha.

## 6. Decisões propostas e perguntas

### Decisões propostas (o utilizador decide)

1. **P1 — Duas camadas**: run (XP → cartas → evoluções + barco) e meta
   (Intel → desbloqueios horizontais + Threat). Sem XP de personagem,
   skill tree, ARMORY, mastery, variantes ou base.
2. **P2 — Cortar o Scrap** e usar "escolhe 1 de 3" (carta / arma /
   abastecer) no barco. Reavaliar após playtest.
3. **P3 — Munição**: arma base infinita + 1 slot de arma especial com
   munição limitada; o auto-fire pode ser impedido de gastar a especial.
4. **P4 — Cartas**: catálogo de 18 (6 stats, 12 comportamento), 3
   raridades, garantia de comportamento em cada oferta, limite de 6 cartas
   de comportamento por run.
5. **P5 — Evoluções**: arma + carta no máximo + objetivo da ilha; oferecida
   no barco. Slice: só Storm Rifle.
6. **P6 — Intel conserva-se ao morrer**; extração multiplica ×1,5.
7. **P7 — Classes**: Recruit, Vanguard (ex-Renegade), Field Medic; ativa +
   passiva + loadout; perks em 1–3 slots.
8. **P8 — Dificuldade** em Threat 1–5 desbloqueados por extração.

### Perguntas para o utilizador

1. Concordas em cortar o Scrap já no slice, ou preferes testar as duas
   versões (seria mais trabalho)?
2. A arma especial deve **substituir** a anterior quando se escolhe outra,
   ou queres 2 slots especiais?
3. Morrer conserva **100%** do Intel ou uma parte (p. ex. 70%) para a
   extração pesar mais?
4. As cartas mais complexas devem começar bloqueadas (desbloqueio por
   Intel) ou o pool completo deve estar aberto desde a run 1?
5. A granada do Recruit como ativa agrada-te, ou preferes outra (p. ex.
   torreta, que era ideia do brainstorm)?
6. O Medic do original funcionava a solo; o Field Medic mantém-se a solo
   (sem aliados/IA). Confirmas que não há co-op nem aliados no plano?
7. Os nomes Vanguard/Field Medic/Intel/Threat servem, ou queres nomes com
   mais humor (tom DRG)?

### Fora do âmbito ("não vamos fazer", por agora)

Moeda de run com loja; XP por classe; árvores de skills; mastery e
variantes; construção, torres e melhorias de base; ranks repetidos de
"+X%"; mais de 3 classes antes de o slice estar divertido.
