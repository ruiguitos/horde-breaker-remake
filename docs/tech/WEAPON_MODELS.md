# Integração das cinco armas originais

Pedido do utilizador de 2026-10-15: integrar os modelos produzidos em Blender
antes de avançar para movimentos mais realistas das personagens. Esta entrega
substitui as armas em caixas, mantendo os dois rigs e a locomoção existente.

## Modelos usados pelo jogo

`game/world/weapon_model.gd` carrega os GLB importados de
`assets/models/weapons/tactical_original/`. Não é uma cena de demonstração:
`SoldierModel` e `ViewModel`, usados pelo Armory e pelas ilhas, já chamavam
este carregador e passam a desenhar os novos modelos.

| Identificador do jogo | GLB | Comprimento | Triângulos | Superfícies em jogo |
|---|---|---:|---:|---:|
| rifle | assault_rifle.glb | 0,9608 m | 7 482 | 4 |
| smg | smg.glb | 0,7400 m | 6 292 | 4 |
| machine_gun | machine_gun.glb | 1,0400 m | 7 940 | 5 |
| shotgun | shotgun.glb | 1,0400 m | 4 550 | 5 |
| marksman | marksman.glb | 1,1200 m | 7 708 | 5 |

O primeiro carregamento junta as superfícies estáticas que partilham o mesmo
material. A cache conserva a malha e a transformação do `Muzzle`: trocar de
arma ou criar outra instância não volta a construir a geometria. Os GLB e
fontes Blender permanecem editáveis e não foram alterados para esta operação.
São preservados os materiais próprios, UVs, normais, tangentes e triângulos.
O auxiliar antigo de materiais Poly Haven mantém-se para o equipamento do
`EscortModel`; não substitui os materiais dos novos GLB.

## Pega, mão de apoio e disparo

O `WeaponMount` conserva o referencial calibrado da mão direita dos modelos
entregues. `GRIP_FROM_MUZZLE` refere-se ao ponto de pega visto da antiga boca
do cano do rig; não desloca a boca do cano da arma nova para essa posição.
`SoldierModel.muzzle` aponta sempre ao `Muzzle` da arma equipada. Assim, também
a espingarda deixa de usar o cano invisível do modelo antigo nos efeitos.

`weapon_support_hold.gd` corre depois da pose de braços entregue e antes do
ajuste de mira/locomoção. Um ponto de contacto por arma, em `SUPPORT_POINTS`,
define onde a palma esquerda apoia o guarda-mão ou a bomba. A solução de dois
segmentos roda braço e antebraço, mantém o comprimento dos ossos e conserva a
orientação da mão. Alvos fora do alcance são limitados ao comprimento do braço.
As posições são pontos artísticos de contacto, não colisores de dedos.

Ao transportar uma lata, este ajuste desativa-se e o caminho existente prende
a arma à mão esquerda enquanto a direita leva a lata. Ao largá-la, regressam
o apoio por arma e a montagem na mão direita. A locomoção com passadas em fase,
recuar, strafe e tronco a apontar foi preservada.

Em primeira pessoa mantém-se a escala de apresentação de 50%, o recuo e a
retração junto a paredes. O clarão fica 3 cm à frente do `Muzzle` em espaço da
arma (1,5 cm na apresentação), sem sombras da arma junto ao olho.

## Verificação

- `tests/test_weapon_models.gd`: contagens exatas dos cinco GLB, comprimentos,
  atributos das malhas, materiais PBR, cano equipado, sombras e troca nas três
  câmaras, Recruit e Vanguard.
- `tests/test_weapon_grips.gd`: apoio da palma em ambas as classes, nas cinco
  armas, durante avanço, strafe/sprint e variação da elevação da mira. Antes
  do ajuste, o erro era 2,7–13,6 cm; depois fica abaixo do limite de 2 mm.
- `tests/test_recruit_animation.gd`: locomoção, apoio atualizado, transporte e
  devolução da arma, pausa e Armory. Mantém os limites existentes de deslize
  dos pés e alinhamento do cano.
- Suite completa e capturas Forward+ em
  `assets/models/weapons/tactical_original/checks/` e `previews/in_game_*.png`.
  O executor usa dados temporários em `.godot/weapon-integration-user/`, sem
  alterar os saves do utilizador.

Execução local: **45/47 scripts passaram** (44 do jogo, incluindo o teste
novo de pegas e o teste de FOV entretanto presente, mais 3 dos spikes).
Passaram as duas runs completas de três ilhas do teste de resistência.
Os testes de armas, câmaras, pegas e animações passaram. Resultados compactos
em `checks/integration_results.json` e `checks/integration_suite.json`.

Falhas registadas fora dos testes de modelos: `test_escort.gd` mostrou o bot
da seed 505 preso na reparação após 900 s simulados; o executor interrompeu
esse script aos 180 s reais. `test_intel_search.gd` falhou a proporção de
rotas da Town (14% obtidos). Não se alteraram estas simulações de missões
para obter uma suite verde. Os testes usam `IslandRun`, sem depender dos
modelos visuais. A suite geral continua, por isso, com estas duas falhas.

## Limites e continuação

Esta integração não acrescenta clips de recarga, bombeamento da shotgun,
dedos articulados por arma nem IK dos pés. As luvas/mangas de primeira pessoa
continuam a representação simples existente. A locomoção mantém as limitações
medidas em [LOCOMOTION.md](LOCOMOTION.md). As lentes são opacas, conforme as
notas dos assets.

**Texturas (2026-10-18).** A AR (`TEXTURED` em `weapon_model.gd`) recebe os
mapas normal e de rugosidade Poly Haven nos materiais `gunmetal`, `steel` e
`polymer`, por nome no GLB, em triplanar. As cores são as do Blender: um mapa
de cor multiplicado por elas mudou a cor aprovada, por isso não é usado. As
outras armas continuam com cor lisa até serem verificadas do mesmo modo. A
comparação de perto está em [docs/design/weapon_textures/](../design/weapon_textures/).
Ganho visível sobretudo na coronha e no punho; o metal mantém-se liso.
Verificação com `tools/dev/zombie_preview.gd -- <png> rifle` (janela, GPU).

A revisão externa foi inicialmente bloqueada. Após autorização explícita do
utilizador, o JEV recebeu apenas os trechos do carregador e do ajuste do
braço esquerdo. Não recebeu testes, outros ficheiros ou código de locomoção.
Devolveu `escalate`, com baixa confiança e sem diagnóstico concreto por linha;
não constitui aprovação nem prova de defeito. O resultado consultivo está em
`checks/jev_loader_arm_review.json`. A inspeção e os testes locais continuam
a ser a evidência de funcionamento; não houve alteração de código nesta revisão.

## Primeira pessoa: peças, mira e recarga (F1, 2026-10-18)

`ViewModel` monta a arma com `WeaponModel.build_parts`: o mesmo GLB com cada
peça como nó próprio (o mundo continua a usar a versão fundida). Três
movimentos, todos por código e medidos pelos nós do GLB:

- **Mira:** a mira frontal e a traseira ficam na linha central da vista; a
  arma inclina-se em torno do punho o ângulo que as nivela
  (`ViewModel.sight_rest`). A traseira fica a 0,12 m do olho.
- **Recarga:** o carregador desce a meio e volta; o punho do ferrolho puxa
  para trás no fim. A duração é a do temporizador (SMG 1,1 s, Machine Gun
  3,2 s). A AR é instantânea: não tem animação, porque a recarga do jogo também
  não tem tempo.
- **Nomes:** o Godot troca o ponto dos nomes do GLB por `_` (`5.56` vira
  `5_56`). Tabela `ViewModel.LAYOUT`.

Não inclui: braço e mão em primeira pessoa (ainda luvas em caixa), IK, clips
de Blender, recarga da espingarda e da marksman (sem temporizador), ótica.
Capturas em `docs/design/weapon_animation/`.

## Braços e mãos em primeira pessoa (F2, 2026-10-18)

`FirstPersonArms` (`game/world/first_person_arms.gd`) começou com um só modelo,
`assets/models/characters/arms_firstperson_original/arms_firstperson.glb`; desde
com as empunhaduras abaixo, cada arma tem o seu par de mãos. A mão direita fica no punho; o braço esquerdo é resolvido com
dois ossos (lei dos cossenos, 0,30 m cada) para que a palma fique no ponto de
apoio da arma (`WeaponModel.support_point`). A mão não roda: o contacto da
palma é uma translação exata do punho.

O repouso do GLB é a pose fletida de empunhadura, não o bind reto; o IK parte
dos comprimentos fletidos e mantém o cotovelo do seu lado. Mangas e luvas
tomam as cores da classe (`SoldierModel.PALETTES`).

Correção de escala (2026-10-18): arma e braços partilham a escala real
(`GUN_SCALE` 1,0; braços sem compensação inversa). O alvo é o ponto de apoio
direto, em espaço da arma. A solução anterior usava arma a 0,5 e braços a
1,0: acertava o marcador da palma, mas os dedos ficavam duas vezes maiores
em relação ao guarda-mão e à empunhadura. O teste passa agora a verificar
também a escala, além do contacto da palma.

O repouso `ViewModel.REST` é (0,16; -0,23; -0,42): o conjunto fica mais baixo
e 2 cm mais à frente do que antes. A comparação usa uma captura isolada do
Godot, Vanguard, rifle, FOV 70°, 1280×720, sem UI nem movimento:
[antes](../design/first_person_arms/codex_scale_before.png) e
[depois](../design/first_person_arms/codex_scale_after.png). O ajuste visual
do enquadramento completo da ilha continua sujeito a playtest; as capturas
isoladas não representam uma nova validação em combate.

Os anteriores défices de alcance da marksman e da shotgun foram resolvidos
pelas variantes abaixo.

## Empunhadura própria de cada arma (2026-10-18)

`FirstPersonArms.MODELS` referencia cinco GLBs em
`assets/models/characters/weapon_grips_original/`. `ViewModel.set_weapon`
escolhe o par de mãos correspondente. Mantêm o mesmo rig de oito ossos,
materiais e escala real; a curvatura dos dedos e a posição inicial dos braços
passam a corresponder à geometria de cada arma.

- **Rifle e SMG:** dedos fechados nas pegas e apoio nos respetivos guarda-mãos.
- **Machine Gun:** apoio 4 cm mais à frente (Z=-0,35 m), afastado da caixa de
  munições; enquadramento de anca 6 cm mais baixo para ocultar o fim da manga.
- **Shotgun:** mão direita inclinada em torno do pescoço da coronha,
  mão esquerda adaptada ao pump, com espaço para o cano superior.
- **Marksman:** polegar direito pelo espaço da coronha e dedos sem entrar
  nas aberturas do guarda-mão.

Os apoios foram medidos na superfície dos GLBs e atualizados em
`WeaponModel.SUPPORT_POINTS`; o teste de terceira pessoa passou nas duas
classes e cinco armas. Os ossos de braço/antebraço conservam 0,30 m, sem
esticar. O contacto da palma após skinning no Godot tem erro inferior a
0,005 mm nas cinco variantes. Triângulos por variante: rifle 2 616, SMG
2 568, Machine Gun 2 658, shotgun 2 592 e marksman 2 704.

O teste antigo que exigia arma a meia escala foi substituído pelo contrato
de escala real já aplicado em F2: marksman a 1,21 m do olho até à ponta do
clarão, com tolerância de 2 cm. Mantém a verificação de alcance; não reduz
novamente a arma em relação às mãos.

Fontes, limites numéricos, comando de reconstrução e relatórios:
[NOTES.md](../../assets/models/characters/weapon_grips_original/NOTES.md).
Capturas de primeira pessoa, pega direita, apoio esquerdo, ADS e parede em
`docs/design/weapon_grips/`, produzidas com `tools/dev/weapon_grip_preview.gd`.
São poses estáticas no renderer real, não novas animações de dedos ou recarga.
O alinhamento/ótica ADS não configurado das armas compridas era uma limitação
desta entrega de grip; a correção posterior está descrita abaixo.

## Mira da Machine Gun, marksman e AR (2026-10-21)

A Machine Gun e a marksman usavam `ADS_FALLBACK`, pensado para armas mais
pequenas: a câmara ficava dentro da geometria e quase todo o ecrã escurecia.
Arma e braços continuam à escala real, com as mesmas empunhaduras.

- **Machine Gun:** a cópia de primeira pessoa recebe um anel traseiro sobre
  a calha. O centro desse anel e o topo do poste frontal ficam no eixo da
  câmara, com o anel a 0,12 m do olho. O GLB original não foi alterado.
- **Marksman:** os centros das lentes definem a posição de mira. Como a
  ótica original tem tampas/lentes opacas, a partir de 95% do movimento ADS
  a arma deixa de ser desenhada e surge uma máscara circular com retículo,
  sobre a própria vista do mundo. Ao baixar a mira reaparecem arma e mãos.
  Mantém o zoom ADS existente (FOV × 0,75); não simula refração nem uma
  segunda câmara dentro da lente.
- **AR:** o «+» do HUD desaparece ao apontar e durante a descida da mira;
  regressa ao terminar o movimento. A terceira pessoa mantém o seu «+».

`scope_overlay.gd` desenha a máscara atrás do HUD; pausa, menus e cartas
ocultam ambos os indicadores de mira. `test_view_model.gd` verifica o
alinhamento e a visibilidade da arma; `test_camera_aim.gd` verifica os
controlos reais da interface, incluindo a volta à terceira pessoa.

**Peso da arma (2026-10-24):** a arma fica atrás da vista quando a câmara roda.
Com a taxa de rotação da câmara (`ViewModel._turn_rate`), a arma desvia-se em
sentido contrário à volta, 0,006 m por rad/s, até 0,03 m (`LAG_PER_RATE`,
`LAG_MAX`), e volta ao repouso com constante de tempo de 0,11 s (`LAG_RESPONSE` 9/s; a 1 %
do desvio, cerca de meio segundo depois). Com a
mira em baixo o desvio desaparece, para não mexer na linha de mira. O atraso
lê só a rotação, não a posição, porque o tremor de impacto da câmara mexe na
posição e a arma reagiria a ele. Quando a arma fica escondida (terceira pessoa)
ou passa a outra câmara, o atraso volta a zero, para que a volta feita entretanto
não conte como um atraso. Fica por ver no editor se 0,006 m/(rad/s) se
lê como peso sem atrapalhar a mira de quadril. `test_view_model.gd` verifica o
atraso, o regresso, a mira em ADS e o limite.

Capturas verificadas no Godot com GPU, incluindo a ilha e o HUD:
[Machine Gun](../design/weapon_ads/machine_gun_island.png),
[marksman](../design/weapon_ads/marksman_island.png) e
[AR sem «+»](../design/weapon_ads/rifle_island.png).
Condições e validação em [weapon_ads/README.md](../design/weapon_ads/README.md).

## Painel de loadout: renders dos modelos reais (2026-10-24)

O painel LOADOUT do armeiro mostrava silhuetas vetoriais. Agora mostra um render
3/4 de cada arma, feito a partir do modelo que o jogador segura
(`WeaponModel.build_parts`). Os PNG estão em `game/ui/art/weapons/<id>.png`,
240 × 96, com a cor do painel como fundo. Gera-os
`tools/dev/weapon_icon_render.gd`, numa janela (o render precisa da GPU):

    godot --path . --script res://tools/dev/weapon_icon_render.gd

Depois corre-se o import, para os PNG ganharem os ficheiros `.import`; repete-se
sempre que os PNG mudam, porque `load()` lê a cópia importada, não o PNG novo.
Se o PNG de uma arma faltar, o painel usa a silhueta antiga. `test_weapon_pictures.gd`
verifica os cinco renders, as imagens no loadout, o texto da Shotgun e o título
«Ammo Reserves».

Árvore de perks a 1600 × 900: os nomes ficam numa linha (cortados com reticências
só se não couberem), as duas alternativas empilham-se com a letra A/B, o ícone e o
nome, e os pips correm em linha por baixo. O ícone desceu de 30 para 18 px para
caber a altura da árvore a 1152 × 648; fica por ver no editor se 18 px se lê bem.
