---
titulo: "Perk — Skirmisher"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/skirmisher.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Skirmisher

← [[02 Conteúdo/Perks|Perks]]

Mobile combat: keep moving while you shoot.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `skirmisher` · **Nome no jogo:** Skirmisher

| Campo | Valor | Origem |
|---|---|---|
| Ramo | combat | `.tres` |
| Patamar | 2 | `.tres` |
| Alternativa (0=A, 1=B) | 1 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Moving while firing: speed +{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(4, 8, 12) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Standing still: primary spread +{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(20, 40, 60) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/skirmisher.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
