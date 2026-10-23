# Análise do jogo — 23 de outubro de 2026

Estado do código em `master` (commit `60eb957`, com as alterações desta análise
por commitar). O que se mediu aqui é o que o bot faz com as regras reais do
jogo. Não é equilíbrio nem dificuldade: são humanos que dizem isso.

## Resumo

- **Completabilidade:** o bot completa as seis ilhas em duas runs de três ilhas
  (sementes 101 e 202), incluindo o Volcano feito à mão, com o boss morto nas duas.
- **Telemetria:** os disparos por arma e o XP por ilha batem com a fórmula real
  de XP (ver abaixo), e as cinco armas aparecem em runs completas.
- **Ritmo (a medir com humanos):** as runs do bot demoram 5 a 7 minutos de
  simulação, contra o alvo de 20 a 30 minutos da auditoria (B01). O bot não
  morre e navega sem erros; por isso isto não diz nada sobre dificuldade, mas a
  diferença é grande demais para ignorar.
- **Correções de documentação:** a fórmula do XP na auditoria estava sem o fator
  10 (B07). T06, T07, T10, U04 e U05 foram atualizados com o estado verificado.
- **Decisões que continuam tuas:** o alvo de duração (B01), as recompensas sem
  benefício (B03 e B04), a contagem de missões no `CLAUDE.md`, as propostas de
  menus 6 a 10 e a direção do Volcano e das Salinas.

## Como se mediu

`tests/test_soak_run.gd`: um bot joga uma run de três ilhas, com as regras reais,
por duas sementes. Escolhe as ilhas como o jogo (`HandmadeIsland.pick`), por isso
o Volcano feito à mão entra em todas as runs.

Limites que mudam a leitura:
- **O bot é invencível** (HP 10 000). Mede se a run se completa e quanto tempo
  demora sem mortes; não mede dano nem dificuldade.
- **O bot dispara sempre que tem alvo.** A SMG aparece com volumes de tiro que
  um jogador não faz.
- **A carga muda entre ilhas** (três pares, primeira arma principal, segunda
  secundária). Trocar de arma a cada 15 s é um padrão do bot, não de um jogador.
- **Duas sementes** são pouco para qualquer média.

## Resultados (carga válida, 2026-10-23)

Estes números são de uma execução de 2026-10-23 (saída do `test_soak_run` e das
capturas da sessão). Repetem-se com a mesma semente e o mesmo código.

Semente 101:

| Ilha | Bioma | Missão | Modificador | Tempo | Abates | Nível (acumulado) | Disparos | XP na ilha | Boss |
|---|---|---|---|---|---|---|---|---|---|
| 1 | jungle | rescue | swarm | 60 s | 47 | 2 | escopeta 23, metralhadora 111 | 211 | — |
| 2 | port | activate | elite | 119 s | 98 | 3 | escopeta 39, carabina 246 | 471 | — |
| 3 | volcano | defend | fog | 258 s | 1 147 | 14 | SMG 1 933, carabina de precisão 60 | 14 533 | morto |

Semente 202:

| Ilha | Bioma | Missão | Modificador | Tempo | Abates | Nível (acumulado) | Disparos | XP na ilha | Boss |
|---|---|---|---|---|---|---|---|---|---|
| 1 | beach | defend | elite | 124 s | 350 | 9 | SMG 445, carabina de precisão 30 | 4 844 | — |
| 2 | town | rescue | fog | 65 s | 98 | 9 | metralhadora 270 | 261 | — |
| 3 | volcano | activate | short | 129 s | 326 | 11 | carabina 556, escopeta 30 | 2 985 | morto |

Duração total de cada run: 437 s na semente 101 e 318 s na semente 202.

## Verificação do XP

A fórmula real está em `GameData.xp_for_level`: `10 × (8 + 6n + n²)`. Para subir do
nível 1 ao nível `L` é preciso acumular a soma dos níveis anteriores:

| Nível atingido | XP acumulado necessário | XP acumulado no bot | Resultado |
|---|---|---|---|
| 9 (semente 202, após a ilha 1) | 4 840 | 4 844 | consistente |
| 11 (semente 202, fim da run) | 7 950 | 8 090 | consistente |
| 14 (semente 101, fim da run) | 14 690 | 15 215 | consistente |

O XP por ilha (`xp_earned`) é o XP recolhido, antes de qualquer subida de nível
gastá-lo. Por isso a soma das ilhas dá o XP acumulado da run.

## Leitura dos resultados

1. **Completabilidade: sem problemas.** Seis ilhas completadas em duas runs de
   três ilhas, e dois bosses mortos no Volcano feito à mão. O Volcano funciona de ponta a ponta,
   incluindo a lava e o boss, nos dois sentidos da run.
2. **Ritmo: a medir.** O bot demora 5 a 7 minutos por run. O alvo da auditoria
   (B01) é de 20 a 30 minutos para um jogador. Se os humanos forem três a quatro
   vezes mais lentos, o alvo fica no sítio; se não, ajusta-se a duração das
   missões ou o número de ilhas. Isto só se decide com playtests.
3. **Progressão: não concluir ainda.** O nível 14 na semente 101 vem de 1 147
   abates no Volcano, com o modificador de nevoeiro e a horda em massa. Um jogador
   matará muito menos, e o XP por ilha será muito menor. A curva está correta;
   a quantidade de XP que um humano recolhe é que precisa de dados.
4. **Armas: volume não é equilíbrio.** A SMG dispara 1 933 vezes no Volcano porque
   o bot dispara sempre que tem alvo. Não se deve reduzir a SMG por isto. A
   medição de equilíbrio por arma (B05) precisa de humanos.
5. **Lava: confirmada no jogo.** Numa captura dentro do jogo (`tools/dev/screenshot_ingame.gd`,
   com o jogador a norte da primeira poça), as poças aparecem como faixas laranja
   no solo. Vistas de longe, os discos finos de 8 cm lêem-se como linhas. É uma
   questão de arte (brilho ou borda), não de lógica.

## Problemas encontrados e estado

**Corrigido nesta análise (código):**
- `tests/test_soak_run.gd`: o bot usava sempre a carga por omissão, só com carabina
  e escopeta, e a metralhadora nunca disparava. Agora cada ilha tem uma carga
  diferente, com a arma principal primeiro (o jogo recusa duas principais).
- `tests/test_soak_run.gd`: o relatório passa a mostrar disparos por arma e XP por ilha.
- `tools/dev/screenshot_ingame.gd`: a ferramenta punha a posição antes de a ilha
  estar pronta, e o `noclip` falhava (`run` ainda era nulo). Agora as duas coisas
  acontecem no frame 5.

**Corrigido nesta análise (documentação, `docs/tech/GAME_AUDIT.md`):**
- B07: a fórmula do XP tem o fator 10. Chegar do nível 1 ao 30 exige 113 970 XP.
- T06: telemetria de disparos e XP por ilha feita; falta a seed da ilha no registo.
- T07: o nome dos registos tem milissegundos e a falha de escrita gera aviso.
- T10: créditos integrados; as licenças entram no pacote pelo preset.
- U04: não é requisito (o loadout usa as teclas 1 e 2).
- U05: sensibilidade e zona morta do stick já estão nas definições.

**Por resolver, sem decisão tua:**
- `GameData.loadout` (`game/data/game_data.gd`, linhas 489–495) guarda a última
  arma principal que recebe e repõe a escopeta por omissão se faltar a secundária.
  Uma carga com duas principais perde a primeira em silêncio. O carregamento do
  perfil já valida as categorias dos dois slots (`game/core/profile.gd`, linhas
  180–189), por isso o caso não chega ao jogo. Só afeta chamadas erradas, como as
  do bot antes de esta correção. Não alterei o comportamento.
- `T01` (`tests/run_all.gd`): `classify()` aceita quatro códigos de crash no
  encerramento (5, 139, −1073741819 e 3221225477) desde que o log tenha uma linha
  `TEST: ` e nenhuma marca de falha. Na suite de hoje, os 74 testes saíram com
  código 0, por isso o caso não se observou. A regra continua permissiva, e a
  auditoria mantém o item aberto.
- A exportação foi validada a 2026-10-18 (`tools/export/README.md`). Antes de
  distribuir, convém repeti-la: entraram o Volcano feito à mão, a lava e a telemetria.
- A lava é desenhada com discos finos, e aparece como linha de longe (ver resultado 5).

**Decisões tuas:**
- **Duração alvo (B01):** 20–30 minutos mantém-se, ou ajusta-se depois do playtest?
- **Missões no `CLAUDE.md`:** o ficheiro diz 9 missões, mas o código tem 11 recursos
  de missão. Dez estão nas rotas do arquipélago, e a Holdout fica só na Berlenga.
  Não alterei o `CLAUDE.md`, porque é o ficheiro de instruções do projeto.
- **Volcano feito à mão:** aprovas o desenho, com o relevo baixo (cerca de 34 m) e sem
  landmarks? O mapa tem 17 obstáculos (edifícios e rochas), depois de nivelar as
  poças; antes eram 19.
- **Salinas:** o mapa existe no Blender (`tools/art/maps/salinas_island.blend`). Queres
  integrá-lo no jogo, e com que direção visual?
- **Propostas de menus 6 a 10:** ainda sem decisão (título, arquivo, leitura,
  texto nas perks, âmbar).
- **Ilhéu das Rolas:** continua sem nota no repositório. É mesmo a próxima ilha?

**Por fazer, com trabalho próprio:**
- **Berlenga, ilhotas e rochedos como decoração** (`docs/tech/` e notas de
  2026-10-08): não está implementado. Mexe nas cenas geradas da Berlenga, pelo que
  segue o processo de subagentes com revisão do Codex.
- **Poses do Bloater e do Behemoth em fúria:** trabalho de arte com o Codex, que
  precisa de aprovação.
- **M05 (copas das árvores), M06 (serrilhado das falésias), M07 (luz):** não
  resolvidos por código sozinho. M05 só afeta builds futuros, porque a auditoria
  proíbe regenerar cenas existentes.
- **D01, D02, D04 e D06 da auditoria:** documentos históricos ou catálogos longos.

## Próximos passos sugeridos

1. Playtest com humanos (B01): três a cinco runs por classe, com a telemetria
   nova (`user://runs/`). Comparar com o bot, sem tirar conclusões de duas sementes.
2. Decidir a contagem de missões no `CLAUDE.md` e a duração alvo.
3. Repetir a exportação e o arranque do executável antes de distribuir (T09).
4. Decidir o Volcano e as Salinas, e só depois integrar.
5. Berlenga, ilhotas e rochedos, quando quiseres avançar com esse trabalho.
