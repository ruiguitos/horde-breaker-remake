---
titulo: "docs/history/2026-11-14_ASSETS2GODOT_HANDOFF.md"
tipo: "referencia"
estado: "relatorio_historico"
atualizado: "2026-11-14"
tags: ["horde-breaker", "referencia"]
fontes: ["docs/history/2026-11-14_ASSETS2GODOT_HANDOFF.md"]
---

# docs/history/2026-11-14_ASSETS2GODOT_HANDOFF.md

> [!warning] Cópia de consulta
> Esta é uma cópia de consulta. A fonte continua no repositório; mudanças nesta cópia não alteram o original. Arquivo: não usar como lista de trabalho atual.

Fonte: `docs/history/2026-11-14_ASSETS2GODOT_HANDOFF.md` · SHA-256: `8a4e3d266ec3e31ba79589f872410c67109daabc566c6a26bddccccbe52e0730`

# Assets2Godot — integração de 2026-11-14

## Pedido e decisão do utilizador

O utilizador pediu avaliação e integração do Assets2Godot (Asset Library 5603)
e respondeu **«sim»** à exceção GPLv2 para o addon como ferramenta do editor.
Esta exceção não autoriza outras licenças de assets nem o cliente BlendKit.
Codex não editou `docs/DECISIONS.md`, conforme `AGENTS.md`.

## Entrega

Instalado o pacote oficial sem executáveis da versão 0.8.2, com origem,
commit e checksum em `addons/assets2godot/PROJECT_INTEGRATION.md`. O cliente
auxiliar exige uma permissão booleana do projeto, atualmente falsa, além
da preferência do editor. BlendKit fica oculto e a inicialização da UI é
omitida em headless. Os dois fornecedores CC0 começam em 1K.

Corrigido o conflito entre o enum `State` do addon e a classe global do
controlador existente, usando `ClientState`; corrigida a consulta a uma fonte
inexistente no Godot 4.7. As marcas BlendKit substituídas não são distribuídas;
os dois ícones substitutos são originais CC0. Os avisos GPL e de marcas dos
fornecedores ficam preservados.

O preset Windows exclui a ferramenta e a cache. A cache é ignorada pelo Git.
Não foram alteradas regras, cenas ou modelos do jogo, nem foi feito commit.

## Evidência e limites

Guia técnico, verificações e limitações: `docs/tech/ASSETS2GODOT.md`.
O ensaio isolado descarregou e importou um modelo e um material Poly Haven
a 1K. O teste de um PCK mínimo confirmou a exclusão recursiva da ferramenta
e da cache. Não substitui uma exportação completa nem aprovação visual.

Resultado da bateria completa: **88/88 passaram**, saída 0, em 1 507 902 ms
(25 min 8 s), Godot 4.7.2 Windows. Não foram alteradas as regras de aprovação
do runner nem adicionadas exceções de crash. Os ensaios de política,
carregamento dos assets e exclusão do PCK também terminaram com saída 0.

As respostas JEV estão em `vault/99 Ferramentas/JEV/04_integracao_assets2godot_revisao.json`
e `05_integracao_assets2godot_gate.json`. O segundo parecer confirmou as duas
afirmações verificadas, mas manteve a revisão em `escalate`; é consultivo.
Erros observados no compositor do projeto completo e avisos de limpeza ao
sair do editor estão descritos no guia, sem atribuir uma causa não comprovada.

## Texto para passar ao Claude

> Lê AGENTS.md e CLAUDE.md, depois docs/tech/ASSETS2GODOT.md e este relatório.
> O Assets2Godot 0.8.2 já está integrado; não voltes a instalá-lo por cima das
> adaptações locais. O utilizador aceitou explicitamente GPLv2 para esta
> ferramenta do editor a 2026-11-14. Como agente principal autorizado, regista
> essa decisão em docs/DECISIONS.md, mantendo o âmbito: editor apenas,
> excluído da exportação, sem autorização geral para outras licenças.
> Preserva a política que bloqueia o cliente auxiliar e BlendKit, o guard de
> headless, ClientState, os ícones originais e os filtros de exportação.
> Consulta os resultados finais no guia antes de declarar os testes passados.
> Não confundas os dois assets do ensaio isolado com conteúdo integrado nas
> ilhas. Os ficheiros não relacionados da arena e do vault já existiam antes
> desta integração; não os incluas num commit do addon sem rever o âmbito.

## Comandos sugeridos — não executados

Estes comandos incluem apenas a integração do addon. O vault e os modelos da
arena continuam separados, para não incluir ficheiros pessoais ou trabalho
anterior sem revisão.

```powershell
git add -- .gitignore CLAUDE.md project.godot export_presets.cfg assets/LICENSES.md addons/assets2godot/ docs/tech/ASSETS2GODOT.md docs/history/2026-11-14_ASSETS2GODOT_HANDOFF.md tests/test_assets2godot.gd tests/test_assets2godot.gd.uid
git diff --cached --stat
git commit -m "feat(editor): integrate Assets2Godot with CC0 providers"
```
