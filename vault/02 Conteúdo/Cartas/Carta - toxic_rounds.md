---
titulo: "Carta — Toxic Rounds"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/toxic_rounds.tres", "game/data/resources/card_data.gd"]
---

# Carta — Toxic Rounds

← [[02 Conteúdo/Cartas|Cartas]]

Primary: +5% poison chance per rank. Deals 6 damage/s for 4 s. Refreshes without stacking.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `toxic_rounds` · **Nome no jogo:** Toxic Rounds

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 5 | `.tres` |
| Categoria | elements | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"toxic", &"damage_over_time"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Filtro de arma | Array[StringName]([&"rifle", &"smg", &"machine_gun"]) | `.tres` |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | {} | Por defeito no Resource |
| Desbloqueio (Intel) | 0 | Por defeito no Resource |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/toxic_rounds.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
