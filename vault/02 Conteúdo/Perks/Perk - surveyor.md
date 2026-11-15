---
titulo: "Perk — Surveyor"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-15"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/surveyor.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Surveyor

← [[02 Conteúdo/Perks|Perks]]

Hold the ground and let the XP come.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `surveyor` · **Nome no jogo:** Surveyor

| Campo | Valor | Origem |
|---|---|---|
| Ramo | survival | `.tres` |
| Patamar | 3 | `.tres` |
| Alternativa (0=A, 1=B) | 1 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Standing still: XP pickup radius +{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(50, 75, 100) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Moving: XP pickup radius −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(10, 20, 30) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/surveyor.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
