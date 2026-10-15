# Vanguard v01 — integração no jogo

Integração de 2026-10-11, a pedido do utilizador. O Vanguard substitui o
modelo provisório de caixas pelo rig da pasta
`assets/models/characters/vanguard/Horde_Braker_Vanguard_v01_entrega/`.
Não foi necessário Blender nem foram executados os scripts de geração
incluídos na entrega. O `.blend`, os previews e os relatórios ficam
preservados; o `.gdignore` impede a sua importação pelo Godot.

## Assets de runtime

| Ficheiro em `assets/models/characters/vanguard/` | Origem na entrega |
|---|---|
| `vanguard_v01.glb` | `Horde_Braker_Vanguard_v01_rigged.glb` |
| `vanguard_animations.tres` | `Vanguard_UAL_compatible.tres` |
| `vanguard_rifle_hold.json` | `Vanguard_Rifle_Hold_pose.json` |

As três cópias mantêm o conteúdo original. O GLB usa 53 ossos e 104 peças
rígidas, com frente -Z e pés em Y=0. A altura de rest é **2,025 m**, igual
à do Recruit; a armadura e a mochila têm maior volume. Não foi aplicada
escala adicional. A biblioteca tem 46 clips UAL adaptados; a origem CC0
de Quaternius está registada em `assets/LICENSES.md` e nos créditos.
Uma leitura independente do GLB confirmou 4 056 triângulos, 35 materiais,
uma skin e zero clips internos: as animações vêm da biblioteca externa.

## Funcionamento

`SoldierModel` escolhe o GLB e a biblioteca pela classe, conservando
hierarquia, skins e attachments. O Vanguard usa `VanguardAnimationTree`,
com avanço manual e canais relativos ao Skeleton3D, como o Recruit.

- Locomoção igual à do Recruit ([LOCOMOTION.md](LOCOMOTION.md)): Idle e
  Walk/Jog/Sprint em fase ao ritmo da velocidade, recuar e strafe; congela
  em pausa, level-up, hitstop e fim de run. O Breaker não alonga o corpo com rig.
- `recruit_rifle_hold.gd` é agora partilhado: recebe o caminho da pose
  de cada classe e prepara os oito offsets dos braços uma vez.
- A AR usa as peças `Rifle_*` e o Muzzle da entrega. Shotgun, SMG,
  Machine Gun e Marksman continuam a usar os modelos provisórios,
  presos à mão direita; ocultam a AR quando equipados.
- Em primeira pessoa, o corpo apenas projeta sombras. Mantém-se o
  ViewModel de mãos/arma existente. Fixa e terceira pessoa mostram o rig.
- O Armory usa o mesmo modelo e avança a animação Idle, além de rodar a
  personagem. Esta correção também aplica a animação Idle ao Recruit.

Não foram alterados stats, controlos, colisão, desbloqueios ou perfil.
Se o GLB não estiver disponível, conserva-se o fallback de caixas.

## Limites e continuação para o Claude

Estão ativos os três clips de locomoção; os restantes 43 ficam para
integração posterior. A pose de duas mãos é a da AR entregue. Afinar
pegas específicas quando chegarem os modelos finais das outras armas.
Não há animações específicas de War Cry, recarga ou strafe integradas.
Não há IK independente do tronco para a mira vertical.

Preservar a rotação do contentor Rig, as skins, os canais rebased da
biblioteca, o avanço manual e o attachment à mão. Não reparentar peças
skinned para os pivots do modelo antigo. Ver também
[RECRUIT_MODEL.md](RECRUIT_MODEL.md).

A etapa seguinte escolhida pelo utilizador é o Armory **Abrigo 3D** e
o menu de perks **Três ramos**, mantendo a paleta Atlântico e azulejo.
Essa escolha visual não altera as regras da árvore de perks.

## Validação

`test_recruit_animation.gd` cobre agora as duas classes: rig, 46 clips,
104 peças, Idle/Walk/Sprint, pausa, movimento dos ossos, cinco armas,
sombras em primeira pessoa, Muzzle na mão e contacto da mão esquerda
com erro inferior a 2 mm. Também verifica o rig e o avanço de Idle no
Armory. `test_world_dressing.gd` confirma a altura de 2,025 m e os pés
no chão para ambas as classes.

Uma mutação temporária que fazia o Vanguard voltar ao modelo de caixas
foi rejeitada pelo teste; o código foi reposto byte a byte e voltou a
passar. Capturas reais em Forward+ confirmaram a comparação com o Recruit,
a mochila, Walk/Sprint, o Armory e as três câmaras no jogo. As capturas
de estúdio foram feitas após desaparecer o Boot Splash, sem alterar o jogo.
Suite completa: **35/35 scripts passaram** (`tests/` e `spikes/`), sem
`TEST FAIL`, `SCRIPT ERROR` ou erros de parsing. As duas runs do bot
extraíram nas seis ilhas, incluindo os bosses. Os perfis usados nas
verificações ficaram separados do perfil real do utilizador.

O import registou os erros já existentes dos addons de editor
(Dialogue Manager, safe save); os três DLLs removidos foram restaurados.
Mantém-se o código de saída nativo do Godot já conhecido no Windows
(`-1073741819`), após os resultados limpos dos testes. As capturas GPU
não registaram erros de script; persistem avisos de RIDs no encerramento.
A revisão consultiva JEV recebeu um resumo técnico sem código privado e
pediu revisão por confiança baixa, sem identificar um defeito concreto.
A conclusão assenta na inspeção local, nos testes e nas capturas.

Trabalho preparado para revisão, sem commit nem push nesta intervenção.
