# Catálogo de combate — revisão de valores atuais

Estado verificado em **2026-10-10**, incluindo as alterações locais ainda sem
commit. Este documento regista o que o jogo executa hoje; não aprova novos
valores nem altera o equilíbrio. A proposta de design em
[CARDS_WEAPONS_PERKS.md](../design/CARDS_WEAPONS_PERKS.md) contém também valores
anteriores e funcionalidades por implementar: não deve ser lida como catálogo
atual.

**5 armas · 39 cartas · 2 classes jogáveis · 7 inimigos · 5 perks.**
Os nomes apresentados mantêm o inglês usado no jogo. HP significa vida;
DPS significa dano por segundo; `r` significa rank da carta.

## 1. Armas

Todas as classes podem usar todas as armas desbloqueadas. Assault Rifle,
Shotgun e Heavy Pistol fazem parte de todas as runs; comprar SMG ou Marksman
acrescenta-as às runs seguintes. Ainda não existe escolha de arma principal
e secundária.

### Valores base

| Arma / ID | Dano por projétil | Tiros/s | Alcance | Projéteis por tiro | Dispersão total | Alvos por projétil | Munição máxima | Empurrão por acerto | Desbloqueio Intel |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|
| Assault Rifle / `rifle` | 12 | 9 | 30 m | 1 | 2° | 1 | Infinita | 0,05 m | Inicial |
| Shotgun / `shotgun` | 9 | 1,4 | 12 m | 8 | 22° | 2 | 40 tiros | 0,6 m | Inicial |
| Heavy Pistol / `pistol` | 60 | 2,2 | 35 m | 1 | 0° | 4 | 60 tiros | 0,3 m | Inicial |
| SMG / `smg` | 7 | 16 | 18 m | 1 | 7° | 1 | 300 tiros | 0,02 m | 60 |
| Marksman Rifle / `marksman` | 110 | 1,2 | 45 m | 1 | 0° | 6 | 30 tiros | 0,5 m | 80 |

Perfuração conta o **total** de alvos, incluindo o primeiro. Cada tiro da
Shotgun gasta uma munição, apesar dos oito projéteis. Não há carregadores nem
recarga manual: munição é a reserva total. Não há críticos aleatórios nem
queda de dano com a distância dentro do alcance.

### Comparação teórica, sem melhorias

| Arma | Dano por tiro no corpo | Dano por tiro em headshot | DPS num alvo | DPS agregado máximo com perfuração | Munição ÷ cadência |
|---|---:|---:|---:|---:|---:|
| Assault Rifle | 12 | 30 | 108 | 108 | Ilimitado |
| Shotgun | 72 | 180 | 100,8 | 201,6 | 28,57 s |
| Heavy Pistol | 60 | 150 | 132 | 528 | 27,27 s |
| SMG | 7 | 17,5 | 112 | 112 | 18,75 s |
| Marksman Rifle | 110 | 275 | 132 | 792 | 25 s |

São **limites de cálculo**, não DPS medido em jogo: assumem todos os
projéteis acertados, alvos alinhados quando há perfuração, ausência de
armadura, sprint e interrupções. Na Shotgun, 180 exige os oito projéteis
acertarem o alvo marcado para headshot. Outros inimigos atravessados pelo
mesmo tiro recebem dano de corpo. A última coluna é uma comparação de
reserva, não uma medição do instante do último disparo.

### Modificadores que já funcionam

- Headshot: dano ×2,5. Apenas o alvo selecionado recebe o marcador de
  headshot; os restantes alvos perfurados não o recebem.
- Assault Rifle: Hollow Points, Fast Hands, Ricochet, Pop Goes the Head,
  Piercing Rounds, Steady Aim, Point Blank, Finish the Job e nove cartas
  elementais. As outras armas **não ativam** esses efeitos exclusivos.
- Todas as armas: Executioner aumenta dano contra atordoados/congelados;
  Battle Rhythm aumenta cadência após War Cry. Field Medic e Second Breath
  recompensam abates por headshot.
- Munição finita: Pack Rat aplica ×1,5; Bigger Mags aplica `1 + 0,15r`;
  Supply Shortage divide a capacidade por dois. O jogo trunca para inteiro
  nas etapas do cálculo. Bigger Mags não repõe munição.
- Ao esgotar uma arma, o jogo volta à Assault Rifle. Um gerador concluído
  repõe metade da capacidade atual das armas finitas, até ao máximo.

## 2. Personagens e classes

### Jogáveis

| Classe / ID | Intel | HP inicial e máximo base | Velocidade | Sprint | Breaker: distância / cooldown | Habilidade |
|---|---:|---:|---:|---:|---|---|
| Recruit / `recruit` | Grátis | 100 | 6 m/s | 9,6 m/s | 5 m / 6 s | Grenade |
| Vanguard / `vanguard` | 150 | 140 | 6 m/s | 9,6 m/s | 5 m / 4,2 s | War Cry |

As diferenças base do Vanguard são **+40 HP** e cooldown do Breaker
**−30%**. Não tem dano de arma ou velocidade base adicionais.

| Stat partilhado | Valor / comportamento atual |
|---|---|
| Escudo | Começa em 0; capacidade 100; absorve antes da vida; sem regeneração automática |
| Estamina | 3 s de sprint; recuperação de 0,75 s de estamina/s após 0,8 s de espera |
| Sprint | Velocidade ×1,6; impede disparos; indisponível enquanto agarrado |
| Raio de colisão | 0,4 m |
| Breaker | 5 m em 0,18 s; 15 dano no impacto final; raio 2,2 m; atordoa 1 s |
| Empurrão durante Breaker | 0,6 m por aplicação aos inimigos próximos; repetido durante a investida, não um total único |
| Proteção do Breaker | 0,4 s de proteção contra corpo a corpo; explosões de Bloater, lava e ataques especiais do boss ignorados durante a investida |
| Libertar Grabber | Breaker solta-o, atordoa 2 s e empurra 2,5 m |
| Dano corpo a corpo recebido | Soma limitada a 25 por passo da simulação, antes da redução de War Cry e do escudo |
| Atração de XP | Raio 3 m; orbes aproximam-se a 14 m/s e são recolhidos a menos de 0,8 m |
| XP a partir do nível 30 | Recolha automática de toda a XP no chão da ilha/parte atual, incluindo na transição para 30 |

**Mira atual:** na câmara fixa, o cone tem semiângulo de 50°, ou seja
**±50° e 100° totais**. O alvo é escolhido por distância + 0,4 m por grau
de desvio; inimigos a menos de 2,5 m recebem prioridade, mas ainda têm de
estar no cone e visíveis. Headshot a ±9°. Nas câmaras com mira, o limite
angular é 6° em relação ao corpo; a cabeça usa raio `0,4 × escala visual`
em metros. Head Hunter amplia este raio por 15/9. Estes números não são
probabilidades de crítico.

### Habilidades

| Stat | Grenade — Recruit | War Cry — Vanguard |
|---|---|---|
| Cooldown base | 12 s | 16 s |
| Alcance / raio | Lançamento até 14 m; explosão 5 m | 7 m em redor do jogador |
| Dano base | 90 por inimigo atingido | Sem dano direto |
| Tempo | Explode após 0,8 s | Proteção durante 5 s |
| Atordoamento | 0,6 s | 1,5 s |
| Empurrão | 2 m | 1 m |
| Proteção | — | Corpo a corpo recebido ×0,6, ou seja −40% |
| Cartas específicas | Grenadier, Wide Blast, Concussion | Rally, Intimidation, Battle Rhythm |

O lançamento da granada para na primeira parede. A pesquisa de inimigos
na explosão e no War Cry usa raio, sem teste de linha de visão. Brute e
Behemoth não podem ser empurrados, mas podem ser atordoados.
War Cry **não reduz** dano de lava, explosão de Bloater, slam ou rochas.

### Outras personagens

| Personagem | Estado e stats |
|---|---|
| Sobrevivente da missão Rescue | NPC: 100 HP; 5,6 m/s; encontrado a 3 m; segue quando está a mais de 2 m; sofre 7 HP/s por inimigo a 1,3 m, até seis inimigos, máximo 42 HP/s |
| Director Hale | Personagem de rádio; sem entidade de combate nem stats de HP/dano |
| Field Medic como classe | Planeada no conceito inicial; não existe no registo atual de classes e Med Kit não está implementado |

**Field Medic já é o nome de uma carta** (`vampire`), não de uma terceira
classe. São conceitos distintos com o mesmo nome.

## 3. As 39 cartas

Cada escolha acrescenta um rank. Os aumentos percentuais são aditivos
dentro da mesma fórmula, salvo o cooldown multiplicativo de Hair Trigger e
Grenadier. Os valores máximos abaixo isolam cada carta, sem outros perks
ou cartas.

### Assault Rifle — 8 cartas

Estas cartas exigem possuir a Assault Rifle; o efeito de combate usa essa
arma. Ambas as classes podem recebê-las.

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo |
|---|---:|---|---|
| Hollow Points / `hollow_points` | 5 | Dano base da AR ×`(1 + 0,10r)` | +50%; 12 → 18 por bala |
| Fast Hands / `fast_hands` | 5 | Cadência da AR +8% por rank | +40%; 9 → 12,6 tiros/s isoladamente |
| Ricochet / `ricochet` | 3 | Cada quarto tiro de AR que acerte o alvo ricocheteia para `r` alvos adicionais; 60% do dano do acerto original; até 6 m por salto | Até 3 ricochetes |
| Pop Goes the Head / `explosive_heads` | 3 | Abate direto de AR por headshot: explosão de raio 3 m, `15 + 15r` dano | 60 dano por inimigo na área |
| Piercing Rounds / `piercing_rounds` | 3 | AR atravessa mais um alvo por rank | 4 alvos totais por bala |
| Steady Aim / `steady_aim` | 3 | AR parada: +8% cadência por rank | +24%; 11,16 tiros/s isoladamente |
| Point Blank / `point_blank` | 3 | Dano da AR ×`(1 + 0,10r)` a distância ≤4 m | +30% nesse alcance |
| Finish the Job / `finish_the_job` | 3 | Dano da AR ×`(1 + 0,15r)` se alvo tiver menos de 30% da vida máxima escalada | +45% nessa condição |

Fast Hands e Steady Aim somam os bónus de cadência: ambos no máximo dão
**14,76 tiros/s** parado, antes de Battle Rhythm. Hollow Points, Point
Blank e Finish the Job multiplicam entre si quando as condições coincidem.
Os ricochetes não repetem inimigos já atingidos pelo disparo e escolhem o
vizinho vivo mais próximo com linha de visão. O seu dano pode transportar
o multiplicador do headshot original, mas o ricochete não conta como outro
headshot.

### Elementos — 9 cartas

O filtro de oferta exige possuir a Assault Rifle. Apenas acertos diretos
da AR sorteiam fogo, frio, veneno e descarga. Cada elemento tem sorteio
independente: podem ocorrer vários no mesmo acerto. `+5%` significa mais
cinco pontos percentuais de probabilidade por rank, até 25%.

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo / requisito |
|---|---:|---|---|
| Wind Rounds / `wind_rounds` | 5 | Acertos de AR acrescentam `0,15r` m de empurrão | +0,75 m; total 0,8 m; sem efeito nos não empurráveis |
| Fire Rounds / `fire_rounds` | 5 | 5% por rank de queimadura: 8 dano/s durante 3 s | 25%; 24 dano por aplicação completa sem modificadores |
| Frost Rounds / `frost_rounds` | 5 | 5% por rank de frio: −15% velocidade por aplicação durante 4 s; terceira aplicação congela 1 s e consome o frio | 25% de aplicação; boss recebe −7,5% por aplicação, até −22,5%, sem congelar |
| Storm Rounds / `storm_rounds` | 5 | 5% por rank de descarga: um salto a até 6 m, 60% do dano do acerto | 25% de descarga |
| Toxic Rounds / `toxic_rounds` | 5 | 5% por rank de veneno: 6 dano/s durante 4 s | 25%; 24 dano por aplicação completa sem modificadores |
| Wildfire / `wildfire` | 3 | Abate não secundário de inimigo queimado transmite queimadura de 3 s a até `r` vizinhos a 6 m | Até 3 vizinhos; exige Fire Rounds I |
| Deep Freeze / `deep_freeze` | 3 | Congelamento dura `1 + 0,25r` s | 1,75 s; exige Frost Rounds I; boss continua sem congelar |
| Chain Lightning / `chain_lightning` | 3 | Descarga ganha um salto por rank | Até 4 saltos totais antes da combinação; exige Storm Rounds I |
| Toxic Cloud / `toxic_cloud` | 3 | Abate não secundário de inimigo envenenado cria nuvem de raio 2 m, 6 dano/s, durante `1 + r` s | 4 s; 24 dano por inimigo que permaneça dentro, antes de modificadores; exige Toxic Rounds I |

Fogo e veneno renovam duração sem somar várias instâncias do mesmo estado.
Podem coexistir. Frio renova a duração das aplicações acumuladas. Congelar
impede movimento, ataques e agarres; atordoar também interrompe ataques.

**Nota de execução:** Wildfire e Toxic Cloud estão no ramo de abates
`não secundários`, que inclui granada e Breaker contra inimigos previamente
afetados. Apesar do filtro de AR, não exigem que o golpe fatal seja de AR.
Abates por queimadura, veneno, nuvem, ricochete ou descarga não propagam
estes efeitos.

### Combinações automáticas — não são cartas adicionais

| Combinação | Condição | Efeito |
|---|---|---|
| Thermal Shock | Aplicar fogo a inimigo congelado, possuindo Frost Rounds | 30 dano e descongelamento; fogo mantém-se se o alvo sobreviver |
| Conductive Frost | Descarga num inimigo com aplicações de frio, possuindo Frost Rounds | Mais um salto; com Chain Lightning III pode chegar a 5 saltos |
| Toxic Combustion | Aplicar fogo a inimigo dentro de uma nuvem tóxica, até 2 m do centro | Consome a nuvem; explosão de 25 dano num raio de 3 m |

Estes danos são secundários e não voltam a sortear elementos. Executioner
pode aumentar dano secundário contra alvos atordoados/congelados.

### Defesa, cura e utilidade — 10 cartas

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo / condição |
|---|---:|---|---|
| Thick Hide / `thick_hide` | 5 | Cada escolha acrescenta 15 HP máximos e cura 15 HP, até ao novo máximo | +75 HP máximos; Recruit 175 / Vanguard 215, sem Thick Skin |
| Field Medic / `vampire` | 5 | Cada abate por headshot cura `r` HP | 5 HP por abate por headshot; qualquer arma |
| Kill Rations / `kill_rations` | 5 | A cada múltiplo de dez abates na run, cura `2r` HP | 10 HP a cada dez abates; inclui abates secundários |
| Field Dressing / `field_dressing` | 5 | Cada orbe de XP recolhido cura `0,2r` HP | 1 HP por orbe, independentemente do valor de XP |
| Catch Your Breath / `catch_your_breath` | 3 | Após 5 s sem sofrer dano, regenera `0,5r` HP/s | 1,5 HP/s; dano absorvido pelo escudo também reinicia a espera |
| XP Magnet / `magnet` | 5 | Raio de atração de XP = `3 × (1 + 0,40r)` m | 9 m; a partir do nível 30 a recolha global torna o efeito redundante |
| Bigger Mags / `bigger_mags` | 5 | Capacidade das armas finitas ×`(1 + 0,15r)` | +75%: Shotgun 70, Pistol 105, SMG 525, Marksman 52, sem outros modificadores |
| Fast Learner / `fast_learner` | 5 | XP recolhida ×`(1 + 0,05r)`; fração conservada entre recolhas e ilhas | +25% XP; combina multiplicativamente com Double XP |
| Light Boots / `light_boots` | 5 | Velocidade de caminhada e sprint ×`(1 + 0,04r)` | +20%; 7,2 m/s a andar, 11,52 m/s em sprint; não aumenta distância do Breaker |
| Second Breath / `second_breath` | 3 | Abate por headshot repõe `0,1r` s de estamina | 0,3 s por abate; limitado ao máximo de 3 s |

Bigger Mags exige uma arma finita **possuída na run**, não a arma atualmente
selecionada. As restantes cartas desta tabela servem ambas as classes e
não têm pré-requisitos. A cura não ultrapassa HP máximos nem repõe escudo.

### Breaker — 6 cartas

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo |
|---|---:|---|---|
| Hair Trigger / `quick_breaker` | 5 | Cooldown do Breaker ×`0,9^r` | Recruit 3,543 s; Vanguard 2,480 s, antes de Adrenaline |
| Shockwave Breaker / `shockwave` | 5 | Dano final `15 + 15r`; raio `2,2 × (1 + 0,20r)` m | 90 dano; 4,4 m de raio |
| Adrenaline / `adrenaline` | 3 | Cada abate retira `0,1r` s ao cooldown restante do Breaker | −0,3 s por abate; inclui abates secundários; mínimo zero |
| Executioner / `executioner` | 5 | Dano contra atordoados ou congelados ×`(1 + 0,20r)` | ×2; todas as armas, habilidades e danos secundários |
| Aftershock / `aftershock` | 3 | Atordoamento aplicado ao longo do Breaker = `1 + 0,20r` s | 1,6 s; não aumenta os 2 s do ato específico de libertar um Grabber |
| Crowd Splitter / `crowd_splitter` | 3 | Empurrão durante Breaker = `0,6 + 0,40r` m por aplicação | 1,8 m por aplicação; Brute e Behemoth imunes ao empurrão |

Executioner aparece na categoria Breaker, mas o seu alcance é **qualquer
dano do jogador** contra o estado indicado. O Breaker atordoa durante a
passagem antes do impacto final; isso permite beneficiar de Executioner.

### Exclusivas do Recruit — 3 cartas

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo, sem perks |
|---|---:|---|---|
| Grenadier / `grenadier` | 5 | Cooldown da granada = `12 × 0,9^r` s | 7,086 s; com Demolitions, 4,606 s |
| Wide Blast / `wide_blast` | 3 | Raio da granada = `5 + 0,4r` m | 6,2 m; com Demolitions, 7,2 m |
| Concussion / `concussion` | 3 | Atordoamento da granada = `0,6 + 0,25r` s | 1,35 s |

### Exclusivas do Vanguard — 3 cartas

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo |
|---|---:|---|---|
| Rally / `rally` | 5 | Ativar War Cry cura `5r` HP | 25 HP por ativação |
| Intimidation / `intimidation` | 3 | Empurrão do War Cry = `1 + 0,4r` m | 2,2 m; não aumenta o raio nem empurra Brute/Behemoth |
| Battle Rhythm / `battle_rhythm` | 3 | War Cry dá +8% cadência por rank durante 3 s | +24% em qualquer arma; soma aos bónus de cadência da AR |

Nenhuma destas três altera o cooldown de 16 s do War Cry.

### Regras de seleção e progressão

- Catálogo: **157 ranks** somados; cada classe tem acesso a 36 cartas,
  porque as três da outra classe ficam excluídas, assumindo as armas
  iniciais presentes.
- Cartas no rank máximo não aparecem em level-ups, rerolls ou mantimentos.
  Pré-requisitos e filtros de classe/armas aplicam-se antes do sorteio.
- Oferta: uma carta nova e uma melhoria, quando existirem ambas; terceiro
  lugar ponderado. Melhorias têm peso ×1,5; uma etiqueta partilhada com a
  build dá ×1,25. Sem duplicados; com poucas elegíveis aparecem só uma ou
  duas opções. Mantimento de carta oferece uma única elegível.
- Sem elegíveis: cura de 20 HP. Rerolls: dois iniciais, +1 por ilha
  intermédia concluída, reserva máxima três.
- XP do nível `n` para `n+1`: **`8 + 6n + n²`**. Exemplos: 1→2 = 15;
  10→11 = 168; 29→30 = 1023; 30→31 = 1088.
- Do nível 1 ao 30 são necessários **11 397 XP de progressão**. Fast Learner
  e Double XP aumentam quanto recebe cada orbe, reduzindo o número de
  abates/orbes necessários. Nível 30 não é o limite de níveis.
- XP Magnet ainda pode ser oferecida depois do nível 30 se tiver ranks
  disponíveis; não existe um filtro para a nova recolha global.

## 4. Inimigos

### Stats base, antes da dificuldade

| Inimigo / ID | HP | Velocidade sorteada | Dano de contacto definido | Intervalo | DPS de contacto bruto | XP por abate | Redução frontal | Empurrável |
|---|---:|---|---:|---:|---:|---:|---:|---|
| Walker / `walker` | 30 | 1,8–2,6 m/s | 8 | 1 s | 8 | 1 | 0% | Sim |
| Runner / `runner` | 18 | 4,6–5,4 m/s | 6 | 0,7 s | 8,57 | 1 | 0% | Sim |
| Brute / `brute` | 260 | 1,6–1,9 m/s | 25 | 1,6 s | 15,63 | 6 | 75% | Não |
| Grabber / `grabber` | 70 | 2,8–3,2 m/s | 4 | 0,5 s | 8 | 3 | 0% | Sim |
| Behemoth / `behemoth` | 1800 | 1,7 m/s; 2,7 na fase 2 | 35 | 1,4 s | 25 bruto | 40 | 50% | Não |
| Bloater / `bloater` | 90 | 1,3–1,5 m/s | 10 | 1,2 s | 8,33 | 3 | 0% | Sim |
| Screamer / `screamer` | 45 | 3–3,4 m/s | 3 | 1 s | 3 | 4 | 0% | Sim |

DPS bruto é `dano / intervalo`, sem atordoamento, congelamento, distância,
War Cry ou limite por passo. **O golpe de contacto de 35 do Behemoth também
entra no limite de 25 por passo**, pelo que sozinho entrega até 25 por
golpe, cerca de 17,86 HP/s antes de outras reduções. Slam e rochas usam
outro caminho e não entram nesse limite.

O alcance de contacto usa `1,1 + 0,4 = 1,5 m` entre centros para todos os
tipos. Na movimentação a horda usa um raio comum de **0,35 m**; o tamanho
visual não cria uma colisão proporcional. A pesquisa dos tiros usa um raio
comum aproximado de **0,443 m** (`0,35 × √1,6`); a mira em primeira/terceira
pessoa usa também o tamanho visual para reconhecer o corpo e a cabeça.

| Inimigo | Altura | Escala visual | Comportamento específico |
|---|---:|---:|---|
| Walker | 1,7 m | 1 | Aproxima-se e ataca |
| Runner | 1,6 m | 0,85 | Aproxima-se mais depressa; pouca vida |
| Brute | 2,4 m | 1,6 | Blindagem frontal; resiste a empurrão, não a atordoamento/congelamento |
| Grabber | 1,9 m | 1,1 | Agarra ao atacar; só um agarre ativo; impede deslocação normal/sprint; morte, congelamento ou Breaker libertam |
| Behemoth | 4,2 m | 3 | Chefe; blindagem frontal, sem empurrão nem congelamento; aceita atordoamento e lentidão reduzida |
| Bloater | 1,6 m | 1,7 | Ao morrer explode: raio 3,5 m, 20 dano ao jogador, 45 aos outros inimigos, empurrão de 1,5 m |
| Screamer | 1,8 m | 0,8 | Recua quando está a menos de 11 m, fora do alcance de contacto; pode chamar pico de horda |

**Blindagem frontal:** Brute recebe 25% e Behemoth 50% do dano quando a
velocidade indica que estão virados para a origem do ataque. Não é uma
armadura universal: com velocidade quase zero não há essa redução. Breaker,
granada, estados e várias explosões passam pelo caminho que a ignora;
tiros e ricochetes podem recebê-la.

**Screamer:** precisa de linha de visão a até 22 m, acumula 3 s para chamar
um pico de 15 s; cooldown global da chamada 15 s. A progressão é partilhada
entre Screamers: não exige que seja sempre o mesmo. Sem nenhum a ver o
jogador, desce em vez de voltar imediatamente a zero.

### Escala de HP por ilha e Threat

`HP efetivos = HP base × (1 + 0,3 × índice da ilha) × (1 + 0,2 × (Threat − 1))`

O índice começa em zero. A progressão por ilhas é **linear**: ×1, ×1,3,
×1,6; não é aplicar ×1,3 repetidamente. Numa expedição usa o índice da parte.

| Threat | HP ilha 1 | HP ilha 2 | HP ilha 3 | Intel | Aumento pedido ao limite do diretor |
|---|---:|---:|---:|---:|---:|
| 1 | ×1 | ×1,3 | ×1,6 | ×1 | +0 |
| 2 | ×1,2 | ×1,56 | ×1,92 | ×1,25 | +25 |
| 3 | ×1,4 | ×1,82 | ×2,24 | ×1,5 | +50 |

Exemplos no arquipélago: Walker na ilha 3/Threat 3 tem **67,2 HP**; Brute
tem **582,4 HP**; Behemoth na ilha 3 tem **2880 / 3456 / 4032 HP** para
Threat 1/2/3. Esta escala não aumenta velocidade, dano nem XP por abate.
Lava causa 30 dano/s aos inimigos e 18 ao jogador; Behemoth é imune à lava.

### Behemoth — ataques e fases

Surge na última ilha quando a tarefa principal fica concluída; não surge
na missão Holdout da expedição. Os cooldowns indicam o intervalo configurado;
posicionamento e ataques em curso podem atrasar uma ação.

| Ação | Fase 1 | Fase 2, abaixo de 50% HP |
|---|---|---|
| Movimento | 1,7 m/s | 2,7 m/s |
| Slam | Inicia a ≤9 m; aviso 1,2 s; raio 6 m; 30 dano; cooldown 5 s | Mesmo dano/raio/aviso; cooldown 3 s |
| Rocha | Lança a ≥12 m; voo/aviso 1,5 s; raio 2,5 m; 20 dano; cooldown 3,5 s | Mesmo dano/raio/aviso; cooldown 2,1 s |
| Invocação | A cada 9 s: até 4 Runners | A cada 9 s: até 4 Runners e 1 Brute |
| Contacto e blindagem | Stats da tabela base | Mantêm-se |

Invocações dependem de pontos livres e alcançáveis. O chefe não ganha HP
ao mudar de fase. Nuke impede invocações e spawns normais durante 5 s.

### Diretor e composição da horda

- Começa com 6 s de calma. Relax dura normalmente 10–15 s; Build up cresce
  de 0,6 a 2,5 spawns/s em 30 s; Peak usa 4,5 spawns/s durante 12–18 s.
  Há também picos forçados por objetivos/Screamer.
- A taxa multiplica por `1 + tempo do diretor / 600`. Ilhas posteriores
  começam com mais 120 s de tempo do diretor por índice da ilha.
- Base: limite do diretor 150 no pico e 60% desse valor durante Build up.
  Swarm pede +40; Threat pede +25/+50; Hazard Pay multiplica primeiro por
  1,25. Contudo, o spawn normal tem um segundo limite fixo de 150 — ver
  pontos de revisão abaixo. Invocações do chefe não passam por esse limite.
- Jungle aplica ×1,4 à frequência de especiais. Elite Pack atribui ×2
  aos especiais; **substitui**, não multiplica, o ×1,4 de Jungle.

| Tipo | Probabilidade base no início do diretor | Aos 300 s ou mais |
|---|---:|---:|
| Walker | 76% | 52% |
| Runner | 15% | 25% |
| Brute | 2% | 6% |
| Grabber | 4% | 9% |
| Bloater | 2% | 5% |
| Screamer | 1% | 3% |

O crescimento é linear até aos 300 s, depois estabiliza. Jungle/Elite
aumentam Brute, Grabber, Bloater e Screamer, retirando a diferença ao
Walker; Runner mantém a sua percentagem. O diretor não sorteia Behemoth.

## 5. Perks e outros modificadores

Os perks são compras permanentes, com um único nível atual; só produzem
efeito quando equipados. Existem três slots, o primeiro grátis e os
adicionais por 100 e 250 Intel. A árvore de ranks continua por implementar.

| Perk / ID | Intel | Efeito executado |
|---|---:|---|
| Thick Skin / `thick_skin` | 40 | +30 HP máximos e iniciais; não reduz dano |
| Pack Rat / `pack_rat` | 40 | +50% capacidade de todas as armas finitas, incluindo SMG e Marksman |
| Head Hunter / `head_hunter` | 60 | Cone de headshot ±9° → ±15°; na mira 1.ª/3.ª pessoa amplia o raio de cabeça por 15/9 |
| Battering Ram / `long_breaker` | 50 | Distância do Breaker ×1,4: 5 → 7 m; mesma duração de 0,18 s |
| Demolitions / `demolitions` | 50 | Granada: cooldown ×0,65, 12 → 7,8 s; raio +1 m, 5 → 6 m; não aumenta dano |

HP máximo combinado de Vanguard + Thick Skin + Thick Hide V = **245 HP**;
Recruit com os mesmos perk/carta = **205 HP**. Escudo mantém capacidade 100.
Demolitions não tem filtro de classe ao equipar e não beneficia o War Cry.

| Modificador de rota / ID | Intel | Comportamento atual |
|---|---:|---|
| Calm Waters / `calm` | ×1 | Sem alteração |
| Swarm / `swarm` | ×1,3 | Pede +40 ao limite do diretor; sujeito ao limite fixo do spawn |
| Elite Pack / `elite` | ×1,3 | Frequência de Brute, Grabber, Bloater e Screamer ×2 |
| Sea Fog / `fog` | ×1,2 | Define densidade de nevoeiro 0,018; não altera HP/dano das armas ou dos inimigos |
| Supply Shortage / `short` | ×1,2 | Capacidade de munição finita dividida por dois; geradores repõem metade dessa capacidade reduzida |

Hazard Pay acrescenta ×1,25 Intel e pede ×1,25 ao limite do diretor durante
uma ilha. Extração final multiplica o Intel por ×1,5; morrer conserva o Intel
ganho sem esse prémio. Estes valores modificam recompensas, não o dano.

Os sete power-ups já implementados também alteram combate/recursos.
Valores, probabilidades e limites estão documentados em
[POWER_UPS_AND_DEFEAT.md](POWER_UPS_AND_DEFEAT.md): Insta-Kill, Double
XP/Intel, Nuke, Full Power, Max Armor, Fire Sale e Max Ammo.

## 6. Pontos para decidir na revisão

Esta lista distingue diferenças confirmadas no código de hipóteses de
equilíbrio. **Nenhuma foi corrigida ou reequilibrada nesta revisão.**

| Ponto | Constatação | Questão de design / correção a considerar |
|---|---|---|
| Identidade da SMG | 112 DPS contra 108 da AR (+3,7%), alcance 18 contra 30 m, maior dispersão, reserva equivalente a 18,75 s; não ativa as cartas exclusivas da AR | Dar-lhe um papel próprio, rever stats ou partilhar algumas cartas; não remover sem decisão |
| Distribuição de builds | 17/39 cartas ligadas à AR; Shotgun, Pistol, SMG e Marksman sem cartas exclusivas | Decidir se a AR é a base fixa com armas de recurso ou se queremos builds para cada arma |
| Field Medic | Nome já usado pela carta de cura; classe/Med Kit ainda ausentes | Escolher se a classe continua planeada e evitar nomes ambíguos |
| Limite da horda | Diretor permite mais de 150 em Swarm/Threat/Hazard; `_spawn_enemy()` recusa a partir de 150; chefe pode acrescentar invocações acima disso | Uniformizar limites e medir desempenho antes de aumentar a população |
| War Cry | Texto da classe promete −40% dano recebido; execução só reduz contacto corpo a corpo | Restringir a descrição ou aplicar a proteção também aos restantes danos |
| Pack Rat | Descrição cita Shotgun/Heavy Pistol; execução inclui todas as armas finitas | Atualizar texto para descrever o efeito real |
| Elite Pack | Descrição cita Brutes/Grabbers; execução também duplica Bloaters/Screamers; em Jungle substitui ×1,4 por ×2 | Corrigir texto e decidir se os multiplicadores devem acumular |
| Demolitions no Vanguard | Pode ocupar um slot sem melhorar War Cry | Filtrar por classe ou criar efeito equivalente para Vanguard |
| XP Magnet após nível 30 | Continua elegível antes do rank máximo, mas XP já é recolhida globalmente | Excluir da oferta, convertê-la ou aceitar a redundância |
| Acesso ao nível 30 | Curva atual exige 11 397 XP recebidos desde nível 1; cada Walker/Runner rende 1 XP base | Medir se o limiar é atingível numa run normal antes de rever a curva |
| Armadura e dimensão | Blindagem depende da velocidade; colisão/hitscan comuns apesar de tamanhos visuais diferentes | Confirmar se é a simplificação pretendida ou se chefes/especiais precisam de volumes próprios |
| Executioner | No rank V duplica qualquer dano contra atordoados, incluindo DOT, nuvens e Breaker | Medir builds de atordoamento e chefes; ainda não prova desequilíbrio |
| Largura do cone | O valor 50° é usado como semiângulo: 100° totais na câmara fixa | Confirmar se a intenção de «cone de 50°» era largura total ou desvio para cada lado |

Uma ordem útil de revisão é: **papel das armas → classes e habilidades →
cartas por build → inimigos e dificuldade**. Só depois escolher novos valores
e medir runs sem invulnerabilidade.

## 7. Fontes e verificação

- Catálogos carregados pelo Godot, incluindo defaults omitidos nos `.tres`:
  `game/data/weapons.tres`, `cards.tres`, `classes.tres`, `enemies.tres`,
  `perks.tres`, `modifiers.tres` e os respetivos recursos individuais.
- Regras partilhadas: `game/data/game_data.gd`.
- Classes/perks no início da run: `game/core/run_context.gd`.
- Efeitos, dano, habilidades, XP, dificuldade e boss:
  `game/world/island_run.gd`.
- Movimento, contacto, estados e pesquisa de tiros: `game/horde/horde.gd`.
- Frequência e composição: `game/world/director.gd`.
- Ofertas e filtros: `game/world/card_offers.gd`.

A exportação headless confirmou os seis catálogos; os números derivados
foram calculados a partir desses dados e comparados com as fórmulas do
código. Esta revisão documental **não é um playtest de equilíbrio**.
Não foram alterados scripts, recursos de gameplay nem testes nesta tarefa.
