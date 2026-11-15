---
titulo: "docs/history/2026-11-14_BEACH_VISUAL_PILOT_HANDOFF.md"
tipo: "referencia"
estado: "relatorio_historico"
atualizado: "2026-11-15"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/history/2026-11-14_BEACH_VISUAL_PILOT_HANDOFF.md"]
---

# docs/history/2026-11-14_BEACH_VISUAL_PILOT_HANDOFF.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original. Arquivo: não usar como lista de trabalho atual.

Fonte: `docs/history/2026-11-14_BEACH_VISUAL_PILOT_HANDOFF.md` · SHA-256: `68bd22b4b10ea427410d9749939255a046cc9f22d9138bde0555be292a6b35e8`

# Entrega — piloto visual beach_01

Data: 2026-11-14. Pedido: Codex e Claude trabalharem juntos, começando pela
`beach_01`, opção escolhida explicitamente pelo utilizador. Sem commit/push.

## Feito

Fachadas nas seis casas, detalhes na torre, materiais PBR nas construções,
ponte, caminhos e rochas existentes. Quatro camadas de terreno, faixa molhada,
erva em lâminas, oito afloramentos costeiros, casco/troncos/rede/postes e árvores
mortas exclusivas do horror. As rochas originais continuam visíveis.
Escada exterior excluída para não sugerir acesso inexistente.

Camada persistente `game/world/handmade/dressing/`, instanciada pela ilha normal.
Autorias em `tools/dev/beach_dressing.gd` e `apply_beach_dressing.gd`;
`build_islands.gd` reaplica-a numa geração futura da praia, exceto no trial RoadGen.
Reaplicar substitui Dressing e a pintura: alterações manuais não são fundidas.
A ilha atual foi atualizada sem regenerar layout ou marcadores.

Dois assets novos CC0 a 1K: Boulder 01 (Rico Cilliers, reduzido para 3 984
triângulos) e Coast Sand 01 (Rob Tuytel), Poly Haven. Manifestos com hashes,
licenças e ferramentas de preparação entregues; sem plugins novos.

Documentação atualizada: `TODO.md`, `game/README.md`, `assets/LICENSES.md`,
`docs/tech/MAP_VISUAL_REWORK.md`, `docs/tech/BEACH_VISUAL_PILOT.md` e nota
Obsidian `04 Arte e interface/Ilhas - melhoria visual.md`.
`docs/DECISIONS.md` não foi editado.

## Colaboração real com Claude

Foram feitas duas consultas pela conta local Claude Code, com ferramentas só
de leitura: planeamento e revisão do patch. Claude não editou nem executou Godot.
Respostas originais em `beach_pilot_20261114/CLAUDE_PLAN.md` e `CLAUDE_REVIEW.md`.
São registos do estado em que foram escritos, não a descrição atual do código.

Correções resultantes da revisão: eliminada a troca de rochas por malhas demasiado
pequenas, reposta visibilidade na reaplicação, sólidos assentes no chão real,
declive calculado a partir do mapa de jogo, materiais persistentes com IDs estáveis,
falhas de autoria propagadas, cache de malhas e caixas individuais para a câmara.
Os testes foram reforçados para verificar estas condições após recarregar a cena.

## Validação efetivamente executada

- Godot 4.7.2: suite completa **89/89**, exit 0, 18 min 18 s.
- Oito testes afetados repetidos com sucesso após as últimas correções do jogo;
  nomes/exit codes em `beach_pilot_20261114/final_targeted.txt` e logs individuais.
- Bloqueio, cobertura, alturas e todos os marcadores iguais à fixture pré-piloto.
  PNGs da grelha antes/depois idênticos byte a byte.
- Reaplicação final exit 0 e **nenhum byte alterado** na ilha, região Terrain3D
  e ficheiros de Dressing. Relatório `authoring_repeat.json`.
- Cópia isolada do gerador em `.scratch`: geração beach exit 0, `problems []`,
  auditoria sem objetos estranhos e rotas alternativas dos três gargalos acessíveis.
  Não se regenerou a ilha atual para testar este caminho.
- Import final exit 0, sem `SCRIPT ERROR`/`Parse Error`; `.uid` criados.
  Os dois DLL Terrain3D continuam presentes e sem alterações.
- Capturas reais Forward+ nas três câmaras e normal/horror, inspecionadas.
  A posição da captura da torre foi afastada da caixa da construção para evitar
  apresentar uma pose de inspeção dentro de células bloqueadas.
- GLB: contagem independente dos índices confirma 3 984 triângulos e SHA-256
  `41b842356d6f9b2551e4e48bae04f8446b032adc01e2480ae8828490d103dca8`.
- Benchmark emparelhado: média antes/depois de 5,91/5,56 ms (1.ª pessoa),
  6,14/5,40 ms (3.ª) e 5,60/5,81 ms (fixa); +45,74 MiB no contador de texturas.
  Valores completos e limites no guia técnico; não demonstram melhoria de FPS.
- `git diff --check` sem erros. Outras ilhas, materiais partilhados e DLLs
  sem alterações. Existem avisos de interpolação e recursos em uso ao encerrar.

JEV: `vault/99 Ferramentas/JEV/07_beach_visual_pilot.json` guarda pedido e resposta
completos. Confirmou claims de grelha/adereços; devolveu `escalate` por confiança
insuficiente e claim de cronologia dos testes sem suporte suficiente nos excertos.
Não é aprovação automática nem substitui os logs locais. Não indicou um defeito
concreto adicional. Esta limitação fica declarada na entrega.

## Falta fazer

Avaliação humana em combate e nos cantos das fachadas/câmara, afinar luz e
legibilidade do horror, vegetação maior, modelos menos geométricos de casas,
farol/barco/pontes e transições costeiras/falésias. As quatro ilhas restantes não
foram renovadas. Não alterar layouts antes de avaliar este piloto com o utilizador.

## Prompt para Claude

```text
Lê CLAUDE.md, AGENTS.md, TODO.md e docs/tech/BEACH_VISUAL_PILOT.md.
O utilizador escolheu beach_01 como piloto visual antes das outras quatro ilhas.
Codex implementou o piloto com a tua consulta de planeamento e revisão de leitura.
Consulta docs/history/2026-11-14_BEACH_VISUAL_PILOT_HANDOFF.md e os logs associados.
Não faças reset, stash, commit ou push nem regeneres a ilha automaticamente.
Há alterações anteriores não relacionadas, incluindo Assets2Godot, arena e vault.
Dressing é gerado por tools/dev/beach_dressing.gd e reaplicado pelo writer; editar
a cena gerada diretamente não sobrevive à reaplicação. Os marcadores, bloqueio,
cobertura e alturas são protegidos por tests/test_beach_dressing.gd e pela fixture.
89/89 testes passaram, seguidos de oito testes afetados. JEV não deu aprovação
automática: vê o JSON 07, os logs locais e os limites de validação descritos.
Próximo passo: avaliar o piloto com o Rui, sobretudo legibilidade horror, modelos
ainda geométricos e vegetação maior. Só avançar para outras ilhas após essa avaliação.
Não edites DECISIONS.md por inferência: apenas decisões explícitas do utilizador.
```

## Git — comandos para o utilizador, não executados

Estes comandos incluem o piloto e a pesquisa visual que o fundamenta. Há outro
trabalho anterior na árvore: addon Assets2Godot, arena, texturas de arma e vault.
Não usar `git add .`. Rever o que já estiver staged antes de prosseguir.
`assets/LICENSES.md` também contém a linha anterior do addon, já autorizada;
o addon e as suas configurações não são incluídos por estes comandos.

Atalho equivalente aos vários `git add` abaixo: rever a lista
`docs/history/beach_pilot_20261114/git_paths.txt` e executar
`git add --pathspec-from-file=docs/history/beach_pilot_20261114/git_paths.txt`.
Rever sempre `git diff --cached --stat` antes de gravar o commit.

```powershell
git status --short
git diff --cached --stat
git add -- TODO.md assets/LICENSES.md game/README.md game/world/beach_vegetation.gd game/world/island.gd game/world/scenery_kit.gd
git add -- game/world/handmade/islands/beach_01.tscn game/world/handmade/islands/beach_01_data/terrain3d_00_00.res game/world/handmade/dressing
git add -- assets/models/polyhaven/boulder_01 tools/assets tools/dev/build_islands.gd tools/dev/apply_beach_dressing.gd tools/dev/apply_beach_dressing.gd.uid tools/dev/beach_dressing.gd tools/dev/beach_dressing.gd.uid tools/dev/beach_visual_review.gd tools/dev/beach_visual_review.gd.uid
git add -- tests/test_beach_dressing.gd tests/test_beach_dressing.gd.uid tests/fixtures/beach_visual_baseline.json
git add -- docs/tech/BEACH_VISUAL_PILOT.md docs/tech/MAP_VISUAL_REWORK.md docs/history/2026-11-14_BEACH_VISUAL_PILOT_HANDOFF.md docs/history/beach_pilot_20261114 docs/design/beach_pilot_20261114
git diff --cached --check
git diff --cached --stat
git commit -m "feat(world): add beach visual pilot with PBR scenery"
git pull --rebase origin master
git push origin master
```

Antes do pull, resolver o restante trabalho local se o Git o exigir; não usar
stash ou descartar ficheiros para contornar isso. As notas Obsidian e o relatório
JEV estão fora deste conjunto para não incluir a configuração pessoal do vault.
