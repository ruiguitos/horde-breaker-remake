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
- [ ] **Modo Exfil**: os degraus do diretor (90 s, +25 vivos, teto 250) e o
  ritmo de especiais são propostas de playtest. A telemetria fica no `island_log`
  da run; o ficheiro de telemetria não é escrito nas corridas do sandbox (regra
  existente). Decidir se o modo deve gravar.
- [ ] **Mapa do Exfil**: a arena (`assets/models/environment/extraction_test_arena/`,
  `layout.json`) está em caixas de placeholder com as pegadas do `build_layout.py`;
  as alturas são suposições (paredes 3 m, cobertura baixa 1,2 m, contentores 2,6 m,
  pilares 6 m, beacon 3 m). Os 8 módulos GLB ainda não foram entregues: quando
  chegarem, substituir as caixas em `Buildings/` e `Decor/` sem redesenhar a geometria.
  Falta verificar no editor a altura do cais, o beacon e as gargantas.
  Limite conhecido: a grelha não tem altura de passagem, por isso a plataforma
  bloqueia (é cobertura) e a rampa não leva a ela. O próprio layout diz que
  isto exige integração no motor.

## Validação (precisa de jogar ou de hardware)

- [ ] Playtest com pessoas reais: 3 pessoas, uma run do arquipélago no Threat 1
  com o Recruit, telemetria em `user://runs/`. É a maior lacuna do projeto.
- [x] Medir FPS no PC (RTX 5060 8 GB) com 150 inimigos: 5,1–5,2 ms de média
  e p99 de ~12 ms nas três câmaras, a 1600×900; números em `game/README.md`.
  `tools/dev/bench_frame.gd` repete a medição.
- [x] Medir o custo da arma realista: +0,02 ms na média, dentro do ruído, e o
  mesmo número de draw calls.
- [ ] Medir o que a primeira medição não cobriu: Berlenga, vulcão com o
  Behemoth, cartas elementais em pico e 1080p/1440p/4K.
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

- [ ] Ver a jogar a horda depois da correção de 2026-11-10: os inimigos já não devem vir em fila nem
  sempre do mesmo lado em terreno aberto (`tests/test_horde_spread.gd` mede-o; falta o olho).

## Animação e arte

- [ ] Braços com a mira: a UAL não tem pega de rifle, e os clipes de pistola
  partiriam a pega de duas mãos (`docs/tech/LOCOMOTION.md`, *Camada de tronco*).
- [ ] Ver no editor o aviso de 0,3 s dos Shamblers e Runners (inclinação, braços
  e avanço a 25 %) e a Fuel Run com o aviso ligado.
- [ ] Aviso do golpe no Crawler: o `crawler_body.gdshader` tem de levantar os
  braços antes de o Crawler ter aviso.

Bloqueados por mecânica (não são animação pendente; motivo em `docs/tech/LOCOMOTION.md`):

- `Pistol_Reload`: a pega de duas mãos tem de ceder durante a recarga, e falta decidir se a mão esquerda vai ao carregador.
- `Interact`: `interact()` só trata dos bidões da Fuel Run; não há noção de "segurar E".
- `PickUp_Table`: não há sinais apanhados; `interact()` só trata dos bidões.
- `Jump_Land`: o jogo não tem queda normal (`_fly` só sobe em noclip) e o Breaker não tem ar; falta definir o que é "degrau alto".
- `Hit_Head`: `react_hit()` não recebe a zona do dano, por isso não há origem de dano na cabeça.
- [ ] Ver no editor o peso da arma em primeira pessoa (atraso ao rodar a
  câmara, `LAG_PER_RATE`). Por fazer: o sway de posição ao andar e ao acelerar.
- [ ] Ver no editor a explosão do Bloater (corpo a inchar 0,35 s e bola de fogo
  no mesmo tempo) e a pose de fase 2 do Behemoth (`ENRAGED_POSE`, a afinar).
- [ ] Ver no editor o flinch, o roll e a queda na morte do jogador
  (`docs/tech/LOCOMOTION.md`, secção Reações).
- [ ] Ver a pose de chamada do Screamer e a carga do golpe do Behemoth.
- [ ] Ver no editor a estrada escura do preset horror, a cor de cada bioma
  (`game/data/biomes/*.tres`) a luz do preset horror (1,3; a captura ainda sai escura), e a erva e os seixos da praia, nas ilhas geradas e na beach_01 (até 400 instâncias,
  60 m; desligados no preset Low). São propostas a confirmar.

## Modelos (Codex)

- [ ] Ronda de modelos pedida em 2026-11-10: quatro armas realistas e seis inimigos.
  Pedidos e contratos em `docs/tech/MODELS_ROUND_BRIEF.md`; à espera das entregas do Codex.

- [ ] `crawler.glb`: reconfirmar os testes e ver no editor. Todos os crawlers
  partilham cabeça e corpo; 4 814 triângulos cada (walker 708).
- [ ] Empunhaduras de primeira pessoa: ver no editor as mangas, a mão direita
  e a espingarda (ombro ajustado, sem alongar ossos).
- [ ] Recarga dos braços (SMG e Machine Gun): falta a revisão a jogar
  (sensação e posição das mãos). Ver `docs/history/RELOAD_ARM_CLIPS_RESUME_2026-10-21.md`.
- [ ] Walker herói (`walker_hero_original/`): rig e 4 clips aprovados como
  molde; a malha não entra. Guardar para quando houver base mesh.

## Conteúdo e apresentação

- [ ] Menus na direção A («field dossier», decisão de 2026-11-10): o título está feito
  (`game/ui/dossier.gd`, captura em `docs/design/dossier_20261111/`). Por fazer: armory, perks
  (quadro de fichas), armas (formulário de requisição), barco, debrief e cartas. Decidir se entra
  uma fonte de máquina de escrever (hoje IBM Plex Mono; a Special Elite é Apache 2.0, fora da
  lista de licenças aceites).
- [ ] Ilhas com aspeto natural (decisão de 2026-11-10), piloto na `beach_01`: 1) pôr as 13 peças
  do `scenery_kit` nos edifícios e na praia; 2) variar a vegetação com as peças do kit de
  natureza por usar; 3) várias texturas no terreno e costa menos regular; 4) medir desenho e
  grelha. Faltam modelos para casas, contentores, barco e pontes (hoje caixas): Codex ou kits CC0.
- [ ] Vista geral do mapa antes de partir: desenhar a ilha real a partir da grelha da cena
  (`HandmadeIsland.grid_image`) em vez das manchas de `game/ui/route_map.gd`.
- [ ] Objetivos variados: feito em 2026-11-10 na `beach_01` (seis geradores, cada run usa três,
  `IslandRun.pick_generators`) e no Exfil (três pontos de extração, um por seed, revelado aos
  10:00); teste em `tests/test_objective_pools.gd`. Por fazer: ver os três sítios novos da
  `beach_01` no editor (165,125; 90,180; 170,60), as outras quatro ilhas, bolsas para as outras
  missões e o boss a nascer num `Arena_`.
- [ ] HUD: placas escuras por trás dos blocos, feito em 2026-11-10 (`Hud._plate`); ver a jogar.
  Por fazer, da mesma proposta: minimapa sem legenda fixa, habilidades compactas, XP numa linha
  fina, abates só na pausa; cartas de level-up e debrief com menos vazio.
- [ ] Ver no editor a árvore de perks a 1600 × 900 (ícones de 18 px, pips em linha)
  e o painel LOADOUT com os renders (`docs/tech/WEAPON_MODELS.md`).
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

- Origin jogável e mapa de rotas em grafo: expansões, fora do ciclo
  single-player aprovado. A rota entre ilhas é sorteada desde 2026-10-14.
- Co-op: pendente desde 2026-11-10 (decisão do utilizador), para começar mais
  tarde. Falta decidir a forma (local, LAN, online); `docs/design/COOP_PROPOSAL.md`.
- VAT para zombies: proposta de `BRAINSTORM.md` §8; o shader anima por pivôs e
  a necessidade não foi demonstrada.
