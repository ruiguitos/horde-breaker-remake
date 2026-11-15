---
titulo: "Carta — Field Dressing"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "cards"]
fontes: ["game/data/cards/field_dressing.tres", "game/data/resources/card_data.gd"]
---

# Carta — Field Dressing

← [[02 Conteúdo/Cartas|Cartas]]

Each collected XP orb heals 0.2 HP per rank.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `field_dressing` · **Nome no jogo:** Field Dressing

| Campo | Valor | Origem |
|---|---|---|
| Ranks máximos | 5 | `.tres` |
| Categoria | sustain | `.tres` |
| Etiquetas do jogo | Array[StringName]([&"pickup", &"heal"]) | `.tres` |
| Filtro de classe | — | Por defeito no Resource |
| Exige arma com reserva limitada | Não | Por defeito no Resource |
| Pré-requisitos | {} | Por defeito no Resource |
| Desbloqueio (Intel) | 0 | Por defeito no Resource |

Ver [[03 Sistemas/XP e cartas]] para recolha de XP, ranks máximos e rerolls.

## Fontes

- `game/data/cards/field_dressing.tres`
- `game/data/resources/card_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
