---
titulo: "Perk — Intimidating Cry"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/intimidating_cry.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Intimidating Cry

← [[02 Conteúdo/Perks|Perks]]

Scatter the threats around you.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `intimidating_cry` · **Nome no jogo:** Intimidating Cry

| Campo | Valor | Origem |
|---|---|---|
| Ramo | breaker | `.tres` |
| Patamar | 3 | `.tres` |
| Alternativa (0=A, 1=B) | 1 | `.tres` |
| Filtro de classe | vanguard | `.tres` |
| Benefício | War Cry pushes {v} m further | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(1, 2, 3) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | War Cry protection −{v} s | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(1, 2, 3) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/intimidating_cry.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
