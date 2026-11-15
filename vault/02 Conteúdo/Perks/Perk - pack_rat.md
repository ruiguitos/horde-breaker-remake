---
titulo: "Perk — Pack Rat"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/pack_rat.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Pack Rat

← [[02 Conteúdo/Perks|Perks]]

Long expeditions: more ammo for every weapon with a finite reserve.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `pack_rat` · **Nome no jogo:** Pack Rat

| Campo | Valor | Origem |
|---|---|---|
| Ramo | survival | `.tres` |
| Patamar | 2 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Secondary max ammo +{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(20, 35, 50) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Movement speed −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(2, 4, 6) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/pack_rat.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
