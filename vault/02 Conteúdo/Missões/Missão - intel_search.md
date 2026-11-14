---
titulo: "Missão — Intel Search"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "missions"]
fontes: ["game/data/missions/intel_search.tres", "game/data/resources/mission_data.gd"]
---

# Missão — Intel Search

← [[02 Conteúdo/Missões|Missões]]

Search the marked spots for intel before time runs out, transmit it, then get out.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `intel_search` · **Nome no jogo:** Intel Search

| Campo | Valor | Origem |
|---|---|---|
| Disponível nas rotas | Sim | Por defeito no Resource |
| Quantidade de pontos | 3 | `.tres` |
| Segundos por ponto | 4.0 | `.tres` |
| radius | 2.5 | `.tres` |
| spike_seconds | 8.0 | `.tres` |
| search_spots | 5 | `.tres` |
| time_limit | 120.0 | `.tres` |
| transmit_seconds | 15.0 | `.tres` |
| transmit_radius | 5.0 | `.tres` |
| intel_reward | 15 | `.tres` |
| Biomas preferidos | Array[StringName]([&"town"]) | `.tres` |
| Peso nos biomas preferidos | 3 | `.tres` |

## Fontes

- `game/data/missions/intel_search.tres`
- `game/data/resources/mission_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
