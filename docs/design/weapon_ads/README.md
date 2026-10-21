# Correção da mira — 2026-10-21

As imagens `*_island.png` mostram a cena real da ilha, Recruit, 1280×720,
FOV de perfil 60° e ADS completo (45°). Captura estática, sem disparar;
as armas foram selecionadas diretamente para comparar o mesmo ponto de vista.
Não são uma validação de munição, recargas ou combate em movimento.

1. [Machine Gun](machine_gun_island.png): alvo visível pelo anel traseiro.
2. [Marksman](marksman_island.png): mundo visível no retículo circular.
3. [AR](rifle_island.png): mira de ferro sem o «+» do HUD.

`machine_gun_ads.png` e `marksman_ads.png` são capturas isoladas com uma
grelha distante, FOV base 70°, ADS completo (52,5°), no renderer Compatibility.
O comando da ferramenta aceita destino, FOV base e fração ADS opcionais:

```text
godot --path . --rendering-method gl_compatibility --script res://tools/dev/weapon_grip_preview.gd -- machine_gun ads res://docs/design/weapon_ads 70 1
```

A ótica usa a vista ampliada já existente, sem refração ou render adicional.
A arma é ocultada apenas durante a vista pela luneta; os assets e as
empunhaduras não foram alterados por esta correção.

Revisão JEV: recebeu apenas um resumo das alterações e das verificações
locais, sem código da ilha, imagens, modelos ou ficheiros do projeto.
Devolveu `escalate`, com confiança insuficiente para confirmar as alegações
a partir desse resumo; não identificou uma contradição concreta. Não é uma
aprovação externa. A evidência usada é a dos testes e capturas locais.

## Validação final

60/60 scripts de regressão do jogo aprovados. A ferramenta local interrompeu
inicialmente `test_escort.gd` e `test_soak_run.gd` aos 120 s; ambos passaram
na repetição sem esse limite curto. Não foi alterado o runner do projeto.
Foram excluídos `test_first_person_grip_assets.gd` e
`test_reload_arm_clips.gd`: pertencem à auditoria dos assets/clips de recarga
em curso. Os testes de integração dos braços, empunhaduras, recargas,
câmara, interface e modelos estão entre os aprovados.

Lista, limites das capturas e hashes do código verificado:
[validation.json](validation.json). Os testes respeitam o critério do
projeto: sem `TEST FAIL` nem `SCRIPT ERROR`, com resultado de conclusão e
saída normal ou o código conhecido de encerramento do Godot no Windows.
Avisos de recursos no encerramento não são falhas de teste.
