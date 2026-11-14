---
titulo: "Perk — Thick Skin"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/thick_skin.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Thick Skin

← [[02 Conteúdo/Perks|Perks]]

Soak up the hits.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `thick_skin` · **Nome no jogo:** Thick Skin

| Campo | Valor | Origem |
|---|---|---|
| Ramo | survival | `.tres` |
| Patamar | 1 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Max HP +{v} | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(10, 20, 30) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Healing received −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(5, 10, 15) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/thick_skin.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
