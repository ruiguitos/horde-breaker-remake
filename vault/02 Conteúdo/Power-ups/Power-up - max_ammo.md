---
titulo: "Power-up — MAX AMMO"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "power_ups"]
fontes: ["game/data/power_ups/max_ammo.tres", "game/data/resources/power_up_data.gd"]
---

# Power-up — MAX AMMO

← [[02 Conteúdo/Power-ups|Power-ups]]

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `max_ammo` · **Nome no jogo:** MAX AMMO

| Campo | Valor | Origem |
|---|---|---|
| Símbolo | ▥ | `.tres` |
| Peso no sorteio | 1.0 | Por defeito no Resource |
| Exige arma com reserva limitada | Sim | `.tres` |
| Duração (s) | 0.0 | Por defeito no Resource |
| Atraso de spawns (s) | 0.0 | Por defeito no Resource |
| Rerolls adicionais | 0 | Por defeito no Resource |
| Fração de escudo reposta | 0.0 | Por defeito no Resource |

O efeito exige recolha. Expirar ou sair da ilha sem apanhar perde o power-up. Ver [[03 Sistemas/Power-ups e pickups]].

## Fontes

- `game/data/power_ups/max_ammo.tres`
- `game/data/resources/power_up_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
