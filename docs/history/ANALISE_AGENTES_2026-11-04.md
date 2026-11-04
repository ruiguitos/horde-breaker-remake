# Análise de código e de jogo (agentes do estúdio), 2026-11-04

Estado: registo de uma análise de leitura. Não houve playtest, nem medição de desempenho por sistema, nem execução da suite completa. Os achados vêm de agentes. Os pontos marcados **verificado** foram conferidos no código; os restantes são hipóteses. As prioridades abaixo são uma proposta para decisão: não substituem `TODO.md` até o utilizador as aprovar.

## Método

- Sete agentes do estúdio, cada um numa área, só de leitura: arquitetura (`lead-programmer`), gameplay (`gameplay-programmer`), UI e acessibilidade (`ui-programmer`), desempenho estático (`performance-analyst`), pilares do GDD (`game-designer`), testes e riscos (`qa-lead`), e mapas e ilhas (`level-designer`).
- Vários agentes atingiram o limite de 20 turnos sem entregar; foram reativados com um pedido de entrega.
- Há alterações por commitar em `island_run.gd`, `director.gd`, `game_data.gd` e outros ficheiros. Os achados nesses ficheiros valem para o estado de hoje.

## Resumo

1. **A rede de segurança tem furos.** O executor dá PASS a um teste que crasha depois de imprimir uma linha `TEST:` (verificado). O smoke só instancia `main.tscn`.
2. **Há um bug provável de equilíbrio.** O Elite Pack substitui o multiplicador da selva (verificado).
3. **O jogo ainda não tem prova humana.** Há três desenhos de playtest diferentes; sem decisão, a validação não fecha.
4. **As ilhas são sorteadas, não desenhadas.** Nenhuma das cinco tem sítios para Cargo, Nest, Search, Signal, Escort ou Uplink; só o Activate tem marcadores (verificado).
5. **Os ficheiros centrais são grandes.** `island_run.gd` tem 4092 linhas, `island.gd` 2965 e `hud.gd` 2191 (verificado). A lógica de missões está espalhada por cadeias de `if mission ==`.
6. **Acessibilidade por fazer.** Não há modo daltónico nem movimento reduzido (verificado para o daltónico).
7. **Desempenho: medir antes de otimizar.** O bench não separa o custo da horda.
8. **Pilares: o código cobre os três, mas a decisão entre ilhas é o elo fraco.** Sair cedo é opção dominada, o breaker pode empilhar e o Archivist paga-se numa run. Veredicto do agente: CONCERNS, sem crítico.

## Verificado no código

- `tests/run_all.gd:85-91`: se o log tiver `TEST: ` (com espaço), não tiver `TEST FAIL`, `SCRIPT ERROR` nem `Parse Error`, e o código de saída for 139 ou -1073741819, classifica como PASS.
- `game/world/island_run.gd:496-502`: `specials_mult *= 1.4` (selva) é substituído por `= 2.0` (Elite).
- `game/world/director.gd:9-10`: limiares 70 e 25. `game/README.md:777` diz que os números de equilíbrio estão em `game_data.gd`.
- `game/main.gd:266`: a telemetria escreve `"version": 3`; `game/README.md:632` fala de versão 2 do formato.
- `game/data/missions/escort.tres:14`: `escort_speed = 2.0`. `game/README.md:289-293`: tempos de 69, 97, 145 e 162 s para as quatro partes da Berlenga.
- As cinco cenas de `game/world/handmade/islands/` não têm marcadores dos objetivos `Cargo_`, `Nest_`, `Search_`, `Signal_`, `EscortRoute_` e `Uplink` (zero ocorrências). Têm só `Generator1–3`, usados pelo Activate (`beach_01.tscn:848`; leitura em `handmade_island.gd:194`).
- Nenhum código de `game/` lê os marcadores `Arena_` (cinco cenas os têm).
- `game/ui/`: `tr()` aparece só em 2 dos 26 ficheiros (`dialogue_box.gd` e `loading_screen.gd`). Não há `.pot` nem `.po` em `game/` (os addons têm, mas não são do jogo).
- `game/ui/dev_menu.gd:101-103`: escreve `run.noclip` diretamente nos callbacks.
- `game/core/game_input.gd:27`: a tecla R faz parte de `confirm`.
- `game/data/game_data.gd:413`: `enemy_types()` reconstrói a lista a cada chamada.
- `game/world/island.gd:1991`: `_fade_occluders` corre a cada frame, em `_process`.
- `DevOptions` é estado estático lido em código de produção (`island_run.gd`, `profile.gd`, `main.gd`).
- `game/world/island.gd:326` cria `Hud.new()`, e `island.gd` lê `Minimap.FUEL_COLOR`: o mundo depende da UI.
- Não há autoloads do jogo; só os dos addons (`project.godot:42-48`).
- `game/data/game_data.gd`: `EXTRACTION_INTEL_MULTIPLIER = 1.5` e `CROSSHAIR_CONE_DEG = 6.0`.
- `game/data/perks/archivist.tres`: `benefit_values = (10, 20, 30)`; `game/world/island_run.gd:3817-3820` soma esse valor por caixa.
- `game/world/island_run.gd:2932-2935`: o Insta-Kill mata qualquer inimigo, incluindo o boss (comentário no código).

## Achados por prioridade (proposta)

### 1. Proteger o trabalho (antes de mais código)

- **Gate que dá PASS a crashes.** Feito (2026-11-04, `tests/run_all.gd`): um código de crash é FAIL mesmo depois dos resultados. A exceção do quirk existe só por teste, na lista `KNOWN_SHUTDOWN_CRASH` (vazia: a suite de hoje saiu 83/83 com código 0). Não se usaram marcadores finais, que tocariam em 86 ficheiros.
- **Smoke raso.** O smoke só instancia `main.tscn`, e os estados carregam-se com `load()` em runtime. Um erro de parsing num estado pode passar. Feito (2026-11-04): `tests/test_smoke.gd` verifica os 85 scripts de `game/` com `can_instantiate()`. `load() == null` não bastava: uma sonda com erro de sintaxe voltou de `load()` sem `null`. (S)
- **Trabalho em curso sem isolamento.** Nove ficheiros de `game/` por commitar, incluindo `island_run.gd` e `director.gd`. Correção: correr a suite antes de cada commit. Decidir quando se commita. (decisão)

### 2. Bugs e lacunas com teste

- **Elite Pack** substitui o multiplicador da selva. Antes de mudar, escrever o teste e vê-lo falhar. A intenção é do designer. (S)
- **Ciclo do diretor** (`director.gd:57-93`) sem teste; os testes de missão congelam-no. Feito (2026-11-04): `tests/test_director_cycle.gd`, 14 verificações com seed fixa (arranque, pico, relaxamento, teto, semente). São testes de caracterização: passam no código atual. As 5 do EXFIL estão em `tests/test_director_exfil.gd`, que só se commita com o EXFIL do diretor, porque dependem dele. (M)
- **Transições de missão** sem tabela: cinco estados, mais inteiros próprios em cada missão. Correção: tabela e teste de transições inválidas. (M)
- **Telemetria** sem teste. Fechar a janela a meio de uma ilha pode perder essa ilha, porque não há tratamento de `WM_CLOSE_REQUEST` em `game/` (relatório, não confirmado). Adiado: a escrita está em `game/main.gd:254`, com alterações do utilizador por commitar. Por fazer: montar o JSON numa função testada, e decidir se o fecho grava a ilha parcial. (S e decisão)
- **Empurrão do breaker.** `knock_back` empurra 0,6 m a cada fotograma da investida, o que pode tornar a distância dependente do FPS. Verificado: não depende do FPS. A simulação corre em `_physics_process` com o passo fixo de 60 Hz (`island.gd:1898-1940`), e o projeto não altera `physics_ticks_per_second`. O empurrão é de 0,6 m por tick (`island_run.gd:2027`) e só mudaria se a taxa de física mudasse. Não alterado. (S)

### 3. Jogo e desenho

- **Playtest sem protocolo único.** Três desenhos: o TODO fala em 3 pessoas, 1 run, Recruit e Threat 1; o B01 da auditoria fala em duas classes; a análise de 2026-10-23 fala em 3 a 5 runs por classe; a revisão de 2026-10-22 fala em 4 de 5 pessoas em 90 s. Correção: o utilizador fixa a amostra e há um protocolo único no TODO. (decisão)
- **Tempos da Berlenga.** Os tempos do README não batem com a escolta a 2 m/s. Com um percurso de 616 m na parte 1, o mínimo são 308 s (relatório). A origem dos 69 e 97 s não foi encontrada. Correção: velocidade própria do sobrevivente e repetir a medição. (S)
- **Objetivos sem sítios desenhados.** A variedade vem do sorteio, não do lugar. Correção: marcadores autorais por ilha no `_design_*` de `tools/dev/build_islands.gd`. (M por ilha)
- **Arena do Behemoth.** O boss nasce a 22 m do jogador, em ângulo aleatório (relatório). Os `Arena_*` não são lidos. Correção: nascer num `Arena_*` e desenhar a arena com pilares. (S e M)
- **Pesos das missões.** A missão da casa pesa 3 em 12 na primeira ilha, e a Escort, aprovada para o Port, pesa 1 (relatório). Decisão do utilizador. (decisão)
- **Validação de rotas.** `_check_routes` testa só o Activate; a fuga em 3 s não tem teste (relatório). Correção: incluir `Choke_` e `Arena_` (S) e um teste de distância de fuga (M).

### 4. Acessibilidade e interface

- **Modo daltónico** inexistente (verificado). A paleta é única em `ui_theme.gd`; só parte dos estados tem forma. (M)
- **Movimento reduzido** inexistente: o flash de dano é só vermelho, há tremor no `island.gd`, e o carregamento tem espera mínima de 1,2 s sem saltar (relatório). (M)
- **Remapeamento** só captura teclado e rato; sem comando, o REBIND fica em «PRESS KEY…» (leitura, não corrido). (M)
- **Escala de texto.** O controlo existente é a escala do HUD (60–100 %); os menus não têm escala de texto. (M)
- **Localização.** Só 2 de 26 ficheiros usam `tr()`. O `CLAUDE.md` pede texto em inglês, e `ui-code.md` torna a localização obrigatória. Decidir se a regra se aplica já. (decisão)
- **Menu de desenvolvimento** escreve diretamente no estado. Verificado: o gate existe. `DevOptions.enabled()` é `OS.is_debug_build()` (`game/core/dev_options.gd:15-16`), e o menu só é criado se estiver ativo (`island.gd:311`). (S)
- **R confirma** nos ecrãs de fim (verificado). Pode haver avanço acidental. (S)
- **Definições gravam a cada passo do slider** (relatório). Não alterado: `profile.save()` aparece em 13 chamadas de `game/ui/settings_panel.gd`, e o painel já grava ao fechar (linha 56). O custo não foi medido. (S)

### 5. Estrutura e dados

- **Lógica de missões espalhada** por `island_run.gd`, `island.gd` e `hud.gd`. Correção: uma interface `Mission`, um script por missão, em passos com testes a proteger. (L)
- **Funções longas:** `_build_world` (~194 linhas), `build_map` (~200) e `set_mission` (~154). (M por grupo)
- **Dependência mundo para UI.** Correção: mover a paleta de marcadores para `game/data`. (S)
- **`DevOptions`** é estado global lido em produção. Correção: um objeto de opções injetado. (S e M)
- **`Profile`** mistura definições, progressão e gravação, com serialização manual. Correção: separar e derivar o save de uma lista única de campos. (M)
- **Valores de equilíbrio fora de `game/data/`** (`director.gd`, `horde.gd`), ao contrário do que diz o README. Correção: mover para dados, com teste que compare texto e número. (M)

### 6. Desempenho (hipóteses, por medir)

- **Medir primeiro.** O bench regista delta, draw calls e vivos, sem separar a horda. Com 600 amostras, o p99 assenta em cerca de seis frames. Já feito no bench: `tools/dev/bench_island.gd` cronometra `run.step` por tick, em CPU e sem janela. Três corridas hoje, com 180 vivos no máximo (Threat 3, Swarm): média 1,94 ms, p95 ~3,1 ms, p99 ~3,7 ms, máximo 10 a 18 ms. Não se soma aos ~5 ms do FPS com GPU (`TODO.md`), que é outra medição. (S)
- **Consultas de raio.** `query_radius` visita (2⌈r⌉+1)² células a cada tick, e a mira sem alvo repete a procura. (S e M)
- **`enemy_types()`** reconstrói a lista a cada morte (verificado). Correção: passar `run.horde.types`. (S)
- **`_fade_occluders`** percorre todos os edifícios a cada frame (verificado). Correção: escrever só quando o valor muda. (S)
- **Explosões.** O relatório diz que cada explosão cria nó, malha e material. O código mostra reutilização de `_explosions[k]`. Confirmar antes de mudar. (S)
- **Escritas de MultiMesh** por instância e por frame nos detritos (relatório). (S)
- **Teto de 290 vivos** é alcançável pelas regras do código (relatório), mas a medição documentada é de 150. Medir no PC. (S)

## Pilares do GDD (análise do game-designer)

Veredicto do agente: **CONCERNS**. O código cobre os três pilares: horda com teto até 300 e breaker, rotas e modificadores, 39 cartas, 12 nós de perks com 26 alternativas, e 5 armas. O elo mais fraco é a decisão entre ilhas (P2). Os riscos são de dominância e de economia, e todos estão por jogar.

1. **Sair cedo é opção dominada (P2, alto).** Sair no barco banca as ilhas concluídas, morrer mantém também a ilha atual, e só continuar dá o ×1,5 (verificado). O trade-off «extrair cedo contra arriscar» (GDD §3) não existe. Decisão do utilizador (`PROGRESSION_AND_ECONOMY.md` §6, pergunta 3). (S)
2. **Breaker empilhado (P1/P3, alto, hipótese).** Cálculo do agente: um Vanguard com Hair Trigger V e Recovery III tem cerca de 2,1 s de cooldown; com Adrenaline III, cerca de 1,3 s por uso. Um acerto pode chegar a ×5,6 com quatro cartas. A build cabe em 13 escolhas. O movimento pode ser a melhor forma de matar, ao contrário de `COMBAT_AND_ENEMIES.md` §2.2. Medir antes de mexer; teto ao cooldown total ou rever Adrenaline. (M)
3. **Archivist paga-se numa run (P3, alto).** Logística I e Archivist I custam 100 Intel e dão +10 por caixa (verificado). Com quatro caixas por ilha (`island_map.gd:192`), dão +120 numa run de três ilhas, e +360 no rank III. A referência de run média é de 40 a 60 Intel (`PROGRESSION_AND_ECONOMY.md` §3.1). Contraria «a meta dá opções, não números» (§0). Decisão: uma caixa por ilha, ou um valor menor. (S)
4. **Catálogo numérico e metas de nível contraditórias (P3, alto).** Cerca de 28 das 39 cartas são números. Há sobreposições: HP (Thick Hide e Thick Skin), velocidade (Light Boots e Fleet Footed), cura por orbe (Field Dressing e Trail Rations). `PROGRESSION_AND_ECONOMY.md` fala em nível 12 a 15, mas a curva dá 68 920 XP até ao nível 25. Há tensão com «dezenas de +5 %» (GDD §2). Decidir a meta e fundir as sobreposições. (M)
5. **Decisões entre ilhas pouco informativas (P2, médio).** Calm (×1,0) é a única rota sem bónus; cura e munição ficam bloqueadas quando estão cheias; Fog só muda o visual; Swarm e hazard pay mudam o teto, não a taxa de spawn. Nenhum custo está medido. Medir antes de mexer. (M)
6. **Parar para focar não existe (P1, médio).** O headshot é geométrico, sem termo de movimento, e correr dispara (decisão de 2026-10-14). O modo por omissão (3.ª pessoa) só dispara com a cruz a menos de 6° do corpo (verificado). A regra de disparo muda com a câmara, contra o cone da decisão de 2026-10-05. Decidir: cone ou cruz. (M)
7. **AR sem tempo morto (P3, médio).** Cálculo do agente: com recarga, o DPS do AR é 108; com 1,6 s de recarga, 73. SMG 89, MG 151. A escolha da principal depende de uma decisão pendente (`TODO.md`). Não confirmei o campo de recarga em `rifle.tres`. (S e decisão)
8. **Insta-Kill e Nuke saltam o Behemoth (P2, médio).** O Insta-Kill mata qualquer inimigo, o boss incluído (verificado). Segundo o agente, o Nuke também, o que não confirmei. A frequência não está medida (`game_data.gd:314-317`). O clímax da ilha final pode ser saltado por sorte. Correção: excluir o boss do Nuke e, se for decisão, do Insta-Kill. (S)
9. **Documentação atrasada (baixo).** `COMBAT_CATALOG.md` §4 e §6, `GAME_AUDIT.md` §1 e §3, `COMBAT_AND_ENEMIES.md` §2.1 e `game/README.md:3` dizem que o spawn recusa a partir de 150 (o código usa `director.max_alive`), 9 nós e 20 alternativas (código: 12 e 26), e 2 cargas de breaker (segundo o agente, o código tem 1). O G01 já está resolvido. (S)

**Não avaliado (pilares):** sensação de mira e de disparo; peso das escolhas; vivos atingidos pelo teto (ler o painel F3 numa sessão); abates por fonte; custo real de Fog, Elite e hazard pay; equilíbrio entre classes; níveis por run humana.

## Decisões para o utilizador

1. Amostra do playtest: quantas pessoas, que classe, que Threat e quantas runs.
2. Elite Pack: a selva e o Elite somam-se ou substituem-se?
3. Exfil: o limite de vivos ignorar Threat e modificadores é de propósito?
4. Peso da missão da casa no sorteio: manter, subir ou fixar?
5. Fecho de janela a meio de uma ilha: gravar a ilha parcial ou não?
6. Acessibilidade: entram já o modo daltónico, o movimento reduzido e o remapeamento com comando?
7. Localização: a regra `ui-code.md` aplica-se já, ou só quando houver mais de um idioma?
8. Sair cedo: a extração antecipada deve ter custo? (`PROGRESSION_AND_ECONOMY.md` §6, pergunta 3.)
9. Archivist: uma caixa por ilha, ou um valor menor?
10. Meta de nível e cartas: nível 12 a 15 ou 25? Fundir as cartas sobrepostas?
11. Mira: cone de 6° ou cruz? Correr e disparar deve ter custo de precisão?
12. Boss: o Insta-Kill e o Nuke devem poder matar o Behemoth?
13. Commit do trabalho em curso (nove ficheiros de `game/`, incluindo `main.gd`) e deste relatório.
14. Ordem: que grupos avançam primeiro?

**Recomendações** (minhas; a decisão é tua):

1. Adotar já o protocolo do `TODO.md`: 3 pessoas, uma run, Recruit, Threat 1. Repetir por classe depois.
2. Somam-se. Substituir a selva em silêncio apaga um efeito de bioma. Confirmar a intenção do designer.
3. Manter o limite do Exfil, mas dizê-lo no design: o modo tem regras próprias.
4. Fixar em 1 até haver playtest, para não ajustar o sorteio com dados que ainda não existem.
5. Gravar a ilha parcial, marcada como abandonada. Perder a run quando a janela fecha estraga a telemetria do playtest.
6. Sim, o modo daltónico e o movimento reduzido já. O remapeamento com comando fica para depois.
7. Só quando houver um segundo idioma. Hoje obrigaria a `tr()` em todo o lado sem benefício.
8. Sim, com um custo pequeno e visível. Sem custo, sair cedo domina as outras opções.
9. Um valor menor, com teto por ilha. O valor soma por caixa (`archivist.tres`), por isso acumula dentro de uma ilha.
10. Nível 15 nos primeiros testes. Fundir cartas só depois de listar as duplicadas.
11. Manter o cone que o código já usa, com um pequeno custo de precisão ao correr.
12. Não. O Insta-Kill não deve matar o boss, e o Nuke pode, com dano.
13. Commit do teu trabalho em curso antes de eu tocar nos ficheiros de `game/`. As minhas alterações ficam à parte.
14. Grupo 2 (bugs com teste), depois o 4 (acessibilidade), e só depois o 3 (desenho).

## Não avaliado

- Desempenho real em milissegundos por sistema, e o teto de 200 a 290 vivos.
- Sensação de jogo, dificuldade, ritmo humano, legibilidade e leitura de rotas na câmara.
- A suite completa (`run_all.gd`) e a sua duração. Só o smoke foi corrido.
- Créditos de fontes e de modelos, e carregamento em thread.

## Próximos passos (sugestão)

- Feito em 2026-11-04: o gate e o smoke (grupo 1), o teste do ciclo do diretor (grupo 2), e a verificação de quatro afirmações do relatório (empurrão do breaker, gate do menu de desenvolvimento, gravação das definições, telemetria adiada).
- Decidir os pontos de «Decisões para o utilizador» (14).
- Depois de commitares o trabalho em curso: a telemetria com a função testada, o `enemy_types()` e as validações de rotas dos mapas.
