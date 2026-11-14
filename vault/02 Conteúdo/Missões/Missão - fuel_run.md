---
titulo: "Missão — Fuel Run"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "missions"]
fontes: ["game/data/missions/fuel_run.tres", "game/data/resources/mission_data.gd"]
---

# Missão — Fuel Run

← [[02 Conteúdo/Missões|Missões]]

Carry three fuel cans to the boat, then get out.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `fuel_run` · **Nome no jogo:** Fuel Run

| Campo | Valor | Origem |
|---|---|---|
| Disponível nas rotas | Sim | Por defeito no Resource |
| Quantidade de pontos | 3 | `.tres` |
| pickup_radius | 1.8 | `.tres` |
| delivery_radius | 6.0 | `.tres` |
| carry_speed_mult | 0.8 | `.tres` |
| spike_seconds | 20.0 | `.tres` |
| Biomas preferidos | Array[StringName]([&"beach"]) | `.tres` |
| Peso nos biomas preferidos | 3 | `.tres` |

## Fontes

- `game/data/missions/fuel_run.tres`
- `game/data/resources/mission_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
