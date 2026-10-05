# Tarefas para sessões na cloud

Cada tarefa é independente e pode correr **em paralelo**: escreve só nos
seus próprios ficheiros, num branch próprio, e termina com um PR para
`master`. Copiar o bloco do prompt tal como está para uma sessão nova em
[claude.ai/code](https://claude.ai/code) com o repositório
`ruiguitos/horde-breaker-remake` selecionado.

Preparado a 2026-10-05. As tarefas de design produzem **propostas**: o
utilizador decide e regista em `docs/DECISIONS.md`.

| ID | Tipo | Entrega | Branch |
|---|---|---|---|
| D1 | Design | `docs/design/GDD.md` | `design/gdd-v2` |
| D2 | Design | `docs/design/COMBAT_AND_ENEMIES.md` | `design/combat-enemies` |
| D3 | Design | `docs/design/PROGRESSION_AND_ECONOMY.md` | `design/progression` |
| D4 | Design | `docs/design/WORLD_AND_MISSIONS.md` | `design/world-missions` |
| D5 | Design | `docs/design/CAMERA_CONTROLS_HUD.md` | `design/camera-hud` |
| T1 | Técnico | `docs/tech/ARCHITECTURE.md` | `tech/architecture` |
| S1 | Spike | `spikes/camera_medium/` | `spike/camera-medium` |
| S2 | Spike | `spikes/horde_flowfield/` | `spike/horde-flowfield` |
| S3 | Spike | `spikes/director/` | `spike/director` |

Ordem sugerida se não der para lançar todas: S1, S2, D1, D2, T1, D5, D3, D4, S3.

---

## D1 — GDD v2

```text
Lê CLAUDE.md, docs/DECISIONS.md, docs/design/BRAINSTORM.md e docs/legacy/ (sobretudo GDD.md, PROJECT_AUDIT.md, INSPIRATIONS.md e ARCHIPELAGO_GAMEPLAY_PLAN.md).

Tarefa: escreve docs/design/GDD.md, o GDD v2 do remake, em português de Portugal, curto (alvo: 2–4 páginas). Conteúdo:
1. Pitch de uma frase e high concept de um parágrafo.
2. 3 pilares, cada um com "o que significa" e "o que exclui".
3. Core loops: 30 s, 5 min (ilha), 25 min (run), meta. Para cada loop: ações, decisões do jogador, recompensa.
4. Fantasia do jogador, público-alvo, plataforma (PC Windows, teclado/rato e comando), sessão-alvo.
5. Âmbito do vertical slice (1 ilha, 1 classe, 3 armas, 4 inimigos, 1 missão) e lista "não vamos fazer" com o porquê.
6. Decisões propostas: para cada ponto em aberto de docs/DECISIONS.md, 2–3 opções com prós/contras e a tua recomendação, coerente com a câmara média já decidida.
7. Perguntas para o utilizador.

Não edites docs/DECISIONS.md nem outros ficheiros. Trabalha no branch design/gdd-v2 e abre um PR para master com um resumo das recomendações.
```

## D2 — Combate e inimigos

```text
Lê CLAUDE.md, docs/DECISIONS.md, docs/design/BRAINSTORM.md e docs/legacy/ (GDD.md, INSPIRATIONS.md, CONTENT_EXPANSION_PLAN.md).

Tarefa: escreve docs/design/COMBAT_AND_ENEMIES.md em português de Portugal. Conteúdo:
1. Modelo de mira com câmara média: compara mira manual, mira assistida (magnetismo) e auto-fire opcional; recomenda um, explica o papel dos headshots/pontos fracos.
2. O verbo "breaker" (empurrão/dash pela horda): 2–3 variantes, cooldown, risco/recompensa.
3. Arsenal inicial de 6–8 armas definidas por comportamento (não só stats): papel, alcance, munição (infinita vs limitada), sinergias.
4. Bestiário de 8–10 inimigos: papel, silhueta legível de cima a ~35°, comportamento, contra do jogador, valores iniciais (HP, velocidade, dano) como hipóteses de playtest.
5. Diretor de horda à Left 4 Dead: métrica de intensidade, fases crescer/pico/alívio, orçamento de inimigos, regras de spawn fora do campo de visão da câmara média.
6. Game feel: lista priorizada (hit-stop, knockback, som, partículas) com custo estimado.
7. Decisões propostas e perguntas para o utilizador.

Não edites outros ficheiros. Branch design/combat-enemies, PR para master.
```

## D3 — Progressão e economia

```text
Lê CLAUDE.md, docs/DECISIONS.md, docs/design/BRAINSTORM.md e docs/legacy/ (GDD.md, SKILL_TREE_EXPANSION_PROPOSAL.md, SCRAP_EXPEDITION_PLAN.md, PROJECT_AUDIT.md).

Tarefa: escreve docs/design/PROGRESSION_AND_ECONOMY.md em português de Portugal. O original tinha camadas a mais (Scrap, Credits, 2 tipos de XP, cartas, skill tree, ARMORY, mastery, variantes, evoluções, base); o objetivo é reduzir a duas camadas claras. Conteúdo:
1. Camada da run: XP e curva de níveis, catálogo de 15–20 cartas (⅓ stats, ⅔ comportamento), evoluções de armas, raridades e regras de sorteio.
2. Economia da run: moeda(s), onde se ganham, onde se gastam (loja do barco ou equivalente), munição.
3. Camada meta: uma moeda, desbloqueios horizontais (armas, classes, perks, modificadores), níveis de dificuldade.
4. Classes: 2–3 com identidade (habilidade ativa + passiva + loadout) sem árvores de 50 nós.
5. Tabela de ritmo: o que o jogador desbloqueia nas primeiras 1, 5, 10 e 20 runs.
6. Decisões propostas e perguntas para o utilizador.

Não edites outros ficheiros. Branch design/progression, PR para master.
```

## D4 — Mundo, ilhas e missões

```text
Lê CLAUDE.md, docs/DECISIONS.md, docs/design/BRAINSTORM.md e docs/legacy/ (ARCHIPELAGO_GAMEPLAY_PLAN.md, MAP_DESIGN.md, HUD_AND_OUTER_MISSIONS.md, PROJECT_AUDIT.md).

Tarefa: escreve docs/design/WORLD_AND_MISSIONS.md em português de Portugal. Conteúdo:
1. Estrutura da expedição: mapa em grafo (camadas, nós, escolhas visíveis), duração-alvo por ilha e por run, extração antecipada vs continuar.
2. Ilhas como cenas compactas (150–250 m): regras de layout para câmara média (legibilidade, oclusão, rotas de fuga, ritmo aberto/fechado, landmarks).
3. 6–8 templates de missão com fases, condição de sucesso/falha, evento de horda e recompensa.
4. Fichas de 4 ilhas (Dawn Beach, Shadow Forest, High Cliffs, Volcano Peak) reaproveitando a intenção do original: identidade, zonas, landmarks, missões possíveis.
5. Base: compara acampamento com tiers, barco como base móvel e "sem base"; recomenda um.
6. Modificadores de ilha para rejogabilidade (6–10).
7. Decisões propostas e perguntas para o utilizador.

Não edites outros ficheiros. Branch design/world-missions, PR para master.
```

## D5 — Câmara média, controlos e HUD

```text
Lê CLAUDE.md, docs/DECISIONS.md (câmara média já decidida), docs/design/BRAINSTORM.md (secção 7) e docs/legacy/ (GDD.md, INSPIRATIONS.md, HUD_AND_OUTER_MISSIONS.md).

Tarefa: escreve docs/design/CAMERA_CONTROLS_HUD.md em português de Portugal. Conteúdo:
1. Especificação da câmara média: presets (ombro afastado / média / alta leve), parâmetros, yaw livre vs fixo, colisão e oclusão, zoom dinâmico em picos de horda, câmara em eventos (boss, desembarque).
2. Controlos completos para teclado/rato e comando (tabela de bindings), incluindo mira, breaker, habilidade, interação e troca de arma.
3. HUD: layout por zonas do ecrã, o que fica no mundo vs no HUD, indicadores de borda para ameaças fora de vista, legibilidade em 1152×648 e 1920×1080. Inclui um esboço ASCII do ecrã.
4. Acessibilidade: auto-fire opcional, tamanho de texto, daltonismo, shake reduzido.
5. Critérios de playtest para escolher o preset final.
6. Decisões propostas e perguntas para o utilizador.

Não edites outros ficheiros. Branch design/camera-hud, PR para master.
```

## T1 — Arquitetura técnica

```text
Lê CLAUDE.md, docs/DECISIONS.md, docs/design/BRAINSTORM.md (secção 8) e docs/legacy/PROJECT_AUDIT.md (lições de estabilidade e performance).

Tarefa: escreve docs/tech/ARCHITECTURE.md em português de Portugal para o remake em Godot 4.7 + GDScript tipado. Conteúdo:
1. Estrutura de pastas de game/ e convenções de nomes.
2. Autoloads (o mínimo possível) e porquê; event bus; state machine da run (menu → barco → ilha → extração → debrief).
3. Dados em Resources: WeaponData, EnemyData, CardData, IslandData, MissionData (campos mínimos).
4. Horda: arquitetura para 300+ inimigos (simulação em arrays, flow field, spatial hash, MultiMesh, LOD de animação), e onde ficam CharacterBody/física.
5. Save versionado com migrações; telemetria por run em JSON.
6. Testes headless: convenções, runner único, o que se testa em CI vs no editor.
7. Orçamento de performance-alvo e como medir.
8. Riscos técnicos e spikes recomendados.

Inclui também tests/run_all.gd: um runner headless que descobre e corre todos os tests/test_*.gd e spikes/*/tests/test_*.gd em subprocessos (OS.execute com o executável atual) e devolve exit code ≠ 0 se algum falhar; valida-o com tests/test_smoke.gd.

Não edites outros ficheiros. Branch tech/architecture, PR para master.
```

## S1 — Spike da câmara média

```text
Lê CLAUDE.md, docs/DECISIONS.md e docs/design/BRAINSTORM.md (secção 7, tabela de presets).

Tarefa: cria o spike spikes/camera_medium/ em Godot 4.7 com GDScript tipado, só com primitivas (sem assets externos):
- Cena camera_medium.tscn: chão 120×120 m, alguns blocos/colunas como obstáculos e oclusores, um jogador cápsula e ~40 "zombies" cápsula que andam devagar para o jogador (movimento simples, sem navegação).
- Movimento do jogador WASD + comando, relativo à câmara.
- Rig de câmara com os 3 presets (ombro afastado ~25°/7 m/0,8 m; média ~35°/10 m/0,4 m; alta leve ~45°/13 m/0 m), trocáveis com as teclas 1/2/3, transição suave, parâmetros @export.
- Yaw com rato (botão direito ou sempre, configurável) e analógico direito; mira por retícula no ecrã com raycast ao plano do jogador; linha de mira visível.
- Oclusão: obstáculos entre câmara e jogador ficam semitransparentes.
- Overlay de texto com preset atual, parâmetros e número de zombies visíveis no frustum.
- Testes headless em spikes/camera_medium/tests/: a cena carrega, os presets aplicam os valores certos, a contagem de zombies no frustum funciona, o raycast de mira acerta no plano.
- README.md do spike: como abrir no editor (Windows) e testar (F6 na cena), o que observar em cada preset, e limites (na cloud não houve verificação visual).

Não edites ficheiros fora de spikes/camera_medium/. Corre os testes antes do PR. Branch spike/camera-medium, PR para master.
```

## S2 — Spike da horda com flow field

```text
Lê CLAUDE.md e docs/design/BRAINSTORM.md (secção 8).

Tarefa: cria o spike spikes/horde_flowfield/ em Godot 4.7 com GDScript tipado, só com primitivas:
- Grelha de flow field (célula 1 m) num mapa 150×150 m com obstáculos; recalculo incremental quando o jogador muda de célula (BFS/Dijkstra), feito fora do frame se necessário.
- Agentes como dados (PackedVector3Array/arrays), não como nós: seguem o campo, separação por spatial hash, velocidades variadas.
- Render com MultiMeshInstance3D (cápsulas ou caixas).
- Consulta "hitscan" contra o spatial hash (raio + direção → primeiro agente), sem physics bodies.
- Benchmark headless spikes/horde_flowfield/tests/bench_horde.gd: mede o tempo de simulação por tick (média, p95, p99) para 100, 300, 500, 1000 e 2000 agentes, e o tempo de recalcular o flow field; imprime uma tabela.
- Testes headless: agentes contornam um obstáculo e chegam ao alvo; nenhum agente atravessa paredes; hitscan devolve o agente mais próximo na linha.
- README.md do spike com os números medidos, o ambiente (CPU da cloud, headless, sem GPU) e o que fica por medir no PC do utilizador (render, GPU).

Não edites ficheiros fora de spikes/horde_flowfield/. Branch spike/horde-flowfield, PR para master.
```

## S3 — Spike do diretor de horda

```text
Lê CLAUDE.md, docs/design/BRAINSTORM.md (secção 3) e docs/legacy/GDD.md (secção "Inimigos", diretor original).

Tarefa: cria o spike spikes/director/ em Godot 4.7 com GDScript tipado, totalmente headless (sem cena visual):
- Um diretor de horda à Left 4 Dead: métrica de intensidade (dano recebido, inimigos próximos, tempo sem pausa), fases build-up / peak / relax, orçamento de inimigos ativos, composição por tipos, eventos especiais.
- Um jogador simulado simples (mata N inimigos/s conforme uma "skill" configurável, recebe dano por inimigos próximos).
- Simulação de uma run de 25 minutos para 3 perfis de jogador (fraco, médio, forte) que exporta CSV (tempo, intensidade, fase, inimigos ativos, spawns, vida) para spikes/director/output/.
- Comparação com o diretor original (escalada só por tempo: nível a cada 75–110 s, teto 90) na mesma simulação.
- Testes: as fases alternam; o orçamento nunca é excedido; o perfil fraco recebe mais períodos de alívio do que o forte.
- README.md com a explicação do modelo, gráficos em ASCII ou tabelas resumidas dos CSV e recomendações de parâmetros.

Não edites ficheiros fora de spikes/director/. Branch spike/director, PR para master.
```
