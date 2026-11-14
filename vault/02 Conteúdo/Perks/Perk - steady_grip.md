---
titulo: "Perk — Steady Grip"
tipo: "conteudo"
estado: "dados_observados"
atualizado: "2026-11-14"
tags: ["horde-breaker", "perks"]
fontes: ["game/data/perks/steady_grip.tres", "game/data/resources/perk_data.gd"]
---

# Perk — Steady Grip

← [[02 Conteúdo/Perks|Perks]]

Defensive stance: hold still to tighten your aim.

> [!info] Dados observados, não equilíbrio final
> Valores lidos do `.tres` e dos valores por defeito do Resource. São dados base; dificuldade, cartas, perks e lógica podem alterá-los. A descrição é texto do jogo, não prova isolada do efeito.

**ID:** `steady_grip` · **Nome no jogo:** Steady Grip

| Campo | Valor | Origem |
|---|---|---|
| Ramo | combat | `.tres` |
| Patamar | 2 | `.tres` |
| Alternativa (0=A, 1=B) | 0 | `.tres` |
| Filtro de classe |  | Por defeito no Resource |
| Benefício | Standing still: primary spread −{v}% | `.tres` |
| Valores do benefício (I/II/III) | PackedFloat32Array(20, 40, 60) | `.tres` |
| Valores do segundo benefício | PackedFloat32Array() | Por defeito no Resource |
| Contrapartida | Moving: primary fire rate −{v}% | `.tres` |
| Valores da contrapartida (I/II/III) | PackedFloat32Array(5, 10, 15) | `.tres` |

Os arrays de valores são totais por rank, não incrementos. Os ranks pertencem ao nó; há alternativas com contrapartidas. Ver [[03 Sistemas/Intel e perks]].

## Fontes

- `game/data/perks/steady_grip.tres`
- `game/data/resources/perk_data.gd`
- [[90 Referências/docs/tech/COMBAT_CATALOG|Catálogo técnico — referência com histórico]]
