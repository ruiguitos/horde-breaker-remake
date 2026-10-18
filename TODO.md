# TODO

Lista viva de pendentes. Uma linha por item; apagar quando feito. Decisões
do utilizador estão em `docs/DECISIONS.md`; a evidência da última auditoria
em `docs/tech/GAME_AUDIT.md` (secção de 17 de outubro).

## Validação (precisa de jogar ou de hardware)

- [ ] Medir FPS no PC (RTX 5060 8 GB) com 150 inimigos, em jogo completo
  (terreno, HUD, boss e efeitos), e preencher `game/README.md`.
- [ ] Equilíbrio a jogar: curva de XP (quadrática, ×10; ver
  `docs/tech/COMBAT_CATALOG.md`), power-ups, dano corpo a corpo limitado a 25
  por frame, duração do boss, dificuldade entre ilhas.
- [ ] Berlenga de ponta a ponta à mão: Escort → Signals → Hold Sequence →
  Holdout, com rampas, passagens estreitas, spawns e barco.
- [ ] Som e música a ouvido (volumes em `island.gd::_play_audio`, timbres em
  `audio/sfx.gd` e `audio/music.gd`). Sons de disparo AR/SMG/Machine Gun/Shotgun
  continuam sintetizados; gravar quando houver.
- [ ] Comando: sessão com comando físico, reconexão, resoluções e ultrawide.
- [ ] Crawler com o GLB: ritmo do passo em jogo, leitura dos headshots (alvo a
  0.685 m, centro visual ~0.79 m), tombamento e morte. Custo de GPU medido a
  +0.52 ms com 150 crawlers em planície; decidir se cabe com o jogo cheio.

## Modelos (Codex)

- [ ] `crawler.glb`: a cabeça está ~3 cm afastada do tronco (NOTES do Codex só
  subiu a cabeça); todos os crawlers têm a mesma cabeça e corpo. Pedir correção
  ao Codex. Triângulos: 4632 por crawler (walker 708); reduzir feridas e dentes
  se o playtest pedir.

## Conteúdo

- [ ] Volcano sem cena feita à mão equivalente a `volcano_01.tscn` (o gerador
  procedural cobre o boss; falta acabamento e landmarks).
- [ ] Props realistas restantes (`docs/tech/REALISTIC_PROPS.md`): rever a
  utilidade antes de integrar, já há alternativas procedurais.
- [ ] Cartas desbloqueadas por Intel no pool; equilibrar classes.

## Animação e feedback

- [ ] Movimento próprio do Breaker, e ações de ferimento e morte no modelo do
  jogador (`docs/tech/LOCOMOTION.md`).
- [ ] Poses dos especiais sincronizadas com as ações reais (grito, explosão,
  fases do boss).

## Técnico

- [ ] Pacote Windows: não existe `export_presets.cfg` (está no `.gitignore`).
  Falta exportação reproduzível, versão, ícone, licenças incluídas e arranque
  sem editor. Precisa dos templates de exportação 4.7 (só há os de mono).
- [ ] Definir `application/config/version` antes da primeira versão distribuída
  (a telemetria regista `dev` até lá).
- [ ] Correr a suite completa (`tests/test_*.gd`) antes de cada entrega e
  confirmar 0 `TEST FAIL`, `SCRIPT ERROR` e `Parse Error`.

## Fora do plano (decisões)

- Origin jogável, co-op e mapa de rotas em grafo: expansões, fora do ciclo
  single-player aprovado. A rota entre ilhas é sorteada desde 2026-10-14.
- VAT para zombies: é uma proposta de `BRAINSTORM.md` §8, não uma decisão; o
  shader atual anima por pivôs e a auditoria não demonstrou necessidade.
