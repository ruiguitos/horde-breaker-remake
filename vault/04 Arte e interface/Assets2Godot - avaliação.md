---
titulo: "Assets2Godot — avaliação"
tipo: "avaliacao"
estado: "integrado_testado"
atualizado: "2026-11-14"
tags: ["horde-breaker", "assets", "ferramentas"]
---

# Assets2Godot — avaliação

Relacionado: [[04 Arte e interface/Arte e interface]] · [[04 Arte e interface/Assets e licenças]] · [[05 Desenvolvimento/Ferramentas e plugins]].

## Estado atual — 2026-11-14

O utilizador aceitou a exceção GPLv2 para a ferramenta do editor. A versão
0.8.2 foi instalada, com o cliente auxiliar bloqueado pela configuração do
projeto e excluída da exportação. Guia e evidência atualizados em
`docs/tech/ASSETS2GODOT.md`, no repositório.

O ensaio isolado abriu os catálogos Poly Haven e ambientCG e descarregou um
modelo e um material a 1K. Nenhum foi colocado nas ilhas. A bateria completa
passou: **88/88 testes**, saída 0. O parecer JEV sobre a política está em
[[99 Ferramentas/JEV/04_integracao_assets2godot_revisao.json]].
O segundo parecer, com as afirmações verificadas e os limites da revisão,
está em [[99 Ferramentas/JEV/05_integracao_assets2godot_gate.json]].

## Evidência e limites

- A Asset Library apresenta 0.8.2, GPLv2, alpha, Godot 4.4+.
- O README declara testes CI em 4.7.x; isto não comprova compatibilidade com
  este projeto. Blender foi encontrado no caminho de instalação local.
- O addon e os assets descarregados têm licenças distintas. Usar uma ferramenta
  GPL não torna automaticamente todo o trabalho produzido GPL; cópia ou
  distribuição de código da ferramenta exige análise própria.
- A exceção GPLv2 foi aceite pelo utilizador nesta sessão e registada em
  `CLAUDE.md` e na ficha técnica. Codex não altera `docs/DECISIONS.md`.
- O cliente auxiliar está ligado por defeito no código consultado. Ocultar
  o separador BlendKit não o desliga; há uma opção de cliente independente.

## Fluxo recomendado

1. Projeto de apoio separado; fixar a versão e impedir o arranque automático
   do cliente opcional antes de ativar o addon.
2. Começar por Poly Haven/ambientCG CC0, um modelo e um material, texturas de
   1K nos props e até 2K onde se justifique.
3. Conferir materiais, escala, colisão, custo e caminhos. Só copiar os recursos
   escolhidos para `assets/`; confirmar que as cenas não dependem de cache
   ignorada pelo Git. Registar origem/licença antes de integrar.

O addon não substitui otimização, LOD, validação de headless ou medições no
jogo. O parecer JEV é consultivo e está em
`99 Ferramentas/JEV/03_avaliacao_assets2godot.json`.

## Fontes

- [Asset Library — 5603](https://godotengine.org/asset-library/asset/5603)
- [Repositório e README](https://github.com/ikonnow/Assets2Godot)
- [Código do plugin consultado](https://github.com/ikonnow/Assets2Godot/blob/main/addons/assets2godot/plugin.gd)
- [GNU FAQ — ferramentas e resultados](https://www.gnu.org/licenses/gpl-faq.en.html#CanIUseGPLToolsForNF)

Decisão aceite nesta conversa; o registo em `docs/DECISIONS.md` fica para o
agente principal, conforme as regras do projeto.
