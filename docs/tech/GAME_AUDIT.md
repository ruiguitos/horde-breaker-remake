# Horde Breaker — auditoria do jogo e trabalho por terminar

## Estado atual — 2026-10-17

**Referência:** `2555d01`. Revisão estática da documentação, código e recursos
da cópia local. Há alterações locais de limpeza de addons e ficheiros de
importação; foram preservadas. Não foram executados testes, exportações ou
uma sessão gráfica nesta revisão. As contagens de testes e medições da
auditoria de 11 de outubro, abaixo, são históricas.

**Conclusão:** o ciclo principal já está implementado. Os pendentes atuais
concentram-se na coerência das regras, robustez, animações de ações,
acabamento dos cenários e validação jogada. Não é necessário voltar a criar
os modelos das cinco armas, a locomoção ou os modelos dos especiais.

### 1. Correções técnicas prioritárias

P1 significa prioridade antes de distribuir uma versão; não significa que
tenha sido reproduzido um bloqueio de uma run nesta revisão.

| Prioridade | O que falta | Evidência atual e critério de conclusão |
|---|---|---|
| P1 | Unificar os limites da horda. | `IslandRun.load_context()` aumenta `director.max_alive` com Threat/modificadores, mas `_spawn_enemy()` continua limitado a `GameData.MAX_ALIVE = 150`. Ninhos usam o menor dos dois limites; invocações do boss acrescentam inimigos sem consultar esse teto. Aplicar uma política comum, respeitando o máximo de 300 decidido, e verificar todos os caminhos. [Simulação](../../game/world/island_run.gd), [diretor](../../game/world/director.gd). |
| P1 | Proteger a gravação do perfil. | `Profile.save()` abre diretamente o ficheiro final para escrita; `load_profile()` devolve um perfil novo quando o JSON é ilegível. Faltam escrita temporária/substituição, recuperação e preservação do ficheiro danificado. Não foi observada perda de dados nesta análise. [Perfil](../../game/core/profile.gd). |
| P1 | Corrigir o executor geral de testes. | `run_all.gd` exige código de saída zero e só procura `TEST FAIL`; não verifica explicitamente `SCRIPT ERROR`, parsing, conclusão ou timeout. Pode rejeitar testes concluídos no Windows ou não reconhecer um erro de script. Validar com casos controlados de sucesso, erro, falha e processo pendurado. [Executor](../../tests/run_all.gd). |
| P1, distribuição | Restringir noclip ao desenvolvimento. | Mouse 4/5 ativa `run.noclip` sem proteção de build no respetivo handler. Confirmar que fica inacessível numa versão de release. [Entrada](../../game/core/game_input.gd), [ilha](../../game/world/island.gd). |
| P1, distribuição | Preparar e validar o pacote Windows. | Não existe `export_presets.cfg` nesta cópia. Falta demonstrar exportação reproduzível, versão/ícone, inclusão das licenças e arranque sem editor. O ecrã de créditos já existe; não o contar novamente como sistema em falta. |
| P2 | Alinhar texto e efeitos. | War Cry promete redução genérica de dano, mas o fator 0,6 está no dano melee. Elite Pack menciona Brutes/Grabbers, mas o diretor também aumenta Bloaters/Screamers. Corrigir descrições ou decidir alterar os efeitos. A antiga descrição de Pack Rat já foi corrigida. [Vanguard](../../game/data/classes/vanguard.tres), [Elite Pack](../../game/data/modifiers/elite.tres). |
| P2 | Completar definições de comando. | Settings guarda sensibilidade do rato, mas não do stick nem zonas mortas configuráveis. A mira lê o dispositivo 0 e usa velocidades fixas. Rever seleção do comando ativo e validar com hardware. [Settings](../../game/ui/settings_panel.gd), [mira](../../game/world/island.gd). |
| P2 | Completar a telemetria para reprodução de problemas. | O JSON inclui resultados por etapa, mas não guarda seed da run/ilha, revisão do jogo, utilização das armas ou causa de morte. O nome tem precisão de segundos e falhas de abertura são silenciosas. [Gravação](../../game/main.gd), [resultados](../../game/world/island_run.gd). |

### 2. Modelos, animações, som e cenários ainda parciais

| Área | O que já existe | Trabalho ainda por fazer |
|---|---|---|
| Jogador | Recruit/Vanguard com Idle/Walk/Jog/Sprint, strafe/recuo sintetizados, apoio dos pés e empunhadura por arma. | Movimento próprio do Breaker; rodar no sítio e arranques/paragens mais naturais; ações de habilidade, ferimento e morte; resolver a interseção da perna com a lata. A avaliação visual nas mudanças de direção continua necessária. [Locomoção](LOCOMOTION.md), [modelo](../../game/world/soldier_model.gd). |
| Armas | Cinco GLB originais integrados; pega, cano, recuo e ADS em primeira pessoa. | Clips de recarga e bombeamento da shotgun, mãos/dedos mais detalhados e lentes mais convincentes. A mecânica já tem carregadores: SMG recarrega em 1,1 s, Machine Gun em 3,2 s; AR continua instantânea. Não afirmar que todas as recargas mecânicas estão em falta. [Armas](WEAPON_MODELS.md), [dados](../../game/data/weapons). |
| Sobrevivente | Escort tem modelo humano próprio com movimento simples dos membros e pose caído. | Rescue continua a criar uma cápsula laranja em `island.gd`. Integrar um humano nessa missão e melhorar deslocação, ferimento e morte; não criar outro sistema de escolta. [Modelos](../../game/world/escort_model.gd), [integração](../../game/world/island.gd). |
| Inimigos | Walker e seis especiais com silhuetas próprias; Crawler e perda de pernas também existem. | Sincronizar poses com ações reais: grito, explosão e fases/ataques do boss. O shader usa animação por pivôs; não há necessidade demonstrada de substituir esse sistema por VAT. Não confundir modelos existentes com todos os estados de animação concluídos. [Especiais](SPECIAL_ENEMY_MODELS.md), [arte atual](ZOMBIE_AND_WEAPON_ART.md). |
| Props | Gerador, bidão, caixote e barreira realistas; carrinho original procedural. | A integração dos restantes oito downloads continua pendente segundo `REALISTIC_PROPS.md`: barril, carrinho, braseiro, rádio, boia, cais, kit de forte e Venus. Rever utilidade antes de integrar: já há alternativas procedurais, incluindo carrinho e forte. [Props](REALISTIC_PROPS.md), [registo ativo](../../game/world/island_props.gd). |
| Cenários | Quatro ilhas manuais do arquipélago; Berlenga com quatro partes. O gerador já tem kits de farol e forte. | Volcano continua sem uma cena manual equivalente a `volcano_01.tscn`. Acabamento, colisões, caminhos, visibilidade e landmarks precisam de revisão jogada. Não classificar automaticamente o farol/forte como modelos inexistentes; a presença dos kits não certifica o aspeto de todas as cenas geradas. [Kits](../../tools/real_island/landmarks.gd), [ilhas](../../game/world/handmade/islands). |
| Áudio | Ambiente, música adaptativa, síntese e amostras Ovani. | Sons de disparo apropriados para AR/SMG/Machine Gun/Shotgun; continuam sintetizados. Afinar volumes, fadiga e leitura direcional a ouvido. [Som](../../game/audio/sfx.gd), [README](../../game/README.md). |

### 3. Validação pendente — não é ausência de implementação

1. **Desempenho do jogo completo:** medir 150 inimigos e o teto efetivo
   depois da correção dos limites, nas três câmaras, com terreno, IA, HUD,
   boss e efeitos elementais. O ensaio gráfico dos modelos dos especiais
   exclui esses sistemas; não demonstra FPS da ilha completa. Registar
   tempos médios/p95, memória e estabilidade numa sessão prolongada.
2. **Equilíbrio com jogadores:** XP/cartas, munição/recargas, duas classes,
   Threat 1–3, pressão entre ilhas, economia e duração das runs. Rever o
   impacto de Nuke/Insta-Kill no boss. Os bots que repõem vida não validam
   dificuldade humana.
3. **Berlenga de ponta a ponta:** Escort → Signals → Hold Sequence →
   Holdout, incluindo rampas, passagens estreitas, spawns e barco.
4. **Comando, resoluções e acessibilidade:** testar dispositivo ativo,
   reconexão, foco, legibilidade, ultrawide/4K e estados que dependem de cor.
5. **Suite atual:** voltar a executar antes de afirmar uma contagem verde.
   O commit `173d93c` contém correções de Escort/Intel Search; os resultados
   45/47, 46/48 e 47/49 dos relatórios de modelos são anteriores. Esta
   revisão não confirma nem repete essas falhas.

### 4. Pendentes antigos que já não devem orientar implementação

- Armas originais, empunhadura de duas mãos, caminhar/correr e modelos dos
  especiais: implementados. ADS, Crawlers e perda de pernas foram
  acrescentados entretanto.
- Árvore de perks, seleção de arma principal/secundária e substituição da
  Heavy Pistol pela Machine Gun: implementadas.
- Painel `ISLAND CLEARED`/`PART CLEARED`: existe `IslandEndPanel`, com
  estatísticas por etapa separadas do total da run. A pré-visualização da
  Berlenga recebe expedição/parte e desenha paisagem própria sem palmeiras.
  O §5 do handoff continua a pedir estas tarefas já feitas.
- Hold Sequence, Fuel Run, Nests, Intel Search, Signals, Sabotage e Escort:
  existem no código. O início de `OBJECTIVES_PROPOSAL.md` descreve uma
  proposta antiga; as secções posteriores registam integrações. Não usar
  a frase inicial «nada implementado» como estado atual.
- Remapeamento de armas 4/5: deixou de ser um requisito do loadout atual,
  que leva principal/secundária nas teclas 1/2. `weapon_next` e reroll
  continuam fora da lista de remapeamento, se se pretender completá-la.
- Créditos: já têm painel integrado. Hashima: removida por decisão;
  restaurá-la não é um pendente.
- `TODO.md` ainda duplica VAT, usa XP anterior à escala ×10 e diz «3
  missões». `CLAUDE.md` ainda apresenta uma slice de uma ilha. O handoff,
  propostas e relatórios históricos precisam de referências ao estado
  atual, preservando as decisões do utilizador.

### 5. Expansões que exigem decisão de âmbito

**Origin jogável**, mapa de rotas em grafo, cartas desbloqueadas por Intel,
mais classes/armas, evoluções e co-op continuam propostas/expansões. Não
são falhas do ciclo single-player aprovado. O final narrativo Origin já
existe. O grafo de rotas também deve ser reconciliado com a decisão mais
recente de transições automáticas e rota aleatória entre ilhas.

**Ordem recomendada:** limites da horda → saves/runner → sobrevivente Rescue
e ações de animação → medição completa e playtest → acabamento dos
cenários/áudio → pacote distribuível. Atualizar a lista curta de tarefas
em conjunto com essa próxima ronda; não implementar expansões por inferência.

**Verificação externa limitada:** o JEV verificou três distinções
metodológicas usando apenas um resumo abstrato e sanitizado, sem código,
caminhos ou identificadores do projeto: benchmark de arte versus jogo
completo, locomoção versus animações de ações e listas antigas versus
código atual. Confirmou as três; não auditou o repositório nem certificou
as implementações. Não foram enviados novos trechos de código.

---

## Auditoria histórica — 2026-10-11

O restante documento conserva a análise daquela data. Pendentes,
catálogos, commits e resultados abaixo não representam automaticamente
o estado atual; prevalece a atualização de 17 de outubro acima.

**Data:** 2026-10-11. **Estado analisado:** `48d0c42ae3fc7501d0eb3993fb9351ab3e9daa61`, depois das alterações do Claude.

**Atualização posterior à auditoria (2026-10-11):** a escala de XP mudou
para custos ×10 e recompensas 10/12/100/45/1000/45/60 por EnemyKind.
Os valores abaixo são o retrato da revisão indicada; os atuais estão no
[catálogo de combate](COMBAT_CATALOG.md). O feedback de Fast Learner no
HUD e a rejeição de power-ups expirados também foram reforçados, conforme
[cartas](CARDS_IMPLEMENTATION.md) e [power-ups](POWER_UPS_AND_DEFEAT.md).

O jogo já tem um ciclo completo e testável. O trabalho principal que falta é
resolver algumas incoerências, validar o equilíbrio com jogadores e substituir
o grey-box por modelos, animações e cenários consistentes. Os menus principais
e o HUD já foram renovados; não é necessário reconstruí-los todos.

Esta auditoria documenta o estado observado. Não altera regras, valores,
mapas ou assets e não autoriza implementar propostas. As decisões fechadas
continuam em [DECISIONS.md](../DECISIONS.md), que não foi alterado.
O [TODO.md](../../TODO.md) continua a ser a lista curta de trabalho ativo;
este documento reúne a evidência, os detalhes e os candidatos a tarefas.

## 1. Como foi verificado

- Leitura das regras, documentos de design, passagem de trabalho, código,
  recursos de dados, testes e dos dois commits mais recentes do Claude.
- **26/26 testes passaram:** 23 do jogo e três dos spikes. Todos terminaram
  com marcadores de sucesso e sem `TEST FAIL`, `SCRIPT ERROR` ou `Parse Error`.
- Execução sequencial, com perfil e telemetria numa pasta de utilizador
  isolada. O perfil real do jogador não foi usado para guardar resultados.
- Duas runs completas do bot, seeds 101 e 202, em Threat 2: seis ilhas,
  cobrindo os cinco biomas e as três missões do arquipélago, com extração.
- Verificação visual de 15 capturas do jogo em **Forward+, RTX 5060,
  1600 × 900**: título, Armory/classes/armas/perks, barco, acampamento,
  três câmaras, pausa, Settings, cartas, derrota, fim de ilha e debrief.
  Os ecrãs foram preparados com estados controlados; não representam
  quinze percursos jogados manualmente.
- Verificações específicas adicionais confirmaram o limite de spawns,
  a recolha de Extra Reroll com a reserva cheia e o tamanho do catálogo.
- JEV recebeu apenas resumos abstratos e sanitizados de quatro conclusões.
  Três tiveram confirmação; a formulação sobre o limite recebeu um veredicto
  ambíguo, de baixa confiança. Nesse caso prevalece a reprodução local
  explícita de **240 configurados / 150 efetivos**. JEV é apoio à revisão,
  não substitui a inspeção nem os testes.

**Limites da validação:** o bot repõe a vida a cada passo. Os seus tempos
de 301 e 364 segundos simulados não provam a duração de uma run humana nem
o equilíbrio. Não foi feita uma campanha manual completa na Berlenga,
uma sessão com comando físico, uma avaliação auditiva ou um benchmark
prolongado de FPS. As capturas não certificam todas as resoluções.

O Godot apresenta o problema conhecido de encerramento no Windows
(`-1073741819` depois de concluir os testes). Na sessão gráfica houve também
avisos de recursos gráficos/texto ainda alocados ao sair. Registar e isolar
essa limpeza é um pendente; não atribuir automaticamente estes avisos
a uma fuga de memória durante o combate.

Os logs, catálogo exportado e PNGs desta execução estão localmente em:
`C:/Users/Rui/.codex/visualizations/2026/10/05/01a10cc0-7b07-7312-9916-7b70f4c6b83d/game_audit_2026_10_11/`.
São evidência desta máquina e não fazem parte do repositório.

## 2. O que já está implementado

| Área | Estado atual confirmado |
|---|---|
| Ciclo da run | Título → Armory → barco/ilha → debrief → Armory; morte termina a run; Intel é conservado; extração ×1,5; Quick Redeploy. |
| Expedição | Berlenga com quatro partes e acampamentos, progressão transportada e Holdout final. |
| Combate | Auto-fire, três modos de câmara, headshots, Breaker, sprint com estamina, Granada e War Cry. |
| Armas | Cinco armas. AR com reserva infinita e carregador de 30; Shotgun, Heavy Pistol, SMG e Marksman com munição finita. |
| Cartas | 39 cartas, 157 ranks no catálogo; filtros de classe/arma/pré-requisitos; ofertas e rerolls deterministas; ranks máximos excluídos. |
| Elementos | Fire, Frost, Storm e Toxic; quatro melhorias elementais; três combinações automáticas. Wind Rounds também existe. |
| XP | Curva quadrática; XP fracionária do Fast Learner; a partir do nível 30, recolha automática de toda a XP no chão. |
| Power-ups | Sete tipos, RNG próprio, cooldown e garantia, desaparecimento, drops alcançáveis, ícones, minimapa e temporizadores. |
| Proteção | Escudo até 100, absorvido antes da vida; barra no HUD. |
| Meta | Cinco perks em slots, compra de slots, classes e armas, Threat 1–3. |
| Inimigos | Walker, Runner, Brute, Grabber, Bloater, Screamer e Behemoth; diretor com crescer/pico/relax. |
| Missões | Activate 3, Defend, Rescue; Holdout específico da expedição. Caixas opcionais e modificadores de rota. |
| Mundo | Cinco biomas; quatro ilhas `_01` feitas à mão; Hashima; Berlenga com terreno real; vulcão procedural. |
| Apresentação | Sky3D, Terrain3D, vegetação do Nature MegaKit, mar, partículas, desmembramento simples, grading e opções gráficas. |
| Menus | Tema próprio em título, Armory, barco, acampamento, cartas, pausa, derrota, debrief, Settings e arquivo de Intel. |
| HUD | Vida, escudo, XP, estamina, cooldowns, munição/carregador, objetivos, rádio, minimapa e avisos de perigo. |
| Pausa | Resume, Settings e Abandon; Controls já está dentro de Settings. Confirmação antes de abandonar. |
| Áudio | SFX sintetizados e do pack Ovani, música adaptativa e volumes separados. |
| História | Rádio de Hale, dez ficheiros de Intel e final narrativo Origin no debrief, com escolha persistida e bónus de Intel. |
| Técnico | Regras em `IslandRun` sem nós, flow field, spatial hash, MultiMesh, testes headless, perfil JSON versionado e telemetria por run. |

**Field Medic já não é uma classe jogável.** Foi retirado do catálogo e os
perfis antigos são migrados. A carta chamada Field Medic continua a existir.
Não tratar o regresso dessa classe como uma tarefa por cumprir.

## 3. Correções e incoerências confirmadas

Prioridades: **P1** antes de estabilizar/distribuir uma versão; **P2** na
próxima ronda de melhorias; **P3** acabamento. Não foi reproduzido um
bloqueio do ciclo principal nos testes desta auditoria.

### G01 — P1 — Fazer os limites da horda corresponderem à dificuldade

- [x] Usar uma regra comum para o diretor, spawns normais e invocações.

`IslandRun.load_context()` aumenta `director.max_alive` para Threat, Swarm
e Hazard Pay, mas `_spawn_enemy()` bloqueia aos `GameData.MAX_ALIVE = 150`.
Reprodução: Threat 3 + Swarm configura **240**; com 150 inimigos vivos,
uma chamada de spawn normal mantém **150**. As invocações do boss usam
outro caminho. O HUD de debug pode mostrar um limite superior ao que o
spawn normal consegue atingir.

**Feito quando:** testes confirmam a densidade configurada e o limite global,
incluindo invocações; benchmark com os números realmente atingidos.
Respeitar o teto de **300** já decidido, sem aumentar a carga sem medir.
Evidência: [island_run.gd](../../game/world/island_run.gd),
[director.gd](../../game/world/director.gd), [game_data.gd](../../game/data/game_data.gd).

### G02 — P1 — Retirar o acesso normal ao noclip numa versão distribuível

- [x] Condicionar os atalhos de noclip e a sua ativação a uma versão de desenvolvimento.

Os botões laterais Mouse 4/5 têm bindings de noclip e o handler de
`Island._unhandled_input()` não verifica `OS.is_debug_build()`. A opção
Test Island do título já tem essa proteção; o noclip não. Permite atravessar
paredes e mar e evitar dano. É útil para desenvolver, mas precisa de uma
separação explícita antes de exportar o jogo para jogadores.

**Feito quando:** funciona no desenvolvimento e não se ativa no executável
de release, incluindo por um binding guardado. Evidência:
[game_input.gd](../../game/core/game_input.gd), [island.gd](../../game/world/island.gd).

### G03 — P2 — Corrigir as descrições que não correspondem aos efeitos

- [x] War Cry: esclarecer que a redução atual é de dano corpo a corpo, ou
  decidir que deve proteger também de lava, explosões e ataques especiais.
- [x] Pack Rat: a descrição cita Shotgun e Heavy Pistol, mas a capacidade
  aumenta em **todas as armas de munição finita**, incluindo SMG e Marksman.
- [x] Elite Pack: a descrição cita Brutes e Grabbers, mas a ponderação
  também aumenta Bloaters e Screamers.
- [x] Documentar a interação Jungle + Elite Pack: o ×1,4 de especiais da
  selva é substituído por ×2,0, não combinado para ×2,8.

O War Cry anuncia genericamente “−40% damage taken”; a multiplicação por
0,6 está na chamada de dano melee. Os restantes danos seguem caminhos
separados. Corrigir texto é uma mudança pequena; ampliar proteção altera
o equilíbrio e precisa de uma decisão.

**Feito quando:** o texto promete precisamente o que o teste de efeito confirma.
Evidência: [vanguard.tres](../../game/data/classes/vanguard.tres),
[pack_rat.tres](../../game/data/perks/pack_rat.tres),
[elite.tres](../../game/data/modifiers/elite.tres),
[island_run.gd](../../game/world/island_run.gd), [director.gd](../../game/world/director.gd).

### G04 — P2 — Avisar quando um perk não serve a classe selecionada

- [x] Demolitions: impedir a equipagem sem efeito no Vanguard, ou apresentar
  claramente a incompatibilidade e deixar o jogador trocar de classe.

O perk modifica a Granada do Recruit. A lista da Armory permite comprá-lo
e equipá-lo também com Vanguard; pode ocupar um slot sem beneficiar a run.
Conservar a propriedade de perks já comprados. Evidência:
[armory.gd](../../game/states/armory.gd), [island_run.gd](../../game/world/island_run.gd).

### T01 — P1 — Tornar o runner de testes fiável no Windows

- [x] Alinhar `tests/run_all.gd` com os critérios definidos no AGENTS.md.
- [x] Detetar `SCRIPT ERROR`/erros de parsing, conclusão efetiva e testes
  pendurados; não confundir o problema conhecido de encerramento com uma
  falha da simulação, nem ignorar indiscriminadamente qualquer crash.

O runner atual exige exit code 0 e só procura `TEST FAIL`. Pode rejeitar
testes concluídos por causa do encerramento do Godot, ou não detetar um
erro de script se o processo sair com 0. Nesta auditoria os 26 processos
foram avaliados pelos logs e marcadores de conclusão.

**Feito quando:** um teste bom, um erro de script, um `TEST FAIL` e um timeout
produzem classificações corretas. Evidência: [run_all.gd](../../tests/run_all.gd).

## 4. Equilíbrio e progressão — falta validar a jogar

Estes pontos não são bugs demonstrados. São decisões ou valores provisórios
que os testes deterministas não conseguem aprovar.

| ID | Prioridade | Trabalho e critério de conclusão |
|---|---|---|
| B01 | P1 | Medir runs humanas nas duas classes e Threat 1–3: duração, mortes, nível final, Intel/minuto, dano recebido e utilização das armas. Confirmar ou rever o alvo de 20–30 min. |
| B02 | P1 | Validar o boss depois de Insta-Kill/Nuke: ambos agora o matam; medir a frequência de combate saltado e se o pico final continua interessante. Este comportamento está implementado e não é tratado como regressão. |
| B03 | P2 | Decidir o tratamento de recompensas sem benefício: Extra Reroll com três rerolls, Max Shield com escudo cheio, Max Ammo com reservas cheias, Full Power com habilidades prontas. A recolha atual consome o item mesmo sem ganho. |
| B04 | P2 | Decidir se XP Magnet deve continuar elegível depois do nível 30, quando toda a XP já é recolhida automaticamente. Cartas maximizadas já estão corretamente excluídas. |
| B05 | P2 | Rever cada arma com builds reais: tempo para matar, penetração, precisão, alcance, munição e utilidade por classe. Não decidir por DPS bruto apenas. |
| B06 | P2 | Rever as 39 cartas em ranks baixos/máximos e combinações: excesso de cura, cooldowns curtos, dano em cadeia, legibilidade e dominância da AR. **17/39** cartas têm filtro de AR. |
| B07 | P2 | Afinar XP e escolhas: a fórmula atual é `8 + 6n + n²`, com `n` igual ao nível atual; chegar de 1 a 30 exige 11 397 XP antes dos bónus. A recolha automática funciona, mas a sua frequência em runs normais ainda não foi medida. |
| B08 | P2 | Afinar chance/pity/cooldown de drops, durações, escudo, multiplicadores de Intel e combinação Double XP/Intel + extração. |
| B09 | P2 | Rever sobrevivência quando cercado: teto de 25 dano melee por frame, Breaker, Grabbers, sprint, escudo e War Cry. |
| B10 | P2 | Rever progressão entre ilhas: HP é escalado por `1 + 0,3 × island_index`, depois por Threat. Não é multiplicação cumulativa de ×1,3 por ilha. |
| B11 | P2 | Validar Rescue sem auxílio do bot: caminho do sobrevivente, defesa, leitura da sua vida e penalização. A morte do sobrevivente com penalização de Intel e continuação da missão é comportamento existente, não falha automática da run. |
| B12 | P2 | Afinar os custos de armas/classes/perks/slots e o ritmo de desbloqueio. Confirmar que Threat e rotas difíceis compensam o risco depois de corrigir G01. |

Valores atuais dos power-ups, em [game_data.gd](../../game/data/game_data.gd):
1,5% por abate normal, 5% por especial, garantia após 60 abates, intervalo
mínimo 35 s, item no chão 25 s, aviso intermitente nos últimos 10 s.

| Power-up atual | Efeito implementado | O que precisa de atenção |
|---|---|---|
| Insta-Kill | Tiros diretos matam qualquer inimigo, incluindo boss, durante 25 s. | Medir impacto no boss e na dificuldade; não prometer que todos os efeitos secundários passam a matar instantaneamente. |
| Double XP / Intel | Duplica recompensas durante 25 s. | Medir economia e garantir que o jogador percebe o benefício. |
| Nuke | Mata todos os inimigos vivos da ilha, incluindo boss; atrasa spawns 5 s; não gera novos drops nem explosões de Bloater contra o jogador. | Medir frequência e utilidade; feedback visual deve comunicar o alcance global. |
| Full Power | Repõe Breaker e habilidade. | Definir o que acontece quando ambos já estão prontos. |
| Max Shield | Enche o escudo até 100. | Definir utilidade com escudo cheio. |
| Extra Reroll | +1 reroll, máximo três. | Reproduzido: com três, continua com três mas a recolha é registada. *(Resolvido a 2026-10-14: 1 reroll por ecrã de level-up; o Extra Reroll dá +1 no ecrã seguinte, sem reserva.)* |
| Max Ammo | Enche munição das armas finitas desbloqueadas. | Já é filtrado quando não há arma finita; falta decidir o caso de reservas cheias. |

**Recarga:** o carregador de 30 da AR está implementado; a reposição é
instantânea (`RELOAD_SECONDS = 0`). Uma recarga com duração, animação e som
é uma alteração futura a decidir. As restantes armas ainda disparam da
reserva e não têm sistema completo de carregadores.

## 5. Modelos, animações e efeitos

### A01 — P2 — Preparar os modelos necessários

O inventário atual para escolher assets é este; não comprar/preparar modelos
para classes ou armas que só existem em propostas antigas.

| Grupo | Modelos necessários | Estado / cuidados |
|---|---|---|
| Jogadores | Recruit, Vanguard | `SoldierModel` em primitivas; rig partilhável com variantes de roupa/equipamento e silhueta legível. |
| NPC | Sobrevivente | Modelo provisório; deve distinguir-se da horda e mostrar movimento, ferimento e morte. |
| Rádio | Director Hale | Texto/rádio existente. Retrato ou voz é opcional; não exige um NPC 3D por agora. |
| Armas | Assault Rifle, Shotgun, Heavy Pistol, SMG, Marksman Rifle | Modelos em mão e de primeira pessoa; alinhar pega, cano, flash e escala. |
| Horda comum | Walker, Runner | Silhueta, velocidade e animação diferentes; bom ponto de partida para validar o pipeline. |
| Especiais | Brute, Grabber, Bloater, Screamer | Armadura frontal, braços de agarrar, volume de explosão e leitura de alerta reconhecíveis. |
| Boss | Behemoth | Escala própria, golpe no chão, lançamento de rocha, invocação e fase 2 legíveis. |
| Objetos | Granada, geradores, antena, caixas, barco, cais e rochas do boss | Vários ainda são primitivas; não precisam todos de rig ou animação esquelética. |

- [ ] Definir estilo, escala em metros, orientação, pivô, material e limites
  de custo antes de integrar um pack completo.
- [ ] Integrar primeiro uma personagem, uma arma e um Walker; confirmar
  todas as câmaras e custo com 150 inimigos antes de expandir variantes.
- [ ] Reutilizar os modelos no jogo, Armory e primeira pessoa conforme o
  contexto; evitar versões visuais que indiquem hitboxes diferentes.
- [ ] Registar origem/licença de novos assets em `assets/LICENSES.md`.

### A02 — P2 — Animação de personagens e zombies

- [ ] Jogador: idle, andar, correr, sprint, Breaker, habilidade, ferimento e
  morte; recarga só quando a mecânica estiver decidida.
- [ ] Sobrevivente: deslocação/espera, reação e morte.
- [ ] Horda: andar/correr, ataque, agarre, stun, congelamento e morte;
  comportamentos específicos do Bloater, Screamer e Behemoth.
- [ ] Escolher e provar o pipeline VAT para a horda, ou outra solução
  medida que conserve a arquitetura de dados + MultiMesh.
- [ ] Sincronizar estados visuais com o dano e os avisos da simulação;
  impedir que a animação sugira um ataque diferente do que realmente acerta.
- [ ] Adaptar o desmembramento simples aos modelos finais, sem perder a
  leitura de headshots e sem criar uma cena pesada por inimigo.

A Universal Animation Library já está descarregada. Isso não significa
que exista um rig compatível ou uma integração de animação no jogo.
O balançar atual de cabeça/braços não é uma pipeline VAT concluída.
Evidência: [island.gd](../../game/world/island.gd),
[soldier_model.gd](../../game/world/soldier_model.gd),
[view_model.gd](../../game/world/view_model.gd), [LICENSES.md](../../assets/LICENSES.md).

### A03 — P3 — Afinar efeitos e leitura do combate

- [ ] Distinguir melhor fogo, frio, veneno, descarga e duos em hordas densas.
- [ ] Rever contraste de avisos de boss, dano recebido, Grabber e Screamer
  sobre cada bioma e hora do dia.
- [ ] Afinar recoil, flashes, impacto e áudio por arma com os modelos finais.
- [ ] Validar o Nuke global e a quebra de escudo sem saturar o ecrã.

Partículas, números de dano, aviso direcional e desmembramento já existem;
o pendente é acabamento e desempenho, não criar esses sistemas do zero.

## 6. Ilhas, cenários e missões

| ID | Prioridade | Trabalho por terminar |
|---|---|---|
| M01 | P2 | Volcano: dar ao boss uma arena e cenário final próprios. Atualmente há bioma/lava/boss jogáveis, mas não existe `volcano_01.tscn` feita à mão como nos outros quatro biomas. |
| M02 | P2 | Berlenga: substituir o farol em caixa e preparar o modelo do forte; acabar landmarks, cais e identidade visual local. A missão do forte já existe. |
| M03 | P2 | Jogar e testar as quatro partes reais da Berlenga de ponta a ponta: limites, caminhos, rampas, pontes, geradores, sobrevivente, caches, saídas e chegada do barco. |
| M04 | P2 | Rever distribuição de spawns nas partes estreitas e junto a paredes, costa e gargalos; a correção por setores já existe, mas falta uma avaliação jogada de pressão/variedade. |
| M05 | P3 | Corrigir copas de árvores que sobrepõem estradas/telhados. A colocação atual avalia principalmente o tronco. |
| M06 | P3 | Esconder serrilhado das falésias/rampas de grelha com modelos de rocha e materiais adequados, mantendo colisão e acessibilidade. |
| M07 | P3 | Afinar luz, nevoeiro, silhuetas e pontos de orientação em Beach, Town, Jungle, Port/Hashima e Volcano. |

Não regenerar automaticamente cenas do utilizador para cumprir esta lista.
Outras ilhas reais de selva/cidade/vulcão exigem escolha e aprovação do
utilizador, como indica [MAPS_HANDOFF.md](MAPS_HANDOFF.md).

## 7. Menus, HUD, comando e acessibilidade

| ID | Prioridade | Trabalho / critério de conclusão |
|---|---|---|
| U01 | P2 | Fazer uma **maqueta para aprovação** do painel `ISLAND CLEARED` / `PART CLEARED`, conforme o handoff. É o ecrã que ainda destoa claramente do tema. Mostrar resultado da etapa, Intel, progressão e uma continuação com foco/entrada protegida. |
| U02 | P2 | Corrigir a pré-visualização do acampamento da Berlenga: usa uma vista genérica de Beach com palmeiras. Mostrar a paisagem correspondente à parte, sem alterar o bioma da missão apenas para mudar a imagem. |
| U03 | P2 | Clarificar estatísticas do fim de ilha: atualmente Kills/Headshots vêm dos totais acumulados da run. Distinguir “nesta etapa” de “na run” ao renovar o painel. |
| U04 | P2 | Completar o remapeamento: Settings oferece Weapon 1–3, mas não Weapon 4–5. Rever também next weapon e reroll para que todos os controlos relevantes estejam documentados/configuráveis. |
| U05 | P2 | Acrescentar sensibilidade do stick direito e zonas mortas configuráveis. A sensibilidade do rato e o remapeamento teclado/rato já existem. |
| U06 | P2 | Validar um comando físico: sticks, menus, foco, scroll, ícones, troca teclado/comando, desconexão/reconexão e utilização quando o comando ativo não é o dispositivo 0. A mira lê atualmente o dispositivo 0. |
| U07 | P2 | Validar 1280×720, 1920×1080, ultrawide e 4K, modos de janela e HUD 60–100%; garantir texto legível, sem cortes e scroll acessível. Esta auditoria confirmou 1600×900. |
| U08 | P3 | Afinar legibilidade do HUD em sol, nevoeiro, lava e multidões; rever dimensões de números, legenda do minimapa e quantidade de mensagens simultâneas. |
| U09 | P3 | Rever sinais sem depender apenas da cor: estados elementais, objetivo concluído, rota difícil, shield/HP e alvo de headshot. |
| U10 | P3 | Decidir opções para reduzir flashes, shake e intensidade de efeitos, se os playtests mostrarem essa necessidade. |
| U11 | Opcional | Título com ilha realmente animada em 3D e barco mais imersivo: o título atual usa arte de fundo. A aproximação ao conceito inicial pode ser feita depois de estabilizar os modelos/cenários. |

Pausa, derrota e debrief já foram reformulados. **Controls já foi retirado
da pausa**; não repetir essa tarefa. Foco, bloqueios de entrada e confirmação
de abandono já têm implementação e testes.
Evidência: [hud.gd](../../game/ui/hud.gd), [menu_dialog.gd](../../game/ui/menu_dialog.gd),
[game_input.gd](../../game/core/game_input.gd), [profile.gd](../../game/core/profile.gd),
[camp.gd](../../game/states/camp.gd), [CODEX_HANDOFF.md](CODEX_HANDOFF.md).

## 8. Som e história

- [ ] **S01 / P2:** avaliar áudio a ouvido durante runs: equilíbrio entre
  armas, dano, rádio, especiais, UI e música; verificar clipping e fadiga.
- [ ] **S02 / P2:** integrar sons apropriados de AR, SMG e Shotgun. O pack
  Ovani existente não cobre esses disparos; os sons atuais são sintetizados.
- [ ] **S03 / P3:** reforçar pistas dos especiais e boss, distância/direção,
  escudo, pickups e mudanças do diretor. Não duplicar a música adaptativa,
  que já está implementada.
- [ ] **H01 / P2:** validar recuperação dos dez ficheiros, arquivo, primeira
  apresentação do final e persistência da escolha num perfil normal.
- [ ] **H02 / opcional:** vozes de Hale/sobrevivente e retrato de rádio.
- [ ] **H03 / expansão planeada:** decidir o âmbito da ilha **Origin jogável**
  depois do final. Faltam mapa, missão, encontro final e integração dessa
  expansão; a conversa final Origin já funciona no debrief.

Referências: [sfx.gd](../../game/audio/sfx.gd), [music.gd](../../game/audio/music.gd),
[story.gd](../../game/data/story.gd), [origin_ending.gd](../../game/data/origin_ending.gd).

## 9. Desempenho, robustez e distribuição

| ID | Prioridade | Trabalho / critério de conclusão |
|---|---|---|
| T02 | P1 | Medir o jogo completo na RTX 5060: 150 vivos, máximos efetivos depois de G01, boss, builds com elementos/duos e efeitos; comparar câmaras e presets. Registar frame time médio/p95/pior, simulação, draw calls, memória e condições. |
| T03 | P1 | Validar FPS e tempos de entrada/transição nas quatro partes reais da Berlenga e em Hashima. Reproduzir picos antigos antes de atribuir causa ou otimizar. |
| T04 | P1 antes de distribuir | Tornar a gravação do perfil resistente a interrupções: ficheiro temporário/substituição, cópia de recuperação, validação dos campos e aviso quando guardar falha. O `save()` atual escreve diretamente no ficheiro final. Não foi observada perda de um perfil real. |
| T05 | P2 | Distinguir perfil inexistente de perfil ilegível e conservar uma cópia do ficheiro danificado. Hoje JSON inválido resulta num perfil novo; uma gravação posterior pode sobrescrever o ficheiro anterior. |
| T06 | P2 | Melhorar telemetria para playtests: seed da run/ilha, revisão/versão, utilização de armas, XP e nível por etapa, recolhas e causa de morte. Atualmente já há JSON de resultados por run, mas faltam dados para reproduzir e comparar builds. |
| T07 | P2 | Rever unicidade dos nomes de logs e tratamento de falhas de escrita. A telemetria usa data/hora até ao segundo e retorna silenciosamente quando não consegue abrir o ficheiro. |
| T08 | P2 | Testar repetidas transições título/Armory/ilha/debrief e separar avisos de limpeza de recursos do problema de encerramento da engine/addons. Confirmar que memória não cresce durante a sessão. |
| T09 | P1 antes de distribuir | Preparar e validar export Windows: preset, ícone, versão, recursos incluídos, tamanho e arranque num PC sem editor. Não há `export_presets.cfg` local nesta auditoria e não foi verificado um executável exportado. |
| T10 | P1 antes de distribuir | Criar créditos/atribuições e incluir licenças no pacote, incluindo `© OpenStreetMap contributors` e as fontes de relevo, conforme `assets/LICENSES.md`. Não há ainda um ecrã de créditos integrado. |
| T11 | P2 | Rever addons/demos incluídos na exportação e manter apenas dependências necessárias em runtime; medir tamanho antes de remover qualquer conteúdo. Alguns addons servem apenas o editor ou experiências. |
| T12 | Opcional | Automatizar a suite em CI depois de corrigir T01; não foi encontrada configuração `.github` nesta cópia. |
| T13 | Opcional | Guardar/retomar uma run em curso. O perfil persiste meta/opções, mas o estado ativo vive em memória; isto precisa de especificação própria se passar a ser um requisito. |

O comentário do [bench_island.gd](../../tools/dev/bench_island.gd) anuncia
Threat 3 + Swarm com 240 vivos. Enquanto G01 existir, confirmar a contagem
real do cenário em vez de assumir que esse teste mede 240 inimigos.
Não há evidência nesta auditoria para prometer 60/144 FPS estáveis em combate.

## 10. Documentação que precisa de atualização

- [ ] **D01 / P2:** atualizar [CODEX_HANDOFF.md](CODEX_HANDOFF.md): há estados
  “sem commit” apesar de as alterações já estarem em Git, e a referência
  `9b10cf3` não corresponde ao commit atual da correção de mira/spawns.
  Os commits observados são `7874de1` e `48d0c42`.
- [ ] **D02 / P2:** atualizar [COMBAT_CATALOG.md](COMBAT_CATALOG.md) a partir
  dos recursos atuais e dos efeitos: carregador da AR, nomes/efeitos dos
  power-ups, descrições G03 e fórmulas. Não usar uma proposta como catálogo
  dos stats efetivamente implementados.
- [ ] **D03 / P2:** atualizar a descrição inicial de [CLAUDE.md](../../CLAUDE.md)
  e [game/README.md](../../game/README.md), que ainda apresenta partes do
  projeto como uma slice de uma ilha. Preservar as regras do projeto.
- [ ] **D04 / P2:** marcar nas propostas de cartas/progressão o que foi
  implementado e o que continua apenas em discussão; corrigir a diferença
  entre a curva proposta com `n−1` e a fórmula atual com `n`.
- [ ] **D05 / P2:** consolidar o [TODO.md](../../TODO.md): remover o duplicado
  de VAT, corrigir a fórmula de HP entre ilhas e distinguir conteúdo
  jogável existente de modelos/cenários ainda provisórios.
- [ ] **D06 / P3:** rever [ASSETS.md](ASSETS.md), licenças e handoffs de mapas
  para refletir integrações atuais. Não transformar cada addon instalado
  num requisito de integração.

Documentos históricos, `docs/legacy` e reviews com data são referências,
não listas automáticas de tarefas. Não alterar `docs/DECISIONS.md` para
resolver divergências; propor mudanças ao utilizador.

## 11. Decisões propostas — não implementar sem escolha do utilizador

| Tema | O que falta decidir |
|---|---|
| Loadout | AR fixa + secundária escolhida, principais intercambiáveis, ou continuar com todas as armas desbloqueadas disponíveis. Não remover armas por inferência. |
| SMG | Conservar, especializar ou reformular. O seu papel deve ser avaliado com o catálogo atual, onde muitos procs são exclusivos da AR. |
| Perks | Manter slots atuais ou desenvolver a árvore proposta, respeitando perks equipados. A árvore ainda não é uma tarefa aprovada. |
| Cartas de escudo | Kinetic Barrier, Shield Capacitor e Quick Recharge continuam propostas. O escudo-base já existe. |
| Outras cartas propostas | Deadeye, Critical Mass, Last Stand, Blood Draw e Lucky Find não estão no catálogo atual. Aprovar utilidade e valores antes de criar sistemas novos. |
| Run and Gun | A versão que dispara durante sprint contradiz a decisão fechada de sprint sem disparo; requer alteração explícita dessa decisão. *(Resolvido a 2026-10-14: o sprint dispara para todos; carta retirada.)* |
| Evoluções | Evoluções que transformam armas/cartas não estão implementadas. As três combinações elementais automáticas já estão; são sistemas diferentes. |
| Progressão | Cartas desbloqueadas por Intel, mais classes/armas e planeamento de várias paragens da rota são expansões possíveis, não pendentes obrigatórios. |
| Origin | Expansão jogável e duração/posição na campanha. O final narrativo já existe. |
| Coop | Fora do âmbito single-player atual. Um addon e um documento multiplayer não tornam coop uma funcionalidade prometida. |

## 12. Ordem recomendada para pegar no trabalho

1. **Estabilizar:** G01, G02 e T01; corrigir descrições e incompatibilidades.
2. **Validar o jogo:** playtests B01–B12, campanha real da Berlenga e medições
   de desempenho. Só então ajustar números ou aumentar a densidade.
3. **Fechar a interface pendente:** maqueta U01 para aprovação, imagem U02
   e controlos U04–U07. Preservar os menus que já funcionam.
4. **Melhorar a apresentação:** provar uma personagem/arma/Walker, depois
   expandir modelos, animações, landmarks, Volcano, som e efeitos.
5. **Preparar distribuição:** perfil robusto, export, créditos, testes num
   executável e documentação atualizada. Expansões ficam separadas.

Um item fica concluído com código/conteúdo, teste apropriado e verificação
manual quando necessário. “Teste passa” não aprova equilíbrio ou estética.

## Apêndice — inventário de referência para revisão e assets

Stats abaixo são bases sem cartas/perks/Threat. Dano por ataque não é DPS;
Shotgun tem oito bagos e as armas perfurantes podem atingir vários alvos.
Fonte: registos e defaults de `game/data/resources/`, exportados na auditoria.

| Arma | Dano/projétil | Tiros/s | Alcance | Bagos / alvos por bago | Reserva inicial | Carregador | Custo Intel |
|---|---:|---:|---:|---|---:|---:|---:|
| Assault Rifle | 12 | 9 | 30 m | 1 / 1 | ∞ | 30, reposição instantânea | 0 |
| Shotgun | 9 | 1,4 | 12 m | 8 / 2 | 40 | — | 0 |
| Heavy Pistol | 60 | 2,2 | 35 m | 1 / 4 | 60 | — | 0 |
| SMG | 7 | 16 | 18 m | 1 / 1 | 300 | — | 60 |
| Marksman Rifle | 110 | 1,2 | 45 m | 1 / 6 | 30 | — | 80 |

| Personagem jogável | HP base | Habilidade | Desbloqueio |
|---|---:|---|---:|
| Recruit | 100 | Granada | Grátis |
| Vanguard | 140 | War Cry; Breaker com cooldown −30% | 150 Intel |

| Inimigo | HP base | Velocidade m/s | Dano melee / intervalo | XP | Identidade |
|---|---:|---|---|---:|---|
| Walker | 30 | 1,8–2,6 | 8 / 1 s | 1 | Horda comum |
| Runner | 18 | 4,6–5,4 | 6 / 0,7 s | 1 | Rápido |
| Brute | 260 | 1,6–1,9 | 25 / 1,6 s | 6 | Armadura frontal: redução de 75% |
| Grabber | 70 | 2,8–3,2 | 4 / 0,5 s | 3 | Agarra; Breaker solta |
| Bloater | 90 | 1,3–1,5 | 10 / 1,2 s | 3 | Explode ao morrer |
| Screamer | 45 | 3–3,4 | 3 / 1 s | 4 | Afasta-se e chama pico de horda |
| Behemoth | 1800 | 1,7 | 35 / 1,4 s | 40 | Armadura frontal 50%; slam, rochas, invocações e fase 2 |

O HP base do Behemoth não é o HP efetivo da terceira ilha: também recebe
o escalamento por ilha e Threat. Slam, rochas e explosões têm regras próprias.

**39 cartas existentes; número entre parênteses = rank máximo:**

| Categoria | Cartas atuais |
|---|---|
| Assault Rifle — 8 | Hollow Points (5), Fast Hands (5), Ricochet (3), Pop Goes the Head (3), Piercing Rounds (3), Steady Aim (3), Point Blank (3), Finish the Job (3) |
| Elements — 9 | Wind Rounds (5), Fire Rounds (5), Frost Rounds (5), Storm Rounds (5), Toxic Rounds (5), Wildfire (3), Deep Freeze (3), Chain Lightning (3), Toxic Cloud (3) |
| Defense — 1 | Thick Hide (5) |
| Sustain — 4 | Field Medic (5), Kill Rations (5), Field Dressing (5), Catch Your Breath (3) |
| Utility — 5 | XP Magnet (5), Bigger Mags (5), Fast Learner (5), Light Boots (5), Second Breath (3) |
| Breaker — 6 | Hair Trigger (5), Shockwave Breaker (5), Adrenaline (3), Executioner (5), Aftershock (3), Crowd Splitter (3) |
| Recruit — 3 | Grenadier (5), Wide Blast (3), Concussion (3) |
| Vanguard — 3 | Rally (5), Intimidation (3), Battle Rhythm (3) |

Combinações automáticas existentes: **Thermal Shock, Conductive Frost,
Toxic Combustion**. Não ocupam três cartas adicionais no catálogo.

Perks atuais: **Thick Skin, Pack Rat, Head Hunter, Battering Ram,
Demolitions**. Modificadores atuais: **Calm, Swarm, Elite Pack, Sea Fog,
Supply Shortage**. Estes inventários não incluem funcionalidades propostas.
