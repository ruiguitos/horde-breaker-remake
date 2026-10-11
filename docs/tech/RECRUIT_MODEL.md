# Recruit v03 — integração no jogo

Integração de 2026-10-11, a pedido do utilizador. O Recruit usa agora o
modelo com rig da pasta `Horde_Braker_Recruit_v03_entrega`, em vez da v02
com pivots artificiais. O Vanguard mantém o seu modelo atual.

## Assets e origem

Foram copiadas para a pasta `assets/models/characters/recruit/` as peças
necessárias ao runtime, sem executar os scripts de geração entregues:

| Ficheiro | Origem no pacote |
|---|---|
| `recruit_v03.glb` | `Horde_Braker_Recruit_v03_rigged.glb` |
| `recruit_animations.tres` | `Recruit_UAL_compatible.tres` |
| `recruit_rifle_hold.json` | `Recruit_Rifle_Hold_pose.json` |

O GLB tem 53 ossos e 104 peças rígidas; a biblioteca adaptada tem 46 clips.
A altura em rest é aproximadamente 2,025 m, com pés em Y=0 e frente -Z.
Não foi aplicada escala adicional; a rotação de 180° do contentor Rig
foi preservada. A biblioteca de animações deriva da UAL de Quaternius
(CC0); os créditos existentes já atribuem essa biblioteca. Ver
`assets/LICENSES.md`.

A pasta de entrega e a v02 foram preservadas. A entrega recebeu um
`.gdignore` para que Godot não importe o `.blend`, previews e projeto de
validação como assets do jogo. Não é uma dependência do runtime.

## Funcionamento

`SoldierModel` conserva a hierarquia, skins e attachments do GLB.
`RecruitAnimationPlayer`, sob Skeleton3D, lê os canais `.:nome_do_osso`
da biblioteca externa. O código antigo que reparentava peças para pivots
foi retirado do caminho do Recruit: destruiria o rig desta versão.

- Parado → `Idle_Loop`; movimento → `Walk_Loop`; sprint/Breaker em
  movimento → `Sprint_Loop`, com transições de 0,15 s.
- A animação recebe o delta do jogo e congela em pausa, level-up,
  hitstop e fim de run. Não acumula tempo de menus para saltar ao retomar.
- `recruit_rifle_hold.gd` aplica a pose de duas mãos entregue sobre os
  oito ossos dos braços. Os offsets são preparados uma vez.
- A AR usa as peças `Rifle_*` e o Muzzle originais. As restantes armas
  usam os modelos provisórios existentes, ligados à mão direita; ocultam
  a AR para evitar duas armas visíveis. Clarões e tracers seguem o Muzzle.
- Em primeira pessoa o corpo projeta sombras sem ser desenhado;
  mantém-se o ViewModel de mãos/arma usado pelo jogo. As câmaras de
  terceira pessoa e fixa mostram o novo Recruit.
- O Breaker conserva movimento e efeitos, mas não alonga o corpo deste
  rig. A malha e as proporções do Recruit mantêm-se.

O avanço manual usa a API de
[AnimationMixer](https://docs.godotengine.org/en/4.4/classes/class_animationmixer.html),
verificada no Godot 4.7.2 instalado.

## Limites e continuação para o Claude

O jogo usa os três clips de locomoção; os restantes 43 ficam disponíveis
para integração futura. Não foram criados clips de strafe, marcha atrás,
recarga de espingarda ou habilidade: estes movimentos usam a locomoção
disponível. A pose de duas mãos foi feita para a AR; os offsets de pega
dos outros modelos podem ser afinados quando chegarem as armas finais.
A mira vertical do corpo/arma continua sem IK independente do tronco.

Preservar os canais rebased da biblioteca, a rotação Rig e o attachment
da mão ao continuar o trabalho. Novos modelos de armas devem conservar
um Muzzle válido e ocultar as peças da AR quando não estiver equipada.
Não voltar a mover peças skinned para os pivots da v02. Consultar
`tests/test_recruit_animation.gd` e correr a suite completa após alterações.

## Validação

O teste novo verifica rig e clips, seleção Idle/Walk/Sprint, pausa,
movimento dos ossos, troca das cinco armas, sombras em primeira pessoa,
Muzzle na mão animada e apoio da mão esquerda. `test_world_dressing`
verifica a altura de rest e a compatibilidade do modelo. Capturas reais
em Forward+ verificaram locomoção e as três câmaras.

Suite completa: **34/34 scripts passaram** (`tests/` e `spikes/`),
incluindo duas runs simuladas até ao boss, sem `TEST FAIL`, `SCRIPT ERROR`
ou erros de parsing. Uma mutação temporária que trocava Sprint por Walk
foi detetada pelo teste; o ficheiro foi restaurado byte a byte e o teste
voltou a passar. Os três assets copiados mantêm o conteúdo da entrega.

O Godot instalado mantém a falha nativa de saída já conhecida no Windows
(-1073741819), após os testes. O import também registou os erros de editor
pré-existentes do Dialogue Manager; não apareceram nas verificações de
runtime. Os três DLLs removidos pelo import foram restaurados.

A revisão consultiva JEV recebeu apenas um resumo técnico sem código
privado e foi inconclusiva, com confiança baixa; não substitui a revisão
local, os testes ou as capturas. Trabalho preparado para revisão, sem
commit ou push nesta intervenção.
