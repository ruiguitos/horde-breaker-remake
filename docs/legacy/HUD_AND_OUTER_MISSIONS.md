# HUD e missões opcionais — 2026-09-07

Revisão posterior: o utilizador pediu a remoção do painel dos dois slots mostrado
na captura. O HUD deixou de o instanciar; o script mantém-se sem utilização.
As restantes melhorias/missões continuam. Os números abaixo são históricos;
a suite HUD/missões adaptada passou 24/24 headless sem o painel. A continuação
de Scrap está em [SCRAP_EXPEDITION_PLAN.md](SCRAP_EXPEDITION_PLAN.md).

## Entrega

- HUD: dois slots, bindings atuais, arma ativa, carregador/reserva; EMPTY,
  NO RESERVE e LOW RESERVE. Atualiza ambas as armas a 10 Hz, incluindo pickups.
- Radar: mesmo alvo do tracker de objetivos, dourado e preso ao limite quando
  distante; especiais maiores/cor-de-rosa, antes dos normais, com teto de 40.
- Cartas: sem auto-pick; mantém pausa até selecionar, evita duplo clique e
  recalcula ofertas em fila para não oferecer cartas entretanto maxadas.
- Debrief: ilha/objetivo, três melhorias de maior nível e recursos temporários
  versus permanentes, além das estatísticas existentes. Sem métricas inventadas.
- Mourning: três altares, 8 segundos dentro de 8 m por altar; até dois Runners
  por ativação, se houver espaço no orçamento global.
- Shipwreck: três gravadores, 12 segundos dentro de 5 m; até dois Spitters por
  ativação. Afastar-se pausa o trabalho, sem perder o progresso acumulado.
- Recompensa: cache existente (40/60 Scrap), um carregador para a reserva de
  cada arma, limitado à capacidade disponível, e 25 run XP. Uma vez por run.
- Clareiras para scatter em torno de objetivos/caches; terminais com corpo
  World layer 1/mask 0 e interação Area layer 8/mask 2.

As duas missões são opcionais: não bloqueiam ferries de regresso, pontes ou
extração. Estado acompanha a instância da run no Resume Run, sem novo save.
Não aumenta ilhas/regiões; não implementa loja de Scrap, navmesh ou streaming.

## Teste manual

1. Parar a execução antiga. F5 → iniciar uma **run nova** (Resume conserva a antiga).
2. Disparar/recarregar/trocar 1/2; verificar ambos os slots e avisos de reserva.
3. Subir de nível, esperar mais de 10 s; nada deve escolher sozinho. Selecionar
   uma carta com rato ou foco de teclado/comando. A partida deve retomar.
4. Dawn → Lantern Ferry → Mourning. Seguir o alvo dourado, premir F num altar,
   afastar-se e regressar; o progresso deve pausar e continuar. Completar três.
5. Recolher a cache; repetir F não concede nova recompensa. Regressar pelo ferry.
6. High Cliffs → Ironworks → três breakers → Salvage Ferry → Shipwreck.
   Repetir com gravadores, raio menor e ataques à distância.
7. Confirmar que os ferries permitem abandonar as missões incompletas e voltar.
8. Morrer/extrair e verificar debrief. Repetir numa run nova: missões reiniciam.

Não requer edição manual de nós, importação de assets nem regeneração de terreno.

## Validação

Godot 4.7.2, executável console já instalado. Testes de asserção e capturas não
substituem playtest de combate prolongado nem demonstram resolução dos crashes.

- `test_run_upgrades`: 32/32, incluindo espera real de 10,5 s e duplo clique.
- `test_expedition_guidance`: 89/89 (inclui bloqueio de cache, afastamento,
  conclusão dos seis locais e recompensa one-shot).
- `test_destiny_archipelago`: 239/239; `test_minimap`: 17/17.
- `test_archipelago_route_progression`: 27/27; variante Terrain: 65/65.
- `test_expedition_hud_missions`: 39/39 com renderer, em cada uma das resoluções
  1152×648 e 1920×1080: F real, cápsula no acesso aos seis locais, slots sem
  sobreposição com munição, exclusão de carta maxada e debrief dentro do ecrã.
- Capturas locais em `.godot/hud_missions` e `.godot/hud_missions_1080`.
- Persistem depreciações Terrain3D e avisos de ObjectDB/recursos no encerramento
  de algumas suites antigas; a suite nova descarrega o mundo explicitamente.

## Limitações e próximo passo

Balanceamento inicial: combates podem ser fáceis se o orçamento já estiver cheio
ou se o jogador evitar ataques; missão exige presença, não matar todo o encontro.
Os inimigos ainda usam a navegação anterior e podem atravessar obstáculos.
Pontos de aproximação foram testados, não todos os caminhos possíveis na ilha.
Artes dos altares/gravadores são primitivas; falta polimento visual e de combate.
Custos/utilização de Scrap, integridade de armas encontradas e soak continuam
etapas separadas. Recompensa é fixa; seleção de recompensas fica para depois.

## Ficheiros e Git

Criados: `scripts/ui/loadout_status.gd`,
`scripts/systems/expedition_mission_terminal.gd`,
`scripts/systems/outer_island_mission.gd`,
`tests/test_expedition_hud_missions.gd` e este documento.

Alterados: ficheiros indicados nos comandos abaixo. Existem alterações anteriores
nos ficheiros partilhados; organizar primeiro as dependências ou selecionar hunks
com `git add -p`. Sem commit/push nesta tarefa.

```powershell
git status
git add scripts/ui/loadout_status.gd scripts/systems/expedition_mission_terminal.gd scripts/systems/outer_island_mission.gd tests/test_expedition_hud_missions.gd docs/HUD_AND_OUTER_MISSIONS.md
git add scripts/ui/minimap.gd scripts/ui/upgrade_choice_panel.gd scripts/ui/game_over_panel.gd scenes/ui/game_over_panel.tscn scripts/systems/archipelago_objective_tracker.gd scripts/systems/maritime_expansion_hub.gd scripts/systems/destiny_archipelago_design.gd tests/test_expedition_guidance.gd tests/test_run_upgrades.gd
git add -p scripts/ui/game_hud.gd scripts/weapons/weapon_controller.gd scripts/systems/destiny_archipelago_prototype.gd docs/GDD.md docs/ARCHITECTURE.md docs/ROADMAP.md docs/PROGRESS.md
git commit -m "feat: improve expedition HUD and add outer island missions"
```

Acrescentar os `.gd.uid` correspondentes se o editor os gerar; não usar `git add .`.
