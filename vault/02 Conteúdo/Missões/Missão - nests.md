---
titulo: "Missão — Nests"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "missions"]
fontes: ["game/data/missions/nests.tres", "game/data/resources/mission_data.gd"]
---

# Missão — Nests

← [[02 Conteúdo/Missões|Missões]]

Destroy three horde nests, then get out.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `nests` · **Nome no jogo:** Nests

| Campo | Valor | Origem |
|---|---|---|
| Disponível nas rotas | Sim | Por defeito no Resource |
| Quantidade de pontos | 3 | `.tres` |
| radius | 1.4 | `.tres` |
| spike_seconds | 12.0 | `.tres` |
| nest_hp | 600.0 | `.tres` |
| spawn_interval | 7.0 | `.tres` |
| spawn_count | 2 | `.tres` |
| brood_cap | 6 | `.tres` |
| wake_range | 45.0 | `.tres` |
| priority_range | 8.0 | `.tres` |
| Biomas preferidos | Array[StringName]([&"jungle", &"volcano"]) | `.tres` |
| Peso nos biomas preferidos | 3 | `.tres` |

## Fontes

- `game/data/missions/nests.tres`
- `game/data/resources/mission_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
