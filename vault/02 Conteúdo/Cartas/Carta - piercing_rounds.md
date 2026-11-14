---
titulo: "Carta — Piercing Rounds"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/piercing_rounds.tres", "game/data/resources/card_data.gd"]
---

# Carta — Piercing Rounds

← [[02 Conteúdo/Cartas|Cartas]]

Primary rounds pierce one extra target per rank.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `piercing_rounds` · **Nome no jogo:** Piercing Rounds

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 3 | `.tres` |
| Categoria | primary_weapon | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"pierce", &"damage"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Filtro de arma | Array[StringName]([&"rifle", &"smg", &"machine_gun"]) | `.tres` |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | {} | Por defeito no Resource |
| Desbloqueio (Intel) | 30 | `.tres` |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/piercing_rounds.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
