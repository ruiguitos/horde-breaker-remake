---
titulo: "Power-up — MAX SHIELD"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "power_ups"]
fontes: ["game/data/power_ups/max_shield.tres", "game/data/resources/power_up_data.gd"]
---

# Power-up — MAX SHIELD

← [[02 Conteúdo/Power-ups|Power-ups]]

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `max_shield` · **Nome no jogo:** MAX SHIELD

| Campo | Valor | Origem |
|---|---|---|
| Símbolo | ◇ | `.tres` |
| Peso no sorteio | 1.0 | Por defeito no Resource |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Duração (s) | 0.0 | Por defeito no Resource |
| Atraso de spawns (s) | 0.0 | Por defeito no Resource |
| Rerolls adicionais | 0 | Por defeito no Resource |
| Fração de escudo reposta | 1.0 | `.tres` |
| IDs antigos | Array[StringName]([&"max_armor"]) | `.tres` |

O efeito exige recolha. Expirar ou sair da ilha sem apanhar perde o power-up. Ver [[03 Sistemas/Power-ups e pickups]].

## Fontes

- `game/data/power_ups/max_shield.tres`
- `game/data/resources/power_up_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
