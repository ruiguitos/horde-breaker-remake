---
titulo: "Power-up — EXTRA REROLL"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "power_ups"]
fontes: ["game/data/power_ups/extra_reroll.tres", "game/data/resources/power_up_data.gd"]
---

# Power-up — EXTRA REROLL

← [[02 Conteúdo/Power-ups|Power-ups]]

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `extra_reroll` · **Nome no jogo:** EXTRA REROLL

| Campo | Valor | Origem |
|---|---|---|
| Símbolo | ↻ | `.tres` |
| Peso no sorteio | 1.0 | Por defeito no Resource |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Duração (s) | 0.0 | Por defeito no Resource |
| Atraso de spawns (s) | 0.0 | Por defeito no Resource |
| Rerolls adicionais | 1 | `.tres` |
| Fração de escudo reposta | 0.0 | Por defeito no Resource |
| IDs antigos | Array[StringName]([&"fire_sale"]) | `.tres` |

O efeito exige recolha. Expirar ou sair da ilha sem apanhar perde o power-up. Ver [[03 Sistemas/Power-ups e pickups]].

## Fontes

- `game/data/power_ups/extra_reroll.tres`
- `game/data/resources/power_up_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
