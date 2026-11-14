---
titulo: "Fontes e divergências"
tipo: "nota"
estado: "consulta"
atualizado: "2026-11-14"
tags: ["horde-breaker"]
fontes: ["docs/DECISIONS.md", "game/README.md", "docs/tech/COMBAT_CATALOG.md", "game/data/resources/perk_data.gd", "game/data/game_data.gd", "tests/run_all.gd"]
---

# Fontes e divergências

## Como resolver dúvidas

1. Para decisões aprovadas, ler [[90 Referências/docs/DECISIONS|DECISIONS]] e as datas de substituição.
2. Para valores configurados, ler fichas em [[02 Conteúdo/Conteúdo]], os `.tres` e os defaults dos Resources.
3. Para comportamento, conferir a simulação e os testes; a descrição de uma carta pode estar desatualizada.
4. Para trabalho ativo, usar [[90 Referências/TODO|TODO]]. Os relatórios não são backlogs.
5. Para intenção e história, consultar design, propostas e arquivo com o respetivo contexto.

## Divergências observadas

| Fonte | Problema de leitura | Tratamento no cofre |
|---|---|---|
| `game/README.md` | O início diz 9 missões; há 11 Resources | Catálogo calculado dos recursos; referência preservada com aviso |
| `docs/tech/COMBAT_CATALOG.md` | Cabeçalho diz 7 inimigos e árvore de 9 nós/20 alternativas | Fichas mostram 8 inimigos e 26 Resources de perks; não confundir alternativas com nós |
| `perk_data.gd` | Comentário inicial fala em três ramos | `game_data.gd` declara quatro: combat, survival, breaker, logistics |
| `docs/tech/ARCHITECTURE.md` | Apresenta-se como proposta de pré-produção | Mapa do código descreve ficheiros observados; não promove a proposta a arquitetura implementada |
| Documentos de menus | Preservam Atlântico/azulejo e abrigo 3D | Decisões de novembro prevalecem nos menus fora da ilha |
| Relatórios antigos de testes | Podem mencionar crashes tolerados | Regra atual exige exit 0 e resultado, salvo whitelist explícita do runner |

Não foi determinada a atualidade de cada documento pelo histórico Git. As cópias são snapshots, não certificações de que o texto coincide com toda a implementação.

Fontes: [[90 Referências/docs/DECISIONS|DECISIONS]] · [[90 Referências/game/README|README]] · [[90 Referências/docs/tech/COMBAT_CATALOG|COMBAT_CATALOG]] · [[90 Referências/docs/tech/ARCHITECTURE|ARCHITECTURE]].
