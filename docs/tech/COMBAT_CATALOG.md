# Catálogo de combate — revisão de valores atuais

Catálogo atualizado em **2026-10-11**, incluindo a nova escala de XP aprovada
pelo utilizador e as alterações locais ainda sem commit. Este documento
regista o que o jogo executa hoje. A proposta de design em
[CARDS_WEAPONS_PERKS.md](../design/CARDS_WEAPONS_PERKS.md) contém também valores
anteriores e funcionalidades por implementar: não deve ser lida como catálogo
atual.

**5 armas · 39 cartas · 2 classes jogáveis · 7 inimigos · 5 perks.**
Os nomes apresentados mantêm o inglês usado no jogo. HP significa vida;
DPS significa dano por segundo; `r` significa rank da carta.

## 1. Armas

A opção B está implementada: cada run leva **uma principal e uma secundária**,
escolhidas no Armory. Desbloquear conserva a propriedade; equipar troca só
esse espaço. As teclas 1 e 2 selecionam principal/secundária e o D-pad permite
selecionar ou alternar. Quick Redeploy repete também as armas da última run.

### Valores base

| Arma / ID | Espaço | Dano | Tiros/s | Alcance | Projéteis / perfuração | Dispersão | Reserva | Intel |
|---|---|---:|---:|---:|---|---:|---|---:|
| Assault Rifle / `rifle` | Principal | 12 | 9 | 30 m | 1 / 1 | 2° | Infinita | Inicial |
| SMG / `smg` | Principal | 8; 10 até 6 m | 16 | 16 m | 1 / 1 | 7° | Infinita | 60 |
| Machine Gun / `machine_gun` | Principal | 18 | 12 | 32 m | 1 / 1 | 4° | Infinita | 120 |
| Shotgun / `shotgun` | Secundária | 9 | 1,4 | 12 m | 8 / 2 | 22° | 40 tiros | Inicial |
| Marksman Rifle / `marksman` | Secundária | 110 | 1,2 | 45 m | 1 / 6 | 0° | 30 tiros | 80 |

| Principal | Carregador | Recarga automática | Movimento enquanto equipada | DPS de corpo durante fogo / com recargas |
|---|---:|---:|---:|---|
| Assault Rifle | 30 | Instantânea, como antes | ×1,00 | 108 / 108 |
| SMG | 40 | 1,1 s | ×1,15 | 128 / 88,9; até 6 m: 160 / 111,1 |
| Machine Gun | 90 | 3,2 s | ×0,80 | 216 / 151,4 |

A SMG privilegia proximidade e mobilidade. A Machine Gun oferece mais fogo
sustentado, com penalizações de movimento e recarga. Estes números são
**hipóteses de playtest**, não valores finais. O modificador de movimento
aplica-se ao andar e sprint com a arma equipada; o Breaker conserva a distância.

São limites teóricos: assumem acertos de corpo contínuos, sem armadura,
sprint, mudanças de alvo ou melhorias. DPS com recargas usa
`dano × carregador / (carregador ÷ cadência + tempo de recarga)`.
Headshots multiplicam por 2,5. Shotgun tem 100,8 DPS por alvo se os oito
projéteis acertarem; Marksman tem 132, ou até 792 agregado em seis alvos.
Perfuração conta o total de alvos, incluindo o primeiro.

As recargas são independentes: pode usar-se a secundária enquanto a
principal recarrega. Os carregadores começam cheios em cada ilha, como
antes; a munição restante da secundária transita. O HUD mostra rounds/reserva
nas principais e o estado RELOADING quando aplicável. Não há recarga manual.

### Cartas, munição e saves

- As oito cartas antes exclusivas da Assault Rifle e as nove elementais
  passam a servir **qualquer principal**. A categoria é `primary_weapon`;
  os ids das cartas mantêm-se. As secundárias não recebem estes efeitos.
- Executioner, Battle Rhythm e recompensas por headshot mantêm as regras comuns.
- Pack Rat, Bigger Mags e Supply Shortage modificam a reserva da secundária;
  Max Ammo, Ammo Crate e geradores repõem-na. Não aumentam os carregadores.
- Esgotar a secundária regressa à principal equipada. Só as duas armas da
  run entram no HUD, nos filtros de cartas e nos cálculos de mantimentos.
- Heavy Pistol foi retirada do catálogo, YARD, menus, sons e modelos.
  Saves antigos descartam o desbloqueio e trocam a seleção pela Shotgun,
  **sem reembolso**, conforme escolha do utilizador. Seleções inválidas ou
  não desbloqueadas usam AR/Shotgun. Perfis antigos da última run também migram.

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

### Arma principal — 8 cartas

Estas cartas exigem uma principal equipada; o efeito de combate usa essa
arma. Ambas as classes podem recebê-las.

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo |
|---|---:|---|---|
| Hollow Points / `hollow_points` | 5 | Dano base da AR ×`(1 + 0,10r)` | +50%; 12 → 18 por bala |
| Fast Hands / `fast_hands` | 5 | Cadência da principal +8% por rank | +40%; 9 → 12,6 tiros/s isoladamente |
| Ricochet / `ricochet` | 3 | Cada quarto tiro de AR que acerte o alvo ricocheteia para `r` alvos adicionais; 60% do dano do acerto original; até 6 m por salto | Até 3 ricochetes |
| Pop Goes the Head / `explosive_heads` | 3 | Abate direto de AR por headshot: explosão de raio 3 m, `15 + 15r` dano | 60 dano por inimigo na área |
| Piercing Rounds / `piercing_rounds` | 3 | AR atravessa mais um alvo por rank | 4 alvos totais por bala |
| Steady Aim / `steady_aim` | 3 | AR parada: +8% cadência por rank | +24%; 11,16 tiros/s isoladamente |
| Point Blank / `point_blank` | 3 | Dano da principal ×`(1 + 0,10r)` a distância ≤4 m | +30% nesse alcance |
| Finish the Job / `finish_the_job` | 3 | Dano da principal ×`(1 + 0,15r)` se alvo tiver menos de 30% da vida máxima escalada | +45% nessa condição |

Fast Hands e Steady Aim somam os bónus de cadência: ambos no máximo dão
**×1,64 de cadência** parado (AR: 14,76 tiros/s), antes de Battle Rhythm. Hollow Points, Point
Blank e Finish the Job multiplicam entre si quando as condições coincidem.
Os ricochetes não repetem inimigos já atingidos pelo disparo e escolhem o
vizinho vivo mais próximo com linha de visão. O seu dano pode transportar
o multiplicador do headshot original, mas o ricochete não conta como outro
headshot.

### Elementos — 9 cartas

O filtro de oferta exige uma principal equipada. Apenas acertos diretos
da principal sorteiam fogo, frio, veneno e descarga. Cada elemento tem sorteio
independente: podem ocorrer vários no mesmo acerto. `+5%` significa mais
cinco pontos percentuais de probabilidade por rank, até 25%.

| Carta / ID | Ranks máximos | Efeito atual | Resultado no máximo / requisito |
|---|---:|---|---|
| Wind Rounds / `wind_rounds` | 5 | Acertos da principal acrescentam `0,15r` m de empurrão | +0,75 m; total 0,8 m; sem efeito nos não empurráveis |
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
- XP do nível `n` para `n+1`: **`10 × (8 + 6n + n²)`**. Exemplos: 1→2 = 150;
  10→11 = 1680; 29→30 = 10 230; 30→31 = 10 880.
- Do nível 1 ao 30 são necessários **113 970 XP de progressão**. Fast Learner
  e Double XP aumentam quanto recebe cada orbe, reduzindo o número de
  abates/orbes necessários. Nível 30 não é o limite de níveis.
- XP Magnet ainda pode ser oferecida depois do nível 30 se tiver ranks
  disponíveis; não existe um filtro para a nova recolha global.

### Escala de XP — 2026-10-11

Custos e recompensa do Walker aumentaram ambos ×10: continuam a ser
necessários **15 Walkers recolhidos para passar de nível 1 a 2**, sem bónus.
A mudança permite recompensas mais expressivas e frações menores em relação
ao valor de um abate. Runner rende agora 12 XP; especiais e chefe valem mais
em relação ao Walker (tabela seguinte). Não é uma aceleração uniforme de ×10.

| Passagem de nível | XP necessária |
|---|---:|
| 1 → 2 | 150 |
| 5 → 6 | 630 |
| 10 → 11 | 1680 |
| 15 → 16 | 3230 |
| 20 → 21 | 5280 |
| 25 → 26 | 7830 |
| 30 → 31 | 10 880 |

Fast Learner continua a dar +5% por rank. No rank IV, um Walker rende
**12 XP**; com Double XP ativo, **24 XP**. Um Runner rende 14,4 XP nesse
rank, ou 28,8 XP com ambos os efeitos. Field Dressing continua a curar por
orbe, sem multiplicar a cura pela nova escala. As caixas de XP já usam metade
do custo do nível atual, pelo que acompanham a escala automaticamente.

O objetivo de **25–30 níveis numa run de 20–30 minutos** precisa de playtests
com jogadores. Multiplicar custos e XP do Walker pelo mesmo valor não torna
o nível 30 mais próximo; a contribuição dos especiais aumentou, mas a curva
quadrática tardia ainda precisa de ser medida. Não foi aplicada outra curva.

## 4. Inimigos

### Stats base, antes da dificuldade

| Inimigo / ID | HP | Velocidade sorteada | Dano de contacto definido | Intervalo | DPS de contacto bruto | XP por abate | Redução frontal | Empurrável |
|---|---:|---|---:|---:|---:|---:|---:|---|
| Walker / `walker` | 30 | 1,8–2,6 m/s | 8 | 1 s | 8 | 10 | 0% | Sim |
| Runner / `runner` | 18 | 4,6–5,4 m/s | 6 | 0,7 s | 8,57 | 12 | 0% | Sim |
| Brute / `brute` | 260 | 1,6–1,9 m/s | 25 | 1,6 s | 15,63 | 100 | 75% | Não |
| Grabber / `grabber` | 70 | 2,8–3,2 m/s | 4 | 0,5 s | 8 | 45 | 0% | Sim |
| Behemoth / `behemoth` | 1800 | 1,7 m/s; 2,7 na fase 2 | 35 | 1,4 s | 25 bruto | 1000 | 50% | Não |
| Bloater / `bloater` | 90 | 1,3–1,5 m/s | 10 | 1,2 s | 8,33 | 45 | 0% | Sim |
| Screamer / `screamer` | 45 | 3–3,4 m/s | 3 | 1 s | 3 | 60 | 0% | Sim |

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
XP/Intel, Nuke, Full Power, Max Shield, Extra Reroll e Max Ammo.

## 6. Pontos para decidir na revisão

Esta lista distingue diferenças confirmadas no código de hipóteses de
equilíbrio. A escala de XP foi atualizada; os restantes pontos mantêm-se
por decidir.

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
| Acesso ao nível 30 | Curva atual exige 113 970 XP recebidos desde nível 1; Walker/Runner rendem 10/12 XP base; especiais e chefe passaram a valer mais | Medir níveis por minuto e contribuição dos especiais numa run normal antes de ajustar a curva tardia |
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
Os testes `test_data.gd` e `test_island_run.gd` verificam os custos, as sete
recompensas, os abates/recolhas reais e a combinação com Fast Learner e
Double XP. Os valores anteriores continuam no histórico Git.

Verificação da atualização de 2026-10-11: **27/27 scripts de teste passaram**
(26 existentes e o novo `test_island_end_panel.gd` criado externamente durante
a tarefa), sem `TEST FAIL`, `SCRIPT ERROR` ou `Parse Error`. O bot extraiu nas
seis ilhas de duas runs, cobrindo os cinco biomas e os chefes. Terminou ambas
no nível 15 em cerca de oito minutos simulados; usa vida elevada e não
valida o objetivo de níveis para partidas humanas de 20–30 minutos.

O HUD foi visto no Godot Forward+ a 1280×720 com `XP 8999.2/10880` e
`XP +20%`, sem sobreposição. Trocar temporariamente a escala ×10 por ×9
provocou oito falhas; permitir a recolha de um drop com tempo zero provocou
uma falha. Ambas as alterações foram restauradas e os testes focados
voltaram a passar. A revisão JEV recebeu apenas um resumo sanitizado e
foi inconclusiva; a validação baseia-se na inspeção local e nos testes.
