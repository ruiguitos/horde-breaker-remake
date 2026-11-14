---
titulo: "Perk — Spare Rerolls"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/spare_rerolls.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Spare Rerolls

← [[02 Conteúdo/Perks|Perks]]

Each island's first card screen gets extra redraws.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `spare_rerolls` · **Nome no jogo:** Spare Rerolls

| Campo | Valor | Origem |
|---|---|---|
| Ramo | logistics | `.tres` |
| Patamar | 3 | `.tres` |
| Alternativa (0=A, 1=B) | 1 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Extra rerolls on each island's first card screen: +{v} | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(1, 2, 3) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Valores da contrapartida (I/II/III) | PackedFloat32Array() | Por defeito no Resource |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/spare_rerolls.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
