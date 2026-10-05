# TODO

Lista viva de pendentes. Uma linha por item; apagar quando feito.

## Equilíbrio (afinar a jogar)

- [ ] **Level-up**: curva passou a quadrática (`8 + 6n + n²`; 300 XP → nível 7
  em vez de 10) e há 12 cartas (21 escolhas). Confirmar a jogar.
- [ ] Dificuldade entre ilhas (HP ×1,3 por ilha, mais especiais) por validar.

## Gameplay

- [ ] Rotas: mapa em grafo visível (agora são 2 opções por paragem).
- [ ] Mais desbloqueios com Intel: cartas no pool. Equilibrar classes.
- [ ] Boss: ataque à distância, ilha própria (Volcano).
- [ ] Caches/desvios opcionais na ilha.

## Gráficos e feel

- [ ] Afinar o som sintetizado a ouvido (volumes em `island.gd::_play_audio`, timbres em `audio/sfx.gd`); música do diretor.
- [ ] Animação melhor que o "balançar" (Vertex Animation Textures, BRAINSTORM §8).

## Técnico

- [ ] Medir FPS no PC (RX 590) com 150 inimigos e preencher `game/README.md`.
- [ ] Ecrã de título; mais opções (sensibilidade do comando, remapear teclas).
