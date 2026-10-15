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
medidas em [LOCOMOTION.md](LOCOMOTION.md). Os materiais são PBR sem mapas e as
lentes são opacas, conforme as notas dos assets.

A revisão externa foi inicialmente bloqueada. Após autorização explícita do
utilizador, o JEV recebeu apenas os trechos do carregador e do ajuste do
braço esquerdo. Não recebeu testes, outros ficheiros ou código de locomoção.
Devolveu `escalate`, com baixa confiança e sem diagnóstico concreto por linha;
não constitui aprovação nem prova de defeito. O resultado consultivo está em
`checks/jev_loader_arm_review.json`. A inspeção e os testes locais continuam
a ser a evidência de funcionamento; não houve alteração de código nesta revisão.
