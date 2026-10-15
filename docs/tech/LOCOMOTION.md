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
  ciclos/s, por isso os pés deslizam durante o dash. A UAL tem `Roll`, que
  pode servir.
- **Lata**: a lata é desenhada pelo `island.gd` num ponto fixo
  (`CARRY_OFFSET`) e a perna direita passa por ela ao correr; a arma vai
  baixa na mão esquerda (33–43° para baixo), porque não se dispara.
  `SoldierModel.CARRY_HAND` tem de acompanhar `CARRY_OFFSET`.
- **Para o playtest (editor, Windows)**: câmara fixa a andar com WASD e a
  apontar o rato para o lado oposto; terceira pessoa com S e A/D; sprint de
  lado a disparar; rodar o rato depressa parado; o Armory a rodar;
  uma Fuel Run. Os números medem o deslize e a mira; a avaliação visual
  continua a ser necessária, sobretudo nas mudanças bruscas de direção.

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
