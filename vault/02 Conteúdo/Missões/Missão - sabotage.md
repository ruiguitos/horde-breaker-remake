---
titulo: "Missão — Sabotage"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "missions"]
fontes: ["game/data/missions/sabotage.tres", "game/data/resources/mission_data.gd"]
---

# Missão — Sabotage

← [[02 Conteúdo/Missões|Missões]]

Cut the power, plant charges on the machine, then get clear before it blows.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `sabotage` · **Nome no jogo:** Sabotage

| Campo | Valor | Origem |
|---|---|---|
| Disponível nas rotas | Sim | Por defeito no Resource |
| Quantidade de pontos | 2 | `.tres` |
| Segundos por ponto | 5.0 | `.tres` |
| radius | 3.0 | `.tres` |
| spike_seconds | 12.0 | `.tres` |
| power_seconds | 8.0 | `.tres` |
| power_radius | 4.0 | `.tres` |
| power_spike_seconds | 20.0 | `.tres` |
| fuse_seconds | 20.0 | `.tres` |
| blast_radius | 15.0 | `.tres` |
| blast_damage | 0.6 | `.tres` |
| Biomas preferidos | Array[StringName]([&"port"]) | `.tres` |
| Peso nos biomas preferidos | 3 | `.tres` |

## Fontes

- `game/data/missions/sabotage.tres`
- `game/data/resources/mission_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
