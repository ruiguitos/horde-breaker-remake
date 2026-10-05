# Progressão e economia

Estado: **proposta** (2026-10-05). Nada aqui é decisão até o utilizador o
fechar em `docs/DECISIONS.md`. Números são pontos de partida para o vertical
slice, não balanceamento medido.

Depende de decisões ainda em aberto (direção, mira, escala da horda, base).
Onde isso muda o desenho, está assinalado com **⚑**. Armas, inimigos e o
verbo *breaker* (dash/empurrão) pertencem a `COMBAT_AND_ENEMIES.md`; aqui só
aparecem na medida em que a progressão os toca.

## 0. Porquê reduzir

O original tinha **onze sistemas de progressão**: Scrap, Credits, XP de run,
XP de personagem, cartas, skill tree (57 compras por classe), ARMORY,
mastery, variantes, evoluções por mortes e melhorias da base. Problemas que
isso causou (ver `legacy/GDD.md`, `legacy/SKILL_TREE_EXPANSION_PROPOSAL.md`,
`legacy/PROJECT_AUDIT.md`):

- **Quase tudo era "+X%"**. Um jogador não consegue explicar o que passou a
  fazer de diferente depois de comprar "+4% cadência" pela décima vez.
- **Bónus permanentes empilhados** sobre cartas, variantes e skills tornavam o
  balanceamento impossível de medir e criaram bugs reais (modificadores que não
  se reaplicavam ao trocar de arma, aplicação não idempotente ao retomar).
- **XP sem teto**: ao nível 114 a árvore enchia-se; a escassez deixava de criar
  identidade.
- **Duas moedas sem ponte** (Scrap e Credits) e um depósito de Scrap sem
  consumidores no arquipélago.

O remake fica com **duas camadas**, cada uma com uma só pergunta:

| Camada | Pergunta ao jogador | Recursos | Reinicia |
|---|---|---|---|
| **Run** | "Que build monto com o que me aparece?" | XP → cartas e evoluções; Scrap → barco; munição especial | no fim de cada run |
| **Meta** | "Que opções novas quero ter na próxima run?" | **Intel** → desbloqueios horizontais; Tide (dificuldade) | nunca |

Regra de ouro: **a meta dá opções, a run dá poder.** Um jogador com 20 runs
tem mais escolhas que um jogador novo, não muito mais dano.

Pilar servido: *Builds que mudam a forma de jogar* (BRAINSTORM §1). As
escolhas de loja no barco servem também *Cada ilha é uma decisão*.

---

## 1. Camada da run

### 1.1 XP e curva de níveis

- XP vem de **orbes** largados pelos inimigos (recolha automática dentro de um
  raio) e de **bónus de objetivo** ao cumprir a missão de uma ilha.
- Orbes por inimigo (proposta): comum 1, rápido 1, especial 3, elite 8,
  boss 40. Bónus de objetivo: 25 XP por ilha, 60 na extração.
- XP para passar do nível *L* ao *L+1*:

  ```
  xp_to_next(L) = round(5 + 3·L + 0,35·L²)
  ```

  | Nível | 1 | 2 | 3 | 5 | 8 | 10 | 12 | 15 | 17 | 20 |
  |---|---|---|---|---|---|---|---|---|---|---|
  | XP para o seguinte | 8 | 12 | 17 | 29 | 51 | 70 | 91 | 129 | 157 | 205 |

**Alvo de ritmo:** ~16 subidas numa run vitoriosa de 25 min, mais densas no
início (aprender) e espaçadas no fim (decidir com calma). Modelo usado para
chegar à fórmula: ganho de XP a subir linearmente de 12 para 70 XP/min ao
longo da run, mais os bónus de objetivo. Resultado do modelo:

| Tempo | 0:40 | 3:40 | 5:00 | 10:00 | 15:00 | 19:20 | 23:00 |
|---|---|---|---|---|---|---|---|
| Nível | 2 | 5 | 6 | 10 | 13 | 15 | 17 |

Isto é uma simulação de papel. **Medir no vertical slice** (telemetria por
run: tempo de cada subida, XP/min por ilha) e ajustar só os três coeficientes.

**Porquê esta forma:** o termo linear garante subidas rápidas nos primeiros
minutos; o quadrático, pequeno, compensa o aumento da densidade da horda para
o intervalo entre escolhas não encolher no fim. Sem teto: se a run for longa,
continua a dar cartas (ver *fallback* em 1.4).

Ao subir de nível o jogo **pausa** e mostra três cartas (já era assim no
original e funcionava). Subidas simultâneas ficam em fila.

### 1.2 Raridades

Três, em vez de cinco. A raridade é **fixa por carta** e só afeta a
probabilidade de aparecer; não há a "mesma carta em versão épica".

| Raridade | Cor | Peso por carta | Para quê |
|---|---|---|---|
| Common | branco | 10 | stats e comportamentos simples |
| Rare | azul | 5 | comportamentos que mudam o ritmo de jogo |
| Evolution | dourado | — (garantida, ver 1.4) | transformação de arma |

### 1.3 Catálogo de cartas (18)

**6 de stats (⅓) e 12 de comportamento (⅔).** Nomes em inglês (texto do
jogo). Valores por rank; "Ranks" é o máximo de vezes que se pode escolher.
Um ✱ marca as cartas disponíveis desde a primeira run (as outras desbloqueiam-se
com Intel, ver §3).

#### Stats (6)

| # | Carta | Rar. | Ranks | Efeito por rank |
|---|---|---|---|---|
| S1 ✱ | **Hollow Points** | C | 3 | +12% dano de todas as armas |
| S2 ✱ | **Trigger Discipline** | C | 3 | +10% cadência |
| S3 ✱ | **Fast Hands** | C | 3 | −15% tempo de recarga |
| S4 ✱ | **Field Plating** | C | 3 | +20 vida máxima e cura 20 |
| S5 ✱ | **Light Boots** | C | 3 | +6% velocidade de movimento |
| S6 ✱ | **Magnet** | C | 2 | +40% raio de recolha de orbes, Scrap e munição |

#### Comportamento (12)

| # | Carta | Rar. | Ranks | Efeito (rank 1 → máximo) |
|---|---|---|---|---|
| B1 ✱ | **Powder Keg** | C | 3 | Cada 5.º tiro da arma base explode (raio 2 m). Rank 3: cada 4.º, raio 3 m. |
| B2 ✱ | **Piercing Rounds** | C | 2 | Balas atravessam +1 inimigo por rank. |
| B3 ✱ | **Shockwave Reload** | C | 2 | Recarregar empurra a horda num raio de 3 m (4 m no rank 2), com dano baixo. |
| B4 ✱ | **Scorched Path** | R | 2 | O *breaker* deixa um rasto de fogo durante 3 s (5 s no rank 2). |
| B5 ✱ | **Last Round** | C | 2 | A última bala do carregador causa ×3 dano e perfura (×4 no rank 2). |
| B6 ✱ | **Second Wind** | R | 2 | Cada abate reduz o cooldown do *breaker* em 0,3 s (0,5 s no rank 2). |
| B7 | **Ricochet** | R | 2 | Balas fazem ricochete para o inimigo mais próximo até 4 m, 1× (2× no rank 2). |
| B8 | **Chain Spark** | R | 3 | Abates têm 15% / 25% / 35% de libertar uma faísca que salta para 2 inimigos. |
| B9 | **Tripwire** | C | 2 | Ficar parado 1,5 s larga uma mina de proximidade (máx. 2 / 3 ativas). |
| B10 | **Adrenaline** | R | 1 | Abaixo de 30% de vida: +40% cadência e +15% velocidade. |
| B11 | **Quartermaster** | C | 2 | A cada 12 / 8 abates com a arma base, +1 carga da arma especial. |
| B12 | **Echo** | R | 1 | A habilidade ativa da classe repete-se 2 s depois com 50% do efeito. |

Total de ranks no catálogo: 17 (stats) + 24 (comportamento) = 41. Com ~16
escolhas por run, o jogador preenche **menos de metade**: tem de escolher uma
direção. É essa escassez que cria builds, não uma árvore permanente.

Critério para cada carta de comportamento: **o jogador consegue dizer, numa
frase, o que passou a fazer de diferente** (reposicionar-se para recarregar,
ficar parado para largar minas, guardar a última bala…). Este critério vem da
lição registada em `legacy/INSPIRATIONS.md`.

Limites técnicos herdados do original, que se mantêm: efeitos de abate têm
limite e **não disparam recursivamente** a partir de outros efeitos (uma faísca
não gera faíscas; uma explosão do Powder Keg não conta como "tiro"); projéteis
perfurantes e ricochetes respeitam colisões e alcance.

⚑ **Mira:** se a mira for manual com headshots relevantes, B8 pode passar a
"headshots libertam faísca". Se houver auto-fire, B9/B5 ganham peso porque o
jogador controla sobretudo a posição. O catálogo funciona nos dois casos.

### 1.4 Regras de sorteio

1. **Três cartas distintas** por oferta, sorteadas por peso (Common 10, Rare 5).
2. **Excluídas:** cartas no rank máximo; cartas ainda não desbloqueadas na meta;
   cartas que dependem de algo que o jogador não tem (B11 sem arma especial,
   B12 numa classe sem habilidade ativa, se existir).
3. **Pelo menos uma carta de comportamento** em cada oferta. Sem isto, o
   sorteio por peso pode dar três stats seguidas e a build fica "+X%".
4. **Pity de raridade:** se duas ofertas seguidas não tiveram nenhuma Rare, a
   terceira tem uma garantida.
5. **Evolução garantida:** quando as condições de uma evolução estão cumpridas
   (1.5), a próxima oferta substitui uma das três cartas pela evolução dourada.
6. **Reroll:** 1 por run (mais via perk ou loja do barco). Troca as três cartas.
7. **Skip:** recusar a oferta dá **15 Scrap**. Útil quando nada serve a build.
8. **Fallback:** se não houver cartas suficientes para três opções (catálogo
   esgotado numa run muito longa), as vagas mostram **"Field Ration"**: cura
   30 e +10 Scrap.

Sem prazo para escolher: a run pausa até à escolha explícita.

### 1.5 Evoluções de armas

No original, as evoluções dependiam de contadores de mortes e viviam num
sistema separado. Aqui são **uma combinação legível**: *arma equipada +
carta catalisadora no rank máximo → a próxima subida oferece a evolução*.
Não há XP de arma nem níveis de arma: é menos uma camada.

A evolução **substitui** a arma (mantém slot e munição) e conta como uma
escolha de carta. Uma por arma.

| Arma (base ou especial) | Catalisador (rank máx.) | Evolução | O que muda |
|---|---|---|---|
| Assault Rifle (base) | Powder Keg | **Howitzer Rifle** | Cada 3.º tiro explode (raio 3,5 m) e empurra. |
| Shotgun (base) | Shockwave Reload | **Breaker Gun** | Cada disparo empurra uma parede de zombies em cone. |
| SMG (base) | Ricochet | **Pinball** | Ricochetes ilimitados enquanto houver alvo a ≤ 4 m, dano −20% por salto. |
| Grenade Launcher (esp.) | Tripwire | **Cluster Launcher** | Cada granada larga 4 sub-munições. |
| Flamethrower (esp.) | Scorched Path | **Inferno** | O chão atingido arde 4 s. |
| Railgun (esp.) | Piercing Rounds | **Rail Lance** | Perfuração ilimitada numa linha; carrega-se ao manter o botão. |
| Tesla Coil (esp.) | Chain Spark | **Storm Coil** | Os arcos saltam para +3 alvos e atordoam 0,3 s. |

O catálogo e os stats das armas são de `COMBAT_AND_ENEMIES.md`; esta tabela só
fixa a **regra** e propõe pares. Se o arsenal mudar lá, os pares mudam aqui.

O ecrã de cartas mostra, numa carta catalisadora, o ícone da evolução que ela
abre com a arma atual. Assim o jogador consegue **planear** a evolução, que é
o que dá sentido a escolher Shockwave Reload duas vezes.

---

## 2. Economia da run

### 2.1 Uma moeda: Scrap

**Scrap** é a única moeda da run e **desaparece no fim** (como no original).
Não converte em Intel: se convertesse, guardar Scrap competiria com gastá-lo,
e o barco deixaria de ser uma decisão.

| Fonte | Quantidade (proposta) | Nota |
|---|---|---|
| Inimigos comuns | 15% de chance, 1–2 | pequeno, constante |
| Especiais | 50%, 4–6 | razão para os caçar |
| Elites | 100%, 10–15 | |
| Caches na ilha | 20–40 cada, 2–3 por ilha | razão para explorar fora do objetivo |
| Objetivo cumprido | 50 | |
| Boss de ilha / Volcano | 60 / — | o boss final dá Intel, não Scrap |
| Skip de carta | 15 | |

Alvo: **~150–220 Scrap a chegar ao barco por ilha**, o suficiente para 2–3
compras. Medir em jogo; o original subiu drops a meio do desenvolvimento
porque os números de papel falharam (`legacy/PROJECT_AUDIT.md` §3).

O Scrap é recolhido no chão (com o raio de recolha) e fica logo no "bolso";
**não há depósito**. O depósito do original obrigava a voltar ao hub e não
acrescentava decisão.

### 2.2 Onde se gasta: o barco

⚑ **Base:** este desenho assume o *barco como base móvel* (BRAINSTORM §4). Se
for escolhido acampamento ou nenhuma base, a mesma loja passa para um posto
no fim de cada ilha; as regras não mudam.

Entre ilhas o jogador está no barco: zona segura, sem horda, sem relógio.
A loja do barco tem **stock fixo + 3 ofertas aleatórias** que mudam por ilha.

| Item | Preço | Tipo |
|---|---|---|
| **Patch Up** — cura 50% da vida | 40 | fixo |
| **Special Ammo** — repõe a arma especial ao máximo | 50 | fixo |
| **Reroll Token** — +1 reroll de cartas | 35 | fixo |
| **Special Weapon** — 1 arma especial desbloqueada, aleatória, troca a atual | 90 | oferta |
| **Field Manual** — escolher 1 de 3 cartas agora (fora de subida de nível) | 120 | oferta |
| **Ability Charge** — +1 carga da habilidade ativa nesta run | 100 | oferta |
| **Armor Plate** — absorve 1 golpe por ilha | 80 | oferta |

Preços crescem 15% a cada ilha (o Scrap ganho também cresce). Proposta, a
medir.

Porquê assim: o barco é o "alívio" do diretor de horda (crescer → pico →
alívio) e o momento de **planear a próxima ilha** no mapa da expedição. Juntar
a escolha de rota e a loja no mesmo ecrã faz da paragem uma decisão: "vou à
ilha difícil com a vida a meio, ou gasto em cura e não compro a Railgun?"

### 2.3 Munição

Segue o BRAINSTORM: **logística como escolha, não ansiedade**.

- **Arma base** (da classe): **munição infinita**, só carregador e recarga.
  Nunca se fica sem forma de lutar. Isto resolve o conflito do original, em que
  auto-fire a gastar munição escassa frustrava.
- **Arma especial** (encontrada ou comprada): **cargas limitadas**, sem
  recarga gratuita. Repõe-se com caixas largadas por especiais/elites
  (~25% da capacidade), com Quartermaster (B11) e com Special Ammo no barco.
- **Uma arma especial de cada vez.** Apanhar outra troca-a (a anterior cai no
  chão, como no original).
- A **habilidade ativa** da classe usa cooldown, não munição.

Assim a munição só pesa numa decisão: *quando* gastar a arma forte. Não é
preciso HUD de reservas para duas armas, que o original nunca resolveu bem.

⚑ **Mira:** com mira manual, o jogador escolhe quando disparar a especial.
Com auto-fire, a especial **nunca dispara sozinha**: é sempre um botão. Esta
regra vale nas duas hipóteses.

---

## 3. Camada meta

### 3.1 Uma moeda: Intel

**Intel** (informação recuperada na expedição) é a única moeda permanente.
Substitui Credits, XP de personagem, skill points e mastery.

Ganha-se por **feitos**, não por grind de abates, para premiar jogar bem e
avançar, não ficar a farmar a primeira ilha:

| Fonte | Intel |
|---|---|
| Objetivo de ilha cumprido | 10 |
| Ilha opcional/difícil cumprida | +5 |
| Boss do Volcano derrotado | 20 |
| Extração | ×1,5 sobre o total da run |
| Morte | conserva 100% do ganho (sem o ×1,5) |
| Tide (dificuldade) | +20% por nível acima de 1 |
| Primeira vez (primeira extração, primeira em cada Tide, primeira evolução) | +15 a +40, uma vez |

Ordens de grandeza: run inicial que morre na 2.ª ilha ≈ 10–20 Intel; run
completa em Tide 1 ≈ 75; run completa em Tide 3 ≈ 105.

Morrer conserva o Intel para não punir a experimentação; a extração vale mais
para que **extrair cedo ou arriscar** (BRAINSTORM §2) seja uma escolha real.

### 3.2 Desbloqueios horizontais

Tudo o que se compra com Intel **acrescenta opções**, nunca percentagens
permanentes. Uma carta desbloqueada entra no *pool* de sorteio; uma arma
especial passa a poder aparecer na run.

| Categoria | Começa com | Desbloqueável (preço em Intel) | Total |
|---|---|---|---|
| **Classes** | Recruit | Renegade 60 · Medic 120 | 180 |
| **Armas especiais** | Grenade Launcher, Flamethrower | Railgun 50 · Tesla Coil 80 | 130 |
| **Cartas** | 12 (S1–S6, B1–B6) | Ricochet 30 · Tripwire 30 · Quartermaster 30 · Chain Spark 40 · Adrenaline 40 · Echo 45 | 215 |
| **Perks** | 2 | 8 perks, 30–60 cada (3.3) | ~360 |
| **Passivas alternativas** | 1 por classe | 1 alternativa por classe, 60 cada (§4) | 180 |
| **Loja do barco** | 4 itens fixos | Field Manual 40 · Ability Charge 40 · Armor Plate 40 | 120 |
| **Total** | | | **~1 185** |

As três ofertas da loja do barco entram no stock só depois de desbloqueadas;
até lá, a loja tem os quatro itens fixos e a Special Weapon.

Atenção à armadilha do original: **desbloquear não pode ser obrigatório para
ganhar**. Uma run em Tide 1 tem de ser vencível só com o conteúdo inicial.

### 3.3 Perks (substituem a skill tree)

Em vez de 54 nós com ranks, **perks equipáveis em slots** com uma troca
explícita (sidegrade). Equipam-se antes da run e não mudam durante ela.

- Slots: **1** ao início; **2** na primeira extração; **3** na primeira extração
  em Tide 3. Slots abrem-se por feitos, não com Intel, para não virarem
  "o desbloqueio que toda a gente compra primeiro".

| Perk | Efeito | Custo |
|---|---|---|
| **Scavenger** ✱ | +25% Scrap; −10% vida máxima | — |
| **Steady Start** ✱ | começa a run com 1 carta Common à escolha; −1 reroll | — |
| **Pack Mule** | arma especial com +50% cargas; −8% velocidade | 30 |
| **Lucky Draw** | ofertas com 4 cartas; sem Skip | 45 |
| **Glass Jaw** | +20% dano; não há Patch Up na loja | 40 |
| **Breaker Instinct** | *breaker* com 2 cargas; cooldown +40% | 45 |
| **Collector** | +1 oferta aleatória na loja; preços +15% | 35 |
| **Iron Will** | sobrevive 1× a dano fatal por run com 1 vida; vida máxima −25 | 60 |
| **Specialist** | começa com uma arma especial aleatória; Special Ammo custa +50% | 50 |
| **Last Stand** | após o objetivo de cada ilha, cura total; não há cura no barco | 55 |

### 3.4 Dificuldade: Tide

Níveis de dificuldade à Hazard (Deep Rock) ou Heat (Hades), com nome do
mundo: a **maré** da horda. Desbloqueia-se o nível seguinte ao **extrair** no
anterior.

| Tide | Regra acrescentada (cumulativa) | Intel |
|---|---|---|
| 1 | base | ×1,0 |
| 2 | +1 especial por encontro; loja −1 oferta | ×1,2 |
| 3 | elites com uma modificação aleatória; Volcano com 2 fases | ×1,4 |
| 4 | o diretor encurta os períodos de alívio; Patch Up custa ×2 | ×1,6 |
| 5 | o boss de cada ilha é obrigatório antes de sair | ×1,8 |

Regras que mudam **o que o jogador tem de fazer**, não só HP e dano dos
inimigos, porque "inimigos com +30% vida" é o "+X%" do lado da dificuldade.

**Modificadores de expedição** (ver P2 de `legacy/PROJECT_AUDIT.md`): a partir
de Tide 2, antes da run, até 2 modificadores opcionais, cada um com +10% de
Intel (p. ex. *Spitter Season*, *Short Fuse*: relógio mais curto, *Fog Bank*:
visibilidade menor). Não custam Intel: desbloqueiam-se ao atingir Tide 2.

⚑ **Escala da horda:** com centenas de zombies, as regras de Tide podem subir
densidade; com dezenas + especiais, sobem composição. O orçamento global de
inimigos não sobe com Tide (lição do original: 90 ativos, dificuldade pela
composição).

---

## 4. Classes

Três classes, sem árvores. Cada uma é definida por **quatro coisas**: arma
base, habilidade ativa, passiva e uma carta exclusiva que só ela pode sortear.
Uma **passiva alternativa** desbloqueável (60 Intel) dá a escolha horizontal
que as variantes do original tentavam dar, sem exigir mastery.

Os nomes mantêm os do original; papéis e loadouts foram revistos para não se
sobreporem.

| | **Recruit** | **Renegade** | **Medic** |
|---|---|---|---|
| Papel | dano sustentado a média distância | abrir caminho na horda de perto | resistir e controlar a área |
| Arma base (infinita) | Assault Rifle | Shotgun | SMG |
| Habilidade ativa | **Frag Grenade** — explosão de 4 m que empurra; 12 s de cooldown | **Bull Rush** — investida de 6 m que atravessa e derruba, sem dano recebido durante; 10 s | **Med Field** — área de 5 m durante 6 s: cura 8 vida/s e abranda a horda 30%; 20 s |
| Passiva | **Drilled**: recarga 25% mais rápida | **Thick Skin**: 150 de vida; abates a ≤ 3 m curam 1 | **Field Medic**: regenera 3 vida/s após 4 s sem dano |
| Passiva alternativa | **Overwatch**: parado 1 s → +25% dano até se mexer | **Bloodrush**: 110 de vida; cada abate a ≤ 3 m dá +5% velocidade (máx. 5) | **Combat Stims**: sem regen; cada abate cura 2 |
| Carta exclusiva | **Cook Off** (R): a granada larga 3 fragmentos que explodem | **Momentum** (R): o Bull Rush deixa uma onda de choque no fim | **Triage** (R): o Med Field também repõe 1 carga da arma especial |
| Desbloqueio | inicial | 60 Intel | 120 Intel |

As cartas exclusivas somam-se às 18 do catálogo comum (o jogador vê sempre 19
possíveis). Ficam fora da contagem ⅓/⅔ porque só uma está ativa por run.

Porquê estas: cada classe tem um **verbo diferente** (lançar, investir,
ancorar uma zona) e uma distância preferida diferente. O verbo *breaker*
(dash/empurrão) é **comum a todas** e vem de `COMBAT_AND_ENEMIES.md`; as
habilidades ativas foram escolhidas para não o duplicarem (o Bull Rush é mais
longo, com cooldown maior e derruba em vez de empurrar).

O Medic funciona **a solo** (lição do original: nada que dependa de aliados).

⚑ **Direção:** se o jogo for B (shooter tático), o Recruit ganha peso com
headshots e o Renegade arrisca-se a ser dominante em corredores. Rever no
spike de combate.

Classes futuras (Heavy Gunner, Recon Scout…) ficam fora até haver
playtest das três; a regra do original mantém-se: classe nova só com papel,
passiva, loadout e verbo próprios.

---

## 5. Tabela de ritmo

Pressupostos (a medir): Intel médio por run de **~25** nas runs 1–5, **~50**
nas 6–10 e **~70** nas 11–20 (mais extrações, Tide mais alto). Acumulado:
~125 ao fim da 5.ª, ~375 ao fim da 10.ª, ~1 075 ao fim da 20.ª.

| Ao fim de… | Intel acumulado | O que o jogador tem desbloqueado (caminho típico) | O que já viu dentro das runs |
|---|---|---|---|
| **1 run** | ~20 | Nada comprado ainda (Ricochet a 30 está à vista). | Subir de nível, 12 cartas, barco e loja, 1–2 ilhas. Provavelmente morreu na 2.ª ilha. |
| **5 runs** | ~125 | Renegade; 1–2 cartas novas (Ricochet, Tripwire). Primeira extração em Tide 1 → **Tide 2** e **2.º slot de perk**. | Primeira evolução (Howitzer Rifle é a mais fácil de montar com o Recruit). |
| **10 runs** | ~375 | Medic; Railgun; 4 das 6 cartas (≈ 360 gastos). O primeiro perk novo ou o Field Manual vêm logo a seguir. Tide 2–3. | 3–4 evoluções diferentes; primeiros modificadores de expedição. |
| **20 runs** | ~1 075 | Quase todo o catálogo: as 3 classes com passivas alternativas, as 4 armas especiais, as 18 cartas, a maior parte dos perks; **3.º slot** se extraiu em Tide 3. Tide 3–4. | Todas as evoluções; combinações de perks com trocas reais. |
| **depois** | | O catálogo acaba à volta da run 22–25. O que resta é **Tide 4–5** e modificadores. | |

Porquê esta curva: algo novo **quase em cada uma das primeiras 10 runs**
(Ricochet a 30, Renegade a 60 e Railgun a 50 são deliberadamente baratos),
mais espaçado depois. O catálogo acaba antes de cansar; daí em diante, a
motivação é a dificuldade, não comprar.

Isto **não** é uma escada de poder: o jogador da run 20 é mais versátil, não
precisa de ser mais forte. A dificuldade sobe porque ele escolhe Tide mais alto.

---

## 6. O que fica de fora (não vamos fazer)

| Sistema do original | Destino | Porquê |
|---|---|---|
| Credits | substituído por Intel | uma moeda meta |
| XP de personagem e níveis sem teto | removido | era uma segunda curva de XP só para dar skill points |
| Skill tree (54 nós, 57 compras/classe; proposta de 36) | substituída por perks em slots | "+X%" permanente; difícil de balancear e de explicar |
| Mastery e variantes de classe | substituídas pela passiva alternativa | mesma ideia (escolher uma identidade), sem pré-requisitos de grind |
| ARMORY (compra de armas base) | removido | a arma base é da classe; armas especiais encontram-se na run |
| Evoluções por contadores de mortes | substituídas por arma + catalisador | combinação legível e planeável |
| Depósito de Scrap e melhorias da base | removidos | o barco é a loja; nada se acumula entre ilhas além do Scrap no bolso |
| 5 raridades | 3 | as raridades intermédias não mudavam decisões |

---

## 7. Decisões propostas

O utilizador decide; nenhuma destas está em `DECISIONS.md`.

| # | Proposta | Alternativa |
|---|---|---|
| P1 | **Duas camadas**: run (XP→cartas, Scrap→barco) e meta (Intel→desbloqueios). | manter uma árvore pequena (~15 nós) em vez de perks |
| P2 | **Scrap não converte em Intel.** | converter 10% para não "perder" Scrap ao morrer |
| P3 | **Arma base infinita + uma arma especial com cargas.** | munição limitada em tudo, como o original |
| P4 | **Catálogo inicial de 18 cartas** (6 stats, 12 comportamento), 3 raridades, ≥ 1 comportamento por oferta. | — |
| P5 | **Evolução = arma + catalisador no rank máximo**, oferecida na subida seguinte. | evolução comprada no barco |
| P6 | **Perks em slots** (1→3, abertos por feitos) em vez de skill tree. | slots comprados com Intel |
| P7 | **Dificuldade Tide 1–5**, regras novas em vez de só stats. | modificadores à Heat livres, sem níveis |
| P8 | **Três classes** (Recruit, Renegade, Medic) com ativa + passiva + carta exclusiva + passiva alternativa. | duas classes no vertical slice |
| P9 | **Morrer conserva o Intel**; extrair dá ×1,5. | morrer conserva só 50% |

## 8. Perguntas para o utilizador

1. **Converter Scrap em Intel no fim (P2)?** Recomendo **não**: assim o barco
   é sempre uma decisão de "gastar agora".
2. **Perks ou árvore pequena (P6)?** Recomendo **perks**: cada um explica-se
   numa linha e trocam-se entre runs sem respec.
3. **Quantas classes no vertical slice?** Recomendo **uma (Recruit)**, como
   diz o BRAINSTORM §9, e as outras duas logo a seguir para testar a escolha.
4. **Morrer pesa quanto (P9)?** Recomendo **conservar 100%**: o jogo já
   pune com o tempo perdido; a extração é o bónus.
5. **Nomes:** "Intel" para a moeda meta e "Tide" para a dificuldade
   agradam-te? São texto de jogo, fáceis de mudar.
6. **Ritmo de cartas:** ~16 escolhas em 25 min (uma a cada ~90 s) é o alvo
   certo? Mais escolhas aproximam o jogo de um survivors (A); menos, de um
   shooter tático (B).

## 9. O que medir no vertical slice

Telemetria por run (JSON, como proposto no BRAINSTORM §8):

- tempo de cada subida de nível e XP/min por ilha (valida a curva de 1.1);
- cartas oferecidas, escolhidas, skip e reroll (há cartas que ninguém escolhe?);
- Scrap ganho por ilha e gasto por item (alguém compra Field Manual?);
- cargas da arma especial gastas e minutos sem cargas;
- Intel por run, com causa (objetivo, boss, extração, primeira vez).

Critério para mudar um número: **dados de pelo menos 5 runs**, não uma
impressão de uma.
