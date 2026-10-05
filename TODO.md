# TODO

Lista viva de pendentes. Uma linha por item; apagar quando feito.

## Equilíbrio (afinar a jogar)

- [ ] **Level-up**: curva passou a quadrática (`8 + 6n + n²`; 300 XP → nível 7
  em vez de 10) e há 12 cartas (21 escolhas). Confirmar a jogar.
- [ ] Dano corpo a corpo limitado a 25 por frame (`MAX_MELEE_PER_FRAME`):
  confirmar a jogar se cercado ainda é perigoso o suficiente.
- [ ] Boss: confirmar a duração do combate (bot: ~2 min com a nova escolha
  de alvo).
- [ ] Dificuldade entre ilhas (HP ×1,3 por ilha, mais especiais) por validar.

## Gameplay

- [ ] Ilhas: 5 biomas e 3 missões; faltam peças "à mão" (farol, forte, ponte).

- [ ] Rotas: mapa em grafo visível (agora são 2 opções por paragem).
- [ ] Mais desbloqueios com Intel: cartas no pool. Equilibrar classes.

## Gráficos e feel

- [ ] Afinar som e música a ouvido (volumes em `island.gd::_play_audio`, timbres em `audio/sfx.gd` e `audio/music.gd`).
- [ ] Animação melhor que o "balançar" (Vertex Animation Textures, BRAINSTORM §8).

- [ ] Animação dos zombies com Vertex Animation Textures (andar/atacar).
- [ ] Final da história: 4.ª ilha "Origin" depois de recuperar os 10 ficheiros.

- [ ] Sons de rifle/SMG/shotgun gravados (o pack Ovani não os tem).
- [ ] Reduzir o pack Ovani aos ficheiros usados (215 MB no repositório).

## Técnico

- [ ] Medir FPS no PC (RTX 5060 8 GB) com 150 inimigos e preencher `game/README.md`.
- [ ] Sensibilidade do stick direito (a do rato e o remapear teclas já existem).
