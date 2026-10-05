# TODO

Lista viva de pendentes. Uma linha por item; apagar quando feito.

## Equilíbrio (afinar a jogar)

- [ ] **Level-up**: curva passou a quadrática (`8 + 6n + n²`; 300 XP → nível 7
  em vez de 10) e há 12 cartas (21 escolhas). Confirmar a jogar.
- [ ] **Dano em rajada**: no soak, o bot levou mais de 60 de dano num só
  frame na 3.ª ilha (vários Brutes, golpe do boss e rochas ao mesmo tempo).
  Considerar frames de invulnerabilidade curtos depois de um golpe forte.
- [ ] Boss: confirmar a duração do combate (bot: ~2 min com a nova escolha
  de alvo).
- [ ] Dificuldade entre ilhas (HP ×1,3 por ilha, mais especiais) por validar.

## Gameplay

- [ ] Rotas: mapa em grafo visível (agora são 2 opções por paragem).
- [ ] Mais desbloqueios com Intel: cartas no pool. Equilibrar classes.

## Gráficos e feel

- [ ] Afinar som e música a ouvido (volumes em `island.gd::_play_audio`, timbres em `audio/sfx.gd` e `audio/music.gd`).
- [ ] Animação melhor que o "balançar" (Vertex Animation Textures, BRAINSTORM §8).

## Técnico

- [ ] Medir FPS no PC (RX 590) com 150 inimigos e preencher `game/README.md`.
- [ ] Ecrã de título; mais opções (sensibilidade do comando, remapear teclas).
