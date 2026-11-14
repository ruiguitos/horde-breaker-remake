---
titulo: "Missão — Escort"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "missions"]
fontes: ["game/data/missions/escort.tres", "game/data/resources/mission_data.gd"]
---

# Missão — Escort

← [[02 Conteúdo/Missões|Missões]]

Walk the cart along its route: clear the way, defend it at the stops, repair it if it breaks.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `escort` · **Nome no jogo:** Escort

| Campo | Valor | Origem |
|---|---|---|
| Disponível nas rotas | Sim | Por defeito no Resource |
| Quantidade de pontos | 2 | `.tres` |
| Segundos por ponto | 20.0 | `.tres` |
| radius | 8.0 | `.tres` |
| spike_seconds | 20.0 | `.tres` |
| escort_speed | 2.0 | `.tres` |
| escort_hp | 200.0 | `.tres` |
| escort_hit_dps | 4.0 | `.tres` |
| escort_contact_radius | 1.4 | `.tres` |
| block_radius | 2.0 | `.tres` |
| repair_seconds | 5.0 | `.tres` |
| repair_radius | 4.0 | `.tres` |
| repair_hp | 0.5 | `.tres` |
| route_min | 150.0 | `.tres` |
| route_max | 230.0 | `.tres` |
| Peso nos biomas preferidos | 1 | Por defeito no Resource |

## Fontes

- `game/data/missions/escort.tres`
- `game/data/resources/mission_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
