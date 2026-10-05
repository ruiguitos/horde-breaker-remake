# TODO

Lista viva de pendentes. Uma linha por item; apagar quando feito.

## Equilíbrio (afinar a jogar)

- [ ] **Level-up demasiado fácil**: no primeiro playtest, com ~300 kills e
  nível ~15, quase todas as cartas estavam no máximo. Opções: curva de XP
  mais íngreme (`GameData.xp_for_level`), menos XP por inimigo, mais cartas
  ou mais stacks, cartas raras. Valores em `game/data/game_data.gd`.
- [ ] Dificuldade entre ilhas (HP ×1,3 por ilha, mais especiais) por validar.

## Gameplay

- [ ] Escolha de rota entre ilhas (grafo com modificadores).
- [ ] Mais desbloqueios com Intel: armas e cartas no pool, classes.
- [ ] Boss na última ilha (Volcano).
- [ ] Caches/desvios opcionais na ilha.

## Gráficos e feel

- [ ] Som (tiros, impactos, breaker, música do diretor).
- [ ] Animação melhor que o "balançar" (Vertex Animation Textures, BRAINSTORM §8).
- [ ] Desmembramento por partes da cápsula (agora são cubos).
- [ ] Fade de edifícios entre câmara e jogador (spike `camera_medium`).

## Técnico

- [ ] Medir FPS no PC (RX 590) com 150 inimigos e preencher `game/README.md`.
- [ ] Ecrã de título e opções (volume, sensibilidade).
