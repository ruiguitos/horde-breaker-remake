# Locomoção do Recruit e do Vanguard

O utilizador achou que o andar "parece um pouco estranho". Este documento
regista o que se mediu, o que mudou em `game/world/soldier_model.gd` e o
que fica por fazer. Os dois rigs (Recruit v03, Vanguard v01) usam a mesma
biblioteca UAL e dão os mesmos números.

## Como medir

`tools/dev/locomotion_preview.gd` move o `SoldierModel` tal como o
`island.gd` faz (primeiro `animate()` com a velocidade suavizada, depois a
posição e a orientação da simulação) em 12 cenários com as velocidades do
jogo: parado, andar para a frente / trás / lados / diagonais (6 m/s),
sprint para a frente e de lado (9,6 m/s, "run and gun"), lata de
combustível (4,8 m/s), rodar no sítio e arrancar/parar.

```bash
# números (funciona em --headless)
godot --headless --path . --script res://tools/dev/locomotion_preview.gd -- measure [recruit|vanguard]
# velocidade, passada e fase de cada clip UAL
godot --headless --path . --script res://tools/dev/locomotion_preview.gd -- calibrate
# folhas de contacto (precisa de janela/GPU)
godot --path . --script res://tools/dev/locomotion_preview.gd -- sheet docs/design/art/locomotion_after recruit 0.6
```

- **Deslize** = velocidade horizontal no mundo dos pontos do pé (calcanhar e
  dedos) quando estão a menos de 4 cm do chão. Um pé bem assente fica
  parado (0 m/s). Nas imagens, as marcas no chão são verdes quando o pé está
  parado e amarelas/vermelhas quando desliza.
- **Cano** = direção do cano da arma visível vs a direção para onde o soldado
  aponta (linha vermelha = cano, verde = mira).
- Imagens: `docs/design/art/locomotion_before_side.png`,
  `locomotion_after_side.png` (vista 3/4) e `locomotion_*_fixed.png`
  (câmara fixa do jogo: 35°, 10 m, mesmo tamanho em píxeis que num ecrã
  1080p). Seis fotogramas por linha, um cenário por linha.

## Apoio dos pés — atualização de 2026-10-15

O novo `game/world/foot_contact.gd` corre depois da mira e ajusta apenas
as pernas. Fixa temporariamente um ponto de apoio no mundo durante o
contacto, liberta-o durante a elevação do pé e adapta a trajetória à
altura do terreno. Resolve coxa/canela por rotação, sem esticar os ossos,
preservando a orientação animada do tornozelo e dos dedos.

Medições com o mesmo percurso de 12 cenários, antes/depois desta etapa:

| Cenário | Deslize anterior | Com apoio dos pés |
|---|---|---|
| Frente a 6 m/s | 0,53 m/s | 0,04 m/s |
| Trás a 6 m/s | 0,57 m/s | 0,09 m/s |
| Lados a 6 m/s | 0,55–0,57 m/s | 0,04 m/s |
| Sprint frente | 0,89 m/s | 0,21 m/s |
| Sprint de lado | 0,84 m/s | 0,23 m/s |
| Carregar lata | 0,56 m/s | 0,19 m/s |
| Arrancar/parar | 0,87 m/s | 0,78 m/s |
| Rodar no sítio | 0,85 m/s | 0,84 m/s |

Os pontos de sola medidos deixam de penetrar até 5,9 cm no plano e
mantêm pelo menos 2 mm de folga nos percursos medidos. São dois pontos
aproximados por pé (calcanhar/dedos), não uma prova de ausência de
interseções de todos os vértices das botas.

`island.gd` fornece a altura do terreno desenhado; a mesma rotina serve
os dois rigs. Uma rampa sintética com declive de 12% longitudinal e 8%
transversal também passou. As correções verticais estão limitadas a
22 cm, o apoio horizontal a 18 cm e o alcance ao comprimento real das
pernas: degraus altos, falésias e terreno mais íngreme continuam fora desta
validação. O pé conserva a orientação do clip; não há alinhamento completo
da sola com a normal do terreno. Noclip desliga o apoio; teleportes
descartam os contactos e a pausa não avança o estado.

Pré-visualização real em Forward+, com Walk a 1 m/s, Jog a 6 m/s e Sprint
a 9,6 m/s: [animação](../design/art/locomotion_contact.gif). O Walk lento
é demonstrativo: a velocidade normal do jogo continua a ser 6 m/s.
`tools/dev/movement_preview.gd` gera os 84 fotogramas a 30 fps, sem alterar
a velocidade de jogo. As folhas `locomotion_contact_recruit_side.png` e
`locomotion_contact_recruit_fixed.png` mostram os 12 cenários.

O teste `tests/test_foot_contact.gd` cobre os dois modelos a 1, 6 e
9,6 m/s, recuar, strafe, rampa, comprimentos das pernas, pausa e teleporte.
A implementação usa a ordem documentada dos
[SkeletonModifier3D do Godot 4.7](https://docs.godotengine.org/en/4.7/classes/class_skeletonmodifier3d.html).

## Diagnóstico da calibração original

Os clips UAL estão no sítio (sem root motion: só o osso `DEF-hips` tem
posição, para o balanço vertical). A calibração deu a velocidade a que os
pés de cada clip ficam parados com a reprodução a 1×:

| Clip | Duração | Velocidade | Passada (ciclo) | Deslize residual do clip |
|---|---|---|---|---|
| `Walk_Loop` | 1,33 s | 1,00 m/s | 1,33 m | 0,33 m/s |
| `Jog_Fwd_Loop` | 0,93 s | 6,00 m/s | 5,60 m | 0,55 m/s |
| `Sprint_Loop` | 0,67 s | 8,75 m/s | 5,83 m | 0,94 m/s |

O jogo anda a **6 m/s** (`GameData.PLAYER_SPEED`) e faz sprint a 9,6 m/s.
O código antigo tocava `Walk_Loop` (feito para 1 m/s) a 1× para andar:

| Cenário | Clip antes | Deslize antes | Clip depois | Deslize depois |
|---|---|---|---|---|
| Frente 6 m/s | Walk ×1,00 | **5,10 m/s** (85 % do corpo) | Jog 1,07 ciclos/s | 0,53 m/s |
| Trás 6 m/s | Walk ×1,00 (para a frente) | **6,90 m/s** (115 %) | Jog ao contrário | 0,57 m/s |
| Lado esq./dir. | Walk ×1,00 (para a frente) | 6,08 m/s | Jog, ancas a ±90° | 0,55–0,57 m/s |
| Diagonal frente | Walk | 5,41 m/s | Jog, ancas a 45° | 0,54 m/s |
| Diagonal trás | Walk | 6,67 m/s | Jog ao contrário, ancas a 45° | 0,57 m/s |
| Sprint frente 9,6 m/s | Sprint ×1,00 | 1,30 m/s | Sprint 1,65 ciclos/s | 0,89 m/s |
| Sprint de lado | Sprint (para a frente) | **12,83 m/s** | Sprint, ancas a 90° | 0,84 m/s |
| Lata 4,8 m/s | Walk ×0,80 | 4,16 m/s | Walk/Jog 0,76, 1,05 ciclos/s | 0,56 m/s |
| Rodar no sítio (180° em 0,3 s) | corpo inteiro roda | 0,84 m/s | pernas ficam, depois rodam | 0,85 m/s |
| Arrancar/parar | Walk; continua ×0,60 0,25 s depois de parar | 2,15 m/s | Jog; pára com o corpo | 0,87 m/s |

Em resumo, o "estranho" era:

1. **Patinar**: as pernas davam passos de 1 m/s com o corpo a 6 m/s; os pés
   escorregavam 5 m/s.
2. **Moonwalk**: para trás e para os lados tocava sempre o ciclo para a
   frente (em terceira pessoa, S/A/D usam-se muito: o corpo olha para onde
   a câmara olha).
3. **Arma fora da mira**: o cano apontava 14–20° para baixo parado e a andar,
   e no sprint 43–54° para baixo e 33–48° para o lado. O tiro automático sai
   a direito na direção do corpo, por isso a arma não apontava para onde
   saíam os tiros (pior agora que o sprint também dispara).
4. **Paragem atrasada**: a velocidade suavizada do `island.gd` (lerp 0,2 por
   frame) mantinha o Walk ×0,60 cerca de 0,25 s depois de o corpo parar.

Também medido, sem problema: o modelo olha para −Z (o Skeleton3D está rodado
180° dentro do GLB; as pernas alinham com o movimento a 0°); a pose Idle
tem os pés 13° rodados (postura de tiro), que se mantém.

## O que mudou

**Atualização de 2026-10-15:** a integração dos cinco GLB originais acrescenta
um ajuste do braço esquerdo ao guarda-mão de cada arma, depois da pose
entregue e antes da mira. O cano usado é o da arma equipada. A locomoção
descrita abaixo foi depois complementada pelo apoio dos pés acima;
ver [WEAPON_MODELS.md](WEAPON_MODELS.md).

A calibração original ficou em `soldier_model.gd`. A atualização dos pés
acrescenta um modificador e ligações em `island.gd`.

- **Velocidade medida pelo próprio modelo.** `animate()` compara a posição
  global com a da chamada anterior (filtro de 18/s; saltos de mais de 3 m
  são teleportes). Já não depende do `_walk_speed` do `island.gd`, que
  normalizava por 6 m/s e atrasava a paragem. O parâmetro `speed` só serve
  o modelo de caixas.
- **AnimationTree com as três marchas em fase.** Walk(0) / Jog(1) /
  Sprint(2) num `BlendSpace1D` com `sync`, cada clip esticado para a mesma
  linha de tempo de 1 s e deslocado para o pé esquerdo ir à frente na fase 0
  (o `start_offset` conta na linha de tempo esticada). Misturar marchas
  nunca mistura dois passos diferentes.
- **Ritmo = velocidade / passada.** Um `TimeScale` põe os ciclos por segundo
  em `velocidade / passada da mistura`, por isso os pés acompanham o chão a
  qualquer velocidade (armas que mudam a velocidade, perks, lata).
- **Direção.** Mais de 110° entre o movimento e a mira (sai abaixo de 95°)
  = recuar: o mesmo ciclo tocado ao contrário (não há clip de recuar; o
  sprint para trás usa o Jog). Até lá, as ancas rodam para o movimento (até
  100°) e a coluna roda de volta. A rotação das pernas mistura-se no espaço
  do corpo, nunca por trás, para uma inversão de direção não ficar presa.
- **Tronco que aponta.** Um `SkeletonModifier3D` (`LocomotionRig`, depois
  da pose de duas mãos entregue) roda os dois braços em torno da linha dos
  ombros até o cano ficar nivelado (as mãos nunca saem da arma: 0,0000 m) e
  depois roda a coluna (metade em `spine.002`, o resto em `spine.003`) até o
  cano apontar para a mira. A cabeça segue a mira a 85 % (o Jog e o Sprint
  baixam-na). Resultado: erro do cano 0,0° de lado e ≤ 0,4° na vertical em
  todos os cenários, com as cinco armas.
- **Rodar no sítio.** Parado, as pernas ficam onde estão enquanto o tronco
  roda; até 90°/s seguem suavemente (o Armory roda a 29°/s e não torce);
  passados 50° rodam a 420°/s para apanhar o tronco. Um ciclo de Walk no
  sítio para "dar passos" fazia deslizar mais (0,91–1,08 m/s vs 0,85).
- **Arrancar/parar.** Do repouso a marcha começa logo na da velocidade (o
  jogo não tem aceleração); a mistura Idle↔movimento dura ~0,15 s.
- **Lata.** Com `carrying = true` a arma passa
  para a mão esquerda exatamente onde estava, o braço direito estica até à
  pega da lata (a 4 cm no teste) e o tronco deixa de apontar.
- Custo medido neste PC (Windows 11): `LocomotionRig` 0,017 ms por
  atualização, avanço da árvore 0,059 ms.

## Ligações em `island.gd`

Ligadas nesta atualização, antes de `soldier.animate(...)`:

```gdscript
	soldier.carrying = run.is_carrying()  # lata na mão direita, arma na esquerda
	soldier.aim_pitch = -_tp_pitch if camera_mode != Profile.CameraMode.FIXED else 0.0
```

A primeira liga a pose de carregar a lata. A segunda inclina a arma com a
câmara de primeira/terceira pessoa; na câmara fixa mantém-se nivelada.
Na criação do modelo, `ground_height` recebe a função do terreno; `grounded`
desliga o apoio dos pés durante noclip/voo.

## O que fica

- **Faltam clips na UAL**: não há strafe, recuar, rodar no sítio,
  arrancar/parar, carregar objeto nem sprint a disparar. Strafe e recuar
  são sintetizados (ancas rodadas, ciclo ao contrário); recuar a 6 m/s com
  o Jog ao contrário deve ser visto em jogo.
- **Andar = correr**: a 6 m/s o soldado corre (Jog). Andar devagar só
  aparece abaixo de ~2 m/s, que o jogo não usa.
- **Pés no chão**: corrigidos nesta atualização nos percursos medidos;
  persistem as limitações de terreno e das solas descritas acima.
- **Breaker**: 5 m em 0,18 s (~28 m/s); o ritmo está limitado a 2,2
  ciclos/s, por isso os pés deslizam durante o dash. Desde 2026-10-20 o dash
  rola o corpo com o clip `Roll` (ver Reações); a passada continua limitada.
- **Lata**: a lata é desenhada pelo `island.gd` num ponto fixo
  (`CARRY_OFFSET`) e a perna direita passa por ela ao correr; a arma vai
  baixa na mão esquerda (33–43° para baixo), porque não se dispara.
  `SoldierModel.CARRY_HAND` tem de acompanhar `CARRY_OFFSET`.
- **Para o playtest (editor, Windows)**: câmara fixa a andar com WASD e a
  apontar o rato para o lado oposto; terceira pessoa com S e A/D; sprint de
  lado a disparar; rodar o rato depressa parado; o Armory a rodar;
  uma Fuel Run. Os números medem o deslize e a mira; a avaliação visual
  continua a ser necessária, sobretudo nas mudanças bruscas de direção.

## Reações: ferimento, dash e morte (2026-10-20)

Três clips pontuais da UAL, nos dois rigs, sobrepostos à locomoção em
`soldier_model.gd` (nós `hit`, `dash` e `death` da árvore):

- **Ferimento:** `Hit_Chest` quando `run.hp` desce (`island.gd`, ao lado do
  tremor da câmara). No máximo um flinch a cada 0,35 s: uma multidão não
  sacode o corpo a cada fotograma. O modificador de duas mãos continua a
  correr, por isso as mãos ficam na arma.
- **Dash do Breaker:** `Roll` durante o dash e desvanece no fim (0,1 s). O
  dash dura 0,18 s, por isso só se vê o início do rolamento; é uma escolha a
  validar no editor.
- **Morte** (`run.objective == LOST`, ou seja, a vida chegou a zero): `Death01`
  entra em 0,25 s e segura a última pose. Os modificadores de posição (mãos,
  apoio, pernas) são desligados quando o clip toma o corpo; senão puxavam os
  braços de volta.

`tests/test_soldier_reactions.gd` cobre as duas classes: cooldown do flinch,
flinch que acaba sozinho, roll do dash, morte sem novos flinches e pose que
não deriva em 3 s (0,0000 m).

## Camada de tronco: mira e recuo (2026-10-24)

Primeira parte da Fase 1 da animação (`TODO.md`). Duas coisas, ambas só no tronco:

- **Mira:** `Pistol_Aim_Down`, `Neutral` e `Up` são poses estáticas de 0,17 s. Um
  `BlendSpace1D` escolhe a pose pelo pitch da mira (+10° para cima e −45° para
  baixo, os limites da câmara em terceira pessoa). Um `Blend2` filtrado
  (`aim_trunk`) põe 60 % dessa pose em `DEF-spine.002`, `.003`, pescoço e cabeça.
  Fica por cima da locomoção, por isso o andar conserva parte do balanço do tronco.
- **Recuo:** cada disparo do jogador chama `recoil()`, que inclina o tronco 3°
  para trás; a meia-vida do recuo é de 0,06 s. Aplica-se no `LocomotionRig`,
  depois da mira e antes do olhar da cabeça. Fica suprimido durante o dash, na
  morte e com a carga de combustível, onde a mão já está posicionada.

Não mexem nas pernas (`foot_contact.gd`) nem nos braços. A pega de duas mãos
(`recruit_rifle_hold.gd`) escreve ombros, braços, antebraços e mãos em pose
absoluta, e o `Pistol_Shoot` não move a coluna, por isso o recuo é código e não
clipe. O preview do armeiro e o da escolha de classe usam mira em repouso, por
isso o tronco deles também fica 60 % na pose neutra.

Os braços mantêm as poses locais, mas acompanham o tronco na cena: quando o
tronco se inclina, a arma sobe com ele, e o `LocomotionRig` volta a apontar o
cano à mira.

Testes: `_test_aim_layer` em `tests/test_recruit_animation.gd` e `_test_recoil`
em `tests/test_soldier_reactions.gd`. Leem a pose no sinal `skeleton_updated`,
porque uma leitura logo após `animate()` ainda é anterior aos modificadores.

Ficou por fazer, à espera de decisão:

- **Braços com a mira:** precisam de uma pega de rifle, que a UAL não tem. Os
  clipes de pistola partiriam a pega de duas mãos.
- **Recarga do corpo (`Pistol_Reload`):** a pega tem de ceder durante a recarga,
  e o apoio da mão esquerda também. Falta decidir se a mão esquerda vai ao carregador.
- **Interagir (`Interact`) e apanhar (`PickUp_Table`):** `interact()` só trata dos
  bidões da Fuel Run. Não há noção de "segurar E" nem de sinais apanhados.
- **Aterragem (`Jump_Land`):** o jogo não tem queda normal (`_fly` só sobe em
  noclip), e o Breaker não tem ar. Falta definir o que é "degrau alto".
- **`Hit_Head`:** `react_hit()` não recebe a zona do dano, por isso não há origem
  de dano na cabeça para disparar o clipe.

## Aviso do golpe da horda (2026-10-24)

Não é um clipe nem o rig do jogador. O aviso de 0,3 s dos Shamblers e Runners é
código da horda (`ATTACK_WINDUP` em `game/horde/horde.gd`), e a pose é a de
`game/world/zombie_horde_view.gd`: inclinação e braços no aviso, braços a descer
em 0,15 s depois do golpe. Durante o aviso:

- **Esquiva:** o golpe só acerta se o jogador estiver no alcance (1,5 m) quando o
  aviso acaba. Se já saiu, falha, sem dano nem agarrão, e o intervalo de ataque
  segue como se tivesse acertado.
- **Avanço:** o inimigo continua a andar a `WINDUP_SPEED_SHARE` (25 %) da
  velocidade. Medido em regime estacionário: 23,7 %. A investida lê-se pela
  inclinação e pelos braços.
- **Cancelamentos:** atordoar, congelar, perder as pernas e morrer a meio cancelam
  o golpe.

Verificação: `tests/test_horde_windup.gd`, 24 verificações a passar. Cobrem o tempo
do aviso e o intervalo, os cancelamentos, a esquiva, o acerto com o jogador ainda
em alcance, o cooldown que não muda quando se falha, o movimento já no primeiro tick
e a velocidade de 25 %.

Bot da Fuel Run, seis seeds, o mesmo bot e o mesmo limite de 900 s. "Parado" é o
aviso antes desta correção (o inimigo fica imóvel e o golpe acerta mesmo fora de
alcance). "Sem aviso" é o estado de 2026-10-24 antes do aviso. Largadas são as vezes
em que o bot pousa o bidão por haver mais de 12 inimigos a 6 m; é o indicador de
anel de corpos.

| Seed (mapa) | Sem aviso | Aviso parado | Aviso com esquiva e avanço |
|---|---|---|---|
| 404 (Town) | 159 s | 155 s, 7 largadas | 154 s, 8 largadas |
| 505 (Beach) | 188 s, 11 largadas | falha a 900 s, 2/3, 134 largadas | 203 s, 14 largadas |
| 11 (Beach) | 251 s, 13 largadas | falha a 900 s, 1/3, 6 largadas | 439 s, 53 largadas |
| 12 (Beach) | 637 s, 84 largadas | 472 s, 54 largadas | 310 s, 22 largadas |
| 13 (Town) | 187 s, 11 largadas | 175 s, 8 largadas | 193 s, 11 largadas |
| 14 (Beach) | falha a 900 s, 2/3, 135 largadas | 779 s, 115 largadas | 254 s, 15 largadas |

Com a correção as seis seeds chegam à extração (154 a 439 s). A seed 505, a que o
teste fixa, passa de 2/3 bidões em 900 s para 3/3 em 203 s. As largadas caem em 505
e 14 e sobem em 11 e 13. Não medi a densidade do anel diretamente, e não separei a
esquiva do avanço, por isso a causa fica como hipótese apoiada nos números.

Limites que ficam:

- Sem campo de fluxo calculado, o inimigo fica parado durante o aviso. É uma
  limitação herdada da navegação; o arranque normal já tem o campo pronto.
- O Crawler não tem aviso, porque `crawler_body.gdshader` não levanta os braços.
- A pose não foi vista no ecrã; a verificação é de testes headless.

## Validação

`tests/test_recruit_animation.gd` cobre: fases alinhadas das três marchas,
Jog a 6 m/s com ritmo × passada = velocidade (também a 4,8 m/s), recuar
(ritmo negativo, ancas na mira), strafe (pernas a −90°), sprint de lado,
deslize abaixo de 1 m/s (1,3 no sprint), cano nivelado e na mira em todos os
casos e com as cinco armas, mão esquerda na arma, paragem, rodar no sítio,
lata (arma na mão esquerda, mão direita na pega), pausa e Armory.

Após esta atualização passaram **46/48 scripts** do jogo e dos spikes,
incluindo as 60 verificações de contacto e as duas runs completas, com
extração nas seis ilhas. Reapareceram as duas falhas já observadas na
integração das armas: `test_escort` (seed 505, carro não entregue;
limite de 180 s do executor) e `test_intel_search` (frequência de rotas
Town). Não foram alteradas regras de missão nesta etapa.
Resultados e números: [locomotion_validation.json](locomotion_validation.json).
A revisão da locomoção foi local. O utilizador autorizou posteriormente
apenas o carregador das armas e o ajuste do braço para envio ao JEV;
esse resultado consultivo está em [WEAPON_MODELS.md](WEAPON_MODELS.md).
O código dos pés e os testes não foram enviados.
