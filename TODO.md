# TODO

A única lista de trabalho ativo. Uma linha por item; apagar quando feito.
As decisões fechadas estão em `docs/DECISIONS.md` e prevalecem sobre tudo.
A evidência das auditorias está em `docs/tech/GAME_AUDIT.md`; os relatórios
com data e os handoffs fechados vivem em `docs/history/` (não são listas).

## Decisões à espera do utilizador

- [ ] **Personagens**: estilizado-premium (Codex continua a modelar) ou base
  mesh humana real (MakeHuman/comprada, com retarget). Trava a animação de
  nível seguinte. Três tentativas de humano realista falharam a anatomia:
  `docs/design/art/visual_target_20261023/` e `walker_hero_original/`.
- [ ] **Personagem do jogador**: manter o Recruit v03 e investir em materiais,
  ou trocar por uma malha nova.
- [ ] **Recarga da Assault Rifle**: hoje instantânea e com balas infinitas,
  como estado provisório de jogabilidade. Decidir se fica.
- [ ] **Motor**: proposta em `docs/tech/ENGINE_MIGRATION.md` (ficar no Godot e
  medir o jogo completo). Sem decisão registada.
- [ ] **`assets/models/visual_target_20261023/`**: pasta local ignorada
  (156 MB). Apagar ou manter como arquivo.
- [ ] **Volcano**: aprovar o desenho da cena feita à mão (`volcano_01.tscn`),
  o acabamento e os landmarks.

## Validação (precisa de jogar ou de hardware)

- [ ] Playtest com pessoas reais: 3 pessoas, uma run do arquipélago no Threat 1
  com o Recruit, telemetria em `user://runs/`. É a maior lacuna do projeto.
- [ ] Medir FPS no PC (RTX 5060 8 GB) com 150 inimigos em jogo completo
  (terreno, HUD, boss e efeitos) e preencher `game/README.md`.
- [ ] Medir o custo da arma realista (frame time, draw calls, VRAM) com 150
  inimigos. O GLB tem 28 MB e texturas 2K.
- [ ] Equilíbrio a jogar: curva de XP (quadrática, ×10; ver
  `docs/tech/COMBAT_CATALOG.md`), power-ups, dano corpo a corpo limitado a 25
  por frame, duração do boss, dificuldade entre ilhas.
- [ ] Berlenga de ponta a ponta à mão: Escort → Signals → Hold Sequence →
  Holdout, com rampas, passagens estreitas, spawns e barco.
- [ ] Som e música a ouvido: volumes em `island.gd::_play_audio`, timbres em
  `audio/sfx.gd` e `audio/music.gd`. AR/SMG/Machine Gun/Shotgun continuam
  sintetizados (os passos também).
- [ ] Comando: sessão com comando físico, reconexão, resoluções e ultrawide.
- [ ] Crawler com o GLB: ritmo do passo em jogo, leitura dos headshots (alvo a
  0,685 m), tombamento e morte. Custo medido: +0,52 ms com 150 crawlers.

## Animação e arte

- [ ] Fase 1 da animação (rig atual, custo baixo): ligar os clips UAL que já
  estão instalados e sem uso — `Pistol_Aim_Up/Neutral/Down`, `Pistol_Reload`,
  `Interact`, `PickUp_Table`, `Jump_Land`, `Hit_Head` — e dar *wind-up* de
  0,3 s ao ataque da horda.
- [ ] Sway/lag da arma em primeira pessoa (o ADS, o carregador e o *charge*
  já existem em `view_model.gd`).
- [ ] Poses em código que faltam: explosão do Bloater e fase de raiva do
  Behemoth (`boss_enraged`), em `zombie.gdshader`.
- [ ] Ver no editor o flinch, o roll e a queda na morte do jogador
  (`docs/tech/LOCOMOTION.md`, secção Reações).
- [ ] Ver a pose de chamada do Screamer e a carga do golpe do Behemoth.
- [ ] Preset horror: a estrada é a faixa mais clara do ecrã e puxa o olho.
  Rever material/contraste do caminho à noite.

## Modelos (Codex)

- [ ] `crawler.glb`: reconfirmar os testes e ver no editor. Todos os crawlers
  partilham cabeça e corpo; 4 814 triângulos cada (walker 708).
- [ ] Empunhaduras de primeira pessoa: ver no editor as mangas, a mão direita
  e a espingarda (ombro ajustado, sem alongar ossos).
- [ ] Recarga dos braços (SMG e Machine Gun): falta a revisão a jogar
  (sensação e posição das mãos). Ver `docs/history/RELOAD_ARM_CLIPS_RESUME_2026-10-21.md`.
- [ ] Walker herói (`walker_hero_original/`): rig e 4 clips aprovados como
  molde; a malha não entra. Guardar para quando houver base mesh.

## Conteúdo e apresentação

- [ ] Props realistas restantes (`docs/tech/REALISTIC_PROPS.md`): rever a
  utilidade antes de integrar; já há alternativas procedurais.
- [ ] Equilibrar classes a jogar (as seis cartas com preço já estão no Intel;
  `docs/design/PROGRESSION_AND_ECONOMY.md` §3.2).
- [ ] Pacote Windows: reexportar com o código atual (o `build/` é de 18-10),
  decidir o ícone e a versão, e confirmar o arranque fora do editor.

## Documentação

- [x] Uma lista só: este ficheiro. Relatórios datados e handoffs em
  `docs/history/`.
- [x] `CAMERA_CONTROLS_HUD.md` alinhado com a decisão do auto-fire.
- [x] GDD e `WORLD_AND_MISSIONS.md` marcados onde foram substituídos.
- [ ] Revisão dos links e da numeração de missões (o `CLAUDE.md` diz 9; o jogo
  tem 11 recursos, 10 nas rotas mais o Holdout).

## Fora do plano (não fazer sem decisão nova)

- Origin jogável, co-op e mapa de rotas em grafo: expansões, fora do ciclo
  single-player aprovado. A rota entre ilhas é sorteada desde 2026-10-14.
- VAT para zombies: proposta de `BRAINSTORM.md` §8; o shader anima por pivôs e
  a necessidade não foi demonstrada.
