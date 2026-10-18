# Braços de primeira pessoa — apoio ao Claude, 2026-10-18

Este registo descreve a correção inicial de escala. A entrega seguinte
acrescenta [cinco empunhaduras próprias](../weapon_grips/README.md) e resolve
os défices de alcance da marksman e da shotgun referidos abaixo.

## Causa confirmada e correção aplicada

A arma era desenhada a 0,5, enquanto os braços compensavam com escala local
2,0. O marcador da palma podia coincidir com o apoio, mas a largura da mão,
o arco dos dedos e a empunhadura tinham proporções incompatíveis. Uma
captura isolada do Godot reproduziu o efeito de «garra» observado pelo
utilizador. Não foi necessário alterar o GLB nem o rig.

Em `game/world/view_model.gd`:

- `GUN_SCALE` passou a 1,0; os braços mantêm escala local 1,0.
- O alvo da mão esquerda é `model.support_point`, sem multiplicação.
- `REST` passou de (0,16; -0,16; -0,40) para (0,16; -0,23; -0,42):
  7 cm abaixo e 2 cm mais à frente, conservando o desvio lateral.

As dez peças de dedos foram medidas depois de entrar na árvore e atualizar
o esqueleto: os `BoneAttachment3D` acompanham a posição dos respetivos ossos,
sem erro de translação detetado. As imagens com escala coerente também
mostram os dedos junto à arma; não sustentam a hipótese inicial de um
desfasamento dos dedos provocado por attachments sem atualização.

## Evidência visual

Capturas reais do renderer Compatibility do Godot 4.7.2, Vanguard, câmara
com FOV vertical 70°, 1280×720, fundo neutro, sem UI, recuo ou movimento.
O FOV foi fixado para a comparação; o perfil do jogo permite 60–120°.
Foram capturadas
num SubViewport isolado, para que o menu de arranque não ocultasse o modelo.

| Captura | O que verifica |
|---|---|
| [Antes](codex_scale_before.png) | Arma 0,5; braços compensados para 1,0; dedos demasiado grandes |
| [Depois: rifle](codex_scale_after.png) | Configuração efetiva do código corrigido; empunhadura e enquadramento |
| [ADS rifle](codex_scale_ads.png) | Miras alinhadas; FOV 52,5° (70 × 0,75, como o controlador) |
| [SMG](codex_scale_smg.png) | Outra arma com o novo espaço comum de escala |
| [Parede](codex_scale_wall.png) | Puxada máxima de 0,30 m: arma baixa, maioritariamente fora do enquadramento |

Estas capturas não são um novo playtest em combate. A mão de apoio tem
forma fixa de rifle: faltam avaliar a rotação e a adaptação da empunhadura
para cada classe de arma. A marksman conserva um défice de alcance de
1,50 mm; a shotgun de 1,07 cm. São limitações anteriores, medidas pelo teste,
e não foram escondidas nem corrigidas através de esticar os ossos.

## Testes e continuação

`test_first_person_arms.gd` foi reforçado para detetar a escala incompatível:
falhou antes da correção e passou depois. `test_view_model.gd` também passou,
incluindo alinhamento das miras de rifle/SMG e movimentos de recarga.
Depois da sugestão do Claude, o teste dos braços passou ainda a verificar,
dentro da SceneTree, que o esqueleto e a arma têm o mesmo referencial e
que o erro do contacto em coordenadas do mundo coincide com o erro do IK.
Passou para as cinco armas. Os défices de alcance acima foram medidos de
novo com a configuração efetiva a escala 1,0, sem compensação dos braços.

A suite completa foi tentada: 40 scripts terminaram (34 passaram, seis
falharam), antes de ser interrompida no teste de Settings. A
gravação em `user://` falha no ambiente restrito, e esse teste usa o ficheiro
nulo sem chegar ao `quit()`. Outras verificações de persistência falharam
pelo mesmo bloqueio de escrita. `test_run_all.gd` também é classificado
como falha porque uma mensagem de sucesso inclui o texto literal
«TEST FAIL», que o runner considera um marcador de erro. Não se alteraram
Settings, perfis ou o runner nesta revisão. A suite global não está
aprovada; os testes específicos dos braços e miras passaram. Nenhum commit
ou push foi feito pelo Codex nesta revisão.

Próxima avaliação visual: abrir uma ilha com Vanguard/rifle, testar a mira
e correr, verificando o bordo inferior dos antebraços e se a arma tapa os
alvos. Comparar depois Recruit e as restantes armas. Conservar os ossos
de 0,30 m e a escala coerente; usar enquadramento e IK para afinação.

## Estado da colaboração

Foi usada a skill local `codex-claude-collaboration`. Após uma falha de
DNS e um bloqueio inicial de permissões, o utilizador autorizou explicitamente
enviar só os trechos relevantes de `view_model.gd` e `first_person_arms.gd`
e o resumo do diagnóstico/testes. A consulta limitada ao Claude concluiu
com sucesso. Não foram partilhadas imagens ou os restantes ficheiros.

O Claude concordou com a causa de escala a partir dos trechos e do resumo;
não inspecionou as imagens. Sugeriu os testes do referencial e contacto no
mundo e a captura de puxada máxima, entretanto executados. Apontou ainda
para futura afinação a pose fixa da mão nas restantes armas e o caso
singular de IK quando a direção do alvo fica paralela à dica do cotovelo.
Estas hipóteses não equivalem a falhas observadas nos apoios atuais.
Não se mudou o sistema de IK nem se fez migração da API nesta revisão.
